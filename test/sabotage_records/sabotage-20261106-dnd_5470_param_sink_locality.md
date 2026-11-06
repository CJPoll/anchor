# Sabotage record — behaviour locality

- **Domain:** sabotage
- **Branch:** dnd-5470-param-sink-locality
- **Date:** 2026-11-06
- **Code under test:** `Anchor.Domain.Sabotage.BehaviourMap`, `Anchor.Domain.Sabotage.Report`'s behaviours view, `Anchor.Managers.Sabotage.Behaviours`, the `behaviour_locality_*` keys of `Anchor.Domain.Sabotage.Config`, `Anchor.Adapters.SourceReader.list/1`, `CoverageMap.check/1`'s name, and `Mix.Tasks.Anchor.Sabotage.behaviours_facts/1`
- **Suite run:** each mutation ran `mix test --timeout 2000 --max-cases 2 <its test files>` inside one `test-slot`, by a driver that applied it, ran the files and restored the source. The checkout's absolute path in the output reads `<worktree>`.

Every mutation below reddens a test; each section shows the first failure, cut at 70 lines. BH-A, BH-B and BH-C are the three breaks the QA plan requires: executed causes instead of confirmed ones, the line in the test key, a generated module counted as a directory.

BR-F, BR-G and BM-E first reported no summary, because their first wording left a function or a variable unused and warnings are errors here. They were reworded to keep it used, and re-run.

