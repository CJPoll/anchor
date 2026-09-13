defmodule Anchor.Check.NoDependencyTest do
  # Characterization tests for Anchor.Check.NoDependency.
  #
  # T1 (DND-121) safety-net: these pin the CURRENT observable behavior of
  # `check_file/3` (real `Credo.SourceFile` in, `[%Credo.Issue{}]` out) so that
  # later five-bucket-compliance work (T6.x) has a regression net. They assert
  # what the code does today, not the adjudicated contract in
  # docs/five-bucket-test-matrix.md; where the two differ, the matrix wins later
  # and these assertions are expected to be revised by the fixing ticket.
  use ExUnit.Case, async: true

  alias Anchor.Check.NoDependency
  alias Credo.SourceFile

  defp issues(source, forbidden_modules) do
    source_file = SourceFile.parse(source, "lib/some_module.ex")
    rule = %{type: :no_direct_dependency, forbidden_modules: forbidden_modules}
    NoDependency.check_file(source_file, [rule], [])
  end

  describe "check_file/3" do
    test "flags a direct dependency on a forbidden module" do
      source = """
      defmodule W do
        def f, do: MyApp.Repo.all(Q)
      end
      """

      assert [issue] = issues(source, [MyApp.Repo])
      assert issue.message == "Module has forbidden direct dependency on MyApp.Repo"
      assert issue.trigger == "MyApp.Repo"
      assert issue.line_no == 2
    end

    test "flags a forbidden dep referenced only in a qualified call" do
      source = """
      defmodule W do
        def f do
          Ecto.Query.from(x in "t")
        end
      end
      """

      assert [issue] = issues(source, [Ecto.Query])
      assert issue.trigger == "Ecto.Query"
      assert issue.line_no == 3
    end

    test "flags each distinct forbidden module once" do
      source = """
      defmodule W do
        def f, do: MyApp.Repo.all(Q)
        def g, do: System.halt()
      end
      """

      issues = issues(source, [MyApp.Repo, System])
      triggers = issues |> Enum.map(& &1.trigger) |> Enum.sort()

      assert length(issues) == 2
      assert triggers == ["MyApp.Repo", "System"]
    end

    test "clean module with no forbidden dep returns no issues" do
      source = """
      defmodule W do
        def f, do: Enum.map([], & &1)
      end
      """

      assert issues(source, [MyApp.Repo]) == []
    end

    test "forbidden module named but not referenced returns no issues" do
      source = """
      defmodule W do
        def f, do: MyApp.Other.call()
      end
      """

      assert issues(source, [MyApp.Repo]) == []
    end

    test "empty forbidden list flags nothing" do
      source = """
      defmodule W do
        def f, do: MyApp.Repo.all(Q)
      end
      """

      assert issues(source, []) == []
    end

    test "characterizes which line is reported when a forbidden module appears twice" do
      # Current behavior: `find_module_reference_line/2` prewalks the AST and
      # keeps the LAST match, so with references on lines 2 and 3 the issue is
      # reported at line 3. The acceptance matrix (row 7) specifies the FIRST
      # line (2) as the intended contract; this divergence is pinned here for
      # the fixing ticket (T6.1) to flip.
      source = """
      defmodule W do
        def f, do: MyApp.Repo.all(Q)
        def g, do: MyApp.Repo.one(Q)
      end
      """

      assert [issue] = issues(source, [MyApp.Repo])
      assert issue.line_no == 3
    end

    test "characterizes an aliased forbidden dependency: it is flagged at the alias line" do
      # Current behavior: an `alias MyApp.Repo` line is itself a reference to the
      # forbidden module, so the issue is reported on the alias declaration line
      # (line 2) rather than the usage line. Pinned as-is.
      source = """
      defmodule W do
        alias MyApp.Repo
        def f, do: Repo.all(Q)
      end
      """

      assert [issue] = issues(source, [MyApp.Repo])
      assert issue.trigger == "MyApp.Repo"
      assert issue.line_no == 2
    end
  end

  describe "rule_type/0" do
    test "is :no_direct_dependency" do
      assert NoDependency.rule_type() == :no_direct_dependency
    end
  end
end
