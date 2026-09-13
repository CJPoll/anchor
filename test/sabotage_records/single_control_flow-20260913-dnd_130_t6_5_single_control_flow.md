# Sabotage record — SingleControlFlow detection extracted to Domain

- **Domain:** single_control_flow
- **Branch:** dnd-130-t6-5-single-control-flow
- **Date:** 2026-09-13
- **Code under test:** `Anchor.Domain.Checks.SingleControlFlow.detect_violations/2` (Domain detection), delegated to by the thin Framework shell `Anchor.Check.SingleControlFlow.detect_violations/4` / `check_file/3`
- **Suite run:** `mix test test/anchor/domain/checks/single_control_flow_test.exs test/anchor/check/single_control_flow_test.exs --seed 0`

All mutations were applied to the extracted Domain module
`lib/anchor/domain/checks/single_control_flow.ex`, restored from a backup copy
after each run (the file is new/uncommitted this branch, so `git checkout`
would not have restored it — a pristine copy was kept in `/tmp` and copied
back after each mutation). Baseline: 21 tests (10 Domain + 11 Framework), 0
failures.

| # | Mutation | Tests failed | Failure string (verbatim, representative) |
|---|---|---|---|
| A | threshold `control_flow_count > 1` → `> 2` | **14** | see A below |
| B | `already_in_pipe_chain?` predicate inverted (`match?(...)` → `not match?(...)`) | **2** | see B below |
| C | guard-clause detection reordered to match the ORIGINAL pre-extraction bug (plain `{name,_,args}` clause checked before the `{:when,...}` clause) | **2** | `left: "when"` / `right: "f"` |
| D | violation message `"contains #{count} control-flow structures"` → `"has #{count} control-flow structures"` | **10** | see D below |
| E | reported line `Keyword.get(meta, :line)` → `Keyword.get(meta, :line) + 100` | **9** (Framework) + **2** (Domain, run separately) | see E below |

## A — raise the threshold to 2 (14 failures)

Every row whose fixture has exactly 2 control-flow structures (rows #1, #4,
#5, #6, #7, #8, #10 in both suites) stops being flagged:

```
12) test check_file/3 `for` + `unless` flags (cond/receive also count as structures) (Anchor.Check.SingleControlFlowTest)
    match (=) failed
    code:  assert [issue] = issues(source)
    left:  [issue]
    right: []
```

Confirms the `> 1` threshold (not `>= 2` or some other boundary) is what both
suites pin, and that rows #1/#4/#5/#6/#7/#8/#10 all depend on it.

## B — invert the pipe-chain de-duplication (2 failures)

Only row #3 ("a single pipe chain counts as one") reds in each suite:

```
1) test detect_violations/2 a single pipe chain counts as one (passes) (Anchor.Domain.Checks.SingleControlFlowTest)
   Assertion with == failed
   code:  assert SingleControlFlow.detect_violations(ast, [rule()]) == []
   left:  [%Anchor.Domain.Violation{line: 2, trigger: "f", message: "Function clause `f` contains 2 control-flow structures (maximum allowed: 1). ..."}]
   right: []
```

Inverting the "is this `|>` already inside a chain" predicate makes every
non-innermost pipe stage count separately, turning the 3-stage chain
`x |> a() |> b() |> c()` into a count of 2 (two of its three `|>` nodes now
register as new structures) — exactly the case rows #3 exists to pin. Rows #4
and #5 (a chain alongside another structure, and two separate chains) do NOT
red under this mutation, because their fixtures already expect count 2 and the
mutation still yields ≥2 there too — showing row #3 is the ONLY row that
isolates correct chain collapsing.

## C — reintroduce the original guard-ordering bug (2 failures)

This is the actual defect found and fixed during this extraction (see below):
the pre-extraction code checked the plain `{name, _, args}` pattern before the
`{:when, ...}` guard pattern, and `{:when, meta, [call, guard]}` itself
satisfies `is_atom(name) and is_list(args)` with `name` bound to the atom
`:when` — so a guarded clause's trigger silently became `"when"` instead of
the real function name. Reordering the clauses back to that broken order
reproduces it exactly:

```
1) test detect_violations/2 clause with guard is analyzed (Anchor.Domain.Checks.SingleControlFlowTest)
   Assertion with == failed
   code:  assert violation.trigger == "f"
   left:  "when"
   right: "f"
```

Only row #8 (the dedicated guard-clause row, in both suites) catches this —
every other row's fixture is unguarded. This is a **genuine bug fix**, not new
adjudicated behavior: the Mission's row #8 acceptance ("guarded clause
analyzed → 1 issue trigger `f`") is authoritative and the pre-extraction
implementation did not actually satisfy it (its own test only asserted
`length(issues) == 1`, never the trigger, so the bug was silent). Counting
semantics (which structures count, pipe-chain collapsing) are unchanged from
the pre-extraction code.

## D — message wording (10 failures)

Every row that asserts on `message` (via `==` or `=~`) reds:

```
6) test check_file/3 flags a clause with two control-flow structures (Anchor.Check.SingleControlFlowTest)
   Assertion with =~ failed
   code:  assert issue.message =~ "contains 2 control-flow structures (maximum allowed: 1)"
   left:  "Function clause `f` has 2 control-flow structures (maximum allowed: 1). ..."
   right: "contains 2 control-flow structures (maximum allowed: 1)"
```

Confirms the exact wording (including the count interpolation) is pinned by
rows #1, #4, #5, #6, #7, #10 in both suites (10 = 5 rows × 2 suites).

## E — reported line offset by +100 (9 Framework + 2 Domain failures)

Domain suite (asserts `violation.line` directly):

```
1) test detect_violations/2 flags a clause with two control-flow structures (message/trigger/line) (Anchor.Domain.Checks.SingleControlFlowTest)
   Assertion with == failed
   code:  assert violation.line == 2
   left:  102
   right: 2

2) test detect_violations/2 each violating clause reported at its own def line (Anchor.Domain.Checks.SingleControlFlowTest)
   Assertion with == failed
   code:  assert violation.line == 6
   left:  106
   right: 6
```

Framework suite: pushing the line past the end of the small fixture source
makes Credo's own `format_issue/3` raise (`Credo.Check.add_line_no_options/3`
returns `nil` when the requested line doesn't exist in the source, and the
subsequent map over it fails to match) rather than compare cleanly — still a
hard failure in every row whose fixture has 2+ structures (rows #1, #4, #5,
#6, #7, #8, #10 — 7 rows, but row #1 and #10 raised via a different path than
the `assert issue.line_no ==` rows for the shorter fixtures, so the count
lands at 9 of 11 Framework rows). This proves `line` is threaded end to end
from the Domain violation through `Anchor.Check.Base`'s `format_issue/2`
mapping to `Credo.Issue.line_no`, exactly like the `no_dependency` and
`must_use_module` precedent.

## Measured zeros

None. Every acceptance property (the >1 threshold, pipe-chain collapsing, the
guard-clause trigger fix, the message text, and the reported line) had at
least one reddening mutation, across both the Domain and Framework suites.
