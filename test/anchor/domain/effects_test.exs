defmodule Anchor.Domain.EffectsTest do
  # Domain (ADR 002). DND-5447: each function's role inferred from what it
  # causes, over hand-built graphs (Anchor.Test.EffectsModels): no beams, no
  # Core, so no flow analysis (Model.cfa is nil: every fun.(x) is unresolved).
  # The flow-analysis path runs on compiled fixtures in
  # test/anchor/integration/effects_canary_test.exs.
  #
  # Sabotage record: ../../sabotage_records/effects-20261103-dnd_5447_graph_rules_c.md
  # DND-5461 (callbacks kept): ../../sabotage_records/placement-20261106-dnd_5461_placement_rules.md
  # Sabotage record (DND-5679): ../../sabotage_records/effects-20261106-dnd_5676_effects_cfa_batch.md
  # The DND-5679 compiled case reads one Erlang and one Elixir fixture beam
  # through BeamReader's pure decode and the builder, as cfa_test.exs does.
  use ExUnit.Case, async: true

  import Anchor.Test.BeamFixtures, only: [compile_unloaded: 1]
  import Anchor.Test.EffectsModels

  alias Anchor.Adapters.BeamReader
  alias Anchor.Domain.Cfa
  alias Anchor.Domain.Effects
  alias Anchor.Domain.Graph.Builder
  alias Anchor.Test.StructFlowFixtures

  defp infer(modules, calls, opts \\ []),
    do: modules |> model(calls, opts) |> Effects.infer(callbacks: %{})

  # DND-5678: the apply-site tests' compiled fixture, with Cfa (see that describe).
  setup_all do
    modules =
      compile_unloaded("""
      defmodule AnchorFixtures.EffectsTest.Apply do
        def reads(path), do: (f = &File.read!/1; f.(path))
        def upcase(text), do: (f = &String.upcase/1; f.(text))
        def run(f, x), do: f.(x)
      end
      """)

    graph =
      modules
      |> Enum.map(fn {module, binary} ->
        BeamReader.decode(binary, app: :app, path: "ebin/#{module}.beam")
      end)
      |> Builder.build(%{})

    model = StructFlowFixtures.model(graph)
    model = %{model | cfa: Cfa.analyze(graph, Cfa.default_seed(graph))}
    %{apply_effects: Effects.infer(model, callbacks: %{})}
  end

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

    assert [{D, :f, 2}, {:unresolved, %{line: 7, text: "a call of a computed function ?/1"}}] =
             Effects.evidence(effects, {D, :f, 2})
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

  test "the callbacks it was given are kept on the result (DND-5461)" do
    callbacks = %{GenServer => [{:init, 1}]}
    model = model([{D, "domain", [{:f, 1}], []}], [])

    assert Effects.infer(model, callbacks: callbacks).callbacks == callbacks
    assert Effects.infer(model).callbacks == %{}
  end

  describe "a call into a project function whose body was not read (DND-5679)" do
    @erlang %{path: "ebin/filer.beam", module: :filer, reason: {:not_elixir, :erl_abstract_code}}

    test "a call of an unread project module (an Erlang module) is unresolved, named, never pure" do
      effects =
        infer([{D, "domain", [{:f, 1}], []}], [{{D, :f, 1}, {:filer, :write, 1}}],
          unreadable: [@erlang]
        )

      assert Effects.role(effects, {D, :f, 1}) == :managers
      assert effects.unresolved_calls == 1

      assert [{D, :f, 1}, {:unresolved, %{text: text, line: 7}}] =
               Effects.evidence(effects, {D, :f, 1})

      assert text ==
               "a call of :filer.write/1, in a project module whose body Anchor did not read " <>
                 "({:not_elixir, :erl_abstract_code})"
    end

    test "control: the same call into a module outside the project reaches nothing" do
      effects = infer([{D, "domain", [{:f, 1}], []}], [{{D, :f, 1}, {:filer, :write, 1}}])

      assert Effects.role(effects, {D, :f, 1}) == :domain
      assert effects.unresolved_calls == 0
    end

    test "a module both read and listed unread (a duplicate beam) is read: its functions decide" do
      effects =
        infer(
          [{D, "domain", [{:f, 1}], []}, {D2, "domain", [{:g, 1}], []}],
          [{{D, :f, 1}, {D2, :g, 1}}],
          unreadable: [%{path: "b/d2.beam", module: D2, reason: {:duplicate_module, "a/d2.beam"}}]
        )

      assert Effects.role(effects, {D, :f, 1}) == :domain
    end

    test "a call of a public function with no Core body is unresolved, named" do
      effects =
        infer(
          [{D, "domain", [{:f, 1}], []}, {D2, "domain", [{:g, 1}, {:h, 1}], []}],
          [{{D, :f, 1}, {D2, :g, 1}}],
          unreadable: [%{path: "x.beam", module: D2, reason: {:no_core, [{:g, 1}]}}]
        )

      assert Effects.role(effects, {D, :f, 1}) == :managers

      assert [{D, :f, 1}, {:unresolved, %{text: text}}] = Effects.evidence(effects, {D, :f, 1})
      assert text == "a call of D2.g/1, which has no Core body to read"
    end

    test "compiled: an Erlang module that writes a file, called from a Domain function, is not pure" do
      forms = [
        {:attribute, 1, :module, :anchor_fixtures_effects_filer},
        {:attribute, 1, :export, [{:write, 1}]},
        {:function, 1, :write, 1,
         [
           {:clause, 1, [{:var, 1, :X}], [],
            [
              {:call, 1, {:remote, 1, {:atom, 1, :file}, {:atom, 1, :write_file}},
               [{:string, 1, ~c"out"}, {:var, 1, :X}]}
            ]}
         ]}
      ]

      {:ok, :anchor_fixtures_effects_filer, erlang} =
        :compile.forms(forms, [:binary, :debug_info])

      elixir =
        compile_unloaded("""
        defmodule AnchorFixtures.EffectsTest.Pricing do
          def save(x), do: :anchor_fixtures_effects_filer.write(x)
          def total(xs), do: Enum.sum(xs)
        end
        """)

      graph =
        [{:anchor_fixtures_effects_filer, erlang} | elixir]
        |> Enum.map(fn {module, binary} ->
          BeamReader.decode(binary, app: :app, path: "ebin/#{module}.beam")
        end)
        |> Builder.build(%{})

      effects = graph |> StructFlowFixtures.model() |> Effects.infer(callbacks: %{})

      assert Effects.role(effects, {AnchorFixtures.EffectsTest.Pricing, :save, 1}) == :managers
      assert Effects.role(effects, {AnchorFixtures.EffectsTest.Pricing, :total, 1}) == :domain

      assert [
               _save,
               {:unresolved,
                %{text: "a call of :anchor_fixtures_effects_filer.write/1, " <> _why}}
             ] =
               Effects.evidence(effects, {AnchorFixtures.EffectsTest.Pricing, :save, 1})
    end
  end

  describe "apply sites read from the flow analysis (compiled, Model.cfa set)" do
    # The hand-built models above carry no flow analysis; these run Cfa over a
    # compiled fixture (setup_all above), as the runner does, so an apply
    # site's closures decide.
    @apply AnchorFixtures.EffectsTest.Apply

    test "a closure the analysis resolves to an effect capture reaches that effect", %{
      apply_effects: effects
    } do
      assert Effects.role(effects, {@apply, :reads, 1}) == :adapters

      assert Effects.evidence(effects, {@apply, :reads, 1}) ==
               [{@apply, :reads, 1}, {:primitive, {File, :read!, 1}}]
    end

    test "a closure the analysis resolves to a pure capture reaches nothing", %{
      apply_effects: effects
    } do
      assert Effects.role(effects, {@apply, :upcase, 1}) == :domain
    end

    test "a closure from outside the project is unresolved, named", %{apply_effects: effects} do
      assert Effects.role(effects, {@apply, :run, 2}) == :managers

      assert [
               _run,
               {:unresolved, %{text: "an application of a closure from outside the project"}}
             ] =
               Effects.evidence(effects, {@apply, :run, 2})
    end
  end
end
