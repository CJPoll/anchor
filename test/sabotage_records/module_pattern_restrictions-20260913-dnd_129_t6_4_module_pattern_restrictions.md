# Sabotage record — ModulePatternRestrictions detection extracted to Domain

- **Domain:** module_pattern_restrictions
- **Branch:** dnd-129-t6-4-module-pattern-restrictions
- **Date:** 2026-09-13
- **MR:** T6.4 (DND-129)
- **Code under test:** `Anchor.Domain.Checks.ModulePatternRestrictions.detect_violations/2` (Domain detection), delegated to by the thin Framework shell `Anchor.Check.ModulePatternRestrictions.detect_violations/4` / `check_file/3`
- **Suite run:** `mix test test/anchor/domain/checks/module_pattern_restrictions_test.exs test/anchor/check/module_pattern_restrictions_test.exs --seed 0`

All mutations were applied to the extracted Domain module
`lib/anchor/domain/checks/module_pattern_restrictions.ex`, restored from a
pristine backup copy after each run (the file is new/uncommitted on this branch,
so `git checkout` would not have restored it — a copy was kept in the scratchpad
and copied back). Baseline: **22 tests, 0 failures**.

| # | Mutation | Tests failed | Failure string (verbatim) |
|---|---|---|---|
| A | `uses_module` selection: `Module.concat([rule.uses_module]) in extract_uses(ast)` → `... not in ...` | **14** | see A |
| B | message `"Module defines non-allowed function: #{function_name}"` → `"Module has non-allowed function: ..."` | **2** | see B |
| C | reported line: `line: find_function_line(ast, function_name)` → `... + 1` | **3** | see C |
| E | `allowed_functions` glob branch `if String.contains?(entry, "*")` → `if false` (never treat an entry as a glob) | **4** | see E |
| F | dedup: rewrite `extract_defined_functions` accumulator from a `MapSet` to a prepend list (keeps multi-clause duplicates) | **2** | see F |
| G | drop private-function detection: `:defp` head guard `when is_atom(name)` → `when is_atom(name) and false` | **2** | see G |
| H | allowed/non-allowed split: `Enum.reject(&allowed?(...))` → `Enum.filter(&allowed?(...))` | **17** | see H |
| P | `pattern` selection arm: `Enum.any?(&GlobPattern.matches_module_pattern?(&1, rule.pattern))` → `Enum.any?(fn _ -> false end)` | **1** | see P |
| Z | selection fallback `true -> true` → `true -> false` | **0** | **measured zero — see below** |

## A — invert `uses_module` selection (14 failures)

Flipping `in` → `not in` makes a rule select exactly the files it should not:
every positive row (a file that `use`s `Ecto.Schema` matched by a
`uses_module: "Ecto.Schema"` rule) stops flagging, and row #9 (a file that does
**not** use it) starts flagging. Representative:

```
14) test check_file/3 rule not selecting the file (uses_module) yields nothing (Anchor.Check.ModulePatternRestrictionsTest)
    Assertion with == failed
    code:  assert issues(source, uses_rule([])) == []
    left:  [
             %Credo.Issue{
               check: Anchor.Check.ModulePatternRestrictions,
```

This proves the `uses_module` selector is what gates detection — row #9 (`[]`)
and the eight positive rows move together.

## B — message text (2 failures)

```
code:  assert violation.message == "Module defines non-allowed function: custom"
left:  "Module has non-allowed function: custom"
right: "Module defines non-allowed function: custom"
```

Both the Domain assertion (`violation.message`) and the Framework assertion
(`issue.message`) red, proving the message string is pinned on both sides of the
Framework mapping.

## C — reported line (3 failures)

```
code:  assert issue.line_no == 7
left:  8
right: 7
```

Row #1 (line 7), row #7 (line 5), and the Domain line row (line 3) red with an
off-by-one, proving the definition line is asserted end to end and that
`Credo.Issue.line_no` is fed from `Violation.line` via `format_issue/2`.
(Setting the line to a literal `1` instead orphaned `find_function_line/2` and
failed the `--warnings-as-errors` compile before any test ran, so the value was
perturbed with `+ 1` to keep the function used.)

## E — disable `allowed_functions` glob (4 failures)

```
1) test detect_violations/2 — allowed_functions glob `with_*` allows every `with_`-prefixed function
   code:  assert ModulePatternRestrictions.detect_violations(ast, [uses_rule(["new", "with_*"])]) == []
   left:  [%Anchor.Domain.Violation{line: 3, trigger: "with_status", ...}]
```

With globbing off, `with_status` no longer matches the `with_*` entry, so rows
#5/#6 (both suites) red — proving the glob support (the adjudicated fix) is
actually exercised and not dead.

## F — break multi-clause dedup (2 failures)

```
1) test detect_violations/2 — function checking multi-clause function is reported once (name deduped)
   code:  assert [%Violation{trigger: "foo"}] = ModulePatternRestrictions.detect_violations(ast, [uses_rule([])])
   right: [ %Anchor.Domain.Violation{trigger: "foo"}, %Anchor.Domain.Violation{trigger: "foo"} ...]
```

Replacing the `MapSet` accumulator with a list that keeps duplicates makes the
two `foo/1` clauses report twice. Exactly the two dedup rows (Domain + Framework
row #8) red and nothing else, proving dedup is what row #8 protects.

## G — drop private-function detection (2 failures)

```
1) test detect_violations/2 — function checking flags a private function too
   code:  assert [%Violation{trigger: "helper"}] = ModulePatternRestrictions.detect_violations(ast, [uses_rule([])])
   left:  [%Anchor.Domain.Violation{trigger: "helper"}]
```

Disabling the `:defp` head makes `defp helper` invisible, so row #3 (both
suites) red — proving private definitions are flagged, not just public ones.

## H — invert allowed/non-allowed split (17 failures)

`reject` → `filter` reports *allowed* functions and passes *non-allowed* ones,
moving nearly every row (the positive controls that expect `[]` now flag, and
the flagging rows now come back empty or with the wrong trigger). The broadest
mutation, confirming the `allowed_functions` membership test drives the whole
check.

## P — break `pattern` selection arm (1 failure)

```
1) test detect_violations/2 — selection pattern rule matching a module name selects the file
   code:  assert [%Violation{trigger: "custom"}] = ModulePatternRestrictions.detect_violations(ast, [rule])
```

Forcing the module-name match to `false` drops the `pattern`-selected file, so
the pattern positive-selection row reds — proving the `pattern` arm (module-name
selection via T5's plural `extract_module_names/1` through
`GlobPattern.matches_module_pattern?/2`) is real.

## Measured zeros

**Z — the `true -> true` selection fallback (0 failures).** Mutating the
`rule_selects_file?/2` fallback from `true` to `false` reddens no test. This is
honest and expected: the fallback exists only for a rule that carries **neither**
`pattern` nor `uses_module` — i.e. a `paths`-based (or selector-less) rule, whose
path-scoping is the Manager's job (`Anchor.Managers.Lint` via
`Anchor.Domain.RuleMatching`) and is **out of scope** for this check's detection
(the pre-existing `paths: []` selection shadow the ticket explicitly defers). No
unit exercises that arm because doing so would require reintroducing path
selection here, which the design deliberately leaves upstream. Flagged so a later
reader knows this branch is intentionally untested at the Domain layer, not an
oversight.
