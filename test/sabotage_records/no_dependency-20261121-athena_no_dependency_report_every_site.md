# Sabotage record — no_direct_dependency reports every reference site

- **Domain:** no_dependency
- **Branch:** athena/no-dependency-report-every-site
- **Date:** 2026-11-21
- **Code under test:** `Anchor.Domain.Checks.NoDependency` (`expand_sites/1`, `not_exempt_sites/2`), `Anchor.Domain.DependencyAnalyzer` (`sites/1`, `add_site/3`, `attributed_dependency_lines/2`, `attributed_function_references/1`)
- **Suite run:** `mix test` (whole suite; the rows name the tests that went red)

The check used to report a forbidden module once per file, and a forbidden
function once per rule, at the first line, so a Credo line-level disable on that
line hid every later reference. It now reports one issue per distinct reference
line. Each mutation below was applied to the code under test, the suite re-run,
and the file restored with `git checkout`. Failure strings are verbatim.

## Red before the fix

The new tests, run on the unfixed code (`mix test test/anchor/check/no_dependency_test.exs`).
The disable-on-both-lines test passes on the old code too: it pins what must
not change.

```
Running ExUnit with seed: 384467, max_cases: 32

............

  1) test check_file/3 — every reference site, so a disable covers one line no disable reports every reference, each at its own line (Anchor.Check.NoDependencyTest)
     test/anchor/check/no_dependency_test.exs:189
     match (=) failed
     code:  assert [first, second] = issues_after_disables(source, [Sample.Repo])
     left:  [first, second]
     right: [
              %Credo.Issue{
                check: Anchor.Check.NoDependency,
                category: :design,
                priority: 1,
                severity: 1,
                message: "Module has forbidden direct dependency on Sample.Repo. Fix: do not reference Sample.Repo from a module this rule selects; reach it through a module the rule allows",
                filename: "lib/some_module.ex",
                line_no: 2,
                column: 14,
                exit_status: 2,
                trigger: "Sample.Repo",
                diff_marker: nil,
                meta: [],
                scope: "Sample.Web.Thing.f"
              }
            ]
     stacktrace:
       test/anchor/check/no_dependency_test.exs:198: (test)

........

  2) test check_file/3 — every reference site, so a disable covers one line a disable on the first reference does not hide the second (Anchor.Check.NoDependencyTest)
     test/anchor/check/no_dependency_test.exs:160
     match (=) failed
     code:  assert [issue] = issues_after_disables(source, [Sample.Repo])
     left:  [issue]
     right: []
     stacktrace:
       test/anchor/check/no_dependency_test.exs:170: (test)

..
24 tests, 2 failures
```

## Summary

| # | Mutation | Tests failed |
|---|---|---|
| A | `expand_sites/1` keeps only the first line of each dependency (`Enum.take(lines, 1)`): the old once-per-dependency behaviour | 18 of 4314 |
| B | `sites/1` drops the `Enum.uniq()`, so two references on one line are two sites | 1 of 4314 |
| C | `not_exempt_sites/2` keeps only the first line per dependency after merging owners (`Enum.take(1)`) | 6 of 4314 |
| D | `call_sites` records only the first line of a call (`Map.put_new(.., [line])`): forbidden functions back to once per rule | 4 of 4314 |
| E | `owned_sites` records only the first line per owner and dependency: an allowed_callers rule loses a second site in one owner | 4 of 13 |

## Mutation A

`expand_sites/1` keeps only the first line of each dependency (`Enum.take(lines, 1)`): the old once-per-dependency behaviour. `18` failed of `4314`; the first failure, verbatim:

```

```

## Mutation B

`sites/1` drops the `Enum.uniq()`, so two references on one line are two sites. `1` failed of `4314`; the first failure, verbatim:

```

```

## Mutation C

`not_exempt_sites/2` keeps only the first line per dependency after merging owners (`Enum.take(1)`). `6` failed of `4314`; the first failure, verbatim:

```

```

## Mutation D

`call_sites` records only the first line of a call (`Map.put_new(.., [line])`): forbidden functions back to once per rule. `4` failed of `4314`; the first failure, verbatim:

```

```

## Mutation E

`owned_sites` records only the first line per owner and dependency: an allowed_callers rule loses a second site in one owner. `4` failed of `13`; the first failure, verbatim:

```

```

## Measured zero, then closed

Mutation E first ran green over the whole suite (4314 tests, 0 failures): no test
had one module calling a forbidden module twice while a rule carried
`allowed_callers`, so the per-owner site list was unprotected. A row for it was
added to `test/anchor/domain/checks/no_dependency_allowed_callers_test.exs`
("one unlisted module calling twice"), and E re-ran red as above. The zero is
kept here on purpose (ADR 003).

## Rows that stayed green, and why

- Mutation B reddens one test only: the same-line dedupe is a different property
  from the per-line reporting that A, C, D protect.
- The disable-on-both-lines test is green under every mutation: nothing reported
  means nothing to hide, so no mutation of the site lists can change it. It
  guards against a fix that reports a line a disable covers.

## Traps

- A first draft replaced `[%%Violation{line: 4}] = detect(...)` by string match
  and edited the wrong test (another test had the same assertion). The suite
  caught it; rewrite one test at a time and re-run.
