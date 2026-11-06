defmodule Anchor.Domain.GraphRules.EffectsMatchBucketTest do
  # Domain (ADR 002). DND-5447: the effects_match_bucket graph rule over
  # hand-built models (Anchor.Test.EffectsModels).
  #
  # Sabotage record: ../../../sabotage_records/effects-20261103-dnd_5447_graph_rules_c.md
  # The Fix as a rendered proposal (DND-5448): ../../../sabotage_records/placement-20261106-dnd_5448_placement_core.md
  use ExUnit.Case, async: true

  import Anchor.Test.EffectsModels

  alias Anchor.Domain.Effects
  alias Anchor.Domain.GraphRules.EffectsMatchBucket
  alias Anchor.Domain.Placement

  @rule %{type: :effects_match_bucket, id: "effects", paths: ["lib/**"]}

  # `:callbacks` (external behaviours' callbacks) puts an inference that read
  # them on the model, as the runner does; without it the rule infers with
  # none.
  defp check(modules, calls, opts \\ [], rule \\ @rule) do
    {callbacks, opts} = Keyword.pop(opts, :callbacks)
    model = model(modules, calls, opts)

    model =
      if callbacks,
        do: %{model | effects: Effects.infer(model, callbacks: callbacks)},
        else: model

    EffectsMatchBucket.check(model, rule)
  end

  test "a pure function in a domain bucket passes" do
    assert check([{D, "domain", [{:f, 1}], []}], [{{D, :f, 1}, {Enum, :map, 2}}]) == []
  end

  test "a domain function that reaches an effect is one issue naming the chain" do
    modules = [{D, "domain", [{:f, 1}], []}, {D2, "domain", [{:g, 1}], []}]

    calls = [
      {{D, :f, 1}, {D2, :g, 1}},
      {{D2, :g, 1}, {App.Repo, :insert, 1}}
    ]

    [one, two] =
      check([{App.Repo, "framework", [], behaviours: [Ecto.Repo]} | modules], calls)
      |> Enum.sort_by(& &1.trigger)

    assert one.trigger == "D.f/1"
    assert one.message =~ "D.f/1 is in bucket domain (domain) but reaches an effect"
    assert one.message =~ "D.f/1 -> D2.g/1 -> App.Repo.insert/1"
    assert one.message =~ "Fix: move D.f/1 to the managers bucket: D.f/1 -> D2.g/1"
    assert one.key == "effects|D.f/1|managers"
    assert one.filename == "lib/domain/D.ex"
    assert one.line == 11
    assert one.rule_id == "effects"
    # D2.g/1 calls the Repo itself: it infers adapters.
    assert two.key == "effects|D2.g/1|adapters"
  end

  test "a manager with a direct effect is an issue" do
    [violation] =
      check(
        [{App.Repo, "framework", [], behaviours: [Ecto.Repo]}, {M, "managers", [{:run, 1}], []}],
        [{{M, :run, 1}, {App.Repo, :insert, 1}}]
      )

    assert violation.message =~ "calls an effect itself."
    assert violation.message =~ "Fix: move M.run/1 to the adapters bucket: M.run/1 -> App.Repo"
  end

  test "an adapter function with no effect is an issue" do
    [violation] = check([{A, "adapters", [{:to_map, 1}], []}], [])

    assert violation.message =~ "A.to_map/1 is in bucket adapters but reaches no effect"

    assert violation.message =~
             "Fix: move A.to_map/1 to the domain bucket: no effect is reachable"

    assert violation.key == "effects|A.to_map/1|domain"
  end

  test "an adapter that reaches effects only through another module names it" do
    [violation] =
      check(
        [{A, "adapters", [{:run, 1}], []}, {A2, "adapters", [{:save, 1}], []}],
        [{{A, :run, 1}, {A2, :save, 1}}, {{A2, :save, 1}, {File, :write, 2}}]
      )

    assert violation.message =~ "reaches effects only through A2.save/1"
    assert violation.message =~ "Fix: move A.run/1 to the managers bucket: A.run/1 -> A2.save/1"
  end

  test "an unresolved call in the chain is named, and its Fix offers a behaviour" do
    [violation] =
      check([{D, "domain", [{:f, 2}], []}], [{{D, :f, 2}, {:dynamic, nil, 1, :variable}, :apply}])

    assert violation.message =~ "unresolved dynamic call"
    assert violation.message =~ "at lib/domain/D.ex:7"
    assert violation.message =~ "declare a behaviour for this call"
  end

  test "an effect several Elixir functions compile to is named with every candidate" do
    [violation] = check([{D, "domain", [{:f, 1}], []}], [{{D, :f, 1}, {:erlang, :demonitor, 1}}])

    assert violation.message =~ "Port.demonitor/1"
    assert violation.message =~ "Process.demonitor/1"
  end

  test "roots are not judged" do
    calls = [{{A, :fetch, 1}, {File, :read, 1}}]
    modules = [{A, "adapters", [{:handle_call, 3}, {:fetch, 1}], behaviours: [GenServer]}]
    assert check(modules, calls, callbacks: %{GenServer => [handle_call: 3]}) == []
    # Positive control: the same pure function without the behaviour is judged.
    assert [%{trigger: "A.handle_call/3"}] =
             check([{A, "adapters", [{:handle_call, 3}, {:fetch, 1}], []}], calls)
  end

  test "private functions are not judged" do
    modules = [{M, "managers", [{:helper, 1, :defp}, {:run, 1}], []}]
    calls = [{{M, :run, 1}, {A, :get, 1}}, {{A, :get, 1}, {File, :read, 1}}]

    assert check([{A, "adapters", [{:get, 1}], []} | modules], calls) == []
  end

  test "a bucket with infer false is not judged" do
    modules = [{D, "domain", [{:f, 1}], []}]
    calls = [{{D, :f, 1}, {File, :read, 1}}]

    assert check(modules, calls, infer: %{"domain" => false}) == []
    # Positive control.
    assert [_one] = check(modules, calls, infer: %{"domain" => true})
  end

  test "framework buckets are not judged" do
    assert check([{W, "framework", [{:show, 2}], []}], []) == []
  end

  test "the selector narrows the modules judged" do
    modules = [{D, "domain", [{:f, 1}], []}, {M, "managers", [{:run, 1}], []}]
    rule = %{type: :effects_match_bucket, bucket: "domain"}

    assert check(modules, [], [], rule) == []
    # Positive control: the bad manager is found when the rule selects it.
    assert [%{trigger: "M.run/1"}] = check(modules, [], [], %{rule | bucket: "managers"})
  end

  test "generated __name__ functions are not judged" do
    assert [%{trigger: "A.to_map/1"}] =
             check([{A, "adapters", [{:__struct__, 1}, {:to_map, 1}], []}], [])
  end

  test "a judged bucket with no public function analysed is below the floor" do
    [issue] = check([{A, "adapters", [{:__struct__, 1}, {:load, 1, :defp}], []}], [])

    assert issue.kind == :fail_closed
    assert issue.message =~ "judged no public function of bucket adapters"
    assert issue.message =~ "Fix:"
    # Positive control: a module with a pure public function is judged, not a floor issue.
    assert [%{kind: kind}] = check([{A, "adapters", [{:to_map, 1}], []}], [])
    refute kind == :fail_closed
  end

  # DND-5448: the Fix is the rendered proposal, character for character, and the
  # key stays the one the landed baselines hold.
  test "the Fix is Placement.render/1 of its proposal, and the key is the landed one" do
    model = model([{D, "domain", [{:f, 1}], []}], [{{D, :f, 1}, {File, :read, 1}}])

    assert [violation] = EffectsMatchBucket.check(model, @rule)

    assert [proposal] =
             model |> Placement.build() |> Placement.proposals(model, :effects_match_bucket)

    assert proposal.reason == :bucket_from_effects
    assert String.ends_with?(violation.message, "Fix: " <> Placement.render(proposal))
    assert violation.key == "effects|D.f/1|adapters"
  end

  test "a selected function's proposal only: the selector limits it" do
    modules = [{D, "domain", [{:f, 1}], []}, {D2, "domain", [{:g, 1}], []}]
    calls = [{{D, :f, 1}, {File, :read, 1}}, {{D2, :g, 1}, {File, :read, 1}}]
    rule = %{type: :effects_match_bucket, id: "effects", paths: ["lib/domain/D.ex"]}

    assert [%{trigger: "D.f/1"}] = check(modules, calls, [], rule)
  end

  test "shape/1 states the role table" do
    shape = EffectsMatchBucket.shape(%{type: :effects_match_bucket})

    assert shape =~ "domain reaches no effect"
    assert shape =~ "adapters performs an effect"
    assert shape =~ "managers orchestrates effects through other modules"
  end
end
