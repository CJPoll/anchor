defmodule Anchor.Domain.Sabotage.TestRunRefusalTest do
  # A test run that could not start, as run and replay both end on it.
  # Sabotage record: ../../../sabotage_records/sabotage-20261103-dnd_5483_survivors_replay.md
  use ExUnit.Case, async: true

  alias Anchor.Domain.Sabotage.TestRunRefusal

  describe "code/1 and message/1" do
    test "a missing timeout binary is exit 2, a tool to install" do
      assert TestRunRefusal.code(:timeout_not_found) == 2

      assert TestRunRefusal.message(:timeout_not_found) ==
               "the `timeout` binary was not found, so a test run could not be bounded. " <>
                 "Fix: install coreutils timeout"
    end

    test "a results file not removed is exit 3, naming the file and the posix" do
      reason = {:results_not_removed, "_build/r.bin", :eisdir}

      assert TestRunRefusal.code(reason) == 3

      assert TestRunRefusal.message(reason) ==
               "COULD NOT MEASURE: the previous results file _build/r.bin could not be " <>
                 "removed (:eisdir), so a test run's failures could be an earlier run's. " <>
                 "Fix: remove _build/r.bin by hand"
    end

    test "a results directory not made is exit 3, naming the directory and the posix" do
      reason = {:results_dir_not_created, "_build/d", :eacces}

      assert TestRunRefusal.code(reason) == 3

      assert TestRunRefusal.message(reason) ==
               "COULD NOT MEASURE: the results directory _build/d could not be made " <>
                 "(:eacces), so no test run's failures can be read. Fix: make _build/d " <>
                 "(or its parent) a writable directory"
    end
  end
end
