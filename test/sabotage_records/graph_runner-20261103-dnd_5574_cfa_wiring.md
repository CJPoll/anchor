# Sabotage record — the CFA wiring in `mix anchor.graph` (DND-5574)

- **Domain:** graph_runner
- **Branch:** dnd-5574-cfa-wiring
- **Date:** 2026-11-03
- **Code under test:** `Anchor.Managers.Graph` (the lazy, guarded `Cfa.analyze` run and `Model.cfa`), `Anchor.Domain.GraphRules.needs/1`, `Anchor.Domain.GraphReport` (`apply_sites/1`, the summary's apply-site note, the JSON's `apply_sites`). The `Failures.rule_cfa_crashed/5` mutation of the same run is filed under its own domain: `failures-20261103-dnd_5574_cfa_wiring.md`.
- **Suite run:** one `test-slot` held a driver that, per mutation, edited one file, ran `mix test --timeout 2000 --max-cases 2 <its test files>`, and restored the file with `git checkout`; `git status --short` after the run was clean. Every row is red: a non-zero ExUnit result naming the tests the mutation is meant to break. The failure strings below are copied from that run's output (the assertion block of each row's first failing test, up to eight lines).

| # | Mutation | Tests run | Result | Failing tests |
|---|---|---|---|---|
| CW-A | the analysis is never run: Model.cfa stays nil (`lib/anchor/managers/graph.ex`) | `graph_cfa_test.exs`, `graph_canary_test.exs` | `12 tests, 3 failures` | a rule that runs needs the analysis an analysis that hits its bound is printed as one, every site any; R7: a rule that needs the higher-order flow analysis gets it over the canary, with no bound hit, and the summary counts its apply sites; a rule that runs needs the analysis it runs once for every rule, on Model.cfa, and the counts are exact |
| CW-B | the analysis runs whatever the rules need (`lib/anchor/managers/graph.ex`) | `graph_cfa_test.exs`, `graph_test.exs` | `30 tests, 4 failures` | fail closed a rule whose needs/0 names what the runner does not compute is one issue and is not run; the analysis is not run for it; no rule that runs needs the analysis it is not run: Model.cfa is nil, no counts, the summary says nothing of apply sites; no rule that runs needs the analysis --only narrowing away the rule that needs it: not run; run/2 happy path every module classifies and the rule holds: exit 0, counts exact, artifact written once |
| CW-C | the analysis runs once per rule, not once per run (`lib/anchor/managers/graph.ex`) | `graph_cfa_test.exs` | `9 tests, 1 failure` | a rule that runs needs the analysis it runs once for every rule, on Model.cfa, and the counts are exact |
| CW-D | a crashed analysis is ignored: the rule that needs it runs with Model.cfa nil (`lib/anchor/managers/graph.ex`) | `graph_cfa_test.exs` | `9 tests, 4 failures` | fail closed an analysis that exits: each rule that needs it is one issue and is not run; the others run; fail closed an analysis that raises: each rule that needs it is one issue and is not run; the others run; fail closed an analysis that throws: each rule that needs it is one issue and is not run; the others run; fail closed an analysis that returns no %Cfa{}: each rule that needs it is one issue and is not run; the others run |
| CW-E | a refused needs/0 is read as needing nothing, and the rule runs (`lib/anchor/managers/graph.ex`) | `graph_cfa_test.exs` | `9 tests, 1 failure` | fail closed a rule whose needs/0 names what the runner does not compute is one issue and is not run; the analysis is not run for it |
| CW-F | the counts are dropped from the report (`lib/anchor/managers/graph.ex`) | `graph_cfa_test.exs`, `graph_canary_test.exs` | `12 tests, 3 failures` | R7: a rule that needs the higher-order flow analysis gets it over the canary, with no bound hit, and the summary counts its apply sites; a rule that runs needs the analysis an analysis that hits its bound is printed as one, every site any; a rule that runs needs the analysis it runs once for every rule, on Model.cfa, and the counts are exact |
| CW-G | an analysis that returns no %Cfa{} is accepted (its rules run with Model.cfa nil) (`lib/anchor/managers/graph.ex`) | `graph_cfa_test.exs` | `9 tests, 1 failure` | fail closed an analysis that returns no %Cfa{}: each rule that needs it is one issue and is not run; the others run |
| RP-A | the summary never prints the apply sites (`lib/anchor/domain/graph_report.ex`) | `graph_report_test.exs`, `graph_cfa_test.exs`, `graph_canary_test.exs` | `27 tests, 5 failures` | apply sites (DND-5574, R6) the summary ends with the resolved and any counts when the analysis ran; apply sites (DND-5574, R6) a bound hit is said, never read as a result; a rule that runs needs the analysis an analysis that hits its bound is printed as one, every site any; R7: a rule that needs the higher-order flow analysis gets it over the canary, with no bound hit, and the summary counts its apply sites; a rule that runs needs the analysis it runs once for every rule, on Model.cfa, and the counts are exact |
| RP-B | a bound hit is not said (`lib/anchor/domain/graph_report.ex`) | `graph_report_test.exs`, `graph_cfa_test.exs` | `24 tests, 2 failures` | apply sites (DND-5574, R6) a bound hit is said, never read as a result; a rule that runs needs the analysis an analysis that hits its bound is printed as one, every site any |
| RP-C | the JSON always says null (`lib/anchor/domain/graph_report.ex`) | `graph_report_test.exs`, `graph_cfa_test.exs` | `24 tests, 2 failures` | apply sites (DND-5574, R6) the JSON carries the same counts, per function too; a rule that runs needs the analysis it runs once for every rule, on Model.cfa, and the counts are exact |
| RP-D | apply_sites/1 drops the bound flag (always false) (`lib/anchor/domain/graph_report.ex`) | `graph_report_test.exs`, `graph_cfa_test.exs` | `24 tests, 2 failures` | apply sites (DND-5574, R6) apply_sites/1 takes the counts and the bound from the analysis; nil for none; a rule that runs needs the analysis an analysis that hits its bound is printed as one, every site any |
| RP-E | the JSON's per-function counts are empty (`lib/anchor/domain/graph_report.ex`) | `graph_report_test.exs` | `15 tests, 1 failure` | apply sites (DND-5574, R6) the JSON carries the same counts, per function too |
| NE-A | an unknown need is accepted (`lib/anchor/domain/graph_rules.ex`) | `graph_rules_test.exs`, `graph_cfa_test.exs` | `21 tests, 2 failures` | needs/1 (DND-5574) a need the runner does not compute raises, naming it and what it computes; fail closed a rule whose needs/0 names what the runner does not compute is one issue and is not run; the analysis is not run for it |
| NE-B | needs are not deduplicated (`lib/anchor/domain/graph_rules.ex`) | `graph_rules_test.exs` | `12 tests, 1 failure` | needs/1 (DND-5574) a declared [:cfa] is read, without duplicates |
| NE-C | a non-list needs/0 is read as needing nothing (`lib/anchor/domain/graph_rules.ex`) | `graph_rules_test.exs`, `graph_cfa_test.exs` | `21 tests, 2 failures` | needs/1 (DND-5574) a needs/0 that is not a list raises; fail closed a rule whose needs/0 names what the runner does not compute is one issue and is not run; the analysis is not run for it |
| NE-D | needs/0 is never read: every rule needs nothing (`lib/anchor/domain/graph_rules.ex`) | `graph_rules_test.exs`, `graph_cfa_test.exs`, `graph_canary_test.exs` | `24 tests, 11 failures` | needs/1 (DND-5574) a declared [:cfa] is read, without duplicates; needs/1 (DND-5574) a needs/0 that is not a list raises; needs/1 (DND-5574) a need the runner does not compute raises, naming it and what it computes; fail closed a rule whose needs/0 names what the runner does not compute is one issue and is not run; the analysis is not run for it; a rule that runs needs the analysis an analysis that hits its bound is printed as one, every site any; fail closed an analysis that raises: each rule that needs it is one issue and is not run; the others run; fail closed an analysis that returns no %Cfa{}: each rule that needs it is one issue and is not run; the others run; fail closed an analysis that throws: each rule that needs it is one issue and is not run; the others run; fail closed an analysis that exits: each rule that needs it is one issue and is not run; the others run; R7: a rule that needs the higher-order flow analysis gets it over the canary, with no bound hit, and the summary counts its apply sites; a rule that runs needs the analysis it runs once for every rule, on Model.cfa, and the counts are exact |
| NE-E | a rule with no needs/0 is read as needing the analysis (`lib/anchor/domain/graph_rules.ex`) | `graph_rules_test.exs`, `graph_cfa_test.exs` | `21 tests, 8 failures` | needs/1 (DND-5574) a rule with no needs/0 needs nothing; fail closed an analysis that raises: each rule that needs it is one issue and is not run; the others run; fail closed an analysis that exits: each rule that needs it is one issue and is not run; the others run; fail closed an analysis that throws: each rule that needs it is one issue and is not run; the others run; no rule that runs needs the analysis --only narrowing away the rule that needs it: not run; fail closed an analysis that returns no %Cfa{}: each rule that needs it is one issue and is not run; the others run; fail closed a rule whose needs/0 names what the runner does not compute is one issue and is not run; the analysis is not run for it; no rule that runs needs the analysis it is not run: Model.cfa is nil, no counts, the summary says nothing of apply sites |
| RP-F | no analysis still prints an apply-sites note, and a JSON object (`lib/anchor/domain/graph_report.ex`) | `graph_report_test.exs`, `graph_cfa_test.exs` | `24 tests, 5 failures` | render/2 :text could-not-check entries print first and count as violations; render/2 :text opaque modules are counted in the summary when there are any; render/2 :text one line per finding, then the summary with exact counts; apply sites (DND-5574, R6) no analysis: the summary says nothing of apply sites, and the JSON is null; no rule that runs needs the analysis it is not run: Model.cfa is nil, no counts, the summary says nothing of apply sites |
| RP-G | no analysis is a JSON object, not null (`lib/anchor/domain/graph_report.ex`) | `graph_report_test.exs` | `15 tests, 1 failure` | apply sites (DND-5574, R6) no analysis: the summary says nothing of apply sites, and the JSON is null |

