# Sabotage record — alias-form module patterns (DND-1290)

- **Domain:** glob_pattern
- **Branch:** dnd-1290-empty-relation-list
- **Date:** 2026-09-29
- **Code under test:** `Anchor.Domain.GlobPattern.matches_module_pattern?/2`
  and its `module_name_forms/1`
- **Tests:** `test/anchor/domain/glob_pattern_test.exs` ("alias-form patterns,
  DND-1290"), and the e2e row "an alias-form module pattern selects and
  forbids" in `test/anchor/e2e/checks_e2e_test.exs`
- **Suite run:** `mix test` (608 tests)
- **Merge base:** `origin/main` = 044f5ae; **fix commit:** d3f8a54
- **Primary record (same run):** `rule_schema-20260929-dnd_1290_empty_relation_list.md`

## The defect

A module name reaches the matcher fully qualified (`Elixir.MyApp.Web.Foo`,
from `to_string/1`). A pattern written in alias form, `MyApp.Web.*`, as the
README's own examples are, matched nothing. A `pattern` selector or a
`forbidden_patterns` entry written that way made its rule check nothing.

## Fail-first run (unfixed 044f5ae)

```
  1) test matches_module_pattern?/2 (alias-form patterns, DND-1290) an alias-form pattern matches the fully-qualified Elixir module name (Anchor.Domain.GlobPatternTest)
     test/anchor/domain/glob_pattern_test.exs:94
     Expected truthy, got false
     code: assert GlobPattern.matches_module_pattern?("Elixir.MyApp.Web.Foo", "MyApp.Web.*")

 37) test a rule that checks nothing (DND-1290) an alias-form module pattern selects and forbids (the README's own form) (Anchor.E2E.ChecksE2ETest)
     match (=) failed
     code:  assert [issue] = issues
     left:  [issue]
     right: []
```

After the fix: `608 tests, 0 failures`.

## Mutations

| # | Mutation | Tests failed | Failure string |
|---|---|---|---|
| J | `module_name_forms/1` returns the qualified name only | 2 | `Expected truthy, got false` / `code: assert GlobPattern.matches_module_pattern?("Elixir.MyApp.Web.Foo", "MyApp.Web.*")` (and the e2e row) |
