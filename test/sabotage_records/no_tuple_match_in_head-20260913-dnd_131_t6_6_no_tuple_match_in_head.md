# Sabotage record — NoTupleMatchInHead rewritten to AST detection in Domain

- **Domain:** no_tuple_match_in_head
- **Branch:** dnd-131-t6-6-no-tuple-match-in-head
- **Date:** 2026-09-13
- **MR:** T6.6 (DND-131)
- **Code under test:** `Anchor.Domain.Checks.NoTupleMatchInHead.detect_violations/2`
  (the pure, AST-based Domain detector; the `Anchor.Check.NoTupleMatchInHead`
  shell delegates to it via `check_file/3`)
- **Suite run:**
  `mix test --seed 0 test/anchor/check/no_tuple_match_in_head_test.exs test/anchor/domain/checks/no_tuple_match_in_head_test.exs`
  (24 tests: the 15-row `check_file/3` acceptance matrix + 9 pure-Domain rows)

T6.6 (DND-131) replaced the previous regex-on-source implementation of the
`no_tuple_match_in_head` check with AST-based detection extracted into the pure
`Anchor.Domain.Checks.NoTupleMatchInHead` module. Line numbers now come from AST
metadata, not from re-scanning the source string. Each mutation below was applied
to that Domain module, the suite re-run, the code restored. Failure strings are
verbatim, including `left:` / `right:`.

