# Sabotage record — every check declares a category Credo knows

- **Domain:** no_discarding_arrow_in_with
- **Branch:** credo-category-exit-status
- **Date:** 2026-11-16
- **Code under test:** the `category:` option of `Anchor.Check.NoDiscardingArrowInWith`
- **Tests:** `test/anchor/check/credo_category_test.exs` (all four)
- **Suite run:** `mix test test/anchor/check/credo_category_test.exs` (4 tests);
  full suite after the fix: `mix test` (4265 tests, 0 failures)
- **Merge base:** `origin/main` = 9803748

## Fail-first

Against unfixed 9803748 (`category: :refactoring`), the test file as first
written (line numbers are of that file; the later edit only reworded two
assertion messages):

```


  1) test issue through Credo's exit-status task an issue from a violating source makes the run exit non-zero (Anchor.Check.CredoCategoryTest)
     test/anchor/check/credo_category_test.exs:48
     Assertion with != failed, both sides are exactly equal
     code: assert Execution.get_exit_status(exec) != 0
     left: 0
     stacktrace:
       test/anchor/check/credo_category_test.exs:68: (test)

.

  2) test declared category every check's own exit_status/0 is non-zero (Anchor.Check.CredoCategoryTest)
     test/anchor/check/credo_category_test.exs:41
     Assertion with == failed
     code:  assert bad == []
     left:  [Anchor.Check.NoDiscardingArrowInWith]
     right: []
     stacktrace:
       test/anchor/check/credo_category_test.exs:43: (test)



  3) test declared category every check declares a category for which Credo assigns a non-zero exit status (Anchor.Check.CredoCategoryTest)
     test/anchor/check/credo_category_test.exs:32
     checks declaring a category Credo does not know: [{Anchor.Check.NoDiscardingArrowInWith, :refactoring}]
     code: assert bad == [], "checks declaring a category Credo does not know: #{inspect(bad)}"
     stacktrace:
       test/anchor/check/credo_category_test.exs:38: (test)


Finished in 0.03 seconds (0.03s async, 0.00s sync)
4 tests, 3 failures
```

## Mutations

| # | Mutation | Result |
|---|---|---|
| M1 | `category: :refactor` back to `:refactoring` | `4 tests, 3 failures` (the three above); "the check set is not empty" stayed green, as it should |
| M2 | test filter prefix `"Elixir.Anchor.Check."` changed to `"Elixir.Anchor.Nope."` | `4 tests, 1 failure`, below |

M2 (the guard that stops the other tests passing on an empty module list):

```
  1) test declared category the check set is not empty (Anchor.Check.CredoCategoryTest)
     test/anchor/check/credo_category_test.exs:29
     no Anchor check modules were discovered
     code: refute check_modules() == [], "no Anchor check modules were discovered"
     stacktrace:
       test/anchor/check/credo_category_test.exs:30: (test)
```
