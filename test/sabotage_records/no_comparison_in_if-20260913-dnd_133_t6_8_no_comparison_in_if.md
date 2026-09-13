# Sabotage record — NoComparisonInIf detection extracted to Domain (unless in scope)

- **Domain:** no_comparison_in_if
- **Branch:** dnd-133-t6-8-no-comparison-in-if
- **Date:** 2026-09-13
- **Code under test:** `Anchor.Domain.Checks.NoComparisonInIf.detect_violations/2` (the pure Domain detector; the `Anchor.Check.NoComparisonInIf` shell delegates to it)
- **Suite run:** `mix test test/anchor/check/no_comparison_in_if_test.exs`

T6.8 (DND-133) extracted the detection out of the `Anchor.Check.NoComparisonInIf`
Framework shell into the pure `Anchor.Domain.Checks.NoComparisonInIf` module,
and per the adjudicated fix brought `unless` into scope alongside `if`: an
`unless` whose condition contains a comparison is now flagged with trigger
`"unless"` (matrix row #7), while a comparison-free `unless` stays clean (row
#11). Each mutation below was applied to the Domain module, the suite re-run,
the code restored. Failure strings are verbatim.

| # | Mutation | Tests failed | Failure string |
|---|---|---|---|
| A | Hardcode the trigger to `"if"` regardless of which keyword matched (`trigger = Atom.to_string(keyword)` → `trigger = if keyword == :unless, do: "if", else: "if"`, kept `keyword` referenced to dodge an unused-variable warning) | 1 (row 7) | `code: assert issue.trigger == "unless"` `left: "if"` `right: "unless"` |
| B | Drop `:unless` from the matched keyword set (`when keyword in [:if, :unless]` → `when keyword in [:if]`) | 1 (row 7) | `code: assert [issue] = issues` `left: [issue]` `right: []` |
| C | Drop "direct" from the message string (`"Avoid direct comparisons in ..."` → `"Avoid comparisons in ..."`) | 1 (row 1) | `code: assert issue.message =~ "Avoid direct comparisons in "` `left: "Avoid comparisons in \`if\` statements. Extract the comparison to a function in the appropriate module with a descriptive name."` `right: "Avoid direct comparisons in "` |
| D | Invert the comparison-detection branch (`case has_comparison?(condition) do true -> ...` → `case not has_comparison?(condition) do true -> ...`) | 18 of 18 (every row) | representative: row 8 (positive control, `if adult?(user)`) `code: assert issues == []` `left: [%Credo.Issue{... message: "Avoid direct comparisons in \`if\` statements. ..." line_no: 3, trigger: "if" ...}]` `right: []`; row 2 example (`==` operator) `code: assert length(issues) == 1` `left: 0` `right: 1` |

## Notes on what each mutation proves

- **A** protects the `unless`-vs-`if` trigger discrimination that is the whole
  point of this ticket's adjudicated fix: hardcoding the trigger string reddens
  exactly, and only, row 7 (the `unless` positive case) — every `if` row stays
  green because their trigger genuinely is `"if"`.
- **B** protects that `unless` nodes are matched at all. Dropping it from the
  keyword guard makes `find_if_with_comparisons/1` walk right past an `unless`
  with a comparison, so row 7 goes from one issue to zero — proving `unless`
  detection isn't accidentally supplied by some other code path.
- **C** protects the exact message text every "flags ..." row's message
  assertion (directly or transitively via row 1's `=~`) depends on.
- **D** is the positive-control proof, run across the *entire* matrix in one
  shot: inverting the boolean collapses every "flags" row to zero issues and
  inflates every "does not flag" row (8, 9, 10, 11) to one spurious issue each
  (all four fire on `if`/`unless` nodes whose call-based conditions are — after
  inversion — treated as "no comparison found" being false, i.e. flagged).
  This confirms both directions of the check are actually exercised: no test
  in the 11-row matrix passes vacuously.

## Measured zeros

None. Every one of the 11 acceptance-matrix rows is reddened by at least one
mutation above (rows 2–6, 9, 10 within mutation D's full-suite red; rows 1, 7
each individually isolated by A/B/C; row 8, 11 isolated within D).
