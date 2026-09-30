# Sabotage record — the analysis-crash message (DND-1310)

- **Domain:** failures
- **Branch:** dnd-1310-analyzer-quote-crash
- **Date:** 2026-09-29
- **Code under test:** `Anchor.Domain.Failures.analysis_crash_violation/4` and
  `raised_at/1`
- **Tests:** `test/anchor/domain/failures_test.exs`, describe
  "analysis_crash_violation/4"
- **Suite run:** `mix test` (762 tests; 770 on the review-round head)
- **Merge base:** `origin/main` = a82e01c
- **Other records (same run):** `lint-20260929-dnd_1310_analyzer_quote_crash.md`

## Fail-first

The function is new: the tests could not compile against a82e01c. The message
itself is also pinned by the Lint crash test, which failed first (see the
`lint-` record).

A first draft built the frame text with `Exception.format_stacktrace_entry/1`.
The exact-text test, pinning a frame from an Anchor module, failed on it:

```
left:  "... (raised at (anchor 0.1.0) lib/a.ex:7: Anchor.Domain.DependencyAnalyzer.walk_children/3). Fix: ..."
right: "... (raised at lib/a.ex:7: Anchor.Domain.DependencyAnalyzer.walk_children/3). Fix: ..."
```

That prefix comes from the VM's application table, so the Domain text was not
a function of its inputs (ADR 001; found by the ADR review). `raised_at/1` now
builds the text from the frame alone (`Exception.format_mfa/3` plus the
frame's own file and line), and the test pins the Anchor frame again.

## Mutations

| # | Mutation | Result |
|---|---|---|
| M7 | the argument-list clause of `frame_arity/1` made unreachable (`when is_list(args) and args == :x`), on the review-round head | `770 tests, 1 failure`: `left: "Anchor check Anchor.Check.NoDependency crashed on this file, so it checked no Anchor rule against it: ArgumentError: x (raised at lib/a.ex:7: Sample.Walker.walk_children(nil, %{secret: :state})). Fix: ..."`, `right: "(raised at lib/a.ex:7: Sample.Walker.walk_children/2). Fix: "` |
| S6 | the reason cap raised tenfold (`> @crash_reason_limit * 10`) | `770 tests, 1 failure`: "a long reason is capped at 300 characters", `left: 1043`, `right: 303` |

The review round also made the function `analysis_crash_violation/4`
(`subject, kind, reason, stacktrace`), with `:file_analysis` as a subject and
throws and exits named (`throw: :oops`), and changed the `Fix:` wording to "a
minimal snippet that reproduces it" (the frame's line is in Anchor, not the
user's file).