| # | Mutation | Tests run | Result | Failing tests |
|---|---|---|---|---|
| BH-A | executed counts instead of confirmed (`lib/anchor/domain/sabotage/behaviour_map.ex`) | `behaviour_map_test.exs` | `24 tests, 6 failures` (red) | build/3 a test no kill row names is unconfirmed; build/3 a test killing a function the map says it never ran confirms nothing, and is counted; build/3 an executed-only function with no source shows as generated, for display only; build/3 only a killed row confirms: every other status, with a killer, is no evidence; build/3 a function only executed is no cause and no directory; build/3 a row killed by another test confirms nothing here |
| BH-B | the line is in the test key (`lib/anchor/domain/sabotage/behaviour_map.ex`) | `behaviour_map_test.exs` | `24 tests, 13 failures` (red) | build/3 an executed-only function with no source shows as generated, for display only; build/3 a function recorded in two files counts both: an old record cannot hide one; build/3 a test killing a function the map says it never ran confirms nothing, and is counted; build/3 a kill row at another line than the map's still matches; build/3 two functions in one directory are one directory; build/3 two tests with one key are one behaviour, their functions together; build/3 a function with no Elixir module name has no module to look up; build/3 a row killed by another test confirms nothing here; build/3 a function only executed is no cause and no directory; build/3 a killer naming no test of the map, and an unreadable one, are both said; build/3 a test that killed a mutant of each function it ran: both confirmed, both directories; build/3 a row with no file falls back to the module's source file; build/3 a confirmed function with no source file: no directory, shown as generated |
| BH-C | a generated module counts as a directory (`lib/anchor/domain/sabotage/behaviour_map.ex`) | `behaviour_map_test.exs` | `24 tests, 3 failures` (red) | build/3 a confirmed function with no source file: no directory, shown as generated; build/3 a row with no file falls back to the module's source file; build/3 a function with no Elixir module name has no module to look up |
| BH-D | any status confirms (`lib/anchor/domain/sabotage/behaviour_map.ex`) | `behaviour_map_test.exs` | `24 tests, 1 failure` (red) | build/3 only a killed row confirms: every other status, with a killer, is no evidence |
| BH-E | a key once per behaviour, not per directory (`lib/anchor/domain/sabotage/behaviour_map.ex`) | `behaviour_map_test.exs` | `24 tests, 2 failures` (red) | locality_keys/1 a behaviour with only generated causes adds no key; locality_keys/1 a behaviour's key once per directory |
| BH-F | the narrowest first (`lib/anchor/domain/sabotage/behaviour_map.ex`) | `behaviour_map_test.exs` | `24 tests, 1 failure` (red) | top/2 the widest first, ties by key, at most n |
| BH-G | top takes everything (`lib/anchor/domain/sabotage/behaviour_map.ex`) | `behaviour_map_test.exs` | `24 tests, 1 failure` (red) | top/2 the widest first, ties by key, at most n |
| BH-H | the name is not trimmed (`lib/anchor/domain/sabotage/behaviour_map.ex`) | `behaviour_map_test.exs` | `24 tests, 1 failure` (red) | test_key/2 holds no line, and stays one trimmed baseline line |
| BH-I | a line break stays in the key (`lib/anchor/domain/sabotage/behaviour_map.ex`) | `behaviour_map_test.exs` | `24 tests, 1 failure` (red) | test_key/2 holds no line, and stays one trimmed baseline line |
| BH-J | unmatched killers read as matched (`lib/anchor/domain/sabotage/behaviour_map.ex`) | `behaviour_map_test.exs` | `24 tests, 3 failures` (red) | build/3 a killer naming no test of the map, and an unreadable one, are both said; build/3 a row killed by another test confirms nothing here; build/3 a test killing a function the map says it never ran confirms nothing, and is counted |
| BH-K | kills of functions not executed are not counted (`lib/anchor/domain/sabotage/behaviour_map.ex`) | `behaviour_map_test.exs` | `24 tests, 1 failure` (red) | build/3 a test killing a function the map says it never ran confirms nothing, and is counted |
| BH-L | any entry is well formed (`lib/anchor/domain/sabotage/behaviour_map.ex`) | `behaviour_map_test.exs` | `24 tests, 1 failure` (red) | malformed/1 an entry needs a file and a test name |
| BH-M | the last file wins a module (`lib/anchor/domain/sabotage/behaviour_map.ex`) | `behaviour_map_test.exs` | `24 tests, 1 failure` (red) | files_by_module/1 each module's file; an unreadable file names none; the first file sorted wins |
| BH-N | two tests with one key keep only one (`lib/anchor/domain/sabotage/behaviour_map.ex`) | `behaviour_map_test.exs` | `24 tests, 1 failure` (red) | build/3 two tests with one key are one behaviour, their functions together |
| BH-O | a blank row file is a file (`lib/anchor/domain/sabotage/behaviour_map.ex`) | `behaviour_map_test.exs` | `24 tests, 3 failures` (red) | build/3 a function with no Elixir module name has no module to look up; build/3 a confirmed function with no source file: no directory, shown as generated; build/3 a row with no file falls back to the module's source file |
| BH-P | an executed-only generated function shows nothing (`lib/anchor/domain/sabotage/behaviour_map.ex`) | `behaviour_map_test.exs` | `24 tests, 1 failure` (red) | build/3 an executed-only function with no source shows as generated, for display only |
| BH-Q | only one of a function's files counts (`lib/anchor/domain/sabotage/behaviour_map.ex`) | `behaviour_map_test.exs` | `24 tests, 1 failure` (red) | build/3 a function recorded in two files counts both: an old record cannot hide one |
| BH-R | the module of an mfa is read wrong (`lib/anchor/domain/sabotage/behaviour_map.ex`) | `behaviour_map_test.exs` | `24 tests, 2 failures` (red) | build/3 a row with no file falls back to the module's source file; build/3 a function with no Elixir module name has no module to look up |
| BH-S | an unconfirmed test is a behaviour (`lib/anchor/domain/sabotage/behaviour_map.ex`) | `behaviour_map_test.exs` | `24 tests, 4 failures` (red) | build/3 a test killing a function the map says it never ran confirms nothing, and is counted; build/3 a row killed by another test confirms nothing here; build/3 only a killed row confirms: every other status, with a killer, is no evidence; build/3 a test no kill row names is unconfirmed |
| BR-A | report mode fails on drift (`lib/anchor/domain/sabotage/report.ex`) | `sabotage_behaviours_test.exs` | `29 tests, 3 failures` (red) | the ratchet the default path absent: every key is NEW, said loudly; the ratchet report mode, one NEW: exit 0, printed; the views json says the whole picture |
| BR-B | enforce never fails (`lib/anchor/domain/sabotage/report.ex`) | `sabotage_behaviours_test.exs` | `29 tests, 3 failures` (red) | the ratchet enforce mode, one NEW: exit 1; the ratchet enforce mode, an entry the branch added: GREW, exit 1; the ratchet enforce mode, one STALE: exit 1 |
| BR-C | STALE is no drift (`lib/anchor/domain/sabotage/report.ex`) | `sabotage_behaviours_test.exs` | `29 tests, 1 failure` (red) | the ratchet enforce mode, one STALE: exit 1 |
| BR-D | GREW is no drift (`lib/anchor/domain/sabotage/report.ex`) | `sabotage_behaviours_test.exs` | `29 tests, 1 failure` (red) | the ratchet enforce mode, an entry the branch added: GREW, exit 1 |
| BR-E | the notes are dropped (`lib/anchor/domain/sabotage/report.ex`) | `sabotage_behaviours_test.exs` | `29 tests, 2 failures` (red) | the views killers and sources that did not line up are said; the ratchet the default path absent: every key is NEW, said loudly |
| BR-F | the unmatched killers are not said (`lib/anchor/domain/sabotage/report.ex`) | `sabotage_behaviours_test.exs` | `29 tests, 1 failure` (red) | the views killers and sources that did not line up are said |
| BR-G | the unexecuted kills are not said (`lib/anchor/domain/sabotage/report.ex`) | `sabotage_behaviours_test.exs` | `29 tests, 1 failure` (red) | the views killers and sources that did not line up are said |
| BR-H | a generated cause is not shown (`lib/anchor/domain/sabotage/report.ex`) | `sabotage_behaviours_test.exs` | `29 tests, 1 failure` (red) | the views a confirmed cause with no source shows generated on its line |
| BM-A | the config's map beats --coverage (`lib/anchor/managers/sabotage/behaviours.ex`) | `sabotage_behaviours_test.exs` | `29 tests, 1 failure` (red) | what cannot be measured is exit 3, never a clean report --coverage wins over the configured map |
| BM-B | no map is not refused for zero tests (`lib/anchor/managers/sabotage/behaviours.ex`) | `sabotage_behaviours_test.exs` | `29 tests, 1 failure` (red) | what cannot be measured is exit 3, never a clean report a map with zero tests |
| BM-C | an unchecked term is taken as a map (`lib/anchor/managers/sabotage/behaviours.ex`) | `sabotage_behaviours_test.exs` | `29 tests, 1 failure` (red) | what cannot be measured is exit 3, never a clean report a term that is no map |
| BM-D | no killed row still measures (`lib/anchor/managers/sabotage/behaviours.ex`) | `sabotage_behaviours_test.exs` | `29 tests, 1 failure` (red) | what cannot be measured is exit 3, never a clean report records with no killed row |
| BM-E | an unreadable record is skipped (`lib/anchor/managers/sabotage/behaviours.ex`) | `sabotage_behaviours_test.exs` | `29 tests, 2 failures` (red) | what cannot be measured is exit 3, never a clean report a record that cannot be read names it; what cannot be measured is exit 3, never a clean report a record that cannot be parsed names it and the line |
| BM-F | the default path absent is a failure (`lib/anchor/managers/sabotage/behaviours.ex`) | `sabotage_behaviours_test.exs` | `29 tests, 2 failures` (red) | the ratchet the default path absent: every key is NEW, said loudly; the ratchet a named baseline absent: exit 1, in report mode too |
| BM-G | a malformed baseline is not refused (`lib/anchor/managers/sabotage/behaviours.ex`) | `sabotage_behaviours_test.exs` | `29 tests, 1 failure` (red) | the ratchet a malformed baseline: exit 1, in report mode too |
| BM-H | a first landing is refused (`lib/anchor/managers/sabotage/behaviours.ex`) | `sabotage_behaviours_test.exs` | `29 tests, 1 failure` (red) | the ratchet a first landing has no base copy, so nothing grew |
| BM-I | an unreadable base is no growth (`lib/anchor/managers/sabotage/behaviours.ex`) | `sabotage_behaviours_test.exs` | `29 tests, 1 failure` (red) | what cannot be measured is exit 3, never a clean report a base that cannot be read is no growth it could vouch for |
| BM-J | --write-baseline over a file exits 0 (`lib/anchor/managers/sabotage/behaviours.ex`) | `sabotage_behaviours_test.exs` | `29 tests, 1 failure` (red) | --write-baseline an existing file: exit 2, left as it is |
| BM-K | --write-baseline is ignored (`lib/anchor/managers/sabotage/behaviours.ex`) | `sabotage_behaviours_test.exs` | `29 tests, 3 failures` (red) | --write-baseline no file: created with the sorted keys; --write-baseline a path it cannot write: exit 3; --write-baseline an existing file: exit 2, left as it is |
| BM-L | a baseline that is not UTF-8 reads as could not measure (`lib/anchor/managers/sabotage/behaviours.ex`) | `sabotage_behaviours_test.exs` | `29 tests, 1 failure` (red) | the ratchet a baseline that is not UTF-8: exit 1 |
| BC-A | enforce reads as report (`lib/anchor/domain/sabotage/config.ex`) | `config_test.exs` | `7 tests, 1 failure` (red) | parse/1 every key is read |
| BC-B | a baseline path outside the project passes (`lib/anchor/domain/sabotage/config.ex`) | `config_test.exs` | `7 tests, 1 failure` (red) | parse/1 2: each refusal names its key and ends with a Fix: line |
| BS-A | apps are not listed (`lib/anchor/adapters/source_reader.ex`) | `source_reader_test.exs` | `3 tests, 1 failure` (red) | list/1: the project's lib sources, relative and sorted, and nothing else |
| BS-B | paths stay absolute (`lib/anchor/adapters/source_reader.ex`) | `source_reader_test.exs` | `3 tests, 1 failure` (red) | list/1: the project's lib sources, relative and sorted, and nothing else |
| BK-A | a nameless test passes the check (`lib/anchor/domain/sabotage/coverage_map.ex`) | `coverage_map_test.exs` | `27 tests, 1 failure` (red) | check/1, a test's name |
| BT-A | --write-baseline defaults on (`lib/mix/tasks/anchor.sabotage.ex`) | `anchor_sabotage_behaviours_test.exs` | `6 tests, 1 failure` (red) | the facts: each flag, and what its absence means |

