# Sabotage records: lint (branch dnd-5648-graph-followups)

- **Domain:** lint
- **Branch:** dnd-5648-graph-followups
- **Date:** 2026-11-03

## DND-5631: a violation both enforcement passes found is printed once

**Code under test:** `Anchor.Domain.EnforcementPasses.merge/2`, `Anchor.Domain.Failures.both_enforcement_modes/1`, and their call in `Anchor.Managers.Lint.detect_file/5`.

**Suite run:** one `test-slot` ran `sab.py` per mutation (wait 1.1 s, write, `mix test --timeout 2000 --max-cases 2 <tests>`, restore, wait 1.1 s). PA-R is the new Lint tests on the unfixed code (the Domain test did not exist yet). With every source restored: `222 tests, 0 failures` over the new Domain test, `lint_test.exs` and `test/anchor/check`.

| ID | Mutation | Tests | Result | Failing tests |
|---|---|---|---|---|
| PA-R | regression: the unfixed code, with the new Lint tests (`lib/anchor/managers/lint.ex`) | `lint_test.exs` | `33 tests, 2 failures` (red) | run/4 enforcement: report an unresolvable directive under a report and an enforced rule is one violation; run/4 enforcement: report positive control: a different finding in each pass is kept apart |
| PA-A | the report pass's copies are all kept (`lib/anchor/domain/enforcement_passes.ex`) | `enforcement_passes_test.exs`, `lint_test.exs` | `38 tests, 4 failures` (red) | merge/2 a message with no Fix: gets the note at its end; merge/2 a violation both passes found is one, enforced, naming both modes; run/4 enforcement: report an unresolvable directive under a report and an enforced rule is one violation; run/4 enforcement: report the same finding from a report and an enforced rule is one, enforced |
| PA-B | the kept copy does not name both modes (`lib/anchor/domain/enforcement_passes.ex`) | `enforcement_passes_test.exs`, `lint_test.exs` | `38 tests, 3 failures` (red) | merge/2 a violation both passes found is one, enforced, naming both modes; merge/2 a message with no Fix: gets the note at its end; run/4 enforcement: report an unresolvable directive under a report and an enforced rule is one violation |
| PA-C | the line is left out of a violation's identity (`lib/anchor/domain/enforcement_passes.ex`) | `enforcement_passes_test.exs`, `lint_test.exs` | `38 tests, 1 failure` (red) | merge/2 the same message on another line is another violation |
| PA-D | the report copy is kept instead of the enforced one (`lib/anchor/domain/enforcement_passes.ex`) | `enforcement_passes_test.exs`, `lint_test.exs` | `38 tests, 3 failures` (red) | merge/2 a violation both passes found is one, enforced, naming both modes; run/4 enforcement: report an unresolvable directive under a report and an enforced rule is one violation; run/4 enforcement: report the same finding from a report and an enforced rule is one, enforced |

Filed under their own domain word (ADR 003): PA-E in `failures-20261103-dnd_5648_graph_followups.md`.

### PA-R: regression: the unfixed code, with the new Lint tests

Run summary: `33 tests, 2 failures`

