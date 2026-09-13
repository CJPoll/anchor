# Sabotage record — NoDiscardingArrowInWith detection extracted to Domain

- **Domain:** no_discarding_arrow_in_with
- **Branch:** dnd-134-t6-9-no-discarding-arrow-in-with
- **Date:** 2026-09-13
- **Code under test:** `Anchor.Domain.Checks.NoDiscardingArrowInWith.detect_violations/1` (the pure Domain detector; the `Anchor.Check.NoDiscardingArrowInWith` shell delegates to it)
- **Suite run:** `mix test test/anchor/check/no_discarding_arrow_in_with_test.exs`

T6.9 (DND-134) extracted the detection out of the
`Anchor.Check.NoDiscardingArrowInWith` Framework shell into the pure
`Anchor.Domain.Checks.NoDiscardingArrowInWith` module, mirroring T6.1's
`Anchor.Domain.Checks.NoDependency` shape. No new adjudicated fix this time —
the three discarding shapes (bare `_`, underscore-prefixed var, guard-clause
discard) and the three structural/positive-control shapes (`{:ok, value}`,
`{:ok, _}`, a bound var) behave exactly as before extraction. Each mutation
below was applied to the Domain module, the suite re-run, the code restored.
Failure strings are verbatim, including `left:` / `right:`.

| # | Mutation | Tests failed | Failure string |
|---|---|---|---|
| A | Remove the guard-unwrapping clause from `is_discarding_pattern?/1` (delete the `{:when, _, [inner_pattern \| _]} -> is_discarding_pattern?(inner_pattern)` match) | 1 (row 3) | `match (=) failed` `code: assert [issue] = issues(source)` `left: [issue]` `right: []` |
| B | Null the trigger (`trigger: pattern_string` → `trigger: nil`) | 3 (rows 1, 2, 3) | row 1: `code: assert issue.trigger == "_"` `left: ""` `right: "_"`; row 2: `code: assert issue.trigger == "_result"` `left: ""` `right: "_result"`; row 3: `code: assert issue.trigger == "_x"` `left: ""` `right: "_x"` |
| C | Invert the discarding predicate (`if is_discarding_pattern?(pattern) do` → `if not is_discarding_pattern?(pattern) do`) | 7 of 9 (rows 1, 2, 3, 4, 5, 6, 7; only row 8, which has no arrow clause at all, is unaffected) | rows 1/2/3 (true positives lost): `match (=) failed` `code: assert [issue] = issues(source)` `left: [issue]` `right: []`; rows 4/5 (`{:ok, value}` / `{:ok, _}`, positive controls, now **wrongly flagged**): `code: assert issues(source) == []` `left: [%Credo.Issue{... message: "Unnecessary arrow (<-) in with clause. Pattern \`pattern\` only discards the value. Remove the arrow and pattern to simplify", trigger: "pattern", ...}]` `right: []`; row 6 (bound var `value`, positive control, also wrongly flagged): same shape but `trigger: "value"` (the plain-var pattern still matches `pattern_string/1`'s var-name clause even though it's no longer discarding); row 7 (multi-clause) keeps its 1-issue count but on the **wrong clause**: `code: assert issue.line_no == 4` `left: 3` `right: 4` (the non-discarding `{:ok, v} <-` on line 3 is now flagged instead of the discarding `_ <-` on line 4) |
| D | Weaken the message text (`"Unnecessary arrow (<-) in with clause. Pattern \`#{pattern_string}\` only discards the value. "` → `"Arrow (<-) in with clause. Pattern \`#{pattern_string}\` discards the value. "`) | 1 (row 1) | `code: assert issue.message == "Unnecessary arrow (<-) in with clause. Pattern \`_\` only discards the value. Remove the arrow and pattern to simplify"` `left: "Arrow (<-) in with clause. Pattern \`_\` discards the value. Remove the arrow and pattern to simplify"` `right: "Unnecessary arrow (<-) in with clause. Pattern \`_\` only discards the value. Remove the arrow and pattern to simplify"` |

