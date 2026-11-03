defmodule Anchor.Check.NoForwardingFunctionTest do
  # Framework tests for `no_forwarding_function` (DND-5452): the thin
  # `Anchor.Check.NoForwardingFunction` shell's `check_file/3`, from a parsed
  # `Credo.SourceFile` to `Credo.Issue`s. Detection is the Domain module's;
  # selection by a real `.anchor.yml` is in Anchor.E2E.ChecksE2ETest.
  #
  # Sabotage record: ../../sabotage_records/no_forwarding_function-20261103-dnd_5451_ast_batch.md
  use ExUnit.Case, async: true

  alias Anchor.Check.NoForwardingFunction
  alias Credo.SourceFile

  test "F1: a forwarding function is one issue naming both functions, with Fix" do
    source = """
    defmodule MyApp.Thing do
      def total(items, tax), do: do_total(items, tax)
      defp do_total(items, tax), do: {items, tax}
    end
    """

    assert [issue] = run_check(source)
    assert issue.trigger == "total/2"
    assert issue.line_no == 2
    assert issue.message =~ "total/2 only forwards its arguments unchanged to do_total/2"
    assert issue.message =~ "Fix: inline the hop"
    assert issue.category == :design
  end

  test "a function that does work has no issue (F1 is the control)" do
    source = """
    defmodule MyApp.Thing do
      def total(items, tax), do: do_total(items, tax * 2)
      defp do_total(items, tax), do: {items, tax}
    end
    """

    assert run_check(source) == []
  end

  defp run_check(source) do
    rules = [%{type: :no_forwarding_function}]
    NoForwardingFunction.check_file(SourceFile.parse(source, "lib/my_app/thing.ex"), rules, [])
  end
end
