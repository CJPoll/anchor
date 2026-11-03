# Sabotage record — the base copy of a baseline is found by rule id (DND-5629)

- **Domain:** baseline_rename
- **Branch:** dnd-5441-graph-rules-a
- **Date:** 2026-11-03
- **Code under test:** `Anchor.Domain.BaselineBase`, `Anchor.Domain.Enforcement` and `Anchor.Domain.Failures.baseline_new_rule/4`, the base lookup in `Anchor.Managers.Graph`, and `Anchor.Adapters.GitShow.rules/3`
- **Suite run:** one `test-slot` ran a driver that, for each mutation, wrote it, waited 1.1 s, ran `mix test --force --max-cases 2 <its test files>`, restored the source and waited 1.1 s again, so no run read a stale beam. Every row is red, and no two rows quote the same failure block. With every source restored: `55 tests, 0 failures`.

| ID | Mutation | Tests | Result | Failing tests |
|---|---|---|---|---|
| RN-R | regression: the code before this fix, with the new tests | `baseline_base_test.exs`, `enforcement_test.exs`, `graph_baseline_test.exs` | `41 tests, 21 failures` (red) | gone/2 the ids that had a baseline at the ref and are not rules now, sorted; locate/2 a rule id absent at the ref is a new rule; locate/2 no config at the ref: every rule is new; locate/2 a rule whose baseline path was renamed is found at its path at the ref; gone/2 nothing is gone when there was no config at the ref; locate/2 positive control: an unrenamed path is found at the same path; locate/2 a rule id with no baseline at the ref compares with an empty one; locate/2 the id decides, never the path: another rule's file at the same path is not it; judge/4 a new rule id with nothing gone says so |
| RN-A | locate/2 ignores the id: the first rule with a baseline answers (`lib/anchor/domain/baseline_base.ex`) | `baseline_base_test.exs` | `8 tests, 2 failures` (red) | locate/2 a rule id absent at the ref is a new rule; locate/2 the id decides, never the path: another rule's file at the same path is not it |
| RN-B | locate/2 reads a rule id absent at the ref as one with no baseline there (`lib/anchor/domain/baseline_base.ex`) | `baseline_base_test.exs` | `8 tests, 1 failure` (red) | locate/2 a rule id absent at the ref is a new rule |
| RN-C | gone/2 names a rule that had no baseline at the ref (`lib/anchor/domain/baseline_base.ex`) | `baseline_base_test.exs` | `8 tests, 1 failure` (red) | gone/2 the ids that had a baseline at the ref and are not rules now, sorted |
| RN-D | gone/2 is not sorted (`lib/anchor/domain/baseline_base.ex`) | `baseline_base_test.exs` | `8 tests, 1 failure` (red) | gone/2 the ids that had a baseline at the ref and are not rules now, sorted |
| RN-E | the new-rule note never names the ids gone (`lib/anchor/domain/failures.ex`) | `enforcement_test.exs`, `graph_baseline_test.exs` | `33 tests, 2 failures` (red) | judge/4 a rule id new at the ref is a first landing naming it and the ids gone; run/2 --base REF finds the base baseline by rule id (DND-5629) a rule id new at the ref is a first landing named by the id; no file is read there |
| RN-F | the old path-keyed lookup: the base copy is read at the branch path (`lib/anchor/managers/graph.ex`) | `graph_baseline_test.exs` | `23 tests, 2 failures` (red) | run/2 --base REF finds the base baseline by rule id (DND-5629) a renamed path with the same entries is clean; run/2 --base REF finds the base baseline by rule id (DND-5629) a renamed baseline path with an added entry is GREW |
| RN-G | a rule with no baseline at the ref is a first landing, not compared with empty (`lib/anchor/managers/graph.ex`) | `graph_baseline_test.exs` | `23 tests, 1 failure` (red) | run/2 --base REF finds the base baseline by rule id (DND-5629) a rule id that had no baseline at the ref: every entry is GREW |
| RN-H | a base config that cannot be read reads as absent (every rule a first landing) (`lib/anchor/managers/graph.ex`) | `graph_baseline_test.exs` | `23 tests, 1 failure` (red) | run/2 --base REF finds the base baseline by rule id (DND-5629) a base config that cannot be read fails closed on the config, naming the ref |
| RN-I | GitShow.rules/3 reads a rejected config as no rules (`lib/anchor/adapters/git_show.ex`) | `git_show_test.exs` | `14 tests, 1 failure` (red) | rules/3 (DND-5629) a config the parser rejects is its error, never an empty rule list |

