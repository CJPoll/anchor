defmodule Anchor.Domain.Cfa.Eval do
  @moduledoc """
  One run of one 0-CFA unit — **Domain**, pure (DND-5497). The semantics are
  `Anchor.Domain.Cfa`'s moduledoc; this module is its abstract interpreter
  over Core.

  A run reads the current values (`ctx.values`) and returns
  `%{writes: %{node => value}, reads: MapSet}`: what the unit's body flows
  into each node, and every node it read, so the solver can re-run it when one
  of those grows. A read sees the run's own earlier writes.

  Nodes: `{:var, mfa, name}` (a Core variable of the function `mfa`, lambdas
  included), `{:ret, mfa}`, `{:lret, lambda}`, `{:site, site_id}`, `:escape`,
  and the container slots, per allocation site `alloc`
  (`Anchor.Domain.Cfa.Value`):

    * `{:slot, alloc, key}` — a map field with a literal atom key, a tuple
      position, a list's `:hd` or `:tl`; `{:slot, alloc, :*}` — a map field
      whose key is not a literal atom, and every field of a literal container;
      `{:slot, alloc, :all}`, which every write to the allocation site also
      reaches. A read of key `k` sees `k` and `:*`; a read by a key that is not
      a literal sees `:all`;
    * `{:base, alloc}` — the map a map update (`%{m | k: v}`, `maps:put/3`)
      was built on: a read of the update's field also reads the base's (the
      chain is walked once per allocation site, so a map updated in a loop
      terminates).

  Every slot write also escapes its closures. The payload of a raise
  (`primop match_fail`/`raise`, `erlang:error/exit/throw/raise`) is built
  into no slot: it only reaches a `catch`, which binds `any`; its closures
  escape instead.
  """

  alias Anchor.Domain.Cfa.Value
  alias Anchor.Domain.Core
  alias Anchor.Domain.HigherOrder

  # Erlang BIFs that neither call nor return their arguments: a closure passed
  # to one does not escape.
  @pure_erlang ~w(is_atom is_binary is_bitstring is_boolean is_float is_function
                  is_integer is_list is_map is_map_key is_number is_pid is_port
                  is_record is_reference is_tuple == /= =:= =/= < > =< >= + - * /
                  div rem band bor bxor bnot bsl bsr not and or xor abs length
                  tuple_size map_size byte_size bit_size self node)a

  # Calls that run `M:F(Args...)`: `{index of M, index of the argument list}`.
  @mfa_calls %{
    {:erlang, :apply, 3} => {0, 2},
    {:erlang, :spawn, 3} => {0, 2},
    {:erlang, :spawn, 4} => {1, 3},
    {:erlang, :spawn_link, 3} => {0, 2},
    {:erlang, :spawn_link, 4} => {1, 3},
    {:erlang, :spawn_monitor, 3} => {0, 2},
    {:erlang, :spawn_opt, 4} => {0, 2}
  }

  @raises [
    {:erlang, :error, 1},
    {:erlang, :error, 2},
    {:erlang, :error, 3},
    {:erlang, :exit, 1},
    {:erlang, :throw, 1},
    {:erlang, :raise, 3}
  ]

  @container_access [
    {:erlang, :element, 2},
    {:maps, :get, 2},
    {:maps, :get, 3},
    {:maps, :put, 3},
    {Map, :get, 2},
    {Map, :get, 3},
    {Map, :fetch!, 2},
    {Map, :put, 3}
  ]

  # Node kinds a raise payload's container mode passes through; any other node
  # (a call, above all) evaluates its own arguments normally.
  @payload_types [:tuple, :cons, :map, :literal, :var, :values]

  @typedoc "What a run wrote and read."
  @type acc :: %{writes: %{term() => Value.t()}, reads: MapSet.t()}

  @doc """
  Runs a function or lambda unit: evaluates `fun`'s body for the function
  `mfa` and flows its value into `ret`. `program` holds `closures` and
  `letrec_scopes`, the letrec names in scope where each lambda is defined
  (see `Anchor.Domain.Cfa`); a `letrec` node adds its own names for its body.
  """
  @spec run_function(mfa(), :cerl.cerl(), term(), map(), map()) :: acc()
  def run_function(mfa, fun, ret, program, values) do
    ctx = %{
      program: program,
      values: values,
      mfa: mfa,
      letrecs: unit_scope(ret, program),
      payload?: false
    }

    {value, acc} = eval(:cerl.fun_body(fun), ctx, new_acc())
    write(ret, value, acc)
  end

  # A lambda's body starts with the letrec names in scope where it is
  # defined; a function's body with none (DND-5575).
  defp unit_scope({:lret, lambda}, program), do: Map.fetch!(program.letrec_scopes, lambda)
  defp unit_scope({:ret, _mfa}, _program), do: %{}

  @doc """
  Runs the escape unit: every root's return escapes, and every escaped
  closure's parameters become `any` while its return escapes in turn.
  """
  @spec run_escape(map(), map()) :: acc()
  def run_escape(program, values) do
    ctx = %{program: program, values: values}

    acc =
      Enum.reduce(program.roots, new_acc(), fn root, acc ->
        {returned, acc} = read({:ret, root}, ctx, acc)
        escape([returned], acc)
      end)

    {escaped, acc} = read(:escape, ctx, acc)

    escaped
    |> Value.closure_set()
    |> Enum.sort()
    |> Enum.reduce(acc, &escape_closure(&1, ctx, &2))
  end

  defp escape_closure(closure, ctx, acc) do
    case Map.get(ctx.program.closures, closure) do
      nil ->
        acc

      %{params: params, ret: ret} ->
        acc = Enum.reduce(params, acc, &write(&1, Value.any(), &2))
        {returned, acc} = read(ret, ctx, acc)
        escape([returned], acc)
    end
  end

  defp new_acc, do: %{writes: %{}, reads: MapSet.new()}

  # --- nodes -------------------------------------------------------------------

  defp read(node, ctx, acc) do
    value =
      Value.join(
        Map.get(ctx.values, node, Value.bottom()),
        Map.get(acc.writes, node, Value.bottom())
      )

    {value, %{acc | reads: MapSet.put(acc.reads, node)}}
  end

  defp read_all(nodes, ctx, acc) do
    Enum.reduce(nodes, {Value.bottom(), acc}, fn node, {value, acc} ->
      {read, acc} = read(node, ctx, acc)
      {Value.join(value, read), acc}
    end)
  end

  defp write(node, value, acc) do
    if value == Value.bottom(),
      do: acc,
      else: %{acc | writes: Map.update(acc.writes, node, value, &Value.join(&1, value))}
  end

  defp escape(values, acc) do
    set = values |> Enum.map(&Value.closure_set/1) |> Enum.reduce(MapSet.new(), &MapSet.union/2)
    if MapSet.size(set) == 0, do: acc, else: write(:escape, Value.closures(set), acc)
  end

  defp var_node(ctx, var), do: {:var, ctx.mfa, :cerl.var_name(var)}

  # --- slots ---------------------------------------------------------------------

  defp alloc(node, ctx), do: {:alloc, ctx.mfa, Core.alloc_ordinal(node)}

  defp write_field(alloc, key, value, ctx, acc) do
    if ctx.payload? do
      escape([value], acc)
    else
      acc = write({:slot, alloc, key}, value, acc)
      acc = write({:slot, alloc, :all}, value, acc)
      escape([value], acc)
    end
  end

  # The field `key` (`:*` for a key that is not a literal) of every container
  # `container` may be, and `any` when it may come from outside.
  defp read_field(container, key, ctx, acc) do
    {value, acc} =
      read_fields(Value.allocs(container) |> MapSet.to_list(), key, MapSet.new(), ctx, acc)

    {Value.join(value, Value.outside(container)), acc}
  end

  defp read_fields([], _key, _seen, _ctx, acc), do: {Value.bottom(), acc}

  defp read_fields([alloc | rest], key, seen, ctx, acc) do
    if MapSet.member?(seen, alloc) do
      read_fields(rest, key, seen, ctx, acc)
    else
      {field, acc} = read_all(field_nodes(alloc, key), ctx, acc)
      {base, acc} = read({:base, alloc}, ctx, acc)
      more = base |> Value.allocs() |> MapSet.to_list()
      {others, acc} = read_fields(more ++ rest, key, MapSet.put(seen, alloc), ctx, acc)
      {Value.joins([field, Value.outside(base), others]), acc}
    end
  end

  defp field_nodes(alloc, :*), do: [{:slot, alloc, :all}]
  defp field_nodes(alloc, key), do: [{:slot, alloc, key}, {:slot, alloc, :*}]

  # Every element of every list `list` may be: the heads along each tail.
  defp list_elements(list, ctx, acc),
    do: list_elements(MapSet.to_list(Value.allocs(list)), list, MapSet.new(), ctx, acc)

  defp list_elements([], list, _seen, _ctx, acc), do: {Value.outside(list), acc}

  defp list_elements([alloc | rest], list, seen, ctx, acc) do
    if MapSet.member?(seen, alloc) do
      list_elements(rest, list, seen, ctx, acc)
    else
      {head, acc} = read_all(field_nodes(alloc, :hd), ctx, acc)
      {tail, acc} = read_all(field_nodes(alloc, :tl), ctx, acc)
      more = tail |> Value.allocs() |> MapSet.to_list()
      {others, acc} = list_elements(more ++ rest, tail, MapSet.put(seen, alloc), ctx, acc)
      {Value.joins([head, Value.outside(list), others]), acc}
    end
  end

  defp map_key(node) do
    with true <- :cerl.is_literal(node),
         key when is_atom(key) <- :cerl.concrete(node) do
      key
    else
      _not_a_literal_atom -> :*
    end
  end

  # --- evaluation ----------------------------------------------------------------

  defp eval(node, ctx, acc) do
    type = :cerl.type(node)
    ctx = if type in @payload_types, do: ctx, else: %{ctx | payload?: false}

    case type do
      :literal ->
        if Core.alloc_ordinal(node),
          do: literal_container(node, ctx, acc),
          else: literal(:cerl.concrete(node), ctx, acc)

      :var ->
        variable(node, ctx, acc)

      :fun ->
        lambda(node, ctx, acc)

      :let ->
        let(node, ctx, acc)

      :letrec ->
        scope = Map.merge(ctx.letrecs, Core.letrec_bindings(ctx.mfa, node))
        eval(:cerl.letrec_body(node), %{ctx | letrecs: scope}, acc)

      :seq ->
        seq(node, ctx, acc)

      :case ->
        case_of(node, ctx, acc)

      :receive ->
        receive_of(node, ctx, acc)

      :try ->
        try_of(node, ctx, acc)

      :catch ->
        catch_of(node, ctx, acc)

      :apply ->
        apply_of(node, ctx, acc)

      :call ->
        call(node, ctx, acc)

      :primop ->
        primop(node, ctx, acc)

      :tuple ->
        tuple(node, ctx, acc)

      :cons ->
        cons(node, ctx, acc)

      :map ->
        map(node, ctx, acc)

      :values ->
        values(node, ctx, acc)

      binary when binary in [:binary, :bitstr] ->
        contents(node, Value.bottom(), ctx, acc)

      _other ->
        contents(node, Value.any(), ctx, acc)
    end
  end

  # A node whose value is `value`, evaluated for what its children write.
  defp contents(node, value, ctx, acc) do
    {_values, acc} = node |> :cerl.subtrees() |> List.flatten() |> eval_list(ctx, acc)
    {value, acc}
  end

  defp eval_list(nodes, ctx, acc) do
    {values, acc} =
      Enum.reduce(nodes, {[], acc}, fn node, {values, acc} ->
        {value, acc} = eval(node, ctx, acc)
        {[value | values], acc}
      end)

    {Enum.reverse(values), acc}
  end

  defp values(node, ctx, acc) do
    {values, acc} = node |> :cerl.values_es() |> eval_list(ctx, acc)
    {Value.joins(values), acc}
  end

  # A `values` node gives one value per variable; any other node gives its one
  # value to each (a primop such as `recv_peek_message` binds two).
  defp eval_multi(node, count, ctx, acc) do
    if :cerl.is_c_values(node) do
      node |> :cerl.values_es() |> eval_list(ctx, acc)
    else
      {value, acc} = eval(node, ctx, acc)
      {List.duplicate(value, count), acc}
    end
  end

  defp literal(term, _ctx, acc) when is_function(term) do
    case :erlang.fun_info(term, :type) do
      {:type, :external} ->
        {:module, m} = :erlang.fun_info(term, :module)
        {:name, f} = :erlang.fun_info(term, :name)
        {:arity, a} = :erlang.fun_info(term, :arity)
        {Value.closures([{m, f, a}]), acc}

      {:type, :local} ->
        {Value.any(), acc}
    end
  end

  defp literal(term, _ctx, acc) when is_atom(term), do: {Value.constant(), acc}

  # An empty container has no field to read; any other constant reads as one.
  defp literal(term, _ctx, acc) when term in [%{}, [], {}], do: {Value.bottom(), acc}
  defp literal(_term, _ctx, acc), do: {Value.constant(), acc}

  # A literal container holding a fun (an external fun a module attribute put
  # there): every field of it, at any depth, is its funs or the container.
  defp literal_container(node, ctx, acc) do
    alloc = alloc(node, ctx)
    funs = node |> :cerl.concrete() |> funs_in([])
    value = Value.join(Value.container(alloc, Value.bottom()), Value.constant())
    field = Value.join(Value.closures(funs), value)
    {value, write_field(alloc, :*, field, ctx, acc)}
  end

  defp funs_in(term, found) when is_function(term) do
    {{:module, m}, {:name, f}, {:arity, a}} =
      {:erlang.fun_info(term, :module), :erlang.fun_info(term, :name),
       :erlang.fun_info(term, :arity)}

    [{m, f, a} | found]
  end

  defp funs_in(term, found) when is_tuple(term), do: term |> Tuple.to_list() |> funs_in(found)
  defp funs_in(term, found) when is_map(term), do: term |> Map.to_list() |> funs_in(found)
  defp funs_in([head | tail], found), do: funs_in(tail, funs_in(head, found))
  defp funs_in(_term, found), do: found

  defp variable(node, ctx, acc) do
    case :cerl.var_name(node) do
      {name, arity} = fname when is_atom(name) and is_integer(arity) ->
        {Value.closures(fname_closures(fname, ctx)), acc}

      _name ->
        read(var_node(ctx, node), ctx, acc)
    end
  end

  defp fname_closures({name, arity} = fname, ctx) do
    case Map.get(ctx.letrecs, fname) do
      nil -> [{elem(ctx.mfa, 0), name, arity}]
      ids -> ids
    end
  end

  defp lambda(node, ctx, acc) do
    case Core.lambda_ordinal(node) do
      nil -> {Value.any(), acc}
      ordinal -> {Value.closures([{ctx.mfa, ordinal}]), acc}
    end
  end

  defp let(node, ctx, acc) do
    vars = :cerl.let_vars(node)
    {values, acc} = eval_multi(:cerl.let_arg(node), length(vars), ctx, acc)
    acc = bind_all(vars, values, ctx, acc)
    eval(:cerl.let_body(node), ctx, acc)
  end

  defp seq(node, ctx, acc) do
    {_value, acc} = eval(:cerl.seq_arg(node), ctx, acc)
    eval(:cerl.seq_body(node), ctx, acc)
  end

  defp case_of(node, ctx, acc) do
    clauses = :cerl.case_clauses(node)
    {values, acc} = eval_multi(:cerl.case_arg(node), clause_arity(clauses), ctx, acc)
    clauses_of(clauses, values, ctx, acc)
  end

  defp clause_arity([clause | _rest]), do: length(:cerl.clause_pats(clause))
  defp clause_arity([]), do: 1

  defp clauses_of(clauses, values, ctx, acc) do
    Enum.reduce(clauses, {Value.bottom(), acc}, fn clause, {result, acc} ->
      acc = bind_all(:cerl.clause_pats(clause), values, ctx, acc)
      {value, acc} = eval(:cerl.clause_body(clause), ctx, acc)
      {Value.join(result, value), acc}
    end)
  end

  # OTP 28 Core has no receive node (it is a letrec over recv_* primops); an
  # older one binds every received message as `any`.
  defp receive_of(node, ctx, acc) do
    clauses = :cerl.receive_clauses(node)
    values = List.duplicate(Value.any(), clause_arity(clauses))
    {result, acc} = clauses_of(clauses, values, ctx, acc)
    {_timeout, acc} = eval(:cerl.receive_timeout(node), ctx, acc)
    {action, acc} = eval(:cerl.receive_action(node), ctx, acc)
    {Value.join(result, action), acc}
  end

  defp try_of(node, ctx, acc) do
    vars = :cerl.try_vars(node)
    {values, acc} = eval_multi(:cerl.try_arg(node), length(vars), ctx, acc)
    acc = bind_all(vars, values, ctx, acc)
    {body, acc} = eval(:cerl.try_body(node), ctx, acc)
    evars = :cerl.try_evars(node)
    acc = bind_all(evars, List.duplicate(Value.any(), length(evars)), ctx, acc)
    {handler, acc} = eval(:cerl.try_handler(node), ctx, acc)
    {Value.join(body, handler), acc}
  end

  defp catch_of(node, ctx, acc) do
    {value, acc} = eval(:cerl.catch_body(node), ctx, acc)
    {Value.join(value, Value.any()), acc}
  end

  defp tuple(node, ctx, acc) do
    {values, acc} = node |> :cerl.tuple_es() |> eval_list(ctx, acc)
    alloc = alloc(node, ctx)

    acc =
      values
      |> Enum.with_index()
      |> Enum.reduce(acc, fn {value, index}, acc -> write_field(alloc, index, value, ctx, acc) end)

    {Value.container(alloc, Value.bottom()), acc}
  end

  defp cons(node, ctx, acc) do
    {head, acc} = eval(:cerl.cons_hd(node), ctx, acc)
    {tail, acc} = eval(:cerl.cons_tl(node), ctx, acc)
    alloc = alloc(node, ctx)
    acc = write_field(alloc, :hd, head, ctx, acc)
    {Value.container(alloc, Value.bottom()), write_field(alloc, :tl, tail, ctx, acc)}
  end

  defp map(node, ctx, acc) do
    {base, acc} = eval(:cerl.map_arg(node), ctx, acc)
    alloc = alloc(node, ctx)
    acc = write({:base, alloc}, base, acc)

    acc =
      Enum.reduce(:cerl.map_es(node), acc, fn pair, acc ->
        key = :cerl.map_pair_key(pair)
        {_key, acc} = eval(key, ctx, acc)
        {value, acc} = eval(:cerl.map_pair_val(pair), ctx, acc)
        write_field(alloc, map_key(key), value, ctx, acc)
      end)

    {Value.container(alloc, base), acc}
  end

  defp primop(node, ctx, acc) do
    raise? = :cerl.atom_val(:cerl.primop_name(node)) in [:match_fail, :raise]
    {_values, acc} = node |> :cerl.primop_args() |> eval_list(%{ctx | payload?: raise?}, acc)
    {if(raise?, do: Value.bottom(), else: Value.any()), acc}
  end

  # --- patterns ------------------------------------------------------------------

  defp bind_all(patterns, values, ctx, acc) do
    patterns
    |> Enum.zip(values)
    |> Enum.reduce(acc, fn {pattern, value}, acc -> bind(pattern, value, ctx, acc) end)
  end

  defp bind(pattern, value, ctx, acc) do
    case :cerl.type(pattern) do
      :var -> write(var_node(ctx, pattern), value, acc)
      :alias -> bind_alias(pattern, value, ctx, acc)
      :tuple -> bind_tuple(pattern, value, ctx, acc)
      :cons -> bind_cons(pattern, value, ctx, acc)
      :map -> bind_map(pattern, value, ctx, acc)
      _literal_or_binary -> acc
    end
  end

  defp bind_alias(pattern, value, ctx, acc) do
    acc = write(var_node(ctx, :cerl.alias_var(pattern)), value, acc)
    bind(:cerl.alias_pat(pattern), value, ctx, acc)
  end

  defp bind_tuple(pattern, value, ctx, acc) do
    pattern
    |> :cerl.tuple_es()
    |> Enum.with_index()
    |> Enum.reduce(acc, fn {element, index}, acc ->
      {field, acc} = read_field(value, index, ctx, acc)
      bind(element, field, ctx, acc)
    end)
  end

  defp bind_cons(pattern, value, ctx, acc) do
    {head, acc} = read_field(value, :hd, ctx, acc)
    acc = bind(:cerl.cons_hd(pattern), head, ctx, acc)
    {tail, acc} = read_field(value, :tl, ctx, acc)
    bind(:cerl.cons_tl(pattern), tail, ctx, acc)
  end

  defp bind_map(pattern, value, ctx, acc) do
    Enum.reduce(:cerl.map_es(pattern), acc, fn pair, acc ->
      key = pair |> :cerl.map_pair_key() |> map_key()
      {field, acc} = read_field(value, key, ctx, acc)
      bind(:cerl.map_pair_val(pair), field, ctx, acc)
    end)
  end

  # --- applies and calls ---------------------------------------------------------

  defp apply_of(node, ctx, acc) do
    operator = :cerl.apply_op(node)
    {args, acc} = node |> :cerl.apply_args() |> eval_list(ctx, acc)

    if :cerl.is_c_fname(operator) do
      {name, arity} = fname = :cerl.var_name(operator)

      case Map.get(ctx.letrecs, fname) do
        nil -> call_function({elem(ctx.mfa, 0), name, arity}, args, ctx, acc)
        ids -> invoke(Value.closures(ids), args, ctx, acc)
      end
    else
      {function, acc} = eval(operator, ctx, acc)
      acc = record_sites(node, [function], ctx, acc)
      invoke(function, args, ctx, acc)
    end
  end

  defp record_sites(node, functions, ctx, acc) do
    node
    |> Core.site_ordinals()
    |> Enum.zip(functions)
    |> Enum.reduce(acc, fn {ordinal, function}, acc ->
      write({:site, {ctx.mfa, ordinal}}, function, acc)
    end)
  end

  # Calls each closure `function` may be with `args` (a list, or `{:spread,
  # value}` for an argument list of unknown length whose every element is
  # `value`), and returns what they return. An outside function gets the
  # arguments as escapes and returns `any`.
  defp invoke(function, args, ctx, acc) do
    {result, acc} =
      function
      |> Value.closure_set()
      |> Enum.sort()
      |> Enum.reduce({Value.bottom(), acc}, fn closure, {result, acc} ->
        {value, acc} = invoke_closure(closure, args, ctx, acc)
        {Value.join(result, value), acc}
      end)

    if Value.any?(function),
      do: {Value.join(result, Value.any()), escape(arg_values(args), acc)},
      else: {result, acc}
  end

  defp invoke_closure(closure, args, ctx, acc) do
    case Map.get(ctx.program.closures, closure) do
      nil -> {Value.any(), escape(arg_values(args), acc)}
      %{params: params, ret: ret} -> pass(params, ret, args, ctx, acc)
    end
  end

  defp pass(params, ret, {:spread, value}, ctx, acc),
    do: pass(params, ret, List.duplicate(value, length(params)), ctx, acc)

  defp pass(params, ret, args, ctx, acc) when length(params) == length(args) do
    acc =
      params
      |> Enum.zip(args)
      |> Enum.reduce(acc, fn {param, arg}, acc -> write(param, arg, acc) end)

    read(ret, ctx, acc)
  end

  # A closure of another arity: the call raises `badarity`.
  defp pass(_params, _ret, _args, _ctx, acc), do: {Value.bottom(), acc}

  defp arg_values({:spread, value}), do: [value]
  defp arg_values(args), do: args

  defp call(node, ctx, acc) do
    {_module, acc} = eval(:cerl.call_module(node), ctx, acc)
    {_name, acc} = eval(:cerl.call_name(node), ctx, acc)
    arg_nodes = :cerl.call_args(node)
    mfa = Core.call_mfa(node)
    {args, acc} = eval_list(arg_nodes, %{ctx | payload?: mfa in @raises}, acc)

    case mfa do
      nil -> {Value.any(), escape(args, acc)}
      mfa -> call_mfa(mfa, node, arg_nodes, args, ctx, acc)
    end
  end

  defp call_mfa({:erlang, :make_fun, 3}, _node, arg_nodes, _args, _ctx, acc) do
    if Enum.all?(arg_nodes, &:cerl.is_literal/1) do
      {Value.closures([arg_nodes |> Enum.map(&:cerl.concrete/1) |> List.to_tuple()]), acc}
    else
      {Value.any(), acc}
    end
  end

  defp call_mfa({:erlang, :apply, 2}, node, _arg_nodes, [function, list], ctx, acc) do
    acc = record_sites(node, [function], ctx, acc)
    {element, acc} = list_elements(list, ctx, acc)
    invoke(function, {:spread, element}, ctx, acc)
  end

  # The clause Core gives `s.f` for a module atom `s`: a zero-arity call on it.
  defp call_mfa({:elixir_erl_pass, :no_parens_remote, 2}, _node, _nodes, [subject, _f], _ctx, acc) do
    if Value.any?(subject) or Value.constant?(subject),
      do: {Value.any(), acc},
      else: {Value.bottom(), acc}
  end

  defp call_mfa(mfa, node, arg_nodes, args, ctx, acc) do
    cond do
      Map.has_key?(ctx.program.closures, mfa) -> call_function(mfa, args, ctx, acc)
      mfa in @container_access -> container_access(mfa, arg_nodes, args, node, ctx, acc)
      Map.has_key?(@mfa_calls, mfa) -> mfa_call(mfa, arg_nodes, args, ctx, acc)
      HigherOrder.invocations(mfa) != [] -> higher_order(mfa, node, args, ctx, acc)
      pure_erlang?(mfa) -> {Value.constant(), acc}
      # A raise never returns; what it raises reaches only a catch (`any`).
      mfa in @raises -> {Value.bottom(), escape(args, acc)}
      true -> {Value.any(), escape(args, acc)}
    end
  end

  # `apply(M, F, Args)` and `spawn(M, F, Args)`: a call of `M:F` with Args'
  # elements. With M and F literal and `M:F/n` in the project it is a call
  # (spawn returns a pid, a constant); otherwise any exported function of a
  # matching arity (any arity, when Args' length is unknown) may be called
  # with anything, so their parameters become `any`; unless M or F can be
  # nothing at all, when no run reaches the call.
  defp mfa_call({_m, name, _a} = mfa, arg_nodes, args, ctx, acc) do
    {module_index, list_index} = Map.fetch!(@mfa_calls, mfa)
    module = Enum.at(arg_nodes, module_index)
    function = Enum.at(arg_nodes, module_index + 1)
    list_node = Enum.at(arg_nodes, list_index)
    acc = escape(args, acc)
    {element, acc} = list_elements(Enum.at(args, list_index), ctx, acc)
    count = list_length(list_node)

    {result, acc} =
      case {literal_atom(module), literal_atom(function), count} do
        {{:ok, m}, {:ok, f}, n} when is_integer(n) ->
          if Map.has_key?(ctx.program.closures, {m, f, n}),
            do: call_function({m, f, n}, List.duplicate(element, n), ctx, acc),
            else: {Value.any(), acc}

        _dynamic ->
          if reachable?(Enum.at(args, module_index)) and
               reachable?(Enum.at(args, module_index + 1)),
             do: {Value.any(), open_call(count, ctx, acc)},
             else: {Value.bottom(), acc}
      end

    if name == :apply, do: {result, acc}, else: {Value.constant(), acc}
  end

  # Whether a module or function name may be anything at all here (a value
  # that is nothing is a call no run reaches).
  defp reachable?(value), do: Value.any?(value) or Value.constant?(value)

  defp open_call(count, ctx, acc) do
    ctx.program.exported_by_arity
    |> Enum.filter(fn {arity, _mfas} -> count == nil or arity == count end)
    |> Enum.flat_map(&elem(&1, 1))
    |> Enum.sort()
    |> Enum.flat_map(&Map.fetch!(ctx.program.closures, &1).params)
    |> Enum.reduce(acc, &write(&1, Value.any(), &2))
  end

  defp literal_atom(node) do
    if :cerl.is_literal(node) and is_atom(:cerl.concrete(node)),
      do: {:ok, :cerl.concrete(node)},
      else: :error
  end

  # The length of a Core list whose spine is known, else nil.
  defp list_length(node) do
    cond do
      :cerl.is_c_cons(node) ->
        case list_length(:cerl.cons_tl(node)) do
          nil -> nil
          length -> length + 1
        end

      :cerl.is_literal(node) and is_list(:cerl.concrete(node)) ->
        proper_length(:cerl.concrete(node), 0)

      true ->
        nil
    end
  end

  defp proper_length([], length), do: length
  defp proper_length([_head | tail], length), do: proper_length(tail, length + 1)
  defp proper_length(_improper, _length), do: nil

  defp call_function(mfa, args, ctx, acc) do
    case Map.get(ctx.program.closures, mfa) do
      nil -> {Value.any(), escape(args, acc)}
      %{params: params, ret: ret} -> pass(params, ret, args, ctx, acc)
    end
  end

  # The invoked arguments are apply sites; every argument escapes (the
  # library calls them with values it chooses), and the result is `any`. An
  # argument written as a literal that is no function applies nothing there
  # (DND-5674): `Enum.with_index(list, 1)` (an offset) and `Enum.sort(list,
  # :desc)` (a direction) call no closure, so their site is the empty set,
  # never `any`. A literal fun names its target (`literal/3`).
  defp higher_order(mfa, node, args, ctx, acc) do
    arg_nodes = :cerl.call_args(node)

    functions =
      Enum.map(HigherOrder.invocations(mfa), fn {index, _arity} ->
        invoked(Enum.at(arg_nodes, index), Enum.at(args, index))
      end)

    acc = record_sites(node, functions, ctx, acc)
    {Value.any(), escape(args, acc)}
  end

  # What an invoked argument calls: nothing for a literal that applies
  # nothing (`applies_nothing?/1`); else its closures, and `any` when it may
  # be a constant or a container: a library takes a module (`Enum.sort(list,
  # Mod)` calls `Mod.compare/2`) or a `{:asc, Mod}` tuple there.
  defp invoked(node, function) do
    cond do
      applies_nothing?(node) ->
        Value.bottom()

      Value.constant?(function) or MapSet.size(Value.allocs(function)) > 0 ->
        Value.join(function, Value.any())

      true ->
        function
    end
  end

  # A literal argument no library can call: a number, a binary, a list, a map
  # or the sort directions `:asc` and `:desc`. Any other atom may be a module
  # whose `compare/2` a sort calls, and a tuple may be `{:asc, Mod}`: those
  # stay with the analysis.
  defp applies_nothing?(node) do
    :cerl.is_literal(node) and data_literal?(:cerl.concrete(node))
  end

  defp data_literal?(term) do
    term in [:asc, :desc] or is_number(term) or is_bitstring(term) or is_list(term) or
      (is_map(term) and not is_struct(term))
  end

  defp pure_erlang?({:erlang, name, _arity}), do: name in @pure_erlang
  defp pure_erlang?(_mfa), do: false

  defp container_access({:erlang, :element, 2}, [index, _tuple], [_i, tuple], _node, ctx, acc),
    do: read_field(tuple, element_key(index), ctx, acc)

  defp container_access({:maps, :get, 2}, [key, _map], [_k, map], _node, ctx, acc),
    do: map_get(key, map, Value.bottom(), ctx, acc)

  defp container_access({:maps, :get, 3}, [key, _map, _d], [_k, map, default], _node, ctx, acc),
    do: map_get(key, map, default, ctx, acc)

  defp container_access({Map, :get, 2}, [_map, key], [map, _k], _node, ctx, acc),
    do: map_get(key, map, Value.bottom(), ctx, acc)

  defp container_access({Map, :fetch!, 2}, [_map, key], [map, _k], _node, ctx, acc),
    do: map_get(key, map, Value.bottom(), ctx, acc)

  defp container_access({Map, :get, 3}, [_map, key, _d], [map, _k, default], _node, ctx, acc),
    do: map_get(key, map, default, ctx, acc)

  defp container_access({:maps, :put, 3}, [key, _value, _map], [_k, value, map], node, ctx, acc),
    do: map_put(node, key, value, map, ctx, acc)

  defp container_access({Map, :put, 3}, [_map, key, _value], [map, _k, value], node, ctx, acc),
    do: map_put(node, key, value, map, ctx, acc)

  # `erlang:element/2` is 1-based; a tuple field is its 0-based position.
  defp element_key(index) do
    with true <- :cerl.is_literal(index),
         position when is_integer(position) and position > 0 <- :cerl.concrete(index) do
      position - 1
    else
      _not_a_literal_position -> :*
    end
  end

  defp map_get(key, map, default, ctx, acc) do
    {field, acc} = read_field(map, map_key(key), ctx, acc)
    {Value.join(field, default), acc}
  end

  defp map_put(node, key, value, map, ctx, acc) do
    alloc = alloc(node, ctx)
    acc = write({:base, alloc}, map, acc)
    {Value.container(alloc, map), write_field(alloc, map_key(key), value, ctx, acc)}
  end
end
