defmodule Anchor.Domain.Placement do
  @moduledoc """
  The one placement model (DND-5448, proposal sections 8 and 8.2) — **Domain**, pure
  over `Anchor.Domain.Model`. The engine that proposes a placement and the check that
  rejects a misplacement read this struct, so they cannot disagree.

  `build/1` computes, per function of the project (`def` and `defp`), the facts in
  `Anchor.Domain.Placement.FunctionFacts`. A rule of placement reports
  `proposals/3`; a violation is exactly a proposal whose current differs from its
  proposed, built by `to_violation/3`, and its `Fix:` is `render/1` of the proposal,
  character for character. The rule order is `Anchor.Domain.Placement.Rules`.

  The other function-level rule is `no_inert_hop` (DND-5461): a forwarder that
  crosses no boundary, read from Core by `Anchor.Domain.Placement.Forwarders`.

  `directory_placement` (DND-5462) proposes at the directory level, from the module
  dominator tree `Anchor.Domain.Placement.Directories` derives from this model; its
  proposals' subjects are a module or a directory path (`subject_modules/2`).

  ## Roots

  `roots` are the effect inference's (`Anchor.Domain.Roots`), plus every public macro:
  the compiler calls it, and its expansion leaves no edge to it, so a function only a
  macro's body calls would otherwise read as unreachable.

  ## Precision

  `precision` is printed on every run (`Anchor.Domain.GraphReport.placement/1`):

    * `functions` — the functions placed; `no_spec` — public functions judged for
      ownership with no `@spec`, so their ownership is unknown; `ambiguous_owner` —
      those whose types name two structs; `unjoined` — those with no clause to slice;
    * `computed_calls` — the calls whose function name is computed;
    * `reachability` — `:precise`, `:lost` (one of those calls sits in a reachable
      function, so anything could be reached; `lost_sites` names each), or `:no_roots`
      (no root but a macro: the inference found none).

  `reachable_from_root` reports no function under `:lost` or `:no_roots`: it fails
  closed instead (`Anchor.Domain.GraphRules.ReachableFromRoot`).
  """

  alias Anchor.Domain.Classification
  alias Anchor.Domain.Digraph
  alias Anchor.Domain.Effects
  alias Anchor.Domain.Graph.FunctionNode
  alias Anchor.Domain.Graph.ModuleNode
  alias Anchor.Domain.GraphAlgorithms
  alias Anchor.Domain.Model
  alias Anchor.Domain.Placement.CallGraph
  alias Anchor.Domain.Placement.Directories
  alias Anchor.Domain.Placement.Forwarders
  alias Anchor.Domain.Placement.FunctionFacts
  alias Anchor.Domain.Placement.Ownership
  alias Anchor.Domain.Placement.Rules
  alias Anchor.Domain.Proposal
  alias Anchor.Domain.Violation
  alias Anchor.Domain.ViolationKey

  defstruct functions: %{},
            roots: MapSet.new(),
            idom: %{},
            reachable: MapSet.new(),
            proposals: [],
            precision: %{
              functions: 0,
              no_spec: 0,
              ambiguous_owner: 0,
              unjoined: 0,
              computed_calls: 0,
              reachability: :precise,
              lost_sites: [],
              modules_not_placed: 0
            }

  @type precision :: %{
          functions: non_neg_integer(),
          no_spec: non_neg_integer(),
          ambiguous_owner: non_neg_integer(),
          unjoined: non_neg_integer(),
          computed_calls: non_neg_integer(),
          reachability: :precise | :lost | :no_roots,
          lost_sites: [CallGraph.site()],
          modules_not_placed: non_neg_integer()
        }

  @type t :: %__MODULE__{
          functions: %{mfa() => FunctionFacts.t()},
          roots: MapSet.t(mfa()),
          idom: %{mfa() => mfa() | atom()},
          reachable: MapSet.t(mfa()),
          proposals: [Proposal.t()],
          precision: precision()
        }

  @typedoc "What `proposals/3` lists: a level, or one rule's own."
  @type selection ::
          :function
          | :function_placement
          | :reachable_from_root
          | :effects_match_bucket
          | :no_inert_hop
          | :directory
          | :directory_placement

  @rules [
    :function_placement,
    :reachable_from_root,
    :effects_match_bucket,
    :no_inert_hop,
    :directory_placement
  ]
  @levels [:function, :directory]

  @doc "The model of `model`; see the moduledoc."
  @spec build(Model.t()) :: t()
  def build(%Model{} = model) do
    effects = model.effects || Effects.infer(model)
    roots = MapSet.union(effects.roots, public_macros(model))
    calls = CallGraph.build(model.graph)
    dominators = dominators(calls.digraph, roots)
    reachable = dominators.idom |> Map.keys() |> MapSet.new()

    answers = ownership(model, effects, roots)
    functions = facts(model, effects, calls, dominators, answers)

    placement = %__MODULE__{
      functions: functions,
      roots: roots,
      idom: dominators.idom,
      reachable: reachable,
      precision: precision(model, functions, answers, calls, reachable, effects.roots)
    }

    %{placement | proposals: all_proposals(placement, model, effects)}
  end

  @doc "The facts of `mfa`, or `nil` for a function the model does not hold."
  @spec facts(t(), mfa()) :: FunctionFacts.t() | nil
  def facts(%__MODULE__{functions: functions}, mfa), do: Map.get(functions, mfa)

  @doc """
  The proposals of `selection`, sorted by key: a level (`:function`) is every
  proposal of that level, a rule type one rule's. Under lost precision
  `:reachable_from_root` lists none.
  """
  @spec proposals(t(), Model.t(), selection()) :: [Proposal.t()]
  def proposals(%__MODULE__{proposals: proposals}, %Model{}, level) when level in @levels,
    do: Enum.filter(proposals, &(&1.level == level))

  def proposals(%__MODULE__{proposals: proposals}, %Model{}, rule) when rule in @rules,
    do: Enum.filter(proposals, &(&1.rule == rule))

  @doc "The one line a placement `Fix:` carries. An unknown reason raises: no default text."
  @spec render(Proposal.t()) :: String.t()
  def render(
        %Proposal{reason: :bucket_from_effects, proposed: {:bucket, role, context, module}} = p
      ) do
    "move #{subject(p)} to the #{role} bucket#{of_context(context)}#{named(module)}: " <>
      Enum.join(p.evidence, "; ")
  end

  def render(%Proposal{reason: :output_type_owner, proposed: owner} = proposal) do
    "move #{subject(proposal)} to #{inspect(owner)} (it returns %#{inspect(owner)}{}; the " <>
      "owner of a type holds its transitions)"
  end

  def render(%Proposal{reason: :input_type_owner, proposed: owner} = proposal) do
    "move #{subject(proposal)} to #{inspect(owner)} (its result is computed from " <>
      "%#{inspect(owner)}{})"
  end

  def render(%Proposal{reason: :dominated_by, proposed: owner} = proposal) do
    "move #{subject(proposal)} into #{inspect(owner)} as a private function (only " <>
      "#{inspect(owner)} calls it)"
  end

  def render(%Proposal{reason: :unreachable} = proposal) do
    "delete #{subject(proposal)} (no root reaches it), or add the root that should call it"
  end

  def render(%Proposal{reason: :dominator_subtree, evidence: ["dominated by " <> owner]} = p) do
    "move #{subject(p)} from #{p.current} to #{p.proposed} (only #{owner} reaches it; " <>
      "#{owner} is the directory's public module)"
  end

  def render(%Proposal{reason: :shared_module, proposed: {:library_context, contexts}} = p),
    do: "move #{subject(p)} to a library context used by #{Enum.join(contexts, ", ")}"

  def render(%Proposal{reason: :shared_module, evidence: [reached | notes]} = p) do
    count = reached |> String.split(" ") |> Enum.at(2)

    "move #{subject(p)} to #{p.proposed} (reached from #{count} unrelated callers: shared, " <>
      "not a private helper)" <> Enum.map_join(notes, &"; #{&1}")
  end

  def render(%Proposal{reason: :inert_directory} = p),
    do: "flatten #{p.subject} into #{p.proposed} (no module in it is reached only through it)"

  def render(%Proposal{reason: :inert_hop, proposed: {:inline, to}, evidence: [_to, callers]} = p) do
    "inline #{subject(p)}: its callers (#{String.replace_prefix(callers, "callers: ", "")}) " <>
      "call #{ViolationKey.mfa(to)} directly (it forwards without crossing a bucket, context, " <>
      "app, aggregate, interface or callback boundary)"
  end

  @doc """
  The violation of `proposal` under `rule` (a parsed rule map): the subject's def file
  and line, the proposal's key under the rule's name, and a message ending
  `Fix: <render/1>`.
  """
  @spec to_violation(Proposal.t(), Model.t(), map()) :: Violation.t()
  def to_violation(%Proposal{subject: subject} = proposal, %Model{} = model, rule)
      when is_atom(subject) or is_binary(subject) do
    module = proposal |> subject_modules(model) |> hd()

    %Violation{
      filename: Map.fetch!(model.classification, module).source_file,
      line: model.graph.modules[module].line,
      trigger: subject(proposal),
      rule_id: Map.get(rule, :id),
      key: rule_key(proposal.key, rule),
      message: headline(proposal, model) <> " Fix: " <> render(proposal)
    }
  end

  def to_violation(
        %Proposal{subject: {module, name, arity} = mfa} = proposal,
        %Model{} = model,
        rule
      ) do
    %Violation{
      filename: Map.fetch!(model.classification, module).source_file,
      line: line(model, module, {name, arity}),
      trigger: ViolationKey.mfa(mfa),
      rule_id: Map.get(rule, :id),
      key: rule_key(proposal.key, rule),
      message: headline(proposal, model) <> " Fix: " <> render(proposal)
    }
  end

  @doc """
  The modules a proposal is about: the module of a function or module subject, or every
  classified module whose source file sits directly in a directory subject, sorted by
  source file (the first is where its violation goes).
  """
  @spec subject_modules(Proposal.t(), Model.t()) :: [module()]
  def subject_modules(%Proposal{subject: {module, _name, _arity}}, %Model{}), do: [module]

  def subject_modules(%Proposal{subject: module}, %Model{}) when is_atom(module), do: [module]

  def subject_modules(%Proposal{subject: dir}, %Model{classification: classification})
      when is_binary(dir) do
    for {module, %Classification{source_file: file}} <- classification,
        is_binary(file) and Path.dirname(file) == dir do
      {file, module}
    end
    |> Enum.sort()
    |> Enum.map(&elem(&1, 1))
  end

  defp rule_key(key, rule) do
    [_rule | rest] = String.split(key, "|")
    Enum.join([ViolationKey.rule_name(rule) | rest], "|")
  end

  defp line(%Model{graph: graph}, module, name_arity) do
    case graph.modules[module].functions[name_arity] do
      %FunctionNode{line: line} -> line
      nil -> nil
    end
  end

  defp subject(%Proposal{subject: {_m, _f, _a} = mfa}), do: ViolationKey.mfa(mfa)
  defp subject(%Proposal{subject: dir}) when is_binary(dir), do: dir
  defp subject(%Proposal{subject: module}), do: inspect(module)

  defp of_context(nil), do: ""
  defp of_context(context), do: " of #{context}"

  defp named(nil), do: ""
  defp named(module), do: " (#{inspect(module)})"

  # --- the sentence before the Fix ------------------------------------------------

  defp headline(%Proposal{rule: :effects_match_bucket} = proposal, model) do
    {module, _f, _a} = proposal.subject
    %Classification{bucket: name, role: bucket_role} = model.classification[module]
    prefix = "#{subject(proposal)} is in bucket #{name}"
    prefix <> effects_clause(bucket_role, inferred(proposal), proposal)
  end

  defp headline(%Proposal{reason: :unreachable} = proposal, _model),
    do: "#{subject(proposal)} is public and no root reaches it."

  defp headline(
         %Proposal{reason: :dominator_subtree, evidence: ["dominated by " <> owner]} = p,
         _model
       ),
       do: "#{subject(p)} sits in #{p.current}, but only #{owner} reaches it."

  defp headline(%Proposal{reason: :shared_module} = proposal, _model),
    do: "#{subject(proposal)} is shared: no one module reaches it."

  defp headline(%Proposal{reason: :inert_directory} = proposal, _model),
    do: "#{subject(proposal)} encapsulates nothing: no module in it is reached only through it."

  defp headline(%Proposal{reason: :inert_hop, proposed: {:inline, to}} = proposal, _model),
    do:
      "#{subject(proposal)} only forwards to #{ViolationKey.mfa(to)}, and the hop crosses no boundary."

  defp headline(%Proposal{reason: reason} = proposal, model) do
    {module, _f, _a} = proposal.subject

    "#{subject(proposal)} is in #{inspect(module)}#{bucket_note(module, model)}, but " <>
      owner_clause(reason, proposal.proposed) <> "."
  end

  defp bucket_note(module, model), do: " (bucket #{model.classification[module].bucket})"

  defp owner_clause(:output_type_owner, owner), do: "it returns %#{inspect(owner)}{}"

  defp owner_clause(:input_type_owner, owner),
    do: "its result is computed from %#{inspect(owner)}{}"

  defp owner_clause(:dominated_by, owner), do: "only #{inspect(owner)} calls it"

  defp inferred(%Proposal{key: key}), do: key |> String.split("|") |> List.last()

  defp effects_clause(:domain, _role, _proposal), do: " (domain) but reaches an effect."

  defp effects_clause(:managers, "adapters", _proposal),
    do: " (managers) but calls an effect itself."

  defp effects_clause(_bucket_role, "domain", _proposal), do: " but reaches no effect."

  defp effects_clause(:adapters, "managers", %Proposal{evidence: [chain | _rest]}) do
    " (adapters) but reaches effects only through #{next_step(chain)}."
  end

  defp effects_clause(bucket_role, role, _proposal), do: " (#{bucket_role}) but infers #{role}."

  # The step after the subject in a rendered chain.
  defp next_step(chain) do
    case String.split(chain, " -> ") do
      [_self, next | _rest] -> next
      [only] -> only
    end
  end

  # --- building -------------------------------------------------------------------

  defp public_macros(%Model{graph: graph}) do
    for {module, %ModuleNode{functions: functions}} <- graph.modules,
        {{name, arity}, %FunctionNode{kind: :defmacro}} <- functions,
        into: MapSet.new(),
        do: {module, name, arity}
  end

  defp dominators(digraph, roots) do
    if MapSet.size(roots) == 0,
      do: %{idom: %{}, roots: [], virtual: Digraph.virtual_root()},
      else: GraphAlgorithms.dominators(digraph, MapSet.to_list(roots))
  end

  # Each public function with a domain role, not a root and not generated, answers
  # the two ownership questions; everything else has no owner to ask for.
  defp ownership(%Model{graph: graph} = model, effects, roots) do
    for {module, %ModuleNode{functions: functions} = node} <- graph.modules,
        {{name, arity}, %FunctionNode{kind: :def} = function} <- functions,
        mfa = {module, name, arity},
        Effects.role(effects, mfa) == :domain,
        Rules.movable?(facts_for_ownership(mfa, function, node), model, roots),
        into: %{} do
      {mfa, answers(graph, mfa, function)}
    end
  end

  defp facts_for_ownership(mfa, function, node) do
    %FunctionFacts{mfa: mfa, kind: function.kind, generated?: generated_function?(function, node)}
  end

  defp answers(graph, mfa, function) do
    case Ownership.output_owner(graph, mfa) do
      {:ok, _owner} = output -> %{output: output, input: :none}
      :ambiguous -> %{output: :ambiguous, input: :none}
      :no_spec -> %{output: :no_spec, input: :none}
      :none -> %{output: :none, input: Ownership.input_owner(graph, mfa, function)}
    end
  end

  defp facts(%Model{graph: graph}, effects, calls, dominators, answers) do
    for {module, %ModuleNode{functions: functions} = node} <- graph.modules,
        {{name, arity}, %FunctionNode{kind: kind} = function} <- functions,
        kind in [:def, :defp],
        mfa = {module, name, arity},
        into: %{} do
      {mfa, facts_of(mfa, function, node, effects, calls, dominators, answers)}
    end
  end

  defp facts_of(mfa, function, node, effects, calls, dominators, answers) do
    idom = Map.get(dominators.idom, mfa)
    answer = Map.get(answers, mfa, %{output: :none, input: :none})

    %FunctionFacts{
      mfa: mfa,
      kind: function.kind,
      role: Effects.role(effects, mfa),
      output_owner: owner_of(answer.output),
      input_owner: owner_of(answer.input),
      idom: idom,
      reachable?: idom != nil,
      shared?: GraphAlgorithms.shared?(dominators, mfa),
      generated?: generated_function?(function, node),
      callers: calls.digraph |> Digraph.predecessors(mfa),
      named?: MapSet.member?(calls.named, mfa)
    }
  end

  defp owner_of({:ok, owner}), do: owner
  defp owner_of(_no_owner), do: nil

  @doc """
  Whether `function` of `node` is macro or DSL output, or may be: a module the
  source shows no literal `defmodule` for, or may not, and a clause a macro wrote
  (`quote` puts `context` on the def, `quote generated: true` puts `generated`).
  No placement rule judges it.
  """
  @spec generated_function?(FunctionNode.t(), ModuleNode.t()) :: boolean()
  def generated_function?(%FunctionNode{clauses: clauses}, %ModuleNode{generated?: module}) do
    module != false or Enum.any?(clauses, &macro_clause?/1)
  end

  defp macro_clause?({meta, _args, _guards, _body}),
    do: Keyword.has_key?(meta, :generated) or Keyword.has_key?(meta, :context)

  defp precision(model, functions, answers, calls, reachable, roots) do
    outcomes = answers |> Map.values() |> Enum.flat_map(&[&1.output, &1.input])

    %{
      functions: map_size(functions),
      no_spec: Enum.count(answers, fn {_mfa, answer} -> answer.output == :no_spec end),
      ambiguous_owner: Enum.count(outcomes, &(&1 == :ambiguous)),
      unjoined: Enum.count(outcomes, &(&1 == :unjoined)),
      computed_calls: length(calls.computed),
      reachability: reachability(calls, reachable, roots),
      lost_sites: lost_sites(calls, reachable),
      modules_not_placed: Directories.not_placed(model)
    }
  end

  defp reachability(calls, reachable, roots) do
    cond do
      MapSet.size(roots) == 0 -> :no_roots
      lost_sites(calls, reachable) != [] -> :lost
      true -> :precise
    end
  end

  defp lost_sites(calls, reachable),
    do: Enum.filter(calls.computed, &MapSet.member?(reachable, &1.from))

  defp all_proposals(%__MODULE__{functions: functions} = placement, model, effects) do
    facts = functions |> Map.values() |> Enum.sort_by(& &1.mfa)

    function_rules =
      Enum.flat_map(facts, fn fact ->
        fact |> Rules.placement(placement, model, effects) |> List.wrap()
      end)

    unreachable =
      if placement.precision.reachability == :precise,
        do: Enum.flat_map(facts, &(&1 |> Rules.unreachable() |> List.wrap())),
        else: []

    hops = Forwarders.proposals(%{model | effects: effects})
    directories = Directories.proposals(placement, model, nil)

    Enum.sort_by(function_rules ++ unreachable ++ hops ++ directories, & &1.key)
  end
end
