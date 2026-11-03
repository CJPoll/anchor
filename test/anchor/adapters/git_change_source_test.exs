defmodule Anchor.Adapters.GitChangeSourceTest do
  # Adapter tests (DND-5472): the conversion of real git output, in a git
  # repository each test makes in its own tmp_dir. The commit identity is argv
  # (`-c user.name=...`), never global config.
  # Sabotage record: test/sabotage_records/sabotage_scope-20261103-dnd_5472.md
  use ExUnit.Case, async: true

  alias Anchor.Adapters.GitChangeSource

  @identity [
    "-c",
    "user.name=Anchor Test",
    "-c",
    "user.email=anchor@example.invalid",
    "-c",
    "commit.gpgsign=false"
  ]

  defp git!(root, args) do
    {out, 0} = System.cmd("git", @identity ++ args, cd: root, stderr_to_stdout: true)
    out
  end

  defp repo!(root) do
    git!(root, ["init", "-q", "-b", "main"])
    File.mkdir_p!(Path.join(root, "lib"))
    File.write!(Path.join(root, "lib/a.ex"), "defmodule A do\n  def f, do: 1\nend\n")
    git!(root, ["add", "."])
    git!(root, ["commit", "-q", "-m", "init"])
    root
  end

  @moduletag :tmp_dir

  test "G1: merge_base returns a sha, and diff holds the working tree's hunk", %{tmp_dir: root} do
    repo!(root)
    git!(root, ["checkout", "-q", "-b", "work"])
    File.write!(Path.join(root, "lib/a.ex"), "defmodule A do\n  def f, do: 2\nend\n")

    assert {:ok, sha} = GitChangeSource.merge_base(root, "main")
    assert sha == String.trim(git!(root, ["rev-parse", "main"]))

    assert {:ok, diff} = GitChangeSource.diff(root, sha)
    assert diff =~ "+++ b/lib/a.ex\n@@ -2 +2 @@"
  end

  test "G1b: staged changes are in the diff, and an ignored diff.noprefix cannot change it", %{
    tmp_dir: root
  } do
    repo!(root)
    git!(root, ["config", "diff.noprefix", "true"])
    File.write!(Path.join(root, "lib/a.ex"), "defmodule A do\n  def f, do: 3\nend\n")
    git!(root, ["add", "lib/a.ex"])

    {:ok, sha} = GitChangeSource.merge_base(root, "HEAD")
    assert {:ok, diff} = GitChangeSource.diff(root, sha)
    assert diff =~ "diff --git a/lib/a.ex b/lib/a.ex"
  end

  test "G2: untracked returns only untracked .ex files", %{tmp_dir: root} do
    repo!(root)
    File.write!(Path.join(root, "lib/new.ex"), "defmodule New do\nend\n")
    File.write!(Path.join(root, "notes.txt"), "notes\n")

    assert GitChangeSource.untracked(root) == {:ok, ["lib/new.ex"]}
  end

  test "G3: an unresolvable ref, or one that looks like an option, is no merge-base", %{
    tmp_dir: root
  } do
    repo!(root)

    assert GitChangeSource.merge_base(root, "no-such-ref") ==
             {:error, {:no_merge_base, "no-such-ref"}}

    assert GitChangeSource.merge_base(root, "--output=x") ==
             {:error, {:no_merge_base, "--output=x"}}

    refute File.exists?(Path.join(root, "x"))
  end

  test "G3b: a ref with no history in common with HEAD is no merge-base", %{tmp_dir: root} do
    repo!(root)
    git!(root, ["checkout", "-q", "--orphan", "other"])
    git!(root, ["commit", "-q", "-m", "orphan"])

    assert GitChangeSource.merge_base(root, "main") == {:error, {:no_merge_base, "main"}}
  end

  test "G4: a root that is not a git repository, or does not exist, is :not_a_work_tree", %{
    tmp_dir: root
  } do
    # tmp_dir sits inside this checkout (itself a work tree), so the directory
    # that is not a repository is made under the system temp directory.
    outside =
      Path.join(System.tmp_dir!(), "anchor-not-a-repo-#{System.unique_integer([:positive])}")

    File.mkdir_p!(outside)
    on_exit(fn -> File.rm_rf!(outside) end)

    assert GitChangeSource.merge_base(outside, "main") == {:error, :not_a_work_tree}

    assert GitChangeSource.merge_base(Path.join(root, "missing"), "main") ==
             {:error, :not_a_work_tree}
  end

  test "read returns contents, or the posix error", %{tmp_dir: root} do
    repo!(root)

    assert GitChangeSource.read(root, "lib/a.ex") ==
             {:ok, "defmodule A do\n  def f, do: 1\nend\n"}

    assert GitChangeSource.read(root, "lib/none.ex") == {:error, :enoent}
  end
end
