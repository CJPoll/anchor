defmodule Anchor.Adapters.RecordFileTest do
  # DND-5484: sabotage record files on a tmp dir: created (never over an
  # existing one), appended, listed.
  # Sabotage record: ../../sabotage_records/sabotage-20261103-dnd_5484_records.md
  use ExUnit.Case, async: true

  alias Anchor.Adapters.RecordFile

  @moduletag :tmp_dir

  test "1: create writes a new record, its directories made first", %{tmp_dir: root} do
    assert RecordFile.create(root, "apps/core/test/sabotage_records/a.md", "one\n") == :ok
    assert File.read!(Path.join(root, "apps/core/test/sabotage_records/a.md")) == "one\n"
  end

  test "2: create on an existing path is :eexist and leaves the file untouched", %{tmp_dir: root} do
    :ok = RecordFile.create(root, "r/a.md", "original\n")

    assert RecordFile.create(root, "r/a.md", "new\n") == {:error, :eexist}
    assert File.read!(Path.join(root, "r/a.md")) == "original\n"
  end

  test "3: append keeps the old content and adds the new after a blank line", %{tmp_dir: root} do
    :ok = RecordFile.create(root, "r/a.md", "old\n")

    assert RecordFile.append(root, "r/a.md", "## Run 10:00 UTC\n") == :ok
    assert File.read!(Path.join(root, "r/a.md")) == "old\n\n## Run 10:00 UTC\n"
    assert RecordFile.append(root, "r/none.md", "x") == {:error, :enoent}
  end

  test "4: list finds every record under an apps/*/ glob, never a README", %{tmp_dir: root} do
    for path <- [
          "apps/core/test/sabotage_records/a.md",
          "apps/web/test/sabotage_records/b.md",
          "apps/web/test/sabotage_records/README.md",
          "apps/web/test/other/c.md"
        ],
        do: :ok = RecordFile.create(root, path, "x")

    assert RecordFile.list(root, "apps/*/test/sabotage_records") == [
             "apps/core/test/sabotage_records/a.md",
             "apps/web/test/sabotage_records/b.md"
           ]

    assert RecordFile.read(root, "apps/core/test/sabotage_records/a.md") == {:ok, "x"}
  end

  test "DND-5490: write_report writes the markdown and its .etf, overwriting both", %{
    tmp_dir: root
  } do
    # Sabotage record: ../../sabotage_records/sabotage-20261106-dnd_5490_scan.md
    term = :erlang.term_to_binary(%{findings: []})

    assert RecordFile.write_report(root, "out/scan.md", "old\n", "old") ==
             {:ok, [Path.join(root, "out/scan.md"), Path.join(root, "out/scan.etf")]}

    assert {:ok, _paths} = RecordFile.write_report(root, "out/scan.md", "# scan\n", term)
    assert File.read!(Path.join(root, "out/scan.md")) == "# scan\n"
    assert File.read!(Path.join(root, "out/scan.etf")) == term

    absolute = Path.join(root, "abs/scan.md")
    assert {:ok, [^absolute, _etf]} = RecordFile.write_report("/elsewhere", absolute, "x", term)
  end

  test "DND-5490: write_report says why it could not write, at each step", %{tmp_dir: root} do
    # Sabotage record: ../../sabotage_records/sabotage-20261106-dnd_5490_scan.md
    File.write!(Path.join(root, "file"), "x")
    # The directory cannot be made: a file is in its place.
    assert RecordFile.write_report(root, "file/scan.md", "m", "t") == {:error, :enotdir}
    # The markdown cannot be written: a directory is at its path.
    File.mkdir_p!(Path.join(root, "a/scan.md"))
    assert RecordFile.write_report(root, "a/scan.md", "m", "t") == {:error, :eisdir}
    # The .etf cannot be written: a directory is at its path.
    File.mkdir_p!(Path.join(root, "b/scan.etf"))
    assert RecordFile.write_report(root, "b/scan.md", "m", "t") == {:error, :eisdir}
  end
end
