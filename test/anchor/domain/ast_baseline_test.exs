defmodule Anchor.Domain.AstBaselineTest do
  # DND-5632: an ast (Credo-engine) rule's baseline ratchet. Pure Domain: the
  # key of a finding, the file an entry names, and the comparison judged only
  # over the files the run read.
  #
  # Sabotage record: ../../sabotage_records/baseline-20261103-dnd_5648_graph_followups.md
  use ExUnit.Case, async: true

  alias Anchor.Domain.AstBaseline
  alias Anchor.Domain.Violation
  alias Anchor.Domain.ViolationKey

  @rule %{type: :no_direct_dependency, id: "pure"}

  defp whole(read, unparsed \\ []),
    do: %{whole?: true, read: MapSet.new(read), unparsed: MapSet.new(unparsed)}

  defp narrowed(read), do: %{whole?: false, read: MapSet.new(read), unparsed: MapSet.new()}

  describe "ViolationKey.ast_key/3" do
    test "<id>|<file>|<trigger>; no line, no message" do
      assert ViolationKey.ast_key(@rule, "lib/a.ex", "File") == "pure|lib/a.ex|File"
    end

    test "a nil trigger is an empty segment" do
      assert ViolationKey.ast_key(@rule, "lib/a.ex", nil) == "pure|lib/a.ex|"
    end

    test "a trigger holding | stays whole in the last segment" do
      key = ViolationKey.ast_key(@rule, "lib/a.ex", "|>")
      assert key == "pure|lib/a.ex||>"
      assert AstBaseline.entry_file("pure", key) == "lib/a.ex"
    end

    test "a file holding | or a newline raises" do
      assert_raise ArgumentError, ~r/\|/, fn -> ViolationKey.ast_key(@rule, "lib/a|b.ex", "x") end

      assert_raise ArgumentError, ~r/newline/, fn ->
        ViolationKey.ast_key(@rule, "lib/a.ex", "x\n")
      end
    end
  end

  describe "entry_file/2" do
    test "the file segment after the rule's id" do
      assert AstBaseline.entry_file("pure", "pure|lib/a.ex|File") == "lib/a.ex"
    end

    test "an id holding | is stripped as a prefix, never split" do
      assert AstBaseline.entry_file("a|b", "a|b|lib/a.ex|File") == "lib/a.ex"
    end

    test "an entry with no file segment names none" do
      assert AstBaseline.entry_file("pure", "pure|") == nil
      assert AstBaseline.entry_file("pure", "pure") == nil
    end
  end

  describe "judge/4" do
    test "positive control: every finding held, nothing stale or unjudged" do
      keys = ~w(pure|lib/a.ex|File pure|lib/b.ex|System)

      assert AstBaseline.judge("pure", keys, keys, whole(~w(lib/a.ex lib/b.ex))) ==
               %{new: [], held: keys, stale: [], unjudged: []}
    end

    test "NEW: a finding no entry covers" do
      assert %{new: ["pure|lib/a.ex|IO"], held: ["pure|lib/a.ex|File"]} =
               AstBaseline.judge(
                 "pure",
                 ~w(pure|lib/a.ex|File pure|lib/a.ex|IO),
                 ~w(pure|lib/a.ex|File),
                 whole(~w(lib/a.ex))
               )
    end

    test "STALE: an entry no finding consumes, on a file the run read" do
      assert %{stale: ["pure|lib/a.ex|IO"], unjudged: []} =
               AstBaseline.judge(
                 "pure",
                 ~w(pure|lib/a.ex|File),
                 ~w(pure|lib/a.ex|File pure|lib/a.ex|IO),
                 whole(~w(lib/a.ex))
               )
    end

    test "STALE in a whole run: an entry on a file that no longer exists" do
      assert %{stale: ["pure|lib/gone.ex|File"], unjudged: []} =
               AstBaseline.judge("pure", [], ~w(pure|lib/gone.ex|File), whole(~w(lib/a.ex)))
    end

    test "a narrowed run judges no entry on a file it did not read: no false STALE" do
      entries = ~w(pure|lib/a.ex|File pure|lib/b.ex|File pure|lib/b.ex|IO)

      assert AstBaseline.judge("pure", ~w(pure|lib/a.ex|File), entries, narrowed(~w(lib/a.ex))) ==
               %{
                 new: [],
                 held: ~w(pure|lib/a.ex|File),
                 stale: [],
                 unjudged: ~w(pure|lib/b.ex|File pure|lib/b.ex|IO)
               }
    end

    test "a narrowed run still finds STALE on a file it read" do
      assert %{stale: ["pure|lib/a.ex|IO"], unjudged: ["pure|lib/b.ex|File"]} =
               AstBaseline.judge(
                 "pure",
                 [],
                 ~w(pure|lib/a.ex|IO pure|lib/b.ex|File),
                 narrowed(~w(lib/a.ex))
               )
    end

    test "an entry on a file the run could not parse is unjudged, never STALE" do
      assert %{stale: [], unjudged: ["pure|lib/broken.ex|File"]} =
               AstBaseline.judge(
                 "pure",
                 [],
                 ~w(pure|lib/broken.ex|File),
                 whole(~w(lib/a.ex lib/broken.ex), ~w(lib/broken.ex))
               )
    end

    test "duplicates are a multiset: two findings, one entry, one NEW" do
      assert %{new: ["pure|lib/a.ex|File"], held: ["pure|lib/a.ex|File"]} =
               AstBaseline.judge(
                 "pure",
                 ~w(pure|lib/a.ex|File pure|lib/a.ex|File),
                 ~w(pure|lib/a.ex|File),
                 whole(~w(lib/a.ex))
               )
    end
  end

  describe "exit_code/1 and render/1 (mix anchor.baseline)" do
    test "an enforced violation is 1; report-only notes alone are 0" do
      note = %Violation{filename: "b.txt", message: "NOTE: x", enforcement: :report}
      grew = %Violation{filename: "b.txt", message: "pure|lib/a.ex|File was added"}
      closed = %Violation{filename: "b.txt", message: "unreadable", kind: :fail_closed}

      assert AstBaseline.exit_code([]) == 0
      assert AstBaseline.exit_code([note]) == 0
      assert AstBaseline.exit_code([note, grew]) == 1
      assert AstBaseline.exit_code([closed]) == 1
    end

    test "one line per violation and a summary counting the enforced and report-only" do
      note = %Violation{filename: "b.txt", message: "NOTE: x", enforcement: :report}
      grew = %Violation{filename: "b.txt", line: 3, message: "grew"}

      assert AstBaseline.render([grew, note], 2) ==
               "b.txt:3: [enforce] grew\n" <>
                 "b.txt: [report] NOTE: x\n" <>
                 "anchor.baseline: 2 ast baselines, 1 violation (1 report-only)"
    end

    test "a clean run prints only the summary" do
      assert AstBaseline.render([], 0) ==
               "anchor.baseline: 0 ast baselines, 0 violations (0 report-only)"
    end
  end
end