## BH-A — executed counts instead of confirmed

Run summary: `24 tests, 6 failures`

```text
1) test build/3 a test no kill row names is unconfirmed (Anchor.Domain.Sabotage.BehaviourMapTest)
     test/anchor/domain/sabotage/behaviour_map_test.exs:77
     Assertion with == failed
     code:  assert result.behaviours == []
     left:  [
              %Anchor.Domain.Sabotage.BehaviourMap.Behaviour{
                test_key: "test/t_test.exs::test t does it",
                executed: ["A.f/0"],
                confirmed: ["A.f/0"],
                directories: [],
                generated: ["A.f/0"],
                executed_only: [],
                executed_only_directories: []
              }
            ]
     right: []
     stacktrace:
       test/anchor/domain/sabotage/behaviour_map_test.exs:80: (test)

....
```

## BH-B — the line is in the test key

Run summary: `24 tests, 13 failures`

```text
1) test build/3 an executed-only function with no source shows as generated, for display only (Anchor.Domain.Sabotage.BehaviourMapTest)
     test/anchor/domain/sabotage/behaviour_map_test.exs:66
     match (=) failed
     code:  assert [%Behaviour{} = behaviour] = result.behaviours
     left:  [%Anchor.Domain.Sabotage.BehaviourMap.Behaviour{} = behaviour]
     right: []
     stacktrace:
       test/anchor/domain/sabotage/behaviour_map_test.exs:30: Anchor.Domain.Sabotage.BehaviourMapTest.one/1
       test/anchor/domain/sabotage/behaviour_map_test.exs:74: (test)
```

## BH-C — a generated module counts as a directory

Run summary: `24 tests, 3 failures`

```text
1) test build/3 a confirmed function with no source file: no directory, shown as generated (Anchor.Domain.Sabotage.BehaviourMapTest)
     test/anchor/domain/sabotage/behaviour_map_test.exs:108
     Assertion with == failed
     code:  assert behaviour.directories == []
     left:  ["(generated)"]
     right: []
     stacktrace:
       test/anchor/domain/sabotage/behaviour_map_test.exs:113: (test)

..........
```

## BH-D — any status confirms

Run summary: `24 tests, 1 failure`

```text
1) test build/3 only a killed row confirms: every other status, with a killer, is no evidence (Anchor.Domain.Sabotage.BehaviourMapTest)
     test/anchor/domain/sabotage/behaviour_map_test.exs:92
     timeout
     code: for status <- ~w(timeout survived no_tests invalid crashed) do
     stacktrace:
       test/anchor/domain/sabotage/behaviour_map_test.exs:96: anonymous fn/2 in Anchor.Domain.Sabotage.BehaviourMapTest."test build/3 only a killed row confirms: every other status, with a killer, is no evidence"/1
       (elixir 1.19.4) lib/enum.ex:2520: Enum."-reduce/3-lists^foldl/2-0-"/3
       test/anchor/domain/sabotage/behaviour_map_test.exs:93: (test)
```

## BH-E — a key once per behaviour, not per directory

Run summary: `24 tests, 2 failures`

```text
1) test locality_keys/1 a behaviour with only generated causes adds no key (Anchor.Domain.Sabotage.BehaviourMapTest)
     test/anchor/domain/sabotage/behaviour_map_test.exs:199
     Assertion with == failed
     code:  assert BehaviourMap.locality_keys(%{behaviours: [behaviour(@t_key, [])]}) == []
     left:  ["test/t_test.exs::test t does it"]
     right: []
     stacktrace:
       test/anchor/domain/sabotage/behaviour_map_test.exs:200: (test)
```

## BH-F — the narrowest first

Run summary: `24 tests, 1 failure`

```text
1) test top/2 the widest first, ties by key, at most n (Anchor.Domain.Sabotage.BehaviourMapTest)
     test/anchor/domain/sabotage/behaviour_map_test.exs:205
     Assertion with == failed
     code:  assert result |> BehaviourMap.top(3) |> Enum.map(& &1.test_key) == ["b", "a", "c"]
     left:  ["a", "c", "d"]
     right: ["b", "a", "c"]
     stacktrace:
       test/anchor/domain/sabotage/behaviour_map_test.exs:215: (test)

...........
```

## BH-G — top takes everything

Run summary: `24 tests, 1 failure`

```text
1) test top/2 the widest first, ties by key, at most n (Anchor.Domain.Sabotage.BehaviourMapTest)
     test/anchor/domain/sabotage/behaviour_map_test.exs:205
     Assertion with == failed
     code:  assert result |> BehaviourMap.top(3) |> Enum.map(& &1.test_key) == ["b", "a", "c"]
     left:  ["b", "a", "c", "d"]
     right: ["b", "a", "c"]
     stacktrace:
       test/anchor/domain/sabotage/behaviour_map_test.exs:215: (test)

.............
```

## BH-H — the name is not trimmed

Run summary: `24 tests, 1 failure`

```text
1) test test_key/2 holds no line, and stays one trimmed baseline line (Anchor.Domain.Sabotage.BehaviourMapTest)
     test/anchor/domain/sabotage/behaviour_map_test.exs:183
     Assertion with == failed
     code:  assert BehaviourMap.test_key("test/a_test.exs", " test a\nb\r ") == "test/a_test.exs::test a\\nb"
     left:  "test/a_test.exs:: test a\\nb\\r "
     right: "test/a_test.exs::test a\\nb"
     stacktrace:
       test/anchor/domain/sabotage/behaviour_map_test.exs:184: (test)

.......
```

## BH-I — a line break stays in the key

Run summary: `24 tests, 1 failure`

```text
1) test test_key/2 holds no line, and stays one trimmed baseline line (Anchor.Domain.Sabotage.BehaviourMapTest)
     test/anchor/domain/sabotage/behaviour_map_test.exs:183
     Assertion with == failed
     code:  assert BehaviourMap.test_key("test/a_test.exs", " test a\nb\r ") == "test/a_test.exs::test a\\nb"
     left:  "test/a_test.exs::test a\nb"
     right: "test/a_test.exs::test a\\nb"
     stacktrace:
       test/anchor/domain/sabotage/behaviour_map_test.exs:184: (test)

..................
```

## BH-J — unmatched killers read as matched

Run summary: `24 tests, 3 failures`

```text
1) test build/3 a killer naming no test of the map, and an unreadable one, are both said (Anchor.Domain.Sabotage.BehaviourMapTest)
     test/anchor/domain/sabotage/behaviour_map_test.exs:157
     Assertion with == failed
     code:  assert result.unmatched_killers == ["test/gone_test.exs::test gone", "no line here"]
     left:  ["test/t_test.exs::test t does it", "no line here"]
     right: ["test/gone_test.exs::test gone", "no line here"]
     stacktrace:
       test/anchor/domain/sabotage/behaviour_map_test.exs:168: (test)

....
```

## BH-K — kills of functions not executed are not counted

Run summary: `24 tests, 1 failure`

