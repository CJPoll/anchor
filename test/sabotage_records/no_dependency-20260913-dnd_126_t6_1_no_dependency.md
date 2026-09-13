# Sabotage record — NoDependency detection extracted to Domain

- **Domain:** no_dependency
- **Branch:** dnd-126-t6-1-no-dependency
- **Date:** 2026-09-13
- **Code under test:** `Anchor.Domain.Checks.NoDependency.detect_violations/2` (the pure Domain detector; the `Anchor.Check.NoDependency` shell delegates to it)
- **Suite run:** `mix test test/anchor/check/no_dependency_test.exs`

T6.1 (DND-126) extracted the detection out of the `Anchor.Check.NoDependency`
Framework shell into the pure `Anchor.Domain.Checks.NoDependency` module. Each
mutation below was applied to that Domain module, the suite re-run, the code
restored. Failure strings are verbatim, including `left:` / `right:`.

| # | Mutation | Tests failed | Failure string |
|---|---|---|---|
| A | Keep the **last** reference line instead of the first (change the two `first_reference_line/2` prewalk clauses from matching `, nil ->` to `, _acc ->`, so a later match overwrites the earlier one) | 1 (row 7) | `Assertion with == failed` `code: assert issue.line_no == 2` `left: 4` `right: 2` |
| B | Drop `direct` from the message string (`"Module has forbidden direct dependency on"` → `"Module has forbidden dependency on"`) | 1 (row 1) | `code: assert issue.message == "Module has forbidden direct dependency on MyApp.Repo"` `left: "Module has forbidden dependency on MyApp.Repo"` `right: "Module has forbidden direct dependency on MyApp.Repo"` |
| C | Null the trigger (`trigger: inspect(forbidden_module)` → `trigger: nil`) | 3 (rows 1, 2, 3) | row 1: `code: assert issue.trigger == "MyApp.Repo"` `left: ""` `right: "MyApp.Repo"`; row 2: `left: ""` `right: "Ecto.Query"`; row 3: `left: ["", ""]` `right: ["MyApp.Repo", "System"]` |
| D | Invert the dependency filter (`Enum.filter(&(&1 in dependencies))` → `Enum.filter(&(&1 not in dependencies))`) | 6 (rows 1, 2, 3, 4, 5, 7) | row 5 (positive control): `code: assert issues(source, [MyApp.Repo]) == []` `left: [%Credo.Issue{... message: "Module has forbidden direct dependency on MyApp.Repo", line_no: nil, trigger: "MyApp.Repo" ...}]` `right: []` |

## Notes on what each mutation proves

- **A** is the T6.1 behaviour fix itself (matrix row 7): detection must report the
  **first** reference line when a forbidden module appears twice. The old code
  kept the last prewalk match; row 7 pins the first (line 2, not line 4). The
  mutation reverts the fix and row 7 goes red exactly, and only, on `line_no`.
- **B / C** protect the two visible fields of the violation — `message` and
  `trigger`. Nulling the trigger surfaces as `""` in the built `Credo.Issue`
  (Credo's `format_issue/2` normalizes a `nil` trigger to the empty string), and
  it reddens every happy-path row that asserts a trigger.
- **D** is the positive-control proof: rows 4 and 5 assert `[]` for a clean module
  and for a module that names a *different* dependency, and inverting the filter
  makes the check flag a module the file does **not** reference (note `line_no:
  nil`, since the non-referenced module cannot be located in the AST). The same
  inversion empties the happy-path rows. Row 6 (empty `forbidden_modules`) stays
  green under D because the inner list is empty either way — it is protected by
  the empty-list guard, a different property than the filter.

## Trap encountered (ADR 002 catalogue)

A first attempt at mutation D replaced the filter body with `fn _ -> true end`,
which left the `dependencies` binding unused. Under this project's
`--warnings-as-errors` compile that is a **compile failure**, not a test
failure — `mix test` printed `variable "dependencies" is unused ... Compilation
failed due to warnings while using the --warnings-as-errors option` and ran zero
tests. A mutation that stops the suite compiling proves nothing about the tests;
the re-done mutation (`not in dependencies`) keeps the binding live so the suite
actually runs and the assertions are what fail.

## Measured zeros

None. Every mutation reddened at least one row; each of the eight matrix rows'
asserted properties (message, trigger, first-reference line, presence/absence)
is protected by at least one mutation above.
