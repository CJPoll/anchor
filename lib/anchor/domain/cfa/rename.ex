defmodule Anchor.Domain.Cfa.Rename do
  @moduledoc """
  Renames every variable a function's Core binds so each binding has a name of
  its own — **Domain** (DND-8063).

  The 0-CFA (`Anchor.Domain.Cfa`) keys a variable by its function and its
  name, so two bindings of one name in one function share one abstract value.
  The compiler reuses its generated names across clauses: in
  `DependencyAnalyzer.module_scope/2` one clause binds `_X_@1` to a map value
  read from a parameter (`any`) and a later clause binds `_X_@1` to the `fun`
  its `with ... else` compiles to, so the `with`'s apply site joined with
  `any` and read as "an application of a closure from outside the project",
  making every caller a Manager under `effects_match_bucket`.

  `rename/1` is alpha-renaming: a binder (a `fun`'s or a `let`'s variable, a
  clause pattern's variable, a `try`'s variables) gets a fresh name, and every use of it in its scope follows, so
  the program means what it meant and only the sharing is gone. A use with no
  binder in scope (none in compiled Core) keeps its name. A function name
  (`{name, arity}`, a `letrec` or local call) is never renamed. Names are
  atoms `:"<name>~<n>"`, `n` counted per function in pre-order, so identical
  Core renames identically. A `letrec` (it binds function names only) and an
  alias pattern (`var = pattern`, a variable and a pattern) need no clause of
  their own: their subtrees are walked like any other node's. The compiler lowers `receive` to primops and a
  `letrec` before Anchor reads Core, so a `receive` node is walked as any
  other node (its clauses' variables keep their names, which is sound: no
  sharing is removed there, none is added). Ordinals (`Anchor.Domain.Core.label/1`) count
  `fun`s and sites, never names, so they are unchanged.

  It removes only the over-approximation sharing caused: a value that really
  reaches a variable (a parameter applied, under any name) still reaches it.
  """

  @doc "`core_fun` (a `c_fun`) with every binding renamed apart."
  @spec rename(:cerl.cerl()) :: :cerl.cerl()
  def rename(core_fun) do
    {node, _counter} = expr(core_fun, %{}, 0)
    node
  end

  # --- expressions ------------------------------------------------------------

  defp expr(node, env, n) do
    case :cerl.type(node) do
      :var -> {use_var(node, env), n}
      :fun -> fun(node, env, n)
      :let -> let(node, env, n)
      :case -> case_expr(node, env, n)
      :try -> try_expr(node, env, n)
      :map -> map_expr(node, env, n)
      _other -> subtrees(node, env, n)
    end
  end

  defp fun(node, env, n) do
    {vars, env, n} = binders(:cerl.fun_vars(node), env, n)
    {body, n} = expr(:cerl.fun_body(node), env, n)
    {:cerl.update_c_fun(node, vars, body), n}
  end

  defp let(node, env, n) do
    {arg, n} = expr(:cerl.let_arg(node), env, n)
    {vars, inner, n} = binders(:cerl.let_vars(node), env, n)
    {body, n} = expr(:cerl.let_body(node), inner, n)
    {:cerl.update_c_let(node, vars, arg, body), n}
  end

  defp case_expr(node, env, n) do
    {arg, n} = expr(:cerl.case_arg(node), env, n)
    {clauses, n} = clauses(:cerl.case_clauses(node), env, n)
    {:cerl.update_c_case(node, arg, clauses), n}
  end

  defp try_expr(node, env, n) do
    {arg, n} = expr(:cerl.try_arg(node), env, n)
    {vars, body_env, n} = binders(:cerl.try_vars(node), env, n)
    {body, n} = expr(:cerl.try_body(node), body_env, n)
    {evars, handler_env, n} = binders(:cerl.try_evars(node), env, n)
    {handler, n} = expr(:cerl.try_handler(node), handler_env, n)
    {:cerl.update_c_try(node, arg, vars, body, evars, handler), n}
  end

  # A map expression, its update argument kept (`update_tree/2` would drop
  # it: `%{s | n: 1}` would become `%{n: 1}`).
  defp map_expr(node, env, n) do
    {arg, n} = expr(:cerl.map_arg(node), env, n)
    {pairs, n} = Enum.map_reduce(:cerl.map_es(node), n, &expr(&1, env, &2))
    {:cerl.update_c_map(node, arg, pairs), n}
  end

  # Every other node: its subtrees, in order, in the same scope.
  defp subtrees(node, env, n) do
    case :cerl.subtrees(node) do
      [] ->
        {node, n}

      groups ->
        {groups, n} =
          Enum.map_reduce(groups, n, fn group, n ->
            Enum.map_reduce(group, n, &expr(&1, env, &2))
          end)

        {:cerl.update_tree(node, groups), n}
    end
  end

  defp clauses(clauses, env, n), do: Enum.map_reduce(clauses, n, &clause(&1, env, &2))

  # A clause's patterns bind their variables for its guard and body.
  defp clause(node, env, n) do
    {pats, inner, n} = patterns(:cerl.clause_pats(node), env, n)
    {guard, n} = expr(:cerl.clause_guard(node), inner, n)
    {body, n} = expr(:cerl.clause_body(node), inner, n)
    {:cerl.update_c_clause(node, pats, guard, body), n}
  end

  # --- patterns ---------------------------------------------------------------

  # Patterns are read left to right: a variable binds. A binary segment's
  # size is an expression read in the scope so far (the clause's outer scope
  # plus what the pattern already bound: `<<n:8, data:n>>`); a map key is an
  # expression read in the clause's outer scope only, since Core requires a
  # map pattern's key to be bound before the clause.
  defp patterns(pats, outer, n) do
    {pats, {env, n}} =
      Enum.map_reduce(pats, {outer, n}, fn pat, {env, n} ->
        {pat, env, n} = pattern(pat, env, outer, n)
        {pat, {env, n}}
      end)

    {pats, env, n}
  end

  defp pattern(node, env, outer, n) do
    case :cerl.type(node) do
      :var ->
        {[var], env, n} = binders([node], env, n)
        {var, env, n}

      # A map pattern rebuilt as one (`update_tree/2` would make a map
      # expression, which matches differently).
      :map ->
        {pairs, {env, n}} =
          Enum.map_reduce(:cerl.map_es(node), {env, n}, fn pair, {env, n} ->
            {pair, env, n} = pattern(pair, env, outer, n)
            {pair, {env, n}}
          end)

        {:cerl.ann_c_map_pattern(:cerl.get_ann(node), pairs), env, n}

      :map_pair ->
        {key, n} = expr(:cerl.map_pair_key(node), outer, n)
        {value, env, n} = pattern(:cerl.map_pair_val(node), env, outer, n)
        {:cerl.update_c_map_pair(node, :cerl.map_pair_op(node), key, value), env, n}

      :bitstr ->
        {value, env, n} = pattern(:cerl.bitstr_val(node), env, outer, n)
        {size, n} = expr(:cerl.bitstr_size(node), env, n)

        {:cerl.update_c_bitstr(
           node,
           value,
           size,
           :cerl.bitstr_unit(node),
           :cerl.bitstr_type(node),
           :cerl.bitstr_flags(node)
         ), env, n}

      _other ->
        pattern_subtrees(node, env, outer, n)
    end
  end

  # Every other compound pattern is its subtrees, each a pattern.
  defp pattern_subtrees(node, env, outer, n) do
    case :cerl.subtrees(node) do
      [] ->
        {node, env, n}

      groups ->
        {groups, {env, n}} =
          Enum.map_reduce(groups, {env, n}, fn group, acc ->
            Enum.map_reduce(group, acc, fn sub, {env, n} ->
              {sub, env, n} = pattern(sub, env, outer, n)
              {sub, {env, n}}
            end)
          end)

        {:cerl.update_tree(node, groups), env, n}
    end
  end

  # --- names ------------------------------------------------------------------

  defp binders(vars, env, n) do
    {vars, {env, n}} =
      Enum.map_reduce(vars, {env, n}, fn var, {env, n} ->
        name = :cerl.var_name(var)
        fresh = :"#{name}~#{n}"
        {:cerl.update_c_var(var, fresh), {Map.put(env, name, fresh), n + 1}}
      end)

    {vars, env, n}
  end

  defp use_var(node, env) do
    case Map.fetch(env, :cerl.var_name(node)) do
      {:ok, fresh} -> :cerl.update_c_var(node, fresh)
      :error -> node
    end
  end
end
