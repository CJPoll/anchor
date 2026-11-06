defmodule Anchor.Domain.Aggregates.NonTransactionalTest do
  # DND-5459: writes with no transaction read around them, per function with its
  # callees', and the functions only ever called inside a transaction.
  #
  # Sabotage record: ../../../sabotage_records/aggregates-20261103-dnd_5459_write_sets.md
  # and ../../../sabotage_records/aggregates-20261106-dnd_5459_write_sets.md
  # Sabotage record: ../../../sabotage_records/aggregates-20261106-dnd_5889_default_deny_walker.md
  use ExUnit.Case, async: true

  import Anchor.Test.WriteFixtures

  alias Anchor.Domain.Aggregates.Analysis
  alias Anchor.Domain.Aggregates.Config
  alias Anchor.Domain.FunctionRef

  @ns AnchorFixtures.NonTransactionalTest
  @s Module.concat(@ns, S)
  @t Module.concat(@ns, T)
  @repo Module.concat(@ns, Repo)
  @n Module.concat(@ns, N)

  @source schema(@s, "s") <>
            schema(@t, "t") <>
            repo(@repo) <>
            """
            defmodule #{inspect(@n)} do
              alias #{inspect(@repo)}
              alias #{inspect(@s)}
              alias #{inspect(@t)}

              def n1f, do: (Repo.insert(%S{}); n1g())
              def n1g, do: Repo.insert(%T{})

              def n2f, do: Repo.transaction(fn -> n2g() end)
              defp n2g, do: Repo.insert(%S{})

              def n3f, do: Repo.transaction(fn -> n3g() end)
              def n3h, do: n3g()
              defp n3g, do: Repo.insert(%T{})

              def n4a(0), do: Repo.insert(%S{})
              def n4a(n), do: n4b(n - 1)
              defp n4b(n), do: (Repo.insert(%T{}); n4a(n))

              def n5, do: Ecto.Multi.insert(Ecto.Multi.new(), :a, %S{})

              # A Multi built in a helper, its run callback writing on the
              # literal repo: inline, and as a capture.
              def n6, do: Ecto.Multi.run(Ecto.Multi.new(), :a, fn _r, _c -> Repo.insert(%S{}) end)
              def n7, do: Ecto.Multi.run(Ecto.Multi.new(), :a, &n7_step/2)
              def n7_step(_repo, _changes), do: Repo.insert(%T{})

              def n8, do: Repo.transaction(fn -> Repo.insert(%S{}) end)

              def n11, do: Repo.query!("DELETE FROM s")
              def n12(mod), do: mod.insert(%S{})
              def n13(mod), do: mod.get(S, 1)
              def n14, do: Repo.transaction(fn -> Repo.query!("DELETE FROM s") end)
              def n15(mod), do: Repo.transaction(fn -> mod.insert(%S{}) end)
              def n16, do: n11()


              def n30(fun), do: Repo.transaction(fun)
              def n56(args), do: apply(#{inspect(Module.concat(@ns, Store2))}, :soft_it, args)
              def n50(args), do: apply(Ecto.Adapters.SQL, :query!, args)
              def n51(mod, x), do: mod.soft_delete(x, [])
              def n52(args), do: apply(Repo, :soft_delete, args)
              def n53(name, args), do: apply(Ecto.Adapters.SQL, name, args)
              def n54(mod, args), do: apply(mod, :soft_delete, args)
              def n55(name, args), do: apply(Repo, name, args)


              def n47, do: Repo.insert(%#{inspect(@s)}{})

              def n47_run do
                Repo.transaction(&n47/0)
                Task.start(&n47/0)
              end

              def n48, do: Repo.query!("DELETE FROM s")

              def n48_run do
                Repo.transaction(&n48/0)
                Repo.transaction(&n48/0)
              end
              def n35(mod, fun), do: mod.transaction(fun)
              def n36(args), do: apply(Repo, :insert, args)
              def n37(mod, name, args), do: apply(mod, name, args)
              def n38(mod, args), do: apply(mod, :query!, args)
              def n39(name, args), do: apply(Repo, name, args)
              def n40(args), do: apply(String, :upcase, args)
              def n41(name, args), do: apply(String, name, args)
              def n42(mod, args), do: apply(mod, :upcase, args)
              def n43(args), do: apply(Repo, :get, args)
              def n31(sqls), do: Enum.each(sqls, &Repo.query!/1)
              def n32(mod), do: mod.query!("DELETE FROM s")
              def n33(sqls), do: Enum.each(sqls, &Ecto.Adapters.SQL.query!/1)
              def n34(mod, sqls), do: Enum.each(sqls, &mod.query!/1)

              def n27(0), do: :ok
              def n27(n), do: (Repo.query!("DELETE FROM s"); n27(n - 1))

              def n26, do: Task.async(fn -> Repo.get(S, 1) end)
              def n25(m, f), do: Ecto.Multi.merge(m, f)

              def n22(xs), do: Enum.each(xs, &Repo.insert/1)
              def n23(mod), do: Enum.map([1], &mod.insert/1)
              def n24(mod), do: Enum.map([1], &mod.get/1)

              def n20, do: Repo.transaction(&n20g/0)
              def n20g, do: Repo.insert(%S{})

              def n21, do: Repo.transaction(&n21g/0)
              def n21g, do: Repo.query!("DELETE FROM s")

              def n17, do: Repo.transaction(fn -> n17h() end)
              defp n17h, do: Repo.query!("DELETE FROM s")

              def n18, do: Ecto.Multi.run(Ecto.Multi.new(), :a, &n18_step/2)
              def n18_step(repo, _changes), do: repo.query!("DELETE FROM s")

              def n19, do: Ecto.Multi.run(Ecto.Multi.new(), :a, &n19_step/2)
              def n19_step(_repo, _changes), do: Repo.insert(%S{})
              def n19_direct, do: n19_step(nil, nil)

              def n9, do: Repo.soft_delete(%S{}, [])
              def n10, do: Repo.transaction(fn -> Repo.soft_delete(%S{}, []) end)
            end
            """

  setup_all do
    %{analysis: Analysis.build(graph!(@source), %Config{repos: [@repo]})}
  end

  defp keys(modules), do: MapSet.new(modules, &{:schema, &1})
  defp nontx(a, name, arity \\ 0), do: Map.fetch!(a.nontx, {@n, name, arity})

  test "N1: a function's own writes and its callees' outside a transaction", %{analysis: a} do
    assert nontx(a, :n1f).keys == keys([@s, @t])
    assert nontx(a, :n1g).keys == keys([@t])
    assert nontx(a, :n1f).no_gap_noticed?
  end

  test "N2: a callee called only inside a transaction adds nothing to its caller's entry", %{
    analysis: a
  } do
    assert nontx(a, :n2f).keys == MapSet.new()
  end

  test "N3: a callee also called outside: the outside caller has its keys",
       %{analysis: a} do
    assert nontx(a, :n3h).keys == keys([@t])
    assert nontx(a, :n3f).keys == MapSet.new()
  end

  test "a capture beside a body capture of one function is outside the transaction", %{
    analysis: a
  } do
    assert nontx(a, :n47_run).keys == keys([@s])
    assert [%{keys: body_keys}] = Enum.filter(a.scopes, &(&1.mfa == {@n, :n47_run, 0}))
    assert body_keys == keys([@s])
  end

  test "every capture of a function a body: its caller's entry holds none of it", %{analysis: a} do
    assert nontx(a, :n48_run).keys == MapSet.new()
  end

  test "an unread transaction is no gap outside a transaction", %{analysis: a} do
    assert %{no_gap_noticed?: true} = nontx(a, :n30, 1)
  end

  test "N4: recursion terminates at the fixpoint", %{analysis: a} do
    assert nontx(a, :n4a, 1).keys == keys([@s, @t])
    assert nontx(a, :n4b, 1).keys == keys([@s, @t])
  end

  test "N5: a literal-repo write in an inline Multi.run callback is never non-transactional", %{
    analysis: a
  } do
    assert nontx(a, :n6).keys == MapSet.new()
  end

  test "N5: a captured Multi.run callback's writes are never non-transactional to the builder",
       %{analysis: a} do
    assert nontx(a, :n7).keys == MapSet.new()
  end

  test "a write directly in a transaction body is never non-transactional", %{analysis: a} do
    assert nontx(a, :n8).keys == MapSet.new()
  end

  test "a write_functions write outside a transaction is non-transactional; inside it is not" do
    {:ok, soft_delete} = FunctionRef.parse("#{inspect(@repo)}.soft_delete/2")
    {:ok, soft_it} = FunctionRef.parse("#{inspect(Module.concat(@ns, Store2))}.soft_it/1")
    config = %Config{repos: [@repo], write_functions: [soft_delete, soft_it]}
    analysis = Analysis.build(graph!(@source), config)

    assert nontx(analysis, :n9).keys == keys([@s])
    assert nontx(analysis, :n10).keys == MapSet.new()

    reported = MapSet.new(analysis.unattributed, & &1.mfa)
    assert MapSet.member?(reported, {@n, :n51, 2})
    assert MapSet.member?(reported, {@n, :n52, 1})
    assert MapSet.member?(reported, {@n, :n54, 2})
    assert MapSet.member?(reported, {@n, :n56, 1})
  end

  test "an apply of a computed name reaches every function of the module it names" do
    store = Module.concat(@ns, Store)

    source =
      @source <>
        """
        defmodule #{inspect(store)} do
          alias #{inspect(@repo)}
          def save(x), do: Repo.insert(x)
          def known, do: Repo.transaction(fn -> save(%#{inspect(@s)}{}) end)
          def named(name), do: apply(__MODULE__, name, [%#{inspect(@t)}{}])
        end
        """

    analysis = Analysis.build(graph!(source), %Config{repos: [@repo]})

    assert [%{unresolved: seen}] = Enum.filter(analysis.sites, &(&1.mfa == {store, :save, 1}))
    assert seen =~ "callers are not known"
  end

  test "unattributed: raw SQL and a write on a computed module, outside a transaction", %{
    analysis: a
  } do
    assert [
             %{mfa: {@n, :n11, 0}, what: raw, line: line},
             %{mfa: {@n, :n12, 1}, what: computed},
             %{mfa: {@n, :n17h, 0}},
             %{mfa: {@n, :n21g, 0}},
             %{mfa: {@n, :n22, 1}, what: captured},
             %{mfa: {@n, :n23, 1}, what: computed_capture},
             %{mfa: {@n, :n27, 1}},
             %{mfa: {@n, :n31, 1}, what: raw_capture},
             %{mfa: {@n, :n32, 1}, what: computed_raw},
             %{mfa: {@n, :n33, 1}},
             %{mfa: {@n, :n34, 2}, what: "a capture on a computed module or name"},
             %{mfa: {@n, :n35, 2}, what: computed_transaction},
             %{mfa: {@n, :n36, 1}, what: unread_apply},
             %{mfa: {@n, :n37, 3}},
             %{mfa: {@n, :n38, 2}},
             %{mfa: {@n, :n39, 2}},
             %{mfa: {@n, :n48, 0}},
             %{mfa: {@n, :n50, 1}},
             %{mfa: {@n, :n53, 2}},
             %{mfa: {@n, :n55, 2}}
           ] = a.unattributed

    assert computed_transaction == "a call of transaction/1 on a module held in a variable"
    assert unread_apply == "an apply/3 Anchor cannot resolve"

    assert raw_capture == "a capture of the write #{inspect(@repo)}.query!/1"
    assert computed_raw == "a call of query!/1 on a module held in a variable"

    assert captured == "a capture of the write #{inspect(@repo)}.insert/1"
    assert computed_capture == "a capture on a computed module or name"

    assert raw == "raw SQL (#{inspect(@repo)}.query!/1) Anchor cannot attribute"
    assert computed == "a call of insert/1 on a module held in a variable"
    assert is_integer(line)
  end

  test "a captured run callback's own entry is empty; a direct caller still has its writes",
       %{analysis: a} do
    assert nontx(a, :n7_step, 2).keys == MapSet.new()
    assert nontx(a, :n19_direct).keys == keys([@s])
  end

  test "a function written on a repo is read; what Ecto generates on it is not" do
    sql_repo = Module.concat(@ns, SqlRepo)

    source =
      @source <>
        """
        defmodule #{inspect(sql_repo)} do
          def query!(sql), do: Ecto.Adapters.SQL.query!(__MODULE__, sql, [])
          def get(mod, id), do: mod.lookup(id)
          def insert(x, opts \\\\ []), do: insert_all(x, opts)
          def insert_all(x, _opts), do: x
          def purge, do: query!("DELETE FROM s")
        end
        """

    config = %Config{repos: [@repo, sql_repo]}
    analysis = Analysis.build(graph!(source), config)

    assert [%{mfa: {^sql_repo, :purge, 0}}] =
             Enum.filter(analysis.unattributed, &(elem(&1.mfa, 0) == sql_repo))

    refute Map.has_key?(analysis.nontx, {sql_repo, :get, 2})
    refute Map.has_key?(analysis.nontx, {sql_repo, :query!, 1})
    refute Map.has_key?(analysis.nontx, {sql_repo, :insert, 1})
    assert Map.has_key?(analysis.nontx, {sql_repo, :purge, 0})
  end

  test "a function captured as a transaction's body is inside it", %{analysis: a} do
    assert nontx(a, :n20).keys == MapSet.new()
  end

  test "the gaps with no transaction read around them are counted", %{analysis: a} do
    gaps =
      a.nontx
      |> Enum.flat_map(fn {_mfa, entry} -> entry.gaps end)
      |> Enum.uniq()

    # n17h is only called in a transaction, but its own function reads none around it.
    assert Enum.any?(gaps, &match?({:dynamic_call, {@n, :n17h, 0}, _line}, &1))
    # DND-5889: a function run in another process is a gap with no transaction around it too.
    assert Enum.any?(gaps, &match?({:dynamic_call, {@n, :n26, 0}, _line}, &1))
    refute Enum.any?(gaps, &match?({:dynamic_call, {@n, :n25, 2}, _line}, &1))

    assert a.counts.outside_gaps == length(gaps)
    assert Enum.any?(gaps, &match?({:dynamic_call, {@n, :n13, 1}, _line}, &1))
    assert Enum.any?(gaps, &match?({:dynamic_call, {@n, :n11, 0}, _line}, &1))
    refute Enum.any?(gaps, &match?({:dynamic_call, {@n, :n14, 0}, _line}, &1))
  end

  test "a Multi step is never a non-transactional write", %{analysis: a} do
    assert nontx(a, :n5).keys == MapSet.new()
  end

  test "Z5: under declare: none the Model builds no write analysis, and the index keeps none" do
    graph = graph!("defmodule #{inspect(@n)} do\n  def f, do: :ok\nend\n", "lib/fixture.ex")

    config =
      Anchor.Config.parse_config(%{
        "rules" => [],
        "aggregates" => %{"declare" => "none", "reason" => "no database"},
        "architecture" => %{
          "contexts" => %{"depth" => 2},
          "buckets" => [
            %{"name" => "rest", "role" => "domain", "select" => [%{"pattern" => inspect(@ns)}]}
          ],
          "calls" => %{"rest" => ["rest"]}
        }
      })

    assert {%Anchor.Domain.Model{aggregates: index} = model, _issues} =
             Anchor.Domain.Model.build(graph, config, %{})

    assert Anchor.Domain.Model.aggregate_analysis(model) == nil
    assert index.none == "no database"
  end
end