```text


  1) test run/4 enforcement: report an unresolvable directive under a report and an enforced rule is one violation (Anchor.Managers.LintTest)
     test/anchor/managers/lint_test.exs:111
     match (=) failed
     code:  assert [unresolved] = Enum.filter(violations, &(&1.message =~ "cannot statically resolve"))
     left:  [unresolved]
     right: [
              %Anchor.Domain.Violation{
                line: 2,
                trigger: "alias",
                message: "Anchor cannot statically resolve the target of this `alias`, so references made through it cannot be checked for forbidden dependencies. Fix: name the module literally (e.g. `alias MyApp.Foo`).",
                filename: nil,
                kind: :rule,
                key: nil,
                rule_id: nil,
                enforcement: :enforce
              },
              %Anchor.Domain.Violation{
                line: 2,
                trigger: "alias",
                message: "Anchor cannot statically resolve the target of this `alias`, so references made through it cannot be checked for forbidden dependencies. Fix: name the module literally (e.g. `alias MyApp.Foo`).",
                filename: nil,
                kind: :rule,
                key: nil,
                rule_id: nil,
                enforcement: :report



  2) test run/4 enforcement: report positive control: a different finding in each pass is kept apart (Anchor.Managers.LintTest)
     test/anchor/managers/lint_test.exs:144
     match (=) failed
     code:  assert {:ok, [{_file, [%Violation{trigger: "MyApp.Same", enforcement: :enforce}]}]} =
              Lint.run(MustUseModule, [source_file], [], config_loader: ConfigLoaderMock)
     left:  {:ok, [{_file, [%Anchor.Domain.Violation{trigger: "MyApp.Same", enforcement: :enforce}]}]}
     right: {:ok,
             [
               {%SourceFile<lib/thing.ex>,
                [
                  %Anchor.Domain.Violation{
                    line: 1,
                    trigger: "MyApp.Same",
                    message: "Module must use MyApp.Same",
                    filename: nil,
                    kind: :rule,
                    key: nil,
                    rule_id: nil,
                    enforcement: :enforce
                  },
                  %Anchor.Domain.Violation{
                    line: 1,
                    trigger: "MyApp.Same",
                    message: "Module must use MyApp.Same",
                    filename: nil,
```

### PA-A: the report pass's copies are all kept

Run summary: `38 tests, 4 failures`

```text


  1) test merge/2 a message with no Fix: gets the note at its end (Anchor.Domain.EnforcementPassesTest)
     test/anchor/domain/enforcement_passes_test.exs:42
     match (=) failed
     code:  assert [%{message: "x (Found under rules in enforcement: enforce and report; " <> _}] =
              EnforcementPasses.merge([v("x")], [v("x", %{enforcement: :report})])
     left:  [%{message: "x (Found under rules in enforcement: enforce and report; " <> _}]
     right: [
              %Anchor.Domain.Violation{
                line: 3,
                trigger: "alias",
                message: "x (Found under rules in enforcement: enforce and report; reported once, enforced.)",
                filename: nil,
                kind: :rule,
                key: nil,
                rule_id: nil,
                enforcement: :enforce
              },
              %Anchor.Domain.Violation{
                line: 3,
                trigger: "alias",
                message: "x",
                filename: nil,
                kind: :rule,
                key: nil,
                rule_id: nil,







  2) test merge/2 a violation both passes found is one, enforced, naming both modes (Anchor.Domain.EnforcementPassesTest)
     test/anchor/domain/enforcement_passes_test.exs:15
     match (=) failed
     code:  assert [%Violation{enforcement: :enforce, message: message}] =
              EnforcementPasses.merge(enforced, reported)
     left:  [%Anchor.Domain.Violation{enforcement: :enforce, message: message}]
     right: [
              %Anchor.Domain.Violation{
                line: 3,
                trigger: "alias",
                message: "cannot resolve. (Found under rules in enforcement: enforce and report; reported once, enforced.) Fix: name it",
                filename: nil,
                kind: :rule,
                key: nil,
                rule_id: nil,
                enforcement: :enforce
              },
              %Anchor.Domain.Violation{
                line: 3,
                trigger: "alias",
                message: "cannot resolve. Fix: name it",
                filename: nil,
                kind: :rule,
                key: nil,
                rule_id: nil,



  3) test run/4 enforcement: report an unresolvable directive under a report and an enforced rule is one violation (Anchor.Managers.LintTest)
     test/anchor/managers/lint_test.exs:112
     match (=) failed
     code:  assert [unresolved] = Enum.filter(violations, &(&1.message =~ "cannot statically resolve"))
     left:  [unresolved]
     right: [
              %Anchor.Domain.Violation{
                line: 2,
                trigger: "alias",
                message: "Anchor cannot statically resolve the target of this `alias`, so references made through it cannot be checked for forbidden dependencies. (Found under rules in enforcement: enforce and report; reported once, enforced.) Fix: name the module literally (e.g. `alias MyApp.Foo`).",
                filename: nil,
                kind: :rule,
                key: nil,
                rule_id: nil,
                enforcement: :enforce
              },
              %Anchor.Domain.Violation{
                line: 2,
                trigger: "alias",
                message: "Anchor cannot statically resolve the target of this `alias`, so references made through it cannot be checked for forbidden dependencies. Fix: name the module literally (e.g. `alias MyApp.Foo`).",
                filename: nil,
                kind: :rule,
                key: nil,
                rule_id: nil,
                enforcement: :report



  4) test run/4 enforcement: report the same finding from a report and an enforced rule is one, enforced (Anchor.Managers.LintTest)
     test/anchor/managers/lint_test.exs:145
     match (=) failed
     code:  assert {:ok, [{_file, [%Violation{trigger: "MyApp.Same", enforcement: :enforce}]}]} =
              Lint.run(MustUseModule, [source_file], [], config_loader: ConfigLoaderMock)
     left:  {:ok, [{_file, [%Anchor.Domain.Violation{trigger: "MyApp.Same", enforcement: :enforce}]}]}
     right: {:ok,
             [
               {%SourceFile<lib/thing.ex>,
                [
                  %Anchor.Domain.Violation{
                    line: 1,
                    trigger: "MyApp.Same",
                    message: "Module must use MyApp.Same (Found under rules in enforcement: enforce and report; reported once, enforced.)",
                    filename: nil,
                    kind: :rule,
                    key: nil,
                    rule_id: nil,
                    enforcement: :enforce
                  },
                  %Anchor.Domain.Violation{
                    line: 1,
                    trigger: "MyApp.Same",
                    message: "Module must use MyApp.Same",
                    filename: nil,
```

