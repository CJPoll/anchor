defmodule Anchor.Domain.StructFlow do
  @moduledoc """
  The value flow of one function's Core Erlang (DND-5454): which values are
  known as which struct, and which writes change a known struct —
  **Domain** (ADR 001), pure, read with `:cerl` (no code loading).

  ## Known values (`known/3`)

  A Core variable is known as the struct `S` when every place the function
  binds it agrees on `S`, by one of these (`how`):

    * `:matched` — a pattern names `S` (`%S{} = v` in a head, `case`, `fn` or
      `=`): Core's `V = ~{'__struct__':='S'}~`;
    * `{:spec, mfa}` — it is the return of a call whose every `@spec` returns
      `S` (`Anchor.Domain.StructTypes`), remote (`Turn.new()`) or local;
    * `{:field, T, field}` — it is a field of a value known as `T` whose
      `@type t` types the field as `S`: a read (`t.turn`, Core's
      `case g of ~{'turn':=X}~ -> X`), a pattern (`%T{turn: x}`), or the
      argument of the function `Map.update!/3`, `Map.update/4` hand the
      field's value to (how `put_in(g.turn.status, v)` compiles);
    * flow — a `let`, a `case` clause variable, or a `case` whose every
      clause (its compiler-generated failure clauses aside) returns the same
      known value: what it is bound to.

  Anything else is unknown: a parameter matched by no struct pattern, a call
  with no single-struct spec, a field typed as anything but one struct, a
  variable bound twice to different things. Unknown is never a finding.

  ## Writes (`writes/3`)

  A write changes a value known as `S`:

    * a map update on it (`%{v | k: x}`, Core `~{k:=x|V}~`, op `"map update"`)
      or an inlined put (`Map.put/3`, and a `Map.merge/2` with a literal map,
      which compiles to the same `~{k=>x|V}~`, op `"Map.put"`);
    * `Map.put/merge/replace/replace!/update/update!/delete/drop/put_new/
      put_new_lazy` with it as the map (the ones Elixir inlines included:
      `:maps.put/3`, `:maps.merge/2`, `:maps.update/3`, `:maps.remove/2`),
      except `Map.delete(v, :__struct__)` and a `Map.drop/2` whose literal list
      holds `:__struct__`, which make a plain map;
    * `struct/2` and `struct!/2` on it (`Kernel.struct(v, kw)`; naming the
      module, `struct(S, kw)`, is literal syntax, the AST rule's);
    * `put_in/3`, `update_in/3`, `get_and_update_in/3`, `pop_in/2` rooted at it.

  `put_in(g.turn.status, v)` compiles to `Map.update!(g, :turn, fn t ->
  Map.update!(t, :status, ...) end)`, so it is two writes, one on `g` and one
  on `g.turn` (known by its field type); the leaf `status` is not a container
  and is never judged. Each write carries the line of its Core annotation.
  """

  alias Anchor.Domain.StructTypes

  @typedoc "How a value is known as its struct."
  @type how :: :matched | {:spec, mfa()} | {:field, module(), atom()}

  @typedoc "A Core variable's name."
  @type core_var :: atom() | integer()

  @typedoc "A write to a known struct."
  @type write :: %{struct: module(), op: String.t(), line: pos_integer() | nil, how: how()}

  # {module, name, arity} => {position of the map argument, op}
  @writers %{
    {:maps, :put, 3} => {2, "Map.put"},
    {:maps, :merge, 2} => {0, "Map.merge"},
    {:maps, :update, 3} => {2, "Map.replace!"},
    {:maps, :remove, 2} => {1, "Map.delete"},
    {Map, :put, 3} => {0, "Map.put"},
    {Map, :merge, 2} => {0, "Map.merge"},
    {Map, :merge, 3} => {0, "Map.merge"},
    {Map, :replace, 3} => {0, "Map.replace"},
    {Map, :replace!, 3} => {0, "Map.replace!"},
    {Map, :update, 4} => {0, "Map.update"},
    {Map, :update!, 3} => {0, "Map.update!"},
    {Map, :delete, 2} => {0, "Map.delete"},
    {Map, :drop, 2} => {0, "Map.drop"},
    {Map, :put_new, 3} => {0, "Map.put_new"},
    {Map, :put_new_lazy, 3} => {0, "Map.put_new_lazy"},
    {Kernel, :struct, 2} => {0, "struct"},
    {Kernel, :struct!, 2} => {0, "struct!"},
    {Kernel, :put_in, 3} => {0, "put_in"},
    {Kernel, :update_in, 3} => {0, "update_in"},
    {Kernel, :get_and_update_in, 3} => {0, "get_and_update_in"},
    {Kernel, :pop_in, 2} => {0, "pop_in"}
  }

  # The functions that hand a field's value to a function argument:
  # {module, name, arity} => position of that function.
  @field_funs %{{Map, :update!, 3} => 2, {Map, :update, 4} => 3}

  @max_passes 6

  @doc """
  Every variable of `core` (one function's `c_fun`, in `module`) known as one
  struct, `%{var => {struct, how}}`, under `index` (`StructTypes.index/1`).
  """
  @spec known(:cerl.cerl(), StructTypes.t(), module()) :: %{core_var() => {module(), how()}}
  def known(core, index, module) do
    ctx = %{index: index, module: module}
    st = walk(core, ctx, new_state(fixpoint(core, ctx, %{}, 1), nil))
    settled(st.seen)
  end

  @doc """
  The writes in `core` (a `c_fun` in `module`) that change a value known
  (`known/3`) as a struct, in Core order.
  """
  @spec writes(:cerl.cerl(), StructTypes.t(), module()) :: [write()]
  def writes(core, index, module) do
    ctx = %{index: index, module: module}
    st = walk(core, ctx, new_state(fixpoint(core, ctx, %{}, 1), []))
    Enum.reverse(st.writes)
  end

  # ---- the fixpoint: a function argument's binding is found after its body ----

  # `env` is lexical (a Core variable is bound for its scope); `seen` holds
  # every binding of each variable, for `known/3`. `writes: nil` collects none.
  defp new_state(seeds, writes),
    do: %{env: %{}, seen: %{}, seeds: seeds, funs: %{}, writes: writes}

  # The seeds (a `fun`'s parameter known from the call it is handed to) a
  # pass finds after it walked the `fun`: walk again until they settle.
  defp fixpoint(core, ctx, seeds, pass) do
    st = walk(core, ctx, new_state(seeds, nil))

    if st.seeds == seeds or pass >= @max_passes,
      do: seeds,
      else: fixpoint(core, ctx, st.seeds, pass + 1)
  end

  defp settled(seen) do
    for {var, values} <- seen,
        [{_struct, _how} = value] <- [Enum.uniq(values)],
        into: %{},
        do: {var, value}
  end

  # ---- the walk ----

  defp walk(node, ctx, st) do
    case :cerl.type(node) do
      :let -> walk_let(node, ctx, st)
      :case -> walk_case(node, ctx, st)
      :fun -> walk_fun(node, ctx, st)
      :call -> walk_call(node, ctx, st)
      :map -> walk_map(node, ctx, st)
      :receive -> walk_receive(node, ctx, st)
      :try -> walk_try(node, ctx, st)
      _other -> walk_all(:cerl.subtrees(node) |> List.flatten(), ctx, st)
    end
  end

  defp walk_all(nodes, ctx, st), do: Enum.reduce(nodes, st, &walk(&1, ctx, &2))

  defp walk_let(node, ctx, st) do
    arg = :cerl.let_arg(node)
    st = walk(arg, ctx, st)

    scoped(st, fn st ->
      st =
        case :cerl.let_vars(node) do
          [var] -> st |> bind(var, eval(arg, ctx, st)) |> remember_fun(var, arg)
          vars -> Enum.reduce(vars, st, &bind(&2, &1, nil))
        end

      walk(:cerl.let_body(node), ctx, st)
    end)
  end

  # Runs `fun` on `st` and restores the lexical environment after it.
  defp scoped(st, fun), do: %{fun.(st) | env: st.env}

  defp walk_case(node, ctx, st) do
    arg = :cerl.case_arg(node)
    st = walk(arg, ctx, st)
    values = arg_values(arg, ctx, st)
    Enum.reduce(:cerl.case_clauses(node), st, &walk_clause(&1, values, ctx, &2))
  end

  defp walk_receive(node, ctx, st) do
    st = Enum.reduce(:cerl.receive_clauses(node), st, &walk_clause(&1, [nil], ctx, &2))
    walk_all([:cerl.receive_timeout(node), :cerl.receive_action(node)], ctx, st)
  end

  defp walk_try(node, ctx, st) do
    arg = :cerl.try_arg(node)
    st = walk(arg, ctx, st)

    st =
      scoped(st, fn st ->
        st =
          case :cerl.try_vars(node) do
            [var] -> bind(st, var, eval(arg, ctx, st))
            vars -> Enum.reduce(vars, st, &bind(&2, &1, nil))
          end

        walk(:cerl.try_body(node), ctx, st)
      end)

    scoped(st, fn st ->
      st = Enum.reduce(:cerl.try_evars(node), st, &bind(&2, &1, nil))
      walk(:cerl.try_handler(node), ctx, st)
    end)
  end

  defp walk_clause(clause, values, ctx, st) do
    scoped(st, fn st ->
      st = bind_patterns(st, clause, values, ctx)

      walk_all([:cerl.clause_guard(clause), :cerl.clause_body(clause)], ctx, st)
    end)
  end

  defp walk_fun(node, ctx, st) do
    scoped(st, fn st ->
      st =
        Enum.reduce(:cerl.fun_vars(node), st, fn var, inner ->
          bind(inner, var, Map.get(inner.seeds, :cerl.var_name(var)))
        end)

      walk(:cerl.fun_body(node), ctx, st)
    end)
  end

  defp walk_call(node, ctx, st) do
    st = walk_all(:cerl.call_args(node), ctx, st)

    case call_mfa(node) do
      nil -> st
      mfa -> st |> seed_field_fun(mfa, node, ctx) |> record_call_write(mfa, node, ctx)
    end
  end

  defp walk_map(node, ctx, st) do
    st = walk_all(:cerl.subtrees(node) |> List.flatten(), ctx, st)

    if :cerl.is_c_map_pattern(node) or :cerl.is_literal(:cerl.map_arg(node)) do
      st
    else
      op =
        if Enum.all?(:cerl.map_es(node), &(literal(:cerl.map_pair_op(&1)) == {:ok, :exact})),
          do: "map update",
          else: "Map.put"

      record_write(st, eval(:cerl.map_arg(node), ctx, st), op, node, ctx)
    end
  end

  # ---- patterns ----

  # Binds `clause`'s patterns to `values`, one per pattern (none known when
  # the counts differ).
  defp bind_patterns(st, clause, values, ctx) do
    patterns = :cerl.clause_pats(clause)

    values =
      if length(values) == length(patterns),
        do: values,
        else: List.duplicate(nil, length(patterns))

    patterns
    |> Enum.zip(values)
    |> Enum.reduce(st, fn {pattern, value}, inner -> bind_pattern(inner, pattern, value, ctx) end)
  end

  defp bind_pattern(st, pattern, value, ctx) do
    case :cerl.type(pattern) do
      :var ->
        bind(st, pattern, value)

      :alias ->
        inner = :cerl.alias_pat(pattern)
        value = struct_pattern_value(inner) || value
        st = bind(st, :cerl.alias_var(pattern), value)
        bind_pattern(st, inner, value, ctx)

      :map ->
        container = struct_pattern_value(pattern) || value
        Enum.reduce(:cerl.map_es(pattern), st, &bind_pair(&2, &1, container, ctx))

      _other ->
        pattern
        |> :cerl.subtrees()
        |> List.flatten()
        |> Enum.reduce(st, &bind_pattern(&2, &1, nil, ctx))
    end
  end

  defp bind_pair(st, pair, container, ctx) do
    value =
      with {struct, _how} <- container,
           {:ok, field} when is_atom(field) <- literal(:cerl.map_pair_key(pair)),
           target when target != nil <- StructTypes.field(ctx.index, struct, field) do
        {target, {:field, struct, field}}
      else
        _unknown -> nil
      end

    bind_pattern(st, :cerl.map_pair_val(pair), value, ctx)
  end

  defp struct_pattern_value(pattern) do
    with true <- :cerl.is_c_map(pattern),
         struct when struct != nil <- map_struct(pattern) do
      {struct, :matched}
    else
      _other -> nil
    end
  end

  # ---- what an expression is known to be ----

  defp eval(node, ctx, st) do
    case :cerl.type(node) do
      :var -> lookup(st, node)
      :let -> eval(:cerl.let_body(node), ctx, st)
      :seq -> eval(:cerl.seq_body(node), ctx, st)
      :case -> eval_case(node, ctx, st)
      :call -> eval_call(node, ctx, st)
      :apply -> eval_apply(node, ctx)
      _other -> nil
    end
  end

  # A case whose every real clause returns the same known value (a field
  # read's `case g of ~{'turn':=X}~ -> X; ...` included: its other clauses
  # are compiler-generated failure paths).
  defp eval_case(node, ctx, st) do
    args = arg_values(:cerl.case_arg(node), ctx, st)

    values =
      node
      |> :cerl.case_clauses()
      |> Enum.reject(&failure_clause?/1)
      |> Enum.map(fn clause ->
        eval(:cerl.clause_body(clause), ctx, bind_patterns(st, clause, args, ctx))
      end)
      |> Enum.uniq()

    case values do
      [{_struct, _how} = value] -> value
      _none_or_many -> nil
    end
  end

  defp eval_call(node, ctx, st) do
    case call_mfa(node) do
      {:erlang, :map_get, 2} ->
        [key, map] = :cerl.call_args(node)
        field_of(eval(map, ctx, st), key, ctx)

      nil ->
        nil

      mfa ->
        spec_value(ctx.index, mfa)
    end
  end

  defp eval_apply(node, %{module: module} = ctx) do
    op = :cerl.apply_op(node)

    with true <- :cerl.is_c_var(op),
         {name, arity} when is_atom(name) <- :cerl.var_name(op) do
      spec_value(ctx.index, {module, name, arity})
    else
      _other -> nil
    end
  end

  defp spec_value(index, mfa) do
    case StructTypes.return(index, mfa) do
      nil -> nil
      struct -> {struct, {:spec, mfa}}
    end
  end

  defp field_of({struct, _how}, key, ctx) do
    with {:ok, field} when is_atom(field) <- literal(key),
         target when target != nil <- StructTypes.field(ctx.index, struct, field) do
      {target, {:field, struct, field}}
    else
      _unknown -> nil
    end
  end

  defp field_of(nil, _key, _ctx), do: nil

  # The arguments a case matches its clauses against: one per pattern.
  defp arg_values(arg, ctx, st) do
    if :cerl.is_c_values(arg),
      do: Enum.map(:cerl.values_es(arg), &eval(&1, ctx, st)),
      else: [eval(arg, ctx, st)]
  end

  # A clause Elixir emits to fail: `match_fail`, `erlang:error/1`, or the
  # `no_parens_remote` fallback of a field read on a value that is no map.
  defp failure_clause?(clause) do
    body = :cerl.clause_body(clause)

    (:cerl.is_c_primop(body) and :cerl.atom_val(:cerl.primop_name(body)) == :match_fail) or
      call_mfa(body) == {:erlang, :error, 1} or no_parens_remote?(body)
  end

  defp no_parens_remote?(node) do
    :cerl.is_c_case(node) and
      call_mfa(:cerl.case_arg(node)) == {:elixir_erl_pass, :no_parens_remote, 2}
  end

  # ---- writes and seeds ----

  # `Map.update!(m, :k, fun)`: `fun`'s argument is m's field `k`.
  defp seed_field_fun(st, mfa, node, ctx) do
    with position when position != nil <- Map.get(@field_funs, mfa),
         args = :cerl.call_args(node),
         {_struct, _how} = value <-
           field_of(eval(Enum.at(args, 0), ctx, st), Enum.at(args, 1), ctx),
         [param | _rest] <- fun_params(Enum.at(args, position), st) do
      %{st | seeds: Map.put(st.seeds, :cerl.var_name(param), value)}
    else
      _other -> st
    end
  end

  defp fun_params(node, st) do
    cond do
      :cerl.is_c_fun(node) -> :cerl.fun_vars(node)
      :cerl.is_c_var(node) -> Map.get(st.funs, :cerl.var_name(node), [])
      true -> []
    end
  end

  defp record_call_write(st, mfa, node, ctx) do
    case Map.get(@writers, mfa) do
      {position, op} ->
        args = :cerl.call_args(node)

        if plain_map_result?(mfa, args),
          do: st,
          else: record_write(st, eval(Enum.at(args, position), ctx, st), op, node, ctx)

      nil ->
        st
    end
  end

  defp plain_map_result?({:maps, :remove, 2}, [key, _map]), do: literal(key) == {:ok, :__struct__}
  defp plain_map_result?({Map, :delete, 2}, [_map, key]), do: literal(key) == {:ok, :__struct__}

  defp plain_map_result?({Map, :drop, 2}, [_map, keys]) do
    case literal(keys) do
      {:ok, list} when is_list(list) -> :__struct__ in list
      _other -> false
    end
  end

  defp plain_map_result?(_mfa, _args), do: false

  defp record_write(%{writes: nil} = st, _value, _op, _node, _ctx), do: st

  defp record_write(st, {struct, how}, op, node, _ctx) do
    write = %{struct: struct, op: op, line: line(node), how: how}
    %{st | writes: [write | st.writes]}
  end

  defp record_write(st, nil, _op, _node, _ctx), do: st

  # ---- the environment ----

  defp bind(st, var, value) do
    name = :cerl.var_name(var)
    entry = value || :unknown

    %{
      st
      | env: Map.put(st.env, name, value),
        seen: Map.update(st.seen, name, [entry], &[entry | &1])
    }
  end

  # A variable let-bound to a `fun`: its parameters, for `seed_field_fun/4`.
  defp remember_fun(st, var, arg) do
    if :cerl.is_c_fun(arg),
      do: %{st | funs: Map.put(st.funs, :cerl.var_name(var), :cerl.fun_vars(arg))},
      else: st
  end

  defp lookup(st, var), do: Map.get(st.env, :cerl.var_name(var))

  # ---- Core helpers ----

  defp call_mfa(node) do
    with true <- :cerl.is_c_call(node),
         {:ok, module} when is_atom(module) <- literal(:cerl.call_module(node)),
         {:ok, name} when is_atom(name) <- literal(:cerl.call_name(node)) do
      {module, name, :cerl.call_arity(node)}
    else
      _other -> nil
    end
  end

  defp map_struct(node) do
    Enum.find_value(:cerl.map_es(node), fn pair ->
      with {:ok, :__struct__} <- literal(:cerl.map_pair_key(pair)),
           {:ok, module} when is_atom(module) and module not in [nil, true, false] <-
             literal(:cerl.map_pair_val(pair)) do
        module
      else
        _other -> nil
      end
    end)
  end

  defp literal(node) do
    if :cerl.is_literal(node), do: {:ok, :cerl.concrete(node)}, else: :error
  end

  # The node's own line, else the first line inside it.
  defp line(node) do
    case Enum.find_value(:cerl.get_ann(node), &annotation_line/1) do
      nil -> node |> :cerl.subtrees() |> List.flatten() |> Enum.find_value(&line/1)
      line -> line
    end
  end

  defp annotation_line(line) when is_integer(line) and line > 0, do: line

  defp annotation_line({line, column}) when is_integer(line) and line > 0 and is_integer(column),
    do: line

  defp annotation_line(_other), do: nil
end
