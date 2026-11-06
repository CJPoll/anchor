# Sabotage record — the interface graph rule (DND-5443)

- **Domain:** interface
- **Branch:** dnd-5443-graph-rules-b
- **Date:** 2026-11-03
- **Code under test:** `Anchor.Domain.Interfaces` (`modules_of/2`, `width/1`, `route/2`), `Anchor.Domain.GraphRules.Interface`, its registration in `Anchor.Domain.GraphRules`, the `interface` row and `max_width` check in `Anchor.Domain.RuleSchema`, `max_width` in `Anchor.Config.parse_rule/1`, the interface width in `Anchor.Domain.GraphReport` and `Anchor.Managers.Graph`
- **Suite run:** each mutation ran `mix test --force --timeout 2000 --max-cases 2 <its test files>` inside one `test-slot`, by a driver that applied it, ran the files and restored the source. Every row is red. The checkout's absolute path in the output reads `<worktree>`.

A first pass found IF-E (dropping a second, redundant `uniq_by` in the
no-context path) green: an equivalent mutant, since the first `uniq_by`
already makes each no-context pair unique. The redundant line was removed and
IF-E now drops the first one. Five other first-pass rows did not compile
(`--warnings-as-errors`: an unused helper or variable); they were rewritten to
the same defect in a form that compiles. This table is the full re-run on the
final code.

| # | Mutation | Tests run | Result | Failing tests |
|---|---|---|---|---|
| IN-A | modules_of/2 ignores interface? (`lib/anchor/domain/interfaces.ex`) | `interfaces_test.exs`, `interface_test.exs` | `31 tests, 3 failures` (red) | modules_of/2 the context's interface modules (managers and exports), sorted; not its domain ones; check/2 with no single route, the Fix lists the context's interface modules; check/2 the listed interface modules stop at five, then say how many more |
| IN-B | width/1 counts generated functions (`lib/anchor/domain/interfaces.ex`) | `interfaces_test.exs` | `11 tests, 1 failure` (red) | width/1 public functions of interface modules per context; generated and private not counted |
| IN-C | width/1 counts private functions (`lib/anchor/domain/interfaces.ex`) | `interfaces_test.exs` | `11 tests, 1 failure` (red) | width/1 public functions of interface modules per context; generated and private not counted |
| IN-D | width/1 counts non-interface modules (`lib/anchor/domain/interfaces.ex`) | `interfaces_test.exs`, `interface_test.exs` | `31 tests, 1 failure` (red) | width/1 public functions of interface modules per context; generated and private not counted |
| IN-E | route/2 walks only one hop (`lib/anchor/domain/interfaces.ex`) | `interfaces_test.exs` | `11 tests, 2 failures` (red) | route/2 one interface module reaching the target through one same-context hop is the route; route/2 a call cycle inside the context ends |
| IN-F | route/2 picks the first of several (`lib/anchor/domain/interfaces.ex`) | `interfaces_test.exs` | `11 tests, 1 failure` (red) | route/2 two interface modules reaching it is :none |
| IN-G | route/2 follows calls from another context (`lib/anchor/domain/interfaces.ex`) | `interfaces_test.exs` | `11 tests, 1 failure` (red) | route/2 a call from another context is no route |
| IF-A | a cross-context call is never judged (interface check skipped) (`lib/anchor/domain/graph_rules/interface.ex`) | `interface_test.exs`, `graph_canary_test.exs` | `28 tests, 7 failures` (red) | check/2 a dynamic call reaching an interface and a non-interface candidate is one violation; check/2 a cross-context call to a domain module is one violation, its Fix the route; check/2 the listed interface modules stop at five, then say how many more; check/2 over compiled fixtures (two apps) a call from another app into a domain module is one violation, the manager none; check/2 two calls of one pair are one violation, at the first line; check/2 with no single route, the Fix lists the context's interface modules; interface (DND-5443): the violating module gives exactly one finding, with the route |
| IF-B | an interface callee is a violation too (`lib/anchor/domain/graph_rules/interface.ex`) | `interface_test.exs`, `graph_canary_test.exs` | `28 tests, 12 failures` (red) | check/2 a cross-context call to a module listed in exports (interface? true) is none; check/2 a dynamic call reaching an interface and a non-interface candidate is one violation; check/2 over compiled fixtures (two apps) a call from another app into a domain module is one violation, the manager none; check/2 positive control: a cross-context call to a manager is none; context_acyclic (DND-5445): CycleA and CycleB calling each other give one finding; context_acyclic: CycleB without its call back is none; positive control: the deliberately unclassified module gives exactly one issue; interface (DND-5443): the violating module gives exactly one finding, with the route; the compliant canary modules give no findings, and the summary counts the tree |
| IF-C | a same-context call is judged (`lib/anchor/domain/graph_rules/interface.ex`) | `interface_test.exs` | `20 tests, 2 failures` (red) | check/2 a cross-context call to a domain module is one violation, its Fix the route; check/2 a same-context call to a domain module is never judged |
| IF-D | a nil-context module passes (`lib/anchor/domain/graph_rules/interface.ex`) | `interface_test.exs` | `20 tests, 1 failure` (red) | check/2 a callee with no context is a violation on the callee |
| IF-E | one violation per call, not per (caller, callee) pair (`lib/anchor/domain/graph_rules/interface.ex`) | `interface_test.exs` | `20 tests, 2 failures` (red) | check/2 a caller with no context is one violation naming it, however many calls it makes; check/2 two calls of one pair are one violation, at the first line |
| IF-F | dynamic candidates are not judged (`lib/anchor/domain/graph_rules/interface.ex`) | `interface_test.exs` | `20 tests, 1 failure` (red) | check/2 a dynamic call reaching an interface and a non-interface candidate is one violation |
| IF-G | a computed function name is dropped (`lib/anchor/domain/graph_rules/interface.ex`) | `interface_test.exs` | `20 tests, 1 failure` (red) | check/2 a call with a computed function name is one violation; a closure is not judged |
| IF-H | the selector is ignored (every caller judged) (`lib/anchor/domain/graph_rules/interface.ex`) | `interface_test.exs` | `20 tests, 1 failure` (red) | check/2 a call from a module the rule does not select is not judged |
| IF-I | max_width compares with >= (`lib/anchor/domain/graph_rules/interface.ex`) | `interface_test.exs` | `20 tests, 1 failure` (red) | check/2 max_width: 3 with an interface of exactly 3 is none (the boundary) |
| IF-J | the Fix never names the route (`lib/anchor/domain/graph_rules/interface.ex`) | `interface_test.exs`, `graph_canary_test.exs` | `28 tests, 3 failures` (red) | check/2 over compiled fixtures (two apps) a call from another app into a domain module is one violation, the manager none; check/2 a cross-context call to a domain module is one violation, its Fix the route; interface (DND-5443): the violating module gives exactly one finding, with the route |
| IF-K | the listed modules are not capped at five (`lib/anchor/domain/graph_rules/interface.ex`) | `interface_test.exs` | `20 tests, 1 failure` (red) | check/2 the listed interface modules stop at five, then say how many more |
| IF-L | interface is not registered as a graph rule (`lib/anchor/domain/graph_rules.ex`) | `rule_schema_test.exs`, `graph_canary_test.exs` | `41 tests, 4 failures` (red) | engine/1 every shipped type has an engine; the graph types are the graph rule modules'; R7: a rule that needs the higher-order flow analysis gets it over the canary, with no bound hit, and the summary counts its apply sites; interface (DND-5443): the violating module gives exactly one finding, with the route; the compliant canary modules give no findings, and the summary counts the tree |
| RS-A | max_width: 0 loads (`lib/anchor/domain/rule_schema.ex`) | `rule_checks_nothing_test.exs` | `27 tests, 1 failure` (red) | interface: every rule that checks nothing is refused, and the positive rows load |
| CF-A | max_width is not carried into the parsed rule (`lib/anchor/domain/config.ex`) | `config_test.exs` | `45 tests, 1 failure` (red) | parse_rule/1 — interface (DND-5443) max_width is carried as given; absent, it is nil |
| GR-A | the summary omits the width (`lib/anchor/domain/graph_report.ex`) | `graph_report_test.exs`, `graph_canary_test.exs` | `32 tests, 4 failures` (red) | interface width (DND-5443, R4) a run with an interface rule and no context says so; interface width (DND-5443, R4) the summary ends with each context's width, sorted; the JSON has interface_width; the compliant canary modules give no findings, and the summary counts the tree; R7: a rule that needs the higher-order flow analysis gets it over the canary, with no bound hit, and the summary counts its apply sites |
| GR-B | the JSON omits interface_width (`lib/anchor/domain/graph_report.ex`) | `graph_report_test.exs` | `24 tests, 2 failures` (red) | interface width (DND-5443, R4) no interface rule ran: nothing is printed, and the JSON is null; interface width (DND-5443, R4) the summary ends with each context's width, sorted; the JSON has interface_width |
| MG-A | the runner never computes the width (`lib/anchor/managers/graph.ex`) | `graph_canary_test.exs` | `8 tests, 2 failures` (red) | R7: a rule that needs the higher-order flow analysis gets it over the canary, with no bound hit, and the summary counts its apply sites; the compliant canary modules give no findings, and the summary counts the tree |
| IF-N | a dynamic call is judged against every exporter, not the narrowed targets (`lib/anchor/domain/graph_rules/interface.ex`) | `interface_test.exs` | `21 tests, 1 failure` (red) | check/2 over compiled fixtures (two apps) a behaviour-typed receiver reaches its implementers; an untyped one every exporter |

