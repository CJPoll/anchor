defmodule Anchor.Domain.ConfigPathsTest do
  # Pure candidate-path computation. No IO: `candidates/2` takes cwd + an
  # `apps?` boolean, so no real project tree is needed.
  #
  # Sabotage record: ../../sabotage_records/config-20260913-dnd_123_t3_config_split.md
  use ExUnit.Case, async: true

  alias Anchor.Domain.ConfigPaths

  describe "candidates/2 (test-matrix: config.ex -> config_paths/0)" do
    # Row 1
    test "non-umbrella project yields only the cwd candidate" do
      assert ConfigPaths.candidates("/proj", false) == ["/proj/.anchor.yml"]
    end

    # Row 2
    test "umbrella root yields cwd candidate first, then two-levels-up, de-duplicated" do
      assert ConfigPaths.candidates("/proj", true) == [
               "/proj/.anchor.yml",
               "/.anchor.yml"
             ]
    end

    # Row 3 (BUG 5)
    test "run from inside an umbrella app dir finds the umbrella root" do
      candidates = ConfigPaths.candidates("/proj/apps/my_app", false)

      assert "/proj/.anchor.yml" in candidates
      # And the app-local config remains the first candidate.
      assert hd(candidates) == "/proj/apps/my_app/.anchor.yml"
    end

    # Row 4
    test "candidate list has no duplicates when root and computed paths coincide" do
      # From "/", both the cwd candidate and the two-levels-up candidate resolve
      # to "/.anchor.yml", so the list collapses to a single entry.
      assert ConfigPaths.candidates("/", true) == ["/.anchor.yml"]
    end

    # DND-1265 miss case: a relative cwd would be expanded against whatever the
    # process cwd happens to be, so the lookup would search the wrong place and
    # report "not found" for the wrong path. The malformed key is rejected
    # where it is produced.
    # Sabotage record: ../../sabotage_records/config-20260929-dnd_1265_anchor_fail_closed.md
    test "a relative cwd is rejected, not expanded against the process cwd" do
      assert_raise ArgumentError, ~r/absolute/, fn -> ConfigPaths.candidates("proj", false) end
      assert_raise ArgumentError, ~r/absolute/, fn -> ConfigPaths.candidates("", false) end
    end
  end
end
