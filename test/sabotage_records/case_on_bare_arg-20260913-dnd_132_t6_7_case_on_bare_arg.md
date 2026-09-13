# Sabotage record — CaseOnBareArg detection extracted to Domain

- **Domain:** case_on_bare_arg
- **Branch:** dnd-132-t6-7-case-on-bare-arg
- **Date:** 2026-09-13
- **Code under test:** `Anchor.Domain.Checks.CaseOnBareArg.detect_violations/1` (the pure Domain detector; the `Anchor.Check.CaseOnBareArg` shell delegates to it)
- **Suite run:** `mix test test/anchor/check/case_on_bare_arg_test.exs`

T6.7 (DND-132) extracted the detection out of the `Anchor.Check.CaseOnBareArg`
Framework shell into the pure `Anchor.Domain.Checks.CaseOnBareArg` module,
mirroring T6.1's `Anchor.Domain.Checks.NoDependency` shape, and fixed a bug
along the way: a defaulted (`\\`) bare argument was not previously recognized
as bare and so escaped detection (matrix row 4). Each mutation below was
applied to the Domain module, the suite re-run, the code restored. Failure
strings are verbatim, including `left:` / `right:`.

| # | Mutation | Tests failed | Failure string |
|---|---|---|---|
| A | Remove the defaulted-argument clause from `extract_arg_names/1` (delete the `{:\\, _, [{name, _, nil} \| _default]}` match, leaving only the plain-var clause) | 1 (row 4) | `match (=) failed` `code: assert [issue] = issues(source)` `left: [issue]` `right: []` |
| B | Null the trigger (`trigger: "case"` → `trigger: nil`) | 3 (rows 1, 3, 4) | row 1/3/4 each: `code: assert issue.trigger == "case"` `left: ""` `right: "case"` |
| C | Invert the scrutinee-membership check (`if arg_name in arg_names do` → `if arg_name not in arg_names do`) | 6 (rows 1, 3, 4, 5, 6, 7) | row 5 (positive control) **wrongly flags**: `code: assert issues(source) == []` `left: [%Credo.Issue{... message: "Case statement operates on bare argument \`b\` in function \`process\`. Consider using function head pattern matching instead.", line_no: 5, trigger: "case", ...}]` `right: []`; rows 1/3/4/6/7 lose their expected flag, e.g. row 1: `match (=) failed` `left: [issue]` `right: []`; row 7: `code: assert length(issues) == 2` `left: 0` `right: 2` |
| D | Drop the word "bare" from the message (`"Case statement operates on bare argument"` → `"Case statement operates on argument"`) | 2 (rows 1, 4) | row 1: `code: assert issue.message == "Case statement operates on bare argument \`status\` in function \`process\`. Consider using function head pattern matching instead."` `left: "Case statement operates on argument \`status\` in function \`process\`. Consider using function head pattern matching instead."` `right: "Case statement operates on bare argument \`status\` in function \`process\`. Consider using function head pattern matching instead."`; row 4: `code: assert issue.message =~ "bare argument \`status\`"` `left: "Case statement operates on argument \`status\` in function \`process\`. Consider using function head pattern matching instead."` `right: "bare argument \`status\`"` |

## Notes on what each mutation proves

- **A** is the T6.7 behaviour fix itself (matrix row 4): a defaulted argument
  (`def process(status \\ :ok)`) is still a bare argument and must be flagged.
  Removing the defaulting clause from `extract_arg_names/1` reverts to the
  pre-extraction bug, and row 4 goes red exactly, and only, on that row.
- **B** protects the visible `trigger` field. Nulling it surfaces as `""` in
  the built `Credo.Issue` (Credo's `format_issue/2` normalizes a `nil` trigger
  to the empty string), reddening every row that asserts `trigger == "case"`
  (rows 1, 3, 4) without touching rows that only assert presence/absence or
  message content.
- **C** is the strongest positive-control proof in this record: inverting the
  membership check both *removes* every true positive (rows 1, 3, 4, 6, 7) and
  *fabricates* a false positive on row 5 — the row that exists precisely to
  prove a `case` on a plain local variable (`b`, bound from `f(a)`, not itself
  an argument) is left alone. The fabricated issue names `b` as a "bare
  argument" it never was, which is exactly the failure mode row 5 is written
  to catch.
- **D** protects the message text specifically for the defaulted-arg row (4)
  as well as the primary happy path (row 1) — row 4's assertion is a `=~`
  substring check on the "bare argument" phrase, independent of row 1's exact
  match, so this mutation demonstrates that phrase is asserted by more than
  one row.

## Trap encountered (ADR 002 catalogue)

None. All four mutations compiled and ran cleanly under
`--warnings-as-errors`; no bindings were left unused (the membership-check
inversion in C reuses `arg_name`/`arg_names` as-is, and the message-text edit
in D is a pure string literal change).

## Measured zeros

None. Every mutation reddened at least one row; each of the eight matrix
rows' asserted properties (message text, trigger, line numbers, and
presence/absence for both happy-path and positive-control rows) is protected
by at least one mutation above. Rows 2 and 8 (both "no flag" positive
controls on shapes that never reach the `{arg_name, _, nil}` scrutinee
pattern — a call expression and no `case` at all, respectively) are covered
transitively: any mutation that broadened detection (C) would also have
caught a regression there, and none did, confirming those shapes are outside
the detector's match clauses entirely rather than merely passing by
coincidence.
