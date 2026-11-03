defmodule Anchor.Domain.GraphKeyTest do
  # DND-5440: the graph artifact's key. Pure Domain. DND-5586: the source
  # facts are in it too.
  #
  # Sabotage record: ../../sabotage_records/graph_runner-20261103-dnd_5440_graph_runner.md
  # Sabotage record: ../../sabotage_records/graph_runner-20261103-dnd_5581_hardening_batch.md
  use ExUnit.Case, async: true

  alias Anchor.Domain.GraphKey

  @entries [{"ebin/a.beam", <<1, 2, 3>>}, {"ebin/b.beam", <<4, 5>>}]

  test "is a lower-case hex sha256" do
    assert GraphKey.key(@entries, [], "rules: []", "0.1.0") =~ ~r/\A[0-9a-f]{64}\z/
  end

  test "the same entries in another order give the same key" do
    assert GraphKey.key(Enum.reverse(@entries), [], "c", "v") ==
             GraphKey.key(@entries, [], "c", "v")
  end

  test "two paths with the same bytes give one key whichever is read first (sorted by path)" do
    same = [{"ebin/a.beam", "x"}, {"ebin/b.beam", "x"}]
    assert GraphKey.key(Enum.reverse(same), [], "c", "v") == GraphKey.key(same, [], "c", "v")
  end

  test "one changed byte of a beam, the config or the version changes the key" do
    base = GraphKey.key(@entries, [], "c", "v")

    refute GraphKey.key([{"ebin/a.beam", <<1, 2, 4>>}, {"ebin/b.beam", <<4, 5>>}], [], "c", "v") ==
             base

    refute GraphKey.key(@entries, [], "d", "v") == base
    refute GraphKey.key(@entries, [], "c", "w") == base
  end

  test "moving bytes between a path and its beam changes the key (each part is framed)" do
    refute GraphKey.key([{"ab", "c"}], [], "", "") == GraphKey.key([{"a", "bc"}], [], "", "")
  end

  # DND-5586: the source facts the graph was built from are in the key.
  describe "sources" do
    @sources [{"lib/a.ex", "facts a"}, {"lib/b.ex", "facts b"}]

    test "a changed source entry changes the key; one more or one fewer does too" do
      base = GraphKey.key(@entries, @sources, "c", "v")

      refute GraphKey.key(@entries, [{"lib/a.ex", "facts A"}, {"lib/b.ex", "facts b"}], "c", "v") ==
               base

      refute GraphKey.key(@entries, [{"lib/a.ex", "facts a"}], "c", "v") == base
      refute GraphKey.key(@entries, [], "c", "v") == base
    end

    test "the same sources in another order give the same key (sorted by path)" do
      assert GraphKey.key(@entries, Enum.reverse(@sources), "c", "v") ==
               GraphKey.key(@entries, @sources, "c", "v")
    end

    test "an entry moved from the beams to the sources changes the key (each list is counted)" do
      # The last beam by path: without the counts, both inputs would frame to
      # the same bytes in the same order.
      [first, last] = @entries
      refute GraphKey.key([first], [last], "c", "v") == GraphKey.key(@entries, [], "c", "v")
    end
  end
end
