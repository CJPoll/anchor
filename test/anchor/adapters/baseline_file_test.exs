defmodule Anchor.Adapters.BaselineFileTest do
  # Adapter tests (DND-5441): reading and creating a baseline file in the
  # test's own tmp_dir.
  #
  # Sabotage record: ../../sabotage_records/baseline-20261103-dnd_5441_graph_rules_a.md
  use ExUnit.Case, async: true

  alias Anchor.Adapters.BaselineFile

  @moduletag :tmp_dir

  test "create/3 makes the parent directories and the file; read/2 returns its entries", %{
    tmp_dir: root
  } do
    assert :ok = BaselineFile.create(root, ".anchor/baselines/r.txt", "r|A|x\n")
    assert BaselineFile.read(root, ".anchor/baselines/r.txt") == {:ok, ["r|A|x"]}
  end

  test "create/3 on an existing file returns {:error, :exists} and leaves its bytes", %{
    tmp_dir: root
  } do
    File.write!(Path.join(root, "r.txt"), "keep\n")

    assert BaselineFile.create(root, "r.txt", "new\n") == {:error, :exists}
    assert File.read!(Path.join(root, "r.txt")) == "keep\n"
  end

  # Review floor on d9a61de (ADR 001): the adapter returns entries, so a
  # line that is not UTF-8 is its error, naming the line.
  test "read/2 parses: comments dropped, a line that is not UTF-8 refused", %{tmp_dir: root} do
    File.write!(Path.join(root, "r.txt"), "# header\nr|A|x\n\nr|B|y\n")
    assert BaselineFile.read(root, "r.txt") == {:ok, ["r|A|x", "r|B|y"]}

    File.write!(Path.join(root, "bad.txt"), "r|A|x\n\xff\n")
    assert BaselineFile.read(root, "bad.txt") == {:error, {:line, 2, :invalid_utf8}}
  end

  test "read/2 of a missing file is its posix error", %{tmp_dir: root} do
    assert BaselineFile.read(root, "nope.txt") == {:error, :enoent}
  end

  test "an absolute path or a .. segment is refused before any file is touched", %{
    tmp_dir: root
  } do
    outside = Path.join(root, "outside.txt")

    assert BaselineFile.create(root, outside, "x") == {:error, :outside_root}
    assert BaselineFile.create(root, "a/../../outside.txt", "x") == {:error, :outside_root}
    assert BaselineFile.read(root, "../x") == {:error, :outside_root}
    refute File.exists?(outside)
  end
end
