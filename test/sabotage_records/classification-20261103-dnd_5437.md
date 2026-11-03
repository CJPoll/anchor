# Sabotage record — exactly one bucket, no precedence (DND-5437)

- **Domain:** classification
- **Branch:** dnd-5437
- **Date:** 2026-11-03
- **Code under test:** `Anchor.Domain.Classification` (`classify/2`, `context_of/2`, `bucket_counts/2`)
- **Tests:** `test/anchor/domain/classification_test.exs`
- **Suite run:** targeted `mix test <files>` per mutation; full `mix test` green before and after (876 tests, 0 failures)
- **Merge base:** `origin/main` = 185ecc9; **fix commit:** 3e2861e

Fail-first: the code under test is new in this run (absent on 185ecc9), so each
new test first failed as an undefined module or function; the mutations below
are its proof. Each mutation was applied alone to 3e2861e, the named tests run,
and the file restored with `git checkout --`.

## Mutations

| # | Mutation | Tests failed | Failure string (first failing test) |
|---|---|---|---|
| K1 | classify/2 returns the first matching bucket | 1 failure (`13 tests, 1 failure`) | `classify/2 a module two buckets select is ambiguous, names sorted, whatever the config order (Anchor.Domain.ClassificationTest)`: `Assertion with == failed` |
| K2 | context_of/2 off by one | 2 failures (`13 tests, 2 failures`) | `classify/2 the struct carries the module's app, source file and context (Anchor.Domain.ClassificationTest)`: `match (=) failed` |
| K3 | bucket_counts/2 omits zero-count buckets | 1 failure (`13 tests, 1 failure`) | `bucket_counts/2 a bucket matching nothing is kept, with 0 (Anchor.Domain.ClassificationTest)`: `Assertion with == failed` |
| K4 | interface? ignores interfaces.exports | 1 failure (`13 tests, 1 failure`) | `classify/2 a module listed in interfaces.exports is an interface module (Anchor.Domain.ClassificationTest)`: `match (=) failed` |
