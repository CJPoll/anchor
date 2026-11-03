# Sabotage record — describing a selector (DND-5440)

- **Domain:** architecture
- **Branch:** dnd-5440-graph-runner
- **Date:** 2026-11-03
- **Code under test:** `Anchor.Domain.Architecture.Selector.describe/1` (DND-5440)
- **Suite run:** Each mutation ran `mix test --timeout 2000 --max-cases 2 <its test files>` inside one `test-slot`, by a driver that applied it, ran the files and restored the source; `git status` after the run showed only this branch's own uncommitted work, unchanged. Every row is red: a non-zero ExUnit result naming the test the mutation is meant to break.

| # | Mutation | Tests run | Result | Failing tests |
|---|---|---|---|---|
| SEL-A | a pattern selector described without its quotes (`lib/anchor/domain/architecture/selector.ex`) | `selector_describe_test.exs` | `1 test, 1 failure` | describe/1 writes each selector kind as the config spells it |

## SEL-A — a pattern selector described without its quotes

Run summary: `1 test, 1 failure`

```



  1) test describe/1 writes each selector kind as the config spells it (Anchor.Domain.Architecture.SelectorDescribeTest)
     test/anchor/domain/architecture/selector_describe_test.exs:19
     Assertion with == failed
     code:  assert Selector.describe(selector) == text
     left:  "pattern Mix.Tasks.*"
     right: "pattern \"Mix.Tasks.*\""
     stacktrace:
       test/anchor/domain/architecture/selector_describe_test.exs:20: anonymous fn/2 in Anchor.Domain.Architecture.SelectorDescribeTest."test describe/1 writes each selector kind as the config spells it"/1
       (elixir 1.19.4) lib/enum.ex:2520: Enum."-reduce/3-lists^foldl/2-0-"/3
       test/anchor/domain/architecture/selector_describe_test.exs:20: (test)
```
