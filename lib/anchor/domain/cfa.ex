defmodule Anchor.Domain.Cfa do
  @moduledoc """
  Higher-order flow: a whole-program 0-CFA over Core Erlang — **Domain**, pure
  (DND-5497; the shared contract is the Anchor causal engine epic, section 13).

  For each apply site (`Anchor.Domain.Core`: `fun.(x)`, `apply(f, args)`, and
  the invocation inside `Enum.map(list, fun)` and the other functions
  `Anchor.Domain.HigherOrder` lists) it answers which closures can reach it:
  `{:ok, MapSet}` of closure ids, or `:any` when a value from outside the
  analysed world can. `:any` is counted, never dropped.

  ## Closures

    * a lambda, `{mfa, ordinal}`: the `fun` with that lambda ordinal
      (`Anchor.Domain.Core.label/1`) inside the function `mfa`. A `letrec`
      definition is one too;
    * a capture, `{module, name, arity}`: `&M.f/a` (`erlang:make_fun/3` with
      literal arguments, or a literal external fun) and `&f/a` (a function
      name used as a value).

  ## The analysis

  Monovariant (one abstract value per Core variable, per function return, per
  lambda return, per field slot; no call strings). An abstract value is the
  closures that may be the value, an `any` flag (a value from outside may be
  it) and a `constant` flag (an atom, a module name perhaps, or another
  constant may be it). It is reported as `:any` when
  the `any` flag is set: `any` absorbs at the report, but the closures beside
  it still flow, so a closure joined with an outside value still has its
  parameters and its escape tracked.

  Flow: let bindings, call arguments to the callee's parameters (every call
  of a project function, local or remote), return values, case, receive and
  try clause bindings, and the fields of containers. A container's fields are
  slots per allocation site and key (`Anchor.Domain.Cfa.Eval` lists them):
  one per literal atom map key, tuple position, list head and tail, plus a
  wildcard for a map key that is not a literal atom. A read of key `k` sees
  the `k` and wildcard slots of every allocation site the container may be; a
  read by a non-literal key sees every field. A map update reads through to
  the map it was built on. A read from a container that may come from outside
  is `any`.

  The design (DND-5497's Architecture page) chose one slot per container kind
  and key for the whole program. Measured on the fixtures, that makes every
  struct field read `any`, because the struct module's own generated
  `__struct__/1` writes outside values into the map wildcard slot; so slots
  are per allocation site here.

  Sources of `any`: a root's parameters (from the seed), the result of a call
  outside the project (anything not compiled into the graph, ETS, the process
  dictionary, `erlang:apply/3`, a call on a variable module), a `receive`
  binding (OTP 28 lowers `receive` to `recv_*` primops, whose results are
  `any`), a caught exception, a field read of an outside value.

  Escapes: a closure that reaches code the analysis cannot see escapes, and
  outside code may call it with anything, so its parameters become `any` and
  its return escapes too. A closure escapes when it is an argument of a call
  outside the project (a `send`, a `put`, an ETS insert, an
  `Anchor.Domain.HigherOrder` function, any library call except the type
  tests, comparisons and arithmetic in `@pure_erlang`), an argument of an
  `any` apply site, the return of a root, or a value stored in a container
  (any container may be handed to outside code, and its fields are not
  followed there). A `HigherOrder` invocation passes `any` arguments, which
  is the escape.

  A few library calls are read as container accesses instead of escapes:
  `erlang:element/2`, `maps:get/2,3`, `maps:put/3`, `Map.get/2,3`,
  `Map.fetch!/2`, `Map.put/3`. A struct field read `s.f` is a map pattern in
  Core, beside a clause for a module atom that calls
  `elixir_erl_pass:no_parens_remote/2`; that call is `any` only when the
  value may be outside or an atom.

  ## Roots

  `analyze/3` takes the roots as a seed: `%{mfa => :any | [param_value]}`,
  where a param value is `:any` or a `MapSet` of closure ids. A root's
  parameters start at those values and its return escapes. A seed must hold
  every function that code outside the analysed world calls (exported API,
  OTP callbacks, `Mix.Task.run/1`): one left out gets only what project calls
  pass it. A seed naming a function the graph does not hold raises. `default_seed/1`
  makes every exported function a root with `any` parameters (the open world;
  DND-5500 passes a tighter seed). A function in no seed gets only what
  project calls pass it.

  ## Termination

  A deterministic worklist over units (each function and each lambda body,
  plus one unit that applies escapes), in sorted order, re-running a unit when
  a value it read grew. Values only grow, over a finite lattice (the
  closures and slots are finite), so it terminates; it is also bounded by
  `:max_steps` unit runs (default 50 per unit, plus 1000). A run that hits the
  bound is not a result: every site and return is reported `:any` and
  `bound_hit?` is true, so a lost run never reads as resolved.

  Macros (`defmacro`) are compile-time code and are not analysed. Two Core
  variables of one function with the same name (two `fn`s that each bind
  `x@1`) share one abstract value, which over-approximates.
  """

  alias Anchor.Domain.Cfa.Eval
  alias Anchor.Domain.Cfa.Value
  alias Anchor.Domain.Core
  alias Anchor.Domain.Graph
  alias Anchor.Domain.Graph.FunctionNode
  alias Anchor.Domain.Graph.ModuleNode

  @steps_per_unit 50
  @steps_floor 1000

  defstruct sites: %{},
            returns: %{},
            counts: %{total: 0, resolved: 0, any: 0, by_function: %{}},
            steps: 0,
            bound_hit?: false

  @typedoc "A lambda `{mfa, ordinal}` or a capture `{module, name, arity}`."
  @type closure :: {mfa(), non_neg_integer()} | mfa()
  @type result :: {:ok, MapSet.t(closure())} | :any
  @type param_value :: :any | MapSet.t(closure())
  @type seed :: %{mfa() => :any | [param_value()]}
  @type counts :: %{
          total: non_neg_integer(),
          resolved: non_neg_integer(),
          any: non_neg_integer(),
          by_function: %{
            mfa() => %{
              total: non_neg_integer(),
              resolved: non_neg_integer(),
              any: non_neg_integer()
            }
          }
        }
  @type t :: %__MODULE__{
          sites: %{Core.site_id() => result()},
          returns: %{mfa() => result()},
          counts: counts(),
          steps: non_neg_integer(),
          bound_hit?: boolean()
        }

  @doc """
  Runs the 0-CFA over every `def`/`defp` of `graph` that has Core, with
  `seed` as the roots. `opts`: `:max_steps`, the bound on unit runs.
  """
  @spec analyze(Graph.t(), seed(), keyword()) :: t()
  def analyze(%Graph{} = graph, seed, opts \\ []) do
    program = program(graph, seed)

    max_steps =
      Keyword.get(opts, :max_steps, @steps_per_unit * map_size(program.units) + @steps_floor)

    {values, steps, bound_hit?} = solve(program, max_steps)
    report(program, values, steps, bound_hit?)
  end

  @doc "The closures reaching `site_id`, or `{:error, :unknown_site}`."
  @spec closures_at(t(), Core.site_id()) :: result() | {:error, :unknown_site}
  def closures_at(%__MODULE__{sites: sites}, site_id),
    do: Map.get(sites, site_id, {:error, :unknown_site})

  @doc "Every exported function with Core, as a root whose parameters are all `any`."
  @spec default_seed(Graph.t()) :: seed()
  def default_seed(%Graph{} = graph) do
    graph
    |> project_functions()
    |> Enum.filter(fn {_mfa, %FunctionNode{kind: kind}} -> kind == :def end)
    |> Map.new(fn {mfa, _node} -> {mfa, :any} end)
  end

  # --- the program --------------------------------------------------------------

  defp project_functions(%Graph{modules: modules}) do
    for {module, %ModuleNode{functions: functions}} <- modules,
        {{name, arity}, %FunctionNode{kind: kind, core: core} = node} <- functions,
        kind in [:def, :defp] and core != nil do
      {{module, name, arity}, node}
    end
    |> Enum.sort_by(&elem(&1, 0))
  end

  defp program(graph, seed) do
    functions =
      graph
      |> project_functions()
      |> Enum.map(fn {mfa, node} -> {mfa, Core.label(node.core)} end)

    lambdas =
      for {mfa, fun} <- functions, {ordinal, lambda} <- Core.lambdas(fun) do
        {{mfa, ordinal}, lambda}
      end

    known = MapSet.new(functions, &elem(&1, 0))
    roots = seed |> Map.keys() |> Enum.sort()

    case Enum.reject(roots, &MapSet.member?(known, &1)) do
      [] -> :ok
      unknown -> raise ArgumentError, unknown_roots(unknown)
    end

    %{
      units:
        Map.new(
          [{:escape, nil}] ++
            Enum.map(functions, fn {mfa, fun} -> {{:fun, mfa}, {mfa, fun, {:ret, mfa}}} end) ++
            Enum.map(lambdas, fn {{mfa, _ordinal} = id, fun} ->
              {{:lambda, id}, {mfa, fun, {:lret, id}}}
            end)
        ),
      closures:
        Map.new(
          Enum.map(functions, fn {mfa, fun} -> {mfa, closure_info(mfa, fun, {:ret, mfa})} end) ++
            Enum.map(lambdas, fn {{mfa, _ordinal} = id, fun} ->
              {id, closure_info(mfa, fun, {:lret, id})}
            end)
        ),
      letrecs: Map.new(functions, fn {mfa, fun} -> {mfa, letrec_names(mfa, fun)} end),
      sites: Map.new(functions, fn {mfa, fun} -> {mfa, Core.apply_sites(mfa, fun)} end),
      functions: Enum.map(functions, &elem(&1, 0)),
      roots: roots,
      seed: seed,
      exported_by_arity:
        graph
        |> project_functions()
        |> Enum.filter(fn {_mfa, node} -> node.kind == :def end)
        |> Enum.group_by(fn {{_m, _f, arity}, _node} -> arity end, &elem(&1, 0))
    }
  end

  defp unknown_roots(unknown) do
    "the seed names #{inspect(unknown)}, which the graph holds no def/defp with Core for. " <>
      "Fix: seed only functions of the graph (Cfa.default_seed/1 lists them)."
  end

  defp closure_info(mfa, fun, ret) do
    %{params: Enum.map(:cerl.fun_vars(fun), &var_node(mfa, &1)), ret: ret}
  end

  defp letrec_names(mfa, fun) do
    :cerl_trees.fold(
      fn node, acc ->
        if :cerl.is_c_letrec(node), do: letrec_defs(mfa, node, acc), else: acc
      end,
      %{},
      fun
    )
  end

  defp letrec_defs(mfa, node, acc) do
    Enum.reduce(:cerl.letrec_defs(node), acc, fn {fname, fun}, acc ->
      Map.update(
        acc,
        :cerl.var_name(fname),
        [{mfa, Core.lambda_ordinal(fun)}],
        &[{mfa, Core.lambda_ordinal(fun)} | &1]
      )
    end)
  end

  defp var_node(mfa, var), do: {:var, mfa, :cerl.var_name(var)}

  # --- the solver ----------------------------------------------------------------

  defp solve(program, max_steps) do
    values = seed_values(program)
    order = program.units |> Map.keys() |> Enum.sort()
    queue = :queue.from_list(order)
    loop(program, %{values: values, readers: %{}}, queue, MapSet.new(order), 0, max_steps)
  end

  defp seed_values(program) do
    Enum.reduce(program.seed, %{}, fn {mfa, spec}, values ->
      params = Map.fetch!(program.closures, mfa).params
      specs = seed_specs(mfa, spec, length(params))

      params
      |> Enum.zip(specs)
      |> Enum.reduce(values, fn {param, spec}, values ->
        Map.update(values, param, seed_value(spec), &Value.join(&1, seed_value(spec)))
      end)
    end)
  end

  defp seed_specs(_mfa, :any, arity), do: List.duplicate(:any, arity)
  defp seed_specs(_mfa, specs, arity) when length(specs) == arity, do: specs

  defp seed_specs(mfa, specs, arity) do
    raise ArgumentError,
          "the seed for #{inspect(mfa)} names #{length(List.wrap(specs))} parameter values; " <>
            "the function has #{arity}"
  end

  defp seed_value(:any), do: Value.any()
  defp seed_value(%MapSet{} = closures), do: Value.closures(closures)

  defp loop(program, state, queue, queued, steps, max_steps) do
    case :queue.out(queue) do
      {:empty, _queue} ->
        {state.values, steps, false}

      {{:value, _unit}, _queue} when steps >= max_steps ->
        {state.values, steps, true}

      {{:value, unit}, queue} ->
        queued = MapSet.delete(queued, unit)
        acc = run_unit(unit, program, state.values)
        {state, changed} = apply_writes(state, unit, acc)
        {queue, queued} = enqueue(state, changed, queue, queued)
        loop(program, state, queue, queued, steps + 1, max_steps)
    end
  end

  defp apply_writes(state, unit, acc) do
    readers =
      Enum.reduce(acc.reads, state.readers, fn node, readers ->
        Map.update(readers, node, MapSet.new([unit]), &MapSet.put(&1, unit))
      end)

    {values, changed} =
      acc.writes
      |> Enum.sort()
      |> Enum.reduce({state.values, []}, fn {node, value}, {values, changed} ->
        old = Map.get(values, node, Value.bottom())
        new = Value.join(old, value)
        if new == old, do: {values, changed}, else: {Map.put(values, node, new), [node | changed]}
      end)

    {%{state | values: values, readers: readers}, changed}
  end

  defp enqueue(state, changed, queue, queued) do
    changed
    |> Enum.flat_map(&(state.readers |> Map.get(&1, MapSet.new()) |> MapSet.to_list()))
    |> Enum.uniq()
    |> Enum.sort()
    |> Enum.reduce({queue, queued}, fn unit, {queue, queued} ->
      if MapSet.member?(queued, unit),
        do: {queue, queued},
        else: {:queue.in(unit, queue), MapSet.put(queued, unit)}
    end)
  end

  defp run_unit(:escape, program, values), do: Eval.run_escape(program, values)

  defp run_unit(unit, program, values) do
    {mfa, fun, ret} = Map.fetch!(program.units, unit)
    Eval.run_function(mfa, fun, ret, program, values)
  end

  # --- the report ----------------------------------------------------------------

  defp report(program, values, steps, bound_hit?) do
    present = fn node ->
      if bound_hit?, do: :any, else: Value.present(Map.get(values, node, Value.bottom()))
    end

    sites =
      for {_mfa, sites} <- program.sites, {site_id, _node} <- sites, into: %{} do
        {site_id, present.({:site, site_id})}
      end

    %__MODULE__{
      sites: sites,
      returns: Map.new(program.functions, &{&1, present.({:ret, &1})}),
      counts: counts(program, sites),
      steps: steps,
      bound_hit?: bound_hit?
    }
  end

  defp counts(program, sites) do
    by_function =
      for {mfa, function_sites} <- program.sites, function_sites != [], into: %{} do
        {mfa,
         tally(Enum.map(function_sites, fn {site_id, _node} -> Map.fetch!(sites, site_id) end))}
      end

    sites |> Map.values() |> tally() |> Map.put(:by_function, by_function)
  end

  defp tally(results) do
    any = Enum.count(results, &(&1 == :any))
    %{total: length(results), resolved: length(results) - any, any: any}
  end
end
