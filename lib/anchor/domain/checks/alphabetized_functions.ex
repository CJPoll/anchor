defmodule Anchor.Domain.Checks.AlphabetizedFunctions do
  @moduledoc """
  Pure detection for the "alphabetized functions" check — the **Domain** bucket
  (ADR 001).

  Given an already-acquired AST and the rules already selected for the file (the
  Manager does rule selection; the Framework edge acquires the AST), this returns
  the `%Anchor.Domain.Violation{}` list the check reports. Every function here is
  side-effect-free: same AST and rules in, same violations out. There is **zero
  `Credo.*`** and no IO — mapping a `%Violation{}` onto a `Credo.Issue` is the
  Framework's job (`Anchor.Check.Base`), and acquiring the AST is
  `Anchor.Check.Source`'s.

  ## Mode (T3 / BUG-2 consumer)

  The per-rule `mode` is read from the **atom** key `rule.mode` surfaced by the
  T3 config parse (`Anchor.Config.parse_rule/1`), never from a string key. An
  absent (`nil`) or unrecognized mode falls back to `:separate`, which is the
  default the check documents.

    * `:all` — every function must be alphabetized, regardless of visibility.
    * `:public_only` — only public functions are checked.
    * `:separate` (default) — public functions are alphabetized as a group and
      private functions as a separate group, and additionally every public
      function must appear before every private function (a structural rule).

  ## Ordering unit

  Functions are compared case-insensitively and broken ties by arity
  (`foo/0` before `foo/1`). `defguard`/`defguardp` participate in ordering
  alongside `def`/`defp` and `defmacro`/`defmacrop`. A function with multiple
  clauses collapses to a **single** ordered unit anchored at its **first**
  clause line, so mis-ordering it reports one violation, not one per clause.
  """

  alias Anchor.Domain.Violation

  @public_defs [:def, :defmacro, :defguard]
  @private_defs [:defp, :defmacrop, :defguardp]

  @doc """
  Returns the `%Violation{}` list for `ast` against the already-selected `rules`.

  Each rule is evaluated independently under its own `mode`; the violations are
  concatenated in rule order.
  """
  @spec detect_violations(Macro.t(), [map()]) :: [Violation.t()]
  def detect_violations(ast, rules) do
    functions = extract_functions(ast)

    Enum.flat_map(rules, fn rule ->
      case mode(rule) do
        :all -> check_all_functions(functions)
        :public_only -> check_public_functions_only(functions)
        :separate -> check_separate_visibility(functions)
      end
    end)
  end

  # BUG-2 consumer: mode arrives on the ATOM key `:mode` from the T3 parse. An
  # absent or unrecognized mode falls back to `:separate`.
  defp mode(rule) do
    case Map.get(rule, :mode) do
      :all -> :all
      :public_only -> :public_only
      _ -> :separate
    end
  end

  defp extract_functions(ast) do
    {_, functions} =
      Macro.prewalk(ast, [], fn node, acc ->
        case function_definition(node) do
          nil -> {node, acc}
          func -> {node, [func | acc]}
        end
      end)

    functions
    |> Enum.reverse()
    |> Enum.sort_by(& &1.line)
    |> Enum.uniq_by(&{&1.name, &1.arity, &1.visibility})
  end

  # Guarded def/macro/guard with a body (def/defmacro have a body; the guard
  # form has two args: the `when` clause and the body).
  defp function_definition({def_type, meta, [{:when, _, [{name, _, args} | _]}, _body]})
       when def_type in @public_defs and is_atom(name) and is_list(args) do
    build_function(name, args, meta, :public)
  end

  defp function_definition({def_type, meta, [{:when, _, [{name, _, args} | _]}, _body]})
       when def_type in @private_defs and is_atom(name) and is_list(args) do
    build_function(name, args, meta, :private)
  end

  # `defguard`/`defguardp` carry only the `when` clause (no separate body).
  defp function_definition({def_type, meta, [{:when, _, [{name, _, args} | _]}]})
       when def_type in @public_defs and is_atom(name) and is_list(args) do
    build_function(name, args, meta, :public)
  end

  defp function_definition({def_type, meta, [{:when, _, [{name, _, args} | _]}]})
       when def_type in @private_defs and is_atom(name) and is_list(args) do
    build_function(name, args, meta, :private)
  end

  # Plain (guardless) def/defp/defmacro/defmacrop with a body.
  defp function_definition({def_type, meta, [{name, _, args}, _body]})
       when def_type in @public_defs and is_atom(name) and is_list(args) do
    build_function(name, args, meta, :public)
  end

  defp function_definition({def_type, meta, [{name, _, args}, _body]})
       when def_type in @private_defs and is_atom(name) and is_list(args) do
    build_function(name, args, meta, :private)
  end

  defp function_definition(_node), do: nil

  defp build_function(name, args, meta, visibility) do
    %{
      name: name,
      arity: length(args),
      line: meta[:line],
      visibility: visibility,
      original_name: to_string(name)
    }
  end

  defp check_all_functions(functions) do
    find_ordering_issues(functions, :all)
  end

  defp check_public_functions_only(functions) do
    public_functions = Enum.filter(functions, &(&1.visibility == :public))
    find_ordering_issues(public_functions, :public_only)
  end

  defp check_separate_visibility(functions) do
    {public_functions, private_functions} =
      Enum.split_with(functions, &(&1.visibility == :public))

    public_issues = find_ordering_issues(public_functions, :separate_public)
    private_issues = find_ordering_issues(private_functions, :separate_private)

    # Structural rule: no private function may precede a public function.
    structural_issues = find_structural_violations(functions)

    public_issues ++ private_issues ++ structural_issues
  end

  defp find_ordering_issues(functions, mode) do
    sorted =
      Enum.sort_by(functions, fn func ->
        {String.downcase(func.original_name), func.arity}
      end)

    functions
    |> Enum.with_index()
    |> Enum.flat_map(fn {func, actual_index} ->
      expected_index = Enum.find_index(sorted, &(&1 == func))

      if actual_index != expected_index do
        [create_violation(func, mode, sorted, expected_index)]
      else
        []
      end
    end)
  end

  defp create_violation(func, mode, sorted_functions, expected_index) do
    expected_previous =
      if expected_index > 0 do
        prev = Enum.at(sorted_functions, expected_index - 1)
        "#{prev.original_name}/#{prev.arity}"
      else
        "the beginning"
      end

    visibility_text =
      case mode do
        :all -> ""
        :public_only -> "public "
        :separate_public -> "public "
        :separate_private -> "private "
      end

    %Violation{
      message:
        "#{visibility_text}function `#{func.original_name}/#{func.arity}` is not in alphabetical order. " <>
          "It should appear after #{expected_previous}.",
      line: func.line,
      trigger: "#{func.original_name}/#{func.arity}"
    }
  end

  defp find_structural_violations(functions) do
    last_public_line =
      functions
      |> Enum.filter(&(&1.visibility == :public))
      |> Enum.map(& &1.line)
      |> Enum.max(fn -> 0 end)

    if last_public_line == 0 do
      []
    else
      functions
      |> Enum.filter(&(&1.visibility == :private && &1.line < last_public_line))
      |> Enum.map(fn func ->
        %Violation{
          message:
            "private function `#{func.original_name}/#{func.arity}` appears before public functions. " <>
              "In :separate mode, all public functions must come before private functions.",
          line: func.line,
          trigger: "#{func.original_name}/#{func.arity}"
        }
      end)
    end
  end
end
