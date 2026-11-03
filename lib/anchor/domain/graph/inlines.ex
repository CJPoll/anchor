defmodule Anchor.Domain.Graph.Inlines do
  @moduledoc """
  The stdlib calls Elixir inlines before Core, and their two spellings —
  **Domain**, pure (DND-5551).

  The graph is read from Core Erlang, where a source `Map.merge(a, b)` is
  already `:maps.merge(a, b)`, so the edge names `{:maps, :merge, 2}`; a
  source `Map.put/3` is a map update with no call in it, which
  `Anchor.Domain.Graph.CoreWalker` reads back as `{:maps, :put, 3}`. A rule
  that names a stdlib function must match both spellings, or a rule naming
  `Map.put/3` never sees the call. `spellings/1` gives every name of one Core
  call; `Anchor.Domain.Graph.calls_to/2` matches through it.

  The table is derived from Elixir's own rewrite rules when Anchor compiles
  (`Anchor.Domain.Graph.Inlines.Derive`), never copied by hand, so it is the
  table of the Elixir Anchor runs on.

  ## Tags (DND-5613)

  Some rewrites add a literal argument that tells two Elixir names of one
  Erlang function apart: `Process.monitor/1` is `:erlang.monitor(:process,
  pid)` and `Port.monitor/1` is `:erlang.monitor(:port, port)`. `tags/0` holds
  those literals per Elixir name (derived, like the table). The walker reads
  the tag of such a call back into its Elixir name (`tagged_source/2`), so the
  edge says `Process.monitor/1`, and `spellings/1` of a tagged name leaves out
  a sibling whose tag differs: a rule naming `Process.monitor/1` never matches
  `Port.monitor/1`.

  Two Elixir names no tag tells apart (`Bitwise.band/2` and `Bitwise.&&&/2`,
  `Process.demonitor/1` and `Port.demonitor/1`), and an Erlang call whose tag
  is not a literal (`:erlang.monitor(type, pid)`), stay ambiguous: each is a
  spelling of the others, so a rule naming any of them matches all of them
  (a false positive, never a miss), and `describe/1` names every candidate
  source function, never one guessed name.

  The AST engine reads source, where the name as written is exact; it matches
  through `Anchor.Domain.FunctionRef.names/1`, the same spellings. A source
  call written in Erlang spelling (`:erlang.monitor(:port, p)`) matches every
  Elixir name of that Erlang function there, since the AST rule does not read
  arguments.
  """

  alias Anchor.Domain.Graph.Inlines.Derive

  # The one read of global state, at compile time only: the exports of every
  # `Elixir.*` module of the Elixir compiling Anchor, the domain of the
  # rewrite rules. `table/0` and the functions below are pure.
  @exports for module <- Enum.sort(Application.spec(:elixir, :modules)),
               String.starts_with?(Atom.to_string(module), "Elixir."),
               do: {module, module.module_info(:exports)}

  @table Derive.derive(@exports)
  @tags Derive.tags(@exports)

  # The Erlang functions some tagged Elixir name compiles to.
  @tagged_targets @tags |> Map.keys() |> MapSet.new(&Map.fetch!(@table, &1))

  # `{module, name} => [arity]` for every name in the table, either side, so a
  # token with no arity (`"Map.put"`) finds every arity it has a spelling at.
  @arities (Map.keys(@table) ++ Map.values(@table))
           |> Enum.group_by(fn {m, f, _a} -> {m, f} end, fn {_m, _f, a} -> a end)
           |> Map.new(fn {name, arities} -> {name, arities |> Enum.uniq() |> Enum.sort()} end)

  @elixir_names @table
                |> Enum.group_by(fn {_elixir, erlang} -> erlang end, fn {elixir, _erlang} ->
                  elixir
                end)
                |> Map.new(fn {erlang, names} -> {erlang, Enum.sort(names)} end)

  @doc "`%{elixir_mfa => erlang_mfa}`: every stdlib call Elixir compiles into another function."
  @spec table() :: %{mfa() => mfa()}
  def table, do: @table

  @doc """
  `%{elixir_mfa => [{index, literal}]}`: the literal arguments each tagged
  rewrite adds (see the moduledoc, "Tags").
  """
  @spec tags() :: %{mfa() => [{non_neg_integer(), term()}]}
  def tags, do: @tags

  @doc "The tag of the Elixir name `mfa`, `[]` when it has none."
  @spec tag(mfa()) :: [{non_neg_integer(), term()}]
  def tag({_module, _name, _arity} = mfa), do: Map.get(@tags, mfa, [])

  @doc """
  The arities at which `module.name` has an entry in the table (as an Elixir
  name or as the Erlang function one compiles to), sorted.
  """
  @spec arities(module(), atom()) :: [arity()]
  def arities(module, name), do: Map.get(@arities, {module, name}, [])

  @doc """
  Every name of the Core call `mfa` names, sorted: `mfa` itself, the Erlang
  function an Elixir name compiles to, and every Elixir name that compiles to
  that Erlang function, except one whose tag differs from `mfa`'s (both
  tagged). A function with no other spelling gives `[mfa]`.
  """
  @spec spellings(mfa()) :: [mfa()]
  def spellings({_module, _name, _arity} = mfa) do
    erlang = Map.get(@table, mfa, mfa)
    own = tag(mfa)

    siblings = erlang |> elixir_names() |> Enum.filter(&same_function?(own, tag(&1)))

    [mfa, erlang | siblings]
    |> Enum.uniq()
    |> Enum.sort()
  end

  @doc """
  The Elixir name a call of the Erlang function `erlang` stands for, read
  from its arguments' literals (`[{:ok, value} | :error]`, one per argument,
  `:error` for one that is not a literal): the one tagged Elixir name whose
  every tag literal is there, or `nil` when none or more than one is.
  """
  @spec tagged_source(mfa(), [{:ok, term()} | :error]) :: mfa() | nil
  def tagged_source(erlang, args) do
    if MapSet.member?(@tagged_targets, erlang) do
      erlang
      |> elixir_names()
      |> Enum.filter(&tag_holds?(tag(&1), args))
      |> one()
    end
  end

  @doc """
  Every source function a call edge of `mfa` may have been written as,
  sorted: `[mfa]` when no Elixir name compiles to it, else `mfa` and every
  Elixir name that does.
  """
  @spec candidates(mfa()) :: [mfa()]
  def candidates({_module, _name, _arity} = mfa) do
    case elixir_names(mfa) do
      [] -> [mfa]
      names -> Enum.sort([mfa | names])
    end
  end

  @doc """
  Whether a call edge of `mfa` cannot say which of two or more Elixir names
  was written (`:erlang.band/2`: `Bitwise.band/2` or `Bitwise.&&&/2`).
  """
  @spec ambiguous?(mfa()) :: boolean()
  def ambiguous?({_module, _name, _arity} = mfa), do: length(elixir_names(mfa)) > 1

  @doc """
  The call edge `mfa` as a reader names it: its one Elixir name
  (`{:maps, :put, 3}` is `"Map.put/3"`), itself when it has none, and for an
  ambiguous one every candidate source function, never one guessed name.
  """
  @spec describe(mfa()) :: String.t()
  def describe({_module, _name, _arity} = mfa) do
    case elixir_names(mfa) do
      [] ->
        text(mfa)

      [one] ->
        text(one)

      _many ->
        "one of #{mfa |> candidates() |> Enum.map_join(", ", &text/1)} (each compiles to " <>
          "#{text(mfa)}, so the compiled call does not say which was written)"
    end
  end

  @doc """
  The Elixir names that compile to the Erlang function `mfa`, sorted; `[]`
  when none does (an Elixir name itself gives `[]`).
  """
  @spec elixir_names(mfa()) :: [mfa()]
  def elixir_names({_module, _name, _arity} = mfa), do: Map.get(@elixir_names, mfa, [])

  defp same_function?([], _other), do: true
  defp same_function?(_own, []), do: true
  defp same_function?(own, other), do: own == other

  defp tag_holds?([], _args), do: false

  defp tag_holds?(tag, args),
    do: Enum.all?(tag, fn {index, value} -> Enum.at(args, index) == {:ok, value} end)

  defp one([only]), do: only
  defp one(_none_or_many), do: nil

  defp text({module, name, arity}), do: "#{inspect(module)}.#{name}/#{arity}"
end
