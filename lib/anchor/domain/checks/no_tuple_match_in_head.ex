defmodule Anchor.Domain.Checks.NoTupleMatchInHead do
  @moduledoc """
  Pure detection for the "no `:ok`/`:error` tuple match in a function head"
  check — the **Domain** bucket (ADR 001).

  Given an already-acquired bare AST and the rules already selected for the
  file (the Manager does rule selection; the Framework edge acquires the AST
  via `Anchor.Check.Source`), this returns the `%Anchor.Domain.Violation{}`
  list the check reports. Every function here is side-effect-free: same AST
  and rules in, same violations out. There is **zero `Credo.*`** and no IO —
  mapping a `%Violation{}` onto a `Credo.Issue` is the Framework's job
  (`Anchor.Check.Base`), and acquiring the AST is `Anchor.Check.Source`'s.

  This mirrors the shape of `Anchor.Domain.Checks.NoDependency` and
  `Anchor.Domain.Checks.SingleControlFlow`: a pure `detect_violations/2` that
  takes the bare AST plus the pre-selected rules and returns
  `[%Anchor.Domain.Violation{}]`. It replaces the previous regex-on-source
  implementation with AST-based detection; line numbers come from AST
  metadata, never from re-scanning the source string.

  ## What it detects

  For every `def`/`defp` clause (guarded or not), each **top-level** argument
  in the function head is judged **independently**:

    * A direct `{:ok, ...}` / `{:error, ...}` tuple (any arity ≥ 2) is
      flagged.
    * A match-assignment (`=`) whose operand on either side is such a tuple is
      flagged — so both `def f({:ok, _} = result)` and the reversed
      `def f(result = {:ok, data})` flag.

  A tuple nested inside a list or map sub-pattern is **allowed** — only the
  argument's own top level (or the direct operands of a top-level `=`) is
  inspected. Because judgment is per argument, a direct top-level tuple in one
  argument is flagged even when a sibling argument carries a nested (allowed)
  tuple, and a nested tuple in a sibling never suppresses that flag. Each
  flagged argument yields one violation, reported at the clause's `def`/`defp`
  line, with the function name as the trigger.
  """

  alias Anchor.Domain.Violation

  @tuple_tags [:ok, :error]

  @doc """
  Returns the `%Violation{}` list for `ast` against the already-selected
  `rules`.

  Each rule contributes one violation per top-level head argument that
  directly pattern-matches on an `:ok`/`:error` tuple (or assigns from one).
  """
  @spec detect_violations(Macro.t(), [map()]) :: [Violation.t()]
  def detect_violations(ast, rules) do
    Enum.flat_map(rules, fn _rule ->
      ast
      |> find_function_clauses()
      |> Enum.flat_map(fn {name, visibility, line_no, args} ->
        args
        |> Enum.filter(&flaggable_arg?/1)
        |> Enum.map(fn _arg -> build_violation(name, visibility, line_no) end)
      end)
    end)
  end

  # Collects `{function_name, visibility, def_line, args}` for every `def`/`defp`
  # clause. The guarded shape (`{:when, _, [{name, _, args} | guards]}`) must be
  # matched before the plain `{name, _, args}` shape: a guarded signature is
  # itself `{:when, meta, [...]}`, which would otherwise bind `name` to the atom
  # `:when` and hand back the wrong trigger.
  defp find_function_clauses(ast) do
    {_ast, clauses} =
      Macro.prewalk(ast, [], fn
        {:def, meta, [{:when, _, [{name, _, args} | _guards]}, _body]} = node, acc
        when is_atom(name) and is_list(args) ->
          {node, [{to_string(name), :public, Keyword.get(meta, :line), args} | acc]}

        {:defp, meta, [{:when, _, [{name, _, args} | _guards]}, _body]} = node, acc
        when is_atom(name) and is_list(args) ->
          {node, [{to_string(name), :private, Keyword.get(meta, :line), args} | acc]}

        {:def, meta, [{name, _, args}, _body]} = node, acc
        when is_atom(name) and is_list(args) ->
          {node, [{to_string(name), :public, Keyword.get(meta, :line), args} | acc]}

        {:defp, meta, [{name, _, args}, _body]} = node, acc
        when is_atom(name) and is_list(args) ->
          {node, [{to_string(name), :private, Keyword.get(meta, :line), args} | acc]}

        node, acc ->
          {node, acc}
      end)

    Enum.reverse(clauses)
  end

  # A top-level `=` flags when either operand is a direct result tuple
  # (`{:ok, _} = result` or `result = {:ok, _}`); any other argument flags only
  # when it is itself a direct result tuple.
  defp flaggable_arg?({:=, _meta, [lhs, rhs]}), do: result_tuple?(lhs) or result_tuple?(rhs)
  defp flaggable_arg?(arg), do: result_tuple?(arg)

  # A result tuple is `{:ok, ...}` / `{:error, ...}` of arity >= 2. Two-element
  # tuples are literal 2-tuples in the AST; tuples of arity 3+ are
  # `{:{}, meta, [tag, second | _]}`. A bare `{:ok}` / `{:error}` 1-tuple
  # (`{:{}, meta, [tag]}`) is not a result tuple and is not flagged — the second
  # element is what carries the wrapped value. A tuple nested in a list or map is
  # a different node shape and never reaches here as a bare tuple, so it is
  # allowed.
  defp result_tuple?({tag, _second}) when tag in @tuple_tags, do: true
  defp result_tuple?({:{}, _meta, [tag, _second | _rest]}) when tag in @tuple_tags, do: true
  defp result_tuple?(_other), do: false

  defp build_violation(function_name, visibility, line_no) do
    visibility_text = if visibility == :public, do: "public", else: "private"

    %Violation{
      message:
        "Function `#{function_name}` pattern matches on :ok/:error tuple in its " <>
          "#{visibility_text} function head. Consider having the calling function use a " <>
          "case statement on the value instead.",
      line: line_no,
      trigger: function_name
    }
  end
end