After merging main at 07aef9f. IF-N is the regression test of the narrowing bug: the mutation restores the unfixed line, and its red is the red in the fix commit.

## IN-A — modules_of/2 ignores interface?

Run summary: `31 tests, 3 failures`

```text
  1) test modules_of/2 the context's interface modules (managers and exports), sorted; not its domain ones (Anchor.Domain.InterfacesTest)
     test/anchor/domain/interfaces_test.exs:71
     Assertion with == failed
     code:  assert Interfaces.modules_of(model(), "App.Accounts") == [
              App.Accounts.Admin,
              App.Accounts.Api,
              App.Accounts.Users
            ]
     left:  [App.Accounts.Admin, App.Accounts.Api, App.Accounts.Hash,
             App.Accounts.User, App.Accounts.Users]
     right: [App.Accounts.Admin, App.Accounts.Api, App.Accounts.Users]
     stacktrace:
       test/anchor/domain/interfaces_test.exs:72: (test)

..............

  2) test check/2 with no single route, the Fix lists the context's interface modules (Anchor.Domain.GraphRules.InterfaceTest)
     test/anchor/domain/graph_rules/interface_test.exs:98
     Assertion with =~ failed
     code:  assert v.message =~
              "Fix: call one of App.Accounts's interface modules: App.Accounts.Api, " <>
                "App.Accounts.Users; or, if App.Accounts.User is meant to be public, add it " <>
                "to interfaces.exports (a reviewed change)."
     left:  "App.Billing.Invoice.issue/1 (context App.Billing) calls App.Accounts.User.name/1, which is not part of context App.Accounts's interface. Fix: call one of App.Accounts's interface modules: App.Accounts.Api, App.Accounts.User, App.Accounts.Users; or, if App.Accounts.User is meant to be public, add it to interfaces.exports (a reviewed change)."
     right: "Fix: call one of App.Accounts's interface modules: App.Accounts.Api, App.Accounts.Users; or, if App.Accounts.User is meant to be public, add it to interfaces.exports (a reviewed change)."
     stacktrace:
       test/anchor/domain/graph_rules/interface_test.exs:103: (test)

.........

  3) test check/2 the listed interface modules stop at five, then say how many more (Anchor.Domain.GraphRules.InterfaceTest)
     test/anchor/domain/graph_rules/interface_test.exs:109
     Assertion with =~ failed
     code:  assert v.message =~
              "interface modules: App.Accounts.Api, App.Accounts.M1, App.Accounts.M2, " <>
                "App.Accounts.M3, App.Accounts.M4 and 2 more; or,"
     left:  "App.Billing.Invoice.issue/1 (context App.Billing) calls App.Accounts.User.name/1, which is not part of context App.Accounts's interface. Fix: call one of App.Accounts's interface modules: App.Accounts.Api, App.Accounts.M1, App.Accounts.M2, App.Accounts.M3, App.Accounts.M4 and 3 more; or, if App.Accounts.User is meant to be public, add it to interfaces.exports (a reviewed change)."
     right: "interface modules: App.Accounts.Api, App.Accounts.M1, App.Accounts.M2, App.Accounts.M3, App.Accounts.M4 and 2 more; or,"
     stacktrace:
       test/anchor/domain/graph_rules/interface_test.exs:131: (test)

...
```

## IN-B — width/1 counts generated functions

Run summary: `11 tests, 1 failure`

```text
  1) test width/1 public functions of interface modules per context; generated and private not counted (Anchor.Domain.InterfacesTest)
     test/anchor/domain/interfaces_test.exs:86
     Assertion with == failed
     code:  assert Interfaces.width(model()) == %{"App.Accounts" => 5, "App.Billing" => 1}
     left:  %{"App.Accounts" => 5, "App.Billing" => 3}
     right: %{"App.Accounts" => 5, "App.Billing" => 1}
     stacktrace:
       test/anchor/domain/interfaces_test.exs:89: (test)

.
```

## IN-C — width/1 counts private functions

Run summary: `11 tests, 1 failure`

```text
  1) test width/1 public functions of interface modules per context; generated and private not counted (Anchor.Domain.InterfacesTest)
     test/anchor/domain/interfaces_test.exs:86
     Assertion with == failed
     code:  assert Interfaces.width(model()) == %{"App.Accounts" => 5, "App.Billing" => 1}
     left:  %{"App.Accounts" => 6, "App.Billing" => 1}
     right: %{"App.Accounts" => 5, "App.Billing" => 1}
     stacktrace:
       test/anchor/domain/interfaces_test.exs:89: (test)

.....
```

## IN-D — width/1 counts non-interface modules

Run summary: `31 tests, 1 failure`

```text
  1) test width/1 public functions of interface modules per context; generated and private not counted (Anchor.Domain.InterfacesTest)
     test/anchor/domain/interfaces_test.exs:86
     Assertion with == failed
     code:  assert Interfaces.width(model()) == %{"App.Accounts" => 5, "App.Billing" => 1}
     left:  %{"App.Accounts" => 7, "App.Billing" => 1}
     right: %{"App.Accounts" => 5, "App.Billing" => 1}
     stacktrace:
       test/anchor/domain/interfaces_test.exs:89: (test)

.........................
```

## IN-E — route/2 walks only one hop

Run summary: `11 tests, 2 failures`

```text
  1) test route/2 one interface module reaching the target through one same-context hop is the route (Anchor.Domain.InterfacesTest)
     test/anchor/domain/interfaces_test.exs:98
     Assertion with == failed
     code:  assert Interfaces.route(model(calls), App.Accounts.User) == {:ok, App.Accounts.Users}
     left:  :none
     right: {:ok, App.Accounts.Users}
     stacktrace:
       test/anchor/domain/interfaces_test.exs:101: (test)

.....

  2) test route/2 a call cycle inside the context ends (Anchor.Domain.InterfacesTest)
     test/anchor/domain/interfaces_test.exs:120
     Assertion with == failed
     code:  assert Interfaces.route(model(calls), App.Accounts.User) == {:ok, App.Accounts.Users}
     left:  :none
     right: {:ok, App.Accounts.Users}
     stacktrace:
       test/anchor/domain/interfaces_test.exs:127: (test)
```

## IN-F — route/2 picks the first of several

Run summary: `11 tests, 1 failure`

```text
  1) test route/2 two interface modules reaching it is :none (Anchor.Domain.InterfacesTest)
     test/anchor/domain/interfaces_test.exs:104
     Assertion with == failed
     code:  assert Interfaces.route(model(calls), App.Accounts.User) == :none
     left:  {:ok, App.Accounts.Admin}
     right: :none
     stacktrace:
       test/anchor/domain/interfaces_test.exs:107: (test)

..........
```

## IN-G — route/2 follows calls from another context

Run summary: `11 tests, 1 failure`

```text
  1) test route/2 a call from another context is no route (Anchor.Domain.InterfacesTest)
     test/anchor/domain/interfaces_test.exs:114
     Assertion with == failed
     code:  assert Interfaces.route(model(calls), App.Accounts.User) == :none
     left:  {:ok, App.Billing.Invoices}
     right: :none
     stacktrace:
       test/anchor/domain/interfaces_test.exs:117: (test)

.......
```

## IF-A — a cross-context call is never judged (interface check skipped)

Run summary: `28 tests, 7 failures`