### PA-B: the kept copy does not name both modes

Run summary: `38 tests, 3 failures`

```text


  1) test merge/2 a violation both passes found is one, enforced, naming both modes (Anchor.Domain.EnforcementPassesTest)
     test/anchor/domain/enforcement_passes_test.exs:15
     Assertion with == failed
     code:  assert message ==
              "cannot resolve. (Found under rules in enforcement: enforce and report; " <>
                "reported once, enforced.) Fix: name it"
     left:  "cannot resolve. Fix: name it"
     right: "cannot resolve. (Found under rules in enforcement: enforce and report; reported once, enforced.) Fix: name it"
     stacktrace:
       test/anchor/domain/enforcement_passes_test.exs:22: (test)







  2) test merge/2 a message with no Fix: gets the note at its end (Anchor.Domain.EnforcementPassesTest)
     test/anchor/domain/enforcement_passes_test.exs:42
     match (=) failed
     code:  assert [%{message: "x (Found under rules in enforcement: enforce and report; " <> _}] =
              EnforcementPasses.merge([v("x")], [v("x", %{enforcement: :report})])
     left:  [%{message: "x (Found under rules in enforcement: enforce and report; " <> _}]
     right: [
              %Anchor.Domain.Violation{
                line: 3,
                trigger: "alias",
                message: "x",
                filename: nil,
                kind: :rule,
                key: nil,
                rule_id: nil,
                enforcement: :enforce
              }
            ]
     stacktrace:
       test/anchor/domain/enforcement_passes_test.exs:43: (test)

.................



  3) test run/4 enforcement: report an unresolvable directive under a report and an enforced rule is one violation (Anchor.Managers.LintTest)
     test/anchor/managers/lint_test.exs:112
     Assertion with =~ failed
     code:  assert unresolved.message =~ "rules in enforcement: enforce and report"
     left:  "Anchor cannot statically resolve the target of this `alias`, so references made through it cannot be checked for forbidden dependencies. Fix: name the module literally (e.g. `alias MyApp.Foo`)."
     right: "rules in enforcement: enforce and report"
     stacktrace:
       test/anchor/managers/lint_test.exs:128: (test)

................
```

### PA-C: the line is left out of a violation's identity

Run summary: `38 tests, 1 failure`

```text


  1) test merge/2 the same message on another line is another violation (Anchor.Domain.EnforcementPassesTest)
     test/anchor/domain/enforcement_passes_test.exs:34
     match (=) failed
     code:  assert [%{line: 3, message: "x"}, %{line: 4, enforcement: :report}] =
              EnforcementPasses.merge(enforced, reported)
     left:  [%{line: 3, message: "x"}, %{line: 4, enforcement: :report}]
     right: [
              %Anchor.Domain.Violation{
                line: 3,
                trigger: "alias",
                message: "x (Found under rules in enforcement: enforce and report; reported once, enforced.)",
                filename: nil,
                kind: :rule,
                key: nil,
                rule_id: nil,
                enforcement: :enforce
              }
            ]
     stacktrace:
       test/anchor/domain/enforcement_passes_test.exs:38: (test)

..................................
```

