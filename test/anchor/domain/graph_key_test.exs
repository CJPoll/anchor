defmodule Anchor.Domain.GraphKeyTest do
  # DND-5440: the graph artifact's key. Pure Domain. DND-5586: the source
  # facts are in it too.
  #
  # Sabotage record: ../../sabotage_records/graph_runner-20261103-dnd_5440_graph_runner.md
  # Sabotage record: ../../sabotage_records/graph_runner-20261103-dnd_5581_hardening_batch.md
  # Sabotage record: ../../sabotage_records/graph_runner-20261103-dnd_5638_root_in_key.md
  use ExUnit.Case, async: true

  alias Anchor.Domain.GraphKey

  @root "/work/my_app"
  @entries [{"ebin/a.beam", <<1, 2, 3>>}, {"ebin/b.beam", <<4, 5>>}]

  test "is a lower-case hex sha256" do
    assert GraphKey.key(@root, @entries, [], "rules: []", "0.1.0") =~ ~r/\A[0-9a-f]{64}\z/
  end

  test "the same entries in another order give the same key" do
    assert GraphKey.key(@root, Enum.reverse(@entries), [], "c", "v") ==
             GraphKey.key(@root, @entries, [], "c", "v")
  end

  test "two paths with the same bytes give one key whichever is read first (sorted by path)" do
    same = [{"ebin/a.beam", "x"}, {"ebin/b.beam", "x"}]

    assert GraphKey.key(@root, Enum.reverse(same), [], "c", "v") ==
             GraphKey.key(@root, same, [], "c", "v")
  end

  test "one changed byte of a beam, the config or the version changes the key" do
    base = GraphKey.key(@root, @entries, [], "c", "v")

    refute GraphKey.key(
             @root,
             [{"ebin/a.beam", <<1, 2, 4>>}, {"ebin/b.beam", <<4, 5>>}],
             [],
             "c",
             "v"
           ) ==
             base

    refute GraphKey.key(@root, @entries, [], "d", "v") == base
    refute GraphKey.key(@root, @entries, [], "c", "w") == base
  end

  test "moving bytes between a path and its beam changes the key (each part is framed)" do
    refute GraphKey.key(@root, [{"ab", "c"}], [], "", "") ==
             GraphKey.key(@root, [{"a", "bc"}], [], "", "")
  end

  # DND-5586: the source facts the graph was built from are in the key.
  describe "sources" do
    @sources [{"lib/a.ex", "facts a"}, {"lib/b.ex", "facts b"}]

    test "a changed source entry changes the key; one more or one fewer does too" do
      base = GraphKey.key(@root, @entries, @sources, "c", "v")

      refute GraphKey.key(
               @root,
               @entries,
               [{"lib/a.ex", "facts A"}, {"lib/b.ex", "facts b"}],
               "c",
               "v"
             ) ==
               base

      refute GraphKey.key(@root, @entries, [{"lib/a.ex", "facts a"}], "c", "v") == base
      refute GraphKey.key(@root, @entries, [], "c", "v") == base
    end

    test "the same sources in another order give the same key (sorted by path)" do
      assert GraphKey.key(@root, @entries, Enum.reverse(@sources), "c", "v") ==
               GraphKey.key(@root, @entries, @sources, "c", "v")
    end

    test "an entry moved from the beams to the sources changes the key (each list is counted)" do
      # The last beam by path: without the counts, both inputs would frame to
      # the same bytes in the same order.
      [first, last] = @entries

      refute GraphKey.key(@root, [first], [last], "c", "v") ==
               GraphKey.key(@root, @entries, [], "c", "v")
    end
  end

  # DND-5638: the artifact's facts name paths relative to the root, so two
  # checkouts with the same build output must not share a key.
  describe "root" do
    test "the same inputs under different roots give different keys" do
      refute GraphKey.key("/work/a", @entries, [], "c", "v") ==
               GraphKey.key("/work/b", @entries, [], "c", "v")
    end

    test "the same inputs under the same root give the same key" do
      assert GraphKey.key("/work/a", @entries, [], "c", "v") ==
               GraphKey.key("/work/a", @entries, [], "c", "v")
    end

    test "moving bytes between the root and the version changes the key (the root is framed)" do
      # Unframed, version <> root is "v1/work" for both.
      refute GraphKey.key("/work", [], [], "", "v1") == GraphKey.key("work", [], [], "", "v1/")
    end
  end
end