```text
  1) test check/2 a dynamic call reaching an interface and a non-interface candidate is one violation (Anchor.Domain.GraphRules.InterfaceTest)
     test/anchor/domain/graph_rules/interface_test.exs:196
     match (=) failed
     code:  assert [v] = Interface.check(model(calls, functions), @rule)
     left:  [v]
     right: []
     stacktrace:
       test/anchor/domain/graph_rules/interface_test.exs:200: (test)

......

  2) test check/2 a cross-context call to a domain module is one violation, its Fix the route (Anchor.Domain.GraphRules.InterfaceTest)
     test/anchor/domain/graph_rules/interface_test.exs:79
     match (=) failed
     code:  assert [v] = Interface.check(model(calls), @rule)
     left:  [v]
     right: []
     stacktrace:
       test/anchor/domain/graph_rules/interface_test.exs:85: (test)

..

  3) test check/2 the listed interface modules stop at five, then say how many more (Anchor.Domain.GraphRules.InterfaceTest)
     test/anchor/domain/graph_rules/interface_test.exs:109
     match (=) failed
     code:  assert [v] = Interface.check(wide, @rule)
     left:  [v]
     right: []
     stacktrace:
       test/anchor/domain/graph_rules/interface_test.exs:129: (test)

.

  4) test check/2 over compiled fixtures (two apps) a call from another app into a domain module is one violation, the manager none (Anchor.Domain.GraphRules.InterfaceTest)
     test/anchor/domain/graph_rules/interface_test.exs:305
     match (=) failed
     code:  assert [v] = Interface.check(model, %{type: :interface, pattern: "*.Invoice"})
     left:  [v]
     right: []
     stacktrace:
       test/anchor/domain/graph_rules/interface_test.exs:339: (test)

.

  5) test check/2 two calls of one pair are one violation, at the first line (Anchor.Domain.GraphRules.InterfaceTest)
     test/anchor/domain/graph_rules/interface_test.exs:154
     match (=) failed
     code:  assert [%{line: 4}] = Interface.check(model(calls), @rule)
     left:  [%{line: 4}]
     right: []
     stacktrace:
       test/anchor/domain/graph_rules/interface_test.exs:160: (test)

  6) test check/2 with no single route, the Fix lists the context's interface modules (Anchor.Domain.GraphRules.InterfaceTest)
     test/anchor/domain/graph_rules/interface_test.exs:98
     match (=) failed
     code:  assert [v] = Interface.check(model(calls), @rule)
     left:  [v]
     right: []
     stacktrace:
       test/anchor/domain/graph_rules/interface_test.exs:101: (test)

..

  7) test interface (DND-5443): the violating module gives exactly one finding, with the route (Anchor.Integration.GraphCanaryTest)
     test/anchor/integration/graph_canary_test.exs:231
     Assertion with == failed
     code:  assert report.exit_code == 1
     left:  0
     right: 1
     stacktrace:
       test/anchor/integration/graph_canary_test.exs:236: (test)

.....
```

## IF-B — an interface callee is a violation too

Run summary: `28 tests, 12 failures`

