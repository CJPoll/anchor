defmodule Anchor.Domain.Checks.SingleControlFlow do
  @moduledoc """
  Pure detection for the "single control flow" check — the **Domain** bucket
  (ADR 001).

  Given an already-acquired bare AST and the rules already selected for the
  file (the Manager does rule selection; the Framework edge acquires the AST
  via `Anchor.Check.Source`), this returns the `%Anchor.Domain.Violation{}`
  list the check reports. Every function here is side-effect-free: same AST
  and rules in, same violations out. There is **zero `Credo.*`** and no IO —
  mapping a `%Violation{}` onto a `Credo.Issue` is the Framework's job
  (`Anchor.Check.Base`), and acquiring the AST is `Anchor.Check.Source`'s.

  This mirrors the shape of `Anchor.Domain.Checks.NoDependency` and
  `Anchor.Domain.Checks.MustUseModule`: a pure `detect_violations/2` that
  takes the bare AST plus the pre-selected rules and returns
  `[%Anchor.Domain.Violation{}]`.

  ## What it detects

  Every top-level function clause (`def`/`defp`, guarded or not) that
  contains more than one control-flow structure yields one violation, at the
  clause's `def`/`defp` line. Control-flow structures are: pipe chains
  (`|>`), `cond`, `with`, `case`, `if`, `unless`, `for`, and `receive`. A
  single pipe chain (however many `|>` stages) counts as **one** structure,
  not one per stage — only the outermost `|>` of a chain increments the
  count; a nested/chained `|>` (its left operand is itself a `|>`) is
  skipped so it isn't double-counted.
  """

  alias Anchor.Domain.Violation

  @doc """
  Returns the `%Violation{}` list for `ast` against the already-selected
  `rules`.

  Each rule contributes one violation per function clause whose control-flow
  structure count exceeds 1.
  """
  @spec detect_violations(Macro.t(), [map()]) :: [Violation.t()]
  def detect_violations(ast, rules) do
    Enum.flat_map(rules, fn _rule ->
      ast
      |> find_function_clauses()
      |> Enum.flat_map(fn {function_name, line_no, body} ->
        control_flow_count = count_control_flow_structures(body)

        if control_flow_count > 1 do
          [build_violation(function_name, line_no, control_flow_count)]
        else
          []
        end
      end)
    end)
  end

  defp find_function_clauses(ast) do
    {_, clauses} =
      Macro.prewalk(ast, [], fn
        # Handle functions with guards. This must come before the plain
        # `{name, _, args}` clauses below: a guarded signature is itself
        # `{:when, meta, [call, guard]}`, which also satisfies
        # `is_atom(name) and is_list(args)` with `name` bound to `:when` — so
        # checking the guard shape first is required to get the real function
        # name as the trigger instead of the literal atom `:when`.
        {:def, meta, [{:when, _, [{name, _, args} | _]}, body]} = node, acc
        when is_atom(name) and is_list(args) ->
          {node, [{to_string(name), Keyword.get(meta, :line), body} | acc]}

        {:defp, meta, [{:when, _, [{name, _, args} | _]}, body]} = node, acc
        when is_atom(name) and is_list(args) ->
          {node, [{to_string(name), Keyword.get(meta, :line), body} | acc]}

        {:def, meta, [{name, _, args}, body]} = node, acc when is_atom(name) and is_list(args) ->
          {node, [{to_string(name), Keyword.get(meta, :line), body} | acc]}

        {:defp, meta, [{name, _, args}, body]} = node, acc when is_atom(name) and is_list(args) ->
          {node, [{to_string(name), Keyword.get(meta, :line), body} | acc]}

        node, acc ->
          {node, acc}
      end)

    Enum.reverse(clauses)
  end

  defp count_control_flow_structures(ast) do
    {_, count} =
      Macro.prewalk(ast, 0, fn
        # Pipe chain (count as 1 per chain — skip a pipe already part of one)
        {:|>, _, _} = node, acc ->
          if already_in_pipe_chain?(node) do
            {node, acc}
          else
            {node, acc + 1}
          end

        {:cond, _, _} = node, acc ->
          {node, acc + 1}

        {:with, _, _} = node, acc ->
          {node, acc + 1}

        {:case, _, _} = node, acc ->
          {node, acc + 1}

        {:if, _, _} = node, acc ->
          {node, acc + 1}

        {:unless, _, _} = node, acc ->
          {node, acc + 1}

        {:for, _, _} = node, acc ->
          {node, acc + 1}

        {:receive, _, _} = node, acc ->
          {node, acc + 1}

        node, acc ->
          {node, acc}
      end)

    count
  end

  # Check if this pipe is part of a larger pipe chain (i.e., its left operand
  # is also a pipe), so only the outermost `|>` of a chain is counted.
  defp already_in_pipe_chain?({:|>, _, [left, _right]}) do
    match?({:|>, _, _}, left)
  end

  defp build_violation(function_name, line_no, count) do
    %Violation{
      message:
        "Function clause `#{function_name}` contains #{count} control-flow structures (maximum allowed: 1). " <>
          "Control-flow structures include: pipe chains (|>), cond, with, case, if, unless, for, and receive. Favor extracting pipe chains to helpers before extracting other structures.",
      line: line_no,
      trigger: function_name
    }
  end
end
