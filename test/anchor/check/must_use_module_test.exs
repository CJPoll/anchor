defmodule Anchor.Check.MustUseModuleTest do
  # Characterization tests for Anchor.Check.MustUseModule.
  #
  # T1 (DND-121) safety-net: these pin the CURRENT observable behavior of
  # `check_file/3` (real `Credo.SourceFile` in, `[%Credo.Issue{}]` out). They
  # capture what the code does today, not the adjudicated contract in
  # docs/five-bucket-test-matrix.md; the fixing ticket (T6.3) may revise them.
  use ExUnit.Case, async: true

  alias Anchor.Check.MustUseModule
  alias Credo.SourceFile

  defp issues(source, required_modules) do
    source_file = SourceFile.parse(source, "lib/some_module.ex")
    rule = %{type: :must_use_module, required_modules: required_modules}
    MustUseModule.check_file(source_file, [rule], [])
  end

  describe "check_file/3" do
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

    test "passes when the required module is used" do
      source = """
      defmodule S do
        use MyApp.Schema
        def f, do: :ok
      end
      """

      assert issues(source, [MyApp.Schema]) == []
    end

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

    test "one of two required modules present flags only the missing one" do
      source = """
      defmodule S do
        use MyApp.Schema
        def f, do: :ok
      end
      """

      assert [issue] = issues(source, [MyApp.Schema, MyApp.Base])
      assert issue.trigger == "MyApp.Base"
    end

    test "`use ModName, opts` still counts as a use" do
      source = """
      defmodule S do
        use MyApp.Schema, :controller
        def f, do: :ok
      end
      """

      assert issues(source, [MyApp.Schema]) == []
    end

    test "empty required list flags nothing" do
      source = """
      defmodule S do
        def f, do: :ok
      end
      """

      assert issues(source, []) == []
    end
  end

  describe "rule_type/0" do
    test "is :must_use_module" do
      assert MustUseModule.rule_type() == :must_use_module
    end
  end
end
