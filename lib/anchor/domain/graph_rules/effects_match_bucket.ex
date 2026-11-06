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

  Each violation is one proposal of `Anchor.Domain.Placement` (DND-5448): rule 1
  of `Anchor.Domain.Placement.Rules`, and the `Fix:` is `Placement.render/1` of it,
  which names the inferred role and the evidence: the call chain to the first
  effect (`Effects.evidence/2`), an unresolved call at its line, or that no effect
  is reachable. An effect whose compiled call several Elixir functions share is
  named with every candidate (`Inlines.describe/1`, DND-5613). A pure function whose
  type owner is known is told to go to that owner.
  """

  @behaviour Anchor.Domain.GraphRule
  @behaviour Anchor.Domain.RuleShape

  alias Anchor.Domain.Effects
  alias Anchor.Domain.Failures
  alias Anchor.Domain.Graph.FunctionNode
  alias Anchor.Domain.Graph.ModuleNode
  alias Anchor.Domain.GraphRules
  alias Anchor.Domain.Model
  alias Anchor.Domain.Placement
  alias Anchor.Domain.Roots

  @judged_roles [:domain, :adapters, :managers]

  @impl Anchor.Domain.GraphRule
  def rule_type, do: :effects_match_bucket

  @impl Anchor.Domain.GraphRule
  def narrows?(_base_key, _key), do: false

  @impl Anchor.Domain.GraphRule
  def needs, do: [:cfa, :effects, :placement]

  @impl Anchor.Domain.RuleShape
  def shape(_rule) do
    "a public function's bucket matches what it causes: domain reaches no effect, adapters " <>
      "performs an effect (itself or through its own module), managers orchestrates effects " <>
      "through other modules"
  end

  @impl Anchor.Domain.GraphRule
  def check(%Model{} = model, rule) do
    effects = model.effects || Effects.infer(model)
    roots = effects.roots
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

    placement = model.placement || Placement.build(%{model | effects: effects})
    selected = MapSet.new(judged, fn {module, _class, _bucket} -> module end)

    floor_issues(judged, functions, rule, model) ++
      for proposal <- Placement.proposals(placement, model, :effects_match_bucket),
          MapSet.member?(selected, elem(proposal.subject, 0)),
          do: Placement.to_violation(proposal, model, rule)
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
end
