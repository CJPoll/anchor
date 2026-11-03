defmodule Anchor.Domain.Effects do
  @moduledoc """
  Each function's bucket, inferred from what it causes (DND-5447, proposal
  section 8.2 rule 1) — **Domain**, pure over the model.

  For every `def` and `defp` of the graph, `infer/2` gives its role:

    * `:framework` when it is a root (`Anchor.Domain.Roots`);
    * else `:adapters` when it calls an effect primitive itself
      (`Anchor.Domain.EffectPrimitives.primitive?/2`), or reaches one through
      functions of its own module only (an adapter's public function that
      delegates to its private helper is still the adapter);
    * else `:managers` when it reaches an effect through a function of
      another project module, or reaches a call it cannot resolve;
    * else `:domain`.

  ## What a function calls

  Its call edges (`Anchor.Domain.Graph.Call`):

    * a static call of a primitive is an effect; of a project function, an
      edge to it; of anything else (the stdlib, a dependency), nothing;
    * a call on a computed module (`mod.fetch(x)`) reaches every project
      module exporting the function (`Anchor.Domain.DynamicCalls.candidates/2`,
      the resolution layering uses); with none, the receiver is outside the
      project and unknown, so the call is **unresolved**;
    * a call whose function name is computed (`apply(M, op, args)`,
      `apply(fun, args)`) is unresolved;
    * an apply site (`fun.(x)`, and the invocation inside `Enum.map(xs, fun)`
      and the other higher-order functions): when the model carries the
      higher-order flow analysis (`Model.cfa`, DND-5497), it reaches each
      closure the analysis finds there (a capture `&M.f/a` is that function;
      a lambda is the function it is written in, whose calls the walker
      already gives to that function), and a site reading `:any` is
      unresolved. A higher-order call given a literal where it could take a
      function (`Enum.with_index(list, 1)`) applies nothing there, and neither
      does the collector a comprehension with `into:` applies (the
      `Collectable` implementation of a target the function built itself).
      Without the analysis, every `fun.(x)` is unresolved.

  An unresolved call counts as reaching an effect: it never makes a function
  look pure. Every one is counted (`unresolved_calls`).

  ## What is not analysed

  A public function whose Core body the graph lacks (an `unreadable` entry
  `{:no_core, _}`, DND-5549) has no edges to read, so it gets no role and is
  counted in `not_analysed`; a rule never reads a missing role as a pass.

  ## Evidence

  `evidence/2` is the shortest call chain from a function to its first
  effect (or unresolved call), as the role was decided: within its own module
  for `:adapters`, across modules for `:managers`. `[]` for `:domain` and
  `:framework` functions that reach nothing.
  """

  alias Anchor.Domain.Cfa
  alias Anchor.Domain.Core
  alias Anchor.Domain.DynamicCalls
  alias Anchor.Domain.EffectPrimitives
  alias Anchor.Domain.Graph
  alias Anchor.Domain.Graph.Call
  alias Anchor.Domain.Graph.FunctionNode
  alias Anchor.Domain.Graph.ModuleNode
  alias Anchor.Domain.HigherOrder
  alias Anchor.Domain.Model
  alias Anchor.Domain.Roots

  @type role :: :framework | :ui | :adapters | :domain | :managers

  @typedoc """
  One thing a function's body reaches: a project function, an effect
  primitive, or a call that cannot be resolved (with its description and
  line).
  """
  @type target ::
          {:fn, mfa()}
          | {:primitive, mfa()}
          | {:unresolved,
             %{text: String.t(), line: non_neg_integer() | nil, file: String.t() | nil}}

  @type evidence_step :: mfa() | {:primitive, mfa()} | {:unresolved, map()}

  defstruct roles: %{},
            targets: %{},
            unresolved_calls: 0,
            counts: %{},
            not_analysed: 0

  @type t :: %__MODULE__{
          roles: %{mfa() => role()},
          targets: %{mfa() => [target()]},
          unresolved_calls: non_neg_integer(),
          counts: %{role() => non_neg_integer()},
          not_analysed: non_neg_integer()
        }

  @doc """
  Infers the role of every analysed function of `model`'s graph (see the
  moduledoc). `opts`: `:callbacks`, the behaviour-callback lookup
  `Anchor.Domain.Roots.roots/2` takes.
  """
  @spec infer(Model.t(), keyword()) :: t()
  def infer(%Model{graph: graph} = model, opts \\ []) do
    primitives = EffectPrimitives.build(model.architecture, graph)
    roots = Roots.roots(model, Keyword.get(opts, :callbacks, &Roots.external_callbacks/1))
    no_core = no_core(graph)
    calls = Enum.group_by(graph.calls, & &1.from)

    functions =
      for {module, %ModuleNode{functions: functions}} <- graph.modules,
          {{name, arity}, %FunctionNode{kind: kind} = node} <- functions,
          kind in [:def, :defp],
          mfa = {module, name, arity},
          not MapSet.member?(no_core, mfa),
          do: {mfa, node}

    known = MapSet.new(functions, &elem(&1, 0))
    ctx = %{graph: graph, primitives: primitives, known: known, cfa: model.cfa, calls: calls}

    targets = Map.new(functions, fn {mfa, node} -> {mfa, targets(mfa, node, ctx)} end)

    direct = seeds(targets, &match?({:primitive, _}, &1))
    effectful = seeds(targets, &(not match?({:fn, _}, &1)))
    local = reaching(direct, targets, &same_module?/2)
    reaches = reaching(effectful, targets, fn _from, _to -> true end)

    roles =
      Map.new(targets, fn {mfa, _targets} ->
        {mfa, role(mfa, roots, local, reaches)}
      end)

    %__MODULE__{
      roles: roles,
      targets: targets,
      unresolved_calls: count_unresolved(targets),
      counts: roles |> Map.values() |> Enum.frequencies(),
      not_analysed: MapSet.size(no_core)
    }
  end

  @doc "The inferred role of `mfa`, or `nil` when it was not analysed."
  @spec role(t(), mfa()) :: role() | nil
  def role(%__MODULE__{roles: roles}, mfa), do: Map.get(roles, mfa)

  @doc """
  The shortest chain from `mfa` to the effect that decided its role, as
  `[mfa, ..., {:primitive, mfa} | {:unresolved, info}]`: through its own
  module's functions for `:adapters`, through any project function otherwise.
  `[]` when it reaches no effect or was not analysed.
  """
  @spec evidence(t(), mfa()) :: [evidence_step()]
  def evidence(%__MODULE__{} = effects, mfa) do
    case role(effects, mfa) do
      :adapters ->
        chain(effects.targets, mfa, &same_module?/2, &match?({:primitive, _}, &1))

      nil ->
        []

      _other ->
        chain(effects.targets, mfa, fn _from, _to -> true end, &(not match?({:fn, _}, &1)))
    end
  end

  # --- targets ------------------------------------------------------------------

  defp targets(mfa, %FunctionNode{} = node, ctx) do
    edges = ctx.calls |> Map.get(mfa, []) |> Enum.flat_map(&call_targets(&1, ctx))
    file = source_file(ctx.graph, mfa)

    (edges ++ site_targets(mfa, node, ctx))
    |> Enum.map(&with_file(&1, file))
    |> Enum.uniq()
    |> Enum.reject(&(&1 == {:fn, mfa}))
  end

  defp source_file(graph, {module, _f, _a}) do
    case Graph.module(graph, module) do
      %ModuleNode{source_file: file} -> file
      nil -> nil
    end
  end

  defp with_file({:unresolved, info}, file), do: {:unresolved, Map.put(info, :file, file)}
  defp with_file(target, _file), do: target

  # A closure application is an apply site the flow analysis answers, when
  # the model carries it.
  defp call_targets(%Call{kind: :apply, to: {:dynamic, nil, _arity, :variable}}, %{cfa: %Cfa{}}),
    do: []

  defp call_targets(%Call{to: {:dynamic, nil, arity, _receiver}} = call, _ctx),
    do: [unresolved("a call of a computed function ?/#{arity || "?"}", call.line)]

  defp call_targets(%Call{to: {:dynamic, name, arity, _receiver}} = call, ctx) do
    case DynamicCalls.candidates(ctx.graph, {name, arity}) do
      [] ->
        [unresolved("a call of #{name}/#{arity || "?"} on a computed module", call.line)]

      modules ->
        for module <- modules,
            mfa <- exported(ctx.graph, module, name, arity),
            do: {:fn, mfa}
    end
  end

  defp call_targets(%Call{to: {_m, _f, _a} = to}, ctx), do: static(to, ctx)

  defp static(mfa, ctx) do
    cond do
      EffectPrimitives.primitive?(ctx.primitives, mfa) -> [{:primitive, mfa}]
      MapSet.member?(ctx.known, mfa) -> [{:fn, mfa}]
      true -> []
    end
  end

  defp site_targets(_mfa, _node, %{cfa: nil}), do: []
  defp site_targets(_mfa, %FunctionNode{core: nil}, _ctx), do: []

  defp site_targets(mfa, %FunctionNode{core: core}, ctx) do
    collectors = collectors(core)

    for {site, node} <- Core.apply_sites(mfa, core),
        not data_argument?(site, node),
        not collector_apply?(node, collectors),
        target <- closure_targets(Cfa.closures_at(ctx.cfa, site), node, ctx),
        do: target
  end

  # A comprehension with `into:` compiles to `{acc, fun} =
  # Collectable.into(target)` and applies `fun` per element: the collector of
  # the target's Collectable implementation. Building the target is the
  # function's own call (a `File.stream!/1` there is already an effect), so
  # the collector's applications are not unresolved calls. Read from Core:
  # the variables a case on a `Collectable.into/1` call binds as the second
  # element of its tuple pattern.
  defp collectors(core) do
    :cerl_trees.fold(
      fn node, acc ->
        if :cerl.type(node) == :case and collectable_into?(:cerl.case_arg(node)),
          do: Enum.reduce(:cerl.case_clauses(node), acc, &collector_var/2),
          else: acc
      end,
      MapSet.new(),
      core
    )
  end

  defp collectable_into?(node),
    do: :cerl.type(node) == :call and Core.call_mfa(node) == {Collectable, :into, 1}

  defp collector_var(clause, acc) do
    with [pattern] <- :cerl.clause_pats(clause),
         true <- :cerl.is_c_tuple(pattern),
         [_acc, fun] <- :cerl.tuple_es(pattern),
         true <- :cerl.is_c_var(fun) do
      MapSet.put(acc, :cerl.var_name(fun))
    else
      _other_pattern -> acc
    end
  end

  defp collector_apply?(node, collectors) do
    :cerl.type(node) == :apply and :cerl.is_c_var(:cerl.apply_op(node)) and
      MapSet.member?(collectors, :cerl.var_name(:cerl.apply_op(node)))
  end

  # The invocation a higher-order call records for an argument that is a
  # literal, not a function (`Enum.with_index(list, 1)`: the offset form):
  # nothing is applied there.
  defp data_argument?({_mfa, ordinal}, node) do
    with :call <- :cerl.type(node),
         invocations when invocations != [] <- HigherOrder.invocations(Core.call_mfa(node)),
         index when is_integer(index) <-
           Enum.find_index(Core.site_ordinals(node), &(&1 == ordinal)),
         {arg_index, _arity} <- Enum.at(invocations, index),
         arg when arg != nil <- Enum.at(:cerl.call_args(node), arg_index) do
      :cerl.is_literal(arg) and not is_function(:cerl.concrete(arg))
    else
      _not_a_literal_argument -> false
    end
  end

  defp closure_targets({:ok, closures}, _node, ctx) do
    Enum.flat_map(closures, fn
      {{_m, _f, _a} = defined_in, ordinal} when is_integer(ordinal) -> static(defined_in, ctx)
      {_m, _f, _a} = capture -> static(capture, ctx)
    end)
  end

  defp closure_targets(_any_or_unknown, node, _ctx),
    do: [unresolved("an application of a closure from outside the project", Core.line(node))]

  defp exported(graph, module, name, arity) do
    %ModuleNode{functions: functions} = Graph.module(graph, module)

    for {{^name, a}, %FunctionNode{kind: :def}} <- functions,
        arity == nil or a == arity,
        do: {module, name, a}
  end

  defp unresolved(text, line), do: {:unresolved, %{text: text, line: line}}

  # --- roles ------------------------------------------------------------------

  defp seeds(targets, effect?) do
    for {mfa, reached} <- targets, Enum.any?(reached, effect?), into: MapSet.new(), do: mfa
  end

  # Every function that reaches a seed through `{:fn, _}` edges `follow?`
  # allows: a backward search from the seeds, so recursion needs no special
  # case.
  defp reaching(seeds, targets, follow?) do
    callers =
      for {from, reached} <- targets,
          {:fn, to} <- reached,
          follow?.(from, to),
          reduce: %{} do
        acc -> Map.update(acc, to, [from], &[from | &1])
      end

    search(MapSet.to_list(seeds), seeds, callers)
  end

  defp search([], seen, _callers), do: seen

  defp search([mfa | rest], seen, callers) do
    new = callers |> Map.get(mfa, []) |> Enum.reject(&MapSet.member?(seen, &1))
    search(new ++ rest, Enum.into(new, seen), callers)
  end

  defp role(mfa, roots, local, reaches) do
    cond do
      MapSet.member?(roots, mfa) -> :framework
      MapSet.member?(local, mfa) -> :adapters
      MapSet.member?(reaches, mfa) -> :managers
      true -> :domain
    end
  end

  defp same_module?({module, _f, _a}, {module, _g, _b}), do: true
  defp same_module?(_from, _to), do: false

  defp count_unresolved(targets) do
    targets
    |> Map.values()
    |> Enum.map(fn reached -> Enum.count(reached, &match?({:unresolved, _}, &1)) end)
    |> Enum.sum()
  end

  defp no_core(%Graph{unreadable: unreadable}) do
    for %{module: module, reason: {:no_core, missing}} <- unreadable,
        {name, arity} <- missing,
        into: MapSet.new(),
        do: {module, name, arity}
  end

  # --- evidence -----------------------------------------------------------------

  # Breadth first from `mfa`, so the chain is a shortest one; ties go to the
  # first edge in sorted order, so it is stable.
  defp chain(targets, mfa, follow?, effect?),
    do: bfs([{mfa, [mfa]}], MapSet.new([mfa]), targets, follow?, effect?)

  defp bfs([], _seen, _targets, _follow?, _effect?), do: []

  defp bfs([{at, path} | queue], seen, targets, follow?, effect?) do
    reached = targets |> Map.get(at, []) |> Enum.sort()

    case Enum.find(reached, effect?) do
      nil ->
        next =
          for {:fn, to} <- reached,
              follow?.(at, to),
              not MapSet.member?(seen, to),
              do: {to, path ++ [to]}

        seen = Enum.into(next, seen, &elem(&1, 0))
        bfs(queue ++ next, seen, targets, follow?, effect?)

      effect ->
        path ++ [effect]
    end
  end
end