### PA-D: the report copy is kept instead of the enforced one

Run summary: `38 tests, 3 failures`

```text


  1) test merge/2 a violation both passes found is one, enforced, naming both modes (Anchor.Domain.EnforcementPassesTest)
     test/anchor/domain/enforcement_passes_test.exs:15
     match (=) failed
     code:  assert [%Violation{enforcement: :enforce, message: message}] =
              EnforcementPasses.merge(enforced, reported)
     left:  [%Anchor.Domain.Violation{enforcement: :enforce, message: message}]
     right: [
              %Anchor.Domain.Violation{
                line: 3,
                trigger: "alias",
                message: "cannot resolve. (Found under rules in enforcement: enforce and report; reported once, enforced.) Fix: name it",
                filename: nil,
                kind: :rule,
                key: nil,
                rule_id: nil,
                enforcement: :report
              }
            ]
     stacktrace:
       test/anchor/domain/enforcement_passes_test.exs:19: (test)

....................



  2) test run/4 enforcement: report an unresolvable directive under a report and an enforced rule is one violation (Anchor.Managers.LintTest)
     test/anchor/managers/lint_test.exs:112
     Assertion with == failed
     code:  assert unresolved.enforcement == :enforce
     left:  :report
     right: :enforce
     stacktrace:
       test/anchor/managers/lint_test.exs:126: (test)

.......



  3) test run/4 enforcement: report the same finding from a report and an enforced rule is one, enforced (Anchor.Managers.LintTest)
     test/anchor/managers/lint_test.exs:145
     match (=) failed
     code:  assert {:ok, [{_file, [%Violation{trigger: "MyApp.Same", enforcement: :enforce}]}]} =
              Lint.run(MustUseModule, [source_file], [], config_loader: ConfigLoaderMock)
     left:  {:ok, [{_file, [%Anchor.Domain.Violation{trigger: "MyApp.Same", enforcement: :enforce}]}]}
     right: {:ok,
             [
               {%SourceFile<lib/thing.ex>,
                [
                  %Anchor.Domain.Violation{
                    line: 1,
                    trigger: "MyApp.Same",
                    message: "Module must use MyApp.Same (Found under rules in enforcement: enforce and report; reported once, enforced.)",
                    filename: nil,
                    kind: :rule,
                    key: nil,
                    rule_id: nil,
                    enforcement: :report
                  }
                ]}
             ]}
     stacktrace:
       test/anchor/managers/lint_test.exs:155: (test)
```

## DND-5632 critic round 1: a finding two rules make is judged by each, printed once, enforced first (AB-T)

**Run with:** the `## DND-5632 critic round 1: a finding two rules make is judged by each, printed once, enforced first` section of `baseline-20261103-dnd_5648_graph_followups.md`, which names the code under test and the suite run; filed here by the module mutated.

| ID | Mutation | Tests | Result | Failing tests |
|---|---|---|---|---|
| AB-T | the enforced copy does not win over a report copy seen first (`lib/anchor/domain/enforcement_passes.ex`) | `lint_baseline_test.exs`, `enforcement_passes_test.exs`, `lint_test.exs` | `60 tests, 2 failures` (red) | unique/1 (DND-5632) the enforced copy wins over a report copy seen first; a finding two rules make a report rule's copy never downgrades an enforced baselined rule's NEW finding |

### AB-T: the enforced copy does not win over a report copy seen first

Run summary: `60 tests, 2 failures`

