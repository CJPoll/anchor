# Sabotage record — the one-Fix assertion over the effects canary

- **Domain:** effects
- **Branch:** dnd-5443-graph-rules-b
- **Date:** 2026-11-06
- **Code under test:** `Anchor.Domain.GraphRules.EffectsMatchBucket` (`message/5`)
- **Suite run:** each mutation ran `mix test --force --timeout 2000 --max-cases 2 <its test files>` inside one `test-slot`, by a driver that applied it, ran the files and restored the source. The checkout's absolute path in the output reads `<worktree>`.

EC-G is the one-Fix assertion in `effects_canary_test.exs`. **EC-F is a measured zero:** the last `message/5` clause is a fallback that no (bucket role, inferred role) pair the other clauses leave can reach, so no test can reach it. It is main's code; the MR report proposes a ticket for it.

| # | Mutation | Tests run | Result | Failing tests |
|---|---|---|---|---|
| EC-G | a Manager's effect finding carries no Fix: (`lib/anchor/domain/graph_rules/effects_match_bucket.ex`) | `effects_canary_test.exs` | `3 tests, 1 failure` (red) | the violating modules give one finding per bad function, the compliant none |
| EC-F | the fallback role's finding carries no Fix: (`lib/anchor/domain/graph_rules/effects_match_bucket.ex`) | `effects_canary_test.exs`, `effects_match_bucket_test.exs` | `18 tests, 0 failures` (GREEN: survived) |  |

## EC-G — a Manager's effect finding carries no Fix:

Run summary: `3 tests, 1 failure`

```text
  1) test the violating modules give one finding per bad function, the compliant none (Anchor.Integration.EffectsCanaryTest)
     test/anchor/integration/effects_canary_test.exs:73
     AnchorFixtures.EffectsCanary.Direct.load/1 is in bucket managers (managers) but calls an effect itself: AnchorFixtures.EffectsCanary.Direct.load/1 -> File.read/1. Remedy: move the call into an adapter of this context and call the adapter.
     code: for finding <- report.findings do
     stacktrace:
       (elixir 1.19.4) lib/enum.ex:1688: Enum."-map/2-lists^map/1-1-"/2
       test/anchor/integration/effects_canary_test.exs:97: (test)

.
```

## EC-F — the fallback role's finding carries no Fix:

Run summary: `18 tests, 0 failures`

```text

```
