defmodule Anchor.Adapters.GitEnvIsolationTest do
  # DND-5581: a git hook (or a wrapper) exports GIT_DIR, GIT_WORK_TREE and
  # GIT_INDEX_FILE. The git adapters must still read the repository at their
  # root, never the one those variables name.
  #
  # sync: these tests set the BEAM's own OS environment, which every
  # concurrently running test's System.cmd would inherit. ExUnit runs sync
  # modules after the async ones, one at a time; each test restores the
  # variables it set.
  # Sabotage record: ../../sabotage_records/sabotage_scope-20261103-dnd_5581_hardening_batch.md
  # (E2's GitStatus mutation: ../../sabotage_records/sabotage-20261103-dnd_5581_hardening_batch.md)
  # (E5, GitShow, DND-5441: ../../sabotage_records/baseline-20261103-dnd_5441_graph_rules_a.md, GS-E)
  use ExUnit.Case, async: false

  alias Anchor.Adapters.GitChangeSource
  alias Anchor.Adapters.GitEnv
  alias Anchor.Adapters.GitShow
  alias Anchor.Adapters.GitStatus

  @moduletag :tmp_dir

  @identity ["-c", "user.name=t", "-c", "user.email=t@example.com", "-c", "commit.gpgsign=false"]

  defp git!(root, args) do
    env = Enum.map(GitEnv.local_env_vars(), &{&1, nil})
    {out, 0} = System.cmd("git", @identity ++ args, cd: root, stderr_to_stdout: true, env: env)
    out
  end

  defp repo!(root, body) do
    File.mkdir_p!(Path.join(root, "lib"))
    git!(root, ["init", "-q", "-b", "main"])
    File.write!(Path.join(root, "lib/a.ex"), body)
    git!(root, ["add", "."])
    git!(root, ["commit", "-q", "-m", "init"])
    root
  end

  # Points the hook variables at `decoy` for the rest of the test.
  defp export_decoy!(decoy) do
    export!(%{
      "GIT_DIR" => Path.join(decoy, ".git"),
      "GIT_WORK_TREE" => decoy,
      "GIT_INDEX_FILE" => Path.join(decoy, ".git/index")
    })
  end

  # Sets `vars` in the VM's environment for the rest of the test.
  defp export!(vars) do
    previous = Map.new(vars, fn {name, _} -> {name, System.get_env(name)} end)

    on_exit(fn ->
      Enum.each(previous, fn
        {name, nil} -> System.delete_env(name)
        {name, value} -> System.put_env(name, value)
      end)
    end)

    System.put_env(vars)
  end

  setup %{tmp_dir: tmp_dir} do
    # lib/b.ex is tracked in the real repository only: read through the
    # decoy's index (GIT_INDEX_FILE), it would be untracked.
    File.mkdir_p!(Path.join(tmp_dir, "real/lib"))
    File.write!(Path.join(tmp_dir, "real/lib/b.ex"), "defmodule B do\nend\n")
    real = repo!(Path.join(tmp_dir, "real"), "defmodule A do\n  def f, do: 1\nend\n")
    decoy = repo!(Path.join(tmp_dir, "decoy"), "defmodule Decoy do\nend\n")

    # One more commit in the decoy, so its history differs from the real one.
    File.write!(Path.join(decoy, "lib/a.ex"), "defmodule Decoy do\n  def g, do: :decoy\nend\n")
    git!(decoy, ["commit", "-q", "-a", "-m", "decoy 2"])

    # A working-tree change in each, and an untracked file in each.
    File.write!(Path.join(real, "lib/a.ex"), "defmodule A do\n  def f, do: 2\nend\n")
    File.write!(Path.join(decoy, "lib/a.ex"), "defmodule Decoy do\n  def g, do: :changed\nend\n")
    File.write!(Path.join(real, "lib/real_new.ex"), "defmodule RealNew do\nend\n")
    File.write!(Path.join(decoy, "lib/decoy_new.ex"), "defmodule DecoyNew do\nend\n")

    real_head = String.trim(git!(real, ["rev-parse", "HEAD"]))
    {:ok, real: real, decoy: decoy, real_head: real_head}
  end

  test "E1: GitChangeSource reads the repository at its root, not the one GIT_DIR names", %{
    real: real,
    decoy: decoy,
    real_head: real_head
  } do
    export_decoy!(decoy)

    assert GitChangeSource.merge_base(real, "main") == {:ok, real_head}

    assert {:ok, diff} = GitChangeSource.diff(real, real_head)
    assert diff =~ "+  def f, do: 2"
    refute diff =~ "Decoy"

    assert GitChangeSource.untracked(real) == {:ok, ["lib/real_new.ex"]}

    assert GitChangeSource.show(real, real_head, "lib/a.ex") ==
             {:ok, "defmodule A do\n  def f, do: 1\nend\n"}
  end

  test "E2: GitStatus reads the repository at its root, not the one GIT_DIR names", %{
    real: real,
    decoy: decoy
  } do
    export_decoy!(decoy)

    assert GitStatus.dirty_paths(real, ["lib/a.ex", "lib/real_new.ex", "lib/decoy_new.ex"]) ==
             {:ok, ["lib/a.ex", "lib/real_new.ex"]}

    File.write!(Path.join(real, ".gitignore"), "/lib/real_new.ex\n")
    assert GitStatus.ignored?(real, "lib/real_new.ex") == {:ok, true}
  end

  test "E3: GitEnv unsets every variable the installed git calls repository-local" do
    {out, 0} = System.cmd("git", ["rev-parse", "--local-env-vars"], stderr_to_stdout: false)
    from_git = String.split(out, "\n", trim: true)

    assert "GIT_DIR" in from_git
    assert from_git -- GitEnv.local_env_vars() == []

    unset = for {name, nil} <- GitEnv.env(), do: name
    assert Enum.sort(unset) == Enum.sort(GitEnv.local_env_vars() ++ GitEnv.output_env_vars())
    assert {"GIT_OPTIONAL_LOCKS", "0"} in GitEnv.env()
  end

  # An inherited GIT_DIFF_OPTS overrides the diff's --unified=0, so DiffHunks
  # would read hunks padded with context: a wider scope, with no error.
  test "E4: an inherited GIT_DIFF_OPTS cannot change the diff's context lines", %{
    real: real,
    real_head: real_head
  } do
    export!(%{"GIT_DIFF_OPTS" => "-u3"})

    assert {:ok, diff} = GitChangeSource.diff(real, real_head)
    assert diff =~ "\n@@ -2 +2 @@"
  end

  # The base copy of a baseline (`mix anchor.graph --base`) must be read from
  # the repository at root: read through the decoy, GREW would be judged
  # against another repository's file.
  test "E5: GitShow reads a baseline from the repository at its root, not GIT_DIR's", %{
    real: real,
    decoy: decoy
  } do
    File.mkdir_p!(Path.join(real, ".anchor/baselines"))
    File.write!(Path.join(real, ".anchor/baselines/r.txt"), "r|A|x\n")
    git!(real, ["add", ".anchor"])
    git!(real, ["commit", "-q", "-m", "baseline"])
    export_decoy!(decoy)

    assert GitShow.show(real, "main", ".anchor/baselines/r.txt") == {:ok, ["r|A|x"]}
  end
end
