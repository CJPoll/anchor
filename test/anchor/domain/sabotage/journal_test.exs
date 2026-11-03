defmodule Anchor.Domain.Sabotage.JournalTest do
  # DND-5473: the in-flight journal's entry, bytes and recovery verdict.
  # Sabotage record: ../../../sabotage_records/sabotage-20261103-dnd_5473_sabotage_run.md
  use ExUnit.Case, async: true

  alias Anchor.Domain.Sabotage.Journal

  @original <<"defmodule M do\n  # caf", 0xE9, 0xFF, "\nend\n">>
  @mutated "defmodule M do\nend\n"

  test "an entry hashes both texts and round-trips, non-UTF-8 bytes included" do
    entry = Journal.entry("lib/m.ex", "abc123abc123", @original, @mutated)

    assert entry.original_sha == Journal.sha256(@original)
    assert entry.mutated_sha == Journal.sha256(@mutated)
    assert entry.original_sha =~ ~r/\A[0-9a-f]{64}\z/
    assert Journal.decode(Journal.encode(entry)) == {:ok, entry}
  end

  test "bytes it did not write are corrupt, never a partial entry" do
    entry = Journal.entry("lib/m.ex", "abc123abc123", @original, @mutated)

    tampered =
      String.replace(Journal.encode(entry), entry.original_sha, String.duplicate("0", 64))

    for bytes <- ["", "{", "[]", ~s({"version":2}), tampered],
        do: assert(Journal.decode(bytes) == {:error, :corrupt_journal}, inspect(bytes))
  end

  test "the owner round-trips; a malformed owner is corrupt" do
    entry = %{
      Journal.entry("lib/m.ex", "abc123abc123", @original, @mutated)
      | owner: %{os_pid: 77, started: "12345"}
    }

    assert Journal.decode(Journal.encode(entry)) == {:ok, entry}

    bad = String.replace(Journal.encode(entry), ~s("os_pid":77), ~s("os_pid":"77"))
    assert Journal.decode(bad) == {:error, :corrupt_journal}
  end

  test "a journal naming a file outside the project root is corrupt" do
    for file <- ["/etc/passwd", "../outside.ex", "lib/../../outside.ex", ""] do
      entry = Journal.entry(file, "abc123abc123", @original, @mutated)
      assert Journal.decode(Journal.encode(entry)) == {:error, :corrupt_journal}, file
    end
  end

  test "recovery: the mutated hash restores, the original hash discards, anything else is changed" do
    entry = Journal.entry("lib/m.ex", "abc123abc123", @original, @mutated)

    assert Journal.recovery(entry, Journal.sha256(@mutated)) == :restore
    assert Journal.recovery(entry, Journal.sha256(@original)) == :discard
    assert Journal.recovery(entry, Journal.sha256("edited")) == :changed
  end
end
