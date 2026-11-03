defmodule Anchor.Domain.Demand.Transfer do
  @moduledoc """
  One backward pass over one function's Core Erlang — **Domain**, pure
  (DND-5498). `function/2` walks the body from its result, which is always
  demanded in full (R2), towards its parameters, and returns the demand
  (`Anchor.Domain.Demand.Lattice`) on each parameter, given the summaries of
  the functions and lambdas it calls (`env`). `Anchor.Domain.Demand` runs it
  to a fixpoint over the call graph.

  ## The walk

  `walk(node, demand)` gives the demand `demand` on the value of `node` and
  adds what that makes of every variable of the function. A node walked with
  `:absent` is still walked, so an effect inside a discarded expression
  counts.

    * `let x = e1 in e2`: `e2` first, then `e1` with what `e2` demands of `x`.
      `do e1 e2` (a sequence) walks `e1` with `:absent`.
    * `case e of clauses`: each clause body with the demand, each guard but a
      literal `true` in full, then `e` with the join of what each clause's
      patterns demand: a variable what its body and guard demand of it, a
      tuple or a map with literal atom keys its fields, any other pattern
      (a literal, a list, a binary, a map with another key) in full. Matching
      is a use.
    * A call of a project function or an apply of a closure: each argument
      gets the callee's summary for that parameter, joined over every closure
      the 0-CFA (`Anchor.Domain.Cfa`) resolves the site to. An `:any` site
      demands every argument in full.
    * A call of an effect (`Anchor.Domain.EffectPrimitives`) or of a function
      that calls an argument (`Anchor.Domain.HigherOrder`): every argument in
      full, precisely. A pure BIF (`Anchor.Domain.PureCalls`, an `:erlang`
      row): every argument in full when the result is used, else none. A
      pure library module's function: every argument in full (it may call a
      function argument `HigherOrder` has no row for, so a missing row costs
      precision, never soundness). A type test (`is_map/1`) uses its
      argument for its shape alone (`Lattice.shape/0`). Reads of a literal
      field (`erlang:element/2`, `maps:get/2,3`, `Map.get/2,3`,
      `Map.fetch!/2`) demand that field; `elixir_erl_pass:no_parens_remote/2`
      (the other half of `m.x`, which calls `m:x()` on a module atom) uses
      field `x` of its subject even when its result is unused. Any other call
      (a library call not in a table, a call on a variable module, `apply/3`
      to a target the Core does not name) demands every argument in full and
      is recorded as a reason the function may be imprecise. `apply(f,
      list)` is an apply site: the list is used when a resolved closure uses
      a parameter.
    * Inside a `try`'s protected expression or a `catch` a raise is
      observable: whatever a call, a map update, a binary or a failed match
      raises carries its values to the handler. So there every call (of a
      library, of a project function, of a closure, `apply(f, list)`) uses
      every argument in full, and a map, a binary and a `match_fail` payload
      use their parts in full. A raise outside any `try` is not a use: a
      caller's handler is not followed, and a caller's call inside its own
      `try` uses every argument by this rule.
    * A `fun` whose value is used: its body in full, so what it captures is
      used. A `letrec` definition (a receive or comprehension loop) is
      walked in full.
    * A map key (`%{^k => v}`) or a bitstring size (`size(n)`) inside a
      pattern is read in full.
    * A tuple, list or map built with demand `d`: each component gets `d`'s
      demand on its key (`Lattice.at/2`); a list element or a field under a
      key that is not a literal atom gets everything or nothing.
    * `primop match_fail(...)`: nothing. It is the compiler's report of a
      failed match (`function_clause`, `case_clause`, `badmatch`), and every
      function's Core ends in one that holds every parameter; reading it as a
      use would make every parameter used. A raise the program writes
      (`raise`, `throw`, `exit`, `erlang:error`) is an effect.

  ## Modes

  `env.mode` is `:sound` (above) or `:optimistic`, in which an `:any` apply
  site and an unknown call demand nothing of their arguments. A parameter
  whose demand differs between the two depends on code the analysis cannot
  see: `Anchor.Domain.Demand` reports it as imprecise.

  ## Passes

  For each parameter, the `{callee, index}` pairs it is passed to unchanged
  (a variable bound to it, through `let` and variable patterns), where
  `callee` is a project function's mfa or a lambda id `{mfa, ordinal}`
  (DND-5470 rebuilds the chain of calls that drops a parameter from them).
  """

  alias Anchor.Domain.Cfa
  alias Anchor.Domain.Core
  alias Anchor.Domain.Demand.Lattice
  alias Anchor.Domain.EffectPrimitives
  alias Anchor.Domain.HigherOrder
  alias Anchor.Domain.PureCalls

  @type_tests ~w(is_atom is_binary is_bitstring is_boolean is_float is_function is_integer
                 is_list is_map is_number is_pid is_port is_reference is_tuple)a

  # Field reads: `{index of the container, index of the key, index of the default}`.
  @field_reads %{
    {:maps, :get, 2} => {1, 0, nil},
    {:maps, :get, 3} => {1, 0, 2},
    {Map, :get, 2} => {0, 1, nil},
    {Map, :get, 3} => {0, 1, 2},
    {Map, :fetch!, 2} => {0, 1, nil}
  }

  # Field writes: `{index of the map, index of the key, index of the value}`.
  @field_writes %{
    {:maps, :put, 3} => {2, 0, 1},
    {Map, :put, 3} => {0, 1, 2}
  }

  @typedoc "A function's mfa, or a lambda `{mfa, ordinal}`."
  @type closure :: Cfa.closure()

  @typedoc "Why a demand may be over-approximated: code the analysis cannot see."
  @type reason ::
          {:any_apply, Core.site_id()}
          | {:unknown_call, mfa()}
          | {:dynamic_call, arity()}
          | {:dynamic_apply, Core.site_id() | mfa()}
          | {:unknown_closure, closure()}

  @type env :: %{
          required(:mfa) => mfa(),
          required(:mode) => :sound | :optimistic,
          required(:summaries) => %{closure() => [Lattice.t()]},
          required(:cfa) => Cfa.t() | nil,
          required(:effects) => [Anchor.Domain.FunctionRef.t()]
        }

  @type result :: %{
          params: [Lattice.t()],
          passes: [[{closure(), non_neg_integer()}]],
          lambdas: %{non_neg_integer() => [Lattice.t()]},
          reasons: MapSet.t(reason()),
          callees: MapSet.t(closure())
        }

  @doc """
  The backward pass over `core_fun`, the labelled (`Anchor.Domain.Core.label/1`)
  Core `c_fun` of `env.mfa`: the demand on each parameter and the parameters'
  passes, the demand on each of its lambdas' parameters (by lambda ordinal),
  the reasons met (`:sound` mode records them) and the closures it called
  that `env.summaries` holds. A closure `env.summaries` lacks is a library
  function, or fails closed as `{:unknown_closure, id}`.
  """
  @spec function(:cerl.cerl(), env()) :: result()
  def function(core_fun, env) do
    ctx = env |> Map.put(:letrecs, letrecs(core_fun, env.mfa)) |> Map.put(:protected?, false)
    {params, passes, st} = run(core_fun, new_state(), ctx)

    {lambdas, st} =
      core_fun
      |> Core.lambdas()
      |> Enum.map_reduce(st, fn {ordinal, lambda}, st ->
        {lambda_params, _passes, lambda_st} = run(lambda, new_state(), ctx)
        {{ordinal, lambda_params}, merge_findings(st, lambda_st)}
      end)

    %{
      params: params,
      passes: passes,
      lambdas: Map.new(lambdas),
      reasons: st.reasons,
      callees: st.callees
    }
  end

  defp run(fun, st, ctx) do
    st = walk(:cerl.fun_body(fun), :all, st, ctx)
    names = Enum.map(:cerl.fun_vars(fun), &:cerl.var_name/1)
    params = Enum.map(names, &demand_of(st, &1))
    passes = Enum.map(names, &(st.passes |> Map.get(&1, MapSet.new()) |> Enum.sort()))
    {params, passes, st}
  end

  defp letrecs(core_fun, mfa) do
    :cerl_trees.fold(
      fn node, acc ->
        if :cerl.is_c_letrec(node) do
          Enum.reduce(:cerl.letrec_defs(node), acc, fn {fname, fun}, acc ->
            Map.put(acc, :cerl.var_name(fname), {mfa, Core.lambda_ordinal(fun)})
          end)
        else
          acc
        end
      end,
      %{},
      core_fun
    )
  end

  # --- state -----------------------------------------------------------------------

  defp new_state, do: %{vars: %{}, passes: %{}, reasons: MapSet.new(), callees: MapSet.new()}

  defp merge_findings(st, other),
    do: %{
      st
      | reasons: MapSet.union(st.reasons, other.reasons),
        callees: MapSet.union(st.callees, other.callees)
    }

  defp demand_of(st, name), do: Map.get(st.vars, name, :absent)

  defp need(st, _name, :absent), do: st

  defp need(st, name, demand),
    do: %{st | vars: Map.update(st.vars, name, demand, &Lattice.join(&1, demand))}

  defp reason(st, %{mode: :sound}, reason), do: %{st | reasons: MapSet.put(st.reasons, reason)}
  defp reason(st, _ctx, _reason), do: st

  # The passes of `to` (a variable bound to `from`) are passes of `from` too.
  defp alias_passes(st, from, to) do
    case Map.get(st.passes, to) do
      nil -> st
      passes -> %{st | passes: Map.update(st.passes, from, passes, &MapSet.union(&1, passes))}
    end
  end

  defp record_pass(st, arg, callee, index) do
    case plain_var(arg) do
      nil ->
        st

      name ->
        pass = MapSet.new([{callee, index}])
        %{st | passes: Map.update(st.passes, name, pass, &MapSet.union(&1, pass))}
    end
  end

  # The name of a variable node that is no function name, else nil.
  defp plain_var(node) do
    if :cerl.is_c_var(node) and not :cerl.is_c_fname(node), do: :cerl.var_name(node)
  end

  defp spread(:absent), do: :absent
  defp spread(_demand), do: :all

  # --- the walk --------------------------------------------------------------------

  defp walk(node, demand, st, ctx) do
    case :cerl.type(node) do
      :literal ->
        st

      :var ->
        variable(node, demand, st)

      :fun ->
        lambda(node, demand, st, ctx)

      :let ->
        let(node, demand, st, ctx)

      :letrec ->
        letrec(node, demand, st, ctx)

      :seq ->
        seq(node, demand, st, ctx)

      :case ->
        case_of(node, demand, st, ctx)

      :receive ->
        receive_of(node, demand, st, ctx)

      :try ->
        try_of(node, demand, st, ctx)

      :catch ->
        walk(:cerl.catch_body(node), demand, st, %{ctx | protected?: true})

      :apply ->
        apply_of(node, st, ctx)

      :call ->
        call(node, demand, st, ctx)

      :primop ->
        primop(node, st, ctx)

      :tuple ->
        tuple(node, demand, st, ctx)

      :map ->
        map(node, demand, st, ctx)

      :values ->
        walk_all(:cerl.values_es(node), demand, st, ctx)

      # A cons, a binary, and any node this walk has no rule for: its parts
      # are used in full when it is used, or inside a try (a binary can raise).
      _other ->
        walk_all(
          node |> :cerl.subtrees() |> List.flatten(),
          spread(protected(demand, ctx)),
          st,
          ctx
        )
    end
  end

  defp walk_all(nodes, demand, st, ctx), do: Enum.reduce(nodes, st, &walk(&1, demand, &2, ctx))

  defp variable(node, demand, st) do
    case plain_var(node) do
      # A function name used as a value: a capture, followed at its apply site.
      nil -> st
      name -> need(st, name, demand)
    end
  end

  defp lambda(node, demand, st, ctx) do
    if Lattice.used?(demand) do
      names = Enum.map(:cerl.fun_vars(node), &:cerl.var_name/1)
      body_ctx = %{ctx | protected?: false}
      {:ok, st} = scoped(st, names, &{:ok, walk(:cerl.fun_body(node), :all, &1, body_ctx)})
      st
    else
      st
    end
  end

  # Runs `fun` on `st` with `names` bound afresh (Core variables are lexically
  # scoped: a clause or a `let` may bind a name an enclosing scope also
  # binds), and gives the outer bindings of `names` back afterwards. `fun`
  # returns `{result, st}`, reading what it needs of `names` before the
  # outer bindings come back.
  defp scoped(st, names, fun) do
    saved_vars = Map.take(st.vars, names)
    saved_passes = Map.take(st.passes, names)
    inner = %{st | vars: Map.drop(st.vars, names), passes: Map.drop(st.passes, names)}
    {result, st} = fun.(inner)

    {result,
     %{
       st
       | vars: st.vars |> Map.drop(names) |> Map.merge(saved_vars),
         passes: st.passes |> Map.drop(names) |> Map.merge(saved_passes)
     }}
  end

  defp let(node, demand, st, ctx) do
    bind(:cerl.let_vars(node), :cerl.let_arg(node), st, ctx, fn st ->
      walk(:cerl.let_body(node), demand, st, ctx)
    end)
  end

  # Walks the scope of `vars` (`body`), then `arg` with what the scope
  # demanded of `vars` (one value per variable when `arg` is a `values` node
  # of that size, else one value for them all).
  defp bind(vars, arg, st, ctx, body) do
    names = Enum.map(vars, &:cerl.var_name/1)
    from = plain_var(arg)

    {demands, st} =
      scoped(st, names, fn st ->
        st = body.(st)

        st =
          case names do
            [name] when from != nil -> alias_passes(st, from, name)
            _other -> st
          end

        {Enum.map(names, &demand_of(st, &1)), st}
      end)

    walk_parts(arg, demands, st, ctx)
  end

  defp walk_parts(arg, demands, st, ctx) do
    parts = if :cerl.is_c_values(arg), do: :cerl.values_es(arg), else: [arg]

    if length(parts) == length(demands) do
      parts
      |> Enum.zip(demands)
      |> Enum.reduce(st, fn {part, d}, st -> walk(part, d, st, ctx) end)
    else
      walk(arg, Lattice.joins(demands), st, ctx)
    end
  end

  defp letrec(node, demand, st, ctx) do
    st = walk(:cerl.letrec_body(node), demand, st, ctx)

    Enum.reduce(:cerl.letrec_defs(node), st, fn {_fname, fun}, st ->
      lambda(fun, :all, st, ctx)
    end)
  end

  defp seq(node, demand, st, ctx) do
    st = walk(:cerl.seq_body(node), demand, st, ctx)
    walk(:cerl.seq_arg(node), :absent, st, ctx)
  end

  defp case_of(node, demand, st, ctx) do
    clauses = :cerl.case_clauses(node)
    arg = :cerl.case_arg(node)
    parts = if :cerl.is_c_values(arg), do: :cerl.values_es(arg), else: [arg]

    if clauses != [] and Enum.all?(clauses, &(length(:cerl.clause_pats(&1)) == length(parts))) do
      {columns, st} = Enum.map_reduce(clauses, st, &clause(&1, parts, demand, &2, ctx))

      columns
      |> Enum.zip_with(&Lattice.joins/1)
      |> then(&Enum.zip(parts, &1))
      |> Enum.reduce(st, fn {part, part_demand}, st -> walk(part, part_demand, st, ctx) end)
    else
      {_columns, st} = Enum.map_reduce(clauses, st, &clause(&1, [], demand, &2, ctx))
      walk(arg, :all, st, ctx)
    end
  end

  # One clause: its body and guard in the scope of its pattern variables.
  # Returns what each pattern demands of the value it matches.
  defp clause(clause, parts, demand, st, ctx) do
    patterns = :cerl.clause_pats(clause)
    names = patterns |> :cerl.pat_list_vars() |> Enum.map(&:cerl.var_name/1)

    scoped(st, names, fn st ->
      st = walk(:cerl.clause_body(clause), demand, st, ctx)
      guard = :cerl.clause_guard(clause)

      st =
        if :cerl.is_literal(guard) and :cerl.concrete(guard) == true,
          do: st,
          else: walk(guard, :all, st, ctx)

      st = walk_all(pattern_expressions(patterns), :all, st, ctx)

      st =
        patterns
        |> Enum.zip(parts)
        |> Enum.reduce(st, fn {pattern, part}, st -> pattern_passes(pattern, part, st) end)

      {Enum.map(patterns, &pattern_demand(&1, st)), st}
    end)
  end

  # The expressions inside patterns that are no pattern variable: a map key
  # (`%{^k => v}`) and a bitstring size (`<<x::binary-size(n)>>`). Matching
  # reads them in full.
  defp pattern_expressions(patterns) do
    Enum.flat_map(patterns, fn pattern ->
      :cerl_trees.fold(
        fn node, acc ->
          case :cerl.type(node) do
            :map_pair -> [:cerl.map_pair_key(node) | acc]
            :bitstr -> [:cerl.bitstr_size(node) | acc]
            _other -> acc
          end
        end,
        [],
        pattern
      )
    end)
  end

  defp pattern_passes(pattern, part, st) do
    case {pattern_var(pattern), plain_var(part)} do
      {nil, _from} -> st
      {_name, nil} -> st
      {name, from} -> alias_passes(st, from, name)
    end
  end

  defp pattern_var(pattern) do
    case :cerl.type(pattern) do
      :var -> :cerl.var_name(pattern)
      :alias -> :cerl.var_name(:cerl.alias_var(pattern))
      _other -> nil
    end
  end

  # What matching `pattern` demands of the value it matches.
  defp pattern_demand(pattern, st) do
    case :cerl.type(pattern) do
      :var ->
        demand_of(st, :cerl.var_name(pattern))

      :alias ->
        Lattice.join(
          demand_of(st, :cerl.var_name(:cerl.alias_var(pattern))),
          pattern_demand(:cerl.alias_pat(pattern), st)
        )

      :tuple ->
        pattern
        |> :cerl.tuple_es()
        |> Enum.with_index()
        |> Map.new(fn {element, index} -> {index, pattern_demand(element, st)} end)
        |> used()

      :map ->
        map_pattern_demand(pattern, st)

      # A literal compares the whole value; a list or a binary is read in full.
      _other ->
        :all
    end
  end

  defp map_pattern_demand(pattern, st) do
    pairs = :cerl.map_es(pattern)

    if Enum.all?(pairs, &(literal_atom(:cerl.map_pair_key(&1)) != nil)) do
      pairs
      |> Map.new(
        &{literal_atom(:cerl.map_pair_key(&1)), pattern_demand(:cerl.map_pair_val(&1), st)}
      )
      |> used()
    else
      :all
    end
  end

  defp used(fields), do: Lattice.bound({:used, fields})

  defp literal_atom(node) do
    if :cerl.is_literal(node) and is_atom(:cerl.concrete(node)), do: :cerl.concrete(node)
  end

  # OTP 28 Core has no receive node (a letrec over recv_* primops); an older
  # one: each clause body, the timeout in full, the after action.
  defp receive_of(node, demand, st, ctx) do
    {_columns, st} =
      Enum.map_reduce(:cerl.receive_clauses(node), st, &clause(&1, [], demand, &2, ctx))

    st = walk(:cerl.receive_timeout(node), :all, st, ctx)
    walk(:cerl.receive_action(node), demand, st, ctx)
  end

  defp try_of(node, demand, st, ctx) do
    evars = Enum.map(:cerl.try_evars(node), &:cerl.var_name/1)
    {:ok, st} = scoped(st, evars, &{:ok, walk(:cerl.try_handler(node), demand, &1, ctx)})

    # Inside the protected expression a raise is observable (the handler sees
    # it), so a call there uses its arguments even when its result is unused.
    bind(:cerl.try_vars(node), :cerl.try_arg(node), st, %{ctx | protected?: true}, fn st ->
      walk(:cerl.try_body(node), demand, st, ctx)
    end)
  end

  defp primop(node, st, ctx) do
    # A failed match inside a try reaches the handler with its value.
    demand =
      if :cerl.atom_val(:cerl.primop_name(node)) == :match_fail,
        do: protected(:absent, ctx),
        else: :all

    walk_all(:cerl.primop_args(node), demand, st, ctx)
  end

  defp tuple(node, demand, st, ctx) do
    node
    |> :cerl.tuple_es()
    |> Enum.with_index()
    |> Enum.reduce(st, fn {element, index}, st ->
      walk(element, Lattice.at(demand, index), st, ctx)
    end)
  end

  defp map(node, demand, st, ctx) do
    # An update of a key that must exist (`%{m | k: v}`) can raise.
    demand = protected(demand, ctx)
    st = walk(:cerl.map_arg(node), demand, st, ctx)

    Enum.reduce(:cerl.map_es(node), st, fn pair, st ->
      key = :cerl.map_pair_key(pair)

      case literal_atom(key) do
        nil -> walk_all([key, :cerl.map_pair_val(pair)], spread(demand), st, ctx)
        atom -> walk(:cerl.map_pair_val(pair), Lattice.at(demand, atom), st, ctx)
      end
    end)
  end

  # --- applies and calls -----------------------------------------------------------

  defp apply_of(node, st, ctx) do
    operator = :cerl.apply_op(node)
    args = :cerl.apply_args(node)

    if :cerl.is_c_fname(operator) do
      {name, arity} = fname = :cerl.var_name(operator)
      closure = Map.get(ctx.letrecs, fname, {elem(ctx.mfa, 0), name, arity})
      call_closures([closure], args, st, ctx)
    else
      st = walk(operator, :all, st, ctx)

      case Core.site_ordinals(node) do
        # Unlabelled Core: no site to resolve, so fail closed.
        [] -> unknown_args(args, {:any_apply, {ctx.mfa, nil}}, st, ctx)
        ordinals -> Enum.reduce(ordinals, st, &apply_site({ctx.mfa, &1}, args, &2, ctx))
      end
    end
  end

  defp apply_site(site_id, args, st, ctx) do
    case resolve(ctx.cfa, site_id) do
      {:ok, closures} -> call_closures(Enum.sort(closures), args, st, ctx)
      :any -> unknown_args(args, {:any_apply, site_id}, st, ctx)
    end
  end

  # A site the 0-CFA does not hold (or no 0-CFA at all) is `:any`: fail closed.
  defp resolve(nil, _site_id), do: :any

  defp resolve(cfa, site_id) do
    case Cfa.closures_at(cfa, site_id) do
      {:ok, closures} -> {:ok, closures}
      _any_or_unknown -> :any
    end
  end

  # Each argument gets the join over `closures` of their summary for its
  # parameter. A closure `env.summaries` lacks is a library capture.
  defp call_closures(closures, args, st, ctx) do
    {known, library} = Enum.split_with(closures, &Map.has_key?(ctx.summaries, &1))
    st = %{st | callees: MapSet.union(st.callees, MapSet.new(known))}
    st = Enum.reduce(library, st, &library_closure(&1, args, &2, ctx))
    arity = length(args)

    args
    |> Enum.with_index()
    |> Enum.reduce(st, fn {arg, index}, st ->
      # A summary assumes no handler sees a raise; inside a try or a catch
      # one does, so the callee's every argument is used there.
      demand =
        known
        |> Enum.map(&param_demand(Map.fetch!(ctx.summaries, &1), index, arity))
        |> Lattice.joins()
        |> protected_call(known, ctx)

      st = Enum.reduce(known, st, &record_pass(&2, arg, &1, index))
      walk(arg, demand, st, ctx)
    end)
  end

  # A closure of another arity raises badarity: it uses nothing.
  defp param_demand(params, index, arity) when length(params) == arity, do: Enum.at(params, index)
  defp param_demand(_params, _index, _arity), do: :absent

  defp library_closure({module, name, arity} = mfa, args, st, ctx)
       when is_atom(module) and is_atom(name) and is_integer(arity) do
    if EffectPrimitives.effect?(mfa, ctx.effects) or PureCalls.pure?(mfa),
      do: walk_all(args, :all, st, ctx),
      else: unknown_args(args, {:unknown_call, mfa}, st, ctx)
  end

  defp library_closure(closure, args, st, ctx),
    do: unknown_args(args, {:unknown_closure, closure}, st, ctx)

  defp unknown_args(args, why, st, %{mode: :sound} = ctx),
    do: args |> walk_all(:all, st, ctx) |> reason(ctx, why)

  defp unknown_args(args, _why, st, ctx), do: walk_all(args, :absent, st, ctx)

  defp call(node, demand, st, ctx) do
    args = :cerl.call_args(node)
    demand = protected(demand, ctx)

    case Core.call_mfa(node) do
      nil ->
        st = walk_all([:cerl.call_module(node), :cerl.call_name(node)], :all, st, ctx)
        unknown_args(args, {:dynamic_call, length(args)}, st, ctx)

      {:erlang, :apply, 2} ->
        apply_list(node, args, st, ctx)

      mfa ->
        protected_mfa(mfa, args, demand, st, ctx)
    end
  end

  # Inside a try every call uses every argument in full: whatever it raises
  # (a KeyError holding the map, a badarg holding its arguments) reaches the
  # handler. A project call keeps its passes (`call_closures/4` applies the
  # same rule through `protected_call/3`).
  defp protected_mfa(mfa, args, _demand, st, %{protected?: true} = ctx) do
    if Map.has_key?(ctx.summaries, mfa),
      do: call_closures([mfa], args, st, ctx),
      else: walk_all(args, :all, st, ctx)
  end

  defp protected_mfa(mfa, args, demand, st, ctx), do: call_mfa(mfa, args, demand, st, ctx)

  # Inside a `try` or a `catch` a call that can raise is observable even when
  # its result is not used: it is demanded in full there.
  defp protected(_demand, %{protected?: true}), do: :all
  defp protected(demand, _ctx), do: demand

  defp protected_call(_demand, [_closure | _rest], %{protected?: true}), do: :all
  defp protected_call(demand, _closures, _ctx), do: demand

  # `apply(f, list)`: an apply site whose arguments are the list's elements.
  # The list is used when any closure the site resolves to uses a parameter.
  defp apply_list(node, [function, list], st, ctx) do
    st = walk(function, :all, st, ctx)

    case Core.site_ordinals(node) do
      [] -> unknown_args([list], {:any_apply, {ctx.mfa, nil}}, st, ctx)
      ordinals -> Enum.reduce(ordinals, st, &apply_list_site({ctx.mfa, &1}, list, &2, ctx))
    end
  end

  defp apply_list_site(site_id, list, st, ctx) do
    case resolve(ctx.cfa, site_id) do
      {:ok, closures} ->
        {known, library} = Enum.split_with(Enum.sort(closures), &Map.has_key?(ctx.summaries, &1))
        st = %{st | callees: MapSet.union(st.callees, MapSet.new(known))}
        st = Enum.reduce(library, st, &library_closure(&1, [list], &2, ctx))

        used? =
          Enum.any?(known, &Enum.any?(Map.fetch!(ctx.summaries, &1), fn d -> d != :absent end))

        walk(list, protected_call(if(used?, do: :all, else: :absent), known, ctx), st, ctx)

      :any ->
        unknown_args([list], {:any_apply, site_id}, st, ctx)
    end
  end

  defp call_mfa(mfa, args, demand, st, ctx) do
    cond do
      EffectPrimitives.effect?(mfa, ctx.effects) -> walk_all(args, :all, st, ctx)
      Map.has_key?(ctx.summaries, mfa) -> call_closures([mfa], args, st, ctx)
      HigherOrder.invocations(mfa) != [] -> walk_all(args, :all, st, ctx)
      Map.has_key?(@field_reads, mfa) -> field_read(mfa, args, demand, st, ctx)
      Map.has_key?(@field_writes, mfa) -> field_write(mfa, args, demand, st, ctx)
      true -> other_call(mfa, args, demand, st, ctx)
    end
  end

  # `m.x`'s other half: when `m` is a module atom this runs `m:x()`, which may
  # have an effect, so the subject is used (for field `x` only) even when the
  # result is not.
  defp other_call({:elixir_erl_pass, :no_parens_remote, 2}, [subject, key], _demand, st, ctx) do
    st = walk(key, :all, st, ctx)

    field =
      case literal_atom(key) do
        nil -> :all
        atom -> Lattice.field(atom, :all)
      end

    walk(subject, field, st, ctx)
  end

  defp other_call({:erlang, :element, 2}, [index, tuple], demand, st, ctx) do
    st = walk(index, spread(demand), st, ctx)

    field =
      case literal_position(index) do
        nil -> spread(demand)
        position -> if Lattice.used?(demand), do: Lattice.field(position, demand), else: :absent
      end

    walk(tuple, field, st, ctx)
  end

  defp other_call({:erlang, name, 1}, [arg], demand, st, ctx) when name in @type_tests,
    do: walk(arg, if(Lattice.used?(demand), do: Lattice.shape(), else: :absent), st, ctx)

  defp other_call({:erlang, :apply, 3} = mfa, [module, name, _list] = args, _demand, st, ctx) do
    st = walk_all(args, :all, st, ctx)

    if literal_atom(module) != nil and literal_atom(name) != nil,
      do: st,
      else: reason(st, ctx, {:dynamic_apply, mfa})
  end

  # A BIF row of `PureCalls` takes no function, so its arguments matter only
  # through its result. A module row may take one that `HigherOrder` lacks a
  # row for (`MapSet.filter/2`), whose effects run even when the result is
  # unused, so its arguments are used in full: a missing row costs precision,
  # never soundness.
  defp other_call(mfa, args, demand, st, ctx) do
    cond do
      not PureCalls.pure?(mfa) -> unknown_args(args, {:unknown_call, mfa}, st, ctx)
      elem(mfa, 0) == :erlang -> walk_all(args, spread(demand), st, ctx)
      true -> walk_all(args, :all, st, ctx)
    end
  end

  defp field_read(mfa, args, demand, st, ctx) do
    {map_index, key_index, default_index} = Map.fetch!(@field_reads, mfa)
    key = Enum.at(args, key_index)
    st = walk(key, spread(demand), st, ctx)

    st =
      if default_index, do: walk(Enum.at(args, default_index), demand, st, ctx), else: st

    field =
      case literal_atom(key) do
        nil -> spread(demand)
        atom -> if Lattice.used?(demand), do: Lattice.field(atom, demand), else: :absent
      end

    walk(Enum.at(args, map_index), field, st, ctx)
  end

  # A map built by a put: the value gets the demand on its key; the map it was
  # built on gets the whole demand (it may hold every other field).
  defp field_write(mfa, args, demand, st, ctx) do
    {map_index, key_index, value_index} = Map.fetch!(@field_writes, mfa)
    key = Enum.at(args, key_index)

    value_demand =
      case literal_atom(key) do
        nil -> spread(demand)
        atom -> Lattice.at(demand, atom)
      end

    st = walk(key, spread(demand), st, ctx)
    st = walk(Enum.at(args, value_index), value_demand, st, ctx)
    walk(Enum.at(args, map_index), demand, st, ctx)
  end

  # `erlang:element/2` is 1-based; a tuple field is its 0-based position.
  defp literal_position(node) do
    with true <- :cerl.is_literal(node),
         position when is_integer(position) and position > 0 <- :cerl.concrete(node) do
      position - 1
    else
      _not_a_literal_position -> nil
    end
  end
end
