defmodule Anchor.Domain.Graph.InlinesTest do
  # Domain (ADR 002). DND-5551: Elixir rewrites some stdlib calls to Erlang ones
  # before Core (Map.put becomes :maps.put), so the graph names the Erlang
  # function. Anchor carries the table, derived from Elixir's own rewrite rules,
  # and every stdlib name matches both spellings.
  #
  # Sabotage record: ../../../sabotage_records/inlines-20261103-dnd_5551_graph_hardening.md
  use ExUnit.Case, async: true

  alias Anchor.Domain.Graph.Inlines
  alias Anchor.Domain.Graph.Inlines.Derive

  describe "table/0" do
    test "holds Map.put/3 and Map.merge/2 under their Erlang spellings" do
      assert Map.fetch!(Inlines.table(), {Map, :put, 3}) == {:maps, :put, 3}
      assert Map.fetch!(Inlines.table(), {Map, :merge, 2}) == {:maps, :merge, 2}
    end

    test "is the table Elixir's rewrite rules give on the Elixir it runs on, not a copy" do
      assert Inlines.table() == Derive.derive()
    end

    test "every entry follows Elixir's own rule for that function" do
      for {{module, name, arity} = elixir, erlang} <- Inlines.table() do
        assert erlang != elixir
        assert Derive.rewritten(module, name, arity) == erlang
      end
    end

    test "a function Elixir does not rewrite is not in it (positive control: Map.get/2)" do
      refute Map.has_key?(Inlines.table(), {Map, :get, 2})
      assert Derive.rewritten(Map, :get, 2) == nil
      assert Derive.rewritten(Map, :put, 3) == {:maps, :put, 3}
    end
  end

  describe "spellings/1" do
    test "the Elixir name gives both spellings" do
      assert Inlines.spellings({Map, :put, 3}) == [{Map, :put, 3}, {:maps, :put, 3}]
      assert Inlines.spellings({Map, :merge, 2}) == [{Map, :merge, 2}, {:maps, :merge, 2}]
    end

    test "the Erlang name gives both spellings" do
      assert Inlines.spellings({:maps, :put, 3}) == [{Map, :put, 3}, {:maps, :put, 3}]
      assert Inlines.spellings({:maps, :merge, 2}) == [{Map, :merge, 2}, {:maps, :merge, 2}]
    end

    test "every Elixir name Core cannot tell apart is a spelling (Bitwise.band and &&&)" do
      expected = [{Bitwise, :&&&, 2}, {Bitwise, :band, 2}, {:erlang, :band, 2}]

      assert Inlines.spellings({Bitwise, :band, 2}) == expected
      assert Inlines.spellings({:erlang, :band, 2}) == expected
    end

    test "a function with no other spelling is only itself" do
      assert Inlines.spellings({Map, :get, 2}) == [{Map, :get, 2}]
      assert Inlines.spellings({:maps, :get, 3}) == [{:maps, :get, 3}]
    end
  end

  describe "elixir_names/1" do
    test "maps an Erlang function back to the Elixir names that compile to it" do
      assert Inlines.elixir_names({:maps, :put, 3}) == [{Map, :put, 3}]
      assert Inlines.elixir_names({:maps, :merge, 2}) == [{Map, :merge, 2}]
    end

    test "is empty for a function no Elixir name compiles to" do
      assert Inlines.elixir_names({:maps, :get, 3}) == []
      assert Inlines.elixir_names({Map, :put, 3}) == []
    end
  end
end
