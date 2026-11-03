defmodule Anchor.Check.StructOwnedByModuleTest do
  # Framework tests for `struct_owned_by_module` (DND-5453): the thin
  # `Anchor.Check.StructOwnedByModule` shell's `check_file/3`, from a parsed
  # `Credo.SourceFile` to `Credo.Issue`s. Detection is the Domain module's;
  # selection by a real `.anchor.yml` (F1, F2) is in Anchor.E2E.ChecksE2ETest.
  #
  # Sabotage record: ../../sabotage_records/struct_owned_by_module-20261103-dnd_5451_ast_batch.md
  use ExUnit.Case, async: true

  alias Anchor.Check.StructOwnedByModule
  alias Credo.SourceFile

  test "a struct built outside its module is one issue naming it, with Fix" do
    source = """
    defmodule App.X do
      def run, do: %App.Turn{status: :idle}
    end
    """

    assert [issue] = run_check(source)
    assert issue.trigger == "%App.Turn{"
    assert issue.line_no == 2
    assert issue.message =~ "Only App.Turn's own module may build or change App.Turn"
    assert issue.message =~ "Fix: call a function on S's own module"
    assert issue.category == :design
  end

  test "the struct's own module has no issue (the row above is the control)" do
    source = """
    defmodule App.Turn do
      defstruct [:status]
      def new, do: %App.Turn{status: :idle}
    end
    """

    assert run_check(source) == []
  end

  defp run_check(source) do
    rules = [%{type: :struct_owned_by_module, owned_namespaces: nil}]
    StructOwnedByModule.check_file(SourceFile.parse(source, "lib/app/x.ex"), rules, [])
  end
end
