defmodule Anchor.Check.MustUseModuleTest do
  # Framework contract for Anchor.Check.MustUseModule: real `Credo.SourceFile`
  # in, `[%Credo.Issue{}]` out via `check_file/3`. Detection lives in the Domain
  # (Anchor.Domain.Checks.MustUseModule, tested in
  # test/anchor/domain/checks/must_use_module_test.exs); these rows verify the
  # thin shell delegates and that violations are mapped to issues with the right
  # message/trigger/line_no.
  #
  # Covers docs/five-bucket-test-matrix.md → must_use_module.ex → check_file/3
  # rows #1-7 (adjudicated contract).
  #
  # Sabotage record: ../../sabotage_records/must_use_module-20260913-dnd_128_t6_3_must_use_module.md
  use ExUnit.Case, async: true

  alias Anchor.Check.MustUseModule
  alias Credo.SourceFile

  defp issues(source, required_modules) do
    source_file = SourceFile.parse(source, "lib/some_module.ex")
    rule = %{type: :must_use_module, required_modules: required_modules}
    MustUseModule.check_file(source_file, [rule], [])
  end

  describe "check_file/3" do
    # Row #1
    test "flags a module missing a required use" do
      source = """
      defmodule S do
        def f, do: :ok
      end
      """

      assert [issue] = issues(source, [MyApp.Schema])
      assert issue.message == "Module must use MyApp.Schema"
      assert issue.trigger == "MyApp.Schema"
      assert issue.line_no == 1
    end

    # Row #2
    test "passes when the required module is used" do
      source = """
      defmodule S do
        use MyApp.Schema
        def f, do: :ok
      end
      """

      assert issues(source, [MyApp.Schema]) == []
    end

    # Row #3
    test "flags each missing required module separately" do
      source = """
      defmodule S do
        def f, do: :ok
      end
      """

      issues = issues(source, [MyApp.Schema, MyApp.Base])
      triggers = issues |> Enum.map(& &1.trigger) |> Enum.sort()

      assert length(issues) == 2
      assert triggers == ["MyApp.Base", "MyApp.Schema"]
    end

    # Row #4
    test "one of two required modules present flags only the missing one" do
      source = """
      defmodule S do
        use MyApp.Schema
        def f, do: :ok
      end
      """

      assert [issue] = issues(source, [MyApp.Schema, MyApp.Base])
      assert issue.trigger == "MyApp.Base"
      assert issue.message == "Module must use MyApp.Base"
      assert issue.line_no == 1
    end

    # Row #5
    test "`use ModName, opts` still counts as a use" do
      source = """
      defmodule S do
        use MyApp.Schema, :controller
        def f, do: :ok
      end
      """

      assert issues(source, [MyApp.Schema]) == []
    end

    # Row #6
    test "empty required list flags nothing" do
      source = """
      defmodule S do
        def f, do: :ok
      end
      """

      assert issues(source, []) == []
    end

    # Row #7 — rule selection happens in the Manager (Anchor.Managers.Lint)
    # before check_file/3; a rule that does not select the file never reaches
    # detection, so check_file/3 is called with no rules and flags nothing.
    test "rule not selecting the file yields nothing (no rules reach detection)" do
      source = """
      defmodule S do
        def f, do: :ok
      end
      """

      source_file = SourceFile.parse(source, "lib/some_module.ex")
      assert MustUseModule.check_file(source_file, [], []) == []
    end
  end

  describe "rule_type/0" do
    test "is :must_use_module" do
      assert MustUseModule.rule_type() == :must_use_module
    end
  end
end
