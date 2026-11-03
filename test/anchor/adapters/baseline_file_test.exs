defmodule Anchor.Adapters.BaselineFileTest do
  # Adapter tests (DND-5441): reading and creating a baseline file in the
  # test's own tmp_dir.
  #
  # Sabotage record: ../../sabotage_records/baseline-20261103-dnd_5441_graph_rules_a.md
  # DND-5628 (symlinks): ../../sabotage_records/baseline_symlink-20261103-dnd_5441_graph_rules_a.md
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

  # DND-5628: a symlink committed in the repository (`.anchor` or the file
  # itself) passed the lexical check, so a run read, and --write-baseline
  # created, a file outside the root. Each case keeps a target outside the
  # root and asserts it is unchanged.
  describe "a symlink on the path (DND-5628)" do
    setup %{tmp_dir: tmp_dir} do
      root = Path.join(tmp_dir, "root")
      outside = Path.join(tmp_dir, "outside")
      File.mkdir_p!(root)
      File.mkdir_p!(outside)
      %{root: root, outside: outside}
    end

    test "a symlinked directory is refused for read and for create; nothing is written outside",
         %{root: root, outside: outside} do
      File.write!(Path.join(outside, "r.txt"), "r|A|x\n")
      File.ln_s!(outside, Path.join(root, ".anchor"))

      assert BaselineFile.read(root, ".anchor/r.txt") == {:error, {:symlink, ".anchor"}}

      assert BaselineFile.create(root, ".anchor/new.txt", "r|B|y\n") ==
               {:error, {:symlink, ".anchor"}}

      assert File.ls!(outside) == ["r.txt"]
      assert File.read!(Path.join(outside, "r.txt")) == "r|A|x\n"
    end

    test "a symlink deeper on the path is named by its own path", %{root: root, outside: outside} do
      File.mkdir_p!(Path.join(root, ".anchor"))
      File.ln_s!(outside, Path.join(root, ".anchor/baselines"))

      assert BaselineFile.create(root, ".anchor/baselines/r.txt", "r|B|y\n") ==
               {:error, {:symlink, ".anchor/baselines"}}

      assert File.ls!(outside) == []
    end

    test "a symlinked file is refused for read and for create; its target is unchanged",
         %{root: root, outside: outside} do
      target = Path.join(outside, "target.txt")
      File.write!(target, "r|A|x\n")
      File.mkdir_p!(Path.join(root, ".anchor"))
      File.ln_s!(target, Path.join(root, ".anchor/r.txt"))

      assert BaselineFile.read(root, ".anchor/r.txt") == {:error, {:symlink, ".anchor/r.txt"}}

      assert BaselineFile.create(root, ".anchor/r.txt", "r|B|y\n") ==
               {:error, {:symlink, ".anchor/r.txt"}}

      assert File.read!(target) == "r|A|x\n"
    end

    test "a dangling symlink at the file is refused, and its target is never created", %{
      root: root,
      outside: outside
    } do
      target = Path.join(outside, "planted.txt")
      File.mkdir_p!(Path.join(root, ".anchor"))
      File.ln_s!(target, Path.join(root, ".anchor/r.txt"))

      assert BaselineFile.create(root, ".anchor/r.txt", "r|B|y\n") ==
               {:error, {:symlink, ".anchor/r.txt"}}

      refute File.exists?(target)
    end

    test "positive control: a plain path is created and read, and leaves no temp file", %{
      root: root
    } do
      assert :ok = BaselineFile.create(root, ".anchor/baselines/r.txt", "r|A|x\n")
      assert BaselineFile.read(root, ".anchor/baselines/r.txt") == {:ok, ["r|A|x"]}
      assert File.ls!(Path.join(root, ".anchor/baselines")) == ["r.txt"]
    end
  end
end
