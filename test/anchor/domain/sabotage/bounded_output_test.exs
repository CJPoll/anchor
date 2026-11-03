defmodule Anchor.Domain.Sabotage.BoundedOutputTest do
  # DND-5573: the bounded collector a test run's output goes into. Pure.
  # Sabotage record: ../../../sabotage_records/sabotage-20261103-dnd_5570_sabotage_hardening.md
  use ExUnit.Case, async: true

  alias Anchor.Domain.Sabotage.BoundedOutput

  defp collect(chunks, head, tail) do
    Enum.into(chunks, BoundedOutput.new(head, tail))
  end

  test "output within both limits is kept whole and nothing is dropped" do
    out = collect(["abc", "def"], 4, 4)

    assert BoundedOutput.text(out) == "abcdef"
    assert BoundedOutput.dropped(out) == 0
  end

  test "output past the limits keeps the first head bytes and the last tail bytes, and counts the rest" do
    out = collect(["0123456789", "abcdefghij", "ABCDEFGHIJ"], 4, 6)

    assert out.head == "0123"
    assert out.tail == "EFGHIJ"
    assert BoundedOutput.dropped(out) == 30 - 4 - 6

    assert BoundedOutput.text(out) ==
             "0123\n[... 20 bytes of test output dropped ...]\nEFGHIJ"
  end

  test "the same bytes in any chunking keep and drop the same bytes" do
    bytes = Enum.map_join(1..200, ",", &Integer.to_string/1)

    whole = collect([bytes], 17, 23)

    for size <- [1, 2, 3, 7, 50, 1000] do
      chunks =
        bytes
        |> :binary.bin_to_list()
        |> Enum.chunk_every(size)
        |> Enum.map(&IO.iodata_to_binary/1)

      chunked = collect(chunks, 17, 23)

      assert BoundedOutput.text(chunked) == BoundedOutput.text(whole), "chunks of #{size}"
      assert BoundedOutput.dropped(chunked) == byte_size(bytes) - 40, "chunks of #{size}"
    end
  end

  test "what is held never exceeds the limits, whatever is collected" do
    chunks = List.duplicate(String.duplicate("x", 1024), 2000)
    out = collect(chunks, 100, 150)

    assert byte_size(out.head) == 100
    assert byte_size(out.tail) == 150
    assert BoundedOutput.dropped(out) == 2000 * 1024 - 250
  end

  test "a character cut at a boundary never makes the text invalid UTF-8" do
    out = collect([String.duplicate("é", 40)], 5, 5)

    assert String.valid?(BoundedOutput.text(out))
  end
end
