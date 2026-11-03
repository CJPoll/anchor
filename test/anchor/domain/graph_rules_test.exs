defmodule Anchor.Domain.GraphRulesTest do
  # DND-5440: the graph-rule registry, what a rule selects and its floor.
  # Pure Domain over a hand-built model.
  #
  # Sabotage record: ../../sabotage_records/graph_runner-20261103-dnd_5440_graph_runner.md
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

  describe "all/0" do
    test "every module implements GraphRule, and their types are RuleSchema's graph types" do
      for module <- GraphRules.all() do
        assert (Anchor.Domain.GraphRule in Keyword.get_values(
                  module.__info__(:attributes),
                  :behaviour
                ))
               |> List.flatten()
      end

      assert GraphRules.all() |> Enum.map(& &1.rule_type()) |> Enum.sort() ==
               RuleSchema.rule_types_for_engine(:graph)
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
