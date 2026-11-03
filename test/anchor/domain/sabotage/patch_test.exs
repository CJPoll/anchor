defmodule Anchor.Domain.Sabotage.PatchTest do
  # DND-5471: splicing a replacement over a range, and the one-hunk unified
  # diff each mutant carries.
  # Sabotage record: ../../../sabotage_records/sabotage-20261103-dnd_5471.md
  use ExUnit.Case, async: true

  alias Anchor.Domain.Sabotage.Patch

  @ten Enum.map_join(1..10, &"line #{&1}\n")

  describe "apply_range/3" do
    test "1: a range inside one line changes only that span" do
      source = "one\ntwo\nthree x four\nfive\nsix\n"

      assert Patch.apply_range(source, {{3, 7}, {3, 8}}, "y") ==
               "one\ntwo\nthree y four\nfive\nsix\n"

      assert Patch.slice(source, {{3, 7}, {3, 8}}) == "x"
    end

    test "2: whole lines 2-4 removed, the trailing newline kept" do
      source = "a\nb\nc\nd\ne\n"

      assert Patch.apply_range(source, {{2, 1}, {5, 1}}, "") == "a\ne\n"
    end

    test "columns count codepoints, not bytes" do
      source = "é = 1\nx\n"

      assert Patch.slice(source, {{1, 1}, {1, 2}}) == "é"
      assert Patch.apply_range(source, {{1, 5}, {1, 6}}, "2") == "é = 2\nx\n"
    end

    test "a range that ends before it starts is refused" do
      assert_raise ArgumentError, fn -> Patch.apply_range("abc", {{1, 3}, {1, 1}}, "") end
    end
  end

  describe "unified_diff/3" do
    test "1: one changed line in ten: 3 lines of context each side (pinned text)" do
      after_text = String.replace(@ten, "line 5\n", "LINE 5\n")

      assert Patch.unified_diff("lib/m.ex", @ten, after_text) == """
             --- a/lib/m.ex
             +++ b/lib/m.ex
             @@ -2,7 +2,7 @@
              line 2
              line 3
              line 4
             -line 5
             +LINE 5
              line 6
              line 7
              line 8
             """
    end

    test "2: a change on line 1 starts the hunk at 1, with no context before it" do
      after_text = String.replace(@ten, "line 1\n", "LINE 1\n", global: false)

      assert Patch.unified_diff("m.ex", @ten, after_text) == """
             --- a/m.ex
             +++ b/m.ex
             @@ -1,4 +1,4 @@
             -line 1
             +LINE 1
              line 2
              line 3
              line 4
             """
    end

    test "3: deleting lines 4-5: two `-` lines" do
      after_text = String.replace(@ten, "line 4\nline 5\n", "")

      assert Patch.unified_diff("m.ex", @ten, after_text) == """
             --- a/m.ex
             +++ b/m.ex
             @@ -1,8 +1,6 @@
              line 1
              line 2
              line 3
             -line 4
             -line 5
              line 6
              line 7
              line 8
             """
    end

    test "a last line with no newline is marked" do
      assert Patch.unified_diff("m.ex", "a\nb", "a\nc") == """
             --- a/m.ex
             +++ b/m.ex
             @@ -1,2 +1,2 @@
              a
             -b
             \\ No newline at end of file
             +c
             \\ No newline at end of file
             """
    end

    test "equal texts give no diff" do
      assert Patch.unified_diff("m.ex", @ten, @ten) == ""
    end
  end
end
