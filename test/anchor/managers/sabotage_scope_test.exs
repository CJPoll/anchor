defmodule Anchor.Managers.SabotageScopeTest do
  # Manager tests for `Anchor.Managers.Sabotage.scope/2` (DND-5472), with the
  # change-source port doubled by Hammox `expect/3`, which self-verifies: a call
  # the test does not expect fails it, so "diff never called" is proven by not
  # expecting it.
  # Sabotage record: ../../sabotage_records/sabotage_scope-20261103-dnd_5472.md
  use ExUnit.Case, async: true

  import Hammox

  alias Anchor.ChangeSourceMock
  alias Anchor.Managers.Sabotage

  setup :verify_on_exit!

  @root "/repo"
  @sha "abc123"
  @args %{root: @root, base: "origin/main"}
  @opts [change_source: ChangeSourceMock]

  @source """
  defmodule M do
    def f(x) do
      x + 1
    end
  end
  """

  defp modified(path, hunk) do
    "diff --git a/#{path} b/#{path}\nindex 1..2 100644\n--- a/#{path}\n+++ b/#{path}\n#{hunk}\n-old\n+new\n"
  end

  defp expect_git(diff, untracked) do
    expect(ChangeSourceMock, :merge_base, fn @root, "origin/main" -> {:ok, @sha} end)
    expect(ChangeSourceMock, :diff, fn @root, @sha -> {:ok, diff} end)
    expect(ChangeSourceMock, :untracked, fn @root -> {:ok, untracked} end)
  end

  describe "scope/2" do
    test "M1: a modified file's changed function is in scope" do
      expect_git(modified("lib/m.ex", "@@ -3 +3 @@"), [])
      expect(ChangeSourceMock, :read, fn @root, "lib/m.ex" -> {:ok, @source} end)

      assert {:ok, scope} = Sabotage.scope(@args, @opts)

      assert [%{file: "lib/m.ex", module: M, name: :f, arity: 1, changed_lines: [3]}] =
               scope.functions
    end

    test "M2: an untracked .ex file is wholly added" do
      expect_git("", ["lib/new.ex"])
      expect(ChangeSourceMock, :read, fn @root, "lib/new.ex" -> {:ok, @source} end)

      assert {:ok, scope} = Sabotage.scope(@args, @opts)
      assert [%{file: "lib/new.ex", name: :f, changed_lines: [2, 3, 4]}] = scope.functions
    end

    test "M3: a merge-base error is returned, and nothing else is asked of git" do
      expect(ChangeSourceMock, :merge_base, fn @root, "origin/main" ->
        {:error, {:no_merge_base, "origin/main"}}
      end)

      assert Sabotage.scope(@args, @opts) == {:error, {:no_merge_base, "origin/main"}}
    end

    test "M3b: not a work tree names the root" do
      expect(ChangeSourceMock, :merge_base, fn @root, "origin/main" ->
        {:error, :not_a_work_tree}
      end)

      assert Sabotage.scope(@args, @opts) == {:error, {:not_a_work_tree, @root}}
    end

    test "M4: a diff error carries the command and its output" do
      failure = {:git_failed, ["diff", @sha], 128, "fatal: bad object"}
      expect(ChangeSourceMock, :merge_base, fn @root, "origin/main" -> {:ok, @sha} end)
      expect(ChangeSourceMock, :diff, fn @root, @sha -> {:error, failure} end)

      assert Sabotage.scope(@args, @opts) == {:error, failure}
    end

    test "M4b: diff text Anchor cannot read is an error, never an empty scope" do
      expect(ChangeSourceMock, :merge_base, fn @root, "origin/main" -> {:ok, @sha} end)
      expect(ChangeSourceMock, :diff, fn @root, @sha -> {:ok, "warning: odd\n"} end)

      assert {:error, {:unparseable_diff, {:unrecognised_diff_line, 1, "warning: odd"}}} =
               Sabotage.scope(@args, @opts)
    end

    test "M4c: an untracked-files error is returned" do
      failure = {:git_failed, ["ls-files"], 128, "fatal"}
      expect(ChangeSourceMock, :merge_base, fn @root, "origin/main" -> {:ok, @sha} end)
      expect(ChangeSourceMock, :diff, fn @root, @sha -> {:ok, ""} end)
      expect(ChangeSourceMock, :untracked, fn @root -> {:error, failure} end)

      assert Sabotage.scope(@args, @opts) == {:error, failure}
    end

    test "M5: a changed file that cannot be read names the path" do
      expect_git(modified("lib/m.ex", "@@ -3 +3 @@"), [])
      expect(ChangeSourceMock, :read, fn @root, "lib/m.ex" -> {:error, :eacces} end)

      assert Sabotage.scope(@args, @opts) == {:error, {:unreadable, "lib/m.ex", :eacces}}
    end

    test "M6: a changed file that does not parse names the file and line" do
      expect_git(modified("lib/m.ex", "@@ -3 +3 @@"), [])

      expect(ChangeSourceMock, :read, fn @root, "lib/m.ex" ->
        {:ok, "defmodule M do\n  def f(\nend\n"}
      end)

      assert {:error, {:unparseable, "lib/m.ex", 2, reason}} = Sabotage.scope(@args, @opts)
      assert is_binary(reason)
    end

    test "M7: only test files changed: zero functions, counted, and no file is read" do
      diff =
        modified("test/m_test.exs", "@@ -3 +3 @@") <> modified("test/support/f.ex", "@@ -1 +1 @@")

      expect_git(diff, ["test/support/new.ex"])

      assert {:ok, scope} = Sabotage.scope(@args, @opts)
      assert scope.functions == []
      assert scope.counts.test_files == 3
    end

    test "a clean diff is ok with zero functions" do
      expect_git("", [])

      assert {:ok, %{functions: [], counts: counts}} = Sabotage.scope(@args, @opts)
      assert Enum.all?(counts, fn {_key, count} -> count == 0 end)
    end
  end
end