## Notes on what each mutation proves

- **A** protects the guard-clause unwrapping (matrix row 3): `with _x when
  is_nil(_x) <- f()` must still be recognized as discarding once the `when`
  wrapper is stripped. Removing the unwrap clause makes `is_discarding_pattern?`
  fall through to the plain-atom-name clause with `var_name = :when` (itself an
  atom that doesn't start with `_`), so the guarded clause is silently missed
  — reddening exactly and only row 3.
- **B** protects the visible `trigger` field. Nulling it surfaces as `""` in
  the built `Credo.Issue` (Credo's `format_issue/2` normalizes a `nil` trigger
  to the empty string), reddening every row that asserts an exact `trigger`
  value (rows 1, 2, 3) without touching the rows that only assert
  presence/absence or the message/line number.
- **C** is the strongest positive-control proof in this record: inverting the
  discarding predicate removes every true positive (rows 1, 2, 3) and
  fabricates false positives on rows 4, 5, and 6 — the three rows that exist
  precisely to prove a structural match (`{:ok, value}`, `{:ok, _}`) and a
  plain bound variable (`value`) are left alone. The fabricated issues name
  those patterns as "discarding" (or wrongly re-trigger on the bound-var
  name) when they never were, which is exactly the failure mode rows 4-6 are
  written to catch. Row 7 shows a subtler break: the multi-clause `with` still
  produces exactly one issue (the counting logic is untouched), but it is now
  raised against the *wrong* clause — the meaningful `{:ok, v} <-` instead of
  the discarding `_ <-` — which a plain issue-count assertion would have
  missed; only the explicit `line_no == 4` assertion catches it, illustrating
  why row 7 asserts the line number and not just the count.
- **D** protects the message text specifically for the primary happy path
  (row 1)'s exact-match assertion; the same wording feeds every row's message
  (rows 2, 3, 7 assert only `trigger`/`line_no`, not the full message text),
  so row 1 is the sole message-text guard and this mutation demonstrates it is
  live.

## Trap encountered (ADR 002 catalogue)

Attempting a fifth mutation — nulling the `line:` field in `build_violation/2`
(`line: meta[:line]` → `line: nil`) to directly test line-number propagation —
hit `--warnings-as-errors` before a single test could run: with `meta` no
longer referenced in the function body, `mix compile --warnings-as-errors`
failed with `variable "meta" is unused (if the variable is not meant to be
used, prefix it with an underscore)` at
`lib/anchor/domain/checks/no_discarding_arrow_in_with.ex:104:33:
Anchor.Domain.Checks.NoDiscardingArrowInWith.build_violation/2`. This is the
same class of "orphaned binding" warnings-as-errors trap recorded on prior
T6.x extractions (T6.7's case_on_bare_arg record, T6.4/T6.2's orphaned-alias
and orphaned-head-binding traps) — a compile-time zero-measurer, not a runtime
one, so it is filed here as encountered rather than discarded silently. Line
propagation (rows 1 and 7, which assert exact `line_no` values) is instead
covered transitively: mutations A and C both reddened rows 1/3/7 on the
`match (=) failed` / count axis while leaving the line-number code path
untouched, and no mutation above needed to touch `meta[:line]` to prove a
regression, so line correctness for rows 1 and 7 rests on the passing suite
plus this documented compile-time trap rather than an additional runtime
mutation. The code was restored immediately (`git checkout --
lib/anchor/domain/checks/no_discarding_arrow_in_with.ex`) without running the
test suite in the broken state.

## Measured zeros

None among the four completed mutations (A-D); each reddened at least one
row. The attempted fifth mutation (line-number nulling) is a genuine
zero-measurer in the sense that it never reached the test runner at all (see
Trap above) — recorded honestly rather than omitted.
