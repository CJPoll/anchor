defmodule Anchor.Domain.Sabotage.ScopeFailuresTest do
  # Domain (DND-5472): the text `mix anchor.sabotage scope` prints when it
  # could not measure. Each starts COULD NOT MEASURE, names what failed, and
  # ends with a Fix: line.
  # Sabotage record: test/sabotage_records/sabotage_scope-20261103-dnd_5472.md
  use ExUnit.Case, async: true

  alias Anchor.Domain.Failures

  @rows [
    {{:not_a_work_tree, "/r"},
     "COULD NOT MEASURE: /r is not a git work tree. Fix: run from the repository checkout."},
    {{:no_merge_base, "origin/x"},
     "COULD NOT MEASURE: no merge-base with origin/x. Fix: fetch it (git fetch origin) or pass --base <ref>."},
    {{:git_failed, ["diff", "abc"], 128, "fatal: bad\n"},
     "COULD NOT MEASURE: `git diff abc` exited 128: fatal: bad. Fix: run the command by hand to see why."},
    {{:unparseable, "lib/a.ex", 3, "syntax error"},
     "COULD NOT MEASURE: lib/a.ex:3 does not parse (syntax error). " <>
       "Fix: make it compile; a file that does not parse cannot be scoped."},
    {{:unreadable, "lib/a.ex", :eacces},
     "COULD NOT MEASURE: could not read lib/a.ex (:eacces). Fix: make lib/a.ex a readable file."}
  ]

  describe "scope_could_not_measure/1" do
    test "each known reason has its exact text" do
      for {reason, text} <- @rows do
        assert Failures.scope_could_not_measure(reason) == text
      end
    end

    test "a diff Anchor cannot read and an unknown reason are still reported, with Fix:" do
      for reason <- [{:unparseable_diff, {:truncated_hunk, "lib/a.ex"}}, {:something, :new}] do
        text = Failures.scope_could_not_measure(reason)
        assert String.starts_with?(text, "COULD NOT MEASURE: ")
        assert String.contains?(text, "Fix: ")
      end
    end
  end
end
