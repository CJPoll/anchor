defmodule Anchor.Domain.GraphRules.EffectsMatchBucket do
  @moduledoc """
  The `effects_match_bucket` graph rule (DND-5447): a function's bucket
  follows from what it causes — a **Domain** module (ADR 001). Pure: it reads
  the run's `Anchor.Domain.Model` and its effect inference
  (`Anchor.Domain.Effects`) and returns violations.

  For each module the rule selects whose bucket has role `domain`, `adapters`
  or `managers` and `infer: true` (the default), each public function that is
  not a root must infer its bucket's role: a Domain function reaches no
  effect, an adapter's performs one (itself or through its own module), a
  Manager's reaches effects only through other modules. A mismatch is one
  violation per function, on its def line, keyed
  `<rule>|<Mod.fun/arity>|<inferred role>`.

  Not judged: buckets of role `framework` and `ui` (layering and E1 cover
  them), private functions (placement's dominator rule, DND-5448, does), roots
  (a framework calls them), and functions the compiler names `__name__`
  (`__struct__/1`, `__impl__/1`: generated, never the author's to place).

  A bucket the rule selects modules of, but of which no public function was
  analysed, is below the rule's floor: an issue on the config, never a pass.

  Each message names the inferred role and the evidence: the call chain to the
  first effect (`Effects.evidence/2`), an unresolved call at its line, or
  that no effect is reachable. An effect whose compiled call several Elixir
  functions share is named with every candidate (`Inlines.describe/1`,
  DND-5613). Until DND-5448 lands, the `Fix:` is this rule's own shape per
  case.
  """

  @behaviour Anchor.Domain.GraphRule
  @behaviour Anchor.Domain.RuleShape

  alias Anchor.Domain.Effects
  alias Anchor.Domain.Failures
  alias Anchor.Domain.Graph.FunctionNode
  alias Anchor.Domain.Graph.Inlines
  alias Anchor.Domain.Graph.ModuleNode
  alias Anchor.Domain.GraphRules
  alias Anchor.Domain.Model
  alias Anchor.Domain.Roots
  alias Anchor.Domain.Violation
  alias Anchor.Domain.ViolationKey

  @judged_roles [:domain, :adapters, :managers]

  @impl Anchor.Domain.GraphRule
  def rule_type, do: :effects_match_bucket

  @impl Anchor.Domain.GraphRule
  def needs, do: [:cfa, :effects]

  @impl Anchor.Domain.RuleShape
  def shape(_rule) do
    "a public function's bucket matches what it causes: domain reaches no effect, adapters " <>
      "performs an effect (itself or through its own module), managers orchestrates effects " <>
      "through other modules"
  end

  @impl Anchor.Domain.GraphRule
  def check(%Model{} = model, rule) do
    effects = model.effects || Effects.infer(model)
    roots = Roots.roots(model)
    buckets = Map.new(model.architecture.buckets, &{&1.name, &1})

    judged =
      for module <- GraphRules.select(model, rule),
          %{bucket: name} = class <- [Map.get(model.classification, module)],
          bucket = Map.fetch!(buckets, name),
          bucket.role in @judged_roles and bucket.infer,
          do: {module, class, bucket}

    functions =
      for {module, class, bucket} <- judged,
          {mfa, node} <- public_functions(model, module),
          not Roots.root?(roots, mfa),
          role = Effects.role(effects, mfa),
          role != nil,
          do: {mfa, node, class, bucket, role}

    floor_issues(judged, functions, rule, model) ++
      for {mfa, node, class, bucket, role} <- functions,
          role != bucket.role,
          do: violation(mfa, node, class, bucket, role, effects, rule, model)
  end

  defp public_functions(model, module) do
    case Map.get(model.graph.modules, module) do
      %ModuleNode{functions: functions} ->
        for {{name, arity}, %FunctionNode{kind: :def} = node} <- Enum.sort(functions),
            not generated_name?(name),
            do: {{module, name, arity}, node}

      nil ->
        []
    end
  end

  defp generated_name?(name) do
    text = Atom.to_string(name)
    String.starts_with?(text, "__") and String.ends_with?(text, "__")
  end

  defp floor_issues(judged, functions, rule, model) do
    analysed = MapSet.new(functions, fn {_mfa, _node, _class, bucket, _role} -> bucket.name end)

    judged
    |> Enum.map(fn {_module, _class, bucket} -> bucket.name end)
    |> Enum.uniq()
    |> Enum.sort()
    |> Enum.reject(&MapSet.member?(analysed, &1))
    |> Enum.map(&Failures.effects_bucket_unanalysed(rule, &1, model.config.path))
  end

  defp violation(mfa, node, class, bucket, role, effects, rule, _model) do
    evidence = Effects.evidence(effects, mfa)

    %Violation{
      filename: class.source_file,
      line: node.line,
      trigger: ViolationKey.mfa(mfa),
      rule_id: Map.get(rule, :id),
      key: ViolationKey.graph_key(rule, ViolationKey.mfa(mfa), Atom.to_string(role)),
      message: message(bucket.role, role, mfa, bucket.name, evidence) <> unresolved_fix(evidence)
    }
  end

  defp message(:domain, _role, mfa, name, evidence) do
    "#{ViolationKey.mfa(mfa)} is in bucket #{name} (domain) but reaches an effect: " <>
      "#{chain_text(evidence)}. Fix: move the effect into an adapter and have a Manager call " <>
      "it; #{ViolationKey.mfa(mfa)} then returns the data the Manager needs."
  end

  defp message(:managers, :adapters, mfa, name, evidence) do
    "#{ViolationKey.mfa(mfa)} is in bucket #{name} (managers) but calls an effect itself: " <>
      "#{chain_text(evidence)}. Fix: move the call into an adapter of this context and call " <>
      "the adapter."
  end

  defp message(_role, :domain, mfa, name, _evidence) do
    "#{ViolationKey.mfa(mfa)} is in bucket #{name} but reaches no effect. Fix: move it to a " <>
      "Domain module of this context (it is pure)."
  end

  defp message(:adapters, :managers, mfa, name, [_self, next | _rest] = evidence) do
    "#{ViolationKey.mfa(mfa)} is in bucket #{name} (adapters) but reaches effects only " <>
      "through #{step_text(next)}: #{chain_text(evidence)}. Fix: it orchestrates; move it to " <>
      "a Manager, or move the effect into this adapter."
  end

  defp message(bucket_role, role, mfa, name, evidence) do
    "#{ViolationKey.mfa(mfa)} is in bucket #{name} (#{bucket_role}) but infers #{role}: " <>
      "#{chain_text(evidence)}. Fix: " <> shape(%{})
  end

  defp unresolved_fix(evidence) do
    case List.last(evidence) do
      {:unresolved, _info} -> " Or declare a behaviour for this call so Anchor can resolve it."
      _other -> ""
    end
  end

  defp chain_text([]), do: "no effect is reachable"
  defp chain_text(evidence), do: Enum.map_join(evidence, " -> ", &step_text/1)

  defp step_text({:primitive, mfa}), do: Inlines.describe(mfa)

  defp step_text({:unresolved, %{text: text, line: line} = info}),
    do: "unresolved dynamic call (#{text}) at #{Map.get(info, :file) || "?"}:#{line || "?"}"

  defp step_text({_m, _f, _a} = mfa), do: ViolationKey.mfa(mfa)
end
