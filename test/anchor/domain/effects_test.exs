defmodule Anchor.Domain.EffectsTest do
  # Domain (ADR 002). DND-5447: each function's role inferred from what it
  # causes, over hand-built graphs (Anchor.Test.EffectsModels): no beams, no
  # Core, so no flow analysis (Model.cfa is nil: every fun.(x) is unresolved).
  # The flow-analysis path runs on compiled fixtures in
  # test/anchor/integration/effects_canary_test.exs.
  #
  # Sabotage record: ../../sabotage_records/effects-20261103-dnd_5447_graph_rules_c.md
  use ExUnit.Case, async: true

  import Anchor.Test.EffectsModels

  alias Anchor.Domain.Effects

  defp infer(modules, calls, opts \\ []),
    do: modules |> model(calls, opts) |> Effects.infer(callbacks: %{})

  @adapter_modules [
    {M, "managers", [{:run, 1}], []},
    {A, "adapters", [{:get, 1}, {:do_get, 1, :defp}], []}
  ]

  @adapter_calls [
    {{M, :run, 1}, {A, :get, 1}},
    {{A, :get, 1}, {A, :do_get, 1}, :local},
    {{A, :do_get, 1}, {Req, :get, 1}}
  ]

  test "a function with no effect reachable is domain, with no evidence" do
    effects = infer([{D, "domain", [{:f, 1}], []}], [{{D, :f, 1}, {Enum, :map, 2}}])

    assert Effects.role(effects, {D, :f, 1}) == :domain
    assert Effects.evidence(effects, {D, :f, 1}) == []
  end

  test "a direct primitive call is adapters" do
    effects = infer([{A, "adapters", [{:f, 1}], []}], [{{A, :f, 1}, {File, :read, 1}}])

    assert Effects.role(effects, {A, :f, 1}) == :adapters
    assert Effects.evidence(effects, {A, :f, 1}) == [{A, :f, 1}, {:primitive, {File, :read, 1}}]
  end

  test "a primitive reached through the module's own private helper is adapters" do
    effects = infer(@adapter_modules, @adapter_calls, effects: ["Req"])

    assert Effects.role(effects, {A, :get, 1}) == :adapters
    # Positive control: without Req as an effect, nothing is reached.
    assert Effects.role(infer(@adapter_modules, @adapter_calls), {A, :get, 1}) == :domain
  end

  test "an effect reached only through another module is managers, with the chain" do
    effects = infer(@adapter_modules, @adapter_calls, effects: ["Req"])

    assert Effects.role(effects, {M, :run, 1}) == :managers

    assert Effects.evidence(effects, {M, :run, 1}) ==
             [{M, :run, 1}, {A, :get, 1}, {A, :do_get, 1}, {:primitive, {Req, :get, 1}}]
  end

  test "a root is framework even when it reaches effects" do
    effects =
      infer(
        [{W, "framework", [{:show, 2}], []} | @adapter_modules],
        [{{W, :show, 2}, {M, :run, 1}} | @adapter_calls],
        effects: ["Req"]
      )

    assert Effects.role(effects, {W, :show, 2}) == :framework
  end

  test "recursion between modules reaches the fixpoint" do
    effects =
      infer(
        [{M, "managers", [{:a, 1}], []}, {M2, "adapters", [{:b, 1}], []}],
        [
          {{M, :a, 1}, {M2, :b, 1}},
          {{M2, :b, 1}, {M, :a, 1}},
          {{M2, :b, 1}, {File, :read, 1}}
        ]
      )

    assert Effects.role(effects, {M, :a, 1}) == :managers
    assert Effects.role(effects, {M2, :b, 1}) == :adapters
  end

  test "an unresolved dynamic call counts as an effect" do
    effects =
      infer([{D, "domain", [{:f, 2}], []}], [
        {{D, :f, 2}, {:dynamic, nil, 1, :variable}, :apply}
      ])

    assert Effects.role(effects, {D, :f, 2}) == :managers
    assert effects.unresolved_calls == 1
    assert [{D, :f, 2}, {:unresolved, %{line: 7}}] = Effects.evidence(effects, {D, :f, 2})
  end

  test "a call on a computed module that no project module can receive is unresolved" do
    effects =
      infer([{D, "domain", [{:f, 1}], []}], [{{D, :f, 1}, {:dynamic, :run, 1, :variable}}])

    assert Effects.role(effects, {D, :f, 1}) == :managers
    assert effects.unresolved_calls == 1
  end

  test "a dynamic call resolved to pure implementations stays pure" do
    effects =
      infer(
        [
          {B, "domain", [], []},
          {I1, "domain", [{:run, 1}], behaviours: [B]},
          {I2, "domain", [{:run, 1}], behaviours: [B]},
          {D, "domain", [{:f, 2}], []}
        ],
        [{{D, :f, 2}, {:dynamic, :run, 1, :variable}}]
      )

    assert Effects.role(effects, {D, :f, 2}) == :domain
    assert effects.unresolved_calls == 0
  end

  test "a dynamic call resolved to an effectful implementation reaches its effect" do
    effects =
      infer(
        [{I1, "adapters", [{:run, 1}], []}, {D, "domain", [{:f, 2}], []}],
        [{{D, :f, 2}, {:dynamic, :run, 1, :variable}}, {{I1, :run, 1}, {File, :read, 1}}]
      )

    assert Effects.role(effects, {D, :f, 2}) == :managers
  end

  test "a dynamic call whose candidate is a declared effect reaches that effect" do
    modules = [{I1, "adapters", [{:push, 1}], []}, {D, "domain", [{:f, 2}], []}]
    calls = [{{D, :f, 2}, {:dynamic, :push, 1, :variable}}]

    effects = infer(modules, calls, effects: ["I1.push/1"])

    assert Effects.role(effects, {D, :f, 2}) == :adapters
    assert Effects.evidence(effects, {D, :f, 2}) == [{D, :f, 2}, {:primitive, {I1, :push, 1}}]
    # Positive control: the same call made statically reaches it the same way.
    static = infer(modules, [{{D, :f, 2}, {I1, :push, 1}}], effects: ["I1.push/1"])
    assert Effects.role(static, {D, :f, 2}) == :adapters
  end

  test "counts per role are reported" do
    effects = infer(@adapter_modules, @adapter_calls, effects: ["Req"])

    assert effects.counts == %{adapters: 2, managers: 1}
  end

  test "a public function with no Core body is not analysed, and counted" do
    effects =
      infer([{D, "domain", [{:f, 1}, {:g, 1}], []}], [],
        unreadable: [%{path: "x.beam", module: D, reason: {:no_core, [{:g, 1}]}}]
      )

    assert Effects.role(effects, {D, :g, 1}) == nil
    assert Effects.role(effects, {D, :f, 1}) == :domain
    assert effects.not_analysed == 1
  end
end
