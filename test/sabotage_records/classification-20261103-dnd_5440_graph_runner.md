# Sabotage record — classifying a whole graph (`classify_all/3`) (DND-5440)

- **Domain:** classification
- **Branch:** dnd-5440-graph-runner
- **Date:** 2026-11-03
- **Code under test:** `Anchor.Domain.Classification.classify_all/3` (DND-5440)
- **Suite run:** Each mutation ran `mix test --timeout 2000 --max-cases 2 <its test files>` inside one `test-slot`, by a driver that applied it, ran the files and restored the source; `git status` after the run showed only this branch's own uncommitted work, unchanged. Every row is red: a non-zero ExUnit result naming the test the mutation is meant to break.

| # | Mutation | Tests run | Result | Failing tests |
|---|---|---|---|---|
| CL-A | an ambiguous module is dropped silently (`lib/anchor/domain/classification.ex`) | `classification_test.exs` | `17 tests, 1 failure` | classify_all/3 an ambiguous module is one issue naming both buckets and both selectors, and is in neither |
| CL-B | bucket floor off by one (`lib/anchor/domain/classification.ex`) | `classification_test.exs` | `17 tests, 1 failure` | classify_all/3 a bucket below min_modules is one issue on the config; at the floor, none |
| CL-C | an unclassified module is dropped silently (`lib/anchor/domain/classification.ex`) | `classification_test.exs`, `graph_test.exs`, `graph_canary_test.exs` | `40 tests, 4 failures` | classify_all/3 an unclassified module is one issue on its file and defmodule line, with Fix: and explain; positive control: the deliberately unclassified module gives exactly one issue; run/2 per-module fail-closed issues (exit 1) an unclassified module is one issue on its source file; run/2 per-module fail-closed issues (exit 1) an Erlang module no bucket classifies is an issue |

## CL-A — an ambiguous module is dropped silently

Run summary: `17 tests, 1 failure`

```

  1) test classify_all/3 an ambiguous module is one issue naming both buckets and both selectors, and is in neither (Anchor.Domain.ClassificationTest)
     test/anchor/domain/classification_test.exs:221
     match (=) failed
     code:  assert {map, [issue]} = Classification.classify_all([both, manager], arch, ".anchor.yml")
     left:  {map, [issue]}
     right: {%{
               MyApp.Accounts.Manager => %Anchor.Domain.Classification{
                 module: MyApp.Accounts.Manager,
                 bucket: "managers",
                 role: :managers,
                 context: "MyApp.Accounts",
                 app: :my_app,
                 source_file: "lib/my_app/managers/accounts.ex",
                 interface?: false
               }
             }, []}
     stacktrace:
       test/anchor/domain/classification_test.exs:232: (test)

..
```

## CL-B — bucket floor off by one

Run summary: `17 tests, 1 failure`

```



  1) test classify_all/3 a bucket below min_modules is one issue on the config; at the floor, none (Anchor.Domain.ClassificationTest)
     test/anchor/domain/classification_test.exs:243
     match (=) failed
     code:  assert {_map, [issue]} = Classification.classify_all([user, manager], arch, "conf/.anchor.yml")
     left:  {_map, [issue]}
     right: {%{
               MyApp.Accounts.User => %Anchor.Domain.Classification{
                 module: MyApp.Accounts.User,
                 bucket: "domain",
                 role: :domain,
                 context: "MyApp.Accounts",
                 app: :my_app,
                 source_file: "lib/my_app/domain/accounts/user.ex",
                 interface?: false
               },
               MyApp.Accounts.Manager => %Anchor.Domain.Classification{
                 module: MyApp.Accounts.Manager,
                 bucket: "managers",
                 role: :managers,
                 context: "MyApp.Accounts",
                 app: :my_app,
                 source_file: "lib/my_app/managers/accounts.ex",
                 interface?: false
               }
             }, []}
     stacktrace:
       test/anchor/domain/classification_test.exs:250: (test)

................
```

## CL-C — an unclassified module is dropped silently

Run summary: `40 tests, 4 failures`

```

  1) test classify_all/3 an unclassified module is one issue on its file and defmodule line, with Fix: and explain (Anchor.Domain.ClassificationTest)
     test/anchor/domain/classification_test.exs:203
     match (=) failed
     code:  assert {map, [issue]} = Classification.classify_all([user, manager, stray], arch, ".anchor.yml")
     left:  {map, [issue]}
     right: {%{
               MyApp.Accounts.User => %Anchor.Domain.Classification{
                 module: MyApp.Accounts.User,
                 bucket: "domain",
                 role: :domain,
                 context: "MyApp.Accounts",
                 app: :my_app,
                 source_file: "lib/my_app/domain/accounts/user.ex",
                 interface?: false
               },
               MyApp.Accounts.Manager => %Anchor.Domain.Classification{
                 module: MyApp.Accounts.Manager,
                 bucket: "managers",
                 role: :managers,
                 context: "MyApp.Accounts",
                 app: :my_app,
                 source_file: "lib/my_app/managers/accounts.ex",
                 interface?: false
               }
             }, []}
     stacktrace:
       test/anchor/domain/classification_test.exs:209: (test)

.........
```
