defmodule Anchor.Domain.Graph.Inlines do
  @moduledoc """
  The stdlib calls Elixir inlines before Core, and their two spellings —
  **Domain**, pure (DND-5551).

  The graph is read from Core Erlang, where a source `Map.put(map, :k, v)` is
  already `:maps.put(:k, v, map)`: the edge names `{:maps, :put, 3}`. A rule
  that names a stdlib function must match both spellings, or a rule naming
  `Map.put/3` never sees the call. `spellings/1` gives every name of one Core
  call; `Anchor.Domain.Graph.calls_to/2` matches through it.

  The table is derived from Elixir's own rewrite rules when Anchor compiles
  (`Anchor.Domain.Graph.Inlines.Derive`), never copied by hand, so it is the
  table of the Elixir Anchor runs on.

  Core cannot tell apart two Elixir names that compile to one Erlang function
  (`Bitwise.band/2` and `Bitwise.&&&/2`, or `Process.monitor/1` and
  `Port.monitor/1`, both `:erlang.monitor/2`), nor a source call written in
  Erlang spelling from one Elixir rewrote. So every one of them is a spelling
  of the others: a rule naming any of them matches all of them.
  """

  alias Anchor.Domain.Graph.Inlines.Derive

  @table Derive.derive()

  @elixir_names @table
                |> Enum.group_by(fn {_elixir, erlang} -> erlang end, fn {elixir, _erlang} ->
                  elixir
                end)
                |> Map.new(fn {erlang, names} -> {erlang, Enum.sort(names)} end)

  @doc "`%{elixir_mfa => erlang_mfa}`: every stdlib call Elixir compiles into another function."
  @spec table() :: %{mfa() => mfa()}
  def table, do: @table

  @doc """
  Every name of the Core call `mfa` names, sorted: `mfa` itself, the Erlang
  function an Elixir name compiles to, and every Elixir name that compiles to
  that Erlang function. A function with no other spelling gives `[mfa]`.
  """
  @spec spellings(mfa()) :: [mfa()]
  def spellings({_module, _name, _arity} = mfa) do
    erlang = Map.get(@table, mfa, mfa)

    [mfa, erlang | elixir_names(erlang)]
    |> Enum.uniq()
    |> Enum.sort()
  end

  @doc """
  The Elixir names that compile to the Erlang function `mfa`, sorted; `[]`
  when none does (an Elixir name itself gives `[]`).
  """
  @spec elixir_names(mfa()) :: [mfa()]
  def elixir_names({_module, _name, _arity} = mfa), do: Map.get(@elixir_names, mfa, [])
end
