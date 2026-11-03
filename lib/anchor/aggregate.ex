defmodule Anchor.Aggregate do
  @moduledoc """
  Declares an aggregate from code (DND-5476) — a **Framework** module (ADR
  001): a compile-time macro that persists one attribute and nothing else.

      defmodule MyApp.Threads.ThreadStore do
        use Anchor.Aggregate,
          name: MyApp.Threads.ThreadSpace,
          schemas: [MyApp.Threads.Thread, MyApp.Threads.Message],
          tables: ["thread_reads"]
      end

  expands to exactly

      Module.register_attribute(__MODULE__, :anchor_aggregate, persist: true)
      @anchor_aggregate [name: MyApp.Threads.ThreadSpace,
                         schemas: [MyApp.Threads.Thread, MyApp.Threads.Message],
                         tables: ["thread_reads"], owner: true]

  Options: `name` (required, a module name; it need not be a module),
  `schemas` (module names, default `[]`), `tables` (non-empty strings, default
  `[]`), `owner` (default `true`: the module that uses the macro owns the
  aggregate, DND-5478). Aliases in scope resolve. A schema module that only
  states its membership writes `schemas: [__MODULE__], owner: false`.

  A non-literal option, an unknown key, a missing `name` or a value of the
  wrong type raises `ArgumentError` at compile time, naming the key and the
  shape: the earliest point a declaration can fail closed.

  `mix anchor.graph` reads the attribute from the beam
  (`Anchor.Domain.Aggregates.Index`). The macro defines no function and adds
  no runtime call, but a module that uses it needs Anchor at compile time in
  every environment it compiles in. A repo that keeps Anchor dev/test-only
  writes the two lines above by hand instead: they are read the same.
  """

  @keys [:name, :schemas, :tables, :owner]
  @shape "use Anchor.Aggregate, name: MyApp.Space, schemas: [MyApp.Schema], " <>
           "tables: [\"table\"], owner: true"

  @doc false
  defmacro __using__(opts) do
    value = opts |> Macro.expand_literals(__CALLER__) |> attribute!()

    quote do
      Module.register_attribute(__MODULE__, :anchor_aggregate, persist: true)
      @anchor_aggregate unquote(Macro.escape(value))
    end
  end

  # The attribute value `opts` (already expanded) declares, or an
  # `ArgumentError` naming the key and the shape.
  defp attribute!(opts) do
    unless is_list(opts) and Keyword.keyword?(opts) do
      refuse!("the options must be a keyword list, got: #{Macro.to_string(opts)}")
    end

    case Keyword.keys(opts) -- @keys do
      [] -> :ok
      unknown -> refuse!("unknown option(s) #{Enum.map_join(unknown, ", ", &inspect/1)}")
    end

    [
      name: fetch_name!(opts),
      schemas: modules!(opts),
      tables: tables!(opts),
      owner: owner!(opts)
    ]
  end

  defp fetch_name!(opts) do
    case Keyword.fetch(opts, :name) do
      {:ok, name} -> module!(:name, name)
      :error -> refuse!("the name: option is required")
    end
  end

  defp modules!(opts) do
    case Keyword.get(opts, :schemas, []) do
      schemas when is_list(schemas) -> Enum.map(schemas, &module!(:schemas, &1))
      other -> refuse!("schemas: must be a list of module names, got: #{Macro.to_string(other)}")
    end
  end

  defp module!(key, value) do
    if is_atom(value) and String.starts_with?(Atom.to_string(value), "Elixir."),
      do: value,
      else: refuse!("#{key}: must be a literal module name, got: #{Macro.to_string(value)}")
  end

  defp tables!(opts) do
    tables = Keyword.get(opts, :tables, [])

    if is_list(tables) and Enum.all?(tables, &(is_binary(&1) and &1 != "")),
      do: tables,
      else:
        refuse!("tables: must be a list of non-empty strings, got: #{Macro.to_string(tables)}")
  end

  defp owner!(opts) do
    case Keyword.get(opts, :owner, true) do
      owner when is_boolean(owner) -> owner
      other -> refuse!("owner: must be true or false, got: #{Macro.to_string(other)}")
    end
  end

  defp refuse!(why), do: raise(ArgumentError, "use Anchor.Aggregate: #{why}. Write: #{@shape}")
end
