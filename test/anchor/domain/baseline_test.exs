defmodule Anchor.Domain.BaselineTest do
  # DND-5441: the shrink-only ratchet's file format and multiset comparison.
  # Pure Domain.
  #
  # Sabotage record: ../../sabotage_records/baseline-20261103-dnd_5441_graph_rules_a.md
  use ExUnit.Case, async: true

  alias Anchor.Domain.Baseline

  describe "parse/1" do
    test "keys in file order; comments, blank lines and trailing spaces dropped" do
      bytes = "# anchor baseline for r; shrink only\nr|A|-> B  \n\n  # note\nr|C|-> D\nr|A|-> B\n"
      assert Baseline.parse(bytes) == {:ok, ["r|A|-> B", "r|C|-> D", "r|A|-> B"]}
    end

    test "invalid UTF-8 on line 3 is refused, naming the line" do
      assert Baseline.parse("r|A\nr|B\nr|\xff\n") == {:error, {:line, 3, :invalid_utf8}}
    end

    test "an empty file has no entries" do
      assert Baseline.parse("") == {:ok, []}
    end
  end

  describe "compare/2" do
    test "equal multisets: all held, none new or stale" do
      assert Baseline.compare(~w(a b a), ~w(a a b)) == %{new: [], stale: [], held: ~w(a b a)}
    end

    test "a key listed twice and found once leaves one stale" do
      assert Baseline.compare(~w(a), ~w(a a)) == %{new: [], stale: ~w(a), held: ~w(a)}
    end

    test "a key found twice and listed once is one new" do
      assert Baseline.compare(~w(a a), ~w(a)) == %{new: ~w(a), stale: [], held: ~w(a)}
    end

    test "disjoint: every finding new, every entry stale" do
      assert Baseline.compare(~w(a b), ~w(c)) == %{new: ~w(a b), stale: ~w(c), held: []}
    end

    test "both empty is empty; positive control: findings with no entries are new" do
      assert Baseline.compare([], []) == %{new: [], stale: [], held: []}
      assert Baseline.compare(~w(a), []) == %{new: ~w(a), stale: [], held: []}
    end
  end

  describe "grew/2" do
    test "one more copy of a key than base is that key once" do
      assert Baseline.grew(~w(a a b), ~w(a b)) == ~w(a)
    end

    test "a key the working file dropped is not growth" do
      assert Baseline.grew(~w(a), ~w(a b)) == []
    end

    test "a new key is growth" do
      assert Baseline.grew(~w(a c), ~w(a)) == ~w(c)
    end
  end

  describe "foreign/2" do
    test "entries not starting with the rule id and | are foreign" do
      assert Baseline.foreign("web", ["web|A|x", "webx|A|x", "other|B|y"]) ==
               ["webx|A|x", "other|B|y"]

      assert Baseline.foreign("web", ["web|A|x"]) == []
    end
  end

  describe "render/2" do
    test "header comment, keys sorted, trailing newline; parse round-trips to the sorted keys" do
      rendered = Baseline.render("r", ~w(r|b r|a r|b))
      assert rendered == "# anchor baseline for r; shrink only\nr|a\nr|b\nr|b\n"
      assert Baseline.parse(rendered) == {:ok, ~w(r|a r|b r|b)}
    end
  end

  describe "valid_ref?/1" do
    test "branch, tag, sha, remote and relative refs are valid" do
      for ref <- ~w(main origin/main v1.2.3 HEAD~2 HEAD^ abc123 feature/x_y-z) do
        assert Baseline.valid_ref?(ref), ref
      end
    end

    test "an option, a shell metacharacter, a space, empty or a non-string is refused" do
      for ref <- ["-x", "--output=/tmp/x", "main; rm -rf /", "a b", "a$b", "a:b", "", nil, 1] do
        refute Baseline.valid_ref?(ref), inspect(ref)
      end
    end
  end
end