```text
  1) test unique/1 (DND-5632) the enforced copy wins over a report copy seen first (Anchor.Domain.EnforcementPassesTest)
     test/anchor/domain/enforcement_passes_test.exs:62
     match (=) failed
     code:  assert [%Violation{enforcement: :enforce, key: "pure|lib/a.ex|alias"}] =
              EnforcementPasses.unique([reported, enforced])
     left:  [%Anchor.Domain.Violation{enforcement: :enforce, key: "pure|lib/a.ex|alias"}]
     right: [
              %Anchor.Domain.Violation{
                line: 3,
                trigger: "alias",
                message: "a",
                filename: nil,
                kind: :rule,
                key: nil,
                rule_id: nil,
                enforcement: :report
              }
            ]
     stacktrace:
       test/anchor/domain/enforcement_passes_test.exs:66: (test)

.................

  2) test a finding two rules make a report rule's copy never downgrades an enforced baselined rule's NEW finding (Anchor.Managers.LintBaselineTest)
     test/anchor/managers/lint_baseline_test.exs:251
     match (=) failed
     code:  assert [%Violation{enforcement: :enforce, key: "pure|lib/b.ex|File"}] = violations
     left:  [%Anchor.Domain.Violation{enforcement: :enforce, key: "pure|lib/b.ex|File"}]
     right: [
              %Anchor.Domain.Violation{
                line: 2,
                trigger: "File",
                message: "Module has forbidden direct dependency on File",
                filename: nil,
                kind: :rule,
                key: nil,
                rule_id: nil,
                enforcement: :report
              }
            ]
     stacktrace:
       test/anchor/managers/lint_baseline_test.exs:259: (test)

......................................
```


## DND-5632 critic round 2: a baselined rule's keyed copy is never dropped for an unkeyed one (AB-R2, AB-V, AB-W)

**Run with:** the `## DND-5632 critic round 2: a baselined rule's keyed copy is never dropped for an unkeyed one` section of `baseline-20261103-dnd_5648_graph_followups.md`, which names the code under test and the suite run; filed here by the module mutated.

| ID | Mutation | Tests | Result | Failing tests |
|---|---|---|---|---|
| AB-R2 | regression: round 1's unique/1 (first copy wins on a tie), with the new tests (`lib/anchor/domain/enforcement_passes.ex`) | `lint_baseline_test.exs`, `enforcement_passes_test.exs` | `31 tests, 5 failures` (red) | unique/1 (DND-5632) a keyed copy is kept over an unkeyed one of the same enforcement (its key is written); unique/1 (DND-5632) an enforced unkeyed copy is kept beside a report keyed copy; unique/1 (DND-5632) two baselined rules' keyed copies are both kept; a finding two rules make with no baseline yet, two report rules' finding keeps the baselined rule's key (for --write); beside rules with no baseline a violation every pass makes once per file is printed once |
| AB-V | a keyed report copy is dropped for an unkeyed one (`lib/anchor/domain/enforcement_passes.ex`) | `lint_baseline_test.exs`, `enforcement_passes_test.exs`, `lint_test.exs`, `ast_baseline_test.exs`, `ast_baseline_integration_test.exs` | `83 tests, 4 failures` (red) | unique/1 (DND-5632) a keyed copy is kept over an unkeyed one of the same enforcement (its key is written); unique/1 (DND-5632) an enforced unkeyed copy is kept beside a report keyed copy; a finding two rules make with no baseline yet, two report rules' finding keeps the baselined rule's key (for --write); a baselined rule's findings STALE takes the rule's enforcement: report |
| AB-W | a report copy covers an enforced one (`lib/anchor/domain/enforcement_passes.ex`) | `lint_baseline_test.exs`, `enforcement_passes_test.exs`, `lint_test.exs`, `ast_baseline_test.exs`, `ast_baseline_integration_test.exs` | `83 tests, 1 failure` (red) | unique/1 (DND-5632) an enforced unkeyed copy is kept beside a report keyed copy |

### AB-R2: regression: round 1's unique/1 (first copy wins on a tie), with the new tests

Run summary: `31 tests, 5 failures`

