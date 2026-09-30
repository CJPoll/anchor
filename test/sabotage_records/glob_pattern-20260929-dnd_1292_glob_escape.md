# Sabotage record — every glob compiled in one place (DND-1292)

- **Domain:** glob_pattern (primary record of this run)
- **Branch:** dnd-1292-glob-escape
- **Date:** 2026-09-29
- **Code under test:** `Anchor.Domain.GlobPattern` — `to_regex/2`,
  `tokenizer/1`, `translate/2`, `wildcard_only?/1`, and the class guard that no
  other `lib/` file builds a regex
- **Tests:** `test/anchor/domain/glob_pattern_test.exs` (the DND-1292 blocks),
  `test/anchor/domain/rule_matching_test.exs` ("regex metacharacters are
  literal"), `test/anchor/domain/checks/no_dependency_test.exs`
  ("forbidden_patterns metacharacters"), `test/anchor/e2e/checks_e2e_test.exs`
  ("regex metacharacters in globs are literal")
- **Suite run:** `mix test`, the whole suite (661 tests), one mutation at a time
- **Merge base:** `origin/main` = 87269a3; **fix commit:** b005db3
- **Off-domain records (same run):**
  `rule_schema-20260929-dnd_1292_glob_escape.md` (H),
  `module_pattern_restrictions-20260929-dnd_1292_glob_escape.md` (I)

## The defect

`GlobPattern` escaped only `.`. Every other regex metacharacter in a config
glob was live regex:

- `allowed_functions: ["*?"]` compiled to `^[^/]*?$`, a lazy match-all. The
  rule loaded, allowed every function and checked nothing.
- `paths: ["lib/c++/**/*.ex"]` matched `lib/c/...` and not `lib/c++/...`, so
  the rule selected nothing (the DND-1290 floor reported it, with the wrong
  advice).
- `forbidden_patterns: ["*.Webs?.*"]` also forbade `.Web.`.
- `lib/(old/*.ex` raised `Regex.CompileError` when the check ran.
- `$` let a trailing newline match, and a literal `___DOUBLE_STAR___` in a
  recursive glob (the old placeholder) became `.*`.

## Fail-first run (unfixed 87269a3)

Tests written first. `657 tests, 22 failures`, among them:

```
  1) test rule_matches_file?/2 (regex metacharacters are literal, DND-1292) a `paths` glob with `+` selects its own directory, not the regex reading (Anchor.Domain.RuleMatchingTest)
     Expected truthy, got false
     code: assert RuleMatching.rule_matches_file?(rule, facts(%{filename: "lib/c++/a/b.ex"}))

  5) test detect_violations/2 — forbidden_patterns metacharacters (DND-1292) a `?` in a forbidden pattern is a literal (Anchor.Domain.Checks.NoDependencyTest)
     left:  [%Anchor.Domain.Violation{line: 2, trigger: "App.Web.Foo", ...}]
     right: []

 19) test regex metacharacters are literal (DND-1292) `*?` matches names ending in `?`, not every name (it was a lazy match-all) (Anchor.Domain.GlobPatternTest)
     Expected false or nil, got true
     code: refute GlobPattern.matches_pattern?("run", "*?")

 20) test regex metacharacters are literal (DND-1292) path: a metacharacter matches only itself (Anchor.Domain.GlobPatternTest)
     path: glob "a+b" on "ab": want false, got true
     path: glob "a?b" on "ab": want false, got true
     path: glob "a[b" on "a[b": want true, got {:raised, Regex.CompileError}
     path: glob "a|b" on "ab": want false, got true

 21) test regex metacharacters are literal (DND-1292) an unbalanced bracket or parenthesis is a literal, not a crash (Anchor.Domain.GlobPatternTest)
     ** (Regex.CompileError) missing closing parenthesis at position 20
```

Added later, each run against the unfixed matcher first:

```
trailing newline:  path: glob "a" on "a\n": want false, got true
e2e `*?`:          assert [issue] = issues / left: [issue] / right: []
e2e `+` path:      left: "rule 1 (no_direct_dependency)"  right: "MyApp.Repo"
```

After the fix: `661 tests, 0 failures`.

## Mutations

Each applied alone over the whole suite, then restored.

| # | Mutation | Tests failed | First failure |
|---|---|---|---|
| A | `translate/2` returns a literal unescaped | 27 of 661 | `a \`paths\` glob with \`+\` selects its own directory` / `Expected truthy, got false` |
| B | anchor with `^..$` instead of `\A..\z` | 1 of 661 | `the match is anchored at the very end: a trailing newline is not ignored` / `Assertion with == failed` |
| C | `**/` becomes `.*/` (no zero-segment match) | 1 of 661 | `recursive \`**/\`, \`/**\` and a bare \`**\`` / `Expected truthy, got false` |
| D | recursive tokenizer drops `**` (only single `*`) | 13 of 661 | `#3a recursive path selects a deep file that single-* semantics would miss` / `Expected truthy, got false` |
| E | module `*` becomes `[^/.]*` (stops at dots) | 13 of 661 | `same_context scoping (Gap F) flags a forbidden_patterns match…` / `match (=) failed` |
| F | `wildcard_only?/1` always `false` | 2 of 661 | `a glob of only wildcards matches every name` / `*`; and `RuleChecksNothingTest` `allowed_functions: ["*"] … LOADED` |
| G | `wildcard_only?/1` over-broad (any leading `*`) | 3 of 661 | `a glob with any literal character does not` / `*?`; plus the `*?` positive row refused and the e2e `*?` row |
| J | a second regex compiler added to `lib/anchor/domain/checks/must_use_module.ex` | 1 of 661 | `no other lib/ file builds or runs a regex` / `anchor/domain/checks/must_use_module.ex uses Regex.` |

Review round (commit after b005db3), over the whole suite of 665 tests:

| # | Mutation | Tests failed | First failure |
|---|---|---|---|
| L | path `*` widened to `.*` (crosses `/`) | 6 of 665 | `row 7: non-recursive single-* paths rule does not select a nested file` / `Expected false or nil, got true` |
| M | `/**` becomes `/.*` (requires a trailing segment) | 6 of 665 | `#2 **/ matches zero segments` / `Expected truthy, got false` |

Mutation K (`allowed_functions` back on the path flavor) is in the
`module_pattern_restrictions` record.

Verbatim, mutation B:

```
  1) test regex metacharacters are literal (DND-1292) the match is anchored at the very end: a trailing newline is not ignored (Anchor.Domain.GlobPatternTest)
     Assertion with == failed
     code:  assert row_failure(flavor, "a", "a\n", false) == nil
     left:  "path: glob \"a\" on \"a\\n\": want false, got true"
     right: nil
```

The table cells are shortened; the full output of every run is reproducible by
re-applying the mutation. No measured zeros. Every mutation compiled under
`--warnings-as-errors`.
