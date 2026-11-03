# Sabotage record — Credo's floors skip graph-engine rules (DND-5440)

- **Domain:** rule_coverage
- **Branch:** dnd-5440-graph-runner
- **Date:** 2026-11-03
- **Code under test:** `Anchor.Domain.RuleCoverage.below_floor/3` and `missing_allowed_callers/3` skipping graph-engine rules (DND-5440)
- **Suite run:** Each mutation ran `mix test --timeout 2000 --max-cases 2 <its test files>` inside one `test-slot`, by a driver that applied it, ran the files and restored the source; `git status` after the run showed only this branch's own uncommitted work, unchanged. Every row is red: a non-zero ExUnit result naming the test the mutation is meant to break.

| # | Mutation | Tests run | Result | Failing tests |
|---|---|---|---|---|
| RC-A | graph rules judged by Credo's file floor (`lib/anchor/domain/rule_coverage.ex`) | `rule_coverage_test.exs` | `24 tests, 3 failures` | below_floor/3 and missing_allowed_callers/3 skip graph rules positive control: an AST rule's floor still fires beside it; below_floor/3 and missing_allowed_callers/3 skip graph rules a graph rule's allowed callers are not reported; an AST rule's still are; below_floor/3 and missing_allowed_callers/3 skip graph rules a graph rule with a floor it cannot meet is not reported |

## RC-A — graph rules judged by Credo's file floor

Run summary: `24 tests, 3 failures`

```

  1) test below_floor/3 and missing_allowed_callers/3 skip graph rules positive control: an AST rule's floor still fires beside it (Anchor.Domain.RuleCoverageTest)
     test/anchor/domain/rule_coverage_test.exs:195
     Assertion with == failed
     code:  assert RuleCoverage.below_floor([graph_rule, ast_rule], [@lib_a], &graph_engine_of/1) == [{ast_rule, 0}]
     left:  [
              {%{type: :g, paths: ["nowhere/*.ex"]}, 0},
              {%{
                 type: :must_use_module,
                 recursive: false,
                 paths: ["nowhere/*.ex"]
               }, 0}
            ]
     right: [
              {%{
                 type: :must_use_module,
                 recursive: false,
                 paths: ["nowhere/*.ex"]
               }, 0}
            ]
     stacktrace:
       test/anchor/domain/rule_coverage_test.exs:199: (test)

...
```