```text
  1) test check/2 a cross-context call to a module listed in exports (interface? true) is none (Anchor.Domain.GraphRules.InterfaceTest)
     test/anchor/domain/graph_rules/interface_test.exs:142
     Assertion with == failed
     code:  assert Interface.check(model(calls), @rule) == []
     left:  [
              %Anchor.Domain.Violation{
                line: 7,
                trigger: "App.Billing.Invoice.issue/1",
                message: "App.Billing.Invoice.issue/1 (context App.Billing) calls App.Accounts.Api.token/0, which is not part of context App.Accounts's interface. Fix: call one of App.Accounts's interface modules: App.Accounts.Api, App.Accounts.Users; or, if App.Accounts.Api is meant to be public, add it to interfaces.exports (a reviewed change).",
                filename: "lib/app/billing/invoice.ex",
                kind: :rule,
                key: "interface|App.Billing.Invoice.issue/1|-> App.Accounts.Api.token/0",
                rule_id: "interface",
                enforcement: :enforce
              }
            ]
     right: []
     stacktrace:
       test/anchor/domain/graph_rules/interface_test.exs:145: (test)

..

  2) test check/2 a dynamic call reaching an interface and a non-interface candidate is one violation (Anchor.Domain.GraphRules.InterfaceTest)
     test/anchor/domain/graph_rules/interface_test.exs:196
     match (=) failed
     code:  assert [v] = Interface.check(model(calls, functions), @rule)
     left:  [v]
     right: [
              %Anchor.Domain.Violation{
                line: 7,
                trigger: "App.Billing.Invoice.issue/1",
                message: "App.Billing.Invoice.issue/1 (context App.Billing) calls App.Accounts.User.fetch/1, which is not part of context App.Accounts's interface. Fix: call one of App.Accounts's interface modules: App.Accounts.Api, App.Accounts.Users; or, if App.Accounts.User is meant to be public, add it to interfaces.exports (a reviewed change).",
                filename: "lib/app/billing/invoice.ex",
                kind: :rule,
                key: "interface|App.Billing.Invoice.issue/1|-> App.Accounts.User.fetch/1",
                rule_id: "interface",
                enforcement: :enforce
              },
              %Anchor.Domain.Violation{
                line: 7,
                trigger: "App.Billing.Invoice.issue/1",
                message: "App.Billing.Invoice.issue/1 (context App.Billing) calls App.Accounts.Users.fetch/1, which is not part of context App.Accounts's interface. Fix: call one of App.Accounts's interface modules: App.Accounts.Api, App.Accounts.Users; or, if App.Accounts.Users is meant to be public, add it to interfaces.exports (a reviewed change).",
                filename: "lib/app/billing/invoice.ex",
                kind: :rule,
                key: "interface|App.Billing.Invoice.issue/1|-> App.Accounts.Users.fetch/1",
                rule_id: "interface",
                enforcement: :enforce
              }
            ]
     stacktrace:
       test/anchor/domain/graph_rules/interface_test.exs:200: (test)

............

  3) test check/2 over compiled fixtures (two apps) a call from another app into a domain module is one violation, the manager none (Anchor.Domain.GraphRules.InterfaceTest)
     test/anchor/domain/graph_rules/interface_test.exs:305
     match (=) failed
     code:  assert [v] = Interface.check(model, %{type: :interface, pattern: "*.Invoice"})
     left:  [v]
     right: [
              %Anchor.Domain.Violation{
                line: 5,
                trigger: "AnchorFixtures.InterfaceTest.Billing.Invoice.issue/1",
                message: "AnchorFixtures.InterfaceTest.Billing.Invoice.issue/1 (context AnchorFixtures.InterfaceTest.Billing) calls AnchorFixtures.InterfaceTest.Accounts.Domain.User.name/1, which is not part of context AnchorFixtures.InterfaceTest.Accounts's interface. Fix: call AnchorFixtures.InterfaceTest.Accounts.Users instead.",
                filename: "apps/billing/lib/billing/managers/invoice.ex",
                kind: :rule,
                key: "interface|AnchorFixtures.InterfaceTest.Billing.Invoice.issue/1|-> AnchorFixtures.InterfaceTest.Accounts.Domain.User.name/1",
                rule_id: nil,
                enforcement: :enforce
              },
              %Anchor.Domain.Violation{
                line: 6,
                trigger: "AnchorFixtures.InterfaceTest.Billing.Invoice.ok/1",
                message: "AnchorFixtures.InterfaceTest.Billing.Invoice.ok/1 (context AnchorFixtures.InterfaceTest.Billing) calls AnchorFixtures.InterfaceTest.Accounts.Users.get/1, which is not part of context AnchorFixtures.InterfaceTest.Accounts's interface. Fix: call one of AnchorFixtures.InterfaceTest.Accounts's interface modules: AnchorFixtures.InterfaceTest.Accounts.Users; or, if AnchorFixtures.InterfaceTest.Accounts.Users is meant to be public, add it to interfaces.exports (a reviewed change).",
                filename: "apps/billing/lib/billing/managers/invoice.ex",
                kind: :rule,
                key: "interface|AnchorFixtures.InterfaceTest.Billing.Invoice.ok/1|-> AnchorFixtures.InterfaceTest.Accounts.Users.get/1",
                rule_id: nil,
                enforcement: :enforce
              }
            ]
     stacktrace:
       test/anchor/domain/graph_rules/interface_test.exs:339: (test)

.

  4) test check/2 positive control: a cross-context call to a manager is none (Anchor.Domain.GraphRules.InterfaceTest)
     test/anchor/domain/graph_rules/interface_test.exs:136
     Assertion with == failed
     code:  assert Interface.check(model(calls), @rule) == []
     left:  [
              %Anchor.Domain.Violation{
                line: 7,
                trigger: "App.Billing.Invoice.issue/1",
                message: "App.Billing.Invoice.issue/1 (context App.Billing) calls App.Accounts.Users.get/1, which is not part of context App.Accounts's interface. Fix: call one of App.Accounts's interface modules: App.Accounts.Api, App.Accounts.Users; or, if App.Accounts.Users is meant to be public, add it to interfaces.exports (a reviewed change).",
                filename: "lib/app/billing/invoice.ex",
                kind: :rule,
                key: "interface|App.Billing.Invoice.issue/1|-> App.Accounts.Users.get/1",
                rule_id: "interface",
                enforcement: :enforce
              }
            ]
     right: []
     stacktrace:
       test/anchor/domain/graph_rules/interface_test.exs:139: (test)

.

  5) test context_acyclic (DND-5445): CycleA and CycleB calling each other give one finding (Anchor.Integration.GraphCanaryTest)
     test/anchor/integration/graph_canary_test.exs:172
     match (=) failed
     code:  assert [finding] = report.findings
     left:  [finding]
     right: [
              %Anchor.Domain.GraphReport.Finding{
                rule_id: "context_acyclic",
                type: :context_acyclic,
                label: "rule 2 (id: \"context_acyclic\", context_acyclic)",
                enforcement: :enforce,
                key: "context_acyclic|AnchorFixtures.CycleA,AnchorFixtures.CycleB",
                file: "lib/canary/domain/cycle/cycle_a.ex",
                line: 5,
                message: "contexts AnchorFixtures.CycleA, AnchorFixtures.CycleB form a cycle: AnchorFixtures.CycleA -> AnchorFixtures.CycleB (AnchorFixtures.CycleA.a/1 calls AnchorFixtures.CycleB.b/1), AnchorFixtures.CycleB -> AnchorFixtures.CycleA (AnchorFixtures.CycleB.back/1 calls AnchorFixtures.CycleA.a/1). Fix: invert AnchorFixtures.CycleA -> AnchorFixtures.CycleB (its 1 call is the fewest): have AnchorFixtures.CycleA publish an event AnchorFixtures.CycleB subscribes to, or declare the function AnchorFixtures.CycleA needs in an interface AnchorFixtures.CycleA owns and have AnchorFixtures.CycleB implement it."
              },
              %Anchor.Domain.GraphReport.Finding{
                rule_id: "interface",
                type: :interface,
                label: "rule 3 (id: \"interface\", interface)",
                enforcement: :enforce,
                key: "interface|AnchorFixtures.IfaceLeft.Compliant.run/1|-> AnchorFixtures.IfaceRight.Api.check/1",
                file: "lib/canary/managers/iface_left/compliant.ex",
                line: 7,
                message: "AnchorFixtures.IfaceLeft.Compliant.run/1 (context AnchorFixtures.IfaceLeft) calls AnchorFixtures.IfaceRight.Api.check/1, which is not part of context AnchorFixtures.IfaceRight's interface. Fix: call one of AnchorFixtures.IfaceRight's interface modules: AnchorFixtures.IfaceRight.Api; or, if AnchorFixtures.IfaceRight.Api is meant to be public, add it to interfaces.exports (a reviewed change)."
              }
            ]
     stacktrace:
       test/anchor/integration/graph_canary_test.exs:178: (test)

  6) test context_acyclic: CycleB without its call back is none (Anchor.Integration.GraphCanaryTest)
     test/anchor/integration/graph_canary_test.exs:188
     match (=) failed
     code:  assert %GraphReport{exit_code: 0, findings: []} = report
     left:  %Anchor.Domain.GraphReport{exit_code: 0, findings: []}
     right: %Anchor.Domain.GraphReport{
              findings: [
                %Anchor.Domain.GraphReport.Finding{
                  rule_id: "interface",
                  type: :interface,
                  label: "rule 3 (id: \"interface\", interface)",
                  enforcement: :enforce,
                  key: "interface|AnchorFixtures.IfaceLeft.Compliant.run/1|-> AnchorFixtures.IfaceRight.Api.check/1",
                  file: "lib/canary/managers/iface_left/compliant.ex",
                  line: 7,
                  message: "AnchorFixtures.IfaceLeft.Compliant.run/1 (context AnchorFixtures.IfaceLeft) calls AnchorFixtures.IfaceRight.Api.check/1, which is not part of context AnchorFixtures.IfaceRight's interface. Fix: call one of AnchorFixtures.IfaceRight's interface modules: AnchorFixtures.IfaceRight.Api; or, if AnchorFixtures.IfaceRight.Api is meant to be public, add it to interfaces.exports (a reviewed change)."
                }
              ],
              could_not_check: [],
              held: [],
              refused: [],
              counts: %{
                modules: 10,
                opaque: 0,
                apps: 1,
                excluded: 0,
                rules: 3,
                apply_sites: nil,
                no_core: 0,
                interface_width: %{
                  "AnchorFixtures.CycleA" => 0,
                  "AnchorFixtures.CycleB" => 0,
                  "AnchorFixtures.GraphCanary" => 2,
                  "AnchorFixtures.IfaceLeft" => 1,
                  "AnchorFixtures.IfaceRight" => 1
                }
              },
              exit_code: 1
            }
     stacktrace:
       test/anchor/integration/graph_canary_test.exs:203: (test)

  7) test positive control: the deliberately unclassified module gives exactly one issue (Anchor.Integration.GraphCanaryTest)
     test/anchor/integration/graph_canary_test.exs:100
     match (=) failed
     code:  assert [finding] = report.findings
     left:  [finding]
     right: [
              %Anchor.Domain.GraphReport.Finding{
                rule_id: nil,
                type: nil,
                label: "anchor.graph",
                enforcement: :enforce,
                key: nil,
                file: "lib/canary/unclassified.ex",
                line: 3,
                message: "AnchorFixtures.GraphCanary.Stray is in no architecture bucket. Fix: add a selector that matches lib/canary/unclassified.ex to the bucket this module belongs in (mix anchor.explain lib/canary/unclassified.ex shows the candidates)."
              },
              %Anchor.Domain.GraphReport.Finding{
                rule_id: "interface",
                type: :interface,
                label: "rule 3 (id: \"interface\", interface)",
                enforcement: :enforce,
                key: "interface|AnchorFixtures.IfaceLeft.Compliant.run/1|-> AnchorFixtures.IfaceRight.Api.check/1",
                file: "lib/canary/managers/iface_left/compliant.ex",
                line: 7,
                message: "AnchorFixtures.IfaceLeft.Compliant.run/1 (context AnchorFixtures.IfaceLeft) calls AnchorFixtures.IfaceRight.Api.check/1, which is not part of context AnchorFixtures.IfaceRight's interface. Fix: call one of AnchorFixtures.IfaceRight's interface modules: AnchorFixtures.IfaceRight.Api; or, if AnchorFixtures.IfaceRight.Api is meant to be public, add it to interfaces.exports (a reviewed change)."
              }
            ]
     stacktrace:
       test/anchor/integration/graph_canary_test.exs:106: (test)

  8) test interface (DND-5443): the violating module gives exactly one finding, with the route (Anchor.Integration.GraphCanaryTest)
     test/anchor/integration/graph_canary_test.exs:231
     match (=) failed
     code:  assert [finding] = report.findings
     left:  [finding]
     right: [
              %Anchor.Domain.GraphReport.Finding{
                rule_id: "interface",
                type: :interface,
                label: "rule 3 (id: \"interface\", interface)",
                enforcement: :enforce,
                key: "interface|AnchorFixtures.IfaceLeft.Compliant.run/1|-> AnchorFixtures.IfaceRight.Api.check/1",
                file: "lib/canary/managers/iface_left/compliant.ex",
                line: 7,
                message: "AnchorFixtures.IfaceLeft.Compliant.run/1 (context AnchorFixtures.IfaceLeft) calls AnchorFixtures.IfaceRight.Api.check/1, which is not part of context AnchorFixtures.IfaceRight's interface. Fix: call one of AnchorFixtures.IfaceRight's interface modules: AnchorFixtures.IfaceRight.Api; or, if AnchorFixtures.IfaceRight.Api is meant to be public, add it to interfaces.exports (a reviewed change)."
              },
              %Anchor.Domain.GraphReport.Finding{
                rule_id: "interface",
                type: :interface,
                label: "rule 3 (id: \"interface\", interface)",
                enforcement: :enforce,
                key: "interface|AnchorFixtures.IfaceLeft.Violating.run/1|-> AnchorFixtures.IfaceRight.Rules.allowed?/1",
                file: "lib/canary/managers/iface_left/violating.ex",
                line: 7,
                message: "AnchorFixtures.IfaceLeft.Violating.run/1 (context AnchorFixtures.IfaceLeft) calls AnchorFixtures.IfaceRight.Rules.allowed?/1, which is not part of context AnchorFixtures.IfaceRight's interface. Fix: call AnchorFixtures.IfaceRight.Api instead."
              }
            ]
     stacktrace:
       test/anchor/integration/graph_canary_test.exs:237: (test)

  9) test the compliant canary modules give no findings, and the summary counts the tree (Anchor.Integration.GraphCanaryTest)
     test/anchor/integration/graph_canary_test.exs:87
     match (=) failed
     code:  assert %GraphReport{exit_code: 0, findings: [], could_not_check: []} = report
     left:  %Anchor.Domain.GraphReport{exit_code: 0, findings: [], could_not_check: []}
     right: %Anchor.Domain.GraphReport{
              findings: [
                %Anchor.Domain.GraphReport.Finding{
                  rule_id: "interface",
                  type: :interface,
                  label: "rule 3 (id: \"interface\", interface)",
                  enforcement: :enforce,
                  key: "interface|AnchorFixtures.IfaceLeft.Compliant.run/1|-> AnchorFixtures.IfaceRight.Api.check/1",
                  file: "lib/canary/managers/iface_left/compliant.ex",
                  line: 7,
                  message: "AnchorFixtures.IfaceLeft.Compliant.run/1 (context AnchorFixtures.IfaceLeft) calls AnchorFixtures.IfaceRight.Api.check/1, which is not part of context AnchorFixtures.IfaceRight's interface. Fix: call one of AnchorFixtures.IfaceRight's interface modules: AnchorFixtures.IfaceRight.Api; or, if AnchorFixtures.IfaceRight.Api is meant to be public, add it to interfaces.exports (a reviewed change)."
                }
              ],
              could_not_check: [],
              held: [],
              refused: [],
              counts: %{
                modules: 9,
                opaque: 0,
                apps: 1,
                excluded: 0,
                rules: 3,
                apply_sites: nil,
                no_core: 0,
                interface_width: %{
                  "AnchorFixtures.CycleA" => 0,
                  "AnchorFixtures.GraphCanary" => 2,
                  "AnchorFixtures.IfaceLeft" => 1,
                  "AnchorFixtures.IfaceRight" => 1
                }
              },
              exit_code: 1
            }
     stacktrace:
       test/anchor/integration/graph_canary_test.exs:92: (test)



 10) test layering (DND-5442): the violating module gives exactly one finding, with the route (Anchor.Integration.GraphCanaryTest)
     test/anchor/integration/graph_canary_test.exs:113
     match (=) failed
     code:  assert [finding] = report.findings
     left:  [finding]
     right: [
              %Anchor.Domain.GraphReport.Finding{
                rule_id: "layering",
                type: :layering,
                label: "rule 1 (id: \"layering\", layering)",
                enforcement: :enforce,
                key: "layering|AnchorFixtures.GraphCanary.Web.Violating.show/1|-> AnchorFixtures.GraphCanary.Orders.Store.fetch/1",
                file: "lib/canary/framework/layering/violating.ex",
                line: 7,
                message: "AnchorFixtures.GraphCanary.Web.Violating.show/1 (framework, AnchorFixtures.GraphCanary) calls AnchorFixtures.GraphCanary.Orders.Store.fetch/1 (adapters, AnchorFixtures.GraphCanary); framework may call: framework, managers, domain. Fix: route it through managers: framework -> managers -> adapters (call a managers module of the right context, which calls adapters); framework may not call adapters directly."
              },
              %Anchor.Domain.GraphReport.Finding{
                rule_id: "interface",
                type: :interface,
                label: "rule 3 (id: \"interface\", interface)",
                enforcement: :enforce,
                key: "interface|AnchorFixtures.IfaceLeft.Compliant.run/1|-> AnchorFixtures.IfaceRight.Api.check/1",
                file: "lib/canary/managers/iface_left/compliant.ex",
                line: 7,
                message: "AnchorFixtures.IfaceLeft.Compliant.run/1 (context AnchorFixtures.IfaceLeft) calls AnchorFixtures.IfaceRight.Api.check/1, which is not part of context AnchorFixtures.IfaceRight's interface. Fix: call one of AnchorFixtures.IfaceRight's interface modules: AnchorFixtures.IfaceRight.Api; or, if AnchorFixtures.IfaceRight.Api is meant to be public, add it to interfaces.exports (a reviewed change)."
              }
            ]
     stacktrace:
       test/anchor/integration/graph_canary_test.exs:119: (test)



 11) test R7: a rule that needs the higher-order flow analysis gets it over the canary, with no bound hit, and the summary counts its apply sites (Anchor.Integration.GraphCanaryTest)
     test/anchor/integration/graph_canary_test.exs:207
     match (=) failed
     code:  assert [%{message: "cfa saw cfa: 2 sites. Fix: none, a probe."}] = report.findings
     left:  [%{message: "cfa saw cfa: 2 sites. Fix: none, a probe."}]
     right: [
              %Anchor.Domain.GraphReport.Finding{
                rule_id: "interface",
                type: :interface,
                label: "rule 3 (id: \"interface\", interface)",
                enforcement: :enforce,
                key: "interface|AnchorFixtures.IfaceLeft.Compliant.run/1|-> AnchorFixtures.IfaceRight.Api.check/1",
                file: "lib/canary/managers/iface_left/compliant.ex",
                line: 7,
                message: "AnchorFixtures.IfaceLeft.Compliant.run/1 (context AnchorFixtures.IfaceLeft) calls AnchorFixtures.IfaceRight.Api.check/1, which is not part of context AnchorFixtures.IfaceRight's interface. Fix: call one of AnchorFixtures.IfaceRight's interface modules: AnchorFixtures.IfaceRight.Api; or, if AnchorFixtures.IfaceRight.Api is meant to be public, add it to interfaces.exports (a reviewed change)."
              },
              %Anchor.Domain.GraphReport.Finding{
                rule_id: "cfa",
                type: :stub_needs_cfa,
                label: "rule 1 (id: \"cfa\", stub_needs_cfa)",
                enforcement: :enforce,
                key: "cfa",
                file: "lib/canary/managers/orders.ex",
                line: 1,
                message: "cfa saw cfa: 2 sites. Fix: none, a probe."
              }
            ]
     stacktrace:
       test/anchor/integration/graph_canary_test.exs:217: (test)



 12) test layering baseline: written, then held, then STALE once the violation is fixed (Anchor.Integration.GraphCanaryTest)
     test/anchor/integration/graph_canary_test.exs:135
     Assertion with == failed
     code:  assert written.exit_code == 0
     left:  1
     right: 0
     stacktrace:
       test/anchor/integration/graph_canary_test.exs:155: (test)
```