## Failure strings (verbatim, the first failing test of each row)

### CW-A — the analysis is never run: Model.cfa stays nil

```
match (=) failed
code:  assert %{total: 3, resolved: 0, any: 3, bound_hit?: true} = report.counts.apply_sites
left:  %{total: 3, resolved: 0, any: 3, bound_hit?: true}
right: nil
```

### CW-B — the analysis runs whatever the rules need

```
Unexpectedly received message :cfa_ran (which matched :cfa_ran)
code: refute_received :cfa_ran
```

### CW-C — the analysis runs once per rule, not once per run

```
Unexpectedly received message :cfa_ran (which matched :cfa_ran)
code: refute_received :cfa_ran
```

### CW-D — a crashed analysis is ignored: the rule that needs it runs with Model.cfa nil

```
Assertion with =~ failed
code:  assert crashed.message =~
~s|rule 1 (id: "needs", stub_needs_cfa) could not run: the higher-order flow | <>
"analysis it needs (Anchor.Domain.Cfa) crashed: #{"exit: :gone"}"
left:  "needs saw cfa: nil. Fix: none, a probe."
right: "rule 1 (id: \"needs\", stub_needs_cfa) could not run: the higher-order flow analysis it needs (Anchor.Domain.Cfa) crashed: exit: :gone"
```

