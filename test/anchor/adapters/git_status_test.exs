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
end