## IF-C — a same-context call is judged

Run summary: `20 tests, 2 failures`

```text
  1) test check/2 a cross-context call to a domain module is one violation, its Fix the route (Anchor.Domain.GraphRules.InterfaceTest)
     test/anchor/domain/graph_rules/interface_test.exs:79
     match (=) failed
     code:  assert [v] = Interface.check(model(calls), @rule)
     left:  [v]
     right: [
              %Anchor.Domain.Violation{
                line: 7,
                trigger: "App.Accounts.Users.get/1",
                message: "App.Accounts.Users.get/1 (context App.Accounts) calls App.Accounts.User.name/1, which is not part of context App.Accounts's interface. Fix: call App.Accounts.Users instead.",
                filename: "lib/app/accounts/users.ex",
                kind: :rule,
                key: "interface|App.Accounts.Users.get/1|-> App.Accounts.User.name/1",
                rule_id: "interface",
                enforcement: :enforce
              },
              %Anchor.Domain.Violation{
                line: 7,
                trigger: "App.Billing.Invoice.issue/1",
                message: "App.Billing.Invoice.issue/1 (context App.Billing) calls App.Accounts.User.name/1, which is not part of context App.Accounts's interface. Fix: call App.Accounts.Users instead.",
                filename: "lib/app/billing/invoice.ex",
                kind: :rule,
                key: "interface|App.Billing.Invoice.issue/1|-> App.Accounts.User.name/1",
                rule_id: "interface",
                enforcement: :enforce
              }
            ]
     stacktrace:
       test/anchor/domain/graph_rules/interface_test.exs:85: (test)

.........

  2) test check/2 a same-context call to a domain module is never judged (Anchor.Domain.GraphRules.InterfaceTest)
     test/anchor/domain/graph_rules/interface_test.exs:148
     Assertion with == failed
     code:  assert Interface.check(model(calls), @rule) == []
     left:  [
              %Anchor.Domain.Violation{
                line: 7,
                trigger: "App.Billing.Invoice.issue/1",
                message: "App.Billing.Invoice.issue/1 (context App.Billing) calls App.Billing.Total.sum/1, which is not part of context App.Billing's interface. Fix: call App.Billing.Invoice instead.",
                filename: "lib/app/billing/invoice.ex",
                kind: :rule,
                key: "interface|App.Billing.Invoice.issue/1|-> App.Billing.Total.sum/1",
                rule_id: "interface",
                enforcement: :enforce
              }
            ]
     right: []
     stacktrace:
       test/anchor/domain/graph_rules/interface_test.exs:151: (test)

.........
```

## IF-D — a nil-context module passes

Run summary: `20 tests, 1 failure`

