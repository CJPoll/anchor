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
    assert SourcePatcher.read_journal(root) == {:ok, entry}
    assert SourcePatcher.delete_journal(root) == :ok
    assert SourcePatcher.read_journal(root) == :none
    assert SourcePatcher.delete_journal(root) == :ok
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
