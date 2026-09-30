# Sabotage record — the analysis-crash message (DND-1310)

- **Domain:** failures
- **Branch:** dnd-1310-analyzer-quote-crash
- **Date:** 2026-09-29
- **Code under test:** `Anchor.Domain.Failures.analysis_crash_violation/3` and
  `raised_at/1`
- **Tests:** `test/anchor/domain/failures_test.exs`, describe
  "analysis_crash_violation/3"
- **Suite run:** `mix test` (762 tests)
- **Merge base:** `origin/main` = a82e01c
- **Other records (same run):** `lint-20260929-dnd_1310_analyzer_quote_crash.md`

## Fail-first

The function is new: the tests could not compile against a82e01c. The message
itself is also pinned by the Lint crash test, which failed first (see the
`lint-` record).

A first draft of the exact-text test pinned a frame from an Anchor module and
failed on `(anchor 0.1.0)`, the application prefix
`Exception.format_stacktrace_entry/1` adds. The test now uses a module in no
application, so the text does not depend on Anchor's version.

## Mutations

| # | Mutation | Result |
|---|---|---|
| M7 | the argument-list frame clause of `raised_at/1` made unreachable (`when is_list(args) and args == :x`) | `762 tests, 1 failure`: `left: "... (raised at lib/a.ex:7: Sample.Walker.walk_children(nil, %{secret: :state})). Fix: ..."`, `right: "(raised at lib/a.ex:7: Sample.Walker.walk_children/2). Fix: "` |
