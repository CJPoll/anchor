defmodule Anchor.Domain.GraphRulesTest do
  # DND-5440: the graph-rule registry, what a rule selects and its floor.
  # Pure Domain over a hand-built model.
  #
  # Sabotage record: ../../sabotage_records/graph_runner-20261103-dnd_5440_graph_runner.md
  # Sabotage record (DND-5715): ../../sabotage_records/graph_runner-20261106-dnd_5715_bucket_split.md
  # Sabotage record (DND-5633): ../../sabotage_records/context_acyclic-20261103-dnd_5648_graph_followups.md
  # Sabotage record (FX-B): ../../sabotage_records/graph_runner-20261103-dnd_5648_graph_followups.md
  # Sabotage record (DND-5447, DND-5454 rows): ../../sabotage_records/rule_schema-20261103-dnd_5447_graph_rules_c.md
  # (needs/1, DND-5574: ../../sabotage_records/graph_runner-20261103-dnd_5574_cfa_wiring.md)
  # DND-5448: ../../sabotage_records/placement-20261106-dnd_5448_placement_core.md
  use ExUnit.Case, async: true

  alias Anchor.Domain.Classification
  alias Anchor.Domain.Graph
  alias Anchor.Domain.GraphRules
  alias Anchor.Domain.Model
  alias Anchor.Domain.RuleSchema

  defp classified(module, bucket, file) do
    %Classification{module: module, bucket: bucket, role: :domain, source_file: file}
  end

  defp model do
    classification =
      Map.new(
        [
          classified(MyApp.Accounts.User, "domain", "lib/my_app/domain/accounts/user.ex"),
          classified(MyApp.Accounts.Order, "domain", "lib/my_app/domain/accounts/order.ex"),
          classified(MyApp.Accounts.Manager, "managers", "lib/my_app/managers/accounts.ex")
        ],
        &{&1.module, &1}
      )

    %Model{graph: %Graph{}, architecture: nil, classification: classification, config: nil}
  end

  describe "needs/1 (DND-5574)" do
    alias Anchor.Test.GraphRuleStubs, as: Stubs

    test "a rule with no needs/0 needs nothing" do
      assert GraphRules.needs(Stubs.Ok) == []
    end

    test "a declared [:cfa] is read, without duplicates" do
      assert GraphRules.needs(Stubs.NeedsCfa) == [:cfa]
    end

    test "the rule that holds the analyses complete needs the flow analysis and demand" do
      assert GraphRules.needs(GraphRules.AnalysesComplete) == [:cfa, :demand]
    end

    test "a need the runner does not compute raises, naming it and what it computes" do
      error = assert_raise ArgumentError, fn -> GraphRules.needs(Stubs.NeedsUnknown) end

      assert error.message ==
               "Anchor.Test.GraphRuleStubs.NeedsUnknown.needs/0 names [:nope], which the " <>
                 "graph runner does not compute (it computes [:aggregate_analysis, :cfa, :effects, :demand, :placement])"
    end

    test "a needs/0 that is not a list raises" do
      error = assert_raise ArgumentError, fn -> GraphRules.needs(Stubs.NeedsNonList) end

      assert error.message ==
               "Anchor.Test.GraphRuleStubs.NeedsNonList.needs/0 returned :cfa, not a list of [:aggregate_analysis, :cfa, :effects, :demand, :placement]"
    end
  end

  describe "all/0" do
    test "every module implements GraphRule, and their types are RuleSchema's graph types" do
      for module <- GraphRules.all(), do: assert(graph_rule?(module), inspect(module))

      assert GraphRules.all() |> Enum.map(& &1.rule_type()) |> Enum.sort() ==
               RuleSchema.rule_types_for_engine(:graph)
    end
  end

  # Positive control for the registry check above: `all/0` is empty until the
  # first rule type lands, so the behaviour check is shown on modules that do
  # implement it (the test stubs), and on one that does not.
  test "graph_rule?/1 tells a GraphRule module from another module" do
    for module <- Anchor.Test.GraphRuleStubs.all(), do: assert(graph_rule?(module))
    refute graph_rule?(Anchor.Domain.GraphRules)
  end

  defp graph_rule?(module) do
    behaviours =
      module.__info__(:attributes)
      |> Keyword.get_values(:behaviour)
      |> List.flatten()

    Anchor.Domain.GraphRule in behaviours
  end

  # DND-5633: every rule answers narrows?/2 (a required callback), asked by
  # name: no closure, and no check of what is loaded.
  describe "narrows?/3" do
    test "a rule that narrows is asked" do
      assert GraphRules.narrows?(Anchor.Domain.GraphRules.ContextAcyclic, "c|A,B,C", "c|A,B")
      refute GraphRules.narrows?(Anchor.Domain.GraphRules.ContextAcyclic, "c|A,B", "c|A,B,C")
      assert GraphRules.narrows?(Anchor.Test.GraphRuleStubs.FindsNarrowing, "r|wider", "r|found")
    end

    # The gate on 370588d: narrows?/3 read function_exported?/3, false for a
    # module not yet loaded, so "a rule that narrows is asked" passed or failed
    # by test order. The answer must not depend on what is loaded.
    test "a rule not yet loaded is asked all the same" do
      stub = Anchor.Test.GraphRuleStubs.NarrowsWhenUnloaded
      :code.purge(stub)
      :code.delete(stub)
      refute :code.is_loaded(stub)

      assert GraphRules.narrows?(stub, "r|wider", "r|found")
    end

    test "a rule that never narrows, or no rule, says no" do
      refute GraphRules.narrows?(Anchor.Domain.GraphRules.Layering, "c|A,B,C", "c|A,B")
      refute GraphRules.narrows?(nil, "c|A,B,C", "c|A,B")
    end
  end

  describe "select/2" do
    test "bucket: selects the bucket's modules, sorted" do
      assert GraphRules.select(model(), %{bucket: "domain"}) ==
               [MyApp.Accounts.Order, MyApp.Accounts.User]
    end

    test "paths: matches the source file, ** recursive" do
      assert GraphRules.select(model(), %{paths: ["lib/**/managers/**/*.ex"]}) ==
               [MyApp.Accounts.Manager]
    end

    test "pattern: matches the module name" do
      assert GraphRules.select(model(), %{pattern: "MyApp.Accounts.User"}) == [
               MyApp.Accounts.User
             ]

      assert GraphRules.select(model(), %{pattern: "MyApp.Accounts.Use"}) == []
    end

    test "a rule with no selector selects nothing" do
      assert GraphRules.select(model(), %{type: :x}) == []
    end
  end

  describe "below_floor/2" do
    test "a rule below its min_modules is reported with its count; at the floor it is not" do
      below = %{bucket: "domain", min_modules: 3}
      at = %{bucket: "domain", min_modules: 2}

      assert GraphRules.below_floor(model(), [below, at]) == [{below, 2}]
    end

    test "the default floor is 1: a rule selecting nothing is below it" do
      none = %{bucket: "ui"}
      assert GraphRules.below_floor(model(), [none]) == [{none, 0}]
      assert GraphRules.below_floor(model(), [%{bucket: "managers"}]) == []
    end
  end
end
