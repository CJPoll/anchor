defmodule Anchor.Domain.Placement.Forwarders do
  @moduledoc """
  Inert hops, E5/F4 (DND-5461) — **Domain**, pure over the model's Core.

  ## A forwarder

  `forwarder/1` reads one function's Core Erlang. `M.f/n` is a forwarder when its
  Core is

      fun (V1, ..., Vn) -> call 'N':'g'(V1, ..., Vn)

  after peeling the compiler's wrapper: a function compiles to
  `fun (_0, ...) -> case <_0, ...> of <clauses>`, and the forwarder has exactly one
  clause besides the compiler's own `match_fail` clause, whose patterns are distinct
  variables, whose guard is `'true'` and whose body is one call with those variables
  in that order. A `let` that only renames a variable is peeled. `N` must differ from
  `M`: a hop inside one module is the AST rule `no_forwarding_function`'s. A repeated
  parameter needs no check of its own: Elixir compiles it to two variables and a
  guard. Any other
  shape (a literal or extra argument, a reordered one, a pattern, a guard, two
  clauses, a transforming pipe) is not a forwarder. `defdelegate` compiles to the
  same Core as a hand-written forwarder, so one reader covers both.

  ## Inert only when it crosses no boundary

  `boundary/3` answers why a hop from `M.f` to `N.g` is legal, or `:none`. In order:

    1. `N` is not a project module (a wrapper over a dependency or the standard
       library is an adapter seam): `:dependency`;
    2. `M` or `N` is not classified: `:unclassified` (the run already reports it;
       the hop is not judged inert);
    3. another bucket: `:bucket`; another context: `:context`; another OTP app:
       `:app`;
    4. another aggregate, when aggregates are declared (`Model.aggregates`, a module
       belonging to the aggregates that list it as owner or schema; two modules in
       none are in the same): `:aggregate`;
    5. `M` is an interface module and `N` is not (a facade forwarding to its
       interior): `:interface`;
    6. `M.f` implements a behaviour's callback (a project behaviour's, or an
       external one's the effect inference was given, `Effects.callbacks`): its
       signature is fixed by the behaviour: `:callback`.

  So Cody's decision 2 holds by construction: Framework to Manager to Adapter
  forwarding and a context facade's `defdelegate`s each cross a boundary. A boundary
  not on this list (a directory) does not make a hop legal.

  ## Proposals

  `proposals/1` is one `:inert_hop` proposal per inert forwarder that an author
  wrote (`Anchor.Domain.Placement.generated_function?/2` false, and not a
  default-argument function), proposed `{:inline, to}`. The evidence names the
  target and the static callers, or says `dynamic callers only` when no call names
  the forwarder (a dynamic call or none reaches it: it is still inert).
  """

  alias Anchor.Domain.Classification
  alias Anchor.Domain.Graph.Call
  alias Anchor.Domain.Graph.FunctionNode
  alias Anchor.Domain.Graph.ModuleNode
  alias Anchor.Domain.Model
  alias Anchor.Domain.Placement
  alias Anchor.Domain.Proposal
  alias Anchor.Domain.ViolationKey

  @type crossing ::
          :bucket
          | :context
          | :app
          | :dependency
          | :aggregate
          | :interface
          | :callback
          | :unclassified

  @doc "Whether `function`'s Core is a forwarder to another module; see the moduledoc."
  @spec forwarder(FunctionNode.t()) :: {:forwards, mfa()} | :no
  def forwarder(%FunctionNode{core: nil}), do: :no

  def forwarder(%FunctionNode{module: module, core: core}) do
    params = Enum.map(:cerl.fun_vars(core), &:cerl.var_name/1)

    case forwarded_call(:cerl.fun_body(core), params) do
      {^module, _name, _arity} -> :no
      {_other, _name, _arity} = mfa -> {:forwards, mfa}
      nil -> :no
    end
  end

  @doc "The boundary the hop `from` to `to` crosses, or `:none`; see the moduledoc."
  @spec boundary(Model.t(), mfa(), mfa()) :: :none | {:crosses, crossing()}
  def boundary(%Model{} = model, {from_module, _f, _a} = from, {to_module, _g, _b}) do
    from_class = Map.get(model.classification, from_module)
    to_class = Map.get(model.classification, to_module)

    cond do
      not Map.has_key?(model.graph.modules, to_module) -> {:crosses, :dependency}
      from_class == nil or to_class == nil -> {:crosses, :unclassified}
      true -> classified_boundary(model, from, from_class, to_class)
    end
  end

  @doc "The `:inert_hop` proposal of every inert forwarder of `model`, sorted by key."
  @spec proposals(Model.t()) :: [Proposal.t()]
  def proposals(%Model{graph: graph} = model) do
    callers = static_callers(graph.calls)

    for {module, %ModuleNode{functions: functions} = node} <- graph.modules,
        {{name, arity}, %FunctionNode{kind: kind} = function} <- functions,
        kind in [:def, :defp],
        not Placement.generated_function?(function, node),
        not defaults?(node, name, arity),
        {:forwards, to} <- [forwarder(function)],
        boundary(model, {module, name, arity}, to) == :none do
      proposal({module, name, arity}, to, Map.get(callers, {module, name, arity}, []))
    end
    |> Enum.sort_by(& &1.key)
  end

  # --- the forwarder's shape -------------------------------------------------------

  defp forwarded_call(body, params) do
    case :cerl.type(body) do
      :case -> case_forward(body, params)
      _other -> call_of(body, params, %{})
    end
  end

  # The wrapper: `case <params> of <one clause> <the compiler's match_fail> end`.
  defp case_forward(body, params) do
    with true <- vars(case_values(:cerl.case_arg(body))) == params,
         [clause] <- Enum.reject(:cerl.case_clauses(body), &compiler_generated?/1),
         pattern_vars when is_list(pattern_vars) <- vars(:cerl.clause_pats(clause)),
         true <- true_guard?(:cerl.clause_guard(clause)) do
      call_of(:cerl.clause_body(clause), pattern_vars, %{})
    else
      _not_a_forwarder -> nil
    end
  end

  defp case_values(arg) do
    if :cerl.type(arg) == :values, do: :cerl.values_es(arg), else: [arg]
  end

  defp vars(nodes) do
    if Enum.all?(nodes, &(:cerl.type(&1) == :var)),
      do: Enum.map(nodes, &:cerl.var_name/1),
      else: nil
  end

  defp compiler_generated?(clause), do: :compiler_generated in :cerl.get_ann(clause)

  defp true_guard?(guard), do: :cerl.is_literal(guard) and :cerl.concrete(guard) == true

  # A `let <X> = Y in Body` that only renames a variable is peeled; the call's
  # arguments must be the parameters, in order.
  defp call_of(body, params, renames) do
    case :cerl.type(body) do
      :let -> renaming_let(body, params, renames)
      :call -> forwarding_call(body, params, renames)
      _other -> nil
    end
  end

  defp renaming_let(body, params, renames) do
    with [var] <- :cerl.let_vars(body),
         [name] <- vars(case_values(:cerl.let_arg(body))) do
      renames = Map.put(renames, :cerl.var_name(var), Map.get(renames, name, name))
      call_of(:cerl.let_body(body), params, renames)
    else
      _not_a_rename -> nil
    end
  end

  defp forwarding_call(call, params, renames) do
    case vars(:cerl.call_args(call)) do
      nil -> nil
      args -> if Enum.map(args, &Map.get(renames, &1, &1)) == params, do: literal_mfa(call)
    end
  end

  defp literal_mfa(call) do
    module = :cerl.call_module(call)
    name = :cerl.call_name(call)

    if :cerl.is_literal(module) and :cerl.is_literal(name) and
         is_atom(:cerl.concrete(module)) and is_atom(:cerl.concrete(name)),
       do: {:cerl.concrete(module), :cerl.concrete(name), length(:cerl.call_args(call))}
  end

  # A function with default arguments: a lower arity of the same name is the
  # compiler's `super` call into it.
  defp defaults?(%ModuleNode{functions: functions}, name, arity) do
    Enum.any?(functions, fn {{other, lower}, %FunctionNode{clauses: clauses}} ->
      other == name and lower < arity and Enum.any?(clauses, &default_clause?(&1, name))
    end)
  end

  defp default_clause?({_meta, _args, _guards, {:super, meta, _args2}}, name),
    do: Keyword.get(meta, :default) == true and match?({_kind, ^name}, Keyword.get(meta, :super))

  defp default_clause?(_clause, _name), do: false

  # --- the boundary ----------------------------------------------------------------

  defp classified_boundary(model, from, %Classification{} = from_class, to_class) do
    cond do
      from_class.bucket != to_class.bucket ->
        {:crosses, :bucket}

      from_class.context != to_class.context ->
        {:crosses, :context}

      app(model, from_class) != app(model, to_class) ->
        {:crosses, :app}

      aggregates(model, from_class.module) != aggregates(model, to_class.module) ->
        {:crosses, :aggregate}

      from_class.interface? and not to_class.interface? ->
        {:crosses, :interface}

      callback?(model, from) ->
        {:crosses, :callback}

      true ->
        :none
    end
  end

  defp app(%Model{graph: graph}, %Classification{module: module, app: app}) do
    case Map.get(graph.modules, module) do
      %ModuleNode{app: node_app} -> node_app
      nil -> app
    end
  end

  defp aggregates(%Model{aggregates: index}, module) do
    schemas = if Map.has_key?(index.by_schema, module), do: [index.by_schema[module]], else: []
    Enum.sort(Enum.uniq(schemas ++ Map.get(index.owners, module, [])))
  end

  defp callback?(%Model{graph: graph} = model, {module, name, arity}) do
    %ModuleNode{behaviours: behaviours} = Map.fetch!(graph.modules, module)
    external = if model.effects, do: model.effects.callbacks, else: %{}

    Enum.any?(behaviours, fn behaviour ->
      {name, arity} in behaviour_callbacks(graph.modules[behaviour], behaviour, external)
    end)
  end

  defp behaviour_callbacks(%ModuleNode{callbacks: callbacks}, _behaviour, _external),
    do: callbacks

  defp behaviour_callbacks(nil, behaviour, external), do: Map.get(external, behaviour, [])

  # --- the proposal ----------------------------------------------------------------

  defp static_callers(calls) do
    calls
    |> Enum.filter(&static_caller?/1)
    |> Enum.group_by(& &1.to, & &1.from)
    |> Map.new(fn {to, froms} -> {to, froms |> Enum.uniq() |> Enum.sort()} end)
  end

  defp static_caller?(%Call{to: {_m, _f, _a}}), do: true
  defp static_caller?(%Call{}), do: false

  defp proposal({module, _name, _arity} = subject, to, callers) do
    %Proposal{
      level: :function,
      subject: subject,
      current: module,
      proposed: {:inline, to},
      rule: :no_inert_hop,
      reason: :inert_hop,
      evidence: ["forwards to #{ViolationKey.mfa(to)}", callers_text(callers)],
      key:
        Enum.join(
          ["no_inert_hop", "function", ViolationKey.mfa(subject), ViolationKey.mfa(to)],
          "|"
        )
    }
  end

  defp callers_text([]), do: "dynamic callers only"
  defp callers_text(callers), do: "callers: " <> Enum.map_join(callers, ", ", &ViolationKey.mfa/1)
end