```text
1) test build/3 a test killing a function the map says it never ran confirms nothing, and is counted (Anchor.Domain.Sabotage.BehaviourMapTest)
     test/anchor/domain/sabotage/behaviour_map_test.exs:171
     Assertion with == failed
     code:  assert result.not_executed == 1
     left:  0
     right: 1
     stacktrace:
       test/anchor/domain/sabotage/behaviour_map_test.exs:177: (test)

...................
```

## BH-L — any entry is well formed

Run summary: `24 tests, 1 failure`

```text
1) test malformed/1 an entry needs a file and a test name (Anchor.Domain.Sabotage.BehaviourMapTest)
     test/anchor/domain/sabotage/behaviour_map_test.exs:220
     Assertion with == failed
     code:  assert BehaviourMap.malformed(["a::b", "no key", "::b", "a::"]) == ["no key", "::b", "a::"]
     left:  ["no key"]
     right: ["no key", "::b", "a::"]
     stacktrace:
       test/anchor/domain/sabotage/behaviour_map_test.exs:221: (test)

...........
```

## BH-M — the last file wins a module

Run summary: `24 tests, 1 failure`

```text
1) test files_by_module/1 each module's file; an unreadable file names none; the first file sorted wins (Anchor.Domain.Sabotage.BehaviourMapTest)
     test/anchor/domain/sabotage/behaviour_map_test.exs:226
     Assertion with == failed
     code:  assert BehaviourMap.files_by_module(facts) == %{
              "A" => "lib/a.ex",
              "B" => "lib/b.ex",
              "Both" => "lib/a.ex"
            }
     left:  %{"A" => "lib/a.ex", "B" => "lib/b.ex", "Both" => "lib/b.ex"}
     right: %{"A" => "lib/a.ex", "B" => "lib/b.ex", "Both" => "lib/a.ex"}
     stacktrace:
       test/anchor/domain/sabotage/behaviour_map_test.exs:233: (test)

........
```

## BH-N — two tests with one key keep only one

Run summary: `24 tests, 1 failure`

```text
1) test build/3 two tests with one key are one behaviour, their functions together (Anchor.Domain.Sabotage.BehaviourMapTest)
     test/anchor/domain/sabotage/behaviour_map_test.exs:149
     Assertion with == failed
     code:  assert one(BehaviourMap.build(map(tests), rows, %{})).directories == ["lib/a", "lib/b"]
     left:  ["lib/a"]
     right: ["lib/a", "lib/b"]
     stacktrace:
       test/anchor/domain/sabotage/behaviour_map_test.exs:154: (test)

.....................
```

## BH-O — a blank row file is a file

Run summary: `24 tests, 3 failures`

```text
1) test build/3 a function with no Elixir module name has no module to look up (Anchor.Domain.Sabotage.BehaviourMapTest)
     test/anchor/domain/sabotage/behaviour_map_test.exs:128
     Assertion with == failed
     code:  assert one(BehaviourMap.build(map([test_ref([":erl.f/0"])]), [row], %{"erl" => "lib/x.ex"})).generated ==
              [":erl.f/0"]
     left:  []
     right: [":erl.f/0"]
     stacktrace:
       test/anchor/domain/sabotage/behaviour_map_test.exs:131: (test)

......
```

## BH-P — an executed-only generated function shows nothing

Run summary: `24 tests, 1 failure`

```text
1) test build/3 an executed-only function with no source shows as generated, for display only (Anchor.Domain.Sabotage.BehaviourMapTest)
     test/anchor/domain/sabotage/behaviour_map_test.exs:66
     Assertion with == failed
     code:  assert one(result).executed_only_directories == ["(generated)"]
     left:  []
     right: ["(generated)"]
     stacktrace:
       test/anchor/domain/sabotage/behaviour_map_test.exs:74: (test)

...
```

## BH-Q — only one of a function's files counts

Run summary: `24 tests, 1 failure`

```text
1) test build/3 a function recorded in two files counts both: an old record cannot hide one (Anchor.Domain.Sabotage.BehaviourMapTest)
     test/anchor/domain/sabotage/behaviour_map_test.exs:135
     Assertion with == failed
     code:  assert one(BehaviourMap.build(map([test_ref(["A.f/0"])]), rows, %{})).directories == [
              "lib/new",
              "lib/old"
            ]
     left:  ["lib/new"]
     right: ["lib/new", "lib/old"]
     stacktrace:
       test/anchor/domain/sabotage/behaviour_map_test.exs:138: (test)

..
```

## BH-R — the module of an mfa is read wrong

Run summary: `24 tests, 2 failures`

```text
1) test build/3 a row with no file falls back to the module's source file (Anchor.Domain.Sabotage.BehaviourMapTest)
     test/anchor/domain/sabotage/behaviour_map_test.exs:117
     Assertion with == failed
     code:  assert behaviour.directories == ["lib/ab"]
     left:  []
     right: ["lib/ab"]
     stacktrace:
       test/anchor/domain/sabotage/behaviour_map_test.exs:124: (test)

.......
```

## BH-S — an unconfirmed test is a behaviour

Run summary: `24 tests, 4 failures`

```text
1) test build/3 a test killing a function the map says it never ran confirms nothing, and is counted (Anchor.Domain.Sabotage.BehaviourMapTest)
     test/anchor/domain/sabotage/behaviour_map_test.exs:171
     Assertion with == failed
     code:  assert result.behaviours == []
     left:  [
              %Anchor.Domain.Sabotage.BehaviourMap.Behaviour{
                test_key: "test/t_test.exs::test t does it",
                executed: ["A.f/0"],
                confirmed: [],
                directories: [],
                generated: [],
                executed_only: ["A.f/0"],
                executed_only_directories: ["(generated)"]
              }
            ]
     right: []
     stacktrace:
       test/anchor/domain/sabotage/behaviour_map_test.exs:175: (test)

..
```

## BR-A — report mode fails on drift

Run summary: `29 tests, 3 failures`

```text
1) test the ratchet the default path absent: every key is NEW, said loudly (Anchor.Managers.SabotageBehavioursTest)
     test/anchor/managers/sabotage_behaviours_test.exs:261
     match (=) failed
     code:  assert {0, lines} = Sabotage.behaviours(facts(), @opts)
     left:  {0, lines}
     right: {1,
             ["behaviours: no baseline at .anchor/baselines/behaviour-locality.txt: every locality key is NEW",
              "2\ttest/t_test.exs::test t\tlib/a lib/b",
              "behaviours: 1 confirmed, 1 unconfirmed (no killed mutant among what they executed)",
              "NEW test/t_test.exs::test t: this behaviour reaches one more directory",
              "NEW test/t_test.exs::test t: this behaviour reaches one more directory",
              "behaviour locality: 2 NEW, 0 STALE against .anchor/baselines/behaviour-locality.txt (report mode, not failing)"]}
     stacktrace:
       test/anchor/managers/sabotage_behaviours_test.exs:265: (test)

..
```

## BR-B — enforce never fails

Run summary: `29 tests, 3 failures`

