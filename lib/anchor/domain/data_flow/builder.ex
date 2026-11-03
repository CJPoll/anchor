defmodule Anchor.Domain.DataFlow.Builder do
  @moduledoc """
  The walk behind `Anchor.Domain.DataFlow.analyze/1` (DND-5439). Pure
  **Domain**.

  It walks one clause in evaluation order with a `Scope` stack:

    * a pattern (a parameter, the left of `=`, a clause head, the left of a
      `with`/`for` `<-`) binds each non-underscore variable to a fresh key,
      after the right-hand side is read, so `x = x + 1` reads the old `x`;
    * every other variable is a use of the key in scope; `^x` is a use;
    * each clause of `case`/`cond`/`receive`/`try`/`fn`/`for`, and each block
      of `if`/`unless`, opens a scope dropped at its end; `with` steps bind
      into the scope of the later steps and the `do` block, and each `else`
      clause gets its own;
    * a scoping form that is a whole expression of a block (or the right of a
      top-level `=`) becomes a `:branch`/`:fn`/`:for` node whose clause bodies
      are blocks of their own; nested inside any other expression it is part
      of that expression's node;
    * anything else, including any macro call it does not know, is one node
      that uses every variable in it. Nothing is dropped.
  """

  alias Anchor.Domain.DataFlow
  alias Anchor.Domain.DataFlow.Forms
  alias Anchor.Domain.DataFlow.Node
  alias Anchor.Domain.DataFlow.Scope

  @doc "Analyses one clause. See `Anchor.Domain.DataFlow.analyze/1`."
  @spec build([Macro.t()], [Macro.t()], Macro.t()) :: DataFlow.t()
  def build(args, guards, body) do
    state = %{scope: Scope.new(), nodes: %{}, defs: %{}, uses: %{}, blocks: %{}, cur: nil}

    state = Enum.reduce(args, start(state, :param), &bind_pattern(&2, &1))
    params = Enum.reverse(state.cur.binds)

    state = Enum.reduce(Forms.desugar_pipes(guards), start(state, :guard), &expr(&2, &1))
    guard_uses = state.cur.uses |> Enum.reverse() |> Enum.uniq()

    state = walk_block(%{state | cur: nil}, [], Forms.statements(Forms.desugar_pipes(body)), nil)

    %DataFlow{
      nodes: state.nodes,
      defs: state.defs,
      uses: Map.new(state.uses, fn {key, ids} -> {key, ids |> Enum.uniq() |> Enum.sort()} end),
      params: params,
      guard_uses: guard_uses,
      result: List.last(Map.fetch!(state.blocks, [])),
      blocks: state.blocks
    }
  end

  defp bind_pattern(state, pattern) do
    %{vars: vars, pins: pins, sizes: sizes} = Forms.pattern_parts(pattern)
    state = Enum.reduce(pins, state, &expr(&2, &1))
    state = vars |> Enum.uniq() |> Enum.reduce(state, &bind_var(&2, &1))
    Enum.reduce(sizes, state, &expr(&2, &1))
  end

  defp bind_var(%{cur: cur} = state, {name, context}) do
    {key, scope} = Scope.bind(state.scope, name, context)
    binds = if Scope.depth(scope) == cur.depth, do: [key | cur.binds], else: cur.binds
    %{state | scope: scope, defs: Map.put(state.defs, key, cur.id), cur: %{cur | binds: binds}}
  end

  defp clause_body(state, %{body: :none}, _index, :expr), do: state
  defp clause_body(state, %{body: body}, _index, :expr), do: expr(state, body)

  defp clause_body(state, %{body: body, value: value?}, index, {:block, id}) do
    block = if value?, do: id ++ [:clause, index], else: id ++ [:after]
    walk_block(state, block, Forms.statements(body), id)
  end

  defp expr(state, {name, _meta, context} = var) when is_atom(name) and is_atom(context),
    do: if(Forms.variable?(var), do: use_var(state, name, context), else: state)

  defp expr(state, {:^, _meta, [inner]}), do: expr(state, inner)

  # `quote` builds code; nothing in it binds or reads in this clause except the
  # arguments of `unquote`/`unquote_splicing` and the quote's own options.
  defp expr(state, {:quote, _meta, args}) when is_list(args),
    do: Enum.reduce(Forms.quote_reads(args), state, &expr(&2, &1))

  # `binding/0,1` reads every variable in scope by name.
  defp expr(state, {:binding, _meta, args}) when is_list(args) do
    state =
      Enum.reduce(Scope.visible(state.scope), state, fn key, state -> use_key(state, key) end)

    Enum.reduce(args, state, &expr(&2, &1))
  end

  defp expr(state, {:=, _meta, [pattern, rhs]}), do: state |> expr(rhs) |> bind_pattern(pattern)
  defp expr(state, {:@, _meta, _args}), do: state

  defp expr(state, {:&, _meta, [{:/, _smeta, [fun, arity]}]}) when is_integer(arity),
    do:
      if(match?({_name, _fmeta, context} when is_atom(context), fun),
        do: state,
        else: expr(state, fun)
      )

  defp expr(state, {:"::", _meta, [left, spec]}),
    do: Enum.reduce(Forms.spec_exprs(spec), expr(state, left), &expr(&2, &1))

  defp expr(state, {form, _meta, args} = ast) when is_list(args) do
    case Forms.decompose(ast) do
      {:ok, desc} ->
        walk_form(state, desc, :expr)

      :error ->
        Enum.reduce(args, if(is_atom(form), do: state, else: expr(state, form)), &expr(&2, &1))
    end
  end

  defp expr(state, {left, right}), do: state |> expr(left) |> expr(right)
  defp expr(state, list) when is_list(list), do: Enum.reduce(list, state, &expr(&2, &1))
  defp expr(state, _literal), do: state

  defp finish(state, node) do
    node = %{
      node
      | binds: Enum.reverse(state.cur.binds),
        uses: state.cur.uses |> Enum.reverse() |> Enum.uniq()
    }

    uses =
      Enum.reduce(node.uses, state.uses, fn key, acc ->
        Map.update(acc, key, [node.id], &[node.id | &1])
      end)

    %{state | nodes: Map.put(state.nodes, node.id, node), uses: uses}
  end

  defp pop(state), do: %{state | scope: Scope.pop(state.scope)}

  defp pre_item(state, {:match, pattern, guards, rhs}),
    do: Enum.reduce(guards, state |> expr(rhs) |> bind_pattern(pattern), &expr(&2, &1))

  defp pre_item(state, {:expr, ast}), do: expr(state, ast)

  defp push(state), do: %{state | scope: Scope.push(state.scope)}

  defp start(state, id),
    do: %{state | cur: %{id: id, binds: [], uses: [], depth: Scope.depth(state.scope)}}

  # A whole expression of a block: `pattern = <form>` chains and bare forms become
  # branch nodes with blocks of their own; anything else is one node.
  defp statement_form({:=, _meta, [pattern, rhs]}) do
    case statement_form(rhs) do
      {:form, patterns, desc} -> {:form, [pattern | patterns], desc}
      :plain -> :plain
    end
  end

  defp statement_form(ast) do
    case Forms.decompose(ast) do
      {:ok, desc} -> {:form, [], desc}
      :error -> :plain
    end
  end

  defp use_key(%{cur: cur} = state, key), do: %{state | cur: %{cur | uses: [key | cur.uses]}}

  defp use_var(state, name, context), do: use_key(state, Scope.lookup(state.scope, name, context))

  defp walk_block(state, block, statements, parent) do
    {state, ids} =
      statements
      |> Enum.with_index()
      |> Enum.reduce({state, []}, fn {statement, index}, {state, ids} ->
        id = block ++ [index]
        {walk_statement(state, id, block, parent, statement), [id | ids]}
      end)

    %{state | blocks: Map.put(state.blocks, block, Enum.reverse(ids))}
  end

  # A clause's `pre` steps (`with`/`for` steps, a `cond` condition) run before
  # its patterns bind: a `for ... reduce:` reducer pattern sees the generators,
  # never the other way round.
  defp walk_clause(state, clause, index, mode) do
    state = Enum.reduce(clause.pre, push(state), &pre_item(&2, &1))
    state = Enum.reduce(clause.patterns, state, &bind_pattern(&2, &1))
    state = Enum.reduce(clause.guards, state, &expr(&2, &1))
    state |> clause_body(clause, index, mode) |> pop()
  end

  defp walk_form(state, desc, mode) do
    state = Enum.reduce(desc.head, state, &expr(&2, &1))

    desc.clauses
    |> Enum.with_index()
    |> Enum.reduce(state, fn {clause, index}, state -> walk_clause(state, clause, index, mode) end)
  end

  defp walk_statement(state, id, block, parent, statement) do
    saved = state.cur

    node = %Node{
      id: id,
      ast: statement,
      line: Forms.first_line(statement),
      block: block,
      parent: parent
    }

    state = walk_statement_body(start(state, id), node, statement_form(statement))
    %{state | cur: saved}
  end

  defp walk_statement_body(state, node, :plain) do
    kind = if match?({:=, _meta, [_pattern, _rhs]}, node.ast), do: :bind, else: :expr
    state = expr(state, node.ast)

    finish(state, %{
      node
      | kind: kind,
        unsliceable: Forms.unsliceable([node.ast]),
        refutable: Forms.refutable_match?([node.ast])
    })
  end

  defp walk_statement_body(state, node, {:form, patterns, desc}) do
    state = walk_form(state, desc, {:block, node.id})
    state = patterns |> Enum.reverse() |> Enum.reduce(state, &bind_pattern(&2, &1))

    finish(state, %{
      node
      | kind: desc.kind,
        unsliceable: form_unsliceable(desc, patterns),
        refutable: Enum.any?(patterns, &Forms.refutable?/1) or Forms.refutable_match?(desc.head)
    })
  end

  defp form_unsliceable(%{form: :receive}, _patterns), do: :receive

  defp form_unsliceable(desc, patterns) do
    own =
      Enum.flat_map(desc.clauses, fn clause ->
        clause.patterns ++ clause.guards ++ Enum.flat_map(clause.pre, &pre_asts/1)
      end)

    Forms.unsliceable(patterns ++ desc.head ++ own)
  end

  defp pre_asts({:match, pattern, guards, rhs}), do: [pattern, rhs | guards]
  defp pre_asts({:expr, ast}), do: [ast]
end
