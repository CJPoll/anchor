# Sabotage record — the architecture: section, parsed fail-closed (DND-5437)

- **Domain:** architecture
- **Branch:** dnd-5437
- **Date:** 2026-11-03
- **Code under test:** `Anchor.Domain.Architecture.parse/1`, `Anchor.Domain.Architecture.Selector` (`parse/2`, `matches?/2`)
- **Tests:** `test/anchor/domain/architecture_checks_nothing_test.exs`, `test/anchor/domain/architecture/selector_test.exs`
- **Suite run:** targeted `mix test <files>` per mutation; full `mix test` green before and after (876 tests, 0 failures)
- **Merge base:** `origin/main` = 185ecc9; **fix commit:** 3e2861e

Fail-first: the code under test is new in this run (absent on 185ecc9), so each
new test first failed as an undefined module or function; the mutations below
are its proof. Each mutation was applied alone to 3e2861e, the named tests run,
and the file restored with `git checkout --`.

A1: with the "no row" refusal gone, the bucket is still refused (its row reads as `nil`, "must be a list"), but with a message that names the wrong fault; the table row asserts the message's leading key path, so it fails. A6 adds a key the parser would read with no table: the meta-tests fail (no table, and the key list drifts from the documented one).

## Mutations

| # | Mutation | Tests failed | Failure string (first failing test) |
|---|---|---|---|
| A1 | drop the 'bucket with no calls row' refusal | 1 failure (`36 tests, 1 failure`) | `calls: every refusal is refused with its key path and Fix:, positives load (Anchor.Domain.ArchitectureChecksNothingTest)`: `calls / a bucket with no row: wrong message (want it to start with "architecture.calls has no row for bucket \"managers\"" and hold Fix:): architecture.calls.managers must be a list of buckets, got: nil. Fix: list the buckets it may call, e.g. [domain, "manage` |
| A2 | paths selectors non-recursive | 7 failures (`28 tests, 7 failures`) | `classify/2 a module two buckets select is ambiguous, names sorted, whatever the config order (Anchor.Domain.ClassificationTest)`: `Assertion with == failed` |
| A3 | accept a match-all pattern selector | 3 failures (`36 tests, 3 failures`) | `buckets[].select: every refusal is refused with its key path and Fix:, positives load (Anchor.Domain.ArchitectureChecksNothingTest)`: `buckets[].select / the second entry is the bad one: LOADED: %Anchor.Config{rules: [], path: nil, architecture: %Anchor.Domain.Architecture{context_depth: 2, buckets: [%Anchor.Domain.Architecture.Bucket{...}], ...}}` |
| A4 | min_modules accepts 0 | 1 failure (`36 tests, 1 failure`) | `buckets[].min_modules: every refusal is refused with its key path and Fix:, positives load (Anchor.Domain.ArchitectureChecksNothingTest)`: `buckets[].min_modules / 0: LOADED: %Anchor.Config{rules: [], path: nil, architecture: %Anchor.Domain.Architecture{context_depth: 2, buckets: [%Anchor.Domain.Architecture.Bucket{...}], ...}}` |
| A5 | unknown key of the section accepted | 1 failure (`36 tests, 1 failure`) | `architecture: every refusal is refused with its key path and Fix:, positives load (Anchor.Domain.ArchitectureChecksNothingTest)`: `architecture / unknown key bucket: LOADED: %Anchor.Config{rules: [], path: nil, architecture: %Anchor.Domain.Architecture{context_depth: 2, buckets: [%Anchor.Domain.Architecture.Bucket{...}], ...}}` |
| A6 | a new section key with no table | 3 failures (`37 tests, 3 failures`) | `the key paths are exactly the documented keys (Anchor.Domain.ArchitectureChecksNothingTest)`: `Assertion with == failed` |
| A7 | an unknown scope suffix reads as :any | 1 failure (`36 tests, 1 failure`) | `calls: every refusal is refused with its key path and Fix:, positives load (Anchor.Domain.ArchitectureChecksNothingTest)`: `calls / an unknown scope suffix: LOADED: %Anchor.Config{rules: [], path: nil, architecture: %Anchor.Domain.Architecture{context_depth: 2, buckets: [%Anchor.Domain.Architecture.Bucket{...}, ...], ...}}` |
| A8 | contexts.depth accepts 0 | 1 failure (`36 tests, 1 failure`) | `contexts.depth: every refusal is refused with its key path and Fix:, positives load (Anchor.Domain.ArchitectureChecksNothingTest)`: `contexts.depth / 0: LOADED: %Anchor.Config{rules: [], path: nil, architecture: %Anchor.Domain.Architecture{context_depth: 0, buckets: [%Anchor.Domain.Architecture.Bucket{...}], ...}}` |
| A9 | interfaces.exports accepts any non-blank string (a glob) | 1 failure (`36 tests, 1 failure`) | `interfaces.exports: every refusal is refused with its key path and Fix:, positives load (Anchor.Domain.ArchitectureChecksNothingTest)`: `interfaces.exports / a glob: LOADED: %Anchor.Config{rules: [], path: nil, architecture: %Anchor.Domain.Architecture{context_depth: 2, buckets: [%Anchor.Domain.Architecture.Bucket{...}, ...], ...}}` |
| A10 | duplicate bucket names accepted | 1 failure (`36 tests, 1 failure`) | `buckets[].name: every refusal is refused with its key path and Fix:, positives load (Anchor.Domain.ArchitectureChecksNothingTest)`: `buckets[].name / duplicate: LOADED: %Anchor.Config{rules: [], path: nil, architecture: %Anchor.Domain.Architecture{context_depth: 2, buckets: [%Anchor.Domain.Architecture.Bucket{...}, ...], ...}}` |
