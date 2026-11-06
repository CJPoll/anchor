defmodule Anchor.Domain.ParityTest do
  # DND-5491: the AST/graph parity comparison. Pure Domain, on hand-built
  # architectures and violations; the two engines over the fixture tree are
  # test/anchor/integration/layering_parity_test.exs.
  #
  # Sabotage record: ../../sabotage_records/parity-20261103-dnd_5648_graph_followups.md
  use ExUnit.Case, async: true

  alias Anchor.Domain.Architecture
  alias Anchor.Domain.Parity
  alias Anchor.Domain.Violation

  defp arch(calls, buckets \\ nil) do
    buckets =
      buckets ||
        Enum.map(~w(framework managers adapters domain), fn name ->
          %{"name" => name, "role" => name, "select" => [%{"pattern" => "App.*.#{name}.*"}]}
        end)

    {:ok, arch} =
      Architecture.parse(%{"contexts" => %{"depth" => 2}, "buckets" => buckets, "calls" => calls})

    arch
  end

  defp rule(rules, id), do: Enum.find(rules, &(&1.id == id)) || flunk("no rule #{id}")

  describe "ast_rules_for/1" do
    test "a row forbids, directly and transitively, the buckets it omits" do
      rules =
        Parity.ast_rules_for(
          arch(%{
            "framework" => ~w(framework managers adapters domain),
            "managers" => ~w(managers adapters domain),
            "adapters" => ~w(adapters domain),
            "domain" => ~w(domain)
          })
        )

      domain = rule(rules, "parity:domain:direct")

      assert %{type: :no_direct_dependency, pattern: "App.*.domain.*", same_context: false} =
               domain

      assert Enum.sort(domain.forbidden_patterns) ==
               Enum.sort(~w(App.*.framework.* App.*.managers.* App.*.adapters.*))

      transitive = rule(rules, "parity:domain:transitive")
      assert transitive.type == :no_transitive_dependency
      assert Enum.sort(transitive.forbidden_patterns) == Enum.sort(domain.forbidden_patterns)

      assert rule(rules, "parity:adapters:direct").forbidden_patterns ==
               ~w(App.*.framework.* App.*.managers.*)

      # framework's row lists every bucket: it forbids nothing, so no rule.
      refute Enum.any?(rules, &String.starts_with?(&1.id, "parity:framework:"))
    end

    test "an other_context entry forbids that bucket within the caller's own context" do
      rules =
        Parity.ast_rules_for(
          arch(%{
            "framework" => ~w(framework managers adapters domain),
            "managers" => ~w(managers adapters domain),
            "adapters" => ["adapters", "domain", "managers:other_context"],
            "domain" => ~w(domain)
          })
        )

      assert %{
               type: :no_direct_dependency,
               forbidden_patterns: ["App.*.managers.*"],
               same_context: true,
               context_depth: 2
             } = rule(rules, "parity:adapters:same_context")

      assert rule(rules, "parity:adapters:direct").forbidden_patterns == ["App.*.framework.*"]
      assert rule(rules, "parity:adapters:transitive").forbidden_patterns == ["App.*.framework.*"]
    end

    test "a same_context entry cannot be written as an AST rule: ArgumentError naming it" do
      calls = %{
        "framework" => ~w(framework),
        "managers" => ["managers", "adapters:same_context"],
        "adapters" => ~w(adapters),
        "domain" => ~w(domain)
      }

      assert_raise ArgumentError, ~r/managers.*adapters:same_context/, fn ->
        Parity.ast_rules_for(arch(calls))
      end
    end

    test "a bucket selected by anything but pattern raises, naming it" do
      buckets = [
        %{
          "name" => "web",
          "role" => "framework",
          "select" => [%{"uses_module" => "Phoenix.Router"}]
        },
        %{"name" => "domain", "role" => "domain", "select" => [%{"pattern" => "App.Domain.*"}]}
      ]

      assert_raise ArgumentError, ~r/bucket web selects by uses_module/, fn ->
        Parity.ast_rules_for(arch(%{"web" => ~w(web), "domain" => ~w(domain)}, buckets))
      end
    end
  end

  describe "pairs_from_ast/1 and pairs_from_graph/1" do
    test "an AST finding's caller is its file's module, its callee the trigger" do
      results = [
        {"App.Orders.domain.Order",
         [
           %Violation{
             message: "Module has forbidden direct dependency on App.Orders.adapters.Store",
             trigger: "App.Orders.adapters.Store"
           },
           # A once-per-file report names no callee module.
           %Violation{message: "Anchor cannot statically resolve", trigger: "alias"},
           %Violation{message: "unparseable", trigger: nil, kind: :fail_closed}
         ]}
      ]

      assert Parity.pairs_from_ast(results) ==
               MapSet.new([{"App.Orders.domain.Order", "App.Orders.adapters.Store"}])
    end

    test "a graph finding's pair is read from its key" do
      violations = [
        %Violation{
          message: "m",
          key: "layering|App.A.web.Page.show/2|-> App.A.adapters.Store.get/1"
        },
        %Violation{
          message: "m",
          key: "layering|App.A.web.Page.ok?/0|-> App.A.adapters.Store.get!/1"
        },
        # A computed function name reaches no module: no pair.
        %Violation{message: "m", key: "layering|App.A.web.Page.run/1|-> dynamic ?/1"}
      ]

      assert Parity.pairs_from_graph(violations) ==
               MapSet.new([{"App.A.web.Page", "App.A.adapters.Store"}])
    end
  end

  describe "diff/2" do
    test "equal sets: both sides empty" do
      pairs = MapSet.new([{"A", "B"}])
      assert Parity.diff(pairs, pairs) == %{ast_only: [], graph_only: []}
    end

    test "one extra on each side lands in the right field, sorted" do
      ast = MapSet.new([{"A", "B"}, {"C", "D"}])
      graph = MapSet.new([{"A", "B"}, {"E", "F"}])
      assert Parity.diff(ast, graph) == %{ast_only: [{"C", "D"}], graph_only: [{"E", "F"}]}
    end
  end

  describe "uncovered/3 (transitive findings)" do
    @deps %{"A" => ["B"], "B" => ["C"], "C" => [], "X" => ["C"]}

    test "a chain the graph flags an edge on is covered" do
      assert Parity.uncovered(MapSet.new([{"A", "C"}]), MapSet.new([{"B", "C"}]), @deps) == []
    end

    test "a chain with no flagged edge is uncovered" do
      assert Parity.uncovered(MapSet.new([{"A", "C"}]), MapSet.new([{"X", "C"}]), @deps) ==
               [{"A", "C"}]
    end

    test "a flagged edge off the chain does not cover it" do
      assert Parity.uncovered(MapSet.new([{"A", "C"}]), MapSet.new([{"A", "Z"}]), @deps) ==
               [{"A", "C"}]
    end
  end
end