```text
  1) test unique/1 (DND-5632) a keyed copy is kept over an unkeyed one of the same enforcement (its key is written) (Anchor.Domain.EnforcementPassesTest)
     test/anchor/domain/enforcement_passes_test.exs:71
     match (=) failed
     code:  assert [%Violation{key: "pure|lib/a.ex|alias"}] = EnforcementPasses.unique([plain, keyed])
     left:  [%Anchor.Domain.Violation{key: "pure|lib/a.ex|alias"}]
     right: [
              %Anchor.Domain.Violation{
                line: 3,
                trigger: "alias",
                message: "a",
                filename: nil,
                kind: :rule,
                key: nil,
                rule_id: nil,
                enforcement: :report
              }
            ]
     stacktrace:
       test/anchor/domain/enforcement_passes_test.exs:75: (test)

..

  2) test unique/1 (DND-5632) an enforced unkeyed copy is kept beside a report keyed copy (Anchor.Domain.EnforcementPassesTest)
     test/anchor/domain/enforcement_passes_test.exs:85
     Assertion with == failed
     code:  assert EnforcementPasses.unique([plain, keyed]) == [plain, keyed]
     left:  [
              %Anchor.Domain.Violation{
                line: 3,
                trigger: "alias",
                message: "a",
                filename: nil,
                kind: :rule,
                key: nil,
                rule_id: nil,
                enforcement: :enforce
              }
            ]
     right: [
              %Anchor.Domain.Violation{
                line: 3,
                trigger: "alias",
                message: "a",
                filename: nil,
                kind: :rule,
                key: nil,
                rule_id: nil,

  3) test unique/1 (DND-5632) two baselined rules' keyed copies are both kept (Anchor.Domain.EnforcementPassesTest)
     test/anchor/domain/enforcement_passes_test.exs:78
     Assertion with == failed
     code:  assert EnforcementPasses.unique([a, b]) == [a, b]
     left:  [
              %Anchor.Domain.Violation{
                line: 3,
                trigger: "alias",
                message: "a",
                filename: nil,
                kind: :rule,
                key: "pure|lib/a.ex|alias",
                rule_id: "pure",
                enforcement: :enforce
              }
            ]
     right: [
              %Anchor.Domain.Violation{
                line: 3,
                trigger: "alias",
                message: "a",
                filename: nil,
                kind: :rule,
                key: "pure|lib/a.ex|alias",
                rule_id: "pure",
```

(2 more failures in this run, not quoted; every failing test is named in the table.)

### AB-V: a keyed report copy is dropped for an unkeyed one

Run summary: `83 tests, 4 failures`

```text
  1) test unique/1 (DND-5632) a keyed copy is kept over an unkeyed one of the same enforcement (its key is written) (Anchor.Domain.EnforcementPassesTest)
     test/anchor/domain/enforcement_passes_test.exs:71
     match (=) failed
     code:  assert [%Violation{key: "pure|lib/a.ex|alias"}] = EnforcementPasses.unique([plain, keyed])
     left:  [%Anchor.Domain.Violation{key: "pure|lib/a.ex|alias"}]
     right: []
     stacktrace:
       test/anchor/domain/enforcement_passes_test.exs:75: (test)

.....

  2) test unique/1 (DND-5632) an enforced unkeyed copy is kept beside a report keyed copy (Anchor.Domain.EnforcementPassesTest)
     test/anchor/domain/enforcement_passes_test.exs:85
     Assertion with == failed
     code:  assert EnforcementPasses.unique([plain, keyed]) == [plain, keyed]
     left:  [
              %Anchor.Domain.Violation{
                line: 3,
                trigger: "alias",
                message: "a",
                filename: nil,
                kind: :rule,
                key: nil,
                rule_id: nil,
                enforcement: :enforce
              }
            ]
     right: [
              %Anchor.Domain.Violation{
                line: 3,
                trigger: "alias",
                message: "a",
                filename: nil,
                kind: :rule,
                key: nil,
                rule_id: nil,

  3) test a finding two rules make with no baseline yet, two report rules' finding keeps the baselined rule's key (for --write) (Anchor.Managers.LintBaselineTest)
     test/anchor/managers/lint_baseline_test.exs:273
     match (=) failed
     code:  assert [{"lib/b.ex", "File", "pure|lib/b.ex|File"}] = findings(results)
     left:  [{"lib/b.ex", "File", "pure|lib/b.ex|File"}]
     right: []
     stacktrace:
       test/anchor/managers/lint_baseline_test.exs:282: (test)

.....
```

(1 more failures in this run, not quoted; every failing test is named in the table.)

### AB-W: a report copy covers an enforced one

