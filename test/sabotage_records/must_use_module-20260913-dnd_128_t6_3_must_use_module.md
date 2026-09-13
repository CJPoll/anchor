# Sabotage record — MustUseModule detection extracted to Domain

- **Domain:** must_use_module
- **Branch:** dnd-128-t6-3-must-use-module
- **Date:** 2026-09-13
- **Code under test:** `Anchor.Domain.Checks.MustUseModule.detect_violations/2` (Domain detection), delegated to by the thin Framework shell `Anchor.Check.MustUseModule.detect_violations/4` / `check_file/3`
- **Suite run:** `mix test test/anchor/domain/checks/must_use_module_test.exs test/anchor/check/must_use_module_test.exs --seed 0`

All four mutations were applied to the extracted Domain module
`lib/anchor/domain/checks/must_use_module.ex`, restored from a backup copy after
each run (the file is new/uncommitted this branch, so `git checkout` would not
have restored it — a pristine copy was kept in the scratchpad and copied back).
Baseline: 16 tests, 0 failures.

| # | Mutation | Tests failed | Failure string (verbatim) |
|---|---|---|---|
| A | `\|> Enum.reject(&(&1 in uses))` → `\|> Enum.filter(&(&1 in uses))` (invert the "missing" predicate) | **10** | see A below |
| B | message `"Module must use #{inspect(required_module)}"` → `"Module should use ..."` | **3** | `left: "Module should use MyApp.Schema"` / `right: "Module must use MyApp.Schema"` |
| C | violation `line: 1` → `line: 2` | **3** | `code: assert violation.line == 1` / `left: 2` / `right: 1` (and the two `issue.line_no == 1` mirrors) |
| D | drop the nil guard: `required = rule.required_modules \|\| []` → `required = rule.required_modules` | **1** | see D below |

## A — reject → filter (10 failures)

Inverting the predicate makes the check flag *used* modules and pass *missing*
ones, so every positive-and-negative pair moves. Representative strings:

```
8) test check_file/3 flags each missing required module separately (Anchor.Check.MustUseModuleTest)
   Assertion with == failed
   code:  assert length(issues) == 2
   left:  0
   right: 2

9) test check_file/3 one of two required modules present flags only the missing one (Anchor.Check.MustUseModuleTest)
   code:  assert issue.trigger == "MyApp.Base"
   left:  "MyApp.Schema"
   right: "MyApp.Base"

10) test check_file/3 `use ModName, opts` still counts as a use (Anchor.Check.MustUseModuleTest)
    code:  assert issues(source, [MyApp.Schema]) == []
    left:  [%Credo.Issue{... message: "Module must use MyApp.Schema", line_no: 1, trigger: "MyApp.Schema", scope: "S"}]
    right: []
```

Failing across both suites (Domain rows #1/#3/#4 and Framework rows #1–#5)
confirms the `use`-vs-required set difference is what both the pure detector and
the mapped issues assert — including that `use Mod, opts` (row #5) is counted as
a use, since the mutation flips row #5 from `[]` to one issue.

## B — message text (3 failures)

Both the Domain assertion (`violation.message`) and the Framework assertions
(`issue.message`, including the row #4 `"Module must use MyApp.Base"` variant)
red, proving the message string is pinned on both sides of the Framework mapping,
not just at one layer.

## C — reported line (3 failures)

`assert violation.line == 1` (Domain) and the two `issue.line_no == 1`
(Framework rows #1 and #4) red with `left: 2`, proving line 1 is asserted end to
end. The `Credo.Issue.line_no` is fed from `Violation.line` via `format_issue/2`,
so this also proves the shell forwards the Domain line rather than resolving its
own.

## D — nil `required_modules` guard (1 failure)

```
1) test detect_violations/2 nil required_modules is treated as empty and flags nothing (Anchor.Domain.Checks.MustUseModuleTest)
   ** (Protocol.UndefinedError) protocol Enumerable not implemented for Atom.
   Got value:
       nil
   stacktrace:
     (elixir 1.19.4) lib/enum.ex:4570: Enum.reject/2
     (anchor 0.1.0) lib/anchor/domain/checks/must_use_module.ex:40: anonymous fn/2 in Anchor.Domain.Checks.MustUseModule.detect_violations/2
```

Exactly one test (the dedicated Domain nil-guard row) protects the `|| []`
fallback; the other 15 rows all pass a list and are silent under this mutation.
Not a measured zero — the guard is protected — but this row is the *only* thing
protecting it, recorded here so a later reader knows removing the guard has a
single, specific tripwire.

## Measured zeros

None. Every acceptance property (the used/missing set difference, the message,
the trigger via mutation A's `left:` issue dump, the line, and the nil guard) had
at least one reddening mutation. `trigger` is asserted directly by rows #1/#3/#4
of both suites; it was not mutated independently because mutation A already
prints the full `%Credo.Issue{trigger: "MyApp.Schema"}` in its `left:` block,
demonstrating the trigger is carried and asserted.
