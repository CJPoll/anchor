# Sabotage record — `mix anchor.sabotage scope`: the functions a diff changed (DND-5472)

- **Domain:** sabotage_scope
- **Branch:** dnd-5472
- **Date:** 2026-11-03
- **Code under test:** `Anchor.Domain.Sabotage.DiffHunks`, `Anchor.Domain.Sabotage.FunctionSpans`,
  `Anchor.Domain.Sabotage.Scope`, `Anchor.Domain.Failures.scope_could_not_measure/1`,
  `Anchor.Managers.Sabotage.scope/2`, `Anchor.Adapters.GitChangeSource`, `Mix.Tasks.Anchor.Sabotage`
- **Suite run:** per mutation, the one test file named in its row (`MIX_ENV=test mix test <file>`), each
  mutation applied alone to the committed tree and restored byte-for-byte after its run.

Off-domain mutations in this record: `failures` (row N, `Anchor.Domain.Failures`). One record for the
whole Mission, filed under its primary domain (see the README's "one combined record" note).

## Mutations

| # | Mutation | Test file | Tests that failed | Failure string (verbatim) |
|---|---|---|---|---|
| A | `Scope.map_hunk/4` ignores zero-count hunks (a deletion point maps to nothing, counts nothing) | `scope_test.exs` | S3, S4 | S3: `code:  assert identities(build([{12, 0}])) == [{M, :g, 1, ~c"\r"}]` / `left:  []` / `right: [{M, :g, 1, ~c"\r"}]` |
| B | `Scope.kind/1` drops the `test` path segment rule (only `_test.exs` is a test file) | `scope_test.exs` | S6 | `code:  assert scope.counts == %{@zero \| test_files: 3}` / `left:` `test_files: 1, non_source_files: 2` |
| C | `Scope.add_line/4` keeps the first clause's lines (clause union dropped) | `scope_test.exs` | S2, S9, R1, R2 | S2: `match (=) failed` on `%ChangedFunction{... changed_lines: [4, 8]}` |
| D | `FunctionSpans.last_line/2` uses the def's own `line` when there is no `end` (keyword-def end from `line` only) | `function_spans_test.exs` | P3 | `left:  [{M, :f, 1, :def, 2..2, false}, {M, :g, 0, :def, 8..8, false}]` / `right: [{M, :f, 1, :def, 2..6, false}, {M, :g, 0, :def, 8..8, false}]` |
| E | `Managers.Sabotage` reads a merge-base error as an empty diff (`{:ok, ""}`) | `sabotage_scope_test.exs` | M3 | `** (Mox.UnexpectedCallError) no expectation defined for Anchor.ChangeSourceMock.diff/2 in process #PID<0.240.0> with args ["/repo", ""]` |
| F | `DiffHunks.step/2` leaves a hunk body on a line that looks like a `---`/`+++`/`@@` header | `diff_hunks_test.exs` | H8 | `left:  {:error, {:unrecognised_diff_line, 7, "-+++ b/lib/b.ex"}}` / `right: {:ok, %{"lib/a.ex" => %{status: :modified, hunks: [{3, 1}, {8, 2}]}}}` |
| G | `FunctionSpans.walk/3` does not mark defs inside `quote` | `function_spans_test.exs` | P8 | `left:` `{M, :generated, 1, :def, 4..4, false}` where `right:` has `true` |
| H | `defimpl` without `for:` names the protocol alone, not `Protocol.<enclosing module>` | `function_spans_test.exs` | P7 | `left:` `{Inspect, :inspect, 2, :def, 9..9, false}` / `right:` `{Inspect.B, :inspect, 2, :def, 9..9, false}` |
| I | `GitChangeSource.untracked/1` drops the `*.ex` pathspec | `git_change_source_test.exs` | G2 | `left:  {:ok, ["lib/new.ex", "notes.txt"]}` / `right: {:ok, ["lib/new.ex"]}` |
| J | `GitChangeSource.resolve/2` drops `--end-of-options` | `git_change_source_test.exs` | **none (measured zero)** | — |
| K | the task prints COULD NOT MEASURE but does not `exit({:shutdown, 3})` | `anchor_sabotage_scope_test.exs` | F3 | `Expected to catch exit, got nothing` |
| L | `DiffHunks` ignores `+++ /dev/null` | `diff_hunks_test.exs` | **none (measured zero)** | — |
| L2 | `DiffHunks` ignores both `+++ /dev/null` and `deleted file mode` | `diff_hunks_test.exs` | H5 | `left:  {:ok, %{"lib/old.ex" => %{status: :modified, hunks: [{0, 0}]}}}` / `right: {:ok, %{"lib/old.ex" => %{status: :deleted, hunks: []}}}` |
| M | an added file maps no lines (its one all-lines hunk dropped) | `scope_test.exs` | S9 | `left:  []` / `right: [f: 1, g: 1, h: 1]` |
| N | the no-merge-base `Fix:` text changed | `scope_failures_test.exs` | each known reason has its exact text | `left:  "COULD NOT MEASURE: no merge-base with origin/x. Fix: try again."` |
| O | a line in no span no longer counts the hunk as outside a function | `scope_test.exs` | S4, S5, S9, S12, R1, R2 | R1: `left:` `... 0 hunks outside a function, 0 macros"` / `right:` `... 1 hunks outside a function, 0 macros"` |
| P | `GitChangeSource.diff/2` drops `--src-prefix=a/ --dst-prefix=b/` | `git_change_source_test.exs` | G1b | `left:  "diff --git lib/a.ex lib/a.ex\nindex 2576990..6e9d2da 100644\n--- lib/a.ex\n+++ lib/a.ex\n@@ -2 +2 @@ defmodule A do\n-  def f, do: 1\n+  def f, do: 3\n"` |

## Measured zeros, and why

- **J (`--end-of-options`).** No test reddens. The ref is passed as `<ref>^{commit}`, so an option-shaped
  `--base` (`--output=x`) is mangled into an argument rev-parse rejects with or without the separator; G3
  asserts the observable property (no merge-base, no file `x` written), which holds either way. The flag
  is defence in depth, kept because a future rev-parse option could accept the suffix.
- **L (`+++ /dev/null` alone).** No test reddens because git prints `deleted file mode` for every deleted
  file, and that line alone marks the file deleted. L2 removes both signals and H5 fails: the redundancy is
  real, and at least one signal is protected.

## Traps

- D and L2 first failed to compile, not to test: removing the only call of `max_line/2` or `deleted/1`
  is an unused-function warning under `warnings_as_errors`. Each mutation was re-applied keeping a
  reference (`_ = {node, &max_line/2}`, `_ = {dev_null?(side), &deleted/1}`) before the rows above were
  taken.