### CW-E — a refused needs/0 is read as needing nothing, and the rule runs

```
match (=) failed
code:  assert [unknown, nonlist, probe] = report.findings
left:  [unknown, nonlist, probe]
right: [
%Anchor.Domain.GraphReport.Finding{
rule_id: "probe",
type: :stub_cfa_probe,
label: "rule 3 (id: \"probe\", stub_cfa_probe)",
```

### CW-F — the counts are dropped from the report

```
match (=) failed
code:  assert %{total: 2, resolved: 2, any: 0, bound_hit?: false} = report.counts.apply_sites
left:  %{total: 2, resolved: 2, any: 0, bound_hit?: false}
right: nil
```

### CW-G — an analysis that returns no %Cfa{} is accepted (its rules run with Model.cfa nil)

```
Assertion with =~ failed
code:  assert crashed.message =~
~s|rule 1 (id: "needs", stub_needs_cfa) could not run: the higher-order flow | <>
"analysis it needs (Anchor.Domain.Cfa) crashed: #{"ArgumentError: the analysis returned :oops, not a %Cfa{}"}"
left:  "needs saw cfa: nil. Fix: none, a probe."
right: "rule 1 (id: \"needs\", stub_needs_cfa) could not run: the higher-order flow analysis it needs (Anchor.Domain.Cfa) crashed: ArgumentError: the analysis returned :oops, not a %Cfa{}"
```

### RP-A — the summary never prints the apply sites

```
Assertion with == failed
code:  assert GraphReport.summary(report) ==
"anchor.graph: 12 modules in 2 apps, 3 rules, 0 violations " <>
"(0 report-only, 0 baselined); apply sites: 2 resolved, 1 any"
left:  "anchor.graph: 12 modules in 2 apps, 3 rules, 0 violations (0 report-only, 0 baselined)"
right: "anchor.graph: 12 modules in 2 apps, 3 rules, 0 violations (0 report-only, 0 baselined); apply sites: 2 resolved, 1 any"
```

### RP-B — a bound hit is not said

