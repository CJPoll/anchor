# Sabotage record — exactly one bucket, no precedence (DND-5437)

- **Domain:** classification
- **Branch:** dnd-5437
- **Date:** 2026-11-03
- **Code under test:** `Anchor.Domain.Classification` (`classify/2`, `context_of/2`, `bucket_counts/2`)
- **Tests:** `test/anchor/domain/classification_test.exs`
- **Suite run:** each mutation applied alone to fecac77, then
  `MIX_ENV=test mix compile --force` and the `mix test` command named under it,
  then the file restored with `git checkout --`. The full suite (`mix test`)
  was green before and after.
- **Merge base:** `origin/main` = 185ecc9; **fix commit:** fecac77

## Fail-first

The module is new in this run.

`mix test test/anchor/domain/classification_test.exs` against 185ecc9's `lib/` (and README) with this branch's tests: the test file does not compile.

```
    error: Anchor.Domain.Classification.__struct__/1 is undefined, cannot expand struct Anchor.Domain.Classification. Make sure the struct name is correct. If the struct name exists and is correct but it still cannot be found, you likely have cyclic module usage in your code
    │
 62 │       assert {:ok, %Classification{bucket: "domain", role: :domain, module: MyApp.Accounts.User}} =
    │                    ^
    │
    └─ test/anchor/domain/classification_test.exs:62:20: Anchor.Domain.ClassificationTest."test classify/2 a module one bucket selects is in that bucket"/1
** (CompileError) test/anchor/domain/classification_test.exs: cannot compile module Anchor.Domain.ClassificationTest (errors have been logged)
```


An earlier run of these mutations, without the forced recompile, let two edits of one file inside one second pass Mix's stale check, so a mutation ran on the previous mutation's beams (M4 recorded M3's failure, G2 recorded G1's). The critic caught it; every mutation here is from the forced-recompile run.

## Mutations

| # | Mutation | Result |
|---|---|---|
| K1 | classify/2 returns the first matching bucket | `13 tests, 1 failure` |
| K2 | context_of/2 off by one | `13 tests, 2 failures` |
| K3 | bucket_counts/2 omits zero-count buckets | `13 tests, 1 failure` |
| K4 | interface? ignores interfaces.exports | `13 tests, 1 failure` |
| M23 | interface? ignores interfaces.buckets | `13 tests, 1 failure` |
| M24 | an unclassified module reads as ambiguous with no buckets | `13 tests, 2 failures` |

### K1: classify/2 returns the first matching bucket

- File mutated: `lib/anchor/domain/classification.ex`
- Command: `MIX_ENV=test mix compile --force && mix test test/anchor/domain/classification_test.exs`
- Result: `13 tests, 1 failure`

```
  1) test classify/2 a module two buckets select is ambiguous, names sorted, whatever the config order (Anchor.Domain.ClassificationTest)
     test/anchor/domain/classification_test.exs:73
     Assertion with == failed
     code:  assert Classification.classify(facts, architecture([@domain, @framework])) == expected
     left:  {:ok,
             %Anchor.Domain.Classification{
               module: MyApp.Domain.Worker,
               bucket: "domain",
               role: :domain,
               context: "MyApp.Domain",
               app: :my_app,
               source_file: "lib/my_app/domain/worker.ex",
               interface?: false
             }}
     right: {:error, {:ambiguous, MyApp.Domain.Worker, ["domain", "framework"]}}
```

### K2: context_of/2 off by one

- File mutated: `lib/anchor/domain/classification.ex`
- Command: `MIX_ENV=test mix compile --force && mix test test/anchor/domain/classification_test.exs`
- Result: `13 tests, 2 failures`

```
  1) test context_of/2 is the first depth segments (Anchor.Domain.ClassificationTest)
     test/anchor/domain/classification_test.exs:139
     Assertion with == failed
     code:  assert Classification.context_of(MyApp.Accounts.Users, 2) == "MyApp.Accounts"
     left:  "MyApp.Accounts.Users"
     right: "MyApp.Accounts"
```

### K3: bucket_counts/2 omits zero-count buckets

- File mutated: `lib/anchor/domain/classification.ex`
- Command: `MIX_ENV=test mix compile --force && mix test test/anchor/domain/classification_test.exs`
- Result: `13 tests, 1 failure`

```
  1) test bucket_counts/2 a bucket matching nothing is kept, with 0 (Anchor.Domain.ClassificationTest)
     test/anchor/domain/classification_test.exs:166
     Assertion with == failed
     code:  assert names_and_counts(Classification.bucket_counts([facts(MyApp.D, "lib/a/domain/d.ex")], arch)) == [
              {"domain", 1},
              {"managers", 0}
            ]
     left:  [{"domain", 1}]
     right: [{"domain", 1}, {"managers", 0}]
```

### K4: interface? ignores interfaces.exports

- File mutated: `lib/anchor/domain/classification.ex`
- Command: `MIX_ENV=test mix compile --force && mix test test/anchor/domain/classification_test.exs`
- Result: `13 tests, 1 failure`

```
  1) test classify/2 a module listed in interfaces.exports is an interface module (Anchor.Domain.ClassificationTest)
     test/anchor/domain/classification_test.exs:114
     match (=) failed
     code:  assert {:ok, %Classification{bucket: "domain", interface?: true}} =
              Classification.classify(facts(MyApp.Accounts.Api, "lib/a/domain/api.ex"), arch)
     left:  {:ok, %Anchor.Domain.Classification{bucket: "domain", interface?: true}}
     right: {:ok,
             %Anchor.Domain.Classification{
               module: MyApp.Accounts.Api,
               bucket: "domain",
               role: :domain,
               context: "MyApp.Accounts",
               app: :my_app,
               source_file: "lib/a/domain/api.ex",
               interface?: false
             }}
```

### M23: interface? ignores interfaces.buckets

- File mutated: `lib/anchor/domain/classification.ex`
- Command: `MIX_ENV=test mix compile --force && mix test test/anchor/domain/classification_test.exs`
- Result: `13 tests, 1 failure`

```
  1) test classify/2 a module of an interface bucket is an interface module (Anchor.Domain.ClassificationTest)
     test/anchor/domain/classification_test.exs:104
     match (=) failed
     code:  assert {:ok, %Classification{interface?: true}} =
              Classification.classify(facts(MyApp.Accounts, "lib/a/managers/accounts.ex"), arch)
     left:  {:ok, %Anchor.Domain.Classification{interface?: true}}
     right: {:ok,
             %Anchor.Domain.Classification{
               module: MyApp.Accounts,
               bucket: "managers",
               role: :managers,
               context: "MyApp.Accounts",
               app: :my_app,
               source_file: "lib/a/managers/accounts.ex",
               interface?: false
             }}
```

### M24: an unclassified module reads as ambiguous with no buckets

- File mutated: `lib/anchor/domain/classification.ex`
- Command: `MIX_ENV=test mix compile --force && mix test test/anchor/domain/classification_test.exs`
- Result: `13 tests, 2 failures`

```
  1) test classify/2 each selector kind classifies on its own (Anchor.Domain.ClassificationTest)
     test/anchor/domain/classification_test.exs:81
     ** (MatchError) no match of right hand side value:

         {:error, {:ambiguous, MyApp.Other, []}}

     code: for {selector, overrides} <- by_kind do
```
