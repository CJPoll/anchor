defmodule Anchor.Domain.Sabotage.ScopeFailuresTest do
  # Domain (DND-5472): the text `mix anchor.sabotage scope` prints when it
  # could not measure. Each starts COULD NOT MEASURE, names what failed, and
  # ends with a Fix: line.
  # Sabotage record: ../../../sabotage_records/sabotage_scope-20261103-dnd_5472.md
  use ExUnit.Case, async: true

  alias Anchor.Domain.Failures

  @rows [
    {{:unparseable_base, "lib/a.ex", "abc", 4, "syntax error"},
     "COULD NOT MEASURE: lib/a.ex:4 at the merge-base abc does not parse (syntax error). " <>
       "Fix: pass a --base whose copy of lib/a.ex parses; its removed lines cannot be mapped to " <>
       "functions otherwise."},
    {{:unparseable_diff, {:truncated_hunk, "lib/a.ex"}},
     "COULD NOT MEASURE: git printed a diff Anchor cannot read ({:truncated_hunk, \"lib/a.ex\"}). " <>
       "Fix: check git's diff config (an external diff driver or textconv), or report it to Anchor."},
    {{:git_failed, ["ls-files"], 128, ""},
     "COULD NOT MEASURE: `git ls-files` exited 128: (git's message is printed above, on stderr). " <>
       "Fix: run the command by hand to see why."},
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

    test "an unknown reason is still reported, with Fix:" do
      assert Failures.scope_could_not_measure({:something, :new}) ==
               "COULD NOT MEASURE: {:something, :new}. " <>
                 "Fix: this is a defect in Anchor; report it with this text."
    end
  end
end
