defmodule Mix.Tasks.Anchor.SabotageScopeTest do
  # Framework tests for `mix anchor.sabotage scope` (DND-5472): argument
  # parsing, rendering and exit codes, with the Manager's change-source port
  # doubled by Hammox (real git is covered by the adapter tests).
  # sync: capture_io(:stderr) captures the VM-wide standard_error device, which
  # another async test's output would interleave with.
  # Sabotage record: ../../sabotage_records/sabotage_scope-20261103-dnd_5472.md
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO
  import Hammox

  alias Anchor.ChangeSourceMock
  alias Mix.Tasks.Anchor.Sabotage

  setup :verify_on_exit!

  @opts [change_source: ChangeSourceMock]
  @diff "diff --git a/lib/m.ex b/lib/m.ex\nindex 1..2 100644\n--- a/lib/m.ex\n+++ b/lib/m.ex\n@@ -3 +3 @@\n-old\n+new\n"
  @source "defmodule M do\n  def f(x) do\n    x + 1\n  end\nend\n"

  defp expect_one_change(base) do
    root = File.cwd!()
    expect(ChangeSourceMock, :merge_base, fn ^root, ^base -> {:ok, "abc"} end)
    expect(ChangeSourceMock, :diff, fn ^root, "abc" -> {:ok, @diff} end)
    expect(ChangeSourceMock, :untracked, fn ^root -> {:ok, []} end)
    expect(ChangeSourceMock, :read, fn ^root, "lib/m.ex" -> {:ok, @source} end)
  end

  test "F1: text prints the TSV line and the summary" do
    expect_one_change("main")

    output = capture_io(fn -> assert Sabotage.run(["scope", "--base", "main"], @opts) == :ok end)

    assert output ==
             "lib/m.ex\tM\tf/1\tdef\t3\n" <>
               "anchor.sabotage scope: 1 functions in 1 files; excluded: 0 test files, 0 non-source files, " <>
               "0 deleted files, 0 hunks outside a function, 0 macros\n"
  end

  test "F1b: the base defaults to origin/main" do
    expect_one_change("origin/main")

    assert capture_io(fn -> Sabotage.run(["scope"], @opts) end) =~ "1 functions in 1 files"
  end

  test "F2: --format json prints valid JSON" do
    expect_one_change("main")

    output =
      capture_io(fn -> Sabotage.run(["scope", "--base", "main", "--format", "json"], @opts) end)

    assert %{
             "functions" => [%{"function" => "f/1", "changed_lines" => [3]}],
             "function_count" => 1
           } =
             JSON.decode!(output)
  end

  test "F3: an unknown ref exits 3 with COULD NOT MEASURE and a Fix: line" do
    expect(ChangeSourceMock, :merge_base, fn _root, "nope" ->
      {:error, {:no_merge_base, "nope"}}
    end)

    stderr =
      capture_io(:stderr, fn ->
        assert catch_exit(Sabotage.run(["scope", "--base", "nope"], @opts)) == {:shutdown, 3}
      end)

    assert stderr =~ "COULD NOT MEASURE: no merge-base with nope."
    assert stderr =~ "Fix: "
  end

  test "F4: an unknown option, a bad format, or no subcommand is a usage error, exit 2" do
    for argv <- [
          ["scope", "--bogus"],
          ["scope", "--format", "xml"],
          ["scope", "extra"],
          [],
          ["nope"]
        ] do
      stderr =
        capture_io(:stderr, fn ->
          assert catch_exit(Sabotage.run(argv, @opts)) == {:shutdown, 2}
        end)

      assert stderr =~ "Usage: mix anchor.sabotage scope"
    end
  end
end
