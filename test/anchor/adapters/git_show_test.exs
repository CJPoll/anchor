defmodule Anchor.Adapters.GitShowTest do
  # Adapter tests (DND-5441): reading a baseline at a ref, in a git repository
  # each test makes in its own tmp_dir. The commit identity is argv, never
  # global config.
  #
  # Sabotage record: ../../sabotage_records/baseline-20261103-dnd_5441_graph_rules_a.md
  # DND-5628 (symlinks): ../../sabotage_records/baseline_symlink-20261103-dnd_5441_graph_rules_a.md
  # DND-5634 (git's stderr captured): ../../sabotage_records/baseline-20261103-dnd_5648_graph_followups.md
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
    assert GitShow.show(root, "main", ".anchor/baselines/r.txt") == {:ok, ["r|A|x"]}
  end

  test "a file absent at a ref that resolves is :absent", %{tmp_dir: root} do
    repo!(root)
    assert GitShow.show(root, "main", ".anchor/baselines/other.txt") == {:error, :absent}
  end

  # Regression: the existence probe (`git cat-file -e`) wrote "fatal: path
  # ... does not exist in <sha>" to the terminal on every first landing. Git's
  # stderr is the OS process's, not the test's group leader, so the read runs
  # in a child VM with its stderr merged into the output this test reads.
  test "an absent file prints nothing: git's stderr never reaches the terminal", %{
    tmp_dir: root
  } do
    repo!(root)
    ebin = Path.dirname(:code.which(GitShow))

    for path <- [".anchor/baselines/other.txt", ".anchor/baselines/untracked.txt"] do
      File.write!(Path.join(root, ".anchor/baselines/untracked.txt"), "x\n")

      code =
        "IO.inspect(Anchor.Adapters.GitShow.show(#{inspect(root)}, \"main\", #{inspect(path)}))"

      assert System.cmd("elixir", ["-pa", ebin, "-e", code], stderr_to_stdout: true) ==
               {"{:error, :absent}\n", 0}
    end
  end

  test "a ref that does not resolve is a git error, never :absent", %{tmp_dir: root} do
    repo!(root)

    assert {:error, {:git, status, _out}} =
             GitShow.show(root, "nosuch", ".anchor/baselines/r.txt")

    assert status != 0
  end

  # Regression (review floor on d9a61de): once the commit resolved, ANY
  # failure of the path probe read as :absent, a first landing (a NOTE, exit
  # 0). A tree object git cannot read is such a failure: it must be an error.
  test "a path git cannot look up at a resolved ref is a git error, never :absent", %{
    tmp_dir: root
  } do
    repo!(root)
    tree = root |> git!(["rev-parse", "main:.anchor"]) |> String.trim()
    {dir, file} = String.split_at(tree, 2)
    File.rm!(Path.join([root, ".git", "objects", dir, file]))

    # DND-5634: git says why on its stderr, the OS process's, which reached
    # the suite's output. The read runs in a child VM whose stderr this test
    # reads and asserts, so the suite stays quiet.
    ebin = Path.dirname(:code.which(GitShow))

    code =
      "IO.inspect(Anchor.Adapters.GitShow.show(#{inspect(root)}, \"main\", " <>
        "\".anchor/baselines/r.txt\"))"

    {out, 0} = System.cmd("elixir", ["-pa", ebin, "-e", code], stderr_to_stdout: true)
    assert [message, result] = String.split(out, "\n", trim: true)
    assert message == "error: Could not read #{tree}"
    assert result =~ ~r/^\{:error, \{:git, [1-9]\d*, ""\}\}$/
  end

  # Review floor on d9a61de: with no git on the PATH, System.cmd raised and
  # the run crashed with no Fix: line. It runs in a child VM whose PATH holds
  # no git, so this VM's environment is never touched.
  test "no git on the PATH is a git error, never a crash", %{tmp_dir: root} do
    repo!(root)
    ebin = Path.dirname(:code.which(GitShow))

    code =
      ~s|System.put_env("PATH", "/nonexistent"); | <>
        "IO.inspect(Anchor.Adapters.GitShow.show(#{inspect(root)}, \"main\", \"r.txt\"))"

    assert System.cmd("elixir", ["-pa", ebin, "-e", code], stderr_to_stdout: true) ==
             {~s|{:error, {:git, :enoent, "git was not found on the PATH"}}\n|, 0}
  end

  test "an absolute path or a .. segment never reaches git", %{tmp_dir: root} do
    repo!(root)
    assert GitShow.show(root, "main", "/etc/passwd") == {:error, :outside_root}
    assert GitShow.show(root, "main", "../x/r.txt") == {:error, :outside_root}
    assert {:ok, ["r|A|x"]} = GitShow.show(root, "main", ".anchor/baselines/r.txt")
  end

  test "a line that is not UTF-8 at the ref is its error, naming the line", %{tmp_dir: root} do
    repo!(root)
    File.write!(Path.join(root, ".anchor/baselines/bad.txt"), "r|A|x\n\xff\n")
    git!(root, ["add", "."])
    git!(root, ["commit", "-q", "-m", "bad"])

    assert GitShow.show(root, "main", ".anchor/baselines/bad.txt") ==
             {:error, {:line, 2, :invalid_utf8}}
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

  # DND-5628: --base reads the blob from git, never the working tree, so a
  # symlink there is a tree entry of mode 120000, refused, never followed.
  describe "a symlink at the ref (DND-5628)" do
    test "a symlinked file is refused, naming it", %{tmp_dir: root} do
      repo!(root)
      File.ln_s!("/etc/hostname", Path.join(root, ".anchor/baselines/link.txt"))
      git!(root, ["add", "."])
      git!(root, ["commit", "-q", "-m", "link"])

      assert GitShow.show(root, "main", ".anchor/baselines/link.txt") ==
               {:error, {:symlink, ".anchor/baselines/link.txt"}}
    end

    test "a symlinked directory on the path is refused, naming it", %{tmp_dir: root} do
      repo!(root)
      File.ln_s!("/etc", Path.join(root, ".anchor/etc"))
      git!(root, ["add", "."])
      git!(root, ["commit", "-q", "-m", "link"])

      assert GitShow.show(root, "main", ".anchor/etc/hostname") ==
               {:error, {:symlink, ".anchor/etc"}}
    end
  end

  # DND-5629: the base config's graph rules, so a baseline's copy at the ref
  # is found by its rule's id.
  describe "rules/3 (DND-5629)" do
    @canary Path.expand("../../fixtures/graph_canary/.anchor.yml", __DIR__)

    test "the config's rules as committed at the ref, not the working copy", %{tmp_dir: root} do
      git!(root, ["init", "-q", "-b", "main"])

      config =
        @canary
        |> File.read!()
        |> String.replace("    id: layering\n", "    id: layering\n    baseline: old.txt\n")

      File.write!(Path.join(root, ".anchor.yml"), config)
      git!(root, ["add", "."])
      git!(root, ["commit", "-q", "-m", "config"])
      File.write!(Path.join(root, ".anchor.yml"), "rules: []\n")

      assert {:ok, rules} = GitShow.rules(root, "main", ".anchor.yml")
      assert %{id: "layering", baseline: "old.txt"} = Enum.find(rules, &(&1[:id] == "layering"))
    end

    test "no config at a ref that resolves is :absent", %{tmp_dir: root} do
      repo!(root)
      assert GitShow.rules(root, "main", ".anchor.yml") == {:error, :absent}
    end

    test "a config the parser rejects is its error, never an empty rule list", %{tmp_dir: root} do
      git!(root, ["init", "-q", "-b", "main"])
      File.write!(Path.join(root, ".anchor.yml"), "nothing: here\n")
      git!(root, ["add", "."])
      git!(root, ["commit", "-q", "-m", "config"])

      assert {:error, {:invalid_config, _reason}} = GitShow.rules(root, "main", ".anchor.yml")
    end
  end
end
