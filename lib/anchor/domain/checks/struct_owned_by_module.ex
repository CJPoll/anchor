defmodule Anchor.Domain.Checks.StructOwnedByModule do
  @moduledoc """
  Pure detection for the `struct_owned_by_module` rule (DND-5453, proposal M2)
  — the **Domain** bucket (ADR 001). Same AST and rules in, same violations
  out; no IO and no `Credo.*`. A port of the in-file half of crew's
  `Crew.Credo.Checks.StructOnlyChangedByOwnModule`: what one file's text
  decides. What a typespec in another file knows (a field typed as a struct,
  a function's return) is the graph rule DND-5454's.

  ## What it reports

  Only a struct's own module builds or changes it, so each invariant has one
  home. Outside the struct `S`'s own module, in an expression position:

    * `%S{...}` and `%S{s | ...}`;
    * `struct(S)`, `struct(S, kw)`, `struct!(S)`, `struct!(S, kw)` (bare or
      `Kernel.`), `S` a literal module or an alias;
    * on a variable `v` **known** as `S`: `%{v | ...}`;
      `Map.put/put_new/put_new_lazy/merge/replace/replace!/update/update!/
      delete/drop` on `v` (piped or not), except `Map.delete(v, :__struct__)`
      and a `Map.drop/2` whose list holds `:__struct__`; `struct(v, ...)`,
      `struct!(v, ...)`; `put_in/update_in/pop_in/get_and_update_in` whose path
      roots at `v` (every container on the path but the leaf is judged).

  **Owner** of a code position: the innermost `defmodule`, or inside `defimpl
  P, for: M` the module `M` (without `for:`, the enclosing module). Code
  outside every module has the owner `nil`, which owns nothing. Names resolve
  through `Anchor.Domain.DependencyAnalyzer.resolved_modules/1`; a name it
  cannot place is not reported.

  **Pattern positions** are skipped: function heads (except a default
  argument), the left side of `=`, `->` clause patterns (`case`, `with`,
  `fn`, `receive`), `<-` left sides (`with`, `for`), and the first argument of
  `match?/2`. Typespec attributes and `quote` bodies are skipped. Everything
  else is an expression, a `cond` condition and a module attribute included.

  **Known variable.** Within one `def` clause, `v` is known as `S` when every
  place the clause binds `v` (its head, `=`, `->` and `<-` patterns, an `fn`
  argument included) binds it as `%S{}` (`%S{} = v`, `v = %S{}`), or to a
  struct literal of `S`. Any other binding of `v` (bare, to a call's result,
  as a different struct) makes it unknown in the whole clause.

  **`owned_namespaces`** (exact module names) limits the check to structs
  equal to or nested under an entry, so a stdlib or dependency struct the repo
  cannot give a function is out of scope; a top-level `defmodule` outside them
  is itself reported, so a new namespace is never silently unchecked.
  """

  alias Anchor.Domain.DependencyAnalyzer
  alias Anchor.Domain.Violation

  @behaviour Anchor.Domain.RuleShape

  @def_kinds [:def, :defp, :defmacro, :defmacrop]
  @type_attrs [:type, :typep, :opaque, :spec, :callback, :macrocallback]
  @map_writers [
    :put,
    :put_new,
    :put_new_lazy,
    :merge,
    :replace,
    :replace!,
    :update,
    :update!,
    :delete,
    :drop
  ]
  @struct_funs [:struct, :struct!]
  @path_funs [:put_in, :update_in, :pop_in, :get_and_update_in]

  @shape "call a function on S's own module that builds or changes it (e.g. S.new/1, " <>
           "S.put_<field>/2); read fields and pattern-match freely."

  @doc """
  Returns the violations in `ast` for each of the already-selected `rules`.
  A rule's `:owned_namespaces` is a list of module atoms, or `nil` (every
  struct is in scope).
  """
  @spec detect_violations(Macro.t(), [map()]) :: [Violation.t()]
  def detect_violations(ast, rules) do
    resolved = DependencyAnalyzer.resolved_modules(ast)
    Enum.flat_map(rules, fn rule -> detect(ast, rule, resolved) end)
  end

  @doc "The conforming shape: a violation's `Fix:` text."
  @impl Anchor.Domain.RuleShape
  @spec shape(map()) :: String.t()
  def shape(_rule), do: @shape

  defp detect(ast, rule, resolved) do
    ctx = %{
      resolved: resolved,
      owned: owned_namespaces(rule),
      owner: nil,
      top_level?: true,
      bindings: %{},
      local_defs: MapSet.new()
    }

    ast |> walk(ctx, []) |> Enum.reverse()
  end

  defp owned_namespaces(rule) do
    case Map.get(rule, :owned_namespaces) do
      namespaces when is_list(namespaces) and namespaces != [] -> namespaces
      _absent -> :all
    end
  end

  # ---- the walk: expression positions are checked, pattern positions skipped ----

  defp walk({:quote, _meta, args}, _ctx, acc) when is_list(args), do: acc

  defp walk({:defmodule, meta, [name, [{:do, body} | _rest]]}, ctx, acc) do
    module = resolve(name, ctx)
    acc = report_unowned(acc, ctx, module, meta)
    ctx = %{ctx | owner: module, top_level?: false, bindings: %{}, local_defs: local_defs(body)}
    walk(body, ctx, acc)
  end

  # A protocol implementation for a struct is that struct's own code.
  defp walk({:defimpl, _meta, [protocol | rest]}, ctx, acc) do
    opts = rest |> Enum.filter(&Keyword.keyword?/1) |> Enum.concat()
    owner = impl_owner(Keyword.get(opts, :for), protocol, ctx)
    body = Keyword.get(opts, :do)
    ctx = %{ctx | owner: owner, top_level?: false, bindings: %{}, local_defs: local_defs(body)}
    walk(body, ctx, acc)
  end

  defp walk({kind, _meta, [head, body]}, ctx, acc) when kind in @def_kinds and is_list(body) do
    clause_ctx = %{ctx | bindings: bindings(head, body, ctx)}
    acc = walk_head(head, clause_ctx, acc)
    walk(body, clause_ctx, acc)
  end

  defp walk({kind, _meta, [head]}, ctx, acc) when kind in @def_kinds,
    do: walk_head(head, ctx, acc)

  defp walk({:@, _meta, [{attr, _ameta, _value}]}, _ctx, acc) when attr in @type_attrs, do: acc

  defp walk({:cond, _meta, [[do: clauses]]}, ctx, acc) when is_list(clauses) do
    Enum.reduce(clauses, acc, fn
      {:->, _ameta, [conditions, right]}, inner -> walk([conditions, right], ctx, inner)
      other, inner -> walk(other, ctx, inner)
    end)
  end

  defp walk({:->, _meta, [_patterns, right]}, ctx, acc), do: walk(right, ctx, acc)
  defp walk({:=, _meta, [_pattern, right]}, ctx, acc), do: walk(right, ctx, acc)
  defp walk({:<-, _meta, [_pattern, right]}, ctx, acc), do: walk(right, ctx, acc)
  defp walk({:match?, _meta, [_pattern, right]}, ctx, acc), do: walk(right, ctx, acc)

  defp walk({:|>, _meta, [left, {fun, call_meta, args}]}, ctx, acc) when is_list(args),
    do: walk({fun, call_meta, [left | args]}, ctx, acc)

  # B1, B2: a struct literal or struct update syntax naming `S`.
  defp walk({:%, meta, [name, {:%{}, _mmeta, fields}]}, ctx, acc) do
    acc = report_other(acc, ctx, resolve(name, ctx), meta, "%#{Macro.to_string(name)}{")
    walk(fields, ctx, acc)
  end

  # C1: map update syntax on a value known as `S`.
  defp walk({:%{}, meta, [{:|, _bmeta, [base, fields]}]}, ctx, acc) do
    acc = report_other(acc, ctx, value_struct(base, ctx), meta, "%{#{Macro.to_string(base)} |")
    walk([base, fields], ctx, acc)
  end

  defp walk({{:., _dmeta, [receiver, fun]}, meta, args} = call, ctx, acc)
       when is_atom(fun) and is_list(args) do
    case {resolve(receiver, ctx), fun, args} do
      {Map, fun, [first | _rest]} when fun in @map_writers ->
        target = if drops_struct_key?(fun, args), do: nil, else: value_struct(first, ctx)
        acc = report_other(acc, ctx, target, meta, "Map.#{fun}")
        walk(args, ctx, acc)

      {Kernel, fun, _args} when fun in @struct_funs or fun in @path_funs or fun == :match? ->
        walk({fun, [{:kernel_call, true} | meta], args}, ctx, acc)

      _other ->
        walk_children(call, ctx, acc)
    end
  end

  # B3 and C1: `struct/1,2` and `struct!/1,2`, building `S` or changing `v`.
  # A bare name the module defines itself (Kernel's excluded) is not Kernel's.
  defp walk({fun, meta, [first | fields] = args}, ctx, acc)
       when fun in @struct_funs and length(fields) <= 1 do
    target = unless shadowed?(fun, meta, args, ctx), do: struct_target(first, ctx)
    acc = report_other(acc, ctx, target, meta, Atom.to_string(fun))
    walk(args, ctx, acc)
  end

  defp walk({fun, meta, [first | _rest] = args}, ctx, acc) when fun in @path_funs do
    target = unless shadowed?(fun, meta, args, ctx), do: path_target(first, ctx)
    acc = report_other(acc, ctx, target, meta, Atom.to_string(fun))
    walk(args, ctx, acc)
  end

  defp walk(node, ctx, acc), do: walk_children(node, ctx, acc)

  defp walk_children({form, _meta, args}, ctx, acc) when is_list(args),
    do: walk([form | args], ctx, acc)

  defp walk_children({left, right}, ctx, acc), do: walk([left, right], ctx, acc)

  defp walk_children(list, ctx, acc) when is_list(list),
    do: Enum.reduce(list, acc, &walk(&1, ctx, &2))

  defp walk_children(_leaf, _ctx, acc), do: acc

  # A function head is a pattern; only a default argument is an expression.
  defp walk_head({:when, _meta, [call | _guards]}, ctx, acc), do: walk_head(call, ctx, acc)

  defp walk_head({_name, _meta, args}, ctx, acc) when is_list(args) do
    Enum.reduce(args, acc, fn
      {:\\, _dmeta, [_pattern, default]}, inner -> walk(default, ctx, inner)
      _pattern, inner -> inner
    end)
  end

  defp walk_head(_head, _ctx, acc), do: acc

  # ---- owners, scope and names ----

  defp struct_target(first, ctx), do: module_literal(first, ctx) || value_struct(first, ctx)

  defp path_target(first, ctx) do
    first
    |> path_containers()
    |> Enum.map(&value_struct(&1, ctx))
    |> Enum.find(&other?(&1, ctx))
  end

  # A bare call to a name the module defines itself; `Kernel.f` never is.
  defp shadowed?(fun, meta, args, ctx) do
    not Keyword.get(meta, :kernel_call, false) and
      MapSet.member?(ctx.local_defs, {fun, length(args)})
  end

  # Every `{name, arity}` a module body's def/defp makes callable.
  defp local_defs(body) do
    body
    |> List.wrap()
    |> Enum.flat_map(fn
      {:__block__, _meta, statements} -> statements
      statement -> [statement]
    end)
    |> Enum.flat_map(&local_def/1)
    |> MapSet.new()
  end

  defp local_def({kind, _meta, [head | _body]}) when kind in [:def, :defp] do
    case head do
      {:when, _wmeta, [{name, _hmeta, args} | _guards]} when is_atom(name) and is_list(args) ->
        def_arities(name, args)

      {name, _hmeta, args} when is_atom(name) and is_list(args) ->
        def_arities(name, args)

      _other ->
        []
    end
  end

  defp local_def(_statement), do: []

  defp def_arities(name, args) do
    defaults = Enum.count(args, &match?({:\\, _meta, _default}, &1))
    for arity <- (length(args) - defaults)..length(args), do: {name, arity}
  end

  defp impl_owner(nil, _protocol, ctx), do: ctx.owner
  defp impl_owner(targets, protocol, ctx) when is_list(targets), do: resolve(protocol, ctx)
  defp impl_owner(target, protocol, ctx), do: resolve(target, ctx) || resolve(protocol, ctx)

  # The module a name node names, or nil when the resolver could not place it.
  defp resolve({:__aliases__, meta, _parts}, ctx), do: lookup(meta, ctx)
  defp resolve({:__MODULE__, meta, var_ctx}, ctx) when is_atom(var_ctx), do: lookup(meta, ctx)
  defp resolve(_node, _ctx), do: nil

  defp lookup(meta, ctx),
    do: Map.get(ctx.resolved, {Keyword.get(meta, :line), Keyword.get(meta, :column)})

  # A literal module argument (`struct(Turn, ...)`): an alias or `__MODULE__`.
  defp module_literal(node, ctx), do: resolve(node, ctx)

  defp other?(nil, _ctx), do: false
  defp other?(module, ctx), do: in_scope?(module, ctx.owned) and module != ctx.owner

  defp in_scope?(_module, :all), do: true

  defp in_scope?(module, namespaces) do
    name = Atom.to_string(module)

    Enum.any?(namespaces, fn namespace ->
      prefix = Atom.to_string(namespace)
      name == prefix or String.starts_with?(name, prefix <> ".")
    end)
  end

  # ---- issues ----

  defp report_other(acc, ctx, module, meta, trigger) do
    if other?(module, ctx), do: [violation(module, meta, trigger) | acc], else: acc
  end

  defp violation(module, meta, trigger) do
    name = inspect(module)

    %Violation{
      line: Keyword.get(meta, :line),
      trigger: trigger,
      message: "Only #{name}'s own module may build or change #{name}. Fix: " <> @shape
    }
  end

  # Only a top-level module is judged: a nested one shares its namespace.
  defp report_unowned(acc, %{top_level?: true, owned: owned}, module, meta)
       when is_list(owned) and not is_nil(module) do
    if in_scope?(module, owned) do
      acc
    else
      name = inspect(module)

      [
        %Violation{
          line: Keyword.get(meta, :line),
          trigger: name,
          message:
            "Module #{name} is outside owned_namespaces, so its structs would never be " <>
              "checked. Fix: add its namespace to owned_namespaces, or stop selecting this file."
        }
        | acc
      ]
    end
  end

  defp report_unowned(acc, _ctx, _module, _meta), do: acc

  defp drops_struct_key?(:delete, [_map, :__struct__]), do: true
  defp drops_struct_key?(:drop, [_map, keys]) when is_list(keys), do: :__struct__ in keys
  defp drops_struct_key?(_fun, _args), do: false

  # ---- what a value is known to be ----

  # The struct module a value is known to be in this clause, or nil: a struct
  # literal, or a variable every binding in the clause agrees on.
  defp value_struct({:%, _meta, [name, _fields]}, ctx), do: resolve(name, ctx)

  defp value_struct({var, _meta, var_ctx}, ctx) when is_atom(var) and is_atom(var_ctx),
    do: Map.get(ctx.bindings, var)

  defp value_struct(_ast, _ctx), do: nil

  # The containers a path function rebuilds, outermost first: every prefix of
  # `s.a.b` or `s[:a].b` but the leaf; a bare value is its own.
  defp path_containers(path) do
    case path_parent(path) do
      nil -> [path]
      parent -> prefixes(parent)
    end
  end

  defp prefixes(expression) do
    case path_parent(expression) do
      nil -> [expression]
      parent -> prefixes(parent) ++ [expression]
    end
  end

  defp path_parent({{:., _meta, [Access, :get]}, _cmeta, [inner | _keys]}), do: inner

  defp path_parent({{:., _meta, [inner, field]}, _cmeta, []})
       when is_atom(field) and inner != Access,
       do: inner

  defp path_parent(_ast), do: nil

  # What each variable of one `def` clause is known to be: `S` when every
  # place the clause binds it matches it as that one struct.
  defp bindings(head, body, ctx) do
    found = ctx |> collect_head(head, %{}) |> then(&collect(body, ctx, &1))

    for {var, set} <- found,
        [module] <- [MapSet.to_list(set)],
        module != :unknown,
        into: %{},
        do: {var, module}
  end

  defp collect_head(ctx, {:when, _meta, [call | _guards]}, acc), do: collect_head(ctx, call, acc)

  defp collect_head(ctx, {_name, _meta, args}, acc) when is_list(args),
    do: Enum.reduce(args, acc, &collect_pattern(&1, ctx, &2))

  defp collect_head(_ctx, _head, acc), do: acc

  defp collect({:quote, _meta, args}, _ctx, acc) when is_list(args), do: acc

  defp collect({:cond, _meta, [[do: clauses]]}, ctx, acc) when is_list(clauses) do
    Enum.reduce(clauses, acc, fn
      {:->, _ameta, [conditions, right]}, inner -> collect([conditions, right], ctx, inner)
      other, inner -> collect(other, ctx, inner)
    end)
  end

  defp collect({:->, _meta, [patterns, right]}, ctx, acc) when is_list(patterns) do
    acc = Enum.reduce(patterns, acc, &collect_pattern(&1, ctx, &2))
    collect(right, ctx, acc)
  end

  # `v = %S{}` in an expression: the literal is one more binding of `v`.
  defp collect({:=, _meta, [_left, _right]} = match, ctx, acc) do
    {patterns, expression} = split_match(match)

    acc =
      collect_alternatives(patterns, ctx, acc, value_struct(expression, %{ctx | bindings: %{}}))

    collect(expression, ctx, acc)
  end

  defp collect({:<-, _meta, [pattern, right]}, ctx, acc) do
    acc = collect_pattern(pattern, ctx, acc)
    collect(right, ctx, acc)
  end

  defp collect({:match?, _meta, [_pattern, right]}, ctx, acc), do: collect(right, ctx, acc)

  defp collect({fun, _meta, args}, ctx, acc) when is_list(args),
    do: collect([fun | args], ctx, acc)

  defp collect({left, right}, ctx, acc), do: collect([left, right], ctx, acc)

  defp collect(list, ctx, acc) when is_list(list),
    do: Enum.reduce(list, acc, &collect(&1, ctx, &2))

  defp collect(_leaf, _ctx, acc), do: acc

  # `a = b = expr`: `a` and `b` both match expr's value.
  defp split_match({:=, _meta, [left, right]}) do
    {patterns, expression} = split_match(right)
    {[left | patterns], expression}
  end

  defp split_match(expression), do: {[], expression}

  defp collect_pattern({:when, _meta, args}, ctx, acc) when is_list(args) do
    {patterns, _guard} = Enum.split(args, -1)
    Enum.reduce(patterns, acc, &collect_pattern(&1, ctx, &2))
  end

  defp collect_pattern({:\\, _meta, [pattern, default]}, ctx, acc) do
    acc = collect_pattern(pattern, ctx, acc)
    collect(default, ctx, acc)
  end

  defp collect_pattern(pattern, ctx, acc), do: collect_alternatives([pattern], ctx, acc)

  # Patterns that all match one value: a bare variable among them is the
  # struct when exactly one struct is named, and unknown otherwise.
  defp collect_alternatives(patterns, ctx, acc, expression_struct \\ nil) do
    alternatives = Enum.flat_map(patterns, &alternatives/1)
    from_expression = if expression_struct, do: [expression_struct], else: []

    module =
      alternatives
      |> Enum.flat_map(&struct_name(&1, ctx))
      |> Enum.concat(from_expression)
      |> Enum.uniq()
      |> single()

    Enum.reduce(alternatives, acc, fn
      {var, _meta, var_ctx}, inner when is_atom(var) and is_atom(var_ctx) ->
        record(inner, var, module)

      {:%, _meta, [_name, fields]}, inner ->
        collect_inner(fields, ctx, inner)

      other, inner ->
        collect_inner(other, ctx, inner)
    end)
  end

  defp alternatives({:=, _meta, [left, right]}), do: alternatives(left) ++ alternatives(right)
  defp alternatives(pattern), do: [pattern]

  defp struct_name({:%, _meta, [name, _fields]}, ctx) do
    case resolve(name, ctx) do
      nil -> [:unknown]
      module -> [module]
    end
  end

  defp struct_name(_pattern, _ctx), do: []

  defp single([module]), do: module
  defp single(_modules), do: :unknown

  # Inside a pattern every variable is bound; only a nested `=` names a struct.
  defp collect_inner({:=, _meta, [_left, _right]} = match, ctx, acc),
    do: collect_alternatives([match], ctx, acc)

  defp collect_inner({:^, _meta, _pinned}, _ctx, acc), do: acc
  defp collect_inner({:__aliases__, _meta, _segments}, _ctx, acc), do: acc

  defp collect_inner({var, _meta, var_ctx}, _ctx, acc) when is_atom(var) and is_atom(var_ctx),
    do: record(acc, var, :unknown)

  defp collect_inner({:%, _meta, [_name, fields]}, ctx, acc), do: collect_inner(fields, ctx, acc)

  defp collect_inner({_fun, _meta, args}, ctx, acc) when is_list(args),
    do: collect_inner(args, ctx, acc)

  defp collect_inner({left, right}, ctx, acc), do: collect_inner([left, right], ctx, acc)

  defp collect_inner(list, ctx, acc) when is_list(list),
    do: Enum.reduce(list, acc, &collect_inner(&1, ctx, &2))

  defp collect_inner(_leaf, _ctx, acc), do: acc

  defp record(acc, var, entry) do
    if String.starts_with?(Atom.to_string(var), "_"),
      do: acc,
      else: Map.update(acc, var, MapSet.new([entry]), &MapSet.put(&1, entry))
  end
end
