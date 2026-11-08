defmodule Anchor.Adapters.SourcePatcherTest do
  # DND-5473: the journal and file writes on a real tmp directory.
  # Sabotage record: ../../sabotage_records/sabotage-20261103-dnd_5473_sabotage_run.md
  # Sabotage record (DND-5570): ../../sabotage_records/sabotage-20261103-dnd_5570_sabotage_hardening.md
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

  test "the run lock: taken with this run as holder, refused while held, released",
       %{tmp_dir: root} do
    lock = Path.join(root, "_build/anchor-sabotage.lock")

    assert SourcePatcher.take_lock(root) == :ok
    assert %{os_pid: pid} = me = Journal.decode_lock(File.read!(lock))
    assert Integer.to_string(pid) == System.pid()

    assert SourcePatcher.take_lock(root) == {:error, {:held, me}}
    assert Journal.decode_lock(File.read!(lock)) == me

    assert SourcePatcher.release_lock(root) == :ok
    refute File.exists?(lock)
    assert SourcePatcher.release_lock(root) == :ok
    assert File.ls!(Path.join(root, "_build")) == []
  end

  test "with no /proc the lock is refused, :no_proc, and nothing is written", %{tmp_dir: root} do
    no_proc = Path.join(root, "no-proc-here")

    assert SourcePatcher.take_lock(root, no_proc) == {:error, :no_proc}
    refute File.exists?(Path.join(root, "_build"))

    # Positive control: the same call with this host's /proc takes it.
    assert SourcePatcher.take_lock(root, "/proc") == :ok
    assert SourcePatcher.release_lock(root) == :ok
  end

  test "a lock another run holds is never released by this one", %{tmp_dir: root} do
    lock = Path.join(root, "_build/anchor-sabotage.lock")
    File.mkdir_p!(Path.dirname(lock))
    theirs = Journal.encode_lock(%{os_pid: 2_147_483_646, started: "1"})
    File.write!(lock, theirs)

    assert SourcePatcher.release_lock(root) == :ok
    assert File.read!(lock) == theirs
  end

  test "a takeover goes through the takeover lock: held by a live run, the dead lock is left",
       %{tmp_dir: root} do
    lock = Path.join(root, "_build/anchor-sabotage.lock")
    mutex = lock <> ".takeover"
    File.mkdir_p!(Path.dirname(lock))
    dead = Journal.encode_lock(%{os_pid: 2_147_483_646, started: "1"})
    File.write!(lock, dead)

    # The takeover lock names this (live) process: another run is mid-takeover.
    assert SourcePatcher.take_lock(root) == :ok
    me = Journal.decode_lock(File.read!(lock))
    assert SourcePatcher.release_lock(root) == :ok

    File.write!(lock, dead)
    File.write!(mutex, Journal.encode_lock(me))

    assert SourcePatcher.take_lock(root) == {:error, {:held, me}}
    assert File.read!(lock) == dead

    File.write!(mutex, dead)

    assert SourcePatcher.take_lock(root) ==
             {:error, {:stuck, "_build/anchor-sabotage.lock.takeover"}}

    assert File.read!(lock) == dead
  end

  test "a dead or unnamed holder's lock is taken over", %{tmp_dir: root} do
    lock = Path.join(root, "_build/anchor-sabotage.lock")
    File.mkdir_p!(Path.dirname(lock))

    for stale <- [
          Journal.encode_lock(%{os_pid: 2_147_483_646, started: "1"}),
          Journal.encode_lock(nil),
          "not a lock"
        ] do
      File.write!(lock, stale)
      assert SourcePatcher.take_lock(root) == :ok
      assert %{os_pid: pid} = Journal.decode_lock(File.read!(lock))
      assert Integer.to_string(pid) == System.pid()
      assert SourcePatcher.release_lock(root) == :ok
      assert File.ls!(Path.dirname(lock)) == []
    end
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

  # DND-6070: the mirror directories are listed so the mirror's siblings run.
  test "files_in/1 lists the regular files directly in each directory, sorted; a missing one is none",
       %{tmp_dir: root} do
    a = Path.join(root, "a")
    File.mkdir_p!(Path.join(a, "sub_test.exs"))
    File.mkdir_p!(Path.join(root, "b"))
    File.write!(Path.join(a, "y_test.exs"), "")
    File.write!(Path.join(a, "x_test.exs"), "")
    File.write!(Path.join(a, "sub_test.exs/deep_test.exs"), "")
    File.write!(Path.join(root, "b/z_test.exs"), "")

    assert SourcePatcher.files_in([a, Path.join(root, "missing"), Path.join(root, "b")]) == [
             Path.join(a, "x_test.exs"),
             Path.join(a, "y_test.exs"),
             Path.join(root, "b/z_test.exs")
           ]

    assert SourcePatcher.files_in([Path.join(a, "x_test.exs")]) == []
    assert SourcePatcher.files_in([]) == []
  end

  defp mtime(path), do: File.stat!(path, time: :posix).mtime

  test "DND-5485: symlinked/2 names each path with a symlink at the file or a directory above it",
       %{tmp_dir: root} do
    # Sabotage record: ../../sabotage_records/sabotage-20261103-dnd_5483_survivors_replay.md
    outside = Path.join(root, "outside")
    File.mkdir_p!(Path.join(outside, "dir"))
    File.write!(Path.join(outside, "x.ex"), "outside\n")
    File.mkdir_p!(Path.join(root, "proj/lib"))
    File.write!(Path.join(root, "proj/lib/real.ex"), "real\n")
    File.ln_s!(Path.join(outside, "x.ex"), Path.join(root, "proj/lib/link.ex"))
    File.ln_s!(Path.join(outside, "dir"), Path.join(root, "proj/linked_dir"))
    File.ln_s!(Path.join(root, "nowhere"), Path.join(root, "proj/lib/dangling.ex"))
    proj = Path.join(root, "proj")

    paths = ["lib/real.ex", "lib/link.ex", "linked_dir/y.ex", "lib/dangling.ex", "lib/absent.ex"]

    assert SourcePatcher.symlinked(proj, paths) ==
             ["lib/link.ex", "linked_dir/y.ex", "lib/dangling.ex"]
  end
end
