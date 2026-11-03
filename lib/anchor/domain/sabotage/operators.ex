defmodule Anchor.Domain.Sabotage.Operators do
  @moduledoc """
  The six causal sabotage operators (DND-5471). Pure **Domain**: each reads
  one clause of the source tree (`Anchor.Domain.Sabotage.SourceTree`) and
  returns its candidate edits, in source order. Whether an edit still compiles
  is `Anchor.Domain.Sabotage.Mutator`'s job, after the edit is made.

  An edit is `%{operator, variant, target, range, replacement, skip}`:
  `target` is the original text of the node the edit breaks (normalized into
  the id later), `range` the exact text it replaces, and `skip` `nil` or the
  reason the edit cannot be made at all.

  | Operator | Breaks |
  |---|---|
  | `delete_statement` | removes a non-final statement of a block that is not an effect call (its whole lines) |
  | `drop_effect_call` | the same, for a statement (or the right side of its `=`) that is an effect call (`Anchor.Domain.Sabotage.EffectCalls`) |
  | `narrow_clause` | one clause of a function or a `case` with two or more clauses never matches: its head gains `when node() == :__anchor_sabotage_never__` (an existing guard `g` becomes `(g) and ...`) |
  | `with_passthrough` | one `pat <- expr` step of a `with` stops checking: every literal in `pat` becomes `_`, `%Mod{...}` becomes `%{...}`, a step guard is dropped |
  | `force_condition` | the condition of an `if`/`unless` or one `cond` clause (not a final literal `true`) becomes `Process.get(:__anchor_sabotage__) == nil` (variant `true`) or `!= nil` (variant `false`): opaque to the compiler, and the key is never set |
  | `return_input` | the clause returns one of its bare-variable parameters (variant = its index); every other head variable is renamed `_name` |

  `narrow_clause` skips a function or `case` with a single clause: making the
  only clause never match turns every call into a `FunctionClauseError` (or
  `CaseClauseError`), which any test reaching it kills and which says nothing
  about which behaviour the clause carries.
  """

  alias Anchor.Domain.Sabotage.EffectCalls
  alias Anchor.Domain.Sabotage.Patch
  alias Anchor.Domain.Sabotage.SourceTree

  @never "node() == :__anchor_sabotage_never__"
  @forced %{
    true: "Process.get(:__anchor_sabotage__) == nil",
    false: "Process.get(:__anchor_sabotage__) != nil"
  }

  @type ctx :: %{
          source: String.t(),
          clause: SourceTree.clause(),
          clause_count: pos_integer(),
          effect_calls: [String.t()]
        }
  @type edit :: %{
          operator: atom(),
          variant: nil | boolean() | non_neg_integer(),
          target: String.t(),
          range: Patch.range(),
          replacement: String.t(),
          skip: nil | String.t()
        }

  @doc "Every operator, in the order the generator runs them."
  @spec all() :: [atom()]
  def all,
    do: [
      :delete_statement,
      :drop_effect_call,
      :narrow_clause,
      :with_passthrough,
      :force_condition,
      :return_input
    ]

  @spec delete_statement(ctx()) :: [edit()]
  def delete_statement(ctx), do: statement_edits(ctx, :delete_statement)

  @spec drop_effect_call(ctx()) :: [edit()]
  def drop_effect_call(ctx), do: statement_edits(ctx, :drop_effect_call)

  @spec force_condition(ctx()) :: [edit()]
  def force_condition(%{source: source, clause: clause}) do
    clause.body
    |> SourceTree.nodes()
    |> Enum.flat_map(&conditions/1)
    |> Enum.flat_map(fn condition ->
      range = SourceTree.range(condition)
      target = Patch.slice(source, range)

      for variant <- [true, false],
          do: edit(:force_condition, variant, target, range, @forced[variant])
    end)
    |> sorted()
  end

  @spec narrow_clause(ctx()) :: [edit()]
  def narrow_clause(%{source: source, clause: clause, clause_count: count}) do
    own =
      if count >= 2,
        do: [narrow(source, clause.head, clause.call, clause.guard)],
        else: []

    cases =
      clause.body
      |> SourceTree.nodes()
      |> Enum.flat_map(&case_clauses/1)
      |> Enum.flat_map(fn
        {:->, _meta, [[{:when, _wmeta, [pattern, guard]} = head], _body]} ->
          [narrow(source, head, pattern, guard)]

        {:->, _meta, [[pattern], _body]} ->
          [narrow(source, pattern, pattern, nil)]

        _other ->
          []
      end)

    sorted(own ++ cases)
  end

  @spec return_input(ctx()) :: [edit()]
  def return_input(%{source: source, clause: clause}) do
    clause.args
    |> Enum.with_index()
    |> Enum.flat_map(fn {param, index} ->
      case param_var(param) do
        {name, _meta, _context} -> [return_edit(source, clause, name, index)]
        nil -> []
      end
    end)
  end

  @spec with_passthrough(ctx()) :: [edit()]
  def with_passthrough(%{source: source, clause: clause}) do
    clause.body
    |> SourceTree.nodes()
    |> Enum.flat_map(&with_steps/1)
    |> Enum.map(&passthrough(source, &1))
    |> sorted()
  end

  defp case_clauses({:case, _meta, [_scrutinee, kw]}) when is_list(kw) do
    case SourceTree.keyword(kw, :do) do
      [_first, _second | _rest] = clauses -> clauses
      _one_or_none -> []
    end
  end

  defp case_clauses(_node), do: []

  defp conditions({form, _meta, [condition, kw]}) when form in [:if, :unless] and is_list(kw),
    do: [condition]

  defp conditions({:cond, _meta, [kw]}) when is_list(kw) do
    case SourceTree.keyword(kw, :do) do
      clauses when is_list(clauses) ->
        for {:->, _ameta, [[condition], _body]} <- clauses,
            not match?({:__block__, _lmeta, [true]}, condition),
            do: condition

      _other ->
        []
    end
  end

  defp conditions(_node), do: []

  defp edit(operator, variant, target, range, replacement, skip \\ nil),
    do: %{
      operator: operator,
      variant: variant,
      target: target,
      range: range,
      replacement: replacement,
      skip: skip
    }

  defp effect_statement?(source, statement, tokens) do
    case SourceTree.quoted(Patch.slice(source, SourceTree.range(statement))) do
      {:ok, ast} -> {:ok, EffectCalls.effect?(rhs(ast), tokens)}
      :error -> :error
    end
  end

  # The variable nodes of a head's parameters, in source order: not a pin's
  # variable, not a default value, not an underscored one.
  defp head_vars(args) do
    args
    |> Enum.map(fn
      {:\\, _meta, [pattern, _default]} -> pattern
      pattern -> pattern
    end)
    |> SourceTree.nodes()
    |> Enum.reject(&match?({:^, _meta, _args}, &1))
    |> then(fn nodes ->
      pinned = for {:^, _meta, [var]} <- nodes, do: var
      Enum.filter(nodes, &(variable?(&1) and &1 not in pinned))
    end)
  end

  # The line text around `range` holds nothing else (whitespace, or a comment
  # after it).
  defp line_alone?(source, {{start_line, start_col}, {end_line, end_col}}) do
    lines = String.split(source, "\n")
    before = lines |> Enum.at(start_line - 1, "") |> String.slice(0, start_col - 1)
    rest = lines |> Enum.at(end_line - 1, "") |> String.slice((end_col - 1)..-1//1)

    String.trim(before) == "" and
      (String.trim(rest) == "" or String.starts_with?(String.trim_leading(rest), "#"))
  end

  defp narrow(source, head, call, nil) do
    range = SourceTree.range(call)
    target = Patch.slice(source, SourceTree.range(head))
    edit(:narrow_clause, nil, target, range, Patch.slice(source, range) <> " when " <> @never)
  end

  defp narrow(source, head, _call, guard) do
    range = SourceTree.range(guard)
    target = Patch.slice(source, SourceTree.range(head))

    edit(
      :narrow_clause,
      nil,
      target,
      range,
      "(" <> Patch.slice(source, range) <> ") and " <> @never
    )
  end

  defp param_var({:\\, _meta, [pattern, _default]}), do: param_var(pattern)

  defp param_var({:=, _meta, [left, right]}) do
    Enum.find([right, left], &variable?/1)
  end

  defp param_var(pattern), do: if(variable?(pattern), do: pattern)

  defp passthrough(source, {:<-, _meta, [pattern, _rhs]} = step) do
    target = Patch.slice(source, SourceTree.range(step))
    range = SourceTree.range(pattern)

    {bare, guarded?} =
      case pattern do
        {:when, _wmeta, [bare, _guard]} -> {bare, true}
        bare -> {bare, false}
      end

    with {:ok, quoted} <- SourceTree.quoted(Patch.slice(source, SourceTree.range(bare))),
         relaxed = Macro.to_string(relax(quoted)),
         true <- guarded? or relaxed != Macro.to_string(quoted) do
      edit(:with_passthrough, nil, target, range, relaxed)
    else
      _nothing ->
        edit(:with_passthrough, nil, target, range, "", "the pattern has nothing to relax")
    end
  end

  # Every literal becomes `_`, a struct pattern a map pattern. A pin, a binary
  # and a map key are kept: `_` is not valid there.
  defp relax(literal) when is_atom(literal) or is_number(literal) or is_binary(literal),
    do: {:_, [], nil}

  defp relax({:%, meta, [_struct, {:%{}, mmeta, pairs}]}),
    do: relax({:%{}, Keyword.merge(mmeta, meta), pairs})

  defp relax({:%{}, meta, pairs}), do: {:%{}, meta, Enum.map(pairs, &relax_pair/1)}
  defp relax({:^, _meta, _args} = pin), do: pin
  defp relax({:<<>>, _meta, _args} = binary), do: binary
  defp relax({:<>, meta, [left, right]}), do: {:<>, meta, [left, relax(right)]}
  defp relax({name, _meta, context} = var) when is_atom(name) and is_atom(context), do: var

  defp relax({form, meta, args}) when form in [:=, :{}, :|] and is_list(args),
    do: {form, meta, Enum.map(args, &relax/1)}

  defp relax({left, right}), do: {relax(left), relax(right)}
  defp relax(list) when is_list(list), do: Enum.map(list, &relax/1)
  defp relax(other), do: other

  defp relax_pair({key, value}), do: {key, relax(value)}
  defp relax_pair(other), do: other

  defp return_edit(source, clause, name, index) do
    target = Patch.slice(source, SourceTree.range(clause.head))
    body = SourceTree.statements(clause.body)
    {call_start, _call_end} = SourceTree.range(clause.call)
    {body_start, _first_end} = SourceTree.range(List.first(body))
    {_last_start, body_end} = SourceTree.range(List.last(body))
    range = {call_start, body_end}
    renamed = clause.args |> head_vars() |> Enum.reject(&(elem(&1, 0) == name))

    case return_skip(source, clause, body, name, renamed) do
      nil ->
        head = rename(source, call_start, body_start, renamed)
        edit(:return_input, index, target, range, head <> Atom.to_string(name))

      reason ->
        edit(:return_input, index, target, range, "", reason)
    end
  end

  defp return_skip(source, clause, body, name, renamed) do
    names = Enum.map(renamed, &elem(&1, 0))
    guard_names = guard_names(clause.guard)
    body_text = Patch.slice(source, SourceTree.span(List.first(body), List.last(body)))
    read = Enum.find(names, &(&1 in guard_names))
    repeated = names |> Enum.frequencies() |> Enum.find(fn {_name, count} -> count > 1 end)

    cond do
      body_text == Atom.to_string(name) -> "the body already returns `#{name}`"
      read != nil -> "the guard reads `#{read}`, which the mutant renames `_#{read}`"
      repeated != nil -> "`#{elem(repeated, 0)}` appears more than once in the head"
      true -> nil
    end
  end

  defp guard_names(nil), do: []

  defp guard_names(guard),
    do: guard |> SourceTree.nodes() |> Enum.filter(&variable?/1) |> Enum.map(&elem(&1, 0))

  # The text from `from` to `to` with `_` inserted before each variable.
  defp rename(source, from, to, vars) do
    base = Patch.offset(source, from)
    text = Patch.slice(source, {from, to})

    vars
    |> Enum.map(fn {_name, meta, _context} ->
      Patch.offset(source, {meta[:line], meta[:column]}) - base
    end)
    |> Enum.sort(:desc)
    |> Enum.reduce(text, fn at, text ->
      binary_part(text, 0, at) <> "_" <> binary_part(text, at, byte_size(text) - at)
    end)
  end

  defp rhs({:=, _meta, [_pattern, right]}), do: rhs(right)
  defp rhs(ast), do: ast

  defp sorted(edits), do: Enum.sort_by(edits, fn %{range: {start, stop}} -> {start, stop} end)

  defp statement_edits(%{source: source, clause: clause, effect_calls: tokens}, operator) do
    clause.body
    |> SourceTree.nodes()
    |> Enum.filter(&SourceTree.block?/1)
    |> Enum.flat_map(fn block -> block |> SourceTree.statements() |> Enum.drop(-1) end)
    |> Enum.flat_map(fn statement ->
      range = SourceTree.range(statement)
      target = Patch.slice(source, range)

      case effect_statement?(source, statement, tokens) do
        {:ok, effect?} when operator == :drop_effect_call == effect? ->
          [statement_edit(source, operator, target, range)]

        {:ok, _other_operator} ->
          []

        :error ->
          if operator == :delete_statement,
            do: [
              edit(operator, nil, target, range, "", "the statement cannot be read on its own")
            ],
            else: []
      end
    end)
    |> sorted()
  end

  defp statement_edit(source, operator, target, {{start_line, _sc}, {end_line, _ec}} = range) do
    if line_alone?(source, range),
      do: edit(operator, nil, target, {{start_line, 1}, {end_line + 1, 1}}, ""),
      else:
        edit(
          operator,
          nil,
          target,
          range,
          "",
          "it shares line #{start_line} with another expression"
        )
  end

  defp variable?({name, _meta, context}) when is_atom(name) and is_atom(context),
    do: not String.starts_with?(Atom.to_string(name), "_")

  defp variable?(_node), do: false

  defp with_steps({:with, _meta, [_ | _] = args}) do
    case List.last(args) do
      kw when is_list(kw) ->
        for {:<-, _smeta, [_pattern, _rhs]} = step <- Enum.drop(args, -1), do: step

      _other ->
        []
    end
  end

  defp with_steps(_node), do: []
end
