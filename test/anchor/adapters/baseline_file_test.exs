defmodule Anchor.Adapters.BaselineFileTest do
  # Adapter tests (DND-5441): reading and creating a baseline file in the
  # test's own tmp_dir.
  #
  # Sabotage record: ../../sabotage_records/baseline-20261103-dnd_5441_graph_rules_a.md
  # DND-5628 (symlinks): ../../sabotage_records/baseline_symlink-20261103-dnd_5441_graph_rules_a.md
  # Sabotage record (DND-5647): ../../sabotage_records/baseline-20261103-dnd_5648_graph_followups.md
  # Sabotage record (DND-5647, SW-G): ../../sabotage_records/failures-20261103-dnd_5648_graph_followups.md
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

  # DND-5647: a directory swapped for a symlink between the lstat walk and the
  # write redirected the write outside the root. The write step is a seam
  # (`:before_write`), so the swap happens at a fixed point: no timing, no
  # race. After the write the real path is checked, and what was written
  # outside is removed.
  describe "a directory swapped for a symlink after the check (DND-5647)" do
    setup %{tmp_dir: tmp_dir} do
      root = Path.join(tmp_dir, "root")
      outside = Path.join(tmp_dir, "outside")
      File.mkdir_p!(Path.join(root, ".anchor/baselines"))
      File.mkdir_p!(outside)
      %{root: root, outside: outside}
    end

    defp swap(root, outside) do
      fn ->
        File.rm_rf!(Path.join(root, ".anchor/baselines"))
        File.ln_s!(outside, Path.join(root, ".anchor/baselines"))
      end
    end

    test "the write is refused, naming where it went, and nothing remains outside", %{
      root: root,
      outside: outside
    } do
      assert {:error, {:escaped_root, real}} =
               BaselineFile.create(root, ".anchor/baselines/r.txt", "r|A|x\n",
                 before_write: swap(root, outside)
               )

      assert String.ends_with?(real, "/outside/r.txt")
      assert File.ls!(outside) == []
    end

    test "a swap of a directory higher on the path is caught too", %{
      root: root,
      outside: outside
    } do
      File.mkdir_p!(Path.join(outside, "baselines"))

      swap_anchor = fn ->
        File.rm_rf!(Path.join(root, ".anchor"))
        File.ln_s!(outside, Path.join(root, ".anchor"))
      end

      assert {:error, {:escaped_root, _real}} =
               BaselineFile.create(root, ".anchor/baselines/r.txt", "r|A|x\n",
                 before_write: swap_anchor
               )

      assert File.ls!(Path.join(outside, "baselines")) == []
    end

    test "a sibling whose name starts with the root's is outside it", %{
      tmp_dir: tmp_dir,
      root: root
    } do
      sibling = Path.join(tmp_dir, "root_sibling")
      File.mkdir_p!(sibling)

      assert {:error, {:escaped_root, _real}} =
               BaselineFile.create(root, ".anchor/baselines/r.txt", "r|A|x\n",
                 before_write: swap(root, sibling)
               )

      assert File.ls!(sibling) == []
    end

    test "positive control: with no swap the hook runs and the file is written", %{
      root: root,
      outside: outside
    } do
      parent = self()

      assert :ok =
               BaselineFile.create(root, ".anchor/baselines/r.txt", "r|A|x\n",
                 before_write: fn -> send(parent, :hook_ran) end
               )

      assert_received :hook_ran
      assert File.read!(Path.join(root, ".anchor/baselines/r.txt")) == "r|A|x\n"
      assert File.ls!(outside) == []
    end

    test "a root reached through a symlink is its real path, not an escape", %{
      tmp_dir: tmp_dir,
      root: root
    } do
      alias_root = Path.join(tmp_dir, "alias")
      File.ln_s!(root, alias_root)

      assert :ok = BaselineFile.create(alias_root, ".anchor/baselines/r.txt", "r|A|x\n")
      assert File.read!(Path.join(root, ".anchor/baselines/r.txt")) == "r|A|x\n"
    end
  end
end
