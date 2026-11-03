defmodule Anchor.Domain.Graph.Inlines.Derive do
  @moduledoc """
  Derives the inline table from Elixir's own rewrite rules — **Domain**, pure
  (DND-5551).

  Before Core, Elixir rewrites some stdlib calls into Erlang ones: `Map.put/3`
  becomes `:maps.put/3` (its arguments reordered), `Map.merge/2` becomes
  `:maps.merge/2`, `Kernel.elem/2` becomes `:erlang.element/2`, and so on. The
  rules live in the compiler module `:elixir_rewrite` of the Elixir that
  compiles the code, in two kinds: `inline/3` (same arguments) and
  `rewrite/5` (arguments changed). Copying them by hand would go stale with the
  next Elixir, so this module asks those two functions instead, for every
  exported function it is given. Both are pure functions of their arguments;
  nothing is compiled or run, and nothing here reads global state.

  `Anchor.Domain.Graph.Inlines` carries the result as its table, computed when
  Anchor compiles, from every exported function of every `Elixir.*` module of
  the `:elixir` application (read there, once, at compile time). Mix
  recompiles every dependency when the Elixir version changes, so the table
  always belongs to the Elixir Anchor runs on.
  """

  @doc """
  The table: `%{elixir_mfa => erlang_mfa}` for every function in `exports`
  (`[{module, [{name, arity}]}]`, a module's `module_info(:exports)`) that
  Elixir compiles into a call of another function. Raises when it finds none:
  an empty table would read as "nothing is rewritten".
  """
  @spec derive([{module(), [{atom(), arity()}]}]) :: %{mfa() => mfa()}
  def derive(exports) do
    table =
      for {module, functions} <- exports,
          {name, arity} <- functions,
          name not in [:module_info, :__info__],
          erlang = rewritten(module, name, arity),
          erlang != nil,
          into: %{},
          do: {{module, name, arity}, erlang}

    if map_size(table) == 0 do
      raise ArgumentError,
            "Anchor derived no inline table from :elixir_rewrite. Fix: this Elixir's rewrite " <>
              "rules have changed shape; Anchor must be updated for it."
    end

    table
  end

  @doc """
  The function Elixir compiles a call of `module.name/arity` into, or `nil`
  when it compiles to a call of that same function.
  """
  @spec rewritten(module(), atom(), arity()) :: mfa() | nil
  def rewritten(module, name, arity) do
    case :elixir_rewrite.inline(module, name, arity) do
      {erlang_module, erlang_name} -> {erlang_module, erlang_name, arity}
      false -> rewritten_call(module, name, arity)
    end
  end

  defp rewritten_call(module, name, arity) do
    args = Macro.generate_arguments(arity, __MODULE__)

    case :elixir_rewrite.rewrite(module, [], name, [], args) do
      {{:., _dot_meta, [to_module, to_name]}, _meta, to_args}
      when is_atom(to_module) and is_atom(to_name) and is_list(to_args) ->
        other({module, name, arity}, {to_module, to_name, length(to_args)})

      other ->
        raise ArgumentError,
              "Elixir rewrites #{inspect(module)}.#{name}/#{arity} into #{Macro.to_string(other)}, " <>
                "which is not one call. Fix: Anchor's inline table must learn this rewrite shape."
    end
  end

  defp other(same, same), do: nil
  defp other(_elixir, erlang), do: erlang
end
