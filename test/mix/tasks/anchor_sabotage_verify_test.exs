defmodule Mix.Tasks.Anchor.SabotageVerifyTest do
  # Framework tests for `mix anchor.sabotage verify` (DND-5516): argument
  # parsing, rendering and the exit mapping, with the Manager's ports doubled
  # by Hammox (the Manager's own tests cover the verdict).
  # sync: capture_io(:stderr) captures the VM-wide standard_error device, which
  # another async test's output would interleave with.
  # Sabotage record: ../../sabotage_records/sabotage-20261106-dnd_5516_verify.md
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO
  import Hammox

  alias Anchor.BaselineStoreMock
  alias Anchor.ChangeSourceMock
  alias Anchor.ConfigLoaderMock
  alias Anchor.GitBaseMock
  alias Mix.Tasks.Anchor.Sabotage

  setup :verify_on_exit!

  @opts [
    config_loader: ConfigLoaderMock,
    change_source: ChangeSourceMock,
    record_store: Anchor.RecordStoreMock,
    baseline_store: BaselineStoreMock,
    git_base: GitBaseMock
  ]
  @survivors ".anchor/sabotage/survivors.txt"

  defp expect_config do
    root = File.cwd!()

    expect(ConfigLoaderMock, :load_in, fn ^root ->
      {:ok, %Anchor.Config{rules: [], sabotage: %Anchor.Domain.Sabotage.Config{}}}
    end)
  end

  defp expect_diff(diff) do
    root = File.cwd!()
    expect_config()
    expect(ChangeSourceMock, :merge_base, fn ^root, "main" -> {:ok, "abc"} end)
    expect(ChangeSourceMock, :diff, fn ^root, "abc" -> {:ok, diff} end)
    expect(ChangeSourceMock, :untracked, fn ^root -> {:ok, []} end)
    expect(BaselineStoreMock, :read, fn ^root, @survivors -> {:ok, []} end)
    expect(GitBaseMock, :show, fn ^root, "main", @survivors -> {:ok, []} end)
  end

  defp deleted_record do
    path = "test/sabotage_records/old.md"

    "diff --git a/#{path} b/#{path}\ndeleted file mode 100644\n--- a/#{path}\n+++ /dev/null\n@@ -1 +0,0 @@\n-x\n"
  end

  describe "run/2 (verify)" do
    test "1: a clean verdict prints its summary and exits 0" do
      expect_diff("")

      output =
        capture_io(fn -> assert Sabotage.run(["verify", "--base", "main"], @opts) == :ok end)

      assert output == "sabotage verify: no changed functions\n"
    end

    test "1: a failing verdict exits 1, its lines on stderr" do
      expect_diff(deleted_record())

      stderr =
        capture_io(:stderr, fn ->
          assert catch_exit(Sabotage.run(["verify", "--base", "main"], @opts)) == {:shutdown, 1}
        end)

      assert stderr =~ "RECORD REMOVED test/sabotage_records/old.md"
    end

    test "1: COULD NOT MEASURE exits 3" do
      expect_config()
      expect(ChangeSourceMock, :merge_base, fn _root, "main" -> {:error, :not_a_work_tree} end)

      stderr =
        capture_io(:stderr, fn ->
          assert catch_exit(Sabotage.run(["verify", "--base", "main"], @opts)) == {:shutdown, 3}
        end)

      assert stderr =~ "COULD NOT MEASURE:"
      assert stderr =~ "Fix: "
    end

    test "--format json prints the verdict" do
      expect_diff("")

      output =
        capture_io(fn ->
          Sabotage.run(["verify", "--base", "main", "--format", "json"], @opts)
        end)

      assert %{"functions" => 0, "exit_code" => 0} = JSON.decode!(output)
    end

    test "2: no --base, a ref git cannot read, or one Anchor refuses, exits 2 with a Fix:" do
      expect_config()

      expect(ChangeSourceMock, :merge_base, fn _root, "nope" ->
        {:error, {:no_merge_base, "nope"}}
      end)

      for {argv, said} <- [
            {["verify"], "needs --base"},
            {["verify", "--base", "nope"], "--base nope is not a ref git can read"},
            {["verify", "--base", "x;y"], "--base x;y is not a ref git can read"}
          ] do
        stderr =
          capture_io(:stderr, fn ->
            assert catch_exit(Sabotage.run(argv, @opts)) == {:shutdown, 2}
          end)

        assert stderr =~ said
        assert stderr =~ "Fix: "
      end
    end

    test "2: a bare --base, an unknown flag or a bad format is a usage error, exit 2" do
      for argv <- [
            ["verify", "--base"],
            ["verify", "--base", "main", "--bogus"],
            ["verify", "--base", "main", "--format", "xml"],
            ["verify", "--base", "main", "extra"]
          ] do
        stderr =
          capture_io(:stderr, fn ->
            assert catch_exit(Sabotage.run(argv, @opts)) == {:shutdown, 2}
          end)

        assert stderr =~ "mix anchor.sabotage verify --base REF"
        assert stderr =~ "Fix: "
      end
    end
  end
end