```text
  1) test check/2 a callee with no context is a violation on the callee (Anchor.Domain.GraphRules.InterfaceTest)
     test/anchor/domain/graph_rules/interface_test.exs:180
     match (=) failed
     code:  assert [v] = Interface.check(model(calls), @rule)
     left:  [v]
     right: []
     stacktrace:
       test/anchor/domain/graph_rules/interface_test.exs:183: (test)

.................
```

## IF-E — one violation per call, not per (caller, callee) pair

Run summary: `20 tests, 2 failures`

```text
  1) test check/2 a caller with no context is one violation naming it, however many calls it makes (Anchor.Domain.GraphRules.InterfaceTest)
     test/anchor/domain/graph_rules/interface_test.exs:163
     match (=) failed
     code:  assert [v] = Interface.check(model(calls), @rule)
     left:  [v]
     right: [
              %Anchor.Domain.Violation{
                line: 3,
                trigger: "Top",
                message: "Top has no context (fewer than 2 name segments), so its boundary cannot be checked. Fix: rename it under a context of depth 2, or lower contexts.depth.",
                filename: "lib/top.ex",
                kind: :rule,
                key: "interface|Top|no context",
                rule_id: "interface",
                enforcement: :enforce
              },
              %Anchor.Domain.Violation{
                line: 4,
                trigger: "Top",
                message: "Top has no context (fewer than 2 name segments), so its boundary cannot be checked. Fix: rename it under a context of depth 2, or lower contexts.depth.",
                filename: "lib/top.ex",
                kind: :rule,
                key: "interface|Top|no context",
                rule_id: "interface",
                enforcement: :enforce
              },
              %Anchor.Domain.Violation{
                line: 5,
                trigger: "Top",
                message: "Top has no context (fewer than 2 name segments), so its boundary cannot be checked. Fix: rename it under a context of depth 2, or lower contexts.depth.",
                filename: "lib/top.ex",
                kind: :rule,
                key: "interface|Top|no context",
                rule_id: "interface",
                enforcement: :enforce
              }
            ]
     stacktrace:
       test/anchor/domain/graph_rules/interface_test.exs:170: (test)

.................

  2) test check/2 two calls of one pair are one violation, at the first line (Anchor.Domain.GraphRules.InterfaceTest)
     test/anchor/domain/graph_rules/interface_test.exs:154
     match (=) failed
     code:  assert [%{line: 4}] = Interface.check(model(calls), @rule)
     left:  [%{line: 4}]
     right: [
              %Anchor.Domain.Violation{
                line: 4,
                trigger: "App.Billing.Invoice.issue/1",
                message: "App.Billing.Invoice.issue/1 (context App.Billing) calls App.Accounts.User.name/1, which is not part of context App.Accounts's interface. Fix: call one of App.Accounts's interface modules: App.Accounts.Api, App.Accounts.Users; or, if App.Accounts.User is meant to be public, add it to interfaces.exports (a reviewed change).",
                filename: "lib/app/billing/invoice.ex",
                kind: :rule,
                key: "interface|App.Billing.Invoice.issue/1|-> App.Accounts.User.name/1",
                rule_id: "interface",
                enforcement: :enforce
              },
              %Anchor.Domain.Violation{
                line: 9,
                trigger: "App.Billing.Invoice.issue/1",
                message: "App.Billing.Invoice.issue/1 (context App.Billing) calls App.Accounts.User.name/1, which is not part of context App.Accounts's interface. Fix: call one of App.Accounts's interface modules: App.Accounts.Api, App.Accounts.Users; or, if App.Accounts.User is meant to be public, add it to interfaces.exports (a reviewed change).",
                filename: "lib/app/billing/invoice.ex",
                kind: :rule,
                key: "interface|App.Billing.Invoice.issue/1|-> App.Accounts.User.name/1",
                rule_id: "interface",
                enforcement: :enforce
              }
            ]
     stacktrace:
       test/anchor/domain/graph_rules/interface_test.exs:160: (test)
```

## IF-F — dynamic candidates are not judged

Run summary: `20 tests, 1 failure`

```text
  1) test check/2 a dynamic call reaching an interface and a non-interface candidate is one violation (Anchor.Domain.GraphRules.InterfaceTest)
     test/anchor/domain/graph_rules/interface_test.exs:196
     match (=) failed
     code:  assert [v] = Interface.check(model(calls, functions), @rule)
     left:  [v]
     right: []
     stacktrace:
       test/anchor/domain/graph_rules/interface_test.exs:200: (test)

...........
```

## IF-G — a computed function name is dropped

Run summary: `20 tests, 1 failure`

```text
  1) test check/2 a call with a computed function name is one violation; a closure is not judged (Anchor.Domain.GraphRules.InterfaceTest)
     test/anchor/domain/graph_rules/interface_test.exs:204
     match (=) failed
     code:  assert [v] = Interface.check(model(calls), @rule)
     left:  [v]
     right: []
     stacktrace:
       test/anchor/domain/graph_rules/interface_test.exs:216: (test)

......
```

## IF-H — the selector is ignored (every caller judged)

Run summary: `20 tests, 1 failure`

```text
  1) test check/2 a call from a module the rule does not select is not judged (Anchor.Domain.GraphRules.InterfaceTest)
     test/anchor/domain/graph_rules/interface_test.exs:221
     Assertion with == failed
     code:  assert Interface.check(model(calls), rule) == []
     left:  [
              %Anchor.Domain.Violation{
                line: 7,
                trigger: "App.Billing.Invoice.issue/1",
                message: "App.Billing.Invoice.issue/1 (context App.Billing) calls App.Accounts.User.name/1, which is not part of context App.Accounts's interface. Fix: call one of App.Accounts's interface modules: App.Accounts.Api, App.Accounts.Users; or, if App.Accounts.User is meant to be public, add it to interfaces.exports (a reviewed change).",
                filename: "lib/app/billing/invoice.ex",
                kind: :rule,
                key: "interface|App.Billing.Invoice.issue/1|-> App.Accounts.User.name/1",
                rule_id: "interface",
                enforcement: :enforce
              }
            ]
     right: []
     stacktrace:
       test/anchor/domain/graph_rules/interface_test.exs:225: (test)

....
```

## IF-I — max_width compares with >=

Run summary: `20 tests, 1 failure`

```text
  1) test check/2 max_width: 3 with an interface of exactly 3 is none (the boundary) (Anchor.Domain.GraphRules.InterfaceTest)
     test/anchor/domain/graph_rules/interface_test.exs:251
     Assertion with == failed
     code:  assert Interface.check(model([], functions), Map.put(@rule, :max_width, 3)) == []
     left:  [
              %Anchor.Domain.Violation{
                line: nil,
                trigger: "App.Billing",
                message: "context App.Billing exposes 3 public functions on its interface, above max_width 3. Fix: move functions behind fewer interface functions; raising max_width is the owner's call.",
                filename: "/repo/.anchor.yml",
                kind: :rule,
                key: "interface|App.Billing|width",
                rule_id: "interface",
                enforcement: :enforce
              }
            ]
     right: []
     stacktrace:
       test/anchor/domain/graph_rules/interface_test.exs:254: (test)

..................
```

## IF-J — the Fix never names the route

Run summary: `28 tests, 3 failures`

