defmodule Anchor.Domain.Placement.Rules do
  @moduledoc """
  The function rules of placement, in order (DND-5448, proposal section 8.2) —
  **Domain**, pure. The first that applies wins, so a function has at most one
  placement proposal:

    1. **Bucket from effects.** A public function of a judged bucket (role `domain`,
       `adapters` or `managers`, `infer: true`), no root and not named `__name__`,
       whose inferred role differs from its bucket's goes to a module of the
       inferred role, in the same context. `effects_match_bucket` reports it. When
       the inferred role is `domain` and a type's owner in a Domain bucket is known,
       the proposal names that owner, for the reason of rule 2 or 3: moving a pure
       function out of a Manager has one answer, not two.
    2. **Output-type owner.** A public, pure function of a Domain bucket whose
       `@spec` returns a project struct belongs in that struct's module, when that
       module is in a Domain bucket.
    3. **Input-type owner.** One returning a primitive belongs with the owner of the
       one struct parameter on its return value's slice.
    4. **Dominated.** A public, non-root function whose immediate dominator and every
       caller are in one other module of the same bucket and context is that module's
       interior, unless that module is an interface: it would undo the forwarding.

  A shared function (`FunctionFacts.shared?`) gets no move from rules 2 to 4, and rule
  1 names its bucket, not an owner.

  `function_placement` reports rules 2 to 4.

  ## Not judged by rules 2 to 4

  Roots, generated functions, a project behaviour's callbacks (the contract fixes
  the name), `__name__`, `module_info/0,1`, `behaviour_info/1`, `child_spec/1`, and
  every function of an interface module: an interface forwards across a boundary by
  design (Cody's decision 2). Rule 4 also leaves a function a dynamic call or a
  literal `{M, :f, args}` can reach (`FunctionFacts.named?`): it cannot be private.

  ## Reachability

  `unreachable/1` is F5: a public function no root reaches goes, unless it is not
  judged for one of the reasons above, an interface module's and a callback's
  excepted (nothing reaches them either).
  """

  alias Anchor.Domain.Classification
  alias Anchor.Domain.EffectPrimitives
  alias Anchor.Domain.Effects
  alias Anchor.Domain.Graph.Inlines
  alias Anchor.Domain.Graph.ModuleNode
  alias Anchor.Domain.Model
  alias Anchor.Domain.Placement
  alias Anchor.Domain.Placement.FunctionFacts
  alias Anchor.Domain.Proposal
  alias Anchor.Domain.Roots
  alias Anchor.Domain.ViolationKey

  @judged_roles [:domain, :adapters, :managers]
  @never_judged [:module_info, :behaviour_info]

  @doc "The one placement proposal of the function `facts`, or `nil` (rules 1 to 4)."
  @spec placement(FunctionFacts.t(), Placement.t(), Model.t(), Effects.t()) :: Proposal.t() | nil
  def placement(%FunctionFacts{kind: :defp}, _placement, _model, _effects), do: nil

  def placement(%FunctionFacts{mfa: {module, _f, _a}} = facts, placement, model, effects) do
    case Map.get(model.classification, module) do
      %Classification{} = class -> classified(facts, class, placement, model, effects)
      nil -> nil
    end
  end

  @doc "The `:unreachable` proposal of the function `facts`, or `nil` (F5)."
  @spec unreachable(FunctionFacts.t()) :: Proposal.t() | nil
  def unreachable(%FunctionFacts{kind: :def, reachable?: false} = facts) do
    {module, _f, _a} = facts.mfa

    if authored?(facts),
      do: proposal(:reachable_from_root, :unreachable, facts, module, :delete, []),
      else: nil
  end

  def unreachable(%FunctionFacts{}), do: nil

  @doc "Whether rules 2 to 4 can judge the function `facts`; see the moduledoc."
  @spec movable?(FunctionFacts.t(), Model.t(), MapSet.t(mfa())) :: boolean()
  def movable?(%FunctionFacts{mfa: {module, _f, _a} = mfa} = facts, %Model{} = model, roots) do
    facts.kind == :def and authored?(facts) and not MapSet.member?(roots, mfa) and
      not interface?(module, model) and not project_callback?(mfa, model)
  end

  defp classified(facts, class, placement, model, effects) do
    if judged?(facts, class, model, effects) and facts.role != class.role,
      do: from_effects(facts, class, placement, model, effects),
      else: by_owner_or_dominator(facts, class, placement, model)
  end

  defp judged?(%FunctionFacts{mfa: mfa, role: role, kind: :def}, class, model, effects) do
    bucket = Enum.find(model.architecture.buckets, &(&1.name == class.bucket))

    bucket.role in @judged_roles and bucket.infer and role != nil and
      not Roots.root?(effects.roots, mfa) and not dunder?(elem(mfa, 1))
  end

  # Rule 1. A pure function whose owner is known goes to that owner.
  defp from_effects(%FunctionFacts{role: :domain} = facts, class, placement, model, effects) do
    case owner(facts, placement, model) do
      {reason, owner} -> effects_proposal(reason, facts, owner, model, evidence(reason, owner))
      _no_other_owner -> bucket_proposal(facts, class, model, effects)
    end
  end

  defp from_effects(facts, class, _placement, model, effects),
    do: bucket_proposal(facts, class, model, effects)

  defp bucket_proposal(facts, class, model, effects) do
    target = {:bucket, facts.role, class.context, named_target(facts, class, model)}
    effects_proposal(:bucket_from_effects, facts, target, model, chain(effects, facts.mfa))
  end

  # The key stays `<rule>|<Mod.fun/arity>|<inferred role>`, the key this rule's
  # landed baselines hold, whatever the reason.
  defp effects_proposal(reason, facts, proposed, model, evidence) do
    {module, _f, _a} = facts.mfa

    current =
      {:bucket, model.classification[module].role, model.classification[module].context, module}

    %Proposal{
      proposal(:effects_match_bucket, reason, facts, current, proposed, evidence)
      | key: "effects_match_bucket|#{ViolationKey.mfa(facts.mfa)}|#{facts.role}"
    }
  end

  defp by_owner_or_dominator(facts, class, placement, model) do
    with true <- movable?(facts, model, placement.roots),
         {reason, target} <- next_rule(facts, class, placement, model) do
      {module, _f, _a} = facts.mfa
      proposal(:function_placement, reason, facts, module, target, evidence(reason, target))
    else
      _no_proposal -> nil
    end
  end

  # A function already in its owner has answered: rule 4 does not move it away.
  defp next_rule(facts, class, placement, model) do
    case owner_in_domain(facts, class, placement, model) do
      nil -> dominator(facts, class, model)
      answer -> answer
    end
  end

  defp owner_in_domain(%FunctionFacts{role: :domain} = facts, %{role: :domain}, placement, model),
    do: owner(facts, placement, model)

  defp owner_in_domain(_facts, _class, _placement, _model), do: nil

  # Rules 2 and 3: the owner, when it is a Domain module other than the function's own
  # (`:in_owner` when it is the function's own). A shared function gets no move.
  defp owner(%FunctionFacts{mfa: {module, _f, _a}} = facts, placement, model) do
    if movable?(facts, model, placement.roots) and not facts.shared? do
      [{:output_type_owner, facts.output_owner}, {:input_type_owner, facts.input_owner}]
      |> Enum.find(fn {_reason, owner} -> owner != nil end)
      |> domain_owner(module, model)
    end
  end

  defp domain_owner({_reason, module}, module, _model), do: :in_owner

  defp domain_owner({reason, owner}, _module, model) do
    if match?(%Classification{role: :domain}, Map.get(model.classification, owner)),
      do: {reason, owner}
  end

  defp domain_owner(nil, _module, _model), do: nil

  # Rule 4.
  defp dominator(%FunctionFacts{named?: true}, _class, _model), do: nil
  defp dominator(%FunctionFacts{callers: []}, _class, _model), do: nil

  defp dominator(%FunctionFacts{idom: {idom_module, _f, _a}} = facts, class, model) do
    {module, _name, _arity} = facts.mfa
    caller_modules = Enum.uniq(Enum.map(facts.callers, &elem(&1, 0)))

    if caller_modules == [idom_module] and idom_module != module and
         not interface?(idom_module, model) and
         same_place?(class, Map.get(model.classification, idom_module)),
       do: {:dominated_by, idom_module}
  end

  defp dominator(_facts, _class, _model), do: nil

  defp same_place?(%Classification{bucket: bucket, context: context}, %Classification{
         bucket: bucket,
         context: context
       }),
       do: true

  defp same_place?(_class, _other), do: false

  defp proposal(rule, reason, facts, current, proposed, evidence) do
    %Proposal{
      level: :function,
      subject: facts.mfa,
      current: current,
      proposed: proposed,
      rule: rule,
      reason: reason,
      evidence: evidence,
      key: Proposal.key(rule, :function, facts.mfa, proposed)
    }
  end

  defp evidence(:output_type_owner, owner), do: ["it returns %#{inspect(owner)}{}"]

  defp evidence(:input_type_owner, owner),
    do: ["its result is computed from %#{inspect(owner)}{}"]

  defp evidence(:dominated_by, owner), do: ["only #{inspect(owner)} calls it"]

  # The one module of the target role, in this context, with the subject's last name.
  defp named_target(%FunctionFacts{mfa: {module, _f, _a}, role: role}, class, model) do
    tail = tail(module)

    candidates =
      for {other, %Classification{role: ^role, context: context}} <- model.classification,
          context == class.context,
          other != module,
          tail(other) == tail,
          do: other

    case candidates do
      [one] -> one
      _none_or_several -> nil
    end
  end

  defp tail(module), do: module |> Atom.to_string() |> String.split(".") |> List.last()

  defp chain(effects, mfa) do
    case Effects.evidence(effects, mfa) do
      [] ->
        ["no effect is reachable"]

      steps ->
        [Enum.map_join(steps, " -> ", &step_text/1) | unresolved_hint(List.last(steps))]
    end
  end

  defp unresolved_hint({:unresolved, _info}),
    do: ["or declare a behaviour for this call so Anchor can resolve it"]

  defp unresolved_hint(_step), do: []

  defp step_text({:primitive, mfa}), do: Inlines.describe(mfa) <> kind_text(mfa)

  defp step_text({:unresolved, %{text: text, line: line} = info}),
    do: "unresolved dynamic call (#{text}) at #{Map.get(info, :file) || "?"}:#{line || "?"}"

  defp step_text({_m, _f, _a} = mfa), do: ViolationKey.mfa(mfa)

  # DND-5677: a clock or randomness read says so, since it looks like a pure call.
  defp kind_text(mfa) do
    case EffectPrimitives.inference_kind(mfa) do
      :clock -> " (reads the clock)"
      :random -> " (draws a random value)"
      _other -> ""
    end
  end

  @doc "Whether an author wrote the function `facts`: not generated, and no compiler-named function."
  @spec authored?(FunctionFacts.t()) :: boolean()
  def authored?(%FunctionFacts{mfa: {_module, name, arity}, generated?: generated?}) do
    not generated? and not dunder?(name) and name not in @never_judged and
      {name, arity} != {:child_spec, 1}
  end

  defp dunder?(name) do
    text = Atom.to_string(name)
    String.starts_with?(text, "__") and String.ends_with?(text, "__")
  end

  defp interface?(module, model),
    do: match?(%Classification{interface?: true}, Map.get(model.classification, module))

  defp project_callback?({module, name, arity}, %Model{graph: graph}) do
    case Map.get(graph.modules, module) do
      %ModuleNode{behaviours: behaviours} ->
        Enum.any?(behaviours, &declares_callback?(graph.modules[&1], {name, arity}))

      nil ->
        false
    end
  end

  defp declares_callback?(%ModuleNode{callbacks: callbacks}, callback), do: callback in callbacks
  defp declares_callback?(nil, _callback), do: false
end
