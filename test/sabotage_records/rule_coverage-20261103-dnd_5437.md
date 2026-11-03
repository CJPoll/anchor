# Sabotage record — graph rules are never reported unchecked (DND-5437)

- **Domain:** rule_coverage
- **Branch:** dnd-5437
- **Date:** 2026-11-03
- **Code under test:** `Anchor.Domain.RuleCoverage.unchecked/3` (`unchecked/2` existed on 185ecc9 and now delegates)
- **Tests:** `test/anchor/domain/rule_coverage_test.exs` ("unchecked/3")
- **Suite run:** each mutation applied alone to 97cf553 and the command named under
  it run (`mix test <files>`), then the file restored with `git checkout --`.
  The full suite (`mix test`) was green before and after.
- **Merge base:** `origin/main` = 185ecc9; **fix commit:** 97cf553

## Fail-first

`unchecked/3` is new; `unchecked/2` existed.

`mix test test/anchor/domain/rule_coverage_test.exs` against 185ecc9's `lib/` (and README) with this branch's tests: `21 tests, 4 failures`.

```
  1) test unchecked/3 only the AST rule of a mixed list is reported, in order (Anchor.Domain.RuleCoverageTest)
     test/anchor/domain/rule_coverage_test.exs:168
     ** (UndefinedFunctionError) function Anchor.Domain.RuleCoverage.unchecked/3 is undefined or private. Did you mean:

         * unchecked/2

     code: assert RuleCoverage.unchecked(rules, [], &engine_of/1) == [%{type: :a}]

  2) test unchecked/3 an AST rule with an enabled check is not reported (Anchor.Domain.RuleCoverageTest)
     test/anchor/domain/rule_coverage_test.exs:164
     ** (UndefinedFunctionError) function Anchor.Domain.RuleCoverage.unchecked/3 is undefined or private. Did you mean:

         * unchecked/2

     code: assert RuleCoverage.unchecked([%{type: :a}], [:a], &engine_of/1) == []
```


## Mutations

| # | Mutation | Result |
|---|---|---|
| C1 | unchecked/3 ignores engine_of | `21 tests, 2 failures` |

### C1: unchecked/3 ignores engine_of

- File mutated: `lib/anchor/domain/rule_coverage.ex`
- Command: `mix test test/anchor/domain/rule_coverage_test.exs`
- Result: `21 tests, 2 failures`

```
  1) test unchecked/3 only the AST rule of a mixed list is reported, in order (Anchor.Domain.RuleCoverageTest)
     test/anchor/domain/rule_coverage_test.exs:168
     Assertion with == failed
     code:  assert RuleCoverage.unchecked(rules, [], &engine_of/1) == [%{type: :a}]
     left:  [%{type: :g}, %{type: :a}, %{type: :g}]
     right: [%{type: :a}]
```
