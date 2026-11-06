# Sabotage record — one finding two rules make (the merge with main at 07aef9f)

- **Domain:** enforcement_passes
- **Branch:** dnd-5443-graph-rules-b
- **Date:** 2026-11-06
- **Code under test:** `Anchor.Domain.EnforcementPasses` (identity), `Anchor.Domain.RuleShapes.without_fix/1`
- **Suite run:** each mutation ran `mix test --force --timeout 2000 --max-cases 2 <its test files>` inside one `test-slot`, by a driver that applied it, ran the files and restored the source. The checkout's absolute path in the output reads `<worktree>`.

EP-F restores the unfixed behaviour; its red is the regression red in the fix commit.

| # | Mutation | Tests run | Result | Failing tests |
|---|---|---|---|---|
| EP-F | identity keeps the Fix: sentence (`lib/anchor/domain/enforcement_passes.ex`) | `enforcement_passes_test.exs`, `lint_baseline_test.exs` | `37 tests, 3 failures` (red) | merge/2 two rules' copies differing only in their Fix: are one finding, the enforced one's; a finding two rules make with no baseline yet, two report rules' finding keeps the baselined rule's key (for --write); a finding two rules make a report rule's copy never downgrades an enforced baselined rule's NEW finding |
| RS-W | without_fix drops nothing (`lib/anchor/domain/rule_shapes.ex`) | `enforcement_passes_test.exs` | `15 tests, 1 failure` (red) | merge/2 two rules' copies differing only in their Fix: are one finding, the enforced one's |

## EP-F — identity keeps the Fix: sentence

Run summary: `37 tests, 3 failures`

```text
  1) test merge/2 two rules' copies differing only in their Fix: are one finding, the enforced one's (Anchor.Domain.EnforcementPassesTest)
     test/anchor/domain/enforcement_passes_test.exs:29
     match (=) failed
     code:  assert [%Violation{enforcement: :enforce, message: message}] =
              EnforcementPasses.merge(enforced, reported)
     left:  [%Anchor.Domain.Violation{enforcement: :enforce, message: message}]
     right: [
              %Anchor.Domain.Violation{
                line: 3,
                trigger: "alias",
                message: "cannot resolve. Fix: enforced rule's shape",
                filename: nil,
                kind: :rule,
                key: nil,
                rule_id: nil,
                enforcement: :enforce
              },
              %Anchor.Domain.Violation{
                line: 3,
                trigger: "alias",
                message: "cannot resolve. Fix: report rule's shape",
                filename: nil,
                kind: :rule,
                key: nil,
                rule_id: nil,
                enforcement: :report
              }
            ]
     stacktrace:
       test/anchor/domain/enforcement_passes_test.exs:33: (test)

......

  2) test a finding two rules make with no baseline yet, two report rules' finding keeps the baselined rule's key (for --write) (Anchor.Managers.LintBaselineTest)
     test/anchor/managers/lint_baseline_test.exs:329
     match (=) failed
     code:  assert [{"lib/b.ex", "File", "pure|lib/b.ex|File"}] = findings(results)
     left:  [{"lib/b.ex", "File", "pure|lib/b.ex|File"}]
     right: [
              {"lib/b.ex", "File", nil},
              {"lib/b.ex", "File", "pure|lib/b.ex|File"}
            ]
     stacktrace:
       test/anchor/managers/lint_baseline_test.exs:338: (test)

..........

  3) test a finding two rules make a report rule's copy never downgrades an enforced baselined rule's NEW finding (Anchor.Managers.LintBaselineTest)
     test/anchor/managers/lint_baseline_test.exs:309
     match (=) failed
     code:  assert [%Violation{enforcement: :enforce, key: "pure|lib/b.ex|File"}] = violations
     left:  [%Anchor.Domain.Violation{enforcement: :enforce, key: "pure|lib/b.ex|File"}]
     right: [
              %Anchor.Domain.Violation{
                line: 2,
                trigger: "File",
                message: "Module has forbidden direct dependency on File. Fix: do not reference File from a module this rule selects; reach it through a module the rule allows",
                filename: nil,
                kind: :rule,
                key: nil,
                rule_id: nil,
                enforcement: :report
              },
              %Anchor.Domain.Violation{
                line: 2,
                trigger: "File",
                message: "Module has forbidden direct dependency on File. Fix: do not reference File, IO from a module this rule selects; reach it through a module the rule allows",
                filename: nil,
                kind: :rule,
                key: "pure|lib/b.ex|File",
                rule_id: "pure",
                enforcement: :enforce
              }
            ]
     stacktrace:
       test/anchor/managers/lint_baseline_test.exs:317: (test)

.........
```

## RS-W — without_fix drops nothing

Run summary: `15 tests, 1 failure`

```text
  1) test merge/2 two rules' copies differing only in their Fix: are one finding, the enforced one's (Anchor.Domain.EnforcementPassesTest)
     test/anchor/domain/enforcement_passes_test.exs:29
     match (=) failed
     code:  assert [%Violation{enforcement: :enforce, message: message}] =
              EnforcementPasses.merge(enforced, reported)
     left:  [%Anchor.Domain.Violation{enforcement: :enforce, message: message}]
     right: [
              %Anchor.Domain.Violation{
                line: 3,
                trigger: "alias",
                message: "cannot resolve. Fix: enforced rule's shape",
                filename: nil,
                kind: :rule,
                key: nil,
                rule_id: nil,
                enforcement: :enforce
              },
              %Anchor.Domain.Violation{
                line: 3,
                trigger: "alias",
                message: "cannot resolve. Fix: report rule's shape",
                filename: nil,
                kind: :rule,
                key: nil,
                rule_id: nil,
                enforcement: :report
              }
            ]
     stacktrace:
       test/anchor/domain/enforcement_passes_test.exs:33: (test)

.............
```
