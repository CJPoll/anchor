defmodule Anchor.Domain.Aggregates.WriteSitesDefaultTest do
  # DND-5889: the walker's default. Every call and apply it reaches is a site, a
  # followed project call, a call the no-write list clears, or a gap at its line.
  #
  # Sabotage record: ../../../sabotage_records/aggregates-20261106-dnd_5889_default_deny_walker.md
  use ExUnit.Case, async: true

  import Anchor.Test.WriteFixtures

  alias Anchor.Domain.Aggregates.Analysis
  alias Anchor.Domain.Aggregates.Config
  alias Anchor.Domain.Aggregates.Scope
  alias Anchor.Domain.Aggregates.WriteSites
  alias Anchor.Domain.FunctionRef
  alias Anchor.Test.BeamFixtures

  @ns AnchorFixtures.WriteSitesDefaultTest
  @s Module.concat(@ns, S)
  @repo Module.concat(@ns, Repo)
  @d Module.concat(@ns, D)
  @uow Module.concat(@ns, UoW)
  # No module of this name exists: a dependency, as Anchor sees one.
  @lib Module.concat(@ns, Lib)
  @listed Module.concat(@ns, Listed)
  @macros Module.concat(@ns, Macros)

  @source """
  defmodule #{inspect(@uow)} do
    def transaction(_first, _second), do: :ok
    def outer(g), do: transaction(fn -> #{inspect(@repo)}.insert(%#{inspect(@s)}{}) end, g)
    def pass_on(f, g), do: transaction(f, g)
  end

  defmodule #{inspect(@macros)} do
    defmacro m(x), do: x
  end

  defmodule #{inspect(@d)} do
    alias #{inspect(@repo)}
    alias #{inspect(@s)}
    alias #{inspect(@lib)}
    alias #{inspect(@listed)}
    alias #{inspect(@uow)}
    alias Ecto.Multi
    require Logger

    def d4(x), do: Repo.transaction(fn -> Lib.save(x) end)
    def d5(l), do: Repo.transaction(fn -> Enum.count(l) end)
    def d6(pid), do: Repo.transaction(fn -> GenServer.call(pid, :save) end)
    def d7a(m, f, a), do: Repo.transaction(fn -> apply(m, f, a) end)
    def d7b(f), do: Repo.transaction(fn -> f.() end)
    def d8a(m), do: Repo.transaction(fn -> Keyword.put(m, :k, fn -> :ok end) end)
    def d8b(m), do: Repo.transaction(fn -> Keyword.put(m, :k, &own/0) end)
    def d8c, do: Repo.transaction(fn -> Listed.run(fn -> :ok end) end)
    def d8d(x), do: Repo.transaction(fn -> Listed.run(x) end)
    def d8e(l), do: Repo.transaction(fn -> Enum.map(l, fn x -> x end) end)
    def d8f(o), do: Repo.transaction(fn -> Keyword.get(o, :f, &own/0) end)
    def d8g(cs), do: Repo.transaction(fn -> Ecto.Changeset.prepare_changes(cs, fn c -> c end) end)
    def own, do: :ok

    def d9, do: Repo.transaction(fn -> first() end)
    def d9_clean, do: Repo.transaction(fn -> Repo.insert(%S{}) end)
    defp first, do: second()
    defp second, do: Lib.save(1)

    def d10(x), do: Lib.save(x)
    def d10_caller(x), do: d10(x)
    def d10_clean(l), do: Enum.count(l)

    def d11a, do: Repo.transaction(fn -> Repo.insert(%S{}) end)
    def d11b, do: Multi.new() |> Multi.insert(:a, %S{}) |> Repo.transaction()
    def d11c, do: Repo.transaction(fn -> Lib.soft_delete(%S{}) end)
    def d11d, do: Repo.transaction(fn -> Repo.query!("DELETE FROM s") end)
    def d11e(q), do: Repo.transaction(fn -> Repo.all(q) end)

    def d12a(l), do: Repo.transaction(fn -> Enum.map(l, &Lib.save/1) end)
    def d12b(l), do: Repo.transaction(fn -> Enum.map(l, &String.upcase/1) end)
    def d12c, do: Repo.transaction(fn -> &Enum.map/2 end)
    def d12d, do: Repo.transaction(fn -> &Multi.insert/3 end)
    def d12e, do: Repo.transaction(fn -> &Repo.all/1 end)

    def d13a(x), do: Repo.transaction(fn -> apply(Lib, :save, [x]) end)
    def d13b(m), do: Repo.transaction(fn -> apply(Map, :put, [m, :k, 1]) end)
    def d13c, do: Repo.transaction(fn -> apply(Enum, :to_list, []) end)

    def d14a(g), do: UoW.transaction(fn -> Repo.insert(%S{}) end, g)
    def d14b, do: UoW.transaction(fn -> Repo.insert(%S{}) end, :log)

    def d15, do: Repo.transaction(fn -> Multi.new() |> Multi.not_a_function() end)
    def d15b(m), do: Repo.transaction(fn -> Multi.put(m, :k, fn -> :ok end) end)
    def d15c(m), do: Repo.transaction(fn -> {Multi.to_list(m), Multi.put(m, :k, 1)} end)

    def d16, do: Repo.transaction(fn -> (fn -> Repo.insert(%S{}) end).() end)
    def d16b, do: (fn -> Repo.insert(%S{}) end).()
    def d17(pid), do: GenServer.call(pid, :save)
    def d18, do: Task.async(fn -> :ok end)
    def d20a, do: Repo.transaction(fn -> Logger.debug(fn -> "x" end) end)
    def d20h(m), do: Repo.transaction(fn -> Logger.info(m) end)
    def d20i(m), do: Repo.transaction(fn -> Logger.info("said \#{m}") end)
    def d20j(m), do: Repo.transaction(fn -> Logger.error(inspect(m)) end)
    def d20b(c), do: Repo.transaction(fn -> Ecto.Changeset.traverse_errors(c, fn e -> e end) end)
    def d20c(c), do: Repo.transaction(fn -> Ecto.Changeset.update_change(c, :x, fn v -> v end) end)
    def d20d(c), do: Repo.transaction(fn -> Ecto.Changeset.validate_change(c, :x, fn _f, _v -> [] end) end)
    def d20e(c), do: Repo.transaction(fn -> Ecto.Changeset.validate_change(c, :x, :m, fn _f, _v -> [] end) end)
    def d20f(l), do: Repo.transaction(fn -> MapSet.new(l, fn v -> v end) end)
    def d20g(l), do: Repo.transaction(fn -> Enum.map_join(l, fn v -> v end) end)

    def d21a, do: Repo.transaction(&Lib.run/0)
    def d21b, do: Multi.new() |> Multi.run(:k, &Lib.step/2) |> Repo.transaction()
    def d21c, do: Multi.new() |> Multi.run(:k, Lib, :step, []) |> Repo.transaction()
    def d21d, do: Multi.new() |> Multi.run(:k, __MODULE__, :own_step, []) |> Repo.transaction()
    def own_step(_repo, _changes), do: {:ok, 1}
    def d22, do: Repo.transaction(fn -> Lib.tx(fn -> Repo.insert(%S{}) end) end)
    def d23(l, f), do: Repo.transaction(fn -> Enum.map(l, f) end)
    def d24(l), do: Repo.transaction(fn -> Enum.map(l, &Lib.only_here/1) end)

    def d25a(x) do
      Repo.transaction(&Lib.run/0)
      Keyword.put(x, :f, &Lib.run/0)
    end

    def d25b do
      f = &Lib.run/0
      Repo.transaction(f)
      f.()
    end

    def d19, do: Repo.transaction(fn -> #{inspect(@macros)}."MACRO-m"(__ENV__, 1) end)

    def d30a do
      f = fn -> Repo.insert(%S{}) end
      f.()
      Repo.transaction(f)
    end

    def d30b do
      f = fn _repo, _changes -> Repo.insert(%S{}) end
      f.(Repo, %{})
      Multi.new() |> Multi.run(:a, f) |> Repo.transaction()
    end

    def d30c(l) do
      f = fn _x -> Repo.insert(%S{}) end
      Enum.map(l, f)
      Repo.transaction(fn -> f.(1) end)
    end

    def d30d(l) do
      f = fn _x -> Repo.insert(%S{}) end
      Enum.map(l, f)
      f.(1)
    end

    def d30e do
      Repo.transaction(fn ->
        f = fn -> Repo.insert(%S{}) end
        f.()
      end)
    end

    def d30f do
      f = fn -> Repo.insert(%S{}) end
      Repo.transaction(f)
    end

    def d30g do
      f = fn -> Repo.insert(%S{}) end
      Repo.transaction(fn -> f.() end)
    end
  end
  """

  setup_all do
    source = schema(@s, "s") <> repo(@repo) <> @source
    graph = graph!(source)

    config = %Config{
      repos: [@repo],
      no_write_modules: [@listed],
      write_functions: [ok!(FunctionRef.parse("#{inspect(@lib)}.soft_delete/1"))],
      transaction_functions: [
        ok!(FunctionRef.parse("#{inspect(@uow)}.transaction/2")),
        ok!(FunctionRef.parse("#{inspect(@uow)}.outer/1")),
        ok!(FunctionRef.parse("#{inspect(@uow)}.pass_on/2")),
        ok!(FunctionRef.parse("#{inspect(@lib)}.tx/1"))
      ]
    }

    %{
      analysis: Analysis.build(graph, config),
      source: source,
      graph: graph,
      config: config
    }
  end

  defp ok!({:ok, value}), do: value

  defp one(analysis, name) do
    [scope] = Enum.filter(analysis.scopes, &(elem(&1.mfa, 1) == name))
    scope
  end

  defp nontx(analysis, name, arity), do: Map.fetch!(analysis.nontx, {@d, name, arity})

  defp whats(gaps), do: for({:unread, _mfa, _line, what} <- gaps, do: what)

  defp lib_call(name), do: "unread: call of #{inspect(@lib)}.#{name}"

  describe "a call the walker does not read" do
    test "row 4: an unlisted dependency call is a gap at its line, naming it; the scope is incomplete",
         %{analysis: a, source: source} do
      line = BeamFixtures.line_of(source, "def d4(")

      assert %Scope{
               no_gap_noticed?: false,
               gaps: [{:unread, {@d, :d4, 1}, ^line, what}]
             } = one(a, :d4)

      assert what == lib_call("save/1")
    end

    test "row 5: a call on the no-write list is no gap", %{analysis: a} do
      assert %Scope{no_gap_noticed?: true, gaps: []} = one(a, :d5)
    end

    test "row 5: every cleared call is counted, none from a form read another way", %{
      graph: graph,
      config: config
    } do
      facts = WriteSites.facts(graph, config, WriteSites.repos(graph, config))

      assert facts.functions[{@d, :d5, 1}].cleared == 1
      assert facts.functions[{@d, :d11a, 0}].cleared == 0
      assert facts.functions[{@d, :d11e, 1}].cleared == 0
      assert facts.functions[{@d, :d4, 1}].cleared == 0
    end

    test "row 6: GenServer.call/2 is a gap", %{analysis: a} do
      assert whats(one(a, :d6).gaps) == ["unread: call of GenServer.call/2"]
    end

    test "row 7: an apply of unknown values and a call of a parameter are gaps", %{analysis: a} do
      assert %Scope{no_gap_noticed?: false, gaps: [{:dynamic_call, {@d, :d7a, 3}, _}]} =
               one(a, :d7a)

      assert %Scope{no_gap_noticed?: false, gaps: [{:dynamic_call, {@d, :d7b, 1}, _}]} =
               one(a, :d7b)
    end

    test "row 8: a function given to a listed module where HigherOrder names no place is a gap",
         %{analysis: a} do
      assert whats(one(a, :d8a).gaps) == ["unread: a function handed to Keyword.put/3"]
      assert whats(one(a, :d8b).gaps) == ["unread: a function handed to Keyword.put/3"]

      assert whats(one(a, :d8c).gaps) ==
               ["unread: a function handed to #{inspect(@listed)}.run/1"]

      assert whats(one(a, :d8g).gaps) ==
               ["unread: a function handed to Ecto.Changeset.prepare_changes/2"]
    end

    test "row 8: positive controls: data to a listed module, a function HigherOrder names", %{
      analysis: a
    } do
      assert %Scope{no_gap_noticed?: true} = one(a, :d8d)
      assert %Scope{no_gap_noticed?: true} = one(a, :d8e)
      assert %Scope{no_gap_noticed?: true} = one(a, :d8f)
    end

    test "row 9: reached through two project calls, a gap on the scope that reaches it only", %{
      analysis: a
    } do
      assert [{:unread, {@d, :second, 0}, _line, what}] = one(a, :d9).gaps
      assert what == lib_call("save/1")
      assert %Scope{no_gap_noticed?: true} = one(a, :d9_clean)
    end

    test "row 10: with no transaction, a gap on the root's nontx and on no scope", %{analysis: a} do
      for {name, arity} <- [d10: 1, d10_caller: 1] do
        assert [{:unread, {@d, :d10, 1}, _line, what}] = nontx(a, name, arity).gaps
        assert what == lib_call("save/1")
        refute nontx(a, name, arity).no_gap_noticed?
      end

      refute Enum.any?(a.scopes, &(&1.mfa == {@d, :d10, 1}))
      assert nontx(a, :d10_clean, 1).gaps == []
    end

    test "a function run in another process is a gap with no transaction around it too", %{
      analysis: a
    } do
      assert [{:dynamic_call, {@d, :d18, 0}, _line}] = nontx(a, :d18, 0).gaps
      assert whats(nontx(a, :d17, 1).gaps) == ["unread: call of GenServer.call/2"]
    end

    test "the counts hold the cleared calls and the unread ones by callee", %{analysis: a} do
      assert a.counts.cleared >= 1
      assert a.counts.unread_by_callee["unread: call of GenServer.call/2"] == 2
      assert a.counts.unread_by_callee[lib_call("save/1")] == 4
    end
  end

  describe "a function value, or data, that needs no following" do
    for name <- [:d20a, :d20h, :d20i, :d20j, :d20b, :d20c, :d20d, :d20e, :d20f, :d20g] do
      @tag name: name
      test "#{name}: no gap", %{analysis: a, name: name} do
        assert %Scope{no_gap_noticed?: true, gaps: []} = one(a, name)
      end
    end
  end

  describe "a project function the analysis does not walk" do
    test "a macro's own function is a gap, never a call to nowhere", %{analysis: a} do
      assert whats(one(a, :d19).gaps) == ["unread: call of #{inspect(@macros)}.MACRO-m/2"]
    end
  end

  describe "the forms DND-5459 reads stay" do
    test "row 11: a repo write, a Multi step, a listed write function, raw SQL: sites as before",
         %{analysis: a} do
      sites = fn name -> Enum.filter(a.sites, &(elem(&1.mfa, 1) == name)) end

      assert [%{op: :insert, via: :repo}] = sites.(:d11a)
      assert [%{op: :insert, via: :multi}] = sites.(:d11b)
      assert [%{op: :soft_delete, via: :write_function}] = sites.(:d11c)

      for name <- [:d11a, :d11b, :d11c, :d11e] do
        assert %Scope{no_gap_noticed?: true, gaps: []} = one(a, name)
      end

      assert [{:dynamic_call, {@d, :d11d, 0}, _line}] = one(a, :d11d).gaps
    end

    test "the rest of Ecto.Multi reads; a name it does not know is a gap", %{analysis: a} do
      assert whats(one(a, :d15).gaps) == ["unread: call of Ecto.Multi.not_a_function/1"]
      assert whats(one(a, :d15b).gaps) == ["unread: a function handed to Ecto.Multi.put/3"]
      assert %Scope{no_gap_noticed?: true} = one(a, :d15c)
    end

    test "a fn applied where it is written is read, inside a body or not", %{analysis: a} do
      assert %Scope{no_gap_noticed?: true, keys: keys} = one(a, :d16)
      assert keys == MapSet.new([{:schema, @s}])
      assert nontx(a, :d16b, 0).keys == MapSet.new([{:schema, @s}])
    end
  end

  describe "a capture" do
    test "of an unlisted dependency is a gap; of a listed function it is cleared", %{analysis: a} do
      assert whats(one(a, :d12a).gaps) == [
               lib_call("save/1") |> String.replace("call of", "capture of")
             ]

      assert %Scope{no_gap_noticed?: true} = one(a, :d12b)
    end

    test "of a listed function that runs its argument is a gap", %{analysis: a} do
      assert whats(one(a, :d12c).gaps) == ["unread: capture of Enum.map/2"]
    end

    test "of an Ecto.Multi step or a generated repo function is a gap", %{analysis: a} do
      assert whats(one(a, :d12d).gaps) == ["unread: capture of Ecto.Multi.insert/3"]
      assert whats(one(a, :d12e).gaps) == ["unread: capture of #{inspect(@repo)}.all/1"]
    end
  end

  describe "a dependency's function a transaction or a Multi runs" do
    test "a capture of one as the transaction's body is a gap of that transaction", %{analysis: a} do
      assert whats(one(a, :d21a).gaps) == [
               String.replace(lib_call("run/0"), "call of", "capture of")
             ]

      assert nontx(a, :d21a, 0).gaps == []
    end

    test "a second capture of it beside the body does not take the gap off the transaction", %{
      analysis: a
    } do
      capture = String.replace(lib_call("run/0"), "call of", "capture of")

      for {name, arity} <- [d25a: 1, d25b: 0] do
        assert capture in whats(one(a, name).gaps)
        assert capture in whats(nontx(a, name, arity).gaps)
      end
    end

    test "a capture of one as a Multi.run callback is a gap of that transaction", %{analysis: a} do
      assert whats(one(a, :d21b).gaps) == [
               String.replace(lib_call("step/2"), "call of", "capture of")
             ]
    end

    test "Multi.run/5 on one is a gap of that transaction", %{analysis: a} do
      assert whats(one(a, :d21c).gaps) == [
               String.replace(lib_call("step/2"), "call of", "capture of")
             ]
    end

    test "positive control: Multi.run/5 on a project function is no gap", %{analysis: a} do
      assert %Scope{no_gap_noticed?: true, gaps: []} = one(a, :d21d)
    end

    test "a dependency's listed transaction function is read as a scope, never unread", %{
      analysis: a,
      graph: graph,
      config: config
    } do
      scopes = Enum.filter(a.scopes, &(elem(&1.mfa, 1) == :d22))
      assert length(scopes) == 2
      assert Enum.all?(scopes, &(&1.gaps == []))
      facts = WriteSites.facts(graph, config, WriteSites.repos(graph, config))
      assert facts.functions[{@d, :d22, 0}].dynamic == []
    end
  end

  describe "exactly one outcome per call" do
    test "an unknown function handed to a listed function is a gap, and is not also cleared", %{
      graph: graph,
      config: config
    } do
      facts = WriteSites.facts(graph, config, WriteSites.repos(graph, config))
      assert %{cleared: 0, dynamic: [_gap]} = facts.functions[{@d, :d23, 2}]
    end

    test "a capture read twice at one line counts once in unread_by_callee", %{analysis: a} do
      assert a.counts.unread_by_callee[
               String.replace(lib_call("only_here/1"), "call of", "capture of")
             ] == 1
    end
  end

  describe "an apply with a literal module and name" do
    test "of an unlisted dependency is a gap", %{analysis: a} do
      assert whats(one(a, :d13a).gaps) == [lib_call("save/1")]
    end

    test "of a listed function with arguments is a gap: Anchor has no argument nodes", %{
      analysis: a
    } do
      assert whats(one(a, :d13b).gaps) == ["unread: a function handed to Map.put/3"]
    end

    test "of a listed function with no arguments is cleared", %{analysis: a} do
      assert %Scope{no_gap_noticed?: true} = one(a, :d13c)
    end
  end

  describe "a fn run where the walk did not read it" do
    test "row 13: called and passed to a transaction is a gap at the call", %{analysis: a} do
      assert %Scope{no_gap_noticed?: true} = one(a, :d30a)
      assert [{:dynamic_call, {@d, :d30a, 0}, _line}] = nontx(a, :d30a, 0).gaps
    end

    test "row 13: called and given to Multi.run is a gap at the call", %{analysis: a} do
      assert [{:dynamic_call, {@d, :d30b, 0}, _line}] = nontx(a, :d30b, 0).gaps
    end

    test "run in a transaction it is not given to is a gap there", %{analysis: a} do
      assert %Scope{no_gap_noticed?: false} = one(a, :d30c)
      assert %Scope{no_gap_noticed?: false} = one(a, :d30g)
    end

    test "positive: run where it is defined, in or out of a body, is no gap", %{analysis: a} do
      assert %Scope{no_gap_noticed?: true, gaps: []} = one(a, :d30e)
      assert nontx(a, :d30d, 1).gaps == []
    end

    test "positive: only given to the transaction is no gap", %{analysis: a} do
      assert %Scope{no_gap_noticed?: true, gaps: []} = one(a, :d30f)
      assert nontx(a, :d30f, 0).gaps == []
    end
  end

  describe "a transaction_functions call" do
    test "row 14: one argument traced and one not is a gap", %{analysis: a} do
      assert %Scope{no_gap_noticed?: false, gaps: [{:dynamic_call, {@d, :d14a, 1}, _}]} =
               one(a, :d14a)
    end

    test "row 14: positive control: the other argument a literal is no gap", %{analysis: a} do
      assert %Scope{no_gap_noticed?: true, keys: keys} = one(a, :d14b)
      assert keys == MapSet.new([{:schema, @s}])
    end

    test "inside a listed wrapper, a body it reads stays read, with the gap beside it", %{
      analysis: a
    } do
      assert %Scope{no_gap_noticed?: false, keys: keys, gaps: [{:dynamic_call, _, _}]} =
               one(a, :outer)

      assert keys == MapSet.new([{:schema, @s}])
    end

    test "inside a listed wrapper, its own parameter opens nothing", %{analysis: a} do
      assert Enum.filter(a.scopes, &(elem(&1.mfa, 1) == :pass_on)) == []
    end
  end
end
