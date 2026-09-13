defmodule Anchor.Domain.Checks.CaseOnBareArg do
  @moduledoc """
  Pure detection for the "no case on a bare function argument" check — the
  **Domain** bucket (ADR 001).

  Given an already-acquired AST, this returns the `%Anchor.Domain.Violation{}`
  list the check reports. Every function here is side-effect-free: same AST
  in, same violations out. There is **zero `Credo.*`** and no IO — mapping a
  `%Violation{}` onto a `Credo.Issue` is the Framework's job
  (`Anchor.Check.Base`), and acquiring the AST is `Anchor.Check.Source`'s.

  This mirrors the shape T6.1 established in
  `Anchor.Domain.Checks.NoDependency`: a pure `detect_violations/N` that takes
  the bare AST and returns `[%Anchor.Domain.Violation{}]`.

  ## What it detects

  For every `def`/`defp` (guarded or not), a `case` statement whose scrutinee
  is directly one of the function's own arguments is flagged — including a
  defaulted argument (`\\\\`), which is still a bare argument. A scrutinee
  that is a transformed value, a different variable, or a destructured
  pattern (map/tuple match in the function head) is not flagged.
  """

  alias Anchor.Domain.Violation

  @doc """
  Returns the `%Violation{}` list for `ast`.

  Walks every function definition, collects its bare (possibly defaulted)
  argument names, then walks the function body for `case` statements whose
  scrutinee is one of those bare names.
  """
  @spec detect_violations(Macro.t()) :: [Violation.t()]
  def detect_violations(ast) do
    ast
    |> find_case_on_bare_args()
    |> Enum.map(&build_violation/1)
  end

  defp find_case_on_bare_args(ast) do
    {_, violations} =
      Macro.prewalk(ast, [], fn node, acc ->
        case node do
          # Function with guards must come before regular functions
          # because the regular pattern would match the :when atom as the function name
          {:def, _meta, [{:when, _, [{name, _, args} | _guards]}, body]}
          when is_atom(name) and is_list(args) ->
            {node, acc ++ violations_for(name, args, body)}

          {:defp, _meta, [{:when, _, [{name, _, args} | _guards]}, body]}
          when is_atom(name) and is_list(args) ->
            {node, acc ++ violations_for(name, args, body)}

          # Match regular function definitions
          {:def, _meta, [{name, _, args}, body]} when is_atom(name) and is_list(args) ->
            {node, acc ++ violations_for(name, args, body)}

          {:defp, _meta, [{name, _, args}, body]} when is_atom(name) and is_list(args) ->
            {node, acc ++ violations_for(name, args, body)}

          _ ->
            {node, acc}
        end
      end)

    violations
  end

  defp violations_for(name, args, body) do
    arg_names = extract_arg_names(args)
    find_case_violations_in_body(body, arg_names, name)
  end

  defp extract_arg_names(args) do
    Enum.flat_map(args, fn
      {name, _, nil} when is_atom(name) ->
        [name]

      # A defaulted argument (`arg \\ default`) is still a bare argument.
      {:\\, _, [{name, _, nil} | _default]} when is_atom(name) ->
        [name]

      _ ->
        []
    end)
  end

  defp find_case_violations_in_body(body, arg_names, function_name) do
    {_, violations} =
      Macro.prewalk(body, [], fn
        {:case, meta, [{arg_name, _, nil}, _clauses]} = node, acc when is_atom(arg_name) ->
          if arg_name in arg_names do
            violation = %{
              function_name: function_name,
              arg_name: arg_name,
              line_no: Keyword.get(meta, :line)
            }

            {node, [violation | acc]}
          else
            {node, acc}
          end

        node, acc ->
          {node, acc}
      end)

    violations
  end

  defp build_violation(%{function_name: function_name, arg_name: arg_name, line_no: line_no}) do
    %Violation{
      message:
        "Case statement operates on bare argument `#{arg_name}` in function `#{function_name}`. Consider using function head pattern matching instead.",
      line: line_no,
      trigger: "case"
    }
  end
end