```text
  1) test check/2 over compiled fixtures (two apps) a call from another app into a domain module is one violation, the manager none (Anchor.Domain.GraphRules.InterfaceTest)
     test/anchor/domain/graph_rules/interface_test.exs:305
     Assertion with =~ failed
     code:  assert v.message =~ "Fix: call AnchorFixtures.InterfaceTest.Accounts.Users instead."
     left:  "AnchorFixtures.InterfaceTest.Billing.Invoice.issue/1 (context AnchorFixtures.InterfaceTest.Billing) calls AnchorFixtures.InterfaceTest.Accounts.Domain.User.name/1, which is not part of context AnchorFixtures.InterfaceTest.Accounts's interface. Fix: call one of AnchorFixtures.InterfaceTest.Accounts's interface modules: AnchorFixtures.InterfaceTest.Accounts.Users; or, if AnchorFixtures.InterfaceTest.Accounts.Domain.User is meant to be public, add it to interfaces.exports (a reviewed change)."
     right: "Fix: call AnchorFixtures.InterfaceTest.Accounts.Users instead."
     stacktrace:
       test/anchor/domain/graph_rules/interface_test.exs:345: (test)

..

  2) test check/2 a cross-context call to a domain module is one violation, its Fix the route (Anchor.Domain.GraphRules.InterfaceTest)
     test/anchor/domain/graph_rules/interface_test.exs:79
     Assertion with == failed
     code:  assert v.message ==
              "App.Billing.Invoice.issue/1 (context App.Billing) calls " <>
                "App.Accounts.User.name/1, which is not part of context App.Accounts's " <>
                "interface. Fix: call App.Accounts.Users instead."
     left:  "App.Billing.Invoice.issue/1 (context App.Billing) calls App.Accounts.User.name/1, which is not part of context App.Accounts's interface. Fix: call one of App.Accounts's interface modules: App.Accounts.Api, App.Accounts.Users; or, if App.Accounts.User is meant to be public, add it to interfaces.exports (a reviewed change)."
     right: "App.Billing.Invoice.issue/1 (context App.Billing) calls App.Accounts.User.name/1, which is not part of context App.Accounts's interface. Fix: call App.Accounts.Users instead."
     stacktrace:
       test/anchor/domain/graph_rules/interface_test.exs:92: (test)

.............

  3) test interface (DND-5443): the violating module gives exactly one finding, with the route (Anchor.Integration.GraphCanaryTest)
     test/anchor/integration/graph_canary_test.exs:231
     Assertion with =~ failed
     code:  assert finding.message =~
              "which is not part of context AnchorFixtures.IfaceRight's interface. Fix: call " <>
                "AnchorFixtures.IfaceRight.Api instead."
     left:  "AnchorFixtures.IfaceLeft.Violating.run/1 (context AnchorFixtures.IfaceLeft) calls AnchorFixtures.IfaceRight.Rules.allowed?/1, which is not part of context AnchorFixtures.IfaceRight's interface. Fix: call one of AnchorFixtures.IfaceRight's interface modules: AnchorFixtures.IfaceRight.Api; or, if AnchorFixtures.IfaceRight.Rules is meant to be public, add it to interfaces.exports (a reviewed change)."
     right: "which is not part of context AnchorFixtures.IfaceRight's interface. Fix: call AnchorFixtures.IfaceRight.Api instead."
     stacktrace:
       test/anchor/integration/graph_canary_test.exs:246: (test)

.
```

## IF-K — the listed modules are not capped at five

Run summary: `20 tests, 1 failure`

```text
  1) test check/2 the listed interface modules stop at five, then say how many more (Anchor.Domain.GraphRules.InterfaceTest)
     test/anchor/domain/graph_rules/interface_test.exs:109
     Assertion with =~ failed
     code:  assert v.message =~
              "interface modules: App.Accounts.Api, App.Accounts.M1, App.Accounts.M2, " <>
                "App.Accounts.M3, App.Accounts.M4 and 2 more; or,"
     left:  "App.Billing.Invoice.issue/1 (context App.Billing) calls App.Accounts.User.name/1, which is not part of context App.Accounts's interface. Fix: call one of App.Accounts's interface modules: App.Accounts.Api, App.Accounts.M1, App.Accounts.M2, App.Accounts.M3, App.Accounts.M4, App.Accounts.M5, App.Accounts.Users; or, if App.Accounts.User is meant to be public, add it to interfaces.exports (a reviewed change)."
     right: "interface modules: App.Accounts.Api, App.Accounts.M1, App.Accounts.M2, App.Accounts.M3, App.Accounts.M4 and 2 more; or,"
     stacktrace:
       test/anchor/domain/graph_rules/interface_test.exs:131: (test)

..........
```

## IF-L — interface is not registered as a graph rule

Run summary: `41 tests, 4 failures`

```text
  1) test engine/1 every shipped type has an engine; the graph types are the graph rule modules' (Anchor.Domain.RuleSchemaTest)
     test/anchor/domain/rule_schema_test.exs:239
     Assertion with == failed
     code:  assert RuleSchema.rule_types_for_engine(:graph) ==
              Anchor.Domain.GraphRules.all() |> Enum.map(& &1.rule_type()) |> Enum.sort()
     left:  [:context_acyclic, :interface, :layering]
     right: [:context_acyclic, :layering]
     stacktrace:
       test/anchor/domain/rule_schema_test.exs:247: (test)

...............................

  2) test R7: a rule that needs the higher-order flow analysis gets it over the canary, with no bound hit, and the summary counts its apply sites (Anchor.Integration.GraphCanaryTest)
     test/anchor/integration/graph_canary_test.exs:207
     Assertion with == failed
     code:  assert GraphReport.summary(report) ==
              "anchor.graph: 9 modules in 1 apps, 4 rules, 1 violations " <>
                "(0 report-only, 0 baselined); apply sites: 2 resolved, 0 any; interface width: " <>
                "AnchorFixtures.CycleA=0, AnchorFixtures.GraphCanary=2, " <>
                "AnchorFixtures.IfaceLeft=1, AnchorFixtures.IfaceRight=1"
     left:  "anchor.graph: 9 modules in 1 apps, 3 rules, 1 violations (0 report-only, 0 baselined); apply sites: 2 resolved, 0 any"
     right: "anchor.graph: 9 modules in 1 apps, 4 rules, 1 violations (0 report-only, 0 baselined); apply sites: 2 resolved, 0 any; interface width: AnchorFixtures.CycleA=0, AnchorFixtures.GraphCanary=2, AnchorFixtures.IfaceLeft=1, AnchorFixtures.IfaceRight=1"
     stacktrace:
       test/anchor/integration/graph_canary_test.exs:224: (test)

.

  3) test interface (DND-5443): the violating module gives exactly one finding, with the route (Anchor.Integration.GraphCanaryTest)
     test/anchor/integration/graph_canary_test.exs:231
     Assertion with == failed
     code:  assert report.exit_code == 1
     left:  0
     right: 1
     stacktrace:
       test/anchor/integration/graph_canary_test.exs:236: (test)

...

  4) test the compliant canary modules give no findings, and the summary counts the tree (Anchor.Integration.GraphCanaryTest)
     test/anchor/integration/graph_canary_test.exs:87
     Assertion with == failed
     code:  assert GraphReport.summary(report) ==
              "anchor.graph: 9 modules in 1 apps, 3 rules, 0 violations (0 report-only, 0 baselined)" <>
                "; interface width: AnchorFixtures.CycleA=0, AnchorFixtures.GraphCanary=2, " <>
                "AnchorFixtures.IfaceLeft=1, AnchorFixtures.IfaceRight=1"
     left:  "anchor.graph: 9 modules in 1 apps, 2 rules, 0 violations (0 report-only, 0 baselined)"
     right: "anchor.graph: 9 modules in 1 apps, 3 rules, 0 violations (0 report-only, 0 baselined); interface width: AnchorFixtures.CycleA=0, AnchorFixtures.GraphCanary=2, AnchorFixtures.IfaceLeft=1, AnchorFixtures.IfaceRight=1"
     stacktrace:
       test/anchor/integration/graph_canary_test.exs:94: (test)

.
```

## RS-A — max_width: 0 loads

Run summary: `27 tests, 1 failure`

```text
  1) test interface: every rule that checks nothing is refused, and the positive rows load (Anchor.Domain.RuleChecksNothingTest)
     test/anchor/domain/rule_checks_nothing_test.exs:46
     interface / max_width: 0 (fails every context with an interface): LOADED: %Anchor.Config{rules: [%{id: nil, index: 1, ...}], ...}
     code: assert failures == [], Enum.join(failures, "\n")
     stacktrace:
       test/anchor/domain/rule_checks_nothing_test.exs:52: (test)

.................
```

## CF-A — max_width is not carried into the parsed rule

Run summary: `45 tests, 1 failure`

```text
  1) test parse_rule/1 — interface (DND-5443) max_width is carried as given; absent, it is nil (Anchor.Domain.ConfigTest)
     test/anchor/domain/config_test.exs:522
     match (=) failed
     code:  assert %{type: :interface, max_width: 12} =
              Config.parse_rule(%{"type" => "interface", "bucket" => "b", "max_width" => 12})
     left:  %{type: :interface, max_width: 12}
     right: %{
              id: nil,
              match: :reference,
              type: :interface,
              mode: nil,
              pattern: nil,
              recursive: false,
              paths: nil,
              enforcement: :enforce,
              min_modules: nil,
              uses_module: nil,
              context_depth: 2,
              same_context: false,
              bucket: "b",
              baseline: nil,
              max_lines: nil,
              allowed_functions: [],
              required_modules: [],
              forbidden_modules: [],
              forbidden_patterns: [],
              forbidden_functions: [],
              allowed_callers: [],
              pure_patterns: [],
              owned_namespaces: nil,
              min_files: 1,
              max_width: nil
            }
     stacktrace:
       test/anchor/domain/config_test.exs:523: (test)

....................................
```

## GR-A — the summary omits the width

Run summary: `32 tests, 4 failures`

