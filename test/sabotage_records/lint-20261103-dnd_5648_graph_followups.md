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
| PA-E | the note goes after the Fix: line (`lib/anchor/domain/failures.ex`) | `enforcement_passes_test.exs`, `lint_test.exs` | `38 tests, 1 failure` (red) | merge/2 a violation both passes found is one, enforced, naming both modes |

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

### PA-E: the note goes after the Fix: line

Run summary: `38 tests, 1 failure`

```text






  1) test merge/2 a violation both passes found is one, enforced, naming both modes (Anchor.Domain.EnforcementPassesTest)
     test/anchor/domain/enforcement_passes_test.exs:15
     Assertion with == failed
     code:  assert message ==
              "cannot resolve. (Found under rules in enforcement: enforce and report; " <>
                "reported once, enforced.) Fix: name it"
     left:  "cannot resolve. Fix: name it (Found under rules in enforcement: enforce and report; reported once, enforced.)"
     right: "cannot resolve. (Found under rules in enforcement: enforce and report; reported once, enforced.) Fix: name it"
     stacktrace:
       test/anchor/domain/enforcement_passes_test.exs:22: (test)

.....................................
```