## RN-R — regression: the code before this fix

The unfixed code with the new tests: `mix test --force test/anchor/domain/baseline_base_test.exs test/anchor/domain/enforcement_test.exs test/anchor/managers/graph_baseline_test.exs`. Before the fix there was no base-config port and no `BaselineBase`, so the new tests fail on the missing module and `rules/3`, not on the bug itself. RN-F below restores the old lookup (the base copy read at the branch's path) inside the fixed code: the tests catch it as a read at `.anchor/baselines/f.txt`, the branch's path, where the rule's copy at the ref is `.anchor/baselines/old.txt`.

Run summary: `41 tests, 21 failures`

```text
  1) test gone/2 the ids that had a baseline at the ref and are not rules now, sorted (Anchor.Domain.BaselineBaseTest)
     test/anchor/domain/baseline_base_test.exs:44
     ** (UndefinedFunctionError) function Anchor.Domain.BaselineBase.gone/2 is undefined (module Anchor.Domain.BaselineBase is not available)
     code: assert BaselineBase.gone(base, [rule("kept", @new), rule("renamed", @old)]) == ["a", "b"]
     stacktrace:
       Anchor.Domain.BaselineBase.gone([%{id: "b", type: :layering, baseline: ".anchor/baselines/old.txt"}, %{id: "a", type: :layering, baseline: "x.txt"}, %{id: "kept", type: :layering, baseline: ".anchor/baselines/new.txt"}, %{id: "c", type: :layering}], [%{id: "kept", type: :layering, baseline: ".anchor/baselines/new.txt"}, %{id: "renamed", type: :layering, baseline: ".anchor/baselines/old.txt"}])
       test/anchor/domain/baseline_base_test.exs:52: (test)



  2) test locate/2 a rule id absent at the ref is a new rule (Anchor.Domain.BaselineBaseTest)
     test/anchor/domain/baseline_base_test.exs:30
     ** (UndefinedFunctionError) function Anchor.Domain.BaselineBase.locate/2 is undefined (module Anchor.Domain.BaselineBase is not available)
     code: assert BaselineBase.locate([rule("other", @old)], "r") == :new_rule
     stacktrace:
       Anchor.Domain.BaselineBase.locate([%{id: "other", type: :layering, baseline: ".anchor/baselines/old.txt"}], "r")
       test/anchor/domain/baseline_base_test.exs:31: (test)



  3) test locate/2 no config at the ref: every rule is new (Anchor.Domain.BaselineBaseTest)
     test/anchor/domain/baseline_base_test.exs:34
     ** (UndefinedFunctionError) function Anchor.Domain.BaselineBase.locate/2 is undefined (module Anchor.Domain.BaselineBase is not available)
     code: assert BaselineBase.locate(:absent, "r") == :new_rule
     stacktrace:
       Anchor.Domain.BaselineBase.locate(:absent, "r")
       test/anchor/domain/baseline_base_test.exs:35: (test)



  4) test locate/2 a rule whose baseline path was renamed is found at its path at the ref (Anchor.Domain.BaselineBaseTest)
     test/anchor/domain/baseline_base_test.exs:18
     ** (UndefinedFunctionError) function Anchor.Domain.BaselineBase.locate/2 is undefined (module Anchor.Domain.BaselineBase is not available)
     code: assert BaselineBase.locate([rule("r", @old)], "r") == {:path, @old}
     stacktrace:
       Anchor.Domain.BaselineBase.locate([%{id: "r", type: :layering, baseline: ".anchor/baselines/old.txt"}], "r")
       test/anchor/domain/baseline_base_test.exs:19: (test)



  5) test gone/2 nothing is gone when there was no config at the ref (Anchor.Domain.BaselineBaseTest)
     test/anchor/domain/baseline_base_test.exs:55
     ** (UndefinedFunctionError) function Anchor.Domain.BaselineBase.gone/2 is undefined (module Anchor.Domain.BaselineBase is not available)
     code: assert BaselineBase.gone(:absent, [rule("r", @new)]) == []
     stacktrace:
       Anchor.Domain.BaselineBase.gone(:absent, [%{id: "r", type: :layering, baseline: ".anchor/baselines/new.txt"}])
       test/anchor/domain/baseline_base_test.exs:56: (test)



  6) test locate/2 positive control: an unrenamed path is found at the same path (Anchor.Domain.BaselineBaseTest)
     test/anchor/domain/baseline_base_test.exs:22
     ** (UndefinedFunctionError) function Anchor.Domain.BaselineBase.locate/2 is undefined (module Anchor.Domain.BaselineBase is not available)
     code: assert BaselineBase.locate([rule("r", @new)], "r") == {:path, @new}
     stacktrace:
       Anchor.Domain.BaselineBase.locate([%{id: "r", type: :layering, baseline: ".anchor/baselines/new.txt"}], "r")
       test/anchor/domain/baseline_base_test.exs:23: (test)



  7) test locate/2 a rule id with no baseline at the ref compares with an empty one (Anchor.Domain.BaselineBaseTest)
     test/anchor/domain/baseline_base_test.exs:26
     ** (UndefinedFunctionError) function Anchor.Domain.BaselineBase.locate/2 is undefined (module Anchor.Domain.BaselineBase is not available)
     code: assert BaselineBase.locate([%{type: :layering, id: "r"}], "r") == :no_baseline
     stacktrace:
       Anchor.Domain.BaselineBase.locate([%{id: "r", type: :layering}], "r")
       test/anchor/domain/baseline_base_test.exs:27: (test)



  8) test locate/2 the id decides, never the path: another rule's file at the same path is not it (Anchor.Domain.BaselineBaseTest)
     test/anchor/domain/baseline_base_test.exs:38
     ** (UndefinedFunctionError) function Anchor.Domain.BaselineBase.locate/2 is undefined (module Anchor.Domain.BaselineBase is not available)
     code: assert BaselineBase.locate([rule("other", @new), rule("r", @old)], "r") == {:path, @old}
     stacktrace:
       Anchor.Domain.BaselineBase.locate([%{id: "other", type: :layering, baseline: ".anchor/baselines/new.txt"}, %{id: "r", type: :layering, baseline: ".anchor/baselines/old.txt"}], "r")
       test/anchor/domain/baseline_base_test.exs:39: (test)

...

  9) test judge/4 a new rule id with nothing gone says so (Anchor.Domain.EnforcementTest)
     test/anchor/domain/enforcement_test.exs:126
     ** (FunctionClauseError) no function clause matching in Anchor.Domain.Enforcement.base_findings/3

     The following arguments were given to Anchor.Domain.Enforcement.base_findings/3:

         # 1
         []

         # 2
         {:new_rule, []}

         # 3
         %{label: "rule 1 (id: \"r\", layering)", path: ".anchor/baselines/r.txt", ref: "main", rule: %{id: "r", index: 1, type: :layering, enforcement: :enforce}}

     Attempted function clauses (showing 3 out of 3):

         defp base_findings(_entries, -nil-, _context)
         defp base_findings(_entries, -:absent-, %{path: path, ref: ref})
         defp base_findings(entries, -{:ok, base_entries}-, context)

     code: Enforcement.judge([], [], {:new_rule, []}, context(rule(), "main"))
     stacktrace:
       (anchor 0.1.0) lib/anchor/domain/enforcement.ex:51: Anchor.Domain.Enforcement.base_findings/3
       (anchor 0.1.0) lib/anchor/domain/enforcement.ex:48: Anchor.Domain.Enforcement.judge/4
       test/anchor/domain/enforcement_test.exs:128: (test)

..

 10) test judge/4 a rule id new at the ref is a first landing naming it and the ids gone (Anchor.Domain.EnforcementTest)
     test/anchor/domain/enforcement_test.exs:107
     ** (FunctionClauseError) no function clause matching in Anchor.Domain.Enforcement.base_findings/3

     The following arguments were given to Anchor.Domain.Enforcement.base_findings/3:

         # 1
         ["r|A|x"]

         # 2
         {:new_rule, ["old_r"]}

         # 3
         %{label: "rule 1 (id: \"r\", layering)", path: ".anchor/baselines/r.txt", ref: "main", rule: %{id: "r", index: 1, type: :layering, enforcement: :enforce}}

     Attempted function clauses (showing 3 out of 3):

         defp base_findings(_entries, -nil-, _context)
         defp base_findings(_entries, -:absent-, %{path: path, ref: ref})
         defp base_findings(entries, -{:ok, base_entries}-, context)

     code: Enforcement.judge(
     stacktrace:
       (anchor 0.1.0) lib/anchor/domain/enforcement.ex:51: Anchor.Domain.Enforcement.base_findings/3
       (anchor 0.1.0) lib/anchor/domain/enforcement.ex:48: Anchor.Domain.Enforcement.judge/4
       test/anchor/domain/enforcement_test.exs:109: (test)

...

 11) test run/2 --base REF (GREW) a failed read at REF is an issue naming the ref, never no growth (exit 1) (Anchor.Managers.GraphBaselineTest)
     test/anchor/managers/graph_baseline_test.exs:264
     ** (ArgumentError) unknown function rules/3 for mock Anchor.GitBaseMock
     code: expect_base_rules("nosuch", [rule()])
     stacktrace:
       (mox 1.2.0) lib/mox.ex:681: Mox.add_expectation!/4
       (mox 1.2.0) lib/mox.ex:549: Mox.expect/4
       (hammox 0.7.0) lib/hammox.ex:54: anonymous fn/4 in Hammox.expect/4
       (hammox 0.7.0) lib/hammox/telemetry.ex:12: Hammox.Telemetry.NoOp.span/3
       test/anchor/managers/graph_baseline_test.exs:269: (test)



 12) test run/2 --base REF finds the base baseline by rule id (DND-5629) a renamed baseline path with an added entry is GREW (Anchor.Managers.GraphBaselineTest)
     test/anchor/managers/graph_baseline_test.exs:294
     ** (ArgumentError) unknown function rules/3 for mock Anchor.GitBaseMock
     code: expect_base_rules("main", [rule(%{baseline: @old})])
     stacktrace:
       (mox 1.2.0) lib/mox.ex:681: Mox.add_expectation!/4
       (mox 1.2.0) lib/mox.ex:549: Mox.expect/4
       (hammox 0.7.0) lib/hammox.ex:54: anonymous fn/4 in Hammox.expect/4
       (hammox 0.7.0) lib/hammox/telemetry.ex:12: Hammox.Telemetry.NoOp.span/3
       test/anchor/managers/graph_baseline_test.exs:297: (test)

....

 13) test run/2 --base REF (GREW) a baseline that only shrank since REF is not growth (Anchor.Managers.GraphBaselineTest)
     test/anchor/managers/graph_baseline_test.exs:238
     ** (ArgumentError) unknown function rules/3 for mock Anchor.GitBaseMock
     code: expect_base_rules("main", [rule()])
     stacktrace:
       (mox 1.2.0) lib/mox.ex:681: Mox.add_expectation!/4
       (mox 1.2.0) lib/mox.ex:549: Mox.expect/4
       (hammox 0.7.0) lib/hammox.ex:54: anonymous fn/4 in Hammox.expect/4
       (hammox 0.7.0) lib/hammox/telemetry.ex:12: Hammox.Telemetry.NoOp.span/3
       test/anchor/managers/graph_baseline_test.exs:242: (test)

.

 14) test run/2 --base REF (GREW) a baseline absent at REF is a first landing: a NOTE, exit 0 (Anchor.Managers.GraphBaselineTest)
     test/anchor/managers/graph_baseline_test.exs:251
     ** (ArgumentError) unknown function rules/3 for mock Anchor.GitBaseMock
     code: expect_base_rules("main", [rule()])
     stacktrace:
       (mox 1.2.0) lib/mox.ex:681: Mox.add_expectation!/4
       (mox 1.2.0) lib/mox.ex:549: Mox.expect/4
       (hammox 0.7.0) lib/hammox.ex:54: anonymous fn/4 in Hammox.expect/4
       (hammox 0.7.0) lib/hammox/telemetry.ex:12: Hammox.Telemetry.NoOp.span/3
       test/anchor/managers/graph_baseline_test.exs:254: (test)



 15) test run/2 --base REF finds the base baseline by rule id (DND-5629) a renamed path with the same entries is clean (Anchor.Managers.GraphBaselineTest)
     test/anchor/managers/graph_baseline_test.exs:307
     ** (ArgumentError) unknown function rules/3 for mock Anchor.GitBaseMock
     code: expect_base_rules("main", [rule(%{baseline: @old})])
     stacktrace:
       (mox 1.2.0) lib/mox.ex:681: Mox.add_expectation!/4
       (mox 1.2.0) lib/mox.ex:549: Mox.expect/4
       (hammox 0.7.0) lib/hammox.ex:54: anonymous fn/4 in Hammox.expect/4
       (hammox 0.7.0) lib/hammox/telemetry.ex:12: Hammox.Telemetry.NoOp.span/3
       test/anchor/managers/graph_baseline_test.exs:310: (test)

.

 16) test run/2 --base REF (GREW) an entry the branch added since REF fails as GREW (exit 1) (Anchor.Managers.GraphBaselineTest)
     test/anchor/managers/graph_baseline_test.exs:224
     ** (ArgumentError) unknown function rules/3 for mock Anchor.GitBaseMock
     code: expect_base_rules("main", [rule()])
     stacktrace:
       (mox 1.2.0) lib/mox.ex:681: Mox.add_expectation!/4
       (mox 1.2.0) lib/mox.ex:549: Mox.expect/4
       (hammox 0.7.0) lib/hammox.ex:54: anonymous fn/4 in Hammox.expect/4
       (hammox 0.7.0) lib/hammox/telemetry.ex:12: Hammox.Telemetry.NoOp.span/3
       test/anchor/managers/graph_baseline_test.exs:227: (test)



 17) test run/2 --base REF finds the base baseline by rule id (DND-5629) no config at the ref: a first landing (Anchor.Managers.GraphBaselineTest)
     test/anchor/managers/graph_baseline_test.exs:343
     ** (ArgumentError) unknown function rules/3 for mock Anchor.GitBaseMock
     code: expect(GitBaseMock, :rules, fn @root, "main", ".anchor.yml" -> {:error, :absent} end)
     stacktrace:
       (mox 1.2.0) lib/mox.ex:681: Mox.add_expectation!/4
       (mox 1.2.0) lib/mox.ex:549: Mox.expect/4
       (hammox 0.7.0) lib/hammox.ex:54: anonymous fn/4 in Hammox.expect/4
       (hammox 0.7.0) lib/hammox/telemetry.ex:12: Hammox.Telemetry.NoOp.span/3
       test/anchor/managers/graph_baseline_test.exs:346: (test)

.

 18) test run/2 --base REF finds the base baseline by rule id (DND-5629) a base config that cannot be read fails closed on the config, naming the ref (Anchor.Managers.GraphBaselineTest)
     test/anchor/managers/graph_baseline_test.exs:355
     ** (ArgumentError) unknown function rules/3 for mock Anchor.GitBaseMock
     code: expect(GitBaseMock, :rules, fn @root, "main", ".anchor.yml" ->
     stacktrace:
       (mox 1.2.0) lib/mox.ex:681: Mox.add_expectation!/4
       (mox 1.2.0) lib/mox.ex:549: Mox.expect/4
       (hammox 0.7.0) lib/hammox.ex:54: anonymous fn/4 in Hammox.expect/4
       (hammox 0.7.0) lib/hammox/telemetry.ex:12: Hammox.Telemetry.NoOp.span/3
       test/anchor/managers/graph_baseline_test.exs:361: (test)

...

 19) test run/2 --base REF finds the base baseline by rule id (DND-5629) a rule id new at the ref is a first landing named by the id; no file is read there (Anchor.Managers.GraphBaselineTest)
     test/anchor/managers/graph_baseline_test.exs:316
     ** (ArgumentError) unknown function rules/3 for mock Anchor.GitBaseMock
     code: expect_base_rules("main", [rule(%{id: "gone", baseline: @old})])
     stacktrace:
       (mox 1.2.0) lib/mox.ex:681: Mox.add_expectation!/4
       (mox 1.2.0) lib/mox.ex:549: Mox.expect/4
       (hammox 0.7.0) lib/hammox.ex:54: anonymous fn/4 in Hammox.expect/4
       (hammox 0.7.0) lib/hammox/telemetry.ex:12: Hammox.Telemetry.NoOp.span/3
       test/anchor/managers/graph_baseline_test.exs:320: (test)



 20) test run/2 --base REF finds the base baseline by rule id (DND-5629) a rule id that had no baseline at the ref: every entry is GREW (Anchor.Managers.GraphBaselineTest)
     test/anchor/managers/graph_baseline_test.exs:331
     ** (ArgumentError) unknown function rules/3 for mock Anchor.GitBaseMock
     code: expect_base_rules("main", [Map.delete(rule(), :baseline)])
     stacktrace:
       (mox 1.2.0) lib/mox.ex:681: Mox.add_expectation!/4
       (mox 1.2.0) lib/mox.ex:549: Mox.expect/4
       (hammox 0.7.0) lib/hammox.ex:54: anonymous fn/4 in Hammox.expect/4
       (hammox 0.7.0) lib/hammox/telemetry.ex:12: Hammox.Telemetry.NoOp.span/3
       test/anchor/managers/graph_baseline_test.exs:334: (test)



 21) test run/2 --base REF (GREW) without --base, git is never asked (Anchor.Managers.GraphBaselineTest)
     test/anchor/managers/graph_baseline_test.exs:278
     ** (ArgumentError) unknown function rules/3 for mock Anchor.GitBaseMock
     code: expect(GitBaseMock, :rules, 0, fn _root, _ref, _path -> {:error, :absent} end)
     stacktrace:
       (mox 1.2.0) lib/mox.ex:681: Mox.add_expectation!/4
       (mox 1.2.0) lib/mox.ex:549: Mox.expect/4
       (hammox 0.7.0) lib/hammox.ex:54: anonymous fn/4 in Hammox.expect/4
       (hammox 0.7.0) lib/hammox/telemetry.ex:12: Hammox.Telemetry.NoOp.span/3
       test/anchor/managers/graph_baseline_test.exs:282: (test)

..    warning: Anchor.Domain.BaselineBase.locate/2 is undefined (module Anchor.Domain.BaselineBase is not available or is yet to be defined)
    │
 19 │       assert BaselineBase.locate([rule("r", @old)], "r") == {:path, @old}
    │                           ~
    │
    └─ test/anchor/domain/baseline_base_test.exs:19:27: Anchor.Domain.BaselineBaseTest."test locate/2 a rule whose baseline path was renamed is found at its path at the ref"/1
    └─ test/anchor/domain/baseline_base_test.exs:23:27: Anchor.Domain.BaselineBaseTest."test locate/2 positive control: an unrenamed path is found at the same path"/1
    └─ test/anchor/domain/baseline_base_test.exs:27:27: Anchor.Domain.BaselineBaseTest."test locate/2 a rule id with no baseline at the ref compares with an empty one"/1
    └─ test/anchor/domain/baseline_base_test.exs:31:27: Anchor.Domain.BaselineBaseTest."test locate/2 a rule id absent at the ref is a new rule"/1
    └─ test/anchor/domain/baseline_base_test.exs:35:27: Anchor.Domain.BaselineBaseTest."test locate/2 no config at the ref: every rule is new"/1
    └─ test/anchor/domain/baseline_base_test.exs:39:27: Anchor.Domain.BaselineBaseTest."test locate/2 the id decides, never the path: another rule's file at the same path is not it"/1

    warning: Anchor.Domain.BaselineBase.gone/2 is undefined (module Anchor.Domain.BaselineBase is not available or is yet to be defined)
    │
 52 │       assert BaselineBase.gone(base, [rule("kept", @new), rule("renamed", @old)]) == ["a", "b"]
    │                           ~
    │
    └─ test/anchor/domain/baseline_base_test.exs:52:27: Anchor.Domain.BaselineBaseTest."test gone/2 the ids that had a baseline at the ref and are not rules now, sorted"/1
    └─ test/anchor/domain/baseline_base_test.exs:56:27: Anchor.Domain.BaselineBaseTest."test gone/2 nothing is gone when there was no config at the ref"/1
```

## RN-A — locate/2 ignores the id: the first rule with a baseline answers

Mutated `lib/anchor/domain/baseline_base.ex`.

Run summary: `8 tests, 2 failures`

```text
  1) test locate/2 a rule id absent at the ref is a new rule (Anchor.Domain.BaselineBaseTest)
     test/anchor/domain/baseline_base_test.exs:30
     Assertion with == failed
     code:  assert BaselineBase.locate([rule("other", @old)], "r") == :new_rule
     left:  {:path, ".anchor/baselines/old.txt"}
     right: :new_rule
     stacktrace:
       test/anchor/domain/baseline_base_test.exs:31: (test)

..

  2) test locate/2 the id decides, never the path: another rule's file at the same path is not it (Anchor.Domain.BaselineBaseTest)
     test/anchor/domain/baseline_base_test.exs:38
     Assertion with == failed
     code:  assert BaselineBase.locate([rule("other", @new), rule("r", @old)], "r") == {:path, @old}
     left:  {:path, ".anchor/baselines/new.txt"}
     right: {:path, ".anchor/baselines/old.txt"}
     stacktrace:
       test/anchor/domain/baseline_base_test.exs:39: (test)
```

## RN-B — locate/2 reads a rule id absent at the ref as one with no baseline there

Mutated `lib/anchor/domain/baseline_base.ex`.

Run summary: `8 tests, 1 failure`

```text
  1) test locate/2 a rule id absent at the ref is a new rule (Anchor.Domain.BaselineBaseTest)
     test/anchor/domain/baseline_base_test.exs:30
     Assertion with == failed
     code:  assert BaselineBase.locate([rule("other", @old)], "r") == :new_rule
     left:  :no_baseline
     right: :new_rule
     stacktrace:
       test/anchor/domain/baseline_base_test.exs:31: (test)
```

## RN-C — gone/2 names a rule that had no baseline at the ref

Mutated `lib/anchor/domain/baseline_base.ex`.

Run summary: `8 tests, 1 failure`

```text
  1) test gone/2 the ids that had a baseline at the ref and are not rules now, sorted (Anchor.Domain.BaselineBaseTest)
     test/anchor/domain/baseline_base_test.exs:44
     Assertion with == failed
     code:  assert BaselineBase.gone(base, [rule("kept", @new), rule("renamed", @old)]) == ["a", "b"]
     left:  ["a", "b", "c"]
     right: ["a", "b"]
     stacktrace:
       test/anchor/domain/baseline_base_test.exs:52: (test)
```

## RN-D — gone/2 is not sorted

Mutated `lib/anchor/domain/baseline_base.ex`.

Run summary: `8 tests, 1 failure`

```text
  1) test gone/2 the ids that had a baseline at the ref and are not rules now, sorted (Anchor.Domain.BaselineBaseTest)
     test/anchor/domain/baseline_base_test.exs:44
     Assertion with == failed
     code:  assert BaselineBase.gone(base, [rule("kept", @new), rule("renamed", @old)]) == ["a", "b"]
     left:  ["b", "a"]
     right: ["a", "b"]
     stacktrace:
       test/anchor/domain/baseline_base_test.exs:52: (test)
```

## RN-E — the new-rule note never names the ids gone

Mutated `lib/anchor/domain/failures.ex`.

Run summary: `33 tests, 2 failures`

```text
  1) test judge/4 a rule id new at the ref is a first landing naming it and the ids gone (Anchor.Domain.EnforcementTest)
     test/anchor/domain/enforcement_test.exs:107
     Assertion with =~ failed
     code:  assert note.message =~ ~s|rules with a baseline at main that this config no longer has: "old_r"|
     left:  "NOTE: first landing of rule \"r\": no rule with that id had a baseline at main. Fix: review every line of .anchor/baselines/r.txt in this change; from here it only shrinks."
     right: "rules with a baseline at main that this config no longer has: \"old_r\""
     stacktrace:
       test/anchor/domain/enforcement_test.exs:122: (test)

.......................

  2) test run/2 --base REF finds the base baseline by rule id (DND-5629) a rule id new at the ref is a first landing named by the id; no file is read there (Anchor.Managers.GraphBaselineTest)
     test/anchor/managers/graph_baseline_test.exs:316
     Assertion with =~ failed
     code:  assert message =~ ~s|no longer has: "gone"|
     left:  "NOTE: first landing of rule \"f\": no rule with that id had a baseline at main. Fix: review every line of .anchor/baselines/f.txt in this change; from here it only shrinks."
     right: "no longer has: \"gone\""
     stacktrace:
       test/anchor/managers/graph_baseline_test.exs:328: (test)
```

## RN-F — the old path-keyed lookup: the base copy is read at the branch path

Mutated `lib/anchor/managers/graph.ex`.

Run summary: `23 tests, 2 failures`

```text
  1) test run/2 --base REF finds the base baseline by rule id (DND-5629) a renamed path with the same entries is clean (Anchor.Managers.GraphBaselineTest)
     test/anchor/managers/graph_baseline_test.exs:307
     ** (FunctionClauseError) no function clause matching in anonymous fn/3 in Anchor.Managers.GraphBaselineTest."test run/2 --base REF finds the base baseline by rule id (DND-5629) a renamed path with the same entries is clean"/1

     The following arguments were given to anonymous fn/3 in Anchor.Managers.GraphBaselineTest."test run/2 --base REF finds the base baseline by rule id (DND-5629) a renamed path with the same entries is clean"/1:

         # 1
         "/proj"

         # 2
         "main"

         # 3
         ".anchor/baselines/f.txt"

     code: assert %{exit_code: 0, findings: []} = Graph.run(request(%{base: "main"}), deps())
     stacktrace:
       test/anchor/managers/graph_baseline_test.exs:311: anonymous fn/3 in Anchor.Managers.GraphBaselineTest."test run/2 --base REF finds the base baseline by rule id (DND-5629) a renamed path with the same entries is clean"/1
       (hammox 0.7.0) lib/hammox.ex:402: anonymous fn/2 in Hammox.protected_code/3
       (hammox 0.7.0) lib/hammox/telemetry.ex:12: Hammox.Telemetry.NoOp.span/3
       (hammox 0.7.0) lib/hammox.ex:398: Hammox.protected_code/3
       (anchor 0.1.0) lib/anchor/managers/graph.ex:436: Anchor.Managers.Graph.show_base/4
       (anchor 0.1.0) lib/anchor/managers/graph.ex:372: Anchor.Managers.Graph.compare_baseline/5
       (anchor 0.1.0) lib/anchor/managers/graph.ex:348: Anchor.Managers.Graph.run_rule/6
       (elixir 1.19.4) lib/enum.ex:1688: Enum."-map/2-lists^map/1-1-"/2
       (anchor 0.1.0) lib/anchor/managers/graph.ex:237: Anchor.Managers.Graph.measured/5
       test/anchor/managers/graph_baseline_test.exs:313: (test)

...

  2) test run/2 --base REF finds the base baseline by rule id (DND-5629) a renamed baseline path with an added entry is GREW (Anchor.Managers.GraphBaselineTest)
     test/anchor/managers/graph_baseline_test.exs:294
     ** (FunctionClauseError) no function clause matching in anonymous fn/3 in Anchor.Managers.GraphBaselineTest."test run/2 --base REF finds the base baseline by rule id (DND-5629) a renamed baseline path with an added entry is GREW"/1

     The following arguments were given to anonymous fn/3 in Anchor.Managers.GraphBaselineTest."test run/2 --base REF finds the base baseline by rule id (DND-5629) a renamed baseline path with an added entry is GREW"/1:

         # 1
         "/proj"

         # 2
         "main"

         # 3
         ".anchor/baselines/f.txt"

     code: report = Graph.run(request(%{base: "main"}), deps())
     stacktrace:
       test/anchor/managers/graph_baseline_test.exs:298: anonymous fn/3 in Anchor.Managers.GraphBaselineTest."test run/2 --base REF finds the base baseline by rule id (DND-5629) a renamed baseline path with an added entry is GREW"/1
       (hammox 0.7.0) lib/hammox.ex:402: anonymous fn/2 in Hammox.protected_code/3
       (hammox 0.7.0) lib/hammox/telemetry.ex:12: Hammox.Telemetry.NoOp.span/3
       (hammox 0.7.0) lib/hammox.ex:398: Hammox.protected_code/3
       (anchor 0.1.0) lib/anchor/managers/graph.ex:436: Anchor.Managers.Graph.show_base/4
       (anchor 0.1.0) lib/anchor/managers/graph.ex:372: Anchor.Managers.Graph.compare_baseline/5
       (anchor 0.1.0) lib/anchor/managers/graph.ex:348: Anchor.Managers.Graph.run_rule/6
       (elixir 1.19.4) lib/enum.ex:1688: Enum."-map/2-lists^map/1-1-"/2
       (anchor 0.1.0) lib/anchor/managers/graph.ex:237: Anchor.Managers.Graph.measured/5
       test/anchor/managers/graph_baseline_test.exs:300: (test)
```

## RN-G — a rule with no baseline at the ref is a first landing, not compared with empty

Mutated `lib/anchor/managers/graph.ex`.

Run summary: `23 tests, 1 failure`

```text
  1) test run/2 --base REF finds the base baseline by rule id (DND-5629) a rule id that had no baseline at the ref: every entry is GREW (Anchor.Managers.GraphBaselineTest)
     test/anchor/managers/graph_baseline_test.exs:331
     Assertion with == failed
     code:  assert report.exit_code == 1
     left:  0
     right: 1
     stacktrace:
       test/anchor/managers/graph_baseline_test.exs:339: (test)
```

## RN-H — a base config that cannot be read reads as absent (every rule a first landing)

Mutated `lib/anchor/managers/graph.ex`.

Run summary: `23 tests, 1 failure`

```text
  1) test run/2 --base REF finds the base baseline by rule id (DND-5629) a base config that cannot be read fails closed on the config, naming the ref (Anchor.Managers.GraphBaselineTest)
     test/anchor/managers/graph_baseline_test.exs:355
     Assertion with == failed
     code:  assert report.exit_code == 1
     left:  0
     right: 1
     stacktrace:
       test/anchor/managers/graph_baseline_test.exs:367: (test)
```

## RN-I — GitShow.rules/3 reads a rejected config as no rules

Mutated `lib/anchor/adapters/git_show.ex`.

Run summary: `14 tests, 1 failure`

```text
  1) test rules/3 (DND-5629) a config the parser rejects is its error, never an empty rule list (Anchor.Adapters.GitShowTest)
     test/anchor/adapters/git_show_test.exs:191
     match (=) failed
     code:  assert {:error, {:invalid_config, _reason}} = GitShow.rules(root, "main", ".anchor.yml")
     left:  {:error, {:invalid_config, _reason}}
     right: {:ok, []}
     stacktrace:
       test/anchor/adapters/git_show_test.exs:197: (test)
```