```text
  1) test interface width (DND-5443, R4) a run with an interface rule and no context says so (Anchor.Domain.GraphReportTest)
     test/anchor/domain/graph_report_test.exs:220
     Assertion with =~ failed
     code:  assert GraphReport.summary(report) =~ "; interface width: no context"
     left:  "anchor.graph: 12 modules in 2 apps, 3 rules, 0 violations (0 report-only, 0 baselined)"
     right: "; interface width: no context"
     stacktrace:
       test/anchor/domain/graph_report_test.exs:223: (test)

.....

  2) test interface width (DND-5443, R4) the summary ends with each context's width, sorted; the JSON has interface_width (Anchor.Domain.GraphReportTest)
     test/anchor/domain/graph_report_test.exs:201
     Assertion with == failed
     code:  assert GraphReport.summary(report) ==
              "anchor.graph: 12 modules in 2 apps, 3 rules, 0 violations " <>
                "(0 report-only, 0 baselined); interface width: A=5, B=2"
     left:  "anchor.graph: 12 modules in 2 apps, 3 rules, 0 violations (0 report-only, 0 baselined)"
     right: "anchor.graph: 12 modules in 2 apps, 3 rules, 0 violations (0 report-only, 0 baselined); interface width: A=5, B=2"
     stacktrace:
       test/anchor/domain/graph_report_test.exs:205: (test)

........

  3) test the compliant canary modules give no findings, and the summary counts the tree (Anchor.Integration.GraphCanaryTest)
     test/anchor/integration/graph_canary_test.exs:87
     Assertion with == failed
     code:  assert GraphReport.summary(report) ==
              "anchor.graph: 9 modules in 1 apps, 3 rules, 0 violations (0 report-only, 0 baselined)" <>
                "; interface width: AnchorFixtures.CycleA=0, AnchorFixtures.GraphCanary=2, " <>
                "AnchorFixtures.IfaceLeft=1, AnchorFixtures.IfaceRight=1"
     left:  "anchor.graph: 9 modules in 1 apps, 3 rules, 0 violations (0 report-only, 0 baselined)"
     right: "anchor.graph: 9 modules in 1 apps, 3 rules, 0 violations (0 report-only, 0 baselined); interface width: AnchorFixtures.CycleA=0, AnchorFixtures.GraphCanary=2, AnchorFixtures.IfaceLeft=1, AnchorFixtures.IfaceRight=1"
     stacktrace:
       test/anchor/integration/graph_canary_test.exs:94: (test)

  4) test R7: a rule that needs the higher-order flow analysis gets it over the canary, with no bound hit, and the summary counts its apply sites (Anchor.Integration.GraphCanaryTest)
     test/anchor/integration/graph_canary_test.exs:207
     Assertion with == failed
     code:  assert GraphReport.summary(report) ==
              "anchor.graph: 9 modules in 1 apps, 4 rules, 1 violations " <>
                "(0 report-only, 0 baselined); apply sites: 2 resolved, 0 any; interface width: " <>
                "AnchorFixtures.CycleA=0, AnchorFixtures.GraphCanary=2, " <>
                "AnchorFixtures.IfaceLeft=1, AnchorFixtures.IfaceRight=1"
     left:  "anchor.graph: 9 modules in 1 apps, 4 rules, 1 violations (0 report-only, 0 baselined); apply sites: 2 resolved, 0 any"
     right: "anchor.graph: 9 modules in 1 apps, 4 rules, 1 violations (0 report-only, 0 baselined); apply sites: 2 resolved, 0 any; interface width: AnchorFixtures.CycleA=0, AnchorFixtures.GraphCanary=2, AnchorFixtures.IfaceLeft=1, AnchorFixtures.IfaceRight=1"
     stacktrace:
       test/anchor/integration/graph_canary_test.exs:224: (test)

...
```

## GR-B — the JSON omits interface_width

Run summary: `24 tests, 2 failures`

```text
  1) test interface width (DND-5443, R4) no interface rule ran: nothing is printed, and the JSON is null (Anchor.Domain.GraphReportTest)
     test/anchor/domain/graph_report_test.exs:213
     match (=) failed
     code:  assert %{"interface_width" => nil} = JSON.decode!(GraphReport.render(report, :json))
     left:  %{"interface_width" => nil}
     right: %{
              "apply_sites" => nil,
              "apps" => 2,
              "could_not_check" => [],
              "excluded" => 0,
              "exit_code" => 0,
              "findings" => [],
              "held" => [],
              "modules" => 12,
              "no_core" => 0,
              "opaque" => 0,
              "refused" => [],
              "rules" => 3
            }
     stacktrace:
       test/anchor/domain/graph_report_test.exs:217: (test)

  2) test interface width (DND-5443, R4) the summary ends with each context's width, sorted; the JSON has interface_width (Anchor.Domain.GraphReportTest)
     test/anchor/domain/graph_report_test.exs:201
     Assertion with == failed
     code:  assert JSON.decode!(GraphReport.render(report, :json))["interface_width"] == %{"A" => 5, "B" => 2}
     left:  nil
     right: %{"A" => 5, "B" => 2}
     stacktrace:
       test/anchor/domain/graph_report_test.exs:209: (test)

.....................
```

## MG-A — the runner never computes the width

Run summary: `8 tests, 2 failures`

```text
  1) test R7: a rule that needs the higher-order flow analysis gets it over the canary, with no bound hit, and the summary counts its apply sites (Anchor.Integration.GraphCanaryTest)
     test/anchor/integration/graph_canary_test.exs:207
     Assertion with == failed
     code:  assert GraphReport.summary(report) ==
              "anchor.graph: 9 modules in 1 apps, 4 rules, 1 violations " <>
                "(0 report-only, 0 baselined); apply sites: 2 resolved, 0 any; interface width: " <>
                "AnchorFixtures.CycleA=0, AnchorFixtures.GraphCanary=2, " <>
                "AnchorFixtures.IfaceLeft=1, AnchorFixtures.IfaceRight=1"
     left:  "anchor.graph: 9 modules in 1 apps, 4 rules, 1 violations (0 report-only, 0 baselined); apply sites: 2 resolved, 0 any"
     right: "anchor.graph: 9 modules in 1 apps, 4 rules, 1 violations (0 report-only, 0 baselined); apply sites: 2 resolved, 0 any; interface width: AnchorFixtures.CycleA=0, AnchorFixtures.GraphCanary=2, AnchorFixtures.IfaceLeft=1, AnchorFixtures.IfaceRight=1"
     stacktrace:
       test/anchor/integration/graph_canary_test.exs:224: (test)

....

  2) test the compliant canary modules give no findings, and the summary counts the tree (Anchor.Integration.GraphCanaryTest)
     test/anchor/integration/graph_canary_test.exs:87
     Assertion with == failed
     code:  assert GraphReport.summary(report) ==
              "anchor.graph: 9 modules in 1 apps, 3 rules, 0 violations (0 report-only, 0 baselined)" <>
                "; interface width: AnchorFixtures.CycleA=0, AnchorFixtures.GraphCanary=2, " <>
                "AnchorFixtures.IfaceLeft=1, AnchorFixtures.IfaceRight=1"
     left:  "anchor.graph: 9 modules in 1 apps, 3 rules, 0 violations (0 report-only, 0 baselined)"
     right: "anchor.graph: 9 modules in 1 apps, 3 rules, 0 violations (0 report-only, 0 baselined); interface width: AnchorFixtures.CycleA=0, AnchorFixtures.GraphCanary=2, AnchorFixtures.IfaceLeft=1, AnchorFixtures.IfaceRight=1"
     stacktrace:
       test/anchor/integration/graph_canary_test.exs:94: (test)
```

## IF-N — a dynamic call is judged against every exporter, not the narrowed targets

Run summary: `21 tests, 1 failure`

```text
  1) test check/2 over compiled fixtures (two apps) a behaviour-typed receiver reaches its implementers; an untyped one every exporter (Anchor.Domain.GraphRules.InterfaceTest)
     test/anchor/domain/graph_rules/interface_test.exs:384
     Assertion with == failed
     code:  assert keys == [
              "interface|#{@narrow_ns}.Billing.Runner.untyped/2|-> " <>
                "#{@narrow_ns}.Accounts.Domain.Worker.go/1"
            ]
     left:  ["interface|AnchorFixtures.InterfaceTest.Narrow.Billing.Runner.typed/2|-> AnchorFixtures.InterfaceTest.Narrow.Accounts.Domain.Worker.go/1",
             "interface|AnchorFixtures.InterfaceTest.Narrow.Billing.Runner.untyped/2|-> AnchorFixtures.InterfaceTest.Narrow.Accounts.Domain.Worker.go/1"]
     right: ["interface|AnchorFixtures.InterfaceTest.Narrow.Billing.Runner.untyped/2|-> AnchorFixtures.InterfaceTest.Narrow.Accounts.Domain.Worker.go/1"]
     stacktrace:
       test/anchor/domain/graph_rules/interface_test.exs:416: (test)

................
```
