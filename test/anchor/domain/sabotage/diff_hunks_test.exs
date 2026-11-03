defmodule Anchor.Domain.Sabotage.DiffHunksTest do
  # Domain tests for the `git diff --unified=0` parser (DND-5472). Every input is
  # literal diff text in the shape git prints with the adapter's flags
  # (`--src-prefix=a/ --dst-prefix=b/ --no-renames`).
  # Sabotage record: ../../../sabotage_records/sabotage_scope-20261103-dnd_5472.md
  use ExUnit.Case, async: true

  alias Anchor.Domain.Sabotage.DiffHunks

  describe "parse/1" do
    test "H1: one modified file keeps the new-side start and count of its hunk" do
      diff = """
      diff --git a/lib/a.ex b/lib/a.ex
      index 1111111..2222222 100644
      --- a/lib/a.ex
      +++ b/lib/a.ex
      @@ -3,2 +3,4 @@ defmodule A do
      -  old one
      -  old two
      +  new one
      +  new two
      +  new three
      +  new four
      """

      assert DiffHunks.parse(diff) ==
               {:ok, %{"lib/a.ex" => %{status: :modified, hunks: [{3, 4}]}}}
    end

    test "H2: a zero-count hunk (a pure deletion) is kept with count 0" do
      diff = """
      diff --git a/lib/a.ex b/lib/a.ex
      index 1111111..2222222 100644
      --- a/lib/a.ex
      +++ b/lib/a.ex
      @@ -5,2 +4,0 @@ defmodule A do
      -  gone one
      -  gone two
      """

      assert DiffHunks.parse(diff) ==
               {:ok, %{"lib/a.ex" => %{status: :modified, hunks: [{4, 0}]}}}
    end

    test "H3: a hunk header without counts defaults each count to 1" do
      diff = """
      diff --git a/lib/a.ex b/lib/a.ex
      index 1111111..2222222 100644
      --- a/lib/a.ex
      +++ b/lib/a.ex
      @@ -7 +7 @@
      -  x
      +  y
      """

      assert DiffHunks.parse(diff) ==
               {:ok, %{"lib/a.ex" => %{status: :modified, hunks: [{7, 1}]}}}
    end

    test "H4: a file added (--- /dev/null) is :added" do
      diff = """
      diff --git a/lib/new.ex b/lib/new.ex
      new file mode 100644
      index 0000000..3333333
      --- /dev/null
      +++ b/lib/new.ex
      @@ -0,0 +1,2 @@
      +defmodule New do
      +end
      """

      assert DiffHunks.parse(diff) == {:ok, %{"lib/new.ex" => %{status: :added, hunks: [{1, 2}]}}}
    end

    test "H5: a file deleted (+++ /dev/null) is :deleted with no hunks, keyed by its old path" do
      diff = """
      diff --git a/lib/old.ex b/lib/old.ex
      deleted file mode 100644
      index 3333333..0000000
      --- a/lib/old.ex
      +++ /dev/null
      @@ -1,2 +0,0 @@
      -defmodule Old do
      -end
      """

      assert DiffHunks.parse(diff) == {:ok, %{"lib/old.ex" => %{status: :deleted, hunks: []}}}
    end

    test "H6: three files, paths with spaces and quoted paths, all keyed by the b/ path" do
      diff =
        "diff --git a/lib/my file.ex b/lib/my file.ex\n" <>
          "index 1111111..2222222 100644\n" <>
          "--- a/lib/my file.ex\t\n" <>
          "+++ b/lib/my file.ex\t\n" <>
          "@@ -2 +2 @@ a\n" <>
          "-b\n" <>
          "+c\n" <>
          ~S(diff --git "a/lib/q\"\303\251.ex" "b/lib/q\"\303\251.ex") <>
          "\n" <>
          "index 587be6b..975fbec 100644\n" <>
          "--- \"a/lib/q\\\"\\303\\251.ex\"\n" <>
          "+++ \"b/lib/q\\\"\\303\\251.ex\"\n" <>
          "@@ -1 +1 @@\n" <>
          "-x\n" <>
          "+y\n" <>
          "diff --git a/README.md b/README.md\n" <>
          "index 1111111..2222222 100644\n" <>
          "--- a/README.md\n" <>
          "+++ b/README.md\n" <>
          "@@ -1,0 +2,3 @@\n" <>
          "+one\n" <>
          "+two\n" <>
          "+three\n"

      assert DiffHunks.parse(diff) ==
               {:ok,
                %{
                  "lib/my file.ex" => %{status: :modified, hunks: [{2, 1}]},
                  "lib/q\"é.ex" => %{status: :modified, hunks: [{1, 1}]},
                  "README.md" => %{status: :modified, hunks: [{2, 3}]}
                }}
    end

    test "H7: empty text is an empty map" do
      assert DiffHunks.parse("") == {:ok, %{}}
    end

    test "H8: a removed line that reads like a header is body, not a new file" do
      # Under --unified=0 a removed line "-- a/x" prints as "--- a/x": the parser
      # must consume a hunk's body by its counts, never by the line's look.
      diff = """
      diff --git a/lib/a.ex b/lib/a.ex
      index 1111111..2222222 100644
      --- a/lib/a.ex
      +++ b/lib/a.ex
      @@ -3,2 +3,1 @@
      --- a/lib/b.ex
      -+++ b/lib/b.ex
      ++@@ -1 +1 @@
      @@ -9 +8,2 @@
      -x
      +y
      +z
      """

      assert DiffHunks.parse(diff) ==
               {:ok, %{"lib/a.ex" => %{status: :modified, hunks: [{3, 1}, {8, 2}]}}}
    end

    test "H9: a binary or mode-only change has no hunks and is keyed by the header path" do
      diff = """
      diff --git a/lib/mode.ex b/lib/mode.ex
      old mode 100644
      new mode 100755
      diff --git a/priv/logo.png b/priv/logo.png
      new file mode 100644
      index 0000000..1111111
      Binary files /dev/null and b/priv/logo.png differ
      """

      assert DiffHunks.parse(diff) ==
               {:ok,
                %{
                  "lib/mode.ex" => %{status: :modified, hunks: []},
                  "priv/logo.png" => %{status: :added, hunks: []}
                }}
    end

    test "H10: text git would not print is refused, never read as no change" do
      assert {:error, {:unrecognised_diff_line, 1, "warning: something"}} =
               DiffHunks.parse("warning: something\n")

      truncated = """
      diff --git a/lib/a.ex b/lib/a.ex
      index 1111111..2222222 100644
      --- a/lib/a.ex
      +++ b/lib/a.ex
      @@ -3,2 +3,2 @@
      -x
      """

      assert {:error, {:truncated_hunk, "lib/a.ex"}} = DiffHunks.parse(truncated)
    end

    test "H11: a '\\ No newline at end of file' marker inside a hunk is skipped" do
      diff = """
      diff --git a/lib/a.ex b/lib/a.ex
      index 1111111..2222222 100644
      --- a/lib/a.ex
      +++ b/lib/a.ex
      @@ -4 +4 @@
      -end
      \\ No newline at end of file
      +end
      """

      assert DiffHunks.parse(diff) ==
               {:ok, %{"lib/a.ex" => %{status: :modified, hunks: [{4, 1}]}}}
    end
  end
end