```
Assertion with =~ failed
code:  assert GraphReport.summary(report) =~
"; apply sites: 0 resolved, 3 any (step bound hit: every site reads any)"
left:  "anchor.graph: 12 modules in 2 apps, 3 rules, 0 violations (0 report-only, 0 baselined); apply sites: 0 resolved, 3 any"
right: "; apply sites: 0 resolved, 3 any (step bound hit: every site reads any)"
```

### RP-C — the JSON always says null

```
Assertion with == failed
code:  assert JSON.decode!(GraphReport.render(report, :json))["apply_sites"] == %{
"total" => 3,
"resolved" => 2,
"any" => 1,
"bound_hit" => false,
"by_function" => %{"MyApp.X.run/1" => %{"total" => 3, "resolved" => 2, "any" => 1}}
}
```

### RP-D — apply_sites/1 drops the bound flag (always false)

```
Assertion with == failed
code:  assert GraphReport.apply_sites(cfa) == %{@sites | bound_hit?: true}
left:  %{
any: 1,
total: 3,
resolved: 2,
bound_hit?: false,
by_function: %{
```

### RP-E — the JSON's per-function counts are empty

```
Assertion with == failed
code:  assert JSON.decode!(GraphReport.render(report, :json))["apply_sites"] == %{
"total" => 3,
"resolved" => 2,
"any" => 1,
"bound_hit" => false,
"by_function" => %{"MyApp.X.run/1" => %{"total" => 3, "resolved" => 2, "any" => 1}}
}
```

### NE-A — an unknown need is accepted

```
Expected exception ArgumentError but nothing was raised
code: error = assert_raise ArgumentError, fn -> GraphRules.needs(Stubs.NeedsUnknown) end
```

### NE-B — needs are not deduplicated

```
Assertion with == failed
code:  assert GraphRules.needs(Stubs.NeedsCfa) == [:cfa]
left:  [:cfa, :cfa]
right: [:cfa]
```

### NE-C — a non-list needs/0 is read as needing nothing

```
Expected exception ArgumentError but nothing was raised
code: error = assert_raise ArgumentError, fn -> GraphRules.needs(Stubs.NeedsNonList) end
```

### NE-D — needs/0 is never read: every rule needs nothing

```
Assertion with == failed
code:  assert GraphRules.needs(Stubs.NeedsCfa) == [:cfa]
left:  []
right: [:cfa]
```

### NE-E — a rule with no needs/0 is read as needing the analysis

```
Assertion with == failed
code:  assert GraphRules.needs(Stubs.Ok) == []
left:  [:cfa]
right: []
```

### RP-F — no analysis still prints an apply-sites note, and a JSON object

```
Assertion with == failed
code:  assert GraphReport.render(report, :text) ==
".anchor.yml:1: [enforce] anchor.graph COULD NOT MEASURE: x. Fix: y.\n" <>
"anchor.graph: 0 modules in 2 apps, 3 rules, 1 violations (0 report-only, 0 baselined)"
left:  ".anchor.yml:1: [enforce] anchor.graph COULD NOT MEASURE: x. Fix: y.\nanchor.graph: 0 modules in 2 apps, 3 rules, 1 violations (0 report-only, 0 baselined); apply sites: not computed"
right: ".anchor.yml:1: [enforce] anchor.graph COULD NOT MEASURE: x. Fix: y.\nanchor.graph: 0 modules in 2 apps, 3 rules, 1 violations (0 report-only, 0 baselined)"
```

### RP-G — no analysis is a JSON object, not null

```
match (=) failed
code:  assert %{"apply_sites" => nil} = JSON.decode!(GraphReport.render(report, :json))
left:  %{"apply_sites" => nil}
right: %{
"apply_sites" => %{},
"apps" => 2,
"could_not_check" => [],
"exit_code" => 0,
```

## Earlier driver passes, and what changed

- Pass 1: RP-A did not compile (`--warnings-as-errors`: the mutant left
  `resolved`, `any` and `bound_hit?` in a dead `if`), so it proved nothing;
  it was re-shaped to the mutant above. RP-E survived (`15 tests, 0
  failures`): `%{} && sites.by_function` is still `sites.by_function`, as
  `%{}` is truthy, so it was a bad mutant, not a gap; re-shaped to
  `Map.take(sites.by_function, [])`, it is red.
- The review floor asked for CW-G (the `%Cfa{}` return check, added after
  pass 1), NE-E (the "no needs/0 needs nothing" test had no red), RP-F and
  RP-G (the "no analysis" test had no red), `graph_test.exs` in CW-B's run,
  verbatim failure strings, and the failures mutation in its own file. This
  record is the last pass, on the tree under review, with all of them.
