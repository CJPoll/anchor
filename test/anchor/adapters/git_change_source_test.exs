defmodule Anchor.Adapters.GitChangeSourceTest do
  # Adapter tests (DND-5472): the conversion of real git output, in a git
  # repository each test makes in its own tmp_dir. The commit identity is argv
  # (`-c user.name=...`), never global config.
  # Sabotage record: ../../sabotage_records/sabotage_scope-20261103-dnd_5472.md
  # (G6: ../../sabotage_records/sabotage_scope-20261103-dnd_5519_scope_findings.md;
  # G7, and G4/G5's captured stderr:
  # ../../sabotage_records/sabotage_scope-20261103-dnd_5581_hardening_batch.md)
  use ExUnit.Case, async: true

  alias Anchor.Adapters.GitChangeSource
  alias Anchor.Domain.Sabotage.DiffHunks

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
    # A suite run under a git hook inherits the repository-locating variables,
    # which would point these commands at the outer repository instead of tmp_dir.
    env = Enum.map(@hook_env, &{&1, nil})
    {out, 0} = System.cmd("git", @identity ++ args, cd: root, stderr_to_stdout: true, env: env)
    out
  end

  # Evaluates `call` (an expression over the adapter) in a child VM that loads
  # only Anchor's ebin, and returns what it printed: git's message, on stderr,
  # then the result, inspected on stdout. A failing git command writes to the
  # BEAM's own stderr (fd 2), which no `capture_io` in this VM can read, so a
  # case whose stderr is expected runs here: the suite stays quiet, and the
  # message is asserted (DND-5589).
  defp in_child_vm(call) do
    elixir = System.find_executable("elixir")
    assert elixir, "no elixir executable on PATH to run the child VM"

    {out, status} =
      System.cmd(
        elixir,
        ["-pa", Mix.Project.compile_path(), "-e", "IO.inspect(" <> call <> ", width: :infinity)"],
        stderr_to_stdout: true
      )

    assert status == 0, "the child VM exited #{status}:\n#{out}"
    String.split(out, "\n", trim: true)
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

  # A repository at tmp_dir/work with a submodule at vendor/sub whose checkout
  # moved back one commit, and a changed lib/a.ex. The submodule is made from
  # a local path, so no network is touched; `protocol.file.allow=always` lets
  # git clone from it.
  defp repo_with_moved_submodule!(tmp_dir) do
    upstream = Path.join(tmp_dir, "upstream")
    root = Path.join(tmp_dir, "work")
    File.mkdir_p!(upstream)
    File.mkdir_p!(root)

    git!(upstream, ["init", "-q", "-b", "main"])
    File.write!(Path.join(upstream, "f"), "1\n")
    git!(upstream, ["add", "."])
    git!(upstream, ["commit", "-q", "-m", "s1"])
    File.write!(Path.join(upstream, "f"), "2\n")
    git!(upstream, ["commit", "-q", "-a", "-m", "s2"])

    repo!(root)

    git!(root, [
      "-c",
      "protocol.file.allow=always",
      "submodule",
      "add",
      "-q",
      upstream,
      "vendor/sub"
    ])

    git!(root, ["commit", "-q", "-m", "add the submodule"])

    # The submodule's checkout moves back one commit, and a source file changes.
    git!(Path.join(root, "vendor/sub"), ["checkout", "-q", "HEAD~1"])
    File.write!(Path.join(root, "lib/a.ex"), "defmodule A do\n  def f, do: 2\nend\n")
    root
  end

  test "G6: a user's diff.submodule=log cannot change the diff format", %{tmp_dir: tmp_dir} do
    # A submodule whose checked-out commit moved is the case `--submodule=short`
    # exists for: with `diff.submodule=log` and no flag, git prints a
    # `Submodule vendor/sub a..b:` line DiffHunks refuses (a false COULD NOT
    # MEASURE).
    root = repo_with_moved_submodule!(tmp_dir)
    git!(root, ["config", "diff.submodule", "log"])

    {:ok, sha} = GitChangeSource.merge_base(root, "HEAD")
    assert {:ok, diff} = GitChangeSource.diff(root, sha)

    refute diff =~ "Submodule vendor/sub"
    assert diff =~ "+Subproject commit "

    assert {:ok, files} = DiffHunks.parse(diff)
    assert files |> Map.keys() |> Enum.sort() == ["lib/a.ex", "vendor/sub"]
    assert %{status: :modified, hunks: [{2, 1}]} = files["lib/a.ex"]
  end

  # DND-5582: either setting drops the submodule from a plain `git diff`
  # without an error; `--ignore-submodules=none` overrides both.
  for {key, value} <- [{"diff.ignoreSubmodules", "all"}, {"submodule.vendor/sub.ignore", "all"}] do
    @tag config: {key, value}
    test "G7: a user's #{key}=#{value} cannot hide a moved submodule", %{
      tmp_dir: tmp_dir,
      config: {key, value}
    } do
      root = repo_with_moved_submodule!(tmp_dir)
      {:ok, sha} = GitChangeSource.merge_base(root, "HEAD")
      git!(root, ["config", key, value])

      # Positive control: the setting does hide the submodule from a plain diff.
      refute git!(root, ["diff", "--submodule=short", sha, "--"]) =~ "vendor/sub"

      assert {:ok, diff} = GitChangeSource.diff(root, sha)
      assert diff =~ "+++ b/vendor/sub\n"
      assert {:ok, files} = DiffHunks.parse(diff)
      assert files |> Map.keys() |> Enum.sort() == ["lib/a.ex", "vendor/sub"]
    end
  end

  test "G5: show returns a file as it was at a commit, by a path relative to root", %{
    tmp_dir: root
  } do
    repo!(root)
    {:ok, sha} = GitChangeSource.merge_base(root, "HEAD")
    File.write!(Path.join(root, "lib/a.ex"), "changed\n")

    assert GitChangeSource.show(root, sha, "lib/a.ex") ==
             {:ok, "defmodule A do\n  def f, do: 1\nend\n"}

    # A root below the repository's top: paths are relative to root, as the diff's are.
    assert GitChangeSource.show(Path.join(root, "lib"), sha, "a.ex") ==
             {:ok, "defmodule A do\n  def f, do: 1\nend\n"}

    # git says why on stderr; the error carries the command and its status.
    assert [message, result] =
             in_child_vm(
               "Anchor.Adapters.GitChangeSource.show(" <>
                 Enum.map_join([root, sha, "lib/none.ex"], ", ", &inspect/1) <> ")"
             )

    assert message =~ "fatal: path 'lib/none.ex' does not exist"
    assert result =~ ~s|{:error, {:git_failed, ["show", "#{sha}:./lib/none.ex"], 128, ""}}|
  end

  test "G2: untracked returns only untracked .ex files", %{tmp_dir: root} do
    repo!(root)
    File.write!(Path.join(root, "lib/new.ex"), "defmodule New do\nend\n")
    File.write!(Path.join(root, "notes.txt"), "notes\n")

    assert GitChangeSource.untracked(root) == {:ok, ["lib/new.ex"]}
  end

  test "G3: an unresolvable ref, or one spelled like an option, is no merge-base", %{
    tmp_dir: root
  } do
    repo!(root)

    assert GitChangeSource.merge_base(root, "no-such-ref") ==
             {:error, {:no_merge_base, "no-such-ref"}}

    assert GitChangeSource.merge_base(root, "--output=x") ==
             {:error, {:no_merge_base, "--output=x"}}
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

    # git's own answer to the probe is on stderr, which the child VM captures.
    assert [message, "{:error, :not_a_work_tree}"] =
             in_child_vm(
               "Anchor.Adapters.GitChangeSource.merge_base(" <> inspect(outside) <> ~s|, "main")|
             )

    assert message =~ "fatal: not a git repository"

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
