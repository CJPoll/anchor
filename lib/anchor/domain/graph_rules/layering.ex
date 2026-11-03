defmodule Anchor.Domain.GraphRules.Layering do
  @moduledoc """
  The `layering` graph rule (DND-5442): the five-bucket dependency rules,
  enforced over what the compiler produced — a **Domain** module (ADR 001).
  Pure: it reads the run's `Anchor.Domain.Model` and returns violations.

  For every call from a module the rule selects to another classified module
  of the project, the callee's bucket must be in the caller's
  `architecture: calls` row with a matching scope (`Anchor.Domain.CallMatrix`;
  deny by default). The graph is read from beams, so a call a macro injects
  (`use X` expanding into the module) is that module's call: the AST rules
  cannot see it.

    * A call within one module is always allowed; a call to a module outside
      the project (stdlib, dependencies) is not a bucket edge; a call to an
      unclassified module is skipped (the runner already reports the module).
    * A capture (`&M.f/a`) and `apply(M, f, args)` with a literal `M` are
      static calls.
    * A dynamic call (`mod.fetch(x)`) resolves to every project module that
      implements a behaviour declaring that callback
      (`Anchor.Domain.DynamicCalls`), and each candidate is judged as a static
      call. No declaring behaviour is one violation: its target cannot be
      checked.
    * A call whose function name is computed (`apply(M, op, args)`,
      `mod.op_var(x)`, `&M.op_var/1`, `apply(fun, args)`) cannot be checked
      either: one violation. Only applying a variable (`fun.(x)`, an `:apply`
      call through a `:variable`) is a closure application, left to the
      higher-order analysis (DND-5497). `apply/2` and `apply/3` with a computed
      name give the walker the same shape, so `apply(fun, args)` is reported
      too; `fun.(args)` says the same thing and is not.

  One violation per (caller function, callee function), on the caller's
  source file at the first such call's line, keyed
  `<rule>|<Caller.f/a>|-> <Callee.g/b>` (no line). The `Fix:` names the
  allowed route, the shortest bucket path through the matrix
  (`CallMatrix.route/3`), or says there is none.
  """

  @behaviour Anchor.Domain.GraphRule
  @behaviour Anchor.Domain.RuleShape

  alias Anchor.Domain.CallMatrix
  alias Anchor.Domain.DynamicCalls
  alias Anchor.Domain.Graph.Call
  alias Anchor.Domain.GraphRules
  alias Anchor.Domain.Model
  alias Anchor.Domain.Violation
  alias Anchor.Domain.ViolationKey

  @impl Anchor.Domain.GraphRule
  def rule_type, do: :layering

  @impl Anchor.Domain.RuleShape
  def shape(_rule) do
    "every call between two project modules is one the architecture: calls matrix allows; " <>
      "a call the matrix forbids goes through a bucket the caller may call"
  end

  @impl Anchor.Domain.GraphRule
  def check(%Model{} = model, rule) do
    selected = model |> GraphRules.select(rule) |> MapSet.new()

    model.graph.calls
    |> Enum.filter(&MapSet.member?(selected, elem(&1.from, 0)))
    |> Enum.flat_map(&judge(&1, model))
    |> Enum.sort_by(fn {pair, call, _kind} -> {pair, call.line || 0} end)
    |> Enum.uniq_by(fn {pair, _call, _kind} -> pair end)
    |> Enum.map(&violation(&1, model, rule))
  end

  # Each forbidden (caller, target) of one call, with the call and why:
  # `{:forbidden, callee_mfa}` or `{:unresolved, name, arity}`.
  defp judge(%Call{kind: :apply, to: {:dynamic, nil, _arity, :variable}}, _model), do: []

  defp judge(%Call{from: from, to: {:dynamic, nil, arity, _receiver}} = call, _model),
    do: [{{from, {:dynamic, nil, arity}}, call, :unresolved}]

  defp judge(%Call{from: from, to: {:dynamic, name, arity, _receiver}} = call, model) do
    case DynamicCalls.candidates(model.graph, {name, arity}) do
      :unresolved ->
        [{{from, {:dynamic, name, arity}}, call, :unresolved}]

      {:ok, candidates} ->
        Enum.flat_map(candidates, &static(from, {&1, name, arity}, call, model))
    end
  end

  defp judge(%Call{from: from, to: {_module, _name, _arity} = to} = call, model),
    do: static(from, to, call, model)

  defp static({caller, _f, _a} = from, {callee, _g, _b} = to, call, model) do
    with true <- caller != callee,
         %{} = from_class <- Map.get(model.classification, caller),
         %{} = to_class <- Map.get(model.classification, callee),
         false <- CallMatrix.allowed?(model.architecture, from_class, to_class) do
      [{{from, to}, call, :forbidden}]
    else
      _allowed_or_not_judged -> []
    end
  end

  defp violation({{from, target}, call, kind}, model, rule) do
    {caller, _f, _a} = from
    caller_class = Map.fetch!(model.classification, caller)

    %Violation{
      filename: caller_class.source_file,
      line: call.line,
      trigger: ViolationKey.mfa(from),
      rule_id: Map.get(rule, :id),
      key: ViolationKey.graph_key(rule, ViolationKey.mfa(from), "-> " <> target_text(target)),
      message: message(kind, from, target, caller_class, model)
    }
  end

  defp target_text({:dynamic, name, arity}), do: "dynamic #{name || "?"}/#{arity || "?"}"
  defp target_text(mfa), do: ViolationKey.mfa(mfa)

  defp message(:unresolved, from, {:dynamic, nil, arity}, _caller_class, _model) do
    "#{ViolationKey.mfa(from)} calls a function it computes (?/#{arity || "?"}), so its " <>
      "target cannot be checked. Fix: call the module's function by name (or declare it as " <>
      "a behaviour's @callback and call it on the module); apply a closure as fun.(args)."
  end

  defp message(:unresolved, from, {:dynamic, name, arity}, _caller_class, _model) do
    arity_text = arity || "?"

    "#{ViolationKey.mfa(from)} calls #{name}/#{arity_text} on a module it computes, and no " <>
      "behaviour in the project declares that callback, so its target cannot be checked. " <>
      "Fix: declare @callback #{name}/#{arity_text} in a behaviour and implement it in the " <>
      "target modules."
  end

  defp message(:forbidden, from, {callee, _g, _b} = to, caller_class, model) do
    callee_class = Map.fetch!(model.classification, callee)
    arch = model.architecture

    "#{ViolationKey.mfa(from)} (#{side(caller_class)}) calls #{ViolationKey.mfa(to)} " <>
      "(#{side(callee_class)}); #{CallMatrix.row(arch, caller_class.bucket)}. Fix: " <>
      route_text(
        CallMatrix.route(arch, caller_class.bucket, callee_class.bucket),
        caller_class.bucket,
        callee_class.bucket,
        arch
      )
  end

  defp side(%{bucket: bucket, context: context}), do: "#{bucket}, #{context || "no context"}"

  defp route_text(:none, from, to, _arch) do
    "no route: the calls matrix forbids #{from} reaching #{to}; move the logic to a bucket " <>
      "#{from} may call."
  end

  defp route_text([from, to], _from, _to, arch) do
    "#{CallMatrix.row(arch, from)}, so #{from} reaches #{to} only within the scope that row " <>
      "names; keep the call in that scope, or move the logic to a bucket #{from} may call."
  end

  defp route_text([from | _rest] = route, _from, _to, _arch) do
    [_from | middle] = Enum.drop(route, -1)
    to = List.last(route)

    "route it through #{Enum.join(middle, ", then ")}: #{Enum.join(route, " -> ")} " <>
      "(call a #{hd(middle)} module of the right context, which calls #{to}); #{from} may " <>
      "not call #{to} directly."
  end
end
