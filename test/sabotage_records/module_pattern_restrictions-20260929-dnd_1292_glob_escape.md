# Sabotage record — allowed_functions through one matcher (DND-1292)

- **Domain:** module_pattern_restrictions
- **Branch:** dnd-1292-glob-escape
- **Date:** 2026-09-29
- **Code under test:** `Anchor.Domain.Checks.ModulePatternRestrictions`
  `function_matches?/2`
- **Tests:** `test/anchor/domain/checks/module_pattern_restrictions_test.exs`
  ("allowed_functions metacharacters (DND-1292)"), the e2e row
  "allowed_functions `*?` allows the predicates and flags the rest"
- **Suite run:** `mix test`, the whole suite (661 tests)
- **Merge base:** `origin/main` = 87269a3; **fix commit:** b005db3
- **Primary record (same run):** `glob_pattern-20260929-dnd_1292_glob_escape.md`

## The change

`function_matches?/2` had two matchers: an entry with a `*` went through
`GlobPattern`, and any other entry was compared by name, so that a `?` in
`valid?` was not read as regex. That side branch was a workaround for the
DND-1292 defect, and a glob entry with a `?` still hit it (`*?` was a
match-all). Every entry now goes through `GlobPattern.matches_pattern?/2`,
where a `*`-free entry is all literal and matches exactly its own name.

Fail-first (unfixed 87269a3):

```
test detect_violations/2 — allowed_functions metacharacters (DND-1292) `*?` allows predicates and flags everything else
     match (=) failed
     left:  [%Anchor.Domain.Violation{trigger: "run"}]
     right: []
```

## Mutations

| # | Mutation | Tests failed | First failure |
|---|---|---|---|
| I | `function_matches?/2` compares names only (no glob) | 7 of 661 | `` `*!` allows bang functions only `` / `match (=) failed` |
| K | `function_matches?/2` uses the path flavor (`matches_pattern?/2`, `*` stops at `/`) | 1 of 665 | see below |

K is the review-round finding: a function name is not a path, so `*` must
match a user-defined `/` operator. Before the fix `allowed_functions: ["*"]`
could not load anyway (refused as a match-all), but the refusal's premise and
the docstring claim "matches every function name" depended on it. The fix is
`GlobPattern.matches_name_pattern?/2`. K's output, which is also the fail-first
output of the new test:

```
  1) test detect_violations/2 — allowed_functions metacharacters (DND-1292) a `*` entry matches a user-defined `/` operator too (a name, not a path) (Anchor.Domain.Checks.ModulePatternRestrictionsTest)
     Assertion with == failed
     code:  assert ModulePatternRestrictions.detect_violations(ast, [uses_rule(["*"])]) == []
     left:  [
              %Anchor.Domain.Violation{
                line: 3,
                trigger: "/",
                message: "Module defines non-allowed function: /",
                filename: nil,
                kind: :rule
              }
            ]
     right: []
```