```text
1) test the ratchet enforce mode, one NEW: exit 1 (Anchor.Managers.SabotageBehavioursTest)
     test/anchor/managers/sabotage_behaviours_test.exs:218
     match (=) failed
     code:  assert {1, lines} = Sabotage.behaviours(facts(), @opts)
     left:  {1, lines}
     right: {0,
             ["2\ttest/t_test.exs::test t\tlib/a lib/b",
              "behaviours: 1 confirmed, 1 unconfirmed (no killed mutant among what they executed)",
              "NEW test/t_test.exs::test t: this behaviour reaches one more directory",
              "behaviour locality: FAILED, 1 NEW, 0 STALE against .anchor/baselines/behaviour-locality.txt. Fix: bring a NEW behaviour back to fewer directories, and delete the lines of a STALE one"]}
     stacktrace:
       test/anchor/managers/sabotage_behaviours_test.exs:222: (test)

...
```

## BR-C — STALE is no drift

Run summary: `29 tests, 1 failure`

```text
1) test the ratchet enforce mode, one STALE: exit 1 (Anchor.Managers.SabotageBehavioursTest)
     test/anchor/managers/sabotage_behaviours_test.exs:226
     match (=) failed
     code:  assert {1, lines} = Sabotage.behaviours(facts(), @opts)
     left:  {1, lines}
     right: {0,
             ["2\ttest/t_test.exs::test t\tlib/a lib/b",
              "behaviours: 1 confirmed, 1 unconfirmed (no killed mutant among what they executed)",
              "STALE test/t_test.exs::test t: this behaviour reaches one fewer directory",
              "behaviour locality: clean against .anchor/baselines/behaviour-locality.txt (enforce mode)"]}
     stacktrace:
       test/anchor/managers/sabotage_behaviours_test.exs:230: (test)

...................
```

## BR-D — GREW is no drift

Run summary: `29 tests, 1 failure`

```text
1) test the ratchet enforce mode, an entry the branch added: GREW, exit 1 (Anchor.Managers.SabotageBehavioursTest)
     test/anchor/managers/sabotage_behaviours_test.exs:242
     match (=) failed
     code:  assert {1, lines} = Sabotage.behaviours(facts(%{base: "main"}), @opts)
     left:  {1, lines}
     right: {0,
             ["2\ttest/t_test.exs::test t\tlib/a lib/b",
              "behaviours: 1 confirmed, 1 unconfirmed (no killed mutant among what they executed)",
              "GREW test/t_test.exs::test t: added to the baseline since main",
              "behaviour locality: clean against .anchor/baselines/behaviour-locality.txt (enforce mode)"]}
     stacktrace:
       test/anchor/managers/sabotage_behaviours_test.exs:247: (test)

.......................
```

## BR-E — the notes are dropped

Run summary: `29 tests, 2 failures`

```text
1) test the views killers and sources that did not line up are said (Anchor.Managers.SabotageBehavioursTest)
     test/anchor/managers/sabotage_behaviours_test.exs:353
     Assertion with =~ failed
     code:  assert output =~ "1 source files could not be read (first: lib/broken.ex)"
     left:  "2\ttest/t_test.exs::test t\tlib/a lib/b\nbehaviours: 1 confirmed, 1 unconfirmed (no killed mutant among what they executed)\nbehaviours: 1 killers name no test of the map, so they confirm nothing (first: test/gone_test.exs::test gone). Fix: rebuild the map, or run sabotage again for a renamed test\nbehaviours: 1 kills are of a function the map says their test never executed, so they confirm nothing. Fix: rebuild the map from the current tree\nbehaviour locality: clean against .anchor/baselines/behaviour-locality.txt (report mode)"
     right: "1 source files could not be read (first: lib/broken.ex)"
     stacktrace:
       test/anchor/managers/sabotage_behaviours_test.exs:372: (test)

.....
```

## BR-F — the unmatched killers are not said

Run summary: `29 tests, 1 failure`

```text
1) test the views killers and sources that did not line up are said (Anchor.Managers.SabotageBehavioursTest)
     test/anchor/managers/sabotage_behaviours_test.exs:353
     Assertion with =~ failed
     code:  assert output =~ "1 killers name no test of the map"
     left:  "behaviours: 1 source files could not be read (first: lib/broken.ex); their modules show as (generated) where no kill row names a file\n2\ttest/t_test.exs::test t\tlib/a lib/b\nbehaviours: 1 confirmed, 1 unconfirmed (no killed mutant among what they executed)\nbehaviours: 1 kills are of a function the map says their test never executed, so they confirm nothing. Fix: rebuild the map from the current tree\nbehaviour locality: clean against .anchor/baselines/behaviour-locality.txt (report mode)"
     right: "1 killers name no test of the map"
     stacktrace:
       test/anchor/managers/sabotage_behaviours_test.exs:373: (test)

............................
```

## BR-G — the unexecuted kills are not said

Run summary: `29 tests, 1 failure`

```text
1) test the views killers and sources that did not line up are said (Anchor.Managers.SabotageBehavioursTest)
     test/anchor/managers/sabotage_behaviours_test.exs:353
     Assertion with =~ failed
     code:  assert output =~ "1 kills are of a function the map says their test never executed"
     left:  "behaviours: 1 source files could not be read (first: lib/broken.ex); their modules show as (generated) where no kill row names a file\n2\ttest/t_test.exs::test t\tlib/a lib/b\nbehaviours: 1 confirmed, 1 unconfirmed (no killed mutant among what they executed)\nbehaviours: 1 killers name no test of the map, so they confirm nothing (first: test/gone_test.exs::test gone). Fix: rebuild the map, or run sabotage again for a renamed test\nbehaviour locality: clean against .anchor/baselines/behaviour-locality.txt (report mode)"
     right: "1 kills are of a function the map says their test never executed"
     stacktrace:
       test/anchor/managers/sabotage_behaviours_test.exs:375: (test)

..............
```

## BR-H — a generated cause is not shown

Run summary: `29 tests, 1 failure`

```text
1) test the views a confirmed cause with no source shows generated on its line (Anchor.Managers.SabotageBehavioursTest)
     test/anchor/managers/sabotage_behaviours_test.exs:378
     Assertion with =~ failed
     code:  assert text(lines) =~ "0	#{@key}		(generated) A.f/0"
     left:  "0\ttest/t_test.exs::test t\nbehaviours: 1 confirmed, 1 unconfirmed (no killed mutant among what they executed)\nbehaviour locality: clean against .anchor/baselines/behaviour-locality.txt (report mode)"
     right: "0\ttest/t_test.exs::test t\t\t(generated) A.f/0"
     stacktrace:
       test/anchor/managers/sabotage_behaviours_test.exs:391: (test)

.................
```

## BM-A — the config's map beats --coverage

Run summary: `29 tests, 1 failure`

