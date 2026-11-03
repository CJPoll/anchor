defmodule Anchor.Domain.Aggregates.NonTransactionalTest do
  # DND-5459: writes outside every transaction, per function with its
  # callees', and the functions only ever called inside a transaction.
  #
  # Sabotage record: ../../../sabotage_records/aggregates-20261103-dnd_5459_write_sets.md
  # Sabotage record: ../../../sabotage_records/aggregates-20261103-dnd_5659_aggregates_none.md (DND-5659)
  use ExUnit.Case, async: true

  import Anchor.Test.WriteFixtures

  alias Anchor.Domain.Aggregates.Analysis
  alias Anchor.Domain.Aggregates.Config

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

  test "N4: recursion terminates at the fixpoint", %{analysis: a} do
    assert nontx(a, :n4a, 1).keys == keys([@s, @t])
    assert nontx(a, :n4b, 1).keys == keys([@s, @t])
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
