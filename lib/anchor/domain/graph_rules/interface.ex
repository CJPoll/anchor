defmodule Anchor.Domain.GraphRules.Interface do
  @moduledoc """
  The `interface` graph rule (DND-5443): a call from one context into
  another lands only on that context's interface — Anchor's replacement for
  Boundary's exports and deps (Cody's decision 4: reimplement in the graph
  engine, never verify Boundary) — a **Domain** module (ADR 001). Pure: it
  reads the run's `Anchor.Domain.Model` and returns violations.

  For every call from a module the rule selects to another classified module
  of the project:

    * both in one context: not judged here (`layering` judges buckets);
    * in two contexts: allowed only when the callee is an interface module of
      its context (`interfaces.buckets`, or listed in `interfaces.exports`;
      deny by default). Otherwise one violation per (caller function, callee
      function), at the first such call, keyed
      `interface|<Caller.f/a>|-> <Callee.g/b>`. The `Fix:` names the one
      interface module that reaches the callee inside its context
      (`Anchor.Domain.Interfaces.route/2`) when there is exactly one, else
      the context's interface modules (at most five, then "and n more");
    * either module has no context (fewer name segments than
      `contexts.depth`): its boundary cannot be checked, so it is a
      violation, once per module, keyed `interface|<Mod>|no context`, never a
      pass.

  A call to a module outside the project, or to an unclassified one, is not
  judged (the runner reports an unclassified module already). Calls are
  resolved as `layering` resolves them: a capture and `apply/3` with a
  literal module are static; a dynamic call (`mod.fetch(x)`) is judged
  against every project module exporting the function
  (`Anchor.Domain.DynamicCalls`), so one non-interface candidate in another
  context is a violation; a call whose function name is computed cannot be
  checked and is one violation per (caller, arity); applying a closure
  (`fun.(x)`) is left to the higher-order analysis. Apps are not a boundary:
  a call from another app of an umbrella is judged the same (R5).

  ## Width

  With `max_width: n`, each context of a selected module whose interface
  exports more than `n` public functions (`Interfaces.width/1`) is one
  violation on the config, keyed `interface|<context>|width`. Without it,
  the width is only printed (the run summary and `interface_width` in JSON).
  """

  @behaviour Anchor.Domain.GraphRule
  @behaviour Anchor.Domain.RuleShape

  alias Anchor.Domain.Classification
  alias Anchor.Domain.DynamicCalls
  alias Anchor.Domain.Graph.Call
  alias Anchor.Domain.GraphRules
  alias Anchor.Domain.Interfaces
  alias Anchor.Domain.Model
  alias Anchor.Domain.Violation
  alias Anchor.Domain.ViolationKey

  @listed 5

  @impl Anchor.Domain.GraphRule
  def rule_type, do: :interface

  @impl Anchor.Domain.RuleShape
  def shape(_rule) do
    "a call into another context goes to that context's interface: a module of an " <>
      "interfaces.buckets bucket, or one listed in interfaces.exports"
  end

  @impl Anchor.Domain.GraphRule
  def check(%Model{} = model, rule) do
    selected = GraphRules.select(model, rule)
    members = MapSet.new(selected)

    judged =
      model.graph.calls
      |> Enum.filter(&MapSet.member?(members, elem(&1.from, 0)))
      |> Enum.flat_map(&judge(&1, model))
      |> Enum.sort_by(fn {pair, call, _kind} -> {pair, call.line || 0} end)
      |> Enum.uniq_by(fn {pair, _call, _kind} -> pair end)

    {no_context, calls} = Enum.split_with(judged, &match?({_pair, _call, :no_context}, &1))

    no_context_violations(no_context, model, rule) ++
      Enum.map(calls, &violation(&1, model, rule)) ++
      width_violations(model, rule, selected)
  end

  # Each judged (pair, call, why) of one call: `:forbidden` (a callee
  # outside its context's interface), `:unresolved` (a computed function
  # name) or `:no_context` (pair `{:no_context, module}`).
  defp judge(%Call{kind: :apply, to: {:dynamic, nil, _arity, :variable}}, _model), do: []

  defp judge(%Call{from: from, to: {:dynamic, nil, arity, _receiver}} = call, _model),
    do: [{{from, {:dynamic, nil, arity}}, call, :unresolved}]

  defp judge(%Call{from: from, to: {:dynamic, name, arity, _receiver}} = call, model) do
    model.graph
    |> DynamicCalls.candidates({name, arity})
    |> Enum.flat_map(&static(from, {&1, name, arity}, call, model))
  end

  defp judge(%Call{from: from, to: {_module, _name, _arity} = to} = call, model),
    do: static(from, to, call, model)

  defp static({caller, _f, _a} = from, {callee, _g, _b} = to, call, model) do
    with true <- caller != callee,
         %Classification{} = from_class <- Map.get(model.classification, caller),
         %Classification{} = to_class <- Map.get(model.classification, callee) do
      boundary(from, to, call, from_class, to_class)
    else
      _self_or_not_judged -> []
    end
  end

  defp boundary(_from, _to, call, %{context: nil} = from_class, %{context: nil} = to_class) do
    [
      {{:no_context, from_class.module}, call, :no_context},
      {{:no_context, to_class.module}, call, :no_context}
    ]
  end

  defp boundary(_from, _to, call, %{context: nil} = from_class, _to_class),
    do: [{{:no_context, from_class.module}, call, :no_context}]

  defp boundary(_from, _to, call, _from_class, %{context: nil} = to_class),
    do: [{{:no_context, to_class.module}, call, :no_context}]

  defp boundary(_from, _to, _call, %{context: same}, %{context: same}), do: []
  defp boundary(_from, _to, _call, _from_class, %{interface?: true}), do: []
  defp boundary(from, to, call, _from_class, _to_class), do: [{{from, to}, call, :forbidden}]

  defp no_context_violations(judged, model, rule) do
    depth = model.architecture.context_depth

    judged
    |> Enum.sort_by(fn {{:no_context, module}, _call, _kind} -> module end)
    |> Enum.map(fn {{:no_context, module}, call, _kind} ->
      class = Map.fetch!(model.classification, module)
      {caller, _f, _a} = call.from

      %Violation{
        filename: class.source_file,
        line: if(caller == module, do: call.line),
        trigger: inspect(module),
        rule_id: Map.get(rule, :id),
        key: ViolationKey.graph_key(rule, inspect(module), "no context"),
        message:
          "#{inspect(module)} has no context (fewer than #{depth} name segments), so its " <>
            "boundary cannot be checked. Fix: rename it under a context of depth #{depth}, " <>
            "or lower contexts.depth."
      }
    end)
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

  defp target_text({:dynamic, nil, arity}), do: DynamicCalls.computed_name_target(arity)
  defp target_text(mfa), do: ViolationKey.mfa(mfa)

  defp message(:unresolved, from, {:dynamic, nil, arity}, _caller_class, _model),
    do: DynamicCalls.computed_name_message(from, arity)

  defp message(:forbidden, from, {callee, _g, _b} = to, caller_class, model) do
    context = Map.fetch!(model.classification, callee).context

    "#{ViolationKey.mfa(from)} (context #{caller_class.context}) calls " <>
      "#{ViolationKey.mfa(to)}, which is not part of context #{context}'s interface. Fix: " <>
      fix(Interfaces.route(model, callee), Interfaces.modules_of(model, context), callee, context)
  end

  defp fix({:ok, route}, _interface, _callee, _context), do: "call #{inspect(route)} instead."

  defp fix(:none, [], callee, context) do
    "context #{context} has no interface module; give it one (a module of an " <>
      "interfaces.buckets bucket) and call that, or, if #{inspect(callee)} is meant to be " <>
      "public, add it to interfaces.exports (a reviewed change)."
  end

  defp fix(:none, interface, callee, context) do
    "call one of #{context}'s interface modules: #{listed(interface)}; or, if " <>
      "#{inspect(callee)} is meant to be public, add it to interfaces.exports (a reviewed change)."
  end

  defp listed(modules) do
    {shown, rest} = Enum.split(modules, @listed)
    names = Enum.map_join(shown, ", ", &inspect/1)

    case rest do
      [] -> names
      more -> "#{names} and #{length(more)} more"
    end
  end

  defp width_violations(model, rule, selected) do
    case Map.get(rule, :max_width) do
      max when is_integer(max) ->
        widths = Interfaces.width(model)

        selected
        |> Enum.map(&Map.fetch!(model.classification, &1).context)
        |> Enum.reject(&is_nil/1)
        |> Enum.uniq()
        |> Enum.sort()
        |> Enum.filter(&(Map.get(widths, &1, 0) > max))
        |> Enum.map(&width_violation(&1, Map.fetch!(widths, &1), max, model, rule))

      _none ->
        []
    end
  end

  defp width_violation(context, width, max, model, rule) do
    %Violation{
      filename: config_path(model),
      line: nil,
      trigger: context,
      rule_id: Map.get(rule, :id),
      key: ViolationKey.graph_key(rule, context, "width"),
      message:
        "context #{context} exposes #{width} public functions on its interface, above " <>
          "max_width #{max}. Fix: move functions behind fewer interface functions; raising " <>
          "max_width is the owner's call."
    }
  end

  defp config_path(%Model{config: %{path: path}}) when is_binary(path), do: path
  defp config_path(_model), do: ".anchor.yml"
end
