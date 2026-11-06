defmodule Anchor.Domain.Aggregates.NonTransactionalTest do
  # DND-5459: writes outside every transaction, per function with its
  # callees', and the functions only ever called inside a transaction.
  #
  # Sabotage record: ../../../sabotage_records/aggregates-20261103-dnd_5459_write_sets.md
  # and ../../../sabotage_records/aggregates-20261106-dnd_5459_write_sets.md
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

              def n29, do: Repo.transaction(fn -> n29a() end)
              defp n29a, do: n29b()
              defp n29b, do: Repo.insert(%S{})

              def n27(0), do: :ok
              def n27(n), do: (Repo.query!("DELETE FROM s"); n27(n - 1))

              def n28, do: Ecto.Multi.run(Ecto.Multi.new(), :a, __MODULE__, :n28_step, [])
              def n28_step(repo, _changes), do: repo.query!("DELETE FROM s")
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
    assert nontx(a, :n1f).complete?
  end

  test "N2: a callee called only inside a transaction adds nothing and is always in one", %{
    analysis: a
  } do
    assert nontx(a, :n2f).keys == MapSet.new()
    assert MapSet.member?(a.always_in_transaction, {@n, :n2g, 0})
  end

  test "N3: a callee also called outside is not always in one; the outside caller has its keys",
       %{analysis: a} do
    refute MapSet.member?(a.always_in_transaction, {@n, :n3g, 0})
    assert nontx(a, :n3h).keys == keys([@t])
    assert nontx(a, :n3f).keys == MapSet.new()
  end

  test "a recursive function nothing calls in a transaction is not always in one", %{
    analysis: a
  } do
    refute MapSet.member?(a.always_in_transaction, {@n, :n4a, 1})
    refute MapSet.member?(a.always_in_transaction, {@n, :n4b, 1})
    refute MapSet.member?(a.always_in_transaction, {@n, :n27, 1})
  end

  test "a function reached only through one always in a transaction is too", %{analysis: a} do
    assert MapSet.member?(a.always_in_transaction, {@n, :n29a, 0})
    assert MapSet.member?(a.always_in_transaction, {@n, :n29b, 0})
  end

  test "a Multi.run callback given by module and name is always in a transaction", %{
    analysis: a
  } do
    assert MapSet.member?(a.always_in_transaction, {@n, :n28_step, 2})
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
    assert MapSet.member?(a.always_in_transaction, {@n, :n7_step, 2})
  end

  test "a write directly in a transaction body is never non-transactional", %{analysis: a} do
    assert nontx(a, :n8).keys == MapSet.new()
  end

  test "a write_functions write outside a transaction is non-transactional; inside it is not" do
    {:ok, soft_delete} = FunctionRef.parse("#{inspect(@repo)}.soft_delete/2")
    config = %Config{repos: [@repo], write_functions: [soft_delete]}
    analysis = Analysis.build(graph!(@source), config)

    assert nontx(analysis, :n9).keys == keys([@s])
    assert nontx(analysis, :n10).keys == MapSet.new()
  end

  test "unattributed: raw SQL and a write on a computed module, outside a transaction", %{
    analysis: a
  } do
    assert [
             %{mfa: {@n, :n11, 0}, what: raw, line: line},
             %{mfa: {@n, :n12, 1}, what: computed},
             %{mfa: {@n, :n22, 1}, what: captured},
             %{mfa: {@n, :n23, 1}, what: computed_capture},
             %{mfa: {@n, :n27, 1}}
           ] = a.unattributed

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
    assert MapSet.member?(a.always_in_transaction, {@n, :n20g, 0})
    assert MapSet.member?(a.always_in_transaction, {@n, :n21g, 0})
  end

  test "the gaps outside every transaction are counted", %{analysis: a} do
    gaps =
      a.nontx
      |> Enum.reject(fn {mfa, _entry} -> MapSet.member?(a.always_in_transaction, mfa) end)
      |> Enum.flat_map(fn {_mfa, entry} -> entry.gaps end)
      |> Enum.uniq()

    refute Enum.any?(gaps, &match?({:dynamic_call, {@n, :n17h, 0}, _line}, &1))
    refute Enum.any?(gaps, &match?({:dynamic_call, {@n, :n26, 0}, _line}, &1))
    refute Enum.any?(gaps, &match?({:dynamic_call, {@n, :n25, 2}, _line}, &1))

    assert a.counts.outside_gaps == length(gaps)
    assert Enum.any?(gaps, &match?({:dynamic_call, {@n, :n13, 1}, _line}, &1))
    assert Enum.any?(gaps, &match?({:dynamic_call, {@n, :n11, 0}, _line}, &1))
    refute Enum.any?(gaps, &match?({:dynamic_call, {@n, :n14, 0}, _line}, &1))
  end

  test "a Multi step is never a non-transactional write", %{analysis: a} do
    assert nontx(a, :n5).keys == MapSet.new()
  end

  test "roots: a given root is never always in a transaction" do
    root = MapSet.new([{@n, :n2g, 0}])
    analysis = Analysis.build(graph!(@source), %Config{repos: [@repo]}, roots: root)
    refute MapSet.member?(analysis.always_in_transaction, {@n, :n2g, 0})
  end

  test "roots: through Model.build, a framework bucket's public function is a root" do
    fw = Module.concat(@ns, Web)

    source =
      @source <>
        """
        defmodule #{inspect(fw)} do
          def entry, do: #{inspect(@repo)}.insert(%#{inspect(@s)}{})
        end

        defmodule #{inspect(Module.concat(@ns, Caller))} do
          def run, do: #{inspect(@repo)}.transaction(fn -> #{inspect(fw)}.entry() end)
        end
        """

    graph = graph!(source, "lib/fixture.ex")

    config =
      Anchor.Config.parse_config(%{
        "rules" => [],
        "aggregates" => %{"repos" => [inspect(@repo)]},
        "architecture" => %{
          "contexts" => %{"depth" => 2},
          "buckets" => [
            %{"name" => "web", "role" => "framework", "select" => [%{"pattern" => inspect(fw)}]},
            %{
              "name" => "rest",
              "role" => "domain",
              "select" => [%{"pattern" => "#{inspect(@ns)}.N"}]
            }
          ],
          "calls" => %{"web" => ["web", "rest"], "rest" => ["rest", "web"]}
        }
      })

    assert {%Anchor.Domain.Model{aggregate_analysis: analysis}, _issues} =
             Anchor.Domain.Model.build(graph, config, %{})

    refute MapSet.member?(analysis.always_in_transaction, {fw, :entry, 0})
    assert MapSet.member?(analysis.always_in_transaction, {@n, :n2g, 0})
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

    assert {%Anchor.Domain.Model{aggregate_analysis: nil, aggregates: index}, _issues} =
             Anchor.Domain.Model.build(graph, config, %{})

    assert index.none == "no database"
  end
end
