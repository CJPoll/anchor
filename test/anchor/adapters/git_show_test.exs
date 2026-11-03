defmodule Anchor.Adapters.GitShowTest do
  # Adapter tests (DND-5441): reading a baseline at a ref, in a git repository
  # each test makes in its own tmp_dir. The commit identity is argv, never
  # global config.
  #
  # Sabotage record: ../../sabotage_records/baseline-20261103-dnd_5441_graph_rules_a.md
  use ExUnit.Case, async: true

  alias Anchor.Adapters.GitShow

  @moduletag :tmp_dir

  @identity [
    "-c",
    "user.name=Anchor Test",
    "-c",
    "user.email=anchor@example.invalid",
    "-c",
    "commit.gpgsign=false"
  ]

  @hook_env Enum.map(~w(DIR WORK_TREE INDEX_FILE COMMON_DIR), &("GIT_" <> &1))

  defp git!(root, args) do
    env = Enum.map(@hook_env, &{&1, nil})
    {out, 0} = System.cmd("git", @identity ++ args, cd: root, stderr_to_stdout: true, env: env)
    out
  end

  # One commit on main holding .anchor/baselines/r.txt; then the working file
  # changes, so a read at the ref must return the committed bytes.
  defp repo!(root) do
    git!(root, ["init", "-q", "-b", "main"])
    File.mkdir_p!(Path.join(root, ".anchor/baselines"))
    File.write!(Path.join(root, ".anchor/baselines/r.txt"), "r|A|x\n")
    git!(root, ["add", "."])
    git!(root, ["commit", "-q", "-m", "init"])
    File.write!(Path.join(root, ".anchor/baselines/r.txt"), "r|A|x\nr|B|y\n")
    root
  end

  test "a committed file returns its bytes at the ref, not the working copy", %{tmp_dir: root} do
    repo!(root)
    assert GitShow.show(root, "main", ".anchor/baselines/r.txt") == {:ok, "r|A|x\n"}
  end

  test "a file absent at a ref that resolves is :absent", %{tmp_dir: root} do
    repo!(root)
    assert GitShow.show(root, "main", ".anchor/baselines/other.txt") == {:error, :absent}
  end

  test "a ref that does not resolve is a git error, never :absent", %{tmp_dir: root} do
    repo!(root)

    assert {:error, {:git, status, _out}} =
             GitShow.show(root, "nosuch", ".anchor/baselines/r.txt")

    assert status != 0
  end

  test "a ref Anchor refuses never reaches git", %{tmp_dir: root} do
    repo!(root)
    # The repository holds r.txt on main, so a git read of any ref naming it
    # would answer with bytes or a git error, never :bad_ref.
    assert GitShow.show(root, "main; rm -rf /", ".anchor/baselines/r.txt") == {:error, :bad_ref}
    assert GitShow.show(root, "--output=/tmp/x", ".anchor/baselines/r.txt") == {:error, :bad_ref}
    # Positive control: a valid ref in the same repository does reach git.
    assert {:ok, _bytes} = GitShow.show(root, "main", ".anchor/baselines/r.txt")
  end
end
