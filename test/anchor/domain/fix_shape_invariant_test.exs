defmodule Anchor.Domain.FixShapeInvariantTest do
  # DND-5446 (R4, decision 5): every finding carries exactly one Fix:, and an
  # AST rule's Fix is its rule's shape, the same text mix anchor.explain
  # prints. One canonical violating snippet per AST rule type, run through its
  # Domain detector; a type with no row fails the suite. The graph rule types
  # are held by the canary (graph_canary_test.exs, "every graph finding
  # carries exactly one Fix:"), over the real runner. Load refusals are held
  # by rule_checks_nothing_test.exs and architecture_checks_nothing_test.exs.
  #
  # Sabotage record: ../../sabotage_records/rule_shapes-20261103-dnd_5443_graph_rules_b.md
  use ExUnit.Case, async: true

  alias Anchor.Config
  alias Anchor.Domain.Checks
  alias Anchor.Domain.RuleSchema
  alias Anchor.Domain.RuleShapes

  defp rule(type, keys) do
    Config.parse_rule(Map.merge(%{"type" => Atom.to_string(type), "pattern" => "*"}, keys))
  end

  defp ast(source), do: Code.string_to_quoted!(source, columns: true)

  defp lines(source),
    do: source |> String.split("\n") |> Enum.with_index(1) |> Enum.map(fn {l, i} -> {i, l} end)

  # type => {rule keys, fn rule -> violations end}
  defp cases do
    %{
      alphabetized_functions:
        {%{"mode" => "all"},
         &Checks.AlphabetizedFunctions.detect_violations(
           ast("defmodule M do\n  def b(x), do: x\n  def a(x), do: x\nend"),
           [&1]
         )},
      case_on_bare_arg:
        {%{},
         fn _rule ->
           Checks.CaseOnBareArg.detect_violations(
             ast(
               "defmodule M do\n  def f(x) do\n    case x do\n      _ -> 1\n    end\n  end\nend"
             )
           )
         end},
      max_file_length:
        {%{"max_lines" => 1},
         fn rule ->
           source = "defmodule M do\n  def a, do: 1\n  def b, do: 2\nend"
           Checks.MaxFileLength.detect_violations(lines(source), ast(source), [rule], "lib/m.ex")
         end},
      module_pattern_restrictions:
        {%{"allowed_functions" => ["new"]},
         &Checks.ModulePatternRestrictions.detect_violations(
           ast("defmodule M do\n  def other, do: 1\nend"),
           [&1]
         )},
      must_use_module:
        {%{"required_modules" => ["MyApp.Base"]},
         &Checks.MustUseModule.detect_violations(ast("defmodule M do\nend"), [&1])},
      no_comparison_in_if:
        {%{},
         &Checks.NoComparisonInIf.detect_violations(
           ast("defmodule M do\n  def f(a), do: if(a == 1, do: 1, else: 2)\nend"),
           [&1]
         )},
      no_direct_dependency:
        {%{"forbidden_modules" => ["MyApp.Repo"]},
         &Checks.NoDependency.detect_violations(
           ast("defmodule M do\n  def f, do: MyApp.Repo.all()\nend"),
           [&1]
         )},
      no_discarded_pure_expression:
        {%{},
         &Checks.NoDiscardedPureExpression.detect_violations(
           ast("defmodule M do\n  def f(x) do\n    String.upcase(x)\n    :ok\n  end\nend"),
           [&1]
         )},
      no_discarding_arrow_in_with:
        {%{},
         fn _rule ->
           Checks.NoDiscardingArrowInWith.detect_violations(
             ast(
               "defmodule M do\n  def f do\n    with _ <- g(), {:ok, y} <- h() do\n      y\n    end\n  end\nend"
             )
           )
         end},
      no_forwarding_function:
        {%{},
         &Checks.NoForwardingFunction.detect_violations(
           ast("defmodule M do\n  def f(a), do: g(a)\n  defp g(a), do: a\nend"),
           [&1]
         )},
      no_transitive_dependency:
        {%{"forbidden_modules" => ["MyApp.Repo"]},
         &Checks.NoTransitiveDependency.detect_violations(
           ast("defmodule A do\n  def f, do: B.call()\nend"),
           [&1],
           %{A => %{direct_dependencies: [B]}, B => %{direct_dependencies: [MyApp.Repo]}}
         )},
      no_tuple_match_in_head:
        {%{},
         &Checks.NoTupleMatchInHead.detect_violations(
           ast("defmodule M do\n  def f({:ok, x}), do: x\nend"),
           [&1]
         )},
      single_control_flow:
        {%{},
         &Checks.SingleControlFlow.detect_violations(
           ast(
             "defmodule M do\n  def f(x) do\n    if x, do: 1\n    case x do\n      _ -> 2\n    end\n  end\nend"
           ),
           [&1]
         )},
      struct_getter_convention:
        {%{},
         &Checks.StructGetterConvention.detect_violations(
           ast(
             "defmodule M do\n  defstruct [:name]\n  def get_name(%__MODULE__{name: n}), do: n\nend"
           ),
           [&1]
         )},
      struct_owned_by_module:
        {%{},
         &Checks.StructOwnedByModule.detect_violations(
           ast("defmodule A do\n  def f, do: %B{x: 1}\nend"),
           [&1]
         )}
    }
  end

  test "every AST rule type has a row here (a new type without one fails)" do
    assert Enum.sort(Map.keys(cases())) == RuleSchema.rule_types_for_engine(:ast)
  end

  for type <- RuleSchema.rule_types_for_engine(:ast) do
    @tag rule_type: type
    test "#{type}: its canonical violation ends with exactly one Fix:, its rule's shape",
         %{rule_type: type} do
      {keys, detect} = Map.fetch!(cases(), type)
      rule = rule(type, keys)
      shape = RuleShapes.for(rule)

      violations = detect.(rule)
      assert violations != [], "#{type}: the canonical snippet found nothing"

      for violation <- violations do
        assert RuleShapes.fix_count(violation.message) == 1, violation.message
        assert String.ends_with?(violation.message, "Fix: " <> shape), violation.message
      end
    end
  end
end
