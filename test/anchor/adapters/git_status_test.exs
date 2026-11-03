defmodule Anchor.Adapters.GitStatusTest do
  # DND-5473: dirty and ignored paths, asked of a real git repository in a
  # tmp directory.
  # Sabotage record: ../../sabotage_records/sabotage-20261103-dnd_5473_sabotage_run.md
  use ExUnit.Case, async: true

  alias Anchor.Adapters.GitStatus

  @moduletag :tmp_dir

  defp git!(root, args) do
    {out, 0} =
      System.cmd("git", ["-c", "user.name=t", "-c", "user.email=t@example.com" | args],
        cd: root,
        stderr_to_stdout: true
      )

    out
  end

  setup %{tmp_dir: root} do
    git!(root, ["init", "-q"])
    File.mkdir_p!(Path.join(root, "lib"))
    File.write!(Path.join(root, "lib/clean.ex"), "clean")
    File.write!(Path.join(root, "lib/dirty.ex"), "before")
    git!(root, ["add", "."])
    git!(root, ["commit", "-q", "-m", "init"])
    :ok
  end

  test "1: a modified tracked file and an untracked one are dirty; a clean one is not",
       %{tmp_dir: root} do
    File.write!(Path.join(root, "lib/dirty.ex"), "after")
    File.write!(Path.join(root, "lib/new.ex"), "new")

    assert GitStatus.dirty_paths(root, ["lib/clean.ex", "lib/dirty.ex", "lib/new.ex"]) ==
             {:ok, ["lib/dirty.ex", "lib/new.ex"]}

    assert GitStatus.dirty_paths(root, ["lib/clean.ex"]) == {:ok, []}
    assert GitStatus.dirty_paths(root, []) == {:ok, []}
  end

  test "2: ignored? is true when .gitignore lists the journal, false otherwise", %{tmp_dir: root} do
    journal = ".anchor/sabotage/in-flight.json"

    assert GitStatus.ignored?(root, journal) == {:ok, false}

    File.write!(Path.join(root, ".gitignore"), "/.anchor/sabotage/in-flight.json\n")
    assert GitStatus.ignored?(root, journal) == {:ok, true}
  end

  describe "head_sha/1 and ancestor?/2 (DND-5474)" do
    # Sabotage record: ../../sabotage_records/sabotage-20261103-dnd_5474_coverage_map.md
    test "HEAD's sha; an earlier commit is an ancestor, a later or unknown one is not",
         %{tmp_dir: root} do
      {:ok, first} = GitStatus.head_sha(root)
      assert first =~ ~r/\A[0-9a-f]{40}\z/

      File.write!(Path.join(root, "lib/clean.ex"), "changed")
      git!(root, ["commit", "-q", "-am", "second"])
      {:ok, second} = GitStatus.head_sha(root)

      assert second != first
      assert GitStatus.ancestor?(root, first) == {:ok, true}
      assert GitStatus.ancestor?(root, second) == {:ok, true}

      git!(root, ["checkout", "-q", first])
      assert GitStatus.ancestor?(root, second) == {:ok, false}
      assert GitStatus.ancestor?(root, String.duplicate("0", 40)) == {:ok, false}
    end
  end

  describe "changed_since/2 (DND-5474)" do
    # Sabotage record: ../../sabotage_records/sabotage-20261103-dnd_5474_coverage_map.md
    test "files changed since a commit, committed or not, and untracked ones", %{tmp_dir: root} do
      {:ok, first} = GitStatus.head_sha(root)
      assert GitStatus.changed_since(root, first) == {:ok, []}

      File.write!(Path.join(root, "lib/clean.ex"), "committed change")
      git!(root, ["commit", "-q", "-am", "second"])
      File.write!(Path.join(root, "lib/dirty.ex"), "unstaged")
      File.write!(Path.join(root, "lib/new.ex"), "untracked")

      assert {:ok, paths} = GitStatus.changed_since(root, first)
      assert Enum.sort(paths) == ["lib/clean.ex", "lib/dirty.ex", "lib/new.ex"]

      assert {:error, {:git_failed, _args, 128, _out}} =
               GitStatus.changed_since(root, String.duplicate("0", 40))
    end
  end
end
