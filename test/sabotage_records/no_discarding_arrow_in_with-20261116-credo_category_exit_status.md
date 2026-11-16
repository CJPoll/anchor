# Sabotage record — every check declares a category Credo knows

- **Domain:** no_discarding_arrow_in_with
- **Branch:** credo-category-exit-status
- **Date:** 2026-11-16
- **Code under test:** the `category:` option of `Anchor.Check.NoDiscardingArrowInWith`
- **Tests:** `test/anchor/check/credo_category_test.exs`, all three tests that
  fail on the unfixed code
- **Suite run:** `mix test` (4265 tests)
- **Merge base:** `origin/main` = 9803748

## Fail-first

Against unfixed 9803748 (`category: :refactoring`):

```
1) test issue through Credo's exit-status task an issue from a violating source makes the run exit non-zero
   Assertion with != failed, both sides are exactly equal
   left: 0
2) test declared category every check's own exit_status/0 is non-zero
   left:  [Anchor.Check.NoDiscardingArrowInWith]
3) test declared category every check declares a category for which Credo assigns a non-zero exit status
   checks declaring a category Credo does not know
```

## Mutations

| # | Mutation | Result |
|---|---|---|
| M1 | `category: :refactor` back to `:refactoring` | `4 tests, 3 failures` (the three above) |
