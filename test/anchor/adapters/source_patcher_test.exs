defmodule Anchor.Adapters.SourcePatcherTest do
  # DND-5473: the journal and file writes on a real tmp directory.
  # Sabotage record: ../../sabotage_records/sabotage-20261103-dnd_5473_sabotage_run.md
  use ExUnit.Case, async: true

  alias Anchor.Adapters.SourcePatcher
  alias Anchor.Domain.Sabotage.Journal

  @moduletag :tmp_dir

  @original <<"defmodule M do\n  # caf", 0xE9, "\nend\n">>

  test "1: write_journal then read_journal round-trips the entry, non-UTF-8 bytes intact",
       %{tmp_dir: root} do
    entry = Journal.entry("lib/m.ex", "abc123abc123", @original, "mutated")

    assert SourcePatcher.read_journal(root) == :none
    assert SourcePatcher.write_journal(root, entry) == :ok
    assert File.regular?(Path.join(root, ".anchor/sabotage/in-flight.json"))
    assert {:ok, read} = SourcePatcher.read_journal(root)
    assert %{read | owner: nil} == entry
    assert SourcePatcher.delete_journal(root) == :ok
    assert SourcePatcher.read_journal(root) == :none
    assert SourcePatcher.delete_journal(root) == :ok
  end

  test "a second write_journal while one exists is {:error, :eexist}; the first is kept",
       %{tmp_dir: root} do
    first = Journal.entry("lib/m.ex", "aaaaaaaaaaaa", @original, "one")
    second = Journal.entry("lib/m.ex", "bbbbbbbbbbbb", @original, "two")

    assert SourcePatcher.write_journal(root, first) == :ok
    assert SourcePatcher.write_journal(root, second) == {:error, :eexist}
    assert {:ok, %Journal{mutant_id: "aaaaaaaaaaaa"}} = SourcePatcher.read_journal(root)
  end

  test "the journal names this run as its owner, alive; a dead or reused pid is not",
       %{tmp_dir: root} do
    entry = Journal.entry("lib/m.ex", "aaaaaaaaaaaa", @original, "one")
    assert SourcePatcher.write_journal(root, entry) == :ok

    assert {:ok, %Journal{owner: %{os_pid: pid, started: started} = owner}} =
             SourcePatcher.read_journal(root)

    assert Integer.to_string(pid) == System.pid()
    assert SourcePatcher.owner_alive?(owner)
    refute SourcePatcher.owner_alive?(%{owner | started: started <> "0"})
    refute SourcePatcher.owner_alive?(%{os_pid: 2_147_483_646, started: started})
    refute SourcePatcher.owner_alive?(nil)
  end

  test "2: write_file replaces the content and leaves no .anchor-tmp", %{tmp_dir: root} do
    path = Path.join(root, "m.ex")
    File.write!(path, "old")

    assert SourcePatcher.write_file(path, @original) == :ok
    assert File.read!(path) == @original
    refute File.exists?(path <> ".anchor-tmp")
    assert SourcePatcher.sha256_file(path) == {:ok, Journal.sha256(@original)}
  end

  test "3: touch_ahead moves the mtime past a file written just before, and again past itself",
       %{tmp_dir: root} do
    before = Path.join(root, "before.ex")
    path = Path.join(root, "m.ex")
    File.write!(before, "x")
    File.write!(path, "y")

    assert SourcePatcher.touch_ahead(path) == :ok
    assert mtime(path) > mtime(before)

    first = mtime(path)
    assert SourcePatcher.touch_ahead(path) == :ok
    assert mtime(path) > first
  end

  test "4: a corrupt journal is {:error, :corrupt_journal}", %{tmp_dir: root} do
    File.mkdir_p!(Path.join(root, ".anchor/sabotage"))
    File.write!(Path.join(root, ".anchor/sabotage/in-flight.json"), "{not json")

    assert SourcePatcher.read_journal(root) == {:error, :corrupt_journal}
  end

  test "existing/1 keeps the regular files; save_run creates its directory", %{tmp_dir: root} do
    File.write!(Path.join(root, "a_test.exs"), "")
    File.mkdir_p!(Path.join(root, "dir_test.exs"))
    paths = Enum.map(["a_test.exs", "dir_test.exs", "missing_test.exs"], &Path.join(root, &1))

    assert SourcePatcher.existing(paths) == [Path.join(root, "a_test.exs")]

    run_path = Path.join(root, "_build/dev/anchor/sabotage/last-run.etf")
    assert SourcePatcher.save_run(run_path, "bytes") == :ok
    assert File.read!(run_path) == "bytes"
  end

  defp mtime(path), do: File.stat!(path, time: :posix).mtime
end
