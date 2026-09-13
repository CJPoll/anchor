defmodule Anchor.Domain.Checks.NoDiscardingArrowInWith do
  @moduledoc """
  Pure detection for the "no discarding arrow in with" check — the **Domain**
  bucket (ADR 001).

  Given an already-acquired AST, this returns the `%Anchor.Domain.Violation{}`
  list the check reports. Every function here is side-effect-free: same AST
  in, same violations out. There is **zero `Credo.*`** and no IO — mapping a
  `%Violation{}` onto a `Credo.Issue` is the Framework's job
  (`Anchor.Check.Base`), and acquiring the AST is `Anchor.Check.Source`'s.

  This mirrors the shape T6.1 established in
  `Anchor.Domain.Checks.NoDependency`: a pure `detect_violations/N` that takes
  the bare AST and returns `[%Anchor.Domain.Violation{}]`.

  ## What it detects

  For every `with` expression, each clause of the form `pattern <- expr` whose
  `pattern` only discards the value (a bare `_`, an underscore-prefixed
  variable such as `_result`, or either of those under a `when` guard) is
  flagged. A clause whose pattern performs a structural match — `{:ok, value}`,
  `{:ok, _}`, or a plain bound variable like `value` — is not flagged, since
  the arrow is doing real pattern-matching work there.
  """

  alias Anchor.Domain.Violation

  @doc """
  Returns the `%Violation{}` list for `ast`.

  Walks every `with` expression, extracts its clauses (everything before the
  `do` block), and flags each clause whose left-hand pattern only discards the
  matched value.
  """
  @spec detect_violations(Macro.t()) :: [Violation.t()]
  def detect_violations(ast) do
    {_, violations} =
      Macro.prewalk(ast, [], fn node, acc ->
        case node do
          {:with, _meta, clauses} when is_list(clauses) and length(clauses) >= 2 ->
            with_clauses = extract_with_clauses(clauses)
            new_violations = check_with_clauses(with_clauses)
            {node, acc ++ new_violations}

          _ ->
            {node, acc}
        end
      end)

    violations
  end

  defp extract_with_clauses(clauses) do
    do_index =
      Enum.find_index(clauses, fn
        [{:do, _} | _] -> true
        _ -> false
      end)

    if do_index do
      Enum.take(clauses, do_index)
    else
      case List.last(clauses) do
        [{:do, _} | _] -> Enum.drop(clauses, -1)
        _ -> []
      end
    end
  end

  defp check_with_clauses(clauses) do
    Enum.flat_map(clauses, fn clause ->
      case clause do
        {:<-, meta, [pattern, _expr]} ->
          if is_discarding_pattern?(pattern) do
            [build_violation(pattern, meta)]
          else
            []
          end

        _ ->
          []
      end
    end)
  end

  defp is_discarding_pattern?(pattern) do
    case pattern do
      {:_, _, _} ->
        true

      {:when, _, [inner_pattern | _]} ->
        is_discarding_pattern?(inner_pattern)

      {var_name, _, _} when is_atom(var_name) ->
        var_name
        |> Atom.to_string()
        |> String.starts_with?("_")

      _ ->
        false
    end
  end

  defp build_violation(pattern, meta) do
    pattern_string = pattern_string(pattern)

    %Violation{
      message:
        "Unnecessary arrow (<-) in with clause. Pattern `#{pattern_string}` only discards the value. " <>
          "Remove the arrow and pattern to simplify",
      line: meta[:line],
      trigger: pattern_string
    }
  end

  defp pattern_string(pattern) do
    case pattern do
      {:_, _, _} ->
        "_"

      {:when, _, [{:_, _, _} | _]} ->
        "_"

      {:when, _, [{var_name, _, _} | _]} when is_atom(var_name) ->
        Atom.to_string(var_name)

      {var_name, _, _} when is_atom(var_name) ->
        Atom.to_string(var_name)

      _ ->
        "pattern"
    end
  end
end