Run summary: `83 tests, 1 failure`

```text
  1) test unique/1 (DND-5632) an enforced unkeyed copy is kept beside a report keyed copy (Anchor.Domain.EnforcementPassesTest)
     test/anchor/domain/enforcement_passes_test.exs:85
     Assertion with == failed
     code:  assert EnforcementPasses.unique([plain, keyed]) == [plain, keyed]
     left:  [
              %Anchor.Domain.Violation{
                line: 3,
                trigger: "alias",
                message: "a",
                filename: nil,
                kind: :rule,
                key: "pure|lib/a.ex|alias",
                rule_id: "pure",
                enforcement: :report
              }
            ]
     right: [
              %Anchor.Domain.Violation{
                line: 3,
                trigger: "alias",
                message: "a",
                filename: nil,
                kind: :rule,
                key: nil,
                rule_id: nil,
```

## Whole-MR critic: a once-per-file violation prints once beside rules in both modes

**Code under test:** `Anchor.Domain.EnforcementPasses.unique/1`'s identity and `Anchor.Domain.Failures.without_both_enforcement_modes/1`.

**Found by:** the whole-MR critic on 6ed556b: with an enforced rule, a report rule and a baselined rule on one check, `merge/2`'s note changed the plain copy's message, so `unique/1` read the baselined rule's keyed copy as a different finding and the same line printed twice (the DND-5631 symptom). A finding's identity now ignores that note.

**Suite run:** ID-R is the new tests on the unfixed code. ID-A and ID-B were run by `sab.py` (wait 1.1 s, write, run, restore, wait 1.1 s). With every source restored: `86 tests, 0 failures` over enforcement_passes, lint_baseline, lint and failures_graph tests.

| ID | Mutation | Tests | Result | Failing tests |
|---|---|---|---|---|
| ID-R | regression: identity holds the whole message, with the new tests (`lib/anchor/domain/enforcement_passes.ex`) | `enforcement_passes_test.exs`, `lint_baseline_test.exs` | `36 tests, 2 failures` (red) | unique/1 (DND-5632) a copy naming both modes is the same finding as one that does not; beside rules with no baseline a once-per-file violation is printed once beside rules in both modes |
| ID-A | identity keeps the note (`lib/anchor/domain/enforcement_passes.ex`) | `enforcement_passes_test.exs`, `lint_baseline_test.exs` | `36 tests, 2 failures` (red) | unique/1 (DND-5632) a copy naming both modes is the same finding as one that does not; beside rules with no baseline a once-per-file violation is printed once beside rules in both modes |
| ID-B | identity ignores the message altogether (`lib/anchor/domain/enforcement_passes.ex`) | `enforcement_passes_test.exs` | `14 tests, 1 failure` (red) | unique/1 (DND-5632) a different message is a different finding, note or no note |

### ID-R: regression: identity holds the whole message, with the new tests

Run summary: `36 tests, 2 failures`

```text
  1) test unique/1 (DND-5632) a copy naming both modes is the same finding as one that does not (Anchor.Domain.EnforcementPassesTest)
     test/anchor/domain/enforcement_passes_test.exs:56
     Assertion with == failed
     code:  assert EnforcementPasses.unique([merged, keyed]) == [keyed]
     left:  [
              %Anchor.Domain.Violation{
                line: 3,
                trigger: "alias",
                message: "a (Found under rules in enforcement: enforce and report; reported once, enforced.) Fix: b",
                filename: nil,
                kind: :rule,
                key: nil,
                rule_id: nil,
                enforcement: :enforce
              },
              %Anchor.Domain.Violation{
                line: 3,
                trigger: "alias",
                message: "a Fix: b",
                filename: nil,
                kind: :rule,
                key: "pure|lib/a.ex|alias",
                rule_id: "pure",
                enforcement: :enforce
              }

  2) test beside rules with no baseline a once-per-file violation is printed once beside rules in both modes (Anchor.Managers.LintBaselineTest)
     test/anchor/managers/lint_baseline_test.exs:271
     match (=) failed
     code:  assert [%Violation{key: "pure|lib/c.ex|alias"}] = unresolved
     left:  [%Anchor.Domain.Violation{key: "pure|lib/c.ex|alias"}]
     right: [
              %Anchor.Domain.Violation{
                line: 2,
                trigger: "alias",
                message: "Anchor cannot statically resolve the target of this `alias`, so references made through it cannot be checked for forbidden dependencies. (Found under rules in enforcement: enforce and report; reported once, enforced.) Fix: name the module literally (e.g. `alias MyApp.Foo`).",
                filename: nil,
                kind: :rule,
                key: nil,
                rule_id: nil,
                enforcement: :enforce
              },
              %Anchor.Domain.Violation{
                line: 2,
                trigger: "alias",
                message: "Anchor cannot statically resolve the target of this `alias`, so references made through it cannot be checked for forbidden dependencies. Fix: name the module literally (e.g. `alias MyApp.Foo`).",
                filename: nil,
                kind: :rule,
                key: "pure|lib/c.ex|alias",
                rule_id: "pure",
                enforcement: :enforce
```