| # | Mutation | Tests failed | Failure string (verbatim) |
|---|---|---|---|
| A | Drop **reversed** match-assignment support: `flaggable_arg?({:=, _, [lhs, rhs]})` checks only `result_tuple?(lhs)` instead of `... or result_tuple?(rhs)` | 3 (reversed-assign rows: 1 Domain + shell #5 + shell #15) | `code: assert [issue] = issues(source)` `left: [issue]` `right: []` (shell #5, "reversed match-assignment whose right operand is an :ok tuple"); Domain row: `code: assert [%Violation{trigger: "process"}] = violations` `left: [%Anchor.Domain.Violation{trigger: "process"}]` `right: []` |
| B | Drop **forward** match-assignment support: `flaggable_arg?({:=, _, [_lhs, rhs]})` checks only `result_tuple?(rhs)` | 2 (forward-assign: 1 Domain + shell #4) | shell #4: `code: assert [issue] = issues(source)` `left: [issue]` `right: []`; Domain: `code: assert [%Violation{trigger: "process"}] = violations` `left: [%Anchor.Domain.Violation{trigger: "process"}]` `right: []` |
| C | Drop `:error` from the recognised tags (`@tuple_tags [:ok, :error]` → `[:ok]`) | 8 (every `:error` row: shell #2, #3, part of #8, #15, and the absence rows whose positive control is an `:error` tuple: #10, #13; Domain multi-clause + private) | shell #2: `code: assert [issue] = issues(source)` `left: [issue]` `right: []`; Domain multi-clause: `code: assert length(violations) == 3` `left: 1` `right: 3` |
| D | Drop `:ok` from the recognised tags (`@tuple_tags [:ok, :error]` → `[:error]`) | 17 (every `:ok` row plus every absence row whose positive control is an `:ok` tuple) | `code: assert [%Violation{} = violation] = violations` `left: [%Anchor.Domain.Violation{} = violation]` `right: []` (Domain #1 :ok head) |
| E | Null the trigger (`trigger: function_name` → `trigger: nil`) | 23 (all but the one Domain absence row) | Domain #1: `code: assert violation.trigger == "process"` `left: nil` `right: "process"`; Domain private: `code: assert violation.trigger == "handle"` `left: nil` `right: "handle"` |
| F | Emit `"public function head"` for private defs too (`else: "private"` → `else: "public"`) | 2 (private-head rows: Domain + shell #6) | `code: assert issue.message =~ "private function head"` `left: "Function \`handle\` pattern matches on :ok/:error tuple in its public function head. Consider having the calling function use a case statement on the value instead."` `right: "private function head"` |
| G | Report `def` line + 1 (`Keyword.get(meta, :line)` → `(Keyword.get(meta, :line) + 1)`, all four clause extractions) | 2 (the two line assertions: Domain #1 + shell #1) | `code: assert issue.line_no == 2` `left: 3` `right: 2` (shell #1); `code: assert violation.line == 2` `left: 3` `right: 2` (Domain #1) |
| H | Flag tuples nested in a list/map (replace the two `result_tuple?/1` structural clauses with a `Macro.prewalk` that reports any `:ok`/`:error` tuple **anywhere** in the argument subtree) | 5 (the nesting-allowed rows: shell #10 list, #11 map, #14 mixed → 2 issues; Domain sibling-nested control, Domain nested/plain absence) | shell #10/#11 flip from `[issue]` to a two-element list (the second issue is the nested `control`/`handle` tuple); shell #14: `code: assert [issue] = issues(source)` `left: [issue]` `right: [%Credo.Issue{... trigger: "f" ...}, %Credo.Issue{... trigger: "f" ...}]` (the nested `{:error, e}` in `%{r: ...}` now produces a second issue) |

## What each mutation proves

- **A / B** protect the two directions of the adjudicated match-assignment
  contract independently. `{:ok, _} = result` (lhs tuple) and
  `result = {:ok, data}` (rhs tuple) are distinct AST operand orders; A proves
  the RHS operand is really inspected (dropping it reddens only the reversed
  rows, matrix #5/#15), B proves the LHS operand is really inspected (dropping
  it reddens only the forward rows, matrix #4). Neither mutation touches the
  other direction, so each is a tight, single-direction proof.
- **C / D** protect tag recognition per tag. Dropping `:error` leaves `:ok`
  rows green and vice-versa; the asymmetric failure counts (8 vs 17) fall out of
  which rows and which positive controls use which tag. The multi-clause row
  (#8) degrades from 3 issues to 1 under C — a precise `length == 3` → `1`
  proof that both `:error` clauses were being counted.
- **E** protects the trigger field on every flagged row: Credo's
  `format_issue/2` normalises a `nil` trigger, but the pure `%Violation{}`
  carries the raw `nil`, so the Domain rows fail on `left: nil right: "process"`.
- **F** protects the public/private distinction in the message string
  (matrix #1 vs #6). Only the private-head rows go red, and on exactly the
  `=~ "private function head"` assertion.
- **G** protects the line number, which is the crux of the regex → AST rewrite:
  the line must come from `def`-clause AST metadata. Off-by-one reddens exactly
  the two rows that pin `line == 2`.
- **H** is the nesting-allowed proof and the positive-control proof rolled into
  one. It is the inverse of the real contract: it flags tuples nested inside a
  list (#10) or map (#11) sub-pattern, and it makes the mixed head (#14) report
  the nested `{:error, e}` as a *second* issue. The absence rows (#9–#13) and
  their positive controls are what catch it — proving those rows assert real
  absence, not a dead checker.

## Traps encountered (ADR 002 catalogue)

- **`--warnings-as-errors` unused-binding trap.** Every operand-dropping
  mutation (A, B) was written to rename the discarded operand to `_lhs` / `_rhs`
  rather than leaving it bound-but-unused; a bare `[lhs, rhs]` with only one side
  referenced fails this project's `--warnings-as-errors` compile ("variable is
  unused"), which stops the suite compiling and proves nothing. Likewise F was
  chosen as a string swap (`"private"` → `"public"`) rather than hard-coding
  `visibility_text = "public"`, which would have orphaned the `visibility`
  parameter and again failed to compile.
- **Async-suite label interleaving.** A first pass ran the two `async: true`
  suites together and collected failure lines by scanning combined stdout, which
  interleaved and mislabelled mutation B's failures as A's. Every row above was
  re-measured with `--seed 0` and each mutation captured to its own file
  (`/tmp/sab_<key>.txt`) before the strings were transcribed. Treat a compact
  cross-mutation summary as suspect until the per-mutation block is read.

## Measured zeros

None. Every mutation reddened at least one row, and every asserted property of
the 15-row acceptance matrix — direct `:ok` tuple, direct `:error` tuple,
3-element tuple, forward `=` operand, reversed `=` operand, public vs private
message, function-name trigger, `def`-line number, and the three
nesting-allowed / plain-arg / body-case absences with their positive controls —
is protected by at least one mutation above.