```text
1) test what cannot be measured is exit 3, never a clean report --coverage wins over the configured map (Anchor.Managers.SabotageBehavioursTest)
     test/anchor/managers/sabotage_behaviours_test.exs:116
     ** (FunctionClauseError) no function clause matching in anonymous fn/1 in Anchor.Managers.SabotageBehavioursTest.coverage_read/1

     The following arguments were given to anonymous fn/1 in Anchor.Managers.SabotageBehavioursTest.coverage_read/1:

         # 1
         "/repo/other.etf"

     code: assert {3, [_line]} = Sabotage.behaviours(facts(), @opts)
     stacktrace:
       test/anchor/managers/sabotage_behaviours_test.exs:68: anonymous fn/1 in Anchor.Managers.SabotageBehavioursTest.coverage_read/1
       (hammox 0.7.0) lib/hammox.ex:402: anonymous fn/2 in Hammox.protected_code/3
       (hammox 0.7.0) lib/hammox/telemetry.ex:12: Hammox.Telemetry.NoOp.span/3
       (hammox 0.7.0) lib/hammox.ex:398: Hammox.protected_code/3
       (anchor 0.1.0) lib/anchor/managers/sabotage/behaviours.ex:100: Anchor.Managers.Sabotage.Behaviours.read_coverage/3
       (anchor 0.1.0) lib/anchor/managers/sabotage/behaviours.ex:65: Anchor.Managers.Sabotage.Behaviours.run/2
       test/anchor/managers/sabotage_behaviours_test.exs:119: (test)

..................
```

## BM-B — no map is not refused for zero tests

Run summary: `29 tests, 1 failure`

```text
1) test what cannot be measured is exit 3, never a clean report a map with zero tests (Anchor.Managers.SabotageBehavioursTest)
     test/anchor/managers/sabotage_behaviours_test.exs:129
     ** (Mox.UnexpectedCallError) no expectation defined for Anchor.RecordStoreMock.list/2 in process #PID<0.1299.0> with args ["/repo", "test/sabotage_records"]
     code: assert {3, [line]} = Sabotage.behaviours(facts(), @opts)
     stacktrace:
       (mox 1.2.0) lib/mox.ex:903: Mox.__dispatch__/4
       (anchor 0.1.0) lib/anchor/managers/sabotage/behaviours.ex:120: Anchor.Managers.Sabotage.Behaviours.kill_rows/3
       (anchor 0.1.0) lib/anchor/managers/sabotage/behaviours.ex:66: Anchor.Managers.Sabotage.Behaviours.run/2
       test/anchor/managers/sabotage_behaviours_test.exs:132: (test)

..
```

## BM-C — an unchecked term is taken as a map

Run summary: `29 tests, 1 failure`

```text
1) test what cannot be measured is exit 3, never a clean report a term that is no map (Anchor.Managers.SabotageBehavioursTest)
     test/anchor/managers/sabotage_behaviours_test.exs:122
     ** (FunctionClauseError) no function clause matching in Anchor.Domain.Sabotage.CoverageMap.validate/1

     The following arguments were given to Anchor.Domain.Sabotage.CoverageMap.validate/1:

         # 1
         :nope

     Attempted function clauses (showing 3 out of 3):

         def validate(-%{tests: []}-)
         def validate(-%{modules_traced: 0}-)
         def validate(-%{tests: [_ | _], modules_traced: n}-) when -is_integer(n)- and -n > 0-

     code: assert {3, [line]} = Sabotage.behaviours(facts(), @opts)
     stacktrace:
       (anchor 0.1.0) lib/anchor/domain/sabotage/coverage_map.ex:185: Anchor.Domain.Sabotage.CoverageMap.validate/1
       (anchor 0.1.0) lib/anchor/managers/sabotage/behaviours.ex:102: Anchor.Managers.Sabotage.Behaviours.read_coverage/3
       (anchor 0.1.0) lib/anchor/managers/sabotage/behaviours.ex:65: Anchor.Managers.Sabotage.Behaviours.run/2
       test/anchor/managers/sabotage_behaviours_test.exs:125: (test)

.........................
```

## BM-D — no killed row still measures

Run summary: `29 tests, 1 failure`

```text
1) test what cannot be measured is exit 3, never a clean report records with no killed row (Anchor.Managers.SabotageBehavioursTest)
     test/anchor/managers/sabotage_behaviours_test.exs:150
     ** (Mox.UnexpectedCallError) no expectation defined for Anchor.SourceSourceMock.list/1 in process #PID<0.1271.0> with args ["/repo"]
     code: assert {3, [line]} = Sabotage.behaviours(facts(), @opts)
     stacktrace:
       (mox 1.2.0) lib/mox.ex:903: Mox.__dispatch__/4
       (anchor 0.1.0) lib/anchor/managers/sabotage/behaviours.ex:162: Anchor.Managers.Sabotage.Behaviours.source_index/2
       (anchor 0.1.0) lib/anchor/managers/sabotage/behaviours.ex:67: Anchor.Managers.Sabotage.Behaviours.run/2
       test/anchor/managers/sabotage_behaviours_test.exs:158: (test)

................
```

## BM-E — an unreadable record is skipped

Run summary: `29 tests, 2 failures`

```text
1) test what cannot be measured is exit 3, never a clean report a record that cannot be read names it (Anchor.Managers.SabotageBehavioursTest)
     test/anchor/managers/sabotage_behaviours_test.exs:162
     Assertion with =~ failed
     code:  assert line =~ "the record r.md cannot be read (:eacces)"
     left:  "COULD NOT MEASURE: nothing confirms any cause yet: no record holds a killed mutant. Fix: run mix anchor.sabotage run and land its record"
     right: "the record r.md cannot be read (:eacces)"
     stacktrace:
       test/anchor/managers/sabotage_behaviours_test.exs:168: (test)

....................
```
## BM-F — the default path absent is a failure

Run summary: `29 tests, 2 failures`

```text
1) test the ratchet the default path absent: every key is NEW, said loudly (Anchor.Managers.SabotageBehavioursTest)
     test/anchor/managers/sabotage_behaviours_test.exs:261
     match (=) failed
     code:  assert {0, lines} = Sabotage.behaviours(facts(), @opts)
     left:  {0, lines}
     right: {1,
             ["baseline .anchor/baselines/behaviour-locality.txt not found. Fix: run mix anchor.sabotage behaviours --write-baseline, or remove sabotage.behaviour_locality_baseline"]}
     stacktrace:
       test/anchor/managers/sabotage_behaviours_test.exs:265: (test)

.............
```

## BM-G — a malformed baseline is not refused

Run summary: `29 tests, 1 failure`

```text
1) test the ratchet a malformed baseline: exit 1, in report mode too (Anchor.Managers.SabotageBehavioursTest)
     test/anchor/managers/sabotage_behaviours_test.exs:279
     match (=) failed
     code:  assert {1, [line]} = Sabotage.behaviours(facts(), @opts)
     left:  {1, [line]}
     right: {0,
             ["2\ttest/t_test.exs::test t\tlib/a lib/b",
              "behaviours: 1 confirmed, 1 unconfirmed (no killed mutant among what they executed)",
              "NEW test/t_test.exs::test t: this behaviour reaches one more directory",
              "NEW test/t_test.exs::test t: this behaviour reaches one more directory",
              "STALE no key here: this behaviour reaches one fewer directory",
              "behaviour locality: 2 NEW, 1 STALE against .anchor/baselines/behaviour-locality.txt (report mode, not failing)"]}
     stacktrace:
       test/anchor/managers/sabotage_behaviours_test.exs:283: (test)

............................
```

## BM-H — a first landing is refused

Run summary: `29 tests, 1 failure`

