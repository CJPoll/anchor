# Sabotage record — check_file/3 reports a crash too (DND-1310)

- **Domain:** base
- **Branch:** dnd-1310-analyzer-quote-crash
- **Date:** 2026-09-29
- **Code under test:** `Anchor.Check.Base`'s generated `check_file/3`, which
  now routes detection through `Anchor.Managers.Lint.detect_file/5`
- **Tests:** `test/anchor/managers/lint_analysis_crash_test.exs`, "the
  Framework entry reports it as one Credo issue on that file, at higher
  priority"
- **Suite run:** `mix test` (762 tests)
- **Merge base:** `origin/main` = a82e01c
- **Other records (same run):** `lint-20260929-dnd_1310_analyzer_quote_crash.md`

## Fail-first

Against unfixed a82e01c:

```
4) test the Framework entry reports it as one Credo issue on that file, at higher priority
   ** (ArgumentError) injected by the test
   test/anchor/managers/lint_analysis_crash_test.exs:28: Anchor.Managers.LintAnalysisCrashTest.RaisingCheck.check_file/3
```

## Mutations

| # | Mutation | Result |
|---|---|---|
| M4 | `check_file/3` calls `detect_violations/4` directly again | `762 tests, 1 failure`: that test, `** (ArgumentError) injected by the test` |
