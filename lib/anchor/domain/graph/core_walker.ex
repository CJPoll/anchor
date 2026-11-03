defmodule Anchor.Domain.Graph.CoreWalker do
  @moduledoc """
  Reads one function's Core Erlang into call and struct-use edges — **Domain**,
  pure (DND-5438). `:cerl` is a pure accessor library over Core tuples.

  Core is a small lambda calculus: every multi-clause head, `with`, `if`,
  `cond` and `case` is already a `case` in it, `try` a `try`, an anonymous
  function a `fun`, and `receive` (in OTP 28's Core) a `letrec` loop over
  `recv_peek_message` primops; a `for` over a variable is a call to
  `Enum.reduce/3` with a `fun`. One walk over every node reaches every call
  site. The shapes, as `Anchor.Adapters.BeamReader` produces them
  (`core_v1` with `:no_copt`, Elixir 1.19 / OTP 28):

    * `call 'M':'f'(...)` with literal module and name — `:remote` to
      `{M, f, arity}`. A call through `@mod` is one too: the attribute is a
      literal in Core.
    * `apply 'f'/a(...)` — `:local` to `{module, f, a}`. A `letrec`-bound name
      (the loop Core makes of a `receive`, or of a comprehension over a binary
      or a literal) is part of this function's body, not a call.
    * `call 'erlang':'make_fun'(M, F, A)`, or a literal external fun — `:capture`
      to `{M, F, A}`; a module function name used as a value (`&f/a`) —
      `:capture` to `{module, f, a}`.
    * `call 'erlang':'apply'(...)` (`apply/2,3`) — `:apply` to
      `{:dynamic, name | nil, arity | nil, :call}`; `apply V(...)` where `V` is
      a variable (`fun.(x)`) — `:apply` to `{:dynamic, nil, arity, :variable}`.
    * `call V:'f'(...)` — `{:dynamic, f, arity, :variable}`, or `:call` when
      `V` was let-bound to a call (a computed module, `Module.concat(...)`); a
      variable let-bound to a literal module resolves to a `:remote` call.
    * Struct uses, from map nodes whose `__struct__` key holds a literal module:
      a map literal (or a map built on `%{}`) is `:build`; a map in a pattern
      is `:match`; a struct update `%S{s | ...}` is the `case` Elixir emits that
      checks `s` against `%{__struct__: S}` and otherwise raises
      `{:badstruct, S, s}`, which is `:update` (its pattern is not also a
      `:match`).

  Calls into the helpers the compiler emits (`:erlang` BIFs in guards,
  `:erlang.error/1` on a failed struct update) are kept as `:remote` calls:
  filtering is a rule's job.

  Every edge carries the line of its node's Core annotation (or of the first
  annotated node inside it), `line_source: :call`. A node with no line anywhere
  gets the function's def line, `line_source: :def`. Line 0 is no line (the
  compiler's marker for generated code; macro output itself carries the macro
  call site's line).
  """

  alias Anchor.Domain.Graph.Call
  alias Anchor.Domain.Graph.StructUse

  @doc """
  Walks `core_fun`, the Core `c_fun` of `module.name/arity`, and returns its
  call and struct-use edges in source traversal order. `def_line` is the
  function's def line, used when a node has no line; when it is `nil`, the
  line of the `c_fun`'s own annotation is used (and when that is missing too,
  the edge's line is `nil`, `line_source: :def`). `file` is the module's source
  file as Core's `{:file, _}` annotations name it, the cwd-relative path
  (`elixir_v1` `:relative_file`, not the absolute `:file`): a line annotated with
  another file (code a macro injected with `quote location: :keep`) is a line
  of that other file, so it is not used, and the def line stands in. With
  `file` nil, every annotated line is used.
  """
  @spec walk(module(), {atom(), arity()}, :cerl.cerl(), non_neg_integer() | nil, String.t() | nil) ::
          {[Call.t()], [StructUse.t()]}
  def walk(module, {name, arity}, core_fun, def_line \\ nil, file \\ nil) do
    ctx = %{
      module: module,
      file: file,
      from: {module, name, arity},
      def_line: def_line || own_line(core_fun, file),
      env: %{},
      letrec: MapSet.new(),
      pattern?: false
    }

    {calls, uses} = visit(core_fun, ctx, {[], []})
    {Enum.reverse(calls), Enum.reverse(uses)}
  end

  defp visit(node, ctx, acc) do
    case :cerl.type(node) do
      :call -> visit_call(node, ctx, acc)
      :apply -> visit_apply(node, ctx, acc)
      :var -> visit_var(node, ctx, acc)
      :let -> visit_let(node, ctx, acc)
      :letrec -> visit_letrec(node, ctx, acc)
      :case -> visit_case(node, ctx, acc)
      :clause -> visit_clause(node, ctx, acc)
      :map -> visit_map(node, ctx, acc)
      :literal -> visit_literal(node, ctx, acc)
      _other -> visit_children(node, ctx, acc)
    end
  end

  defp visit_children(node, ctx, acc) do
    node
    |> :cerl.subtrees()
    |> List.flatten()
    |> Enum.reduce(acc, &visit(&1, ctx, &2))
  end

  defp visit_all(nodes, ctx, acc), do: Enum.reduce(nodes, acc, &visit(&1, ctx, &2))

  # --- calls -----------------------------------------------------------------

  defp visit_call(node, ctx, acc) do
    module = :cerl.call_module(node)
    name = :cerl.call_name(node)
    args = :cerl.call_args(node)

    case {literal(module), literal(name), length(args)} do
      {{:ok, :erlang}, {:ok, :make_fun}, 3} ->
        capture(node, args, ctx, acc)

      {{:ok, :erlang}, {:ok, :apply}, arity} when arity in [2, 3] ->
        apply_call(node, args, ctx, acc)

      _other ->
        plain_call(node, module, name, args, ctx, acc)
    end
  end

  defp capture(node, [m, f, a] = args, ctx, acc) do
    to =
      case {literal(m), literal(f), literal(a)} do
        {{:ok, mod}, {:ok, fun}, {:ok, arity}}
        when is_atom(mod) and is_atom(fun) and is_integer(arity) ->
          {mod, fun, arity}

        {_m, f_lit, a_lit} ->
          {:dynamic, atom_or_nil(f_lit), integer_or_nil(a_lit), receiver(m, ctx)}
      end

    acc = add_call(acc, node, to, :capture, ctx)
    visit_all(args, ctx, acc)
  end

  defp apply_call(node, [fun, args_list], ctx, acc) do
    acc = add_call(acc, node, {:dynamic, nil, list_length(args_list), :call}, :apply, ctx)
    visit_all([fun, args_list], ctx, acc)
  end

  defp apply_call(node, [m, f, args_list], ctx, acc) do
    to = {:dynamic, atom_or_nil(literal(f)), list_length(args_list), :call}
    acc = add_call(acc, node, to, :apply, ctx)
    visit_all([m, f, args_list], ctx, acc)
  end

  defp plain_call(node, module, name, args, ctx, acc) do
    arity = length(args)

    to =
      case {resolved_module(module, ctx), literal(name)} do
        {{:ok, mod}, {:ok, fun}} when is_atom(mod) and is_atom(fun) -> {mod, fun, arity}
        {_mod, name_lit} -> {:dynamic, atom_or_nil(name_lit), arity, receiver(module, ctx)}
      end

    acc = add_call(acc, node, to, :remote, ctx)
    visit_all([module, name | args], ctx, acc)
  end

  defp visit_apply(node, ctx, acc) do
    operator = :cerl.apply_op(node)
    args = :cerl.apply_args(node)

    acc =
      cond do
        module_fname?(operator, ctx) ->
          {name, arity} = :cerl.var_name(operator)
          add_call(acc, node, {ctx.module, name, arity}, :local, ctx)

        :cerl.is_c_fname(operator) ->
          acc

        :cerl.is_c_var(operator) ->
          add_call(acc, node, {:dynamic, nil, length(args), receiver(operator, ctx)}, :apply, ctx)

        true ->
          visit(
            operator,
            ctx,
            add_call(acc, node, {:dynamic, nil, length(args), :call}, :apply, ctx)
          )
      end

    visit_all(args, ctx, acc)
  end

  # A module function's name used as a value (`&f/a`): a capture.
  defp visit_var(node, ctx, acc) do
    if module_fname?(node, ctx) do
      {name, arity} = :cerl.var_name(node)
      add_call(acc, node, {ctx.module, name, arity}, :capture, ctx)
    else
      acc
    end
  end

  defp module_fname?(node, ctx),
    do: :cerl.is_c_fname(node) and not MapSet.member?(ctx.letrec, :cerl.var_name(node))

  # --- bindings ---------------------------------------------------------------

  defp visit_let(node, ctx, acc) do
    arg = :cerl.let_arg(node)
    acc = visit(arg, ctx, acc)
    env = bind(ctx.env, :cerl.let_vars(node), arg)
    visit(:cerl.let_body(node), %{ctx | env: env}, acc)
  end

  defp bind(env, [var], arg) do
    case binding(arg, env) do
      nil -> Map.delete(env, :cerl.var_name(var))
      value -> Map.put(env, :cerl.var_name(var), value)
    end
  end

  defp bind(env, vars, _arg), do: Enum.reduce(vars, env, &Map.delete(&2, :cerl.var_name(&1)))

  defp binding(arg, env) do
    case :cerl.type(arg) do
      :literal -> {:literal, :cerl.concrete(arg)}
      :var -> Map.get(env, :cerl.var_name(arg))
      type when type in [:call, :apply] -> :call
      _other -> nil
    end
  end

  defp visit_letrec(node, ctx, acc) do
    defs = :cerl.letrec_defs(node)

    letrec =
      Enum.reduce(defs, ctx.letrec, fn {fname, _fun}, set ->
        MapSet.put(set, :cerl.var_name(fname))
      end)

    ctx = %{ctx | letrec: letrec}
    acc = Enum.reduce(defs, acc, fn {_fname, fun}, acc -> visit(fun, ctx, acc) end)
    visit(:cerl.letrec_body(node), ctx, acc)
  end

  # --- cases and patterns -----------------------------------------------------

  defp visit_case(node, ctx, acc) do
    clauses = :cerl.case_clauses(node)

    case Enum.find_value(clauses, &badstruct_raise/1) do
      nil ->
        visit_children(node, ctx, acc)

      struct ->
        acc = add_struct_use(acc, node, struct, :update, ctx)
        acc = visit(:cerl.case_arg(node), ctx, acc)

        Enum.reduce(clauses, acc, fn clause, acc ->
          visit_all([:cerl.clause_guard(clause), :cerl.clause_body(clause)], ctx, acc)
        end)
    end
  end

  # The clause Elixir emits for a struct update whose subject is not the
  # struct: `erlang:error({badstruct, S, Subject})`.
  defp badstruct_raise(clause) do
    body = :cerl.clause_body(clause)

    with true <- :cerl.is_c_call(body),
         {:ok, :erlang} <- literal(:cerl.call_module(body)),
         {:ok, :error} <- literal(:cerl.call_name(body)),
         [tuple] <- :cerl.call_args(body),
         true <- :cerl.is_c_tuple(tuple),
         [tag, struct, _subject] <- :cerl.tuple_es(tuple),
         {:ok, :badstruct} <- literal(tag),
         {:ok, module} when is_atom(module) and module not in [nil, true, false] <-
           literal(struct) do
      module
    else
      _not_a_badstruct_raise -> nil
    end
  end

  defp visit_clause(node, ctx, acc) do
    acc = visit_all(:cerl.clause_pats(node), %{ctx | pattern?: true}, acc)
    visit_all([:cerl.clause_guard(node), :cerl.clause_body(node)], %{ctx | pattern?: false}, acc)
  end

  defp visit_map(node, ctx, acc) do
    acc =
      case map_struct(node) do
        nil -> acc
        struct -> add_struct_use(acc, node, struct, map_op(node, ctx), ctx)
      end

    visit_children(node, ctx, acc)
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

  defp map_op(node, ctx) do
    cond do
      ctx.pattern? or :cerl.is_c_map_pattern(node) -> :match
      literal(:cerl.map_arg(node)) == {:ok, %{}} -> :build
      true -> :update
    end
  end

  defp visit_literal(node, ctx, acc) do
    value = :cerl.concrete(node)
    op = if ctx.pattern?, do: :match, else: :build

    acc =
      value
      |> literal_structs([])
      |> Enum.reverse()
      |> Enum.reduce(acc, &add_struct_use(&2, node, &1, op, ctx))

    case external_fun(value) do
      nil -> acc
      mfa -> add_call(acc, node, mfa, :capture, ctx)
    end
  end

  # Struct modules of every struct map inside a literal term, newest first
  # (the caller reverses them into term order).
  defp literal_structs(%{__struct__: module} = map, found)
       when is_atom(module) and module not in [nil, true, false],
       do: map |> Map.delete(:__struct__) |> Map.values() |> literal_structs([module | found])

  defp literal_structs(map, found) when is_map(map),
    do: map |> Map.to_list() |> literal_structs(found)

  defp literal_structs(list, found) when is_list(list),
    do: list |> improper_to_list() |> Enum.reduce(found, &literal_structs/2)

  defp literal_structs(tuple, found) when is_tuple(tuple),
    do: tuple |> Tuple.to_list() |> literal_structs(found)

  defp literal_structs(_other, found), do: found

  defp improper_to_list([head | tail]) when is_list(tail), do: [head | improper_to_list(tail)]
  defp improper_to_list([head | tail]), do: [head, tail]
  defp improper_to_list([]), do: []

  defp external_fun(value) when is_function(value) do
    case :erlang.fun_info(value, :type) do
      {:type, :external} ->
        {:module, m} = :erlang.fun_info(value, :module)
        {:name, f} = :erlang.fun_info(value, :name)
        {:arity, a} = :erlang.fun_info(value, :arity)
        {m, f, a}

      {:type, :local} ->
        nil
    end
  end

  defp external_fun(_value), do: nil

  # --- values -------------------------------------------------------------------

  defp literal(node) do
    if :cerl.is_literal(node), do: {:ok, :cerl.concrete(node)}, else: :error
  end

  defp resolved_module(module, ctx) do
    case literal(module) do
      {:ok, value} ->
        {:ok, value}

      :error ->
        if :cerl.is_c_var(module) do
          case Map.get(ctx.env, :cerl.var_name(module)) do
            {:literal, value} -> {:ok, value}
            _other -> :error
          end
        else
          :error
        end
    end
  end

  defp receiver(node, ctx) do
    cond do
      not :cerl.is_c_var(node) -> :call
      Map.get(ctx.env, :cerl.var_name(node)) == :call -> :call
      true -> :variable
    end
  end

  defp atom_or_nil({:ok, atom}) when is_atom(atom), do: atom
  defp atom_or_nil(_other), do: nil

  defp integer_or_nil({:ok, integer}) when is_integer(integer), do: integer
  defp integer_or_nil(_other), do: nil

  # The length of a Core list whose spine is known, else nil.
  defp list_length(node) do
    cond do
      :cerl.is_c_cons(node) ->
        case list_length(:cerl.cons_tl(node)) do
          nil -> nil
          length -> length + 1
        end

      :cerl.is_literal(node) and is_list(:cerl.concrete(node)) ->
        literal_list_length(:cerl.concrete(node))

      true ->
        nil
    end
  end

  defp literal_list_length(list) do
    if proper_list?(list), do: length(list), else: nil
  end

  defp proper_list?([]), do: true
  defp proper_list?([_head | tail]), do: proper_list?(tail)
  defp proper_list?(_tail), do: false

  # --- edges and lines --------------------------------------------------------

  defp add_call({calls, uses}, node, to, kind, ctx) do
    {line, source} = line_of(node, ctx)
    call = %Call{from: ctx.from, to: to, kind: kind, line: line, line_source: source}
    {[call | calls], uses}
  end

  defp add_struct_use({calls, uses}, node, struct, op, ctx) do
    {line, source} = line_of(node, ctx)
    use = %StructUse{from: ctx.from, struct: struct, op: op, line: line, line_source: source}
    {calls, [use | uses]}
  end

  defp line_of(node, ctx) do
    case first_line(node, ctx.file) do
      nil -> {ctx.def_line, :def}
      line -> {line, :call}
    end
  end

  # The node's own line, else the first line found inside it (pre-order).
  defp first_line(node, file) do
    case own_line(node, file) do
      nil -> node |> :cerl.subtrees() |> List.flatten() |> Enum.find_value(&first_line(&1, file))
      line -> line
    end
  end

  # A line of `file`: an annotation naming another file is not one.
  defp own_line(node, file) do
    annotation = :cerl.get_ann(node)
    if same_file?(annotation, file), do: annotation_line(annotation), else: nil
  end

  defp same_file?(_annotation, nil), do: true

  defp same_file?(annotation, file) do
    case List.keyfind(annotation, :file, 0) do
      {:file, annotated} -> List.to_string(annotated) == file
      nil -> true
    end
  end

  defp annotation_line(annotation) do
    Enum.find_value(annotation, fn
      line when is_integer(line) and line > 0 -> line
      {line, column} when is_integer(line) and line > 0 and is_integer(column) -> line
      _other -> nil
    end)
  end
end