```text
1) test the ratchet a first landing has no base copy, so nothing grew (Anchor.Managers.SabotageBehavioursTest)
     test/anchor/managers/sabotage_behaviours_test.exs:253
     match (=) failed
     code:  assert {0, _lines} = Sabotage.behaviours(facts(%{base: "main"}), @opts)
     left:  {0, _lines}
     right: {3, ["COULD NOT MEASURE: absent"]}
     stacktrace:
       test/anchor/managers/sabotage_behaviours_test.exs:258: (test)

..........
```

## BM-I — an unreadable base is no growth

Run summary: `29 tests, 1 failure`

```text
1) test what cannot be measured is exit 3, never a clean report a base that cannot be read is no growth it could vouch for (Anchor.Managers.SabotageBehavioursTest)
     test/anchor/managers/sabotage_behaviours_test.exs:186
     ** (CaseClauseError) no case clause matching:

         {:error, :bad_ref}

     code: assert {3, [line]} = Sabotage.behaviours(facts(%{base: "main"}), @opts)
     stacktrace:
       (anchor 0.1.0) lib/anchor/managers/sabotage/behaviours.ex:268: Anchor.Managers.Sabotage.Behaviours.grew/4
       (anchor 0.1.0) lib/anchor/managers/sabotage/behaviours.ex:204: Anchor.Managers.Sabotage.Behaviours.judged/4
       test/anchor/managers/sabotage_behaviours_test.exs:190: (test)

.........................
```

## BM-J — --write-baseline over a file exits 0

Run summary: `29 tests, 1 failure`

```text
1) test --write-baseline an existing file: exit 2, left as it is (Anchor.Managers.SabotageBehavioursTest)
     test/anchor/managers/sabotage_behaviours_test.exs:311
     match (=) failed
     code:  assert {2, [line]} = Sabotage.behaviours(facts(%{write_baseline: true}), @opts)
     left:  {2, [line]}
     right: {0,
             [".anchor/baselines/behaviour-locality.txt already exists and was left as it is: a baseline only shrinks. Fix: delete the lines of what shrank, or remove the file first to start again"]}
     stacktrace:
       test/anchor/managers/sabotage_behaviours_test.exs:315: (test)

..
```

## BM-K — --write-baseline is ignored

Run summary: `29 tests, 3 failures`

```text
1) test --write-baseline no file: created with the sorted keys (Anchor.Managers.SabotageBehavioursTest)
     test/anchor/managers/sabotage_behaviours_test.exs:297
     ** (Mox.UnexpectedCallError) no expectation defined for Anchor.BaselineStoreMock.read/2 in process #PID<0.1267.0> with args ["/repo", ".anchor/baselines/behaviour-locality.txt"]
     code: Sabotage.behaviours(facts(%{write_baseline: true}), @opts)
     stacktrace:
       (mox 1.2.0) lib/mox.ex:903: Mox.__dispatch__/4
       (anchor 0.1.0) lib/anchor/managers/sabotage/behaviours.ex:225: Anchor.Managers.Sabotage.Behaviours.baseline/4
       (anchor 0.1.0) lib/anchor/managers/sabotage/behaviours.ex:203: Anchor.Managers.Sabotage.Behaviours.judged/4
       test/anchor/managers/sabotage_behaviours_test.exs:308: (test)

....
```

## BM-L — a baseline that is not UTF-8 reads as could not measure

Run summary: `29 tests, 1 failure`

```text
1) test the ratchet a baseline that is not UTF-8: exit 1 (Anchor.Managers.SabotageBehavioursTest)
     test/anchor/managers/sabotage_behaviours_test.exs:287
     match (=) failed
     code:  assert {1, [line]} = Sabotage.behaviours(facts(), @opts)
     left:  {1, [line]}
     right: {3, ["COULD NOT MEASURE: line 4 is not UTF-8"]}
     stacktrace:
       test/anchor/managers/sabotage_behaviours_test.exs:291: (test)

......
```

## BC-A — enforce reads as report

Run summary: `7 tests, 1 failure`

```text
1) test parse/1 every key is read (Anchor.Domain.Sabotage.ConfigTest)
     test/anchor/domain/sabotage/config_test.exs:41
     Assertion with == failed
     code:  assert config.behaviour_locality_enforcement == :enforce
     left:  :report
     right: :enforce
     stacktrace:
       test/anchor/domain/sabotage/config_test.exs:71: (test)
```

## BC-B — a baseline path outside the project passes

Run summary: `7 tests, 1 failure`

```text
1) test parse/1 2: each refusal names its key and ends with a Fix: line (Anchor.Domain.Sabotage.ConfigTest)
     test/anchor/domain/sabotage/config_test.exs:149
     ** (MatchError) no match of right hand side value:

         {:ok,
          %Anchor.Domain.Sabotage.Config{
            test_command: ["mix", "test", "--max-cases", "2"],
            max_mutants: 30,
            timeout_seconds: 300,
            operators: [:delete_statement, :drop_effect_call, :narrow_clause,
             :with_passthrough, :force_condition, :return_input],
            effect_calls: [],
            test_mirror: [
              %{to: "apps/{app}/test/{rest}_test.exs", from: "apps/*/lib/**/*.ex"},
              %{to: "test/{rest}_test.exs", from: "lib/**/*.ex"}
            ],
            coverage_map: nil,
            survivors: nil,
            behaviour_locality_baseline: "/tmp/b.txt",
            behaviour_locality_enforcement: :report,
            records: %{
              dir: "test/sabotage_records",
              naming: :domain_date_slot,
              domain_from: :module,
              domain_strip_prefixes: [],
              adr: "the repo's sabotage-record ADR"
            }
          }}

     code: for {label, section, prefix} <- @refusals do
     stacktrace:
       test/anchor/domain/sabotage/config_test.exs:151: anonymous fn/2 in Anchor.Domain.Sabotage.ConfigTest."test parse/1 2: each refusal names its key and ends with a Fix: line"/1
       (elixir 1.19.4) lib/enum.ex:2520: Enum."-reduce/3-lists^foldl/2-0-"/3
       test/anchor/domain/sabotage/config_test.exs:150: (test)

.....
```

## BS-A — apps are not listed

Run summary: `3 tests, 1 failure`

```text
1) test list/1: the project's lib sources, relative and sorted, and nothing else (Anchor.Adapters.SourceReaderTest)
     test/anchor/adapters/source_reader_test.exs:14
     Assertion with == failed
     code:  assert SourceReader.list(tmp_dir) == ["apps/x/lib/x.ex", "lib/a.ex", "lib/b/b.ex"]
     left:  ["lib/a.ex", "lib/b/b.ex"]
     right: ["apps/x/lib/x.ex", "lib/a.ex", "lib/b/b.ex"]
     stacktrace:
       test/anchor/adapters/source_reader_test.exs:28: (test)

..
```

## BS-B — paths stay absolute

Run summary: `3 tests, 1 failure`

