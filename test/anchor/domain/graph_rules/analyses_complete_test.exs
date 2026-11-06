defmodule Anchor.Domain.GraphRules.AnalysesCompleteTest do
  # DND-5715: the analyses_complete graph rule. Pure Domain, over a hand-built
  # model: the analyses' results are the input, so no analysis runs here (a
  # real bound hit is in demand_test.exs and cfa_test.exs).
  #
  # Sabotage record: ../../../sabotage_records/analyses_complete-20261106-dnd_5715_bucket_split.md
  use ExUnit.Case, async: true

  alias Anchor.Domain.Cfa
  alias Anchor.Domain.Classification
  alias Anchor.Domain.Demand
  alias Anchor.Domain.Graph
  alias Anchor.Domain.Graph.FunctionNode
  alias Anchor.Domain.Graph.ModuleNode
  alias Anchor.Domain.GraphRules.AnalysesComplete
  alias Anchor.Domain.Model

  @rule %{type: :analyses_complete, id: "complete", paths: ["lib/app/**"]}
  @file_a "lib/app/a.ex"
  @file_other "lib/other/z.ex"

  defp function(module, name, kind, core \\ :a_core_body) do
    {{name, 1},
     %FunctionNode{module: module, name: name, arity: 1, kind: kind, line: 1, core: core}}
  end

  defp module_node(module, file, functions) do
    {module,
     %ModuleNode{
       module: module,
       app: :app,
       source_file: file,
       functions: Map.new(functions)
     }}
  end

  # A: a def, a defp, a macro and a defp with no Core body; Z outside the rule's selector.
  defp model(demand, cfa \\ %Cfa{}) do
    modules = [
      module_node(A, @file_a, [
        function(A, :pub, :def),
        function(A, :priv, :defp),
        function(A, :mac, :defmacro),
        function(A, :unused, :defp, nil)
      ]),
      module_node(Z, @file_other, [function(Z, :other, :def)])
    ]

    classification =
      for {module, file} <- [{A, @file_a}, {Z, @file_other}], into: %{} do
        {module,
         %Classification{module: module, bucket: "domain", role: :domain, source_file: file}}
      end

    %Model{
      graph: %Graph{modules: Map.new(modules)},
      architecture: nil,
      classification: classification,
      config: %{path: "proj/.anchor.yml"},
      cfa: cfa,
      demand: demand
    }
  end

  defp summaries(mfas), do: Map.new(mfas, &{&1, []})

  defp complete do
    %Demand{
      summaries: summaries([{A, :pub, 1}, {A, :priv, 1}]),
      counts: %{functions: 2, parameters: 2, absent: 1}
    }
  end

  test "every selected function summarised, no bound hit: no violation" do
    assert AnalysesComplete.check(model(complete()), @rule) == []
  end

  test "a hit step bound is one fail-closed violation on the config, naming the steps" do
    assert [violation] =
             AnalysesComplete.check(model(complete(), %Cfa{bound_hit?: true, steps: 7}), @rule)

    assert violation.kind == :fail_closed
    assert violation.filename == "proj/.anchor.yml"
    assert violation.message =~ ~s|rule (id: "complete", analyses_complete): |
    assert violation.message =~ "hit its step bound after 7 steps"
  end

  test "a hit round bound is one fail-closed violation, naming the members" do
    demand = %{complete() | bound_hit: [{A, :pub, 1}, {Z, :other, 1}]}

    assert [violation] = AnalysesComplete.check(model(demand), @rule)

    assert violation.kind == :fail_closed
    assert violation.filename == "proj/.anchor.yml"
    assert violation.message =~ "hit its round bound on 2 function(s) (A.pub/1, Z.other/1)"
  end

  test "a def with no summary is one fail-closed violation naming it" do
    demand = %Demand{summaries: summaries([{A, :priv, 1}])}

    assert [violation] = AnalysesComplete.check(model(demand), @rule)

    assert violation.kind == :fail_closed
    assert violation.message =~ "1 function(s) have a Core body and no demand summary (A.pub/1)"
  end

  test "a defp with no summary is one too" do
    demand = %Demand{summaries: summaries([{A, :pub, 1}])}

    assert [violation] = AnalysesComplete.check(model(demand), @rule)
    assert violation.message =~ "(A.priv/1)"
  end

  describe "the floors (the positive controls)" do
    @sites %Cfa{counts: %{total: 7, resolved: 7, any: 0, by_function: %{}}}

    for {key, judged, above, at} <- [
          {:min_functions, 2, 3, 2},
          {:min_apply_sites, 7, 8, 7},
          {:min_absent_parameters, 1, 2, 1}
        ] do
      test "#{key}: below it is one fail-closed violation naming it and the count; at it, none" do
        rule = Map.put(@rule, unquote(key), unquote(above))

        assert [violation] = AnalysesComplete.check(model(complete(), @sites), rule)
        assert violation.kind == :fail_closed

        assert violation.message =~
                 "judged #{unquote(judged)}, below #{unquote(key)} #{unquote(above)}"

        at = Map.put(@rule, unquote(key), unquote(at))
        assert AnalysesComplete.check(model(complete(), @sites), at) == []
      end
    end

    test "no floor declared: the counts are not judged" do
      assert AnalysesComplete.check(model(complete()), @rule) == []
      assert %Cfa{}.counts.total == 0
    end
  end

  test "every kind of failure is reported together, in order" do
    demand = %Demand{summaries: %{}, bound_hit: [{A, :pub, 1}]}
    rule = Map.put(@rule, :min_functions, 1)

    assert [cfa, rounds, missing, floor] =
             AnalysesComplete.check(model(demand, %Cfa{bound_hit?: true, steps: 1}), rule)

    assert floor.message =~ "below min_functions 1"

    assert cfa.message =~ "step bound"
    assert rounds.message =~ "round bound"
    assert missing.message =~ "2 function(s) have a Core body and no demand summary"
  end

  test "a module outside the selector, once selected, is judged (positive control of Z)" do
    assert [violation] =
             AnalysesComplete.check(model(complete()), %{@rule | paths: ["lib/other/**"]})

    assert violation.message =~ "(Z.other/1)"
  end

  test "a selected module with no node in the graph is not a crash and not a function" do
    model = model(complete())
    model = %{model | graph: %{model.graph | modules: Map.delete(model.graph.modules, Z)}}

    assert AnalysesComplete.check(model, %{@rule | paths: ["lib/**"]}) == []
  end

  test "with no analysis on the model the check crashes: the runner's guard reports it" do
    assert_raise FunctionClauseError, fn ->
      AnalysesComplete.check(%{model(complete()) | demand: nil}, @rule)
    end
  end

  test "a config path comes from the model, the default when there is none" do
    model = %{model(complete(), %Cfa{bound_hit?: true, steps: 1}) | config: nil}

    assert [%{filename: ".anchor.yml"}] = AnalysesComplete.check(model, @rule)
  end

  test "its contract" do
    assert AnalysesComplete.rule_type() == :analyses_complete
    assert AnalysesComplete.needs() == [:cfa, :demand]
    assert AnalysesComplete.narrows?("a", "b") == false
    assert AnalysesComplete.shape(@rule) =~ "every function has a demand summary"
  end
end
