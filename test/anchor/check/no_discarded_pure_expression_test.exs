defmodule Anchor.Check.NoDiscardedPureExpressionTest do
  # Framework tests for `no_discarded_pure_expression` (DND-5451): the thin
  # `Anchor.Check.NoDiscardedPureExpression` shell's `check_file/3`, from a
  # parsed `Credo.SourceFile` to `Credo.Issue`s. Detection is the Domain
  # module's (Anchor.Domain.Checks.NoDiscardedPureExpressionTest); selection by
  # a real `.anchor.yml` is in Anchor.E2E.ChecksE2ETest.
  #
  # Sabotage record: ../../sabotage_records/no_discarded_pure_expression-20261103-dnd_5451_ast_batch.md
  use ExUnit.Case, async: true

  alias Anchor.Check.NoDiscardedPureExpression
  alias Credo.SourceFile

  @violating """
  defmodule MyApp.Thing do
    def put(m) do
      Map.put(m, :a, 1)
      m
    end
  end
  """

  test "F1: a discarded pure call is one issue with its line, trigger and Fix" do
    assert [issue] = run_check(@violating)
    assert issue.line_no == 3
    assert issue.trigger == "Map.put(m, :a, 1)"
    assert issue.message =~ "Fix: use the value"
    assert issue.category == :warning
  end

  test "F3: a clean file has no issue (F1 is the control)" do
    clean = """
    defmodule MyApp.Thing do
      def put(m) do
        IO.puts("x")
        Map.put(m, :a, 1)
      end
    end
    """

    assert run_check(clean) == []
  end

  test "rule_type/0 is the rule type the schema knows" do
    assert NoDiscardedPureExpression.rule_type() == :no_discarded_pure_expression
    assert :no_discarded_pure_expression in Anchor.Domain.RuleSchema.rule_types()
  end

  defp run_check(source) do
    rules = [%{type: :no_discarded_pure_expression, pure_patterns: []}]

    NoDiscardedPureExpression.check_file(
      SourceFile.parse(source, "lib/my_app/thing.ex"),
      rules,
      []
    )
  end
end
