defmodule Anchor.Domain.GraphRules.ParameterReachesSink do
  @moduledoc """
  The `parameter_reaches_sink` graph rule, F2 (DND-5470): every parameter of a
  function reaches its return value or an effect, directly or through the
  callees it is passed to. A **Domain** module (ADR 001), pure: it reads the
  run's `Anchor.Domain.Model` and the demand analysis on it
  (`Anchor.Domain.Demand`, DND-5498) and returns violations.

  A violation is a parameter whose sound demand is `:absent`, one per
  parameter, on its function's def line, keyed
  `<rule>|<Mod.fun/arity>|param <position>` (1-based). Its message names the
  chain of calls that drops the value, rebuilt from the summary's `passes`;
  each level of a chain is its own violation.

  ## Whole parameters only

  A parameter of which only some fields are read is `{:used, fields}`, never
  `:absent`, so it is not reported. Matching is a use too: a clause that
  matches a parameter against anything but a variable, and a guard that reads
  it, make it used in the summary (`Anchor.Domain.Demand.Transfer`). Underscore
  names are no exemption: an unused input is still a dead input.

  ## What imprecision can do

  Demand over-approximates what a function does with a parameter, so its
  imprecision only hides a finding: a parameter passed to an unresolved apply or
  an unknown library call is used. The run prints the precision counts
  (`Anchor.Domain.GraphReport`).

  Who calls a function is another question, and there a false finding is possible.
  A caller with no edge and no full name is unseen: `apply(M, name, args)`,
  `spawn(M, :f, args)`, `spawn(mod, :f, [a])`, an MFA in variables. Reading any of
  them as naming every candidate would let one such call silence the rule, so what
  they might reach stays judged. Before dropping a public function's parameter,
  check that no such caller relies on it. The run counts the `apply`s that compute a
  name (`Anchor.Domain.DynamicCalls.computed_name_count/1`) as a hint; a zero there
  does not rule out the other shapes.

  ## What is not judged

  Exempt, because something else fixes the signature, and counted by
  `counts/2`:

    * a function implementing a callback of a behaviour its module declares (a
      project behaviour's `callbacks` from the graph, an external one's from
      `Model.callbacks`);
    * a function captured anywhere in the project (`&M.f/2`, `&f/2`): the
      consumer fixes the arity;
    * a public function a dynamic call can reach (`mod.f(x)`,
      `Anchor.Domain.DynamicCalls.targets/2`): the unseen receiver fixes the
      arity. A call whose function name is computed as well names no target,
      so it exempts nothing;
    * a public function the code names in full: a literal `{M, :f, args}` with a
      list of known length, in a term or as three arguments of a call (a child
      spec's `start:`, `spawn(M, :f, [a])`, `Anchor.Domain.Core.mfa_references/1`);
    * a generated function: its module has no literal `defmodule`
      (`ModuleNode.generated?`), its name is `__name__`, or a macro wrote it (a
      clause meta with `generated` or `context`, the argument Elixir generates
      for a default's head).

  Not analysed, and counted by `counts/2`, because an answer could be wrong:

    * a function with no summary (no Core body);
    * a function of a module that may be generated (`generated?: :unknown`);
    * a public function of a module with an external behaviour whose callbacks
      the port could not read (none, or missing): it may implement one.

  Selected modules of which no function was judged are one fail-closed issue:
  the rule checked nothing.

  ## The Fix

  Until `Anchor.Domain.Placement` lands (DND-5448), the `Fix:` is this rule's
  own text, the proposal `drop parameter`.
  """

  @behaviour Anchor.Domain.GraphRule
  @behaviour Anchor.Domain.RuleShape

  alias Anchor.Domain.Core
  alias Anchor.Domain.Demand
  alias Anchor.Domain.DynamicCalls
  alias Anchor.Domain.Failures
  alias Anchor.Domain.Graph
  alias Anchor.Domain.Graph.Call
  alias Anchor.Domain.Graph.FunctionNode
  alias Anchor.Domain.Graph.ModuleNode
  alias Anchor.Domain.GraphRules
  alias Anchor.Domain.Model
  alias Anchor.Domain.ViolationKey
  alias Anchor.Domain.Violation

  @type counts :: %{
          judged: non_neg_integer(),
          exempt: non_neg_integer(),
          not_analysed: non_neg_integer()
        }

  @impl Anchor.Domain.GraphRule
  def rule_type, do: :parameter_reaches_sink

  @impl Anchor.Domain.GraphRule
  def narrows?(_base_key, _key), do: false

  @impl Anchor.Domain.GraphRule
  def needs, do: [:cfa, :demand]

  @impl Anchor.Domain.RuleShape
  def shape(_rule) do
    "every parameter reaches the return value or an effect, directly or through a callee; " <>
      "callback implementations and captured, dynamically called or generated functions are " <>
      "exempt"
  end

  @impl Anchor.Domain.GraphRule
  def check(%Model{demand: %Demand{}} = model, rule) do
    verdicts = verdicts(model, rule)

    floor_issue(verdicts, model, rule) ++
      for {mfa, node, :judged} <- verdicts,
          {_param, index} <- Enum.with_index(Map.fetch!(model.demand.summaries, mfa)),
          Demand.param(model.demand, mfa, index) == :absent,
          do: violation(mfa, node, index, model, rule)
  end

  @doc """
  How many functions `rule` selected were judged, exempt or not analysed, for
  the run's summary: what the rule did not look at is never silent.
  """
  @spec counts(Model.t(), map()) :: counts()
  def counts(%Model{demand: %Demand{}} = model, rule) do
    tally = model |> verdicts(rule) |> Enum.frequencies_by(&elem(&1, 2))

    %{
      judged: Map.get(tally, :judged, 0),
      exempt: Map.get(tally, :exempt, 0),
      not_analysed: Map.get(tally, :not_analysed, 0)
    }
  end

  # -- what is judged ---------------------------------------------------------

  defp verdicts(model, rule) do
    reachable = reached_from_outside(model.graph)

    for module <- GraphRules.select(model, rule),
        %ModuleNode{functions: functions} = node <- [Map.get(model.graph.modules, module)],
        {{name, arity}, %FunctionNode{kind: kind} = function} <- Enum.sort(functions),
        kind in [:def, :defp] do
      mfa = {module, name, arity}
      {mfa, function, verdict(mfa, function, node, reachable, model)}
    end
  end

  defp verdict(mfa, function, node, reachable, model) do
    cond do
      not Map.has_key?(model.demand.summaries, mfa) -> :not_analysed
      node.generated? == :unknown -> :not_analysed
      generated?(function, node) -> :exempt
      function.kind == :defp -> private_verdict(mfa, reachable)
      callback?(function, node, model) -> :exempt
      MapSet.member?(reachable, mfa) -> :exempt
      unread_behaviour?(node, model) -> :not_analysed
      true -> :judged
    end
  end

  defp private_verdict(mfa, reachable),
    do: if(MapSet.member?(reachable, mfa), do: :exempt, else: :judged)

  # A macro's output: `quote` puts `context` on the def, `quote generated: true`
  # puts `generated`, and a default's head takes only generated arguments.
  defp generated?(%FunctionNode{name: name, clauses: clauses}, %ModuleNode{generated?: module}) do
    module == true or generated_name?(name) or Enum.any?(clauses, &generated_clause?/1)
  end

  defp generated_name?(name) do
    text = Atom.to_string(name)
    String.starts_with?(text, "__") and String.ends_with?(text, "__")
  end

  defp generated_clause?({meta, args, _guards, _body}) do
    Keyword.has_key?(meta, :generated) or Keyword.has_key?(meta, :context) or
      (args != [] and Enum.all?(args, &generated_arg?/1))
  end

  defp generated_arg?({_name, meta, context}) when is_list(meta) and is_atom(context),
    do: Keyword.get(meta, :generated, false)

  defp generated_arg?(_arg), do: false

  defp callback?(%FunctionNode{name: name, arity: arity}, node, model) do
    Enum.any?(node.behaviours, fn behaviour ->
      {name, arity} in callbacks_of(behaviour, model)
    end)
  end

  defp callbacks_of(behaviour, model) do
    case Map.get(model.graph.modules, behaviour) do
      %ModuleNode{callbacks: callbacks} -> callbacks
      nil -> Map.get(model.callbacks, behaviour, [])
    end
  end

  defp unread_behaviour?(node, model) do
    Enum.any?(node.behaviours, fn behaviour ->
      not Map.has_key?(model.graph.modules, behaviour) and
        Map.get(model.callbacks, behaviour, []) == []
    end)
  end

  # Every function a capture names, every public function a dynamic call with a
  # known name can reach, and every one a literal MFA names.
  defp reached_from_outside(%Graph{calls: calls} = graph) do
    reached = Enum.reduce(calls, MapSet.new(), &add_reached(&1, &2, graph))

    for {_module, %ModuleNode{functions: functions}} <- graph.modules,
        {_name_arity, %FunctionNode{core: core}} <- functions,
        core != nil,
        reference <- Core.mfa_references(core),
        reduce: reached do
      reached -> add_named(reference, reached, graph)
    end
  end

  defp add_named({module, name, arity}, reached, %Graph{modules: modules}) do
    case Map.get(modules, module) do
      nil -> reached
      %ModuleNode{functions: functions} -> add_exports(functions, {module, name, arity}, reached)
    end
  end

  defp add_exports(functions, {module, name, arity}, reached) do
    for {{^name, candidate}, %FunctionNode{kind: :def}} <- functions,
        arity in [nil, candidate],
        reduce: reached do
      reached -> MapSet.put(reached, {module, name, candidate})
    end
  end

  defp add_reached(%Call{kind: :capture, to: {_m, _f, _a} = mfa}, reached, _graph),
    do: MapSet.put(reached, mfa)

  # An `apply/3` whose argument list is not literal has no arity: every arity
  # of the name is in reach.
  defp add_reached(%Call{to: {:dynamic, name, arity, _receiver}} = call, reached, graph) do
    graph
    |> DynamicCalls.targets(call)
    |> Enum.reduce(reached, &add_named({&1, name, arity}, &2, graph))
  end

  defp add_reached(_call, reached, _graph), do: reached

  defp floor_issue(verdicts, model, rule) do
    if GraphRules.select(model, rule) != [] and
         not Enum.any?(verdicts, &(elem(&1, 2) == :judged)),
       do: [Failures.parameter_sink_unjudged(rule, model.config.path)],
       else: []
  end

  # -- the violation ----------------------------------------------------------

  defp violation(mfa, node, index, model, rule) do
    position = index + 1
    name = param_name(node, index)
    chain = chain(model.demand, mfa, index)
    sites = model.graph |> Graph.calls_to(mfa) |> length()
    text = ViolationKey.mfa(mfa)

    %Violation{
      filename: Map.fetch!(model.classification, elem(mfa, 0)).source_file,
      line: node.line,
      trigger: text,
      rule_id: Map.get(rule, :id),
      key: ViolationKey.graph_key(rule, text, "param #{position}"),
      message:
        "#{text} parameter #{position} (#{name}) reaches no return value and no effect " <>
          "(chain: #{chain}; call sites: #{sites}). Fix: drop parameter #{position} (#{name}) " <>
          "of #{text} and stop passing it at its #{sites} call sites."
    }
  end

  # The first clause that names the parameter, else `arg<position>`.
  defp param_name(%FunctionNode{clauses: clauses}, index) do
    Enum.find_value(clauses, "arg#{index + 1}", fn {_meta, args, _guards, _body} ->
      args |> Enum.at(index) |> arg_name()
    end)
  end

  defp arg_name({:=, _meta, [left, right]}), do: arg_name(right) || arg_name(left)

  defp arg_name({name, meta, context})
       when is_atom(name) and is_list(meta) and is_atom(context) and name != :_,
       do: Atom.to_string(name)

  defp arg_name(_pattern), do: nil

  # From `mfa`'s parameter along the first pass whose callee parameter is
  # absent too, until a parameter that is passed no further, or one the chain
  # has already been through (recursion), or a lambda (it has no `passes`).
  defp chain(demand, mfa, index) do
    demand
    |> steps({mfa, index}, MapSet.new())
    |> Enum.map_join(" -> ", &step_text/1)
    |> Kernel.<>(" (dropped)")
  end

  defp steps(demand, {closure, index} = step, seen) do
    next =
      if MapSet.member?(seen, step),
        do: nil,
        else: demand |> passes(closure, index) |> Enum.find(&absent?(demand, &1))

    case next do
      nil -> [step]
      next -> [step | steps(demand, next, MapSet.put(seen, step))]
    end
  end

  defp passes(%Demand{summaries: summaries}, {_m, _f, _a} = mfa, index),
    do: summaries |> Map.fetch!(mfa) |> Enum.at(index) |> Map.fetch!(:passes)

  defp passes(_demand, _lambda, _index), do: []

  defp absent?(%Demand{} = demand, {{_m, _f, _a} = mfa, index}),
    do: Map.has_key?(demand.summaries, mfa) and Demand.param(demand, mfa, index) == :absent

  defp absent?(%Demand{lambdas: lambdas}, {lambda, index}),
    do: lambdas |> Map.get(lambda, []) |> Enum.at(index) == :absent

  defp step_text({{_m, _f, _a} = mfa, index}), do: "#{ViolationKey.mfa(mfa)} param #{index + 1}"

  defp step_text({{mfa, ordinal}, index}),
    do: "fn #{ordinal} in #{ViolationKey.mfa(mfa)} param #{index + 1}"
end