```text
1) test list/1: the project's lib sources, relative and sorted, and nothing else (Anchor.Adapters.SourceReaderTest)
     test/anchor/adapters/source_reader_test.exs:14
     Assertion with == failed
     code:  assert SourceReader.list(tmp_dir) == ["apps/x/lib/x.ex", "lib/a.ex", "lib/b/b.ex"]
     left:  ["<worktree>/tmp/Anchor.Adapters.SourceReaderTest/test-list-1--the-project's-lib-sources,-relative-and-sorted,-and-nothing-else-92cf2d87/apps/x/lib/x.ex",
             "<worktree>/tmp/Anchor.Adapters.SourceReaderTest/test-list-1--the-project's-lib-sources,-relative-and-sorted,-and-nothing-else-92cf2d87/lib/a.ex",
             "<worktree>/tmp/Anchor.Adapters.SourceReaderTest/test-list-1--the-project's-lib-sources,-relative-and-sorted,-and-nothing-else-92cf2d87/lib/b/b.ex"]
     right: ["apps/x/lib/x.ex", "lib/a.ex", "lib/b/b.ex"]
     stacktrace:
       test/anchor/adapters/source_reader_test.exs:28: (test)
```

## BK-A — a nameless test passes the check

Run summary: `27 tests, 1 failure`

```text
1) test check/1, a test's name (DND-5489) a test with no string name is no usable map: a key is built from it (Anchor.Domain.Sabotage.CoverageMapTest)
     test/anchor/domain/sabotage/coverage_map_test.exs:41
     Assertion with == failed
     code:  assert CoverageMap.check(%{map | tests: [Map.put(test_ref, :name, :atom)]}) == {:error, :not_a_map}
     left:  {:ok,
             %{
               version: 1,
               commit: nil,
               tests: [
                 %{
                   functions: [],
                   line: 1,
                   name: :atom,
                   file: "test/a_test.exs"
                 }
               ]
             }}
     right: {:error, :not_a_map}
     stacktrace:
       test/anchor/domain/sabotage/coverage_map_test.exs:47: (test)

..
```

## BT-A — --write-baseline defaults on

Run summary: `6 tests, 1 failure`

```text
1) test the facts: each flag, and what its absence means (Mix.Tasks.Anchor.SabotageBehavioursTest)
     test/mix/tasks/anchor_sabotage_behaviours_test.exs:42
     match (=) failed
     code:  assert {:ok, %{coverage: nil, format: :text, write_baseline: false, base: nil}} =
              Sabotage.behaviours_facts([])
     left:  {:ok, %{coverage: nil, format: :text, write_baseline: false, base: nil}}
     right: {:ok,
             %{
               root: "<worktree>",
               format: :text,
               base: nil,
               coverage: nil,
               write_baseline: true
             }}
     stacktrace:
       test/mix/tasks/anchor_sabotage_behaviours_test.exs:51: (test)

.....
```

## Second run

Against `7985167`, through the same driver and `test-slot`. The module of an mfa is no longer read by a regex, so BH-R here mutates what replaced it, and the first table's BH-R is retired with that code. BK-B and BT-B are new: a `modules_traced` that is no count, and a `--base` ref that reads as an option.

| # | Mutation | Tests run | Result | Failing tests |
|---|---|---|---|---|
| BH-R | the module of an mfa is read wrong (`lib/anchor/domain/sabotage/behaviour_map.ex`) | `behaviour_map_test.exs` | `NO SUMMARY (exit 1)` (NO SUMMARY) |  |
| BK-B | a modules_traced that is no count crashes (`lib/anchor/domain/sabotage/coverage_map.ex`) | `sabotage_behaviours_test.exs` | `30 tests, 1 failure` (red) | what cannot be measured is exit 3, never a clean report a map whose modules_traced is no count is refused, not a crash |
| BT-B | a bad ref reaches the adapter (`lib/mix/tasks/anchor.sabotage.ex`) | `anchor_sabotage_behaviours_test.exs` | `NO SUMMARY (exit 1)` (NO SUMMARY) |  |

### BH-R — the module of an mfa is read wrong

Run summary: `NO SUMMARY (exit 1)`

```text
Compiling 1 file (.ex)
warning: mtime (modified time) for "lib/anchor/domain/sabotage/behaviour_map.ex" was set to the future, resetting to now
     warning: function alias_segment?/1 is unused
     │
 210 │   defp alias_segment?(<<first, _rest::binary>> = segment),
     │        ~
     │
     └─ lib/anchor/domain/sabotage/behaviour_map.ex:210:8: Anchor.Domain.Sabotage.BehaviourMap (module)

Compilation failed due to warnings while using the --warnings-as-errors option
```

### BK-B — a modules_traced that is no count crashes

Run summary: `30 tests, 1 failure`

```text
1) test what cannot be measured is exit 3, never a clean report a map whose modules_traced is no count is refused, not a crash (Anchor.Managers.SabotageBehavioursTest)
     test/anchor/managers/sabotage_behaviours_test.exs:136
     ** (FunctionClauseError) no function clause matching in Anchor.Domain.Sabotage.CoverageMap.validate/1

     The following arguments were given to Anchor.Domain.Sabotage.CoverageMap.validate/1:

         # 1
         %{version: 1, commit: nil, tests: [%{functions: ["A.f/0", "B.g/0"], line: 3, module: "TTest", name: "test t", file: "test/t_test.exs"}, %{functions: ["A.f/0"], line: 3, module: "UTest", name: "test u", file: "test/u_test.exs"}]}

     Attempted function clauses (showing 3 out of 3):

         def validate(-%{tests: []}-)
         def validate(-%{modules_traced: 0}-)
         def validate(-%{tests: [_ | _], modules_traced: n}-) when -is_integer(n)- and -n > 0-

     code: for bad <- [
     stacktrace:
       (anchor 0.1.0) lib/anchor/domain/sabotage/coverage_map.ex:185: Anchor.Domain.Sabotage.CoverageMap.validate/1
       (anchor 0.1.0) lib/anchor/managers/sabotage/behaviours.ex:102: Anchor.Managers.Sabotage.Behaviours.read_coverage/3
       (anchor 0.1.0) lib/anchor/managers/sabotage/behaviours.ex:65: Anchor.Managers.Sabotage.Behaviours.run/2
       test/anchor/managers/sabotage_behaviours_test.exs:144: anonymous fn/2 in Anchor.Managers.SabotageBehavioursTest."test what cannot be measured is exit 3, never a clean report a map whose modules_traced is no count is refused, not a crash"/1
       (elixir 1.19.4) lib/enum.ex:2520: Enum."-reduce/3-lists^foldl/2-0-"/3
       test/anchor/managers/sabotage_behaviours_test.exs:137: (test)

...............
```

### BT-B — a bad ref reaches the adapter

Run summary: `NO SUMMARY (exit 1)`

```text
Compiling 2 files (.ex)
warning: mtime (modified time) for "lib/mix/tasks/anchor.sabotage.ex" was set to the future, resetting to now
warning: mtime (modified time) for "lib/anchor/domain/sabotage/coverage_map.ex" was set to the future, resetting to now
     warning: unused alias Baseline
     │
 136 │   alias Anchor.Domain.Baseline
     │   ~
     │
     └─ lib/mix/tasks/anchor.sabotage.ex:136:3

Compilation failed due to warnings while using the --warnings-as-errors option
```