### ID-A: identity keeps the note

Run summary: `36 tests, 2 failures`

```text
  1) test unique/1 (DND-5632) a copy naming both modes is the same finding as one that does not (Anchor.Domain.EnforcementPassesTest)
     test/anchor/domain/enforcement_passes_test.exs:56
     Assertion with == failed
     code:  assert EnforcementPasses.unique([merged, keyed]) == [keyed]
     left:  [
              %Anchor.Domain.Violation{
                line: 3,
                trigger: "alias",
                message: "a (Found under rules in enforcement: enforce and report; reported once, enforced.) Fix: b",
                filename: nil,
                kind: :rule,
                key: nil,
                rule_id: nil,
                enforcement: :enforce
              },
              %Anchor.Domain.Violation{
                line: 3,
                trigger: "alias",
                message: "a Fix: b",
                filename: nil,
                kind: :rule,
                key: "pure|lib/a.ex|alias",
                rule_id: "pure",
                enforcement: :enforce
              }

  2) test beside rules with no baseline a once-per-file violation is printed once beside rules in both modes (Anchor.Managers.LintBaselineTest)
     test/anchor/managers/lint_baseline_test.exs:271
     match (=) failed
     code:  assert [%Violation{key: "pure|lib/c.ex|alias"}] = unresolved
     left:  [%Anchor.Domain.Violation{key: "pure|lib/c.ex|alias"}]
     right: [
              %Anchor.Domain.Violation{
                line: 2,
                trigger: "alias",
                message: "Anchor cannot statically resolve the target of this `alias`, so references made through it cannot be checked for forbidden dependencies. (Found under rules in enforcement: enforce and report; reported once, enforced.) Fix: name the module literally (e.g. `alias MyApp.Foo`).",
                filename: nil,
                kind: :rule,
                key: nil,
                rule_id: nil,
                enforcement: :enforce
              },
              %Anchor.Domain.Violation{
                line: 2,
                trigger: "alias",
                message: "Anchor cannot statically resolve the target of this `alias`, so references made through it cannot be checked for forbidden dependencies. Fix: name the module literally (e.g. `alias MyApp.Foo`).",
                filename: nil,
                kind: :rule,
                key: "pure|lib/c.ex|alias",
                rule_id: "pure",
                enforcement: :enforce
```

### ID-B: identity ignores the message altogether

Run summary: `14 tests, 1 failure`

```text
  1) test unique/1 (DND-5632) a different message is a different finding, note or no note (Anchor.Domain.EnforcementPassesTest)
     test/anchor/domain/enforcement_passes_test.exs:66
     Assertion with == failed
     code:  assert EnforcementPasses.unique([merged, other]) == [merged, other]
     left:  [
              %Anchor.Domain.Violation{
                line: 3,
                trigger: "alias",
                message: "c",
                filename: nil,
                kind: :rule,
                key: "pure|lib/a.ex|alias",
                rule_id: "pure",
                enforcement: :enforce
              }
            ]
     right: [
              %Anchor.Domain.Violation{
                line: 3,
                trigger: "alias",
                message: "a (Found under rules in enforcement: enforce and report; reported once, enforced.)",
                filename: nil,
                kind: :rule,
                key: nil,
                rule_id: nil,
```

