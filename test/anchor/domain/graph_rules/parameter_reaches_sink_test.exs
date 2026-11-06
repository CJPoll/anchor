defmodule Anchor.Domain.GraphRules.ParameterReachesSinkTest do
  # Domain (ADR 002). DND-5470: the parameter_reaches_sink graph rule over
  # hand-built models and demand summaries (Anchor.Test.EffectsModels). Real
  # Core shapes (patterns, guards, an unresolved apply, send) are held by the
  # canary: test/anchor/integration/parameter_reaches_sink_canary_test.exs.
  #
  # Sabotage record: ../../../sabotage_records/parameter_reaches_sink-20261106-dnd_5470_param_sink_locality.md
  use ExUnit.Case, async: true

  alias Anchor.Domain.Demand
  alias Anchor.Domain.Demand.Param
  alias Anchor.Domain.Graph.FunctionNode
  alias Anchor.Domain.GraphRules.ParameterReachesSink

  @rule %{type: :parameter_reaches_sink, id: "sinks", bucket: "domain"}

  defp param(demand, passes \\ []), do: %Param{demand: demand, passes: passes, imprecise?: false}

  # `summaries`: `%{mfa => [demand | {demand, passes}]}`. Every module is
  # hand-written unless `:generated` says otherwise.
  defp built(modules, calls, summaries, opts \\ []) do
    base = Anchor.Test.EffectsModels.model(modules, calls)

    nodes =
      Map.new(base.graph.modules, fn {module, node} ->
        {module, %{node | generated?: Keyword.get(opts, :generated, false)}}
      end)

    %{
      base
      | graph: %{base.graph | modules: nodes},
        callbacks: Keyword.get(opts, :callbacks, %{}),
        demand: %Demand{
          summaries:
            Map.new(summaries, fn {mfa, params} ->
              {mfa,
               Enum.map(params, fn
                 {demand, passes} -> param(demand, passes)
                 demand -> param(demand)
               end)}
            end),
          lambdas: Keyword.get(opts, :lambdas, %{})
        }
    }
  end

  defp keys(violations), do: violations |> Enum.map(& &1.key) |> Enum.sort()

  defp domain(functions, opts \\ []), do: [{D, "domain", functions, opts}]

  defp with_clauses(model, mfa, clauses) do
    {module, name, arity} = mfa
    node = model.graph.modules[module]

    function = Map.put(node.functions[{name, arity}], :clauses, clauses)
    node = %{node | functions: Map.put(node.functions, {name, arity}, function)}
    %{model | graph: %{model.graph | modules: Map.put(model.graph.modules, module, node)}}
  end

  describe "check/2" do
    test "an absent parameter is one violation; its Fix names the parameter" do
      model =
        built(domain([{:f, 1}, {:g, 2}]), [], %{
          {D, :f, 1} => [:all],
          {D, :g, 2} => [:all, :absent]
        })

      assert [violation] = ParameterReachesSink.check(model, @rule)
      assert violation.key == "sinks|D.g/2|param 2"
      assert violation.trigger == "D.g/2"
      assert violation.filename == "lib/domain/D.ex"
      assert violation.line == 12
      assert violation.rule_id == "sinks"
      assert violation.message =~ "Fix: drop parameter 2 (arg2) of D.g/2"
    end

    test "a used parameter passes: positive control" do
      model = built(domain([{:f, 1}]), [], %{{D, :f, 1} => [:all]})
      assert ParameterReachesSink.check(model, @rule) == []
    end

    test "reading a field is a use: only an absent whole parameter is reported" do
      model =
        built(domain([{:f, 1}, {:g, 1}]), [], %{
          {D, :f, 1} => [{:used, %{id: :all}}],
          {D, :g, 1} => [{:used, %{}}]
        })

      assert ParameterReachesSink.check(model, @rule) == []
    end

    test "a dropped chain is a violation at each level, naming the callee" do
      model =
        built(domain([{:f, 2}, {:g, 1}]), [{{D, :f, 2}, {D, :g, 1}}], %{
          {D, :f, 2} => [:all, {:absent, [{{D, :g, 1}, 0}]}],
          {D, :g, 1} => [:absent]
        })

      [f, g] = model |> ParameterReachesSink.check(@rule) |> Enum.sort_by(& &1.key)

      assert f.key == "sinks|D.f/2|param 2"
      assert f.message =~ "chain: D.f/2 param 2 -> D.g/1 param 1 (dropped)"
      assert g.key == "sinks|D.g/1|param 1"
      assert g.message =~ "chain: D.g/1 param 1 (dropped)"
      assert g.message =~ "call sites: 1"
      assert g.message =~ "at its 1 call sites"
    end

    test "the chain follows an absent callee, past one that is not, and stops at recursion" do
      model =
        built(domain([{:f, 1}, {:used, 1}, {:rec, 1}]), [], %{
          {D, :f, 1} => [{:absent, [{{D, :used, 1}, 0}, {{D, :rec, 1}, 0}]}],
          {D, :used, 1} => [:all],
          {D, :rec, 1} => [{:absent, [{{D, :rec, 1}, 0}]}]
        })

      [f, rec] = model |> ParameterReachesSink.check(@rule) |> Enum.sort_by(& &1.key)

      assert f.message =~ "chain: D.f/1 param 1 -> D.rec/1 param 1 -> D.rec/1 param 1 (dropped)"
      assert rec.message =~ "chain: D.rec/1 param 1 -> D.rec/1 param 1 (dropped)"
    end

    test "a callee outside the summaries, or an unknown lambda, ends the chain" do
      model =
        built(
          domain([{:f, 1}]),
          [],
          %{{D, :f, 1} => [{:absent, [{{Other, :g, 1}, 0}, {{{D, :f, 1}, 9}, 0}]}]}
        )

      assert [violation] = ParameterReachesSink.check(model, @rule)
      assert violation.message =~ "chain: D.f/1 param 1 (dropped)"
    end

    test "the parameter's name comes from the first clause that names it" do
      mfa = {D, :f, 2}
      var = fn name -> {name, [line: 1], nil} end

      clauses = [
        {[line: 1], [:literal, {:_, [], nil}], [], :ok},
        {[line: 2], [{:=, [], [{:%{}, [], []}, var.(:named)]}, var.(:_opts)], [], :ok}
      ]

      model =
        domain([{:f, 2}])
        |> built([], %{mfa => [:absent, :absent]})
        |> with_clauses(mfa, clauses)

      [first, second] = model |> ParameterReachesSink.check(@rule) |> Enum.sort_by(& &1.key)

      assert first.message =~ "parameter 1 (named)"
      assert second.message =~ "parameter 2 (_opts)"
    end

    test "a position with no variable in any clause is arg<position>" do
      mfa = {D, :f, 1}

      model =
        domain([{:f, 1}])
        |> built([], %{mfa => [:absent]})
        |> with_clauses(mfa, [{[line: 1], [{:_, [], nil}], [], :ok}])

      assert [violation] = ParameterReachesSink.check(model, @rule)
      assert violation.message =~ "parameter 1 (arg1)"
    end

    test "the rule selects: a module it does not select is not judged" do
      modules = [{D, "domain", [{:f, 1}], []}, {M, "managers", [{:g, 1}], []}]

      model =
        built(modules, [], %{{D, :f, 1} => [:all], {M, :g, 1} => [:absent]})

      assert ParameterReachesSink.check(model, @rule) == []
    end

    test "the rule refuses a model with no demand analysis: never a clean read" do
      assert_raise FunctionClauseError, fn ->
        domain([]) |> built([], %{}) |> Map.put(:demand, nil) |> ParameterReachesSink.check(@rule)
      end
    end
  end

  describe "exempt functions" do
    @absent %{{D, :f, 1} => [:absent]}
    @judged %{judged: 1, exempt: 0, not_analysed: 0}
    @exempt %{judged: 0, exempt: 1, not_analysed: 0}

    defp plus_judged(model) do
      # One judged, clean function, so the floor does not speak.
      node = model.graph.modules[D]
      extra = %FunctionNode{module: D, name: :ok, arity: 0, kind: :def, line: 1, core: nil}
      node = %{node | functions: Map.put(node.functions, {:ok, 0}, extra)}

      %{
        model
        | graph: %{model.graph | modules: Map.put(model.graph.modules, D, node)},
          demand: %{model.demand | summaries: Map.put(model.demand.summaries, {D, :ok, 0}, [])}
      }
    end

    defp exempt?(model) do
      model = plus_judged(model)
      assert ParameterReachesSink.check(model, @rule) == []
      assert ParameterReachesSink.counts(model, @rule) == %{@exempt | judged: 1}
    end

    test "not exempt: the positive control for this block" do
      model = domain([{:f, 1}]) |> built([], @absent) |> plus_judged()

      assert keys(ParameterReachesSink.check(model, @rule)) == ["sinks|D.f/1|param 1"]
      assert ParameterReachesSink.counts(model, @rule) == %{@judged | judged: 2}
    end

    test "a callback of an external behaviour" do
      domain([{:f, 1}], behaviours: [B])
      |> built([], @absent, callbacks: %{B => [f: 1]})
      |> exempt?()
    end

    test "a callback of a project behaviour, read from the graph" do
      model = domain([{:f, 1}], behaviours: [B]) |> built([], @absent)
      behaviour = %{model.graph.modules[D] | module: B, functions: %{}, callbacks: [f: 1]}

      %{model | graph: %{model.graph | modules: Map.put(model.graph.modules, B, behaviour)}}
      |> exempt?()
    end

    test "a function of a behaviour module that is no callback is judged" do
      model =
        domain([{:f, 1}], behaviours: [B])
        |> built([], @absent, callbacks: %{B => [other: 1]})

      assert keys(ParameterReachesSink.check(model, @rule)) == ["sinks|D.f/1|param 1"]
    end

    test "a captured function, public or private" do
      capture = fn kind ->
        [{{D, :caller, 0}, {D, :f, 1}, :capture}]
        |> then(
          &built(domain([{:f, 1, kind}, {:caller, 0}]), &1, Map.put(@absent, {D, :caller, 0}, []))
        )
      end

      for kind <- [:def, :defp] do
        assert ParameterReachesSink.check(capture.(kind), @rule) == []
      end
    end

    test "a public function a dynamic call can reach, and not another arity" do
      calls = [{{D, :caller, 0}, {:dynamic, :f, 1, :variable}, :remote}]
      summaries = Map.merge(@absent, %{{D, :caller, 0} => [], {D, :f, 2} => [:absent, :all]})

      model = built(domain([{:f, 1}, {:f, 2}, {:caller, 0}]), calls, summaries)

      assert keys(ParameterReachesSink.check(model, @rule)) == ["sinks|D.f/2|param 1"]
    end

    test "a dynamic call with no known arity reaches every arity of the name" do
      calls = [{{D, :caller, 0}, {:dynamic, :f, nil, :call}, :apply}]
      summaries = Map.merge(@absent, %{{D, :caller, 0} => [], {D, :f, 2} => [:absent, :all]})
      model = built(domain([{:f, 1}, {:f, 2}, {:caller, 0}]), calls, summaries)

      assert ParameterReachesSink.check(model, @rule) == []
    end

    test "a dynamic call cannot reach a private function" do
      calls = [{{D, :caller, 0}, {:dynamic, :f, nil, :call}, :apply}]
      summaries = Map.merge(@absent, %{{D, :caller, 0} => [], {D, :f, 2} => [:absent, :all]})
      model = built(domain([{:f, 1}, {:f, 2, :defp}, {:caller, 0}]), calls, summaries)

      assert keys(ParameterReachesSink.check(model, @rule)) == ["sinks|D.f/2|param 1"]
    end

    test "a dynamic call with a computed name exempts nothing" do
      calls = [{{D, :caller, 0}, {:dynamic, nil, nil, :call}, :apply}]
      summaries = Map.put(@absent, {D, :caller, 0}, [])

      model = built(domain([{:f, 1}, {:caller, 0}]), calls, summaries)

      assert keys(ParameterReachesSink.check(model, @rule)) == ["sinks|D.f/1|param 1"]
    end

    test "a function of a generated module" do
      model = domain([{:f, 1}]) |> built([], @absent, generated: true)

      # Nothing else in the module is judged, so only the floor speaks.
      assert [%{kind: :fail_closed}] = ParameterReachesSink.check(model, @rule)
      assert ParameterReachesSink.counts(model, @rule) == @exempt
    end

    test "a function the compiler names __name__" do
      summaries = %{{D, :__struct__, 1} => [:absent]}
      domain([{:__struct__, 1}]) |> built([], summaries) |> exempt?()
    end

    for {what, meta} <- [
          {"quote generated: true", [generated: true]},
          {"a macro's quote", [context: SomeMacro]}
        ] do
      test "a function #{what} wrote" do
        domain([{:f, 1}])
        |> built([], @absent)
        |> with_clauses({D, :f, 1}, [{unquote(meta), [{:x, [line: 1], nil}], [], :ok}])
        |> exempt?()
      end
    end

    test "a default's head, whose arguments Elixir generates" do
      arg = {:x0, [generated: true, version: 0], :elixir_def}

      domain([{:f, 1}])
      |> built([], @absent)
      |> with_clauses({D, :f, 1}, [{[line: 1], [arg], [], :ok}])
      |> exempt?()
    end

    test "a hand-written argument beside a generated one keeps the function judged" do
      args = [{:x0, [generated: true], :elixir_def}, {:y, [line: 1], nil}]
      summaries = %{{D, :f, 2} => [:absent, :all]}

      model =
        domain([{:f, 2}])
        |> built([], summaries)
        |> with_clauses({D, :f, 2}, [{[line: 1], args, [], :ok}])

      assert keys(ParameterReachesSink.check(model, @rule)) == ["sinks|D.f/2|param 1"]
    end
  end

  describe "a function with no arguments" do
    setup do
      model =
        domain([{:f, 0}])
        |> built([], %{{D, :f, 0} => []})
        |> with_clauses({D, :f, 0}, [{[line: 1], [], [], :ok}])

      {:ok, model: model}
    end

    test "is judged: no arguments are not all generated ones", %{model: model} do
      assert %{judged: 1, exempt: 0, not_analysed: 0} = ParameterReachesSink.counts(model, @rule)
    end

    test "a module holding only such functions trips no floor", %{model: model} do
      assert ParameterReachesSink.check(model, @rule) == []
    end
  end

  describe "what is not analysed: counted, never judged" do
    defp not_analysed(model) do
      assert %{not_analysed: 1} = ParameterReachesSink.counts(model, @rule)
      refute Enum.any?(ParameterReachesSink.check(model, @rule), &(&1.key != nil))
    end

    test "a function with no summary" do
      domain([{:f, 1}]) |> built([], %{}) |> not_analysed()
    end

    test "a module that may be generated" do
      domain([{:f, 1}]) |> built([], @absent, generated: :unknown) |> not_analysed()
    end

    test "a public function of a module whose external behaviour gave no callbacks" do
      domain([{:f, 1}], behaviours: [B]) |> built([], @absent) |> not_analysed()

      domain([{:f, 1}], behaviours: [B])
      |> built([], @absent, callbacks: %{B => []})
      |> not_analysed()
    end

    test "a private function of that module is still judged: no behaviour fixes it" do
      model =
        domain([{:f, 1, :defp}], behaviours: [B])
        |> built([], @absent)

      assert keys(ParameterReachesSink.check(model, @rule)) == ["sinks|D.f/1|param 1"]
    end

    test "a macro is neither judged nor counted" do
      model = built(domain([{:f, 1}, {:m, 1, :defmacro}]), [], %{{D, :f, 1} => [:all]})
      assert ParameterReachesSink.counts(model, @rule) == %{judged: 1, exempt: 0, not_analysed: 0}
    end
  end

  describe "the floor" do
    test "selected modules of which nothing could be judged: one fail-closed issue" do
      model = built(domain([{:f, 1}]), [], %{})

      assert [issue] = ParameterReachesSink.check(model, @rule)
      assert issue.kind == :fail_closed
      assert issue.message =~ "judged no function"
      assert issue.message =~ "Fix:"
    end

    test "selected modules with no def or defp at all: the same issue" do
      model = built(domain([{:m, 1, :defmacro}]), [], %{})

      assert [%{kind: :fail_closed} = issue] = ParameterReachesSink.check(model, @rule)
      assert issue.message =~ "judged no function"
    end

    test "a rule that selects no module leaves it to the selection floor" do
      model = built(domain([{:f, 1}]), [], %{{D, :f, 1} => [:all]})
      assert ParameterReachesSink.check(model, %{@rule | bucket: "managers"}) == []
    end
  end

  describe "shape/1" do
    test "states the rule" do
      shape = ParameterReachesSink.shape(@rule)
      assert shape =~ "every parameter reaches the return value or an effect"
      assert shape =~ "callback implementations and captured"
    end
  end

  test "rule_type/0, needs/0 and narrows?/2" do
    assert ParameterReachesSink.rule_type() == :parameter_reaches_sink
    assert ParameterReachesSink.needs() == [:cfa, :demand]
    refute ParameterReachesSink.narrows?("a", "b")
  end
end
