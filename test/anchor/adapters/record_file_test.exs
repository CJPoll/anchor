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
end
