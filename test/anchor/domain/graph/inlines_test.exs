defmodule Anchor.Domain.Graph.InlinesTest do
  # Domain (ADR 002). DND-5551: Elixir rewrites some stdlib calls to Erlang ones
  # before Core (Map.put becomes :maps.put), so the graph names the Erlang
  # function. Anchor carries the table, derived from Elixir's own rewrite rules,
  # and every stdlib name matches both spellings.
  #
  # Sabotage record: ../../../sabotage_records/inlines-20261103-dnd_5551_graph_hardening.md
  # Sabotage record (DND-5613): ../../../sabotage_records/inlines-20261103-dnd_5447_graph_rules_c.md
  use ExUnit.Case, async: true

  alias Anchor.Domain.Graph.Inlines
  alias Anchor.Domain.Graph.Inlines.Derive

  describe "table/0" do
    test "holds Map.put/3 and Map.merge/2 under their Erlang spellings" do
      assert Map.fetch!(Inlines.table(), {Map, :put, 3}) == {:maps, :put, 3}
      assert Map.fetch!(Inlines.table(), {Map, :merge, 2}) == {:maps, :merge, 2}
    end

    test "is the table Elixir's rewrite rules give on the Elixir it runs on, not a copy" do
      exports =
        for module <- Application.spec(:elixir, :modules),
            String.starts_with?(Atom.to_string(module), "Elixir."),
            do: {module, module.module_info(:exports)}

      assert Inlines.table() == Derive.derive(exports)
    end

    test "derive/1 reads only the exports it is given" do
      assert Derive.derive([{Map, [put: 3, get: 2, module_info: 0]}]) ==
               %{{Map, :put, 3} => {:maps, :put, 3}}
    end

    test "derive/1 refuses to give an empty table" do
      assert_raise ArgumentError, ~r/derived no inline table.*Fix:/, fn ->
        Derive.derive([{Map, [get: 2]}])
      end
    end

    # One rewrite level is all spellings/1 follows, so a rewrite whose target
    # is itself rewritten must fail here, not go unseen.
    test "no entry rewrites into a function that is rewritten again" do
      table = Inlines.table()
      assert Enum.filter(Map.values(table), &Map.has_key?(table, &1)) == []
      # Positive control: the table's keys are Elixir names it does hold.
      assert Map.has_key?(table, {Map, :put, 3})
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

  # DND-5613: an inline whose rewrite adds a literal argument (a tag) is told
  # apart from its siblings by that tag.
  describe "tags/0 and spellings/1 of tagged inlines (DND-5613)" do
    test "the tag table holds each rewrite's literal arguments by position" do
      assert Inlines.tag({Process, :monitor, 1}) == [{0, :process}]
      assert Inlines.tag({Port, :monitor, 1}) == [{0, :port}]
      assert Inlines.tag({Process, :monitor, 2}) == [{0, :process}]
      assert Inlines.tag({Float, :to_string, 1}) == [{1, [:short]}]
    end

    test "the tag table is derived from Elixir's rules, not copied" do
      exports =
        for module <- Application.spec(:elixir, :modules),
            String.starts_with?(Atom.to_string(module), "Elixir."),
            do: {module, module.module_info(:exports)}

      assert Inlines.tags() == Derive.tags(exports)
    end

    test "an untagged inline has no tag (positive control: Map.put/3, Bitwise.band/2)" do
      assert Inlines.tag({Map, :put, 3}) == []
      assert Inlines.tag({Bitwise, :band, 2}) == []
      assert Derive.tag(Map, :put, 3) == []
    end

    test "a tagged name's spellings leave out a sibling with another tag" do
      assert Inlines.spellings({Process, :monitor, 1}) ==
               [{Process, :monitor, 1}, {:erlang, :monitor, 2}]

      assert Inlines.spellings({Port, :monitor, 1}) ==
               [{Port, :monitor, 1}, {:erlang, :monitor, 2}]
    end

    test "the Erlang name of a tagged inline spells every Elixir name" do
      assert Inlines.spellings({:erlang, :monitor, 2}) ==
               [{Port, :monitor, 1}, {Process, :monitor, 1}, {:erlang, :monitor, 2}]
    end

    test "tagged_source/2 names the one Elixir name whose tag the literal arguments hold" do
      assert Inlines.tagged_source({:erlang, :monitor, 2}, [{:ok, :process}, :error]) ==
               {Process, :monitor, 1}

      assert Inlines.tagged_source({:erlang, :monitor, 2}, [{:ok, :port}, :error]) ==
               {Port, :monitor, 1}

      assert Inlines.tagged_source({:erlang, :monitor, 2}, [:error, :error]) == nil
      assert Inlines.tagged_source({:erlang, :monitor, 2}, [{:ok, :time_offset}, :error]) == nil
      assert Inlines.tagged_source({:maps, :put, 3}, [:error, :error, :error]) == nil
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
