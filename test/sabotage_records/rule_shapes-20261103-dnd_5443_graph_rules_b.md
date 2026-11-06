# Sabotage record — one Fix: per issue, and every rule type's shape (DND-5446)

- **Domain:** rule_shapes
- **Branch:** dnd-5443-graph-rules-b
- **Date:** 2026-11-03
- **Code under test:** `Anchor.Domain.RuleShapes` (`for/1`, `with_fix/2`, `with_shape/2`, `append_fix/2`, `fix_count/1`), each `Anchor.Domain.Checks.*` module's `shape/1` and Fix suffix, and in `Anchor.Domain.Failures` the generic Fix of a rejected config (`with_generic_fix/2`) and the three load refusals moved there from `Anchor.Domain.RuleSchema`
- **Suite run:** each mutation ran `mix test --force --timeout 2000 --max-cases 2 <its test files>` inside one `test-slot`, by a driver that applied it, ran the files and restored the source. Every row is red. The checkout's absolute path in the output reads `<worktree>`.

RS-E and RS-F stand for every check: each check appends its Fix through the same
`RuleShapes.with_shape/2` call, and `fix_shape_invariant_test.exs` holds every
AST type's canonical violation to exactly one `Fix:`, its shape.

Merging origin/main brought DND-5476's `aggregate_declarations` graph rule.
The invariant's tests failed until it was registered in `RuleShapes` (RS-G);
its canary is a fixture of its own, so its integration test now holds its
findings to one `Fix:` (RS-H), and the graph canary names that test.

| # | Mutation | Tests run | Result | Failing tests |
|---|---|---|---|---|
| RS-A | append_fix appends a second Fix: to a message that has one (`lib/anchor/domain/rule_shapes.ex`) | `rule_shapes_test.exs`, `fix_shape_invariant_test.exs` | `23 tests, 1 failure` (red) | with_fix/2 a message that already carries a Fix: is not given a second |
| RS-B | append_fix adds no full stop before Fix: (`lib/anchor/domain/rule_shapes.ex`) | `rule_shapes_test.exs`, `fix_shape_invariant_test.exs` | `23 tests, 1 failure` (red) | with_fix/2 appends ` Fix: <shape>` once, after a full stop |
| RS-C | fix_count/1 off by one (`lib/anchor/domain/rule_shapes.ex`) | `rule_shapes_test.exs`, `fix_shape_invariant_test.exs` | `23 tests, 17 failures` (red) | with_fix/2 a violation's message is given its Fix; fix_count/1 counts Fix: sentences; alphabetized_functions: its canonical violation ends with exactly one Fix:, its rule's shape; no_transitive_dependency: its canonical violation ends with exactly one Fix:, its rule's shape; must_use_module: its canonical violation ends with exactly one Fix:, its rule's shape; no_forwarding_function: its canonical violation ends with exactly one Fix:, its rule's shape; case_on_bare_arg: its canonical violation ends with exactly one Fix:, its rule's shape; no_tuple_match_in_head: its canonical violation ends with exactly one Fix:, its rule's shape; no_discarded_pure_expression: its canonical violation ends with exactly one Fix:, its rule's shape |
| RS-D | a rule type with no shape entry (struct_owned_by_module) (`lib/anchor/domain/rule_shapes.ex`) | `rule_shapes_test.exs`, `fix_shape_invariant_test.exs` | `23 tests, 2 failures` (red) | for/1 every rule type in RuleSchema.rule_types/0 has a non-empty shape; struct_owned_by_module: its canonical violation ends with exactly one Fix:, its rule's shape |
| RS-E | one check (must_use_module) drops its Fix suffix (`lib/anchor/domain/checks/must_use_module.ex`) | `rule_shapes_test.exs`, `fix_shape_invariant_test.exs`, `must_use_module_test.exs`, `must_use_module_test.exs` | `39 tests, 4 failures` (red) | detect_violations/2 flags a module missing a required use (message/trigger/line); check_file/3 one of two required modules present flags only the missing one; check_file/3 flags a module missing a required use; must_use_module: its canonical violation ends with exactly one Fix:, its rule's shape |
| RS-F | one check (case_on_bare_arg) drops its Fix suffix (`lib/anchor/domain/checks/case_on_bare_arg.ex`) | `rule_shapes_test.exs`, `fix_shape_invariant_test.exs`, `case_on_bare_arg_test.exs` | `32 tests, 2 failures` (red) | check_file/3 flags case directly on a bare argument; case_on_bare_arg: its canonical violation ends with exactly one Fix:, its rule's shape |
| FA-A | the generic Fix is appended even when the reason has its own (two Fix:) (`lib/anchor/domain/failures.ex`) | `failures_test.exs`, `rule_checks_nothing_test.exs`, `architecture_checks_nothing_test.exs` | `84 tests, 29 failures` (red) | one Fix: per rejected config each moved load refusal keeps its own Fix, and only it; struct_owned_by_module: every rule that checks nothing is refused, and the positive rows load; no_discarded_pure_expression: every rule that checks nothing is refused, and the positive rows load; extract_pure_regions_from: every refusal is refused with its key path and Fix:, positives load; contexts: every refusal is refused with its key path and Fix:, positives load; roots[].behaviour: every refusal is refused with its key path and Fix:, positives load; buckets[].select[].uses_module: every refusal is refused with its key path and Fix:, positives load; interfaces.exports: every refusal is refused with its key path and Fix:, positives load; buckets: every refusal is refused with its key path and Fix:, positives load |
| FA-B | a reason with no Fix gets none (`lib/anchor/domain/failures.ex`) | `failures_test.exs`, `rule_checks_nothing_test.exs`, `architecture_checks_nothing_test.exs` | `84 tests, 21 failures` (red) | one Fix: per rejected config a reason with no Fix gets the generic one, once; config_violation/1 an invalid document carries the validation message; config_violation/1 an invalid rule carries the validation message; module_pattern_restrictions: every rule that checks nothing is refused, and the positive rows load; struct_getter_convention: every rule that checks nothing is refused, and the positive rows load; no_tuple_match_in_head: every rule that checks nothing is refused, and the positive rows load; no_discarding_arrow_in_with: every rule that checks nothing is refused, and the positive rows load; max_file_length: every rule that checks nothing is refused, and the positive rows load; context_acyclic: every rule that checks nothing is refused, and the positive rows load |
| FA-C | the moved owned_namespaces: [] refusal loses its own Fix (the generic one replaces it) (`lib/anchor/domain/failures.ex`) | `failures_test.exs`, `rule_checks_nothing_test.exs`, `architecture_checks_nothing_test.exs` | `84 tests, 1 failure` (red) | one Fix: per rejected config each moved load refusal keeps its own Fix, and only it |
| FA-D | the moved pure_patterns refusal loses its own Fix (`lib/anchor/domain/failures.ex`) | `failures_test.exs`, `rule_checks_nothing_test.exs`, `architecture_checks_nothing_test.exs` | `84 tests, 1 failure` (red) | one Fix: per rejected config each moved load refusal keeps its own Fix, and only it |
| RS-G | aggregate_declarations (main's new graph type) has no shape entry (`lib/anchor/domain/rule_shapes.ex`) | `rule_shapes_test.exs` | `7 tests, 1 failure` (red) | for/1 every rule type in RuleSchema.rule_types/0 has a non-empty shape |
| RS-H | an aggregate_declarations finding (claimed twice) carries no Fix: (`lib/anchor/domain/graph_rules/aggregate_declarations.ex`) | `aggregate_declarations_integration_test.exs` | `2 tests, 1 failure` (red) | N1: the violating module's table claim is claimed twice, at the config and at it |
| EP-F | identity keeps the Fix: sentence (`lib/anchor/domain/enforcement_passes.ex`) | `enforcement_passes_test.exs`, `lint_baseline_test.exs` | `37 tests, 3 failures` (red) | merge/2 two rules' copies differing only in their Fix: are one finding, the enforced one's; a finding two rules make with no baseline yet, two report rules' finding keeps the baselined rule's key (for --write); a finding two rules make a report rule's copy never downgrades an enforced baselined rule's NEW finding |
| RS-W | without_fix drops nothing (`lib/anchor/domain/rule_shapes.ex`) | `enforcement_passes_test.exs` | `15 tests, 1 failure` (red) | merge/2 two rules' copies differing only in their Fix: are one finding, the enforced one's |
| EC-G | a Manager's effect finding carries no Fix: (`lib/anchor/domain/graph_rules/effects_match_bucket.ex`) | `effects_canary_test.exs` | `3 tests, 1 failure` (red) | the violating modules give one finding per bad function, the compliant none |
| EC-F | the fallback role's finding carries no Fix: (`lib/anchor/domain/graph_rules/effects_match_bucket.ex`) | `effects_canary_test.exs`, `effects_match_bucket_test.exs` | `18 tests, 0 failures` (GREEN: survived) |  |

After merging main at 07aef9f. EP-F and RS-W cover the identity fix; EP-F restores the unfixed behaviour. EC-G is the one-Fix assertion in effects_canary_test.exs. EC-F SURVIVES, and is a finding, not a pass: effects_match_bucket's last message clause is a fallback no (bucket role, inferred role) pair the other clauses leave reaches, so no test can reach it. It is main's code; proposed as a ticket in the MR report.

## RS-A — append_fix appends a second Fix: to a message that has one

Run summary: `23 tests, 1 failure`

```text
  1) test with_fix/2 a message that already carries a Fix: is not given a second (Anchor.Domain.RuleShapesTest)
     test/anchor/domain/rule_shapes_test.exs:67
     Assertion with == failed
     code:  assert RuleShapes.with_fix("Cannot resolve. Fix: name it literally.", @rule) ==
              "Cannot resolve. Fix: name it literally."
     left:  "Cannot resolve. Fix: name it literally. Fix: one control structure per function clause: extract each extra pipe chain, case, cond, with, if, unless, for or receive into its own named function"
     right: "Cannot resolve. Fix: name it literally."
     stacktrace:
       test/anchor/domain/rule_shapes_test.exs:68: (test)

................
```

## RS-B — append_fix adds no full stop before Fix:

Run summary: `23 tests, 1 failure`

```text
  1) test with_fix/2 appends ` Fix: <shape>` once, after a full stop (Anchor.Domain.RuleShapesTest)
     test/anchor/domain/rule_shapes_test.exs:59
     Assertion with == failed
     code:  assert RuleShapes.with_fix("Too many structures", @rule) ==
              "Too many structures. Fix: " <> RuleShapes.for(@rule)
     left:  "Too many structures Fix: one control structure per function clause: extract each extra pipe chain, case, cond, with, if, unless, for or receive into its own named function"
     right: "Too many structures. Fix: one control structure per function clause: extract each extra pipe chain, case, cond, with, if, unless, for or receive into its own named function"
     stacktrace:
       test/anchor/domain/rule_shapes_test.exs:60: (test)

...................
```

## RS-C — fix_count/1 off by one

Run summary: `23 tests, 17 failures`

```text
  1) test with_fix/2 a violation's message is given its Fix (Anchor.Domain.RuleShapesTest)
     test/anchor/domain/rule_shapes_test.exs:72
     Assertion with == failed
     code:  assert RuleShapes.fix_count(message) == 1
     left:  2
     right: 1
     stacktrace:
       test/anchor/domain/rule_shapes_test.exs:76: (test)

..

  2) test fix_count/1 counts Fix: sentences (Anchor.Domain.RuleShapesTest)
     test/anchor/domain/rule_shapes_test.exs:81
     Assertion with == failed
     code:  assert RuleShapes.fix_count("none") == 0
     left:  1
     right: 0
     stacktrace:
       test/anchor/domain/rule_shapes_test.exs:82: (test)

.

  3) test alphabetized_functions: its canonical violation ends with exactly one Fix:, its rule's shape (Anchor.Domain.FixShapeInvariantTest)
     test/anchor/domain/fix_shape_invariant_test.exs:137
     function `b/1` is not in alphabetical order. It should appear after a/1. Fix: define every function of the module in alphabetical order (by name, then arity)
     code: for violation <- violations do
     stacktrace:
       test/anchor/domain/fix_shape_invariant_test.exs:147: anonymous fn/2 in Anchor.Domain.FixShapeInvariantTest."test alphabetized_functions: its canonical violation ends with exactly one Fix:, its rule's shape"/1
       (elixir 1.19.4) lib/enum.ex:1688: Enum."-map/2-lists^map/1-1-"/2
       test/anchor/domain/fix_shape_invariant_test.exs:146: (test)

.

  4) test no_transitive_dependency: its canonical violation ends with exactly one Fix:, its rule's shape (Anchor.Domain.FixShapeInvariantTest)
     test/anchor/domain/fix_shape_invariant_test.exs:137
     Module has transitive dependency on forbidden module MyApp.Repo (dependency chain: A -> B -> MyApp.Repo). Fix: no chain of dependencies from the module reaches MyApp.Repo; cut the chain where it first enters a module that depends on it
     code: for violation <- violations do
     stacktrace:
       test/anchor/domain/fix_shape_invariant_test.exs:147: anonymous fn/2 in Anchor.Domain.FixShapeInvariantTest."test no_transitive_dependency: its canonical violation ends with exactly one Fix:, its rule's shape"/1
       (elixir 1.19.4) lib/enum.ex:1688: Enum."-map/2-lists^map/1-1-"/2
       test/anchor/domain/fix_shape_invariant_test.exs:146: (test)

  5) test must_use_module: its canonical violation ends with exactly one Fix:, its rule's shape (Anchor.Domain.FixShapeInvariantTest)
     test/anchor/domain/fix_shape_invariant_test.exs:137
     Module must use MyApp.Base. Fix: use MyApp.Base in the module's own defmodule body
     code: for violation <- violations do
     stacktrace:
       test/anchor/domain/fix_shape_invariant_test.exs:147: anonymous fn/2 in Anchor.Domain.FixShapeInvariantTest."test must_use_module: its canonical violation ends with exactly one Fix:, its rule's shape"/1
       (elixir 1.19.4) lib/enum.ex:1688: Enum."-map/2-lists^map/1-1-"/2
       test/anchor/domain/fix_shape_invariant_test.exs:146: (test)

  6) test no_forwarding_function: its canonical violation ends with exactly one Fix:, its rule's shape (Anchor.Domain.FixShapeInvariantTest)
     test/anchor/domain/fix_shape_invariant_test.exs:137
     f/1 only forwards its arguments unchanged to g/1 in the same module: an inert hop. Fix: inline the hop: make the callers of f/n call g/n directly and delete f/n, or rename g/n to f/n (public if f/n was). Keep a forwarding function only where it crosses a boundary (a behaviour callback marked @impl, another module's public API).
     code: for violation <- violations do
     stacktrace:
       test/anchor/domain/fix_shape_invariant_test.exs:147: anonymous fn/2 in Anchor.Domain.FixShapeInvariantTest."test no_forwarding_function: its canonical violation ends with exactly one Fix:, its rule's shape"/1
       (elixir 1.19.4) lib/enum.ex:1688: Enum."-map/2-lists^map/1-1-"/2
       test/anchor/domain/fix_shape_invariant_test.exs:146: (test)

  7) test case_on_bare_arg: its canonical violation ends with exactly one Fix:, its rule's shape (Anchor.Domain.FixShapeInvariantTest)
     test/anchor/domain/fix_shape_invariant_test.exs:137
     Case statement operates on bare argument `x` in function `f`. Consider using function head pattern matching instead. Fix: match the argument in the function heads, one clause per case branch, instead of a case on the bare argument
     code: for violation <- violations do
     stacktrace:
       test/anchor/domain/fix_shape_invariant_test.exs:147: anonymous fn/2 in Anchor.Domain.FixShapeInvariantTest."test case_on_bare_arg: its canonical violation ends with exactly one Fix:, its rule's shape"/1
       (elixir 1.19.4) lib/enum.ex:1688: Enum."-map/2-lists^map/1-1-"/2
       test/anchor/domain/fix_shape_invariant_test.exs:146: (test)

  8) test no_tuple_match_in_head: its canonical violation ends with exactly one Fix:, its rule's shape (Anchor.Domain.FixShapeInvariantTest)
     test/anchor/domain/fix_shape_invariant_test.exs:137
     Function `f` pattern matches on :ok/:error tuple in its public function head. Consider having the calling function use a case statement on the value instead. Fix: take the result as one plain argument, and let the caller branch on {:ok, _} and {:error, _} with a case
     code: for violation <- violations do
     stacktrace:
       test/anchor/domain/fix_shape_invariant_test.exs:147: anonymous fn/2 in Anchor.Domain.FixShapeInvariantTest."test no_tuple_match_in_head: its canonical violation ends with exactly one Fix:, its rule's shape"/1
       (elixir 1.19.4) lib/enum.ex:1688: Enum."-map/2-lists^map/1-1-"/2
       test/anchor/domain/fix_shape_invariant_test.exs:146: (test)

  9) test no_discarded_pure_expression: its canonical violation ends with exactly one Fix:, its rule's shape (Anchor.Domain.FixShapeInvariantTest)
     test/anchor/domain/fix_shape_invariant_test.exs:137
     This expression's value is discarded and it has no effect, so it causes nothing. Fix: use the value (bind it and use the binding, or make it the block's last expression), or delete it. A call kept for its effect must be to a module outside pure_patterns and the stdlib pure set.
     code: for violation <- violations do
     stacktrace:
       test/anchor/domain/fix_shape_invariant_test.exs:147: anonymous fn/2 in Anchor.Domain.FixShapeInvariantTest."test no_discarded_pure_expression: its canonical violation ends with exactly one Fix:, its rule's shape"/1
       (elixir 1.19.4) lib/enum.ex:1688: Enum."-map/2-lists^map/1-1-"/2
       test/anchor/domain/fix_shape_invariant_test.exs:146: (test)



 10) test max_file_length: its canonical violation ends with exactly one Fix:, its rule's shape (Anchor.Domain.FixShapeInvariantTest)
     test/anchor/domain/fix_shape_invariant_test.exs:137
     File contains 4 lines of code (maximum allowed: 1). Consider breaking this file into smaller, more focused modules. Fix: at most 1 lines of code per file; split the module into smaller modules, each with one responsibility
     code: for violation <- violations do
     stacktrace:
       test/anchor/domain/fix_shape_invariant_test.exs:147: anonymous fn/2 in Anchor.Domain.FixShapeInvariantTest."test max_file_length: its canonical violation ends with exactly one Fix:, its rule's shape"/1
       (elixir 1.19.4) lib/enum.ex:1688: Enum."-map/2-lists^map/1-1-"/2
       test/anchor/domain/fix_shape_invariant_test.exs:146: (test)



 11) test no_comparison_in_if: its canonical violation ends with exactly one Fix:, its rule's shape (Anchor.Domain.FixShapeInvariantTest)
     test/anchor/domain/fix_shape_invariant_test.exs:137
     Avoid direct comparisons in `if` statements. Extract the comparison to a function in the appropriate module with a descriptive name. Fix: extract the comparison into a predicate function with a descriptive name, in the module that owns the data, and branch on its result
     code: for violation <- violations do
     stacktrace:
       test/anchor/domain/fix_shape_invariant_test.exs:147: anonymous fn/2 in Anchor.Domain.FixShapeInvariantTest."test no_comparison_in_if: its canonical violation ends with exactly one Fix:, its rule's shape"/1
       (elixir 1.19.4) lib/enum.ex:1688: Enum."-map/2-lists^map/1-1-"/2
       test/anchor/domain/fix_shape_invariant_test.exs:146: (test)



 12) test module_pattern_restrictions: its canonical violation ends with exactly one Fix:, its rule's shape (Anchor.Domain.FixShapeInvariantTest)
     test/anchor/domain/fix_shape_invariant_test.exs:137
     Module defines non-allowed function: other. Fix: define only the allowed functions: new
     code: for violation <- violations do
     stacktrace:
       test/anchor/domain/fix_shape_invariant_test.exs:147: anonymous fn/2 in Anchor.Domain.FixShapeInvariantTest."test module_pattern_restrictions: its canonical violation ends with exactly one Fix:, its rule's shape"/1
       (elixir 1.19.4) lib/enum.ex:1688: Enum."-map/2-lists^map/1-1-"/2
       test/anchor/domain/fix_shape_invariant_test.exs:146: (test)



 13) test struct_getter_convention: its canonical violation ends with exactly one Fix:, its rule's shape (Anchor.Domain.FixShapeInvariantTest)
     test/anchor/domain/fix_shape_invariant_test.exs:137
     Getter function `get_name` should be named `name` to match the field it extracts. Fix: name a getter after the field it returns, and define it in the struct's own module
     code: for violation <- violations do
     stacktrace:
       test/anchor/domain/fix_shape_invariant_test.exs:147: anonymous fn/2 in Anchor.Domain.FixShapeInvariantTest."test struct_getter_convention: its canonical violation ends with exactly one Fix:, its rule's shape"/1
       (elixir 1.19.4) lib/enum.ex:1688: Enum."-map/2-lists^map/1-1-"/2
       test/anchor/domain/fix_shape_invariant_test.exs:146: (test)



 14) test single_control_flow: its canonical violation ends with exactly one Fix:, its rule's shape (Anchor.Domain.FixShapeInvariantTest)
     test/anchor/domain/fix_shape_invariant_test.exs:137
     Function clause `f` contains 2 control-flow structures (maximum allowed: 1). Control-flow structures include: pipe chains (|>), cond, with, case, if, unless, for, and receive. Favor extracting pipe chains to helpers before extracting other structures. Fix: one control structure per function clause: extract each extra pipe chain, case, cond, with, if, unless, for or receive into its own named function
     code: for violation <- violations do
     stacktrace:
       test/anchor/domain/fix_shape_invariant_test.exs:147: anonymous fn/2 in Anchor.Domain.FixShapeInvariantTest."test single_control_flow: its canonical violation ends with exactly one Fix:, its rule's shape"/1
       (elixir 1.19.4) lib/enum.ex:1688: Enum."-map/2-lists^map/1-1-"/2
       test/anchor/domain/fix_shape_invariant_test.exs:146: (test)



 15) test no_discarding_arrow_in_with: its canonical violation ends with exactly one Fix:, its rule's shape (Anchor.Domain.FixShapeInvariantTest)
     test/anchor/domain/fix_shape_invariant_test.exs:137
     Unnecessary arrow (<-) in with clause. Pattern `_` only discards the value. Remove the arrow and pattern to simplify. Fix: write a with clause whose value is discarded as a bare expression, without a discarding pattern and arrow
     code: for violation <- violations do
     stacktrace:
       test/anchor/domain/fix_shape_invariant_test.exs:147: anonymous fn/2 in Anchor.Domain.FixShapeInvariantTest."test no_discarding_arrow_in_with: its canonical violation ends with exactly one Fix:, its rule's shape"/1
       (elixir 1.19.4) lib/enum.ex:1688: Enum."-map/2-lists^map/1-1-"/2
       test/anchor/domain/fix_shape_invariant_test.exs:146: (test)



 16) test no_direct_dependency: its canonical violation ends with exactly one Fix:, its rule's shape (Anchor.Domain.FixShapeInvariantTest)
     test/anchor/domain/fix_shape_invariant_test.exs:137
     Module has forbidden direct dependency on MyApp.Repo. Fix: do not reference MyApp.Repo from a module this rule selects; reach it through a module the rule allows
     code: for violation <- violations do
     stacktrace:
       test/anchor/domain/fix_shape_invariant_test.exs:147: anonymous fn/2 in Anchor.Domain.FixShapeInvariantTest."test no_direct_dependency: its canonical violation ends with exactly one Fix:, its rule's shape"/1
       (elixir 1.19.4) lib/enum.ex:1688: Enum."-map/2-lists^map/1-1-"/2
       test/anchor/domain/fix_shape_invariant_test.exs:146: (test)



 17) test struct_owned_by_module: its canonical violation ends with exactly one Fix:, its rule's shape (Anchor.Domain.FixShapeInvariantTest)
     test/anchor/domain/fix_shape_invariant_test.exs:137
     Only B's own module may build or change B. Fix: call a function on S's own module that builds or changes it (e.g. S.new/1, S.put_<field>/2); read fields and pattern-match freely.
     code: for violation <- violations do
     stacktrace:
       test/anchor/domain/fix_shape_invariant_test.exs:147: anonymous fn/2 in Anchor.Domain.FixShapeInvariantTest."test struct_owned_by_module: its canonical violation ends with exactly one Fix:, its rule's shape"/1
       (elixir 1.19.4) lib/enum.ex:1688: Enum."-map/2-lists^map/1-1-"/2
       test/anchor/domain/fix_shape_invariant_test.exs:146: (test)
```

## RS-D — a rule type with no shape entry (struct_owned_by_module)

Run summary: `23 tests, 2 failures`

```text
  1) test for/1 every rule type in RuleSchema.rule_types/0 has a non-empty shape (Anchor.Domain.RuleShapesTest)
     test/anchor/domain/rule_shapes_test.exs:30
     ** (FunctionClauseError) no function clause matching in Anchor.Domain.RuleShapes.for/1

     The following arguments were given to Anchor.Domain.RuleShapes.for/1:

         # 1
         %{id: nil, match: :reference, type: :struct_owned_by_module, mode: nil, pattern: "MyApp.*", recursive: false, paths: nil, enforcement: :enforce, min_modules: nil, context_depth: 2, uses_module: nil, same_context: false, bucket: nil, baseline: nil, max_lines: nil, allowed_functions: [], required_modules: [], forbidden_modules: [], forbidden_patterns: [], forbidden_functions: [], allowed_callers: [], owned_namespaces: nil, pure_patterns: [], min_files: 1, max_width: nil}

     Attempted function clauses (showing 1 out of 1):

         def for(%{type: type} = rule) when -is_map_key(
       %{
         alphabetized_functions: Anchor.Domain.Checks.AlphabetizedFunctions,
         case_on_bare_arg: Anchor.Domain.Checks.CaseOnBareArg,
         context_acyclic: Anchor.Domain.GraphRules.ContextAcyclic,
         interface: Anchor.Domain.GraphRules.Interface,
         layering: Anchor.Domain.GraphRules.Layering,
         max_file_length: Anchor.Domain.Checks.MaxFileLength,
         module_pattern_restrictions: Anchor.Domain.Checks.ModulePatternRestrictions,
         must_use_module: Anchor.Domain.Checks.MustUseModule,
         no_comparison_in_if: Anchor.Domain.Checks.NoComparisonInIf,
         no_direct_dependency: Anchor.Domain.Checks.NoDependency,
         no_discarded_pure_expression: Anchor.Domain.Checks.NoDiscardedPureExpression,
         no_discarding_arrow_in_with: Anchor.Domain.Checks.NoDiscardingArrowInWith,
         no_forwarding_function: Anchor.Domain.Checks.NoForwardingFunction,
         no_transitive_dependency: Anchor.Domain.Checks.NoTransitiveDependency,
         no_tuple_match_in_head: Anchor.Domain.Checks.NoTupleMatchInHead,
         single_control_flow: Anchor.Domain.Checks.SingleControlFlow,
         struct_getter_convention: Anchor.Domain.Checks.StructGetterConvention
       },
       type
     )-

     code: for type <- RuleSchema.rule_types() do
     stacktrace:
       (anchor 0.1.0) lib/anchor/domain/rule_shapes.ex:52: Anchor.Domain.RuleShapes.for/1
       test/anchor/domain/rule_shapes_test.exs:32: anonymous fn/2 in Anchor.Domain.RuleShapesTest."test for/1 every rule type in RuleSchema.rule_types/0 has a non-empty shape"/1
       (elixir 1.19.4) lib/enum.ex:2520: Enum."-reduce/3-lists^foldl/2-0-"/3
       test/anchor/domain/rule_shapes_test.exs:31: (test)

.......

  2) test struct_owned_by_module: its canonical violation ends with exactly one Fix:, its rule's shape (Anchor.Domain.FixShapeInvariantTest)
     test/anchor/domain/fix_shape_invariant_test.exs:137
     ** (FunctionClauseError) no function clause matching in Anchor.Domain.RuleShapes.for/1

     The following arguments were given to Anchor.Domain.RuleShapes.for/1:

         # 1
         %{id: nil, match: :reference, type: :struct_owned_by_module, mode: nil, pattern: "*", recursive: false, paths: nil, enforcement: :enforce, min_modules: nil, context_depth: 2, uses_module: nil, same_context: false, bucket: nil, baseline: nil, max_lines: nil, allowed_functions: [], required_modules: [], forbidden_modules: [], forbidden_patterns: [], forbidden_functions: [], allowed_callers: [], owned_namespaces: nil, pure_patterns: [], min_files: 1, max_width: nil}

     Attempted function clauses (showing 1 out of 1):

         def for(%{type: type} = rule) when -is_map_key(
       %{
         alphabetized_functions: Anchor.Domain.Checks.AlphabetizedFunctions,
         case_on_bare_arg: Anchor.Domain.Checks.CaseOnBareArg,
         context_acyclic: Anchor.Domain.GraphRules.ContextAcyclic,
         interface: Anchor.Domain.GraphRules.Interface,
         layering: Anchor.Domain.GraphRules.Layering,
         max_file_length: Anchor.Domain.Checks.MaxFileLength,
         module_pattern_restrictions: Anchor.Domain.Checks.ModulePatternRestrictions,
         must_use_module: Anchor.Domain.Checks.MustUseModule,
         no_comparison_in_if: Anchor.Domain.Checks.NoComparisonInIf,
         no_direct_dependency: Anchor.Domain.Checks.NoDependency,
         no_discarded_pure_expression: Anchor.Domain.Checks.NoDiscardedPureExpression,
         no_discarding_arrow_in_with: Anchor.Domain.Checks.NoDiscardingArrowInWith,
         no_forwarding_function: Anchor.Domain.Checks.NoForwardingFunction,
         no_transitive_dependency: Anchor.Domain.Checks.NoTransitiveDependency,
         no_tuple_match_in_head: Anchor.Domain.Checks.NoTupleMatchInHead,
         single_control_flow: Anchor.Domain.Checks.SingleControlFlow,
         struct_getter_convention: Anchor.Domain.Checks.StructGetterConvention
       },
       type
     )-

     code: shape = RuleShapes.for(rule)
     stacktrace:
       (anchor 0.1.0) lib/anchor/domain/rule_shapes.ex:52: Anchor.Domain.RuleShapes.for/1
       test/anchor/domain/fix_shape_invariant_test.exs:141: (test)

.............
```

## RS-E — one check (must_use_module) drops its Fix suffix

Run summary: `39 tests, 4 failures`

```text
  1) test detect_violations/2 flags a module missing a required use (message/trigger/line) (Anchor.Domain.Checks.MustUseModuleTest)
     test/anchor/domain/checks/must_use_module_test.exs:17
     Assertion with == failed
     code:  assert violation.message ==
              "Module must use MyApp.Schema" <> ". Fix: use MyApp.Schema in the module's own defmodule body"
     left:  "Module must use MyApp.Schema"
     right: "Module must use MyApp.Schema. Fix: use MyApp.Schema in the module's own defmodule body"
     stacktrace:
       test/anchor/domain/checks/must_use_module_test.exs:28: (test)

......

  2) test check_file/3 one of two required modules present flags only the missing one (Anchor.Check.MustUseModuleTest)
     test/anchor/check/must_use_module_test.exs:71
     Assertion with == failed
     code:  assert issue.message ==
              "Module must use MyApp.Base" <>
                ". Fix: use MyApp.Schema, MyApp.Base in the module's own defmodule body"
     left:  "Module must use MyApp.Base"
     right: "Module must use MyApp.Base. Fix: use MyApp.Schema, MyApp.Base in the module's own defmodule body"
     stacktrace:
       test/anchor/check/must_use_module_test.exs:82: (test)

.

  3) test check_file/3 flags a module missing a required use (Anchor.Check.MustUseModuleTest)
     test/anchor/check/must_use_module_test.exs:26
     Assertion with == failed
     code:  assert issue.message ==
              "Module must use MyApp.Schema" <> ". Fix: use MyApp.Schema in the module's own defmodule body"
     left:  "Module must use MyApp.Schema"
     right: "Module must use MyApp.Schema. Fix: use MyApp.Schema in the module's own defmodule body"
     stacktrace:
       test/anchor/check/must_use_module_test.exs:35: (test)

.........

  4) test must_use_module: its canonical violation ends with exactly one Fix:, its rule's shape (Anchor.Domain.FixShapeInvariantTest)
     test/anchor/domain/fix_shape_invariant_test.exs:137
     Module must use MyApp.Base
     code: for violation <- violations do
     stacktrace:
       test/anchor/domain/fix_shape_invariant_test.exs:147: anonymous fn/2 in Anchor.Domain.FixShapeInvariantTest."test must_use_module: its canonical violation ends with exactly one Fix:, its rule's shape"/1
       (elixir 1.19.4) lib/enum.ex:1688: Enum."-map/2-lists^map/1-1-"/2
       test/anchor/domain/fix_shape_invariant_test.exs:146: (test)

..............
```

## RS-F — one check (case_on_bare_arg) drops its Fix suffix

Run summary: `32 tests, 2 failures`

```text
  1) test check_file/3 flags case directly on a bare argument (Anchor.Check.CaseOnBareArgTest)
     test/anchor/check/case_on_bare_arg_test.exs:25
     Assertion with == failed
     code:  assert issue.message ==
              "Case statement operates on bare argument `status` in function `process`. Consider using function head pattern matching instead." <>
                " Fix: match the argument in the function heads, one clause per case branch, instead of a case on the bare argument"
     left:  "Case statement operates on bare argument `status` in function `process`. Consider using function head pattern matching instead."
     right: "Case statement operates on bare argument `status` in function `process`. Consider using function head pattern matching instead. Fix: match the argument in the function heads, one clause per case branch, instead of a case on the bare argument"
     stacktrace:
       test/anchor/check/case_on_bare_arg_test.exs:39: (test)

..........

  2) test case_on_bare_arg: its canonical violation ends with exactly one Fix:, its rule's shape (Anchor.Domain.FixShapeInvariantTest)
     test/anchor/domain/fix_shape_invariant_test.exs:137
     Case statement operates on bare argument `x` in function `f`. Consider using function head pattern matching instead.
     code: for violation <- violations do
     stacktrace:
       test/anchor/domain/fix_shape_invariant_test.exs:147: anonymous fn/2 in Anchor.Domain.FixShapeInvariantTest."test case_on_bare_arg: its canonical violation ends with exactly one Fix:, its rule's shape"/1
       (elixir 1.19.4) lib/enum.ex:1688: Enum."-map/2-lists^map/1-1-"/2
       test/anchor/domain/fix_shape_invariant_test.exs:146: (test)

........
```

## FA-A — the generic Fix is appended even when the reason has its own (two Fix:)

Run summary: `84 tests, 29 failures`

```text
  1) test one Fix: per rejected config each moved load refusal keeps its own Fix, and only it (Anchor.Domain.FailuresTest)
     test/anchor/domain/failures_test.exs:286
     Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `owned_namespaces: []` checks no struct. Fix: list module names, e.g. ["MyApp"], or leave owned_namespaces out to check every struct. Fix: correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     code: for {reason, fix} <- [
     stacktrace:
       test/anchor/domain/failures_test.exs:297: anonymous fn/2 in Anchor.Domain.FailuresTest."test one Fix: per rejected config each moved load refusal keeps its own Fix, and only it"/1
       (elixir 1.19.4) lib/enum.ex:2520: Enum."-reduce/3-lists^foldl/2-0-"/3
       test/anchor/domain/failures_test.exs:287: (test)

.....

  2) test struct_owned_by_module: every rule that checks nothing is refused, and the positive rows load (Anchor.Domain.RuleChecksNothingTest)
     test/anchor/domain/rule_checks_nothing_test.exs:48
     struct_owned_by_module / owned_namespaces: [] checks no struct: the issue carries 2 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `owned_namespaces: []` checks no struct. Fix: list module names, e.g. ["MyApp"], or leave owned_namespaces out to check every struct. Fix: correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     struct_owned_by_module / an owned_namespaces glob: the issue carries 2 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `owned_namespaces` entry "App.*" is not an exact Elixir module name (a glob, an Erlang module or a malformed name). Fix: list module names, e.g. ["MyApp"]. Fix: correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     struct_owned_by_module / an owned_namespaces Erlang module: the issue carries 2 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `owned_namespaces` entry ":app" is not an exact Elixir module name (a glob, an Erlang module or a malformed name). Fix: list module names, e.g. ["MyApp"]. Fix: correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     struct_owned_by_module / a malformed owned_namespaces entry after a valid one: the issue carries 2 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `owned_namespaces` entry "app.core" is not an exact Elixir module name (a glob, an Erlang module or a malformed name). Fix: list module names, e.g. ["MyApp"]. Fix: correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     code: assert failures == [], Enum.join(failures, "\n")
     stacktrace:
       test/anchor/domain/rule_checks_nothing_test.exs:54: (test)

...............

  3) test no_discarded_pure_expression: every rule that checks nothing is refused, and the positive rows load (Anchor.Domain.RuleChecksNothingTest)
     test/anchor/domain/rule_checks_nothing_test.exs:48
     no_discarded_pure_expression / pure_patterns: ["*"] declares every module pure: the issue carries 2 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `pure_patterns` entry "*" declares every module pure, so every call would read as having no effect. Fix: name the pure namespaces, e.g. ["MyApp.*.Domain.*"]. Fix: correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     no_discarded_pure_expression / pure_patterns: ["**"] declares every module pure: the issue carries 2 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `pure_patterns` entry "**" declares every module pure, so every call would read as having no effect. Fix: name the pure namespaces, e.g. ["MyApp.*.Domain.*"]. Fix: correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     code: assert failures == [], Enum.join(failures, "\n")
     stacktrace:
       test/anchor/domain/rule_checks_nothing_test.exs:54: (test)

.

  4) test extract_pure_regions_from: every refusal is refused with its key path and Fix:, positives load (Anchor.Domain.ArchitectureChecksNothingTest)
     test/anchor/domain/architecture_checks_nothing_test.exs:54
     extract_pure_regions_from / services: the issue carries 2 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: architecture.extract_pure_regions_from[1] is not a role, got: "services". Fix: use one of: adapters, domain, framework, managers, ui. Fix: correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     extract_pure_regions_from / not a list: the issue carries 2 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: architecture.extract_pure_regions_from must be a list of roles, got: "managers". Fix: list roles from: adapters, domain, framework, managers, ui ([] for none). Fix: correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     code: assert failures == [], Enum.join(failures, "\n")
     stacktrace:
       test/anchor/domain/architecture_checks_nothing_test.exs:59: (test)

  5) test contexts: every refusal is refused with its key path and Fix:, positives load (Anchor.Domain.ArchitectureChecksNothingTest)
     test/anchor/domain/architecture_checks_nothing_test.exs:54
     contexts / missing: the issue carries 2 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: architecture.contexts is missing. Fix: add contexts: {depth: N}. Fix: correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     contexts / not a mapping: the issue carries 2 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: architecture.contexts is not a mapping, got: 2. Fix: write it as contexts: {depth: N}. Fix: correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     contexts / unknown key dept: the issue carries 2 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: architecture.contexts has unknown key(s) "dept". Fix: remove or correct them; the keys of architecture.contexts are: depth. Fix: correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     code: assert failures == [], Enum.join(failures, "\n")
     stacktrace:
       test/anchor/domain/architecture_checks_nothing_test.exs:59: (test)

  6) test roots[].behaviour: every refusal is refused with its key path and Fix:, positives load (Anchor.Domain.ArchitectureChecksNothingTest)
     test/anchor/domain/architecture_checks_nothing_test.exs:54
     roots[].behaviour / blank: the issue carries 2 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: architecture.roots[0].behaviour must name one behaviour module exactly, got: "". Fix: name the behaviour, e.g. Supervisor or :gen_server. Fix: correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     roots[].behaviour / a glob: the issue carries 2 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: architecture.roots[0].behaviour must name one behaviour module exactly, got: "MyApp.*". Fix: name the behaviour, e.g. Supervisor or :gen_server. Fix: correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     roots[].behaviour / a bare colon: the issue carries 2 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: architecture.roots[0].behaviour must name one behaviour module exactly, got: ":". Fix: name the behaviour, e.g. Supervisor or :gen_server. Fix: correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     roots[].behaviour / not a string: the issue carries 2 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: architecture.roots[0].behaviour must name one behaviour module exactly, got: 1. Fix: name the behaviour, e.g. Supervisor or :gen_server. Fix: correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     code: assert failures == [], Enum.join(failures, "\n")
     stacktrace:
       test/anchor/domain/architecture_checks_nothing_test.exs:59: (test)

  7) test buckets[].select[].uses_module: every refusal is refused with its key path and Fix:, positives load (Anchor.Domain.ArchitectureChecksNothingTest)
     test/anchor/domain/architecture_checks_nothing_test.exs:54
     buckets[].select[].uses_module / blank: the issue carries 2 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: architecture.buckets[0].select[0].uses_module must name one Elixir module exactly, got: "". Fix: name the module the bucket's modules `use`, e.g. GenServer. Fix: correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     buckets[].select[].uses_module / a glob: the issue carries 2 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: architecture.buckets[0].select[0].uses_module must name one Elixir module exactly, got: "MyApp.*". Fix: name the module the bucket's modules `use`, e.g. GenServer. Fix: correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     buckets[].select[].uses_module / an Erlang module: the issue carries 2 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: architecture.buckets[0].select[0].uses_module must name one Elixir module exactly, got: ":gen_server". Fix: name the module the bucket's modules `use`, e.g. GenServer. Fix: correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     code: assert failures == [], Enum.join(failures, "\n")
     stacktrace:
       test/anchor/domain/architecture_checks_nothing_test.exs:59: (test)

  8) test interfaces.exports: every refusal is refused with its key path and Fix:, positives load (Anchor.Domain.ArchitectureChecksNothingTest)
     test/anchor/domain/architecture_checks_nothing_test.exs:54
     interfaces.exports / a glob: the issue carries 2 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: architecture.interfaces.exports[0] "MyApp.*" is not one exact Elixir module name (a glob, an Erlang module and a blank are refused). Fix: name the module exactly, as its defmodule spells it, e.g. MyApp.Accounts.Api. Fix: correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     interfaces.exports / a match-all glob: the issue carries 2 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: architecture.interfaces.exports[0] "*" is not one exact Elixir module name (a glob, an Erlang module and a blank are refused). Fix: name the module exactly, as its defmodule spells it, e.g. MyApp.Accounts.Api. Fix: correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     interfaces.exports / an Erlang module: the issue carries 2 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: architecture.interfaces.exports[0] ":ets" is not one exact Elixir module name (a glob, an Erlang module and a blank are refused). Fix: name the module exactly, as its defmodule spells it, e.g. MyApp.Accounts.Api. Fix: correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     interfaces.exports / blank: the issue carries 2 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: architecture.interfaces.exports[1] "  " is not one exact Elixir module name (a glob, an Erlang module and a blank are refused). Fix: name the module exactly, as its defmodule spells it, e.g. MyApp.Accounts.Api. Fix: correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     interfaces.exports / lower case: the issue carries 2 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: architecture.interfaces.exports[0] "myapp.accounts" is not one exact Elixir module name (a glob, an Erlang module and a blank are refused). Fix: name the module exactly, as its defmodule spells it, e.g. MyApp.Accounts.Api. Fix: correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     interfaces.exports / not a list: the issue carries 2 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: architecture.interfaces.exports must be a list of module names, got: "MyApp.Accounts". Fix: list each extra interface module by its exact name, e.g. [MyApp.Accounts.Api]. Fix: correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     code: assert failures == [], Enum.join(failures, "\n")
     stacktrace:
       test/anchor/domain/architecture_checks_nothing_test.exs:59: (test)

.

  9) test buckets: every refusal is refused with its key path and Fix:, positives load (Anchor.Domain.ArchitectureChecksNothingTest)
     test/anchor/domain/architecture_checks_nothing_test.exs:54
     buckets / missing: the issue carries 2 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: architecture.buckets is missing (must be a non-empty list of buckets). Fix: list every bucket, each with a name, a role and a select list. Fix: correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     buckets / []: the issue carries 2 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: architecture.buckets must be a non-empty list of buckets, got: []. Fix: list every bucket, each with a name, a role and a select list. Fix: correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     buckets / not a list: the issue carries 2 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: architecture.buckets must be a non-empty list of buckets, got: %{"name" => "domain", "role" => "domain", "select" => [%{"paths" => ["lib/**/domain/**/*.ex"]}]}. Fix: list every bucket, each with a name, a role and a select list. Fix: correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     buckets / an entry that is not a mapping: the issue carries 2 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: architecture.buckets[0] is not a mapping, got: "domain". Fix: write each bucket as a mapping with name, role and select. Fix: correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     buckets / unknown bucket key: the issue carries 2 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: architecture.buckets[0] has unknown key(s) "selct". Fix: remove or correct them; the keys of architecture.buckets[0] are: infer, min_modules, name, role, select. Fix: correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     code: assert failures == [], Enum.join(failures, "\n")
     stacktrace:
       test/anchor/domain/architecture_checks_nothing_test.exs:59: (test)



 10) test buckets[].select[].exports_function: every refusal is refused with its key path and Fix:, positives load (Anchor.Domain.ArchitectureChecksNothingTest)
     test/anchor/domain/architecture_checks_nothing_test.exs:54
     buckets[].select[].exports_function / no arity: the issue carries 2 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: architecture.buckets[0].select[0].exports_function "run" has no arity. Fix: write the function as "name/arity", e.g. "__aggregate__/0". Fix: correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     buckets[].select[].exports_function / run/x: the issue carries 2 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: architecture.buckets[0].select[0].exports_function "run/x" has "x", which is not an arity (0 to 255). Fix: write the function as "name/arity", e.g. "__aggregate__/0". Fix: correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     buckets[].select[].exports_function / a module-qualified name: the issue carries 2 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: architecture.buckets[0].select[0].exports_function "Mod.run/1" has "Mod.run", which is not a function name. Fix: write the function as "name/arity", e.g. "__aggregate__/0". Fix: correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     buckets[].select[].exports_function / not a string: the issue carries 2 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: architecture.buckets[0].select[0].exports_function must be a string, got: 5. Fix: write the function as "name/arity", e.g. "__aggregate__/0". Fix: correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     code: assert failures == [], Enum.join(failures, "\n")
     stacktrace:
       test/anchor/domain/architecture_checks_nothing_test.exs:59: (test)



 11) test calls: every refusal is refused with its key path and Fix:, positives load (Anchor.Domain.ArchitectureChecksNothingTest)
     test/anchor/domain/architecture_checks_nothing_test.exs:54
     calls / missing: the issue carries 2 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: architecture.calls is missing (must be a mapping with one row per bucket). Fix: add calls: with a row per bucket listing the buckets it may call ([] for none). Fix: correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     calls / not a mapping: the issue carries 2 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: architecture.calls must be a mapping with one row per bucket, got: ["domain"]. Fix: add calls: with a row per bucket listing the buckets it may call ([] for none). Fix: correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     calls / a row for an unknown bucket: the issue carries 2 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: architecture.calls has a row for "ui", which is not a bucket. Fix: remove the row, or add the bucket; buckets: domain, managers. Fix: correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     calls / a bucket with no row: the issue carries 2 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: architecture.calls has no row for bucket "managers". Fix: add calls.managers: [...] listing the buckets managers may call ([] for none). Fix: correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     calls / a null row (YAML `managers:`): the issue carries 2 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: architecture.calls.managers must be a list of buckets, got: nil. Fix: list the buckets it may call, e.g. [domain, "managers:other_context"] ([] for none). Fix: correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     calls / a row that is not a list: the issue carries 2 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: architecture.calls.managers must be a list of buckets, got: "domain". Fix: list the buckets it may call, e.g. [domain, "managers:other_context"] ([] for none). Fix: correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     calls / an unknown target bucket: the issue carries 2 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: architecture.calls.managers[1] names "ui", which is not a bucket. Fix: name one of: domain, managers. Fix: correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     calls / an unknown scope suffix: the issue carries 2 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: architecture.calls.managers[0] names "domain:elsewhere". Fix: the scope suffix is :same_context or :other_context. Fix: correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     calls / a suffix on an unknown bucket: the issue carries 2 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: architecture.calls.managers[0] names "ui", which is not a bucket. Fix: name one of: domain, managers. Fix: correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     calls / a target that is not a string: the issue carries 2 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: architecture.calls.managers[0] is 1, not a bucket name. Fix: write a bucket name as a string. Fix: correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     code: assert failures == [], Enum.join(failures, "\n")
     stacktrace:
       test/anchor/domain/architecture_checks_nothing_test.exs:59: (test)



 12) test roots[].exports_function: every refusal is refused with its key path and Fix:, positives load (Anchor.Domain.ArchitectureChecksNothingTest)
     test/anchor/domain/architecture_checks_nothing_test.exs:54
     roots[].exports_function / no arity: the issue carries 2 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: architecture.roots[0].exports_function "run" has no arity. Fix: write the function as "name/arity", e.g. "__aggregate__/0". Fix: correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     roots[].exports_function / run/x: the issue carries 2 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: architecture.roots[0].exports_function "run/x" has "x", which is not an arity (0 to 255). Fix: write the function as "name/arity", e.g. "__aggregate__/0". Fix: correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     roots[].exports_function / a module-qualified name: the issue carries 2 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: architecture.roots[0].exports_function "Mod.run/1" has "Mod.run", which is not a function name. Fix: write the function as "name/arity", e.g. "__aggregate__/0". Fix: correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     roots[].exports_function / not a string: the issue carries 2 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: architecture.roots[0].exports_function must be a string, got: 5. Fix: write the function as "name/arity", e.g. "__aggregate__/0". Fix: correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     code: assert failures == [], Enum.join(failures, "\n")
     stacktrace:
       test/anchor/domain/architecture_checks_nothing_test.exs:59: (test)

.

 13) test interfaces: every refusal is refused with its key path and Fix:, positives load (Anchor.Domain.ArchitectureChecksNothingTest)
     test/anchor/domain/architecture_checks_nothing_test.exs:54
     interfaces / not a mapping: the issue carries 2 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: architecture.interfaces is not a mapping, got: ["managers"]. Fix: write it as interfaces: {buckets: [...], exports: [...]}. Fix: correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     interfaces / unknown key bucket: the issue carries 2 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: architecture.interfaces has unknown key(s) "bucket". Fix: remove or correct them; the keys of architecture.interfaces are: buckets, exports. Fix: correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     code: assert failures == [], Enum.join(failures, "\n")
     stacktrace:
       test/anchor/domain/architecture_checks_nothing_test.exs:59: (test)



 14) test buckets[].select[].behaviour: every refusal is refused with its key path and Fix:, positives load (Anchor.Domain.ArchitectureChecksNothingTest)
     test/anchor/domain/architecture_checks_nothing_test.exs:54
     buckets[].select[].behaviour / blank: the issue carries 2 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: architecture.buckets[0].select[0].behaviour must name one behaviour module exactly, got: "". Fix: name the behaviour, e.g. Supervisor or :gen_server. Fix: correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     buckets[].select[].behaviour / a glob: the issue carries 2 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: architecture.buckets[0].select[0].behaviour must name one behaviour module exactly, got: "MyApp.*". Fix: name the behaviour, e.g. Supervisor or :gen_server. Fix: correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     buckets[].select[].behaviour / a bare colon: the issue carries 2 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: architecture.buckets[0].select[0].behaviour must name one behaviour module exactly, got: ":". Fix: name the behaviour, e.g. Supervisor or :gen_server. Fix: correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     buckets[].select[].behaviour / not a string: the issue carries 2 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: architecture.buckets[0].select[0].behaviour must name one behaviour module exactly, got: 1. Fix: name the behaviour, e.g. Supervisor or :gen_server. Fix: correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     code: assert failures == [], Enum.join(failures, "\n")
     stacktrace:
       test/anchor/domain/architecture_checks_nothing_test.exs:59: (test)

.

 15) test interfaces.buckets: every refusal is refused with its key path and Fix:, positives load (Anchor.Domain.ArchitectureChecksNothingTest)
     test/anchor/domain/architecture_checks_nothing_test.exs:54
     interfaces.buckets / an unknown bucket: the issue carries 2 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: architecture.interfaces.buckets[1] names "services", which is not a bucket. Fix: name one of: domain, managers. Fix: correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     interfaces.buckets / not a list: the issue carries 2 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: architecture.interfaces.buckets must be a list of bucket names, got: "managers". Fix: list the buckets whose modules are their context's interface, e.g. [managers]. Fix: correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     code: assert failures == [], Enum.join(failures, "\n")
     stacktrace:
       test/anchor/domain/architecture_checks_nothing_test.exs:59: (test)

.

 16) test buckets[].role: every refusal is refused with its key path and Fix:, positives load (Anchor.Domain.ArchitectureChecksNothingTest)
     test/anchor/domain/architecture_checks_nothing_test.exs:54
     buckets[].role / missing: the issue carries 2 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: architecture.buckets[0].role is missing (is not a role). Fix: use one of: adapters, domain, framework, managers, ui. Fix: correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     buckets[].role / service: the issue carries 2 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: architecture.buckets[0].role is not a role, got: "service". Fix: use one of: adapters, domain, framework, managers, ui. Fix: correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     buckets[].role / Domain (case): the issue carries 2 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: architecture.buckets[0].role is not a role, got: "Domain". Fix: use one of: adapters, domain, framework, managers, ui. Fix: correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     code: assert failures == [], Enum.join(failures, "\n")
     stacktrace:
       test/anchor/domain/architecture_checks_nothing_test.exs:59: (test)



 17) test architecture: every refusal is refused with its key path and Fix:, positives load (Anchor.Domain.ArchitectureChecksNothingTest)
     test/anchor/domain/architecture_checks_nothing_test.exs:54
     architecture / architectur: misspelt is an unknown top-level key: the issue carries 2 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: unknown top-level key(s) "architectur"; Fix: remove or correct it; the top-level keys are `architecture`, `rules` and `sabotage`. Fix: correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     architecture / not a mapping: the issue carries 2 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: architecture is not a mapping, got: ["buckets"]. Fix: write architecture: as a mapping with contexts, buckets and calls. Fix: correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     architecture / null: the issue carries 2 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: architecture is not a mapping, got: nil. Fix: write architecture: as a mapping with contexts, buckets and calls. Fix: correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     architecture / unknown key bucket: the issue carries 2 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: architecture has unknown key(s) "bucket". Fix: remove or correct them; the keys of architecture are: buckets, calls, contexts, effects, extract_pure_regions_from, interfaces, roots. Fix: correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     code: assert failures == [], Enum.join(failures, "\n")
     stacktrace:
       test/anchor/domain/architecture_checks_nothing_test.exs:59: (test)

.

 18) test buckets[].select[].paths: every refusal is refused with its key path and Fix:, positives load (Anchor.Domain.ArchitectureChecksNothingTest)
     test/anchor/domain/architecture_checks_nothing_test.exs:54
     buckets[].select[].paths / []: the issue carries 2 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: architecture.buckets[0].select[0].paths must be a non-empty list of non-empty path globs, got: []. Fix: list the source-path globs the bucket holds, e.g. ["lib/**/domain/**/*.ex"]. Fix: correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     buckets[].select[].paths / [""]: the issue carries 2 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: architecture.buckets[0].select[0].paths must be a non-empty list of non-empty path globs, got: [""]. Fix: list the source-path globs the bucket holds, e.g. ["lib/**/domain/**/*.ex"]. Fix: correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     buckets[].select[].paths / a string, not a list: the issue carries 2 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: architecture.buckets[0].select[0].paths must be a non-empty list of non-empty path globs, got: "lib/a.ex". Fix: list the source-path globs the bucket holds, e.g. ["lib/**/domain/**/*.ex"]. Fix: correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     buckets[].select[].paths / a non-string entry: the issue carries 2 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: architecture.buckets[0].select[0].paths must be a non-empty list of non-empty path globs, got: ["lib/a.ex", 1]. Fix: list the source-path globs the bucket holds, e.g. ["lib/**/domain/**/*.ex"]. Fix: correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     buckets[].select[].paths / a match-all ["**"]: the issue carries 2 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: architecture.buckets[0].select[0].paths "**" matches every source file. Fix: give each glob a literal directory or name, e.g. "lib/**/domain/**/*.ex". Fix: correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     buckets[].select[].paths / a match-all **/* beside a real glob: the issue carries 2 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: architecture.buckets[0].select[0].paths "**/*" matches every source file. Fix: give each glob a literal directory or name, e.g. "lib/**/domain/**/*.ex". Fix: correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     buckets[].select[].paths / a match-all *: the issue carries 2 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: architecture.buckets[0].select[0].paths "*" matches every source file. Fix: give each glob a literal directory or name, e.g. "lib/**/domain/**/*.ex". Fix: correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     code: assert failures == [], Enum.join(failures, "\n")
     stacktrace:
       test/anchor/domain/architecture_checks_nothing_test.exs:59: (test)



 19) test buckets[].select: every refusal is refused with its key path and Fix:, positives load (Anchor.Domain.ArchitectureChecksNothingTest)
     test/anchor/domain/architecture_checks_nothing_test.exs:54
     buckets[].select / missing: the issue carries 2 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: architecture.buckets[0].select is missing (must be a non-empty list of selectors). Fix: list at least one selector (behaviour, exports_function, paths, pattern, uses_module). Fix: correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     buckets[].select / []: the issue carries 2 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: architecture.buckets[0].select must be a non-empty list of selectors, got: []. Fix: list at least one selector (behaviour, exports_function, paths, pattern, uses_module). Fix: correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     buckets[].select / not a list: the issue carries 2 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: architecture.buckets[0].select must be a non-empty list of selectors, got: %{"paths" => ["lib/a.ex"]}. Fix: list at least one selector (behaviour, exports_function, paths, pattern, uses_module). Fix: correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     buckets[].select / an entry with no selector key: the issue carries 2 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: architecture.buckets[0].select[0] names no selector. Fix: give it one of: behaviour, exports_function, paths, pattern, uses_module. Fix: correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     buckets[].select / an entry that is not a mapping: the issue carries 2 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: architecture.buckets[0].select[0] is not a mapping, got: "lib/a.ex". Fix: write it as one selector key and its value, e.g. `- pattern: "MyApp.*"`. Fix: correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     buckets[].select / an entry with two selector keys: the issue carries 2 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: architecture.buckets[0].select[0] names 2 selectors (paths, pattern). Fix: split them into one entry each; a module matching any entry is selected. Fix: correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     buckets[].select / an unknown selector key: the issue carries 2 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: architecture.buckets[0].select[0] has unknown key(s) "path". Fix: use exactly one selector key: behaviour, exports_function, paths, pattern, uses_module. Fix: correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     buckets[].select / the second entry is the bad one: the issue carries 2 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: architecture.buckets[0].select[1].pattern "*" matches every module. Fix: write a module-name glob with at least one literal segment, e.g. "MyApp.Domain.*". Fix: correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     code: assert failures == [], Enum.join(failures, "\n")
     stacktrace:
       test/anchor/domain/architecture_checks_nothing_test.exs:59: (test)



 20) test buckets[].name: every refusal is refused with its key path and Fix:, positives load (Anchor.Domain.ArchitectureChecksNothingTest)
     test/anchor/domain/architecture_checks_nothing_test.exs:54
     buckets[].name / missing: the issue carries 2 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: architecture.buckets[0].name is missing (must be lower-case letters and _). Fix: name the bucket, e.g. domain or my_bucket. Fix: correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     buckets[].name / uppercase Domain: the issue carries 2 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: architecture.buckets[0].name must be lower-case letters and _, got: "Domain". Fix: name the bucket, e.g. domain or my_bucket. Fix: correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     buckets[].name / blank: the issue carries 2 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: architecture.buckets[0].name must be lower-case letters and _, got: "". Fix: name the bucket, e.g. domain or my_bucket. Fix: correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     buckets[].name / digits: the issue carries 2 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: architecture.buckets[0].name must be lower-case letters and _, got: "layer2". Fix: name the bucket, e.g. domain or my_bucket. Fix: correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     buckets[].name / duplicate: the issue carries 2 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: architecture.buckets names the bucket "domain" more than once. Fix: give each bucket its own name; a module matching both would be ambiguous. Fix: correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     code: assert failures == [], Enum.join(failures, "\n")
     stacktrace:
       test/anchor/domain/architecture_checks_nothing_test.exs:59: (test)

.

 21) test roots: every refusal is refused with its key path and Fix:, positives load (Anchor.Domain.ArchitectureChecksNothingTest)
     test/anchor/domain/architecture_checks_nothing_test.exs:54
     roots / an entry with two selector keys: the issue carries 2 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: architecture.roots[0] names 2 selectors (paths, pattern). Fix: split them into one entry each; a module matching any entry is selected. Fix: correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     roots / an entry with none: the issue carries 2 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: architecture.roots[0] names no selector. Fix: give it one of: behaviour, exports_function, paths, pattern, uses_module. Fix: correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     roots / not a list: the issue carries 2 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: architecture.roots must be a list of selectors, got: %{"pattern" => "Mix.Tasks.*"}. Fix: list each extra root as one selector entry, e.g. - pattern: "Mix.Tasks.*". Fix: correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     code: assert failures == [], Enum.join(failures, "\n")
     stacktrace:
       test/anchor/domain/architecture_checks_nothing_test.exs:59: (test)

..

 22) test buckets[].infer: every refusal is refused with its key path and Fix:, positives load (Anchor.Domain.ArchitectureChecksNothingTest)
     test/anchor/domain/architecture_checks_nothing_test.exs:54
     buckets[].infer / "yes": the issue carries 2 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: architecture.buckets[0].infer must be true or false, got: "yes". Fix: set it to true or false, or omit it. Fix: correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     buckets[].infer / null: the issue carries 2 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: architecture.buckets[0].infer is missing (must be true or false). Fix: set it to true or false, or omit it. Fix: correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     code: assert failures == [], Enum.join(failures, "\n")
     stacktrace:
       test/anchor/domain/architecture_checks_nothing_test.exs:59: (test)



 23) test roots[].pattern: every refusal is refused with its key path and Fix:, positives load (Anchor.Domain.ArchitectureChecksNothingTest)
     test/anchor/domain/architecture_checks_nothing_test.exs:54
     roots[].pattern / a match-all *: the issue carries 2 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: architecture.roots[0].pattern "*" matches every module. Fix: write a module-name glob with at least one literal segment, e.g. "MyApp.Domain.*". Fix: correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     roots[].pattern / a match-all **: the issue carries 2 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: architecture.roots[0].pattern "**" matches every module. Fix: write a module-name glob with at least one literal segment, e.g. "MyApp.Domain.*". Fix: correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     roots[].pattern / a match-all *.*: the issue carries 2 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: architecture.roots[0].pattern "*.*" matches every module. Fix: write a module-name glob with at least one literal segment, e.g. "MyApp.Domain.*". Fix: correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     roots[].pattern / blank: the issue carries 2 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: architecture.roots[0].pattern must be a non-empty module-name glob, got: "". Fix: write a module-name glob with at least one literal segment, e.g. "MyApp.Domain.*". Fix: correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     roots[].pattern / not a string: the issue carries 2 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: architecture.roots[0].pattern must be a non-empty module-name glob, got: ["A.*"]. Fix: write a module-name glob with at least one literal segment, e.g. "MyApp.Domain.*". Fix: correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     code: assert failures == [], Enum.join(failures, "\n")
     stacktrace:
       test/anchor/domain/architecture_checks_nothing_test.exs:59: (test)



 24) test roots[].uses_module: every refusal is refused with its key path and Fix:, positives load (Anchor.Domain.ArchitectureChecksNothingTest)
     test/anchor/domain/architecture_checks_nothing_test.exs:54
     roots[].uses_module / blank: the issue carries 2 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: architecture.roots[0].uses_module must name one Elixir module exactly, got: "". Fix: name the module the bucket's modules `use`, e.g. GenServer. Fix: correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     roots[].uses_module / a glob: the issue carries 2 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: architecture.roots[0].uses_module must name one Elixir module exactly, got: "MyApp.*". Fix: name the module the bucket's modules `use`, e.g. GenServer. Fix: correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     roots[].uses_module / an Erlang module: the issue carries 2 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: architecture.roots[0].uses_module must name one Elixir module exactly, got: ":gen_server". Fix: name the module the bucket's modules `use`, e.g. GenServer. Fix: correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     code: assert failures == [], Enum.join(failures, "\n")
     stacktrace:
       test/anchor/domain/architecture_checks_nothing_test.exs:59: (test)

.

 25) test effects: every refusal is refused with its key path and Fix:, positives load (Anchor.Domain.ArchitectureChecksNothingTest)
     test/anchor/domain/architecture_checks_nothing_test.exs:54
     effects / "Req.": the issue carries 2 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: architecture.effects[0] names no module or function: "Req." is not a function reference: it names no function; write each entry as "Module.function" or "Module.function/arity" (e.g. "MyApp.Repo.insert/2", ":ets.insert"). Fix: write a module ("Req", ":gen_tcp") or a function ("File.write!/2", ":gen_tcp.connect"). Fix: correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     effects / "Mod.fun/x": the issue carries 2 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: architecture.effects[1] names no module or function: "Mod.fun/x" is not a function reference: it has "x", which is not an arity (0 to 255); write each entry as "Module.function" or "Module.function/arity" (e.g. "MyApp.Repo.insert/2", ":ets.insert"). Fix: write a module ("Req", ":gen_tcp") or a function ("File.write!/2", ":gen_tcp.connect"). Fix: correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     effects / blank: the issue carries 2 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: architecture.effects[0] names no module or function: "" is not a function reference: it names no module; write each entry as "Module.function" or "Module.function/arity" (e.g. "MyApp.Repo.insert/2", ":ets.insert"). Fix: write a module ("Req", ":gen_tcp") or a function ("File.write!/2", ":gen_tcp.connect"). Fix: correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     effects / a glob: the issue carries 2 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: architecture.effects[0] names no module or function: "Req.*" is not a function reference: it has "*", which is not a function name; write each entry as "Module.function" or "Module.function/arity" (e.g. "MyApp.Repo.insert/2", ":ets.insert"). Fix: write a module ("Req", ":gen_tcp") or a function ("File.write!/2", ":gen_tcp.connect"). Fix: correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     effects / not a string: the issue carries 2 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: architecture.effects[0] is 1, not a string. Fix: write a module ("Req", ":gen_tcp") or a function ("File.write!/2", ":gen_tcp.connect"). Fix: correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     effects / not a list: the issue carries 2 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: architecture.effects must be a list of module or function tokens, got: "Req". Fix: list the extra effect primitives, e.g. ["Req", ":gen_tcp.connect"]. Fix: correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     code: assert failures == [], Enum.join(failures, "\n")
     stacktrace:
       test/anchor/domain/architecture_checks_nothing_test.exs:59: (test)



 26) test contexts.depth: every refusal is refused with its key path and Fix:, positives load (Anchor.Domain.ArchitectureChecksNothingTest)
     test/anchor/domain/architecture_checks_nothing_test.exs:54
     contexts.depth / missing: the issue carries 2 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: architecture.contexts.depth is missing (must be a positive integer). Fix: set it to how many leading module-name segments name a context, e.g. 2. Fix: correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     contexts.depth / 0: the issue carries 2 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: architecture.contexts.depth must be a positive integer, got: 0. Fix: set it to how many leading module-name segments name a context, e.g. 2. Fix: correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     contexts.depth / -1: the issue carries 2 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: architecture.contexts.depth must be a positive integer, got: -1. Fix: set it to how many leading module-name segments name a context, e.g. 2. Fix: correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     contexts.depth / "2": the issue carries 2 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: architecture.contexts.depth must be a positive integer, got: "2". Fix: set it to how many leading module-name segments name a context, e.g. 2. Fix: correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     contexts.depth / 1.5: the issue carries 2 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: architecture.contexts.depth must be a positive integer, got: 1.5. Fix: set it to how many leading module-name segments name a context, e.g. 2. Fix: correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     code: assert failures == [], Enum.join(failures, "\n")
     stacktrace:
       test/anchor/domain/architecture_checks_nothing_test.exs:59: (test)



 27) test buckets[].min_modules: every refusal is refused with its key path and Fix:, positives load (Anchor.Domain.ArchitectureChecksNothingTest)
     test/anchor/domain/architecture_checks_nothing_test.exs:54
     buckets[].min_modules / 0: the issue carries 2 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: architecture.buckets[0].min_modules must be a positive integer, got: 0. Fix: a floor is a positive integer; omit it for the default 1. Fix: correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     buckets[].min_modules / -3: the issue carries 2 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: architecture.buckets[0].min_modules must be a positive integer, got: -3. Fix: a floor is a positive integer; omit it for the default 1. Fix: correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     buckets[].min_modules / "5": the issue carries 2 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: architecture.buckets[0].min_modules must be a positive integer, got: "5". Fix: a floor is a positive integer; omit it for the default 1. Fix: correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     buckets[].min_modules / null: the issue carries 2 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: architecture.buckets[0].min_modules is missing (must be a positive integer). Fix: a floor is a positive integer; omit it for the default 1. Fix: correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     code: assert failures == [], Enum.join(failures, "\n")
     stacktrace:
       test/anchor/domain/architecture_checks_nothing_test.exs:59: (test)



 28) test roots[].paths: every refusal is refused with its key path and Fix:, positives load (Anchor.Domain.ArchitectureChecksNothingTest)
     test/anchor/domain/architecture_checks_nothing_test.exs:54
     roots[].paths / []: the issue carries 2 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: architecture.roots[0].paths must be a non-empty list of non-empty path globs, got: []. Fix: list the source-path globs the bucket holds, e.g. ["lib/**/domain/**/*.ex"]. Fix: correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     roots[].paths / [""]: the issue carries 2 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: architecture.roots[0].paths must be a non-empty list of non-empty path globs, got: [""]. Fix: list the source-path globs the bucket holds, e.g. ["lib/**/domain/**/*.ex"]. Fix: correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     roots[].paths / a string, not a list: the issue carries 2 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: architecture.roots[0].paths must be a non-empty list of non-empty path globs, got: "lib/a.ex". Fix: list the source-path globs the bucket holds, e.g. ["lib/**/domain/**/*.ex"]. Fix: correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     roots[].paths / a non-string entry: the issue carries 2 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: architecture.roots[0].paths must be a non-empty list of non-empty path globs, got: ["lib/a.ex", 1]. Fix: list the source-path globs the bucket holds, e.g. ["lib/**/domain/**/*.ex"]. Fix: correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     roots[].paths / a match-all ["**"]: the issue carries 2 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: architecture.roots[0].paths "**" matches every source file. Fix: give each glob a literal directory or name, e.g. "lib/**/domain/**/*.ex". Fix: correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     roots[].paths / a match-all **/* beside a real glob: the issue carries 2 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: architecture.roots[0].paths "**/*" matches every source file. Fix: give each glob a literal directory or name, e.g. "lib/**/domain/**/*.ex". Fix: correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     roots[].paths / a match-all *: the issue carries 2 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: architecture.roots[0].paths "*" matches every source file. Fix: give each glob a literal directory or name, e.g. "lib/**/domain/**/*.ex". Fix: correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     code: assert failures == [], Enum.join(failures, "\n")
     stacktrace:
       test/anchor/domain/architecture_checks_nothing_test.exs:59: (test)



 29) test buckets[].select[].pattern: every refusal is refused with its key path and Fix:, positives load (Anchor.Domain.ArchitectureChecksNothingTest)
     test/anchor/domain/architecture_checks_nothing_test.exs:54
     buckets[].select[].pattern / a match-all *: the issue carries 2 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: architecture.buckets[0].select[0].pattern "*" matches every module. Fix: write a module-name glob with at least one literal segment, e.g. "MyApp.Domain.*". Fix: correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     buckets[].select[].pattern / a match-all **: the issue carries 2 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: architecture.buckets[0].select[0].pattern "**" matches every module. Fix: write a module-name glob with at least one literal segment, e.g. "MyApp.Domain.*". Fix: correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     buckets[].select[].pattern / a match-all *.*: the issue carries 2 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: architecture.buckets[0].select[0].pattern "*.*" matches every module. Fix: write a module-name glob with at least one literal segment, e.g. "MyApp.Domain.*". Fix: correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     buckets[].select[].pattern / blank: the issue carries 2 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: architecture.buckets[0].select[0].pattern must be a non-empty module-name glob, got: "". Fix: write a module-name glob with at least one literal segment, e.g. "MyApp.Domain.*". Fix: correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     buckets[].select[].pattern / not a string: the issue carries 2 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: architecture.buckets[0].select[0].pattern must be a non-empty module-name glob, got: ["A.*"]. Fix: write a module-name glob with at least one literal segment, e.g. "MyApp.Domain.*". Fix: correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     code: assert failures == [], Enum.join(failures, "\n")
     stacktrace:
       test/anchor/domain/architecture_checks_nothing_test.exs:59: (test)

.
```

## FA-B — a reason with no Fix gets none

Run summary: `84 tests, 21 failures`

```text
  1) test one Fix: per rejected config a reason with no Fix gets the generic one, once (Anchor.Domain.FailuresTest)
     test/anchor/domain/failures_test.exs:277
     Assertion with =~ failed
     code:  assert message =~ ~s|rule 2: unknown rule type "x". Fix: correct .anchor.yml to match |
     left:  "Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 2: unknown rule type \"x\". correct .anchor.yml to match the README section \"Config schema: rule keys at a glance\" and its table \"Keys each rule type accepts\"."
     right: "rule 2: unknown rule type \"x\". Fix: correct .anchor.yml to match "
     stacktrace:
       test/anchor/domain/failures_test.exs:280: (test)

...........

  2) test config_violation/1 an invalid document carries the validation message (Anchor.Domain.FailuresTest)
     test/anchor/domain/failures_test.exs:59
     Assertion with =~ failed
     code:  assert violation.message =~ "Fix:"
     left:  "Anchor rejected /p/.anchor.yml, so no Anchor rule was checked: no `rules:` list. correct /p/.anchor.yml to match the README section \"Config schema: rule keys at a glance\" and its table \"Keys each rule type accepts\"."
     right: "Fix:"
     stacktrace:
       test/anchor/domain/failures_test.exs:66: (test)

..

  3) test config_violation/1 an invalid rule carries the validation message (Anchor.Domain.FailuresTest)
     test/anchor/domain/failures_test.exs:48
     Assertion with =~ failed
     code:  assert violation.message =~ "Fix:"
     left:  "Anchor rejected /p/.anchor.yml, so no Anchor rule was checked: rule 2: unknown rule type \"x\". correct /p/.anchor.yml to match the README section \"Config schema: rule keys at a glance\" and its table \"Keys each rule type accepts\"."
     right: "Fix:"
     stacktrace:
       test/anchor/domain/failures_test.exs:56: (test)

.

  4) test module_pattern_restrictions: every rule that checks nothing is refused, and the positive rows load (Anchor.Domain.RuleChecksNothingTest)
     test/anchor/domain/rule_checks_nothing_test.exs:48
     module_pattern_restrictions / no selector: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: the rule has no selector, so it would select no file; give it one of: paths (a non-empty list of path globs), pattern (a module-name glob), uses_module (a module the file uses). correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     module_pattern_restrictions / paths: [] alone: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: the rule has no selector, so it would select no file; give it one of: paths (a non-empty list of path globs), pattern (a module-name glob), uses_module (a module the file uses). correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     module_pattern_restrictions / paths and pattern (only paths was read): the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: the rule has more than one selector (paths, pattern), but only the first is read (paths, then pattern, then uses_module); keep exactly one. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     module_pattern_restrictions / pattern and uses_module (only pattern was read): the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: the rule has more than one selector (pattern, uses_module), but only the first is read (paths, then pattern, then uses_module); keep exactly one. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     module_pattern_restrictions / recursive without paths (read by nothing): the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `recursive` applies only to `paths`, and the rule selects by pattern, so nothing reads it; remove `recursive`, or select by `paths`. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     module_pattern_restrictions / recursive that is not a boolean: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `recursive` must be true or false, got: "yes". correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     module_pattern_restrictions / min_files: 0 (no floor): the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `min_files` must be a positive integer (the fewest files the rule must select), got: 0. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     module_pattern_restrictions / min_files that is not an integer: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `min_files` must be a positive integer (the fewest files the rule must select), got: "2". correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     module_pattern_restrictions / an empty id: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `id` must be a non-empty string, got: "". correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     module_pattern_restrictions / an id that is not a string: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `id` must be a non-empty string, got: 7. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     module_pattern_restrictions / enforcement: warn (neither): the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `enforcement` must be report or enforce, got: "warn". correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     module_pattern_restrictions / baseline on an ast rule (nothing reads it): the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `baseline` is read by graph rules only (mix anchor.graph); an ast rule's findings are not compared with a baseline yet, so it would ratchet nothing; remove `baseline`, and use `enforcement: report` while the rule's findings are being fixed. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     module_pattern_restrictions / bucket on an ast rule (a graph selector): the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: unknown key "bucket" in a module_pattern_restrictions rule (`bucket` applies to graph rules only); known keys for module_pattern_restrictions: allowed_functions, enforcement, id, min_files, paths, pattern, recursive, type, uses_module. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     module_pattern_restrictions / allowed_functions: ["*"] allows every function: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `allowed_functions` entry "*" allows every function, so the rule checks nothing; list the functions the module may define, or remove the rule. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     module_pattern_restrictions / allowed_functions: ["**"] allows every function: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `allowed_functions` entry "**" allows every function, so the rule checks nothing; list the functions the module may define, or remove the rule. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     module_pattern_restrictions / allowed_functions: ["***"] allows every function: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `allowed_functions` entry "***" allows every function, so the rule checks nothing; list the functions the module may define, or remove the rule. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     module_pattern_restrictions / allowed_functions that is a string: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `allowed_functions` must be a list of non-empty strings, got: "new". correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     module_pattern_restrictions / allowed_functions of empty strings: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `allowed_functions` must be a list of non-empty strings, got: [""]. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     code: assert failures == [], Enum.join(failures, "\n")
     stacktrace:
       test/anchor/domain/rule_checks_nothing_test.exs:54: (test)

  5) test struct_getter_convention: every rule that checks nothing is refused, and the positive rows load (Anchor.Domain.RuleChecksNothingTest)
     test/anchor/domain/rule_checks_nothing_test.exs:48
     struct_getter_convention / no selector: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: the rule has no selector, so it would select no file; give it one of: paths (a non-empty list of path globs), pattern (a module-name glob), uses_module (a module the file uses). correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     struct_getter_convention / paths: [] alone: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: the rule has no selector, so it would select no file; give it one of: paths (a non-empty list of path globs), pattern (a module-name glob), uses_module (a module the file uses). correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     struct_getter_convention / paths and pattern (only paths was read): the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: the rule has more than one selector (paths, pattern), but only the first is read (paths, then pattern, then uses_module); keep exactly one. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     struct_getter_convention / pattern and uses_module (only pattern was read): the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: the rule has more than one selector (pattern, uses_module), but only the first is read (paths, then pattern, then uses_module); keep exactly one. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     struct_getter_convention / recursive without paths (read by nothing): the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `recursive` applies only to `paths`, and the rule selects by pattern, so nothing reads it; remove `recursive`, or select by `paths`. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     struct_getter_convention / recursive that is not a boolean: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `recursive` must be true or false, got: "yes". correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     struct_getter_convention / min_files: 0 (no floor): the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `min_files` must be a positive integer (the fewest files the rule must select), got: 0. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     struct_getter_convention / min_files that is not an integer: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `min_files` must be a positive integer (the fewest files the rule must select), got: "2". correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     struct_getter_convention / an empty id: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `id` must be a non-empty string, got: "". correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     struct_getter_convention / an id that is not a string: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `id` must be a non-empty string, got: 7. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     struct_getter_convention / enforcement: warn (neither): the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `enforcement` must be report or enforce, got: "warn". correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     struct_getter_convention / baseline on an ast rule (nothing reads it): the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `baseline` is read by graph rules only (mix anchor.graph); an ast rule's findings are not compared with a baseline yet, so it would ratchet nothing; remove `baseline`, and use `enforcement: report` while the rule's findings are being fixed. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     struct_getter_convention / bucket on an ast rule (a graph selector): the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: unknown key "bucket" in a struct_getter_convention rule (`bucket` applies to graph rules only); known keys for struct_getter_convention: enforcement, id, min_files, paths, pattern, recursive, type, uses_module. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     code: assert failures == [], Enum.join(failures, "\n")
     stacktrace:
       test/anchor/domain/rule_checks_nothing_test.exs:54: (test)

.

  6) test no_tuple_match_in_head: every rule that checks nothing is refused, and the positive rows load (Anchor.Domain.RuleChecksNothingTest)
     test/anchor/domain/rule_checks_nothing_test.exs:48
     no_tuple_match_in_head / no selector: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: the rule has no selector, so it would select no file; give it one of: paths (a non-empty list of path globs), pattern (a module-name glob), uses_module (a module the file uses). correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     no_tuple_match_in_head / paths: [] alone: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: the rule has no selector, so it would select no file; give it one of: paths (a non-empty list of path globs), pattern (a module-name glob), uses_module (a module the file uses). correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     no_tuple_match_in_head / paths and pattern (only paths was read): the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: the rule has more than one selector (paths, pattern), but only the first is read (paths, then pattern, then uses_module); keep exactly one. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     no_tuple_match_in_head / pattern and uses_module (only pattern was read): the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: the rule has more than one selector (pattern, uses_module), but only the first is read (paths, then pattern, then uses_module); keep exactly one. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     no_tuple_match_in_head / recursive without paths (read by nothing): the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `recursive` applies only to `paths`, and the rule selects by pattern, so nothing reads it; remove `recursive`, or select by `paths`. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     no_tuple_match_in_head / recursive that is not a boolean: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `recursive` must be true or false, got: "yes". correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     no_tuple_match_in_head / min_files: 0 (no floor): the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `min_files` must be a positive integer (the fewest files the rule must select), got: 0. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     no_tuple_match_in_head / min_files that is not an integer: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `min_files` must be a positive integer (the fewest files the rule must select), got: "2". correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     no_tuple_match_in_head / an empty id: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `id` must be a non-empty string, got: "". correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     no_tuple_match_in_head / an id that is not a string: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `id` must be a non-empty string, got: 7. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     no_tuple_match_in_head / enforcement: warn (neither): the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `enforcement` must be report or enforce, got: "warn". correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     no_tuple_match_in_head / baseline on an ast rule (nothing reads it): the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `baseline` is read by graph rules only (mix anchor.graph); an ast rule's findings are not compared with a baseline yet, so it would ratchet nothing; remove `baseline`, and use `enforcement: report` while the rule's findings are being fixed. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     no_tuple_match_in_head / bucket on an ast rule (a graph selector): the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: unknown key "bucket" in a no_tuple_match_in_head rule (`bucket` applies to graph rules only); known keys for no_tuple_match_in_head: enforcement, id, min_files, paths, pattern, recursive, type, uses_module. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     code: assert failures == [], Enum.join(failures, "\n")
     stacktrace:
       test/anchor/domain/rule_checks_nothing_test.exs:54: (test)

..

  7) test no_discarding_arrow_in_with: every rule that checks nothing is refused, and the positive rows load (Anchor.Domain.RuleChecksNothingTest)
     test/anchor/domain/rule_checks_nothing_test.exs:48
     no_discarding_arrow_in_with / no selector: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: the rule has no selector, so it would select no file; give it one of: paths (a non-empty list of path globs), pattern (a module-name glob), uses_module (a module the file uses). correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     no_discarding_arrow_in_with / paths: [] alone: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: the rule has no selector, so it would select no file; give it one of: paths (a non-empty list of path globs), pattern (a module-name glob), uses_module (a module the file uses). correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     no_discarding_arrow_in_with / paths and pattern (only paths was read): the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: the rule has more than one selector (paths, pattern), but only the first is read (paths, then pattern, then uses_module); keep exactly one. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     no_discarding_arrow_in_with / pattern and uses_module (only pattern was read): the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: the rule has more than one selector (pattern, uses_module), but only the first is read (paths, then pattern, then uses_module); keep exactly one. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     no_discarding_arrow_in_with / recursive without paths (read by nothing): the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `recursive` applies only to `paths`, and the rule selects by pattern, so nothing reads it; remove `recursive`, or select by `paths`. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     no_discarding_arrow_in_with / recursive that is not a boolean: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `recursive` must be true or false, got: "yes". correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     no_discarding_arrow_in_with / min_files: 0 (no floor): the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `min_files` must be a positive integer (the fewest files the rule must select), got: 0. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     no_discarding_arrow_in_with / min_files that is not an integer: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `min_files` must be a positive integer (the fewest files the rule must select), got: "2". correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     no_discarding_arrow_in_with / an empty id: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `id` must be a non-empty string, got: "". correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     no_discarding_arrow_in_with / an id that is not a string: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `id` must be a non-empty string, got: 7. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     no_discarding_arrow_in_with / enforcement: warn (neither): the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `enforcement` must be report or enforce, got: "warn". correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     no_discarding_arrow_in_with / baseline on an ast rule (nothing reads it): the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `baseline` is read by graph rules only (mix anchor.graph); an ast rule's findings are not compared with a baseline yet, so it would ratchet nothing; remove `baseline`, and use `enforcement: report` while the rule's findings are being fixed. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     no_discarding_arrow_in_with / bucket on an ast rule (a graph selector): the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: unknown key "bucket" in a no_discarding_arrow_in_with rule (`bucket` applies to graph rules only); known keys for no_discarding_arrow_in_with: enforcement, id, min_files, paths, pattern, recursive, type, uses_module. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     code: assert failures == [], Enum.join(failures, "\n")
     stacktrace:
       test/anchor/domain/rule_checks_nothing_test.exs:54: (test)

.

  8) test max_file_length: every rule that checks nothing is refused, and the positive rows load (Anchor.Domain.RuleChecksNothingTest)
     test/anchor/domain/rule_checks_nothing_test.exs:48
     max_file_length / no selector: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: the rule has no selector, so it would select no file; give it one of: paths (a non-empty list of path globs), pattern (a module-name glob), uses_module (a module the file uses). correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     max_file_length / paths: [] alone: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: the rule has no selector, so it would select no file; give it one of: paths (a non-empty list of path globs), pattern (a module-name glob), uses_module (a module the file uses). correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     max_file_length / paths and pattern (only paths was read): the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: the rule has more than one selector (paths, pattern), but only the first is read (paths, then pattern, then uses_module); keep exactly one. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     max_file_length / pattern and uses_module (only pattern was read): the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: the rule has more than one selector (pattern, uses_module), but only the first is read (paths, then pattern, then uses_module); keep exactly one. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     max_file_length / recursive without paths (read by nothing): the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `recursive` applies only to `paths`, and the rule selects by pattern, so nothing reads it; remove `recursive`, or select by `paths`. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     max_file_length / recursive that is not a boolean: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `recursive` must be true or false, got: "yes". correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     max_file_length / min_files: 0 (no floor): the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `min_files` must be a positive integer (the fewest files the rule must select), got: 0. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     max_file_length / min_files that is not an integer: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `min_files` must be a positive integer (the fewest files the rule must select), got: "2". correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     max_file_length / an empty id: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `id` must be a non-empty string, got: "". correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     max_file_length / an id that is not a string: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `id` must be a non-empty string, got: 7. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     max_file_length / enforcement: warn (neither): the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `enforcement` must be report or enforce, got: "warn". correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     max_file_length / baseline on an ast rule (nothing reads it): the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `baseline` is read by graph rules only (mix anchor.graph); an ast rule's findings are not compared with a baseline yet, so it would ratchet nothing; remove `baseline`, and use `enforcement: report` while the rule's findings are being fixed. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     max_file_length / bucket on an ast rule (a graph selector): the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: unknown key "bucket" in a max_file_length rule (`bucket` applies to graph rules only); known keys for max_file_length: enforcement, id, max_lines, min_files, paths, pattern, recursive, type, uses_module. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     code: assert failures == [], Enum.join(failures, "\n")
     stacktrace:
       test/anchor/domain/rule_checks_nothing_test.exs:54: (test)

  9) test context_acyclic: every rule that checks nothing is refused, and the positive rows load (Anchor.Domain.RuleChecksNothingTest)
     test/anchor/domain/rule_checks_nothing_test.exs:48
     context_acyclic / no selector: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: the rule has no selector, so it would select no module; give it one of: bucket (an architecture: bucket name), paths (a non-empty list of path globs), pattern (a module-name glob). correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     context_acyclic / bucket and pattern (only bucket was read): the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: the rule has more than one selector (bucket, pattern), but only the first is read (bucket, then paths, then pattern); keep exactly one. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     context_acyclic / bucket that is not a string: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `bucket` must be a non-empty string, got: ["domain"]. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     context_acyclic / an empty bucket: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `bucket` must be a non-empty string, got: "". correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     context_acyclic / uses_module (an ast selector): the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: unknown key "uses_module" in a context_acyclic rule (`uses_module` applies to ast rules only); known keys for context_acyclic: baseline, bucket, enforcement, id, min_modules, paths, pattern, type. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     context_acyclic / recursive (graph paths are always recursive): the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: unknown key "recursive" in a context_acyclic rule (`recursive` applies to ast rules only); known keys for context_acyclic: baseline, bucket, enforcement, id, min_modules, paths, pattern, type. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     context_acyclic / min_files (the graph floor is min_modules): the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: unknown key "min_files" in a context_acyclic rule ("min_files": did you mean "min_modules"?; `min_files` applies to ast rules only); known keys for context_acyclic: baseline, bucket, enforcement, id, min_modules, paths, pattern, type. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     context_acyclic / min_modules: 0 (no floor): the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `min_modules` must be a positive integer (the fewest modules the rule must select), got: 0. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     context_acyclic / min_modules that is not an integer: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `min_modules` must be a positive integer (the fewest modules the rule must select), got: "2". correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     context_acyclic / an empty id: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `id` must be a non-empty string, got: "". correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     context_acyclic / enforcement: warn: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `enforcement` must be report or enforce, got: "warn". correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     context_acyclic / baseline without id (entries start with it): the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `baseline` needs the rule's `id`: every baseline entry starts with it; give the rule an id. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     context_acyclic / an absolute baseline path: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1 (id: "r"): `baseline: /tmp/r.txt` must be a path relative to the project root with no `..` segment (convention: .anchor/baselines/<rule-id>.txt). correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     context_acyclic / a baseline path climbing out: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1 (id: "r"): `baseline: ../x.txt` must be a path relative to the project root with no `..` segment (convention: .anchor/baselines/<rule-id>.txt). correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     context_acyclic / a baseline path with an inner ..: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1 (id: "r"): `baseline: .anchor/../../x.txt` must be a path relative to the project root with no `..` segment (convention: .anchor/baselines/<rule-id>.txt). correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     context_acyclic / an empty baseline: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1 (id: "r"): `baseline` must be a non-empty path relative to the project root, got: " ". correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     context_acyclic / a bucket naming no architecture bucket: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `bucket: web` names no architecture: bucket, so the rule would select no module; name one of: domain. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     code: assert failures == [], Enum.join(failures, "\n")
     stacktrace:
       test/anchor/domain/rule_checks_nothing_test.exs:54: (test)

.

 10) test no_discarded_pure_expression: every rule that checks nothing is refused, and the positive rows load (Anchor.Domain.RuleChecksNothingTest)
     test/anchor/domain/rule_checks_nothing_test.exs:48
     no_discarded_pure_expression / no selector: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: the rule has no selector, so it would select no file; give it one of: paths (a non-empty list of path globs), pattern (a module-name glob), uses_module (a module the file uses). correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     no_discarded_pure_expression / paths: [] alone: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: the rule has no selector, so it would select no file; give it one of: paths (a non-empty list of path globs), pattern (a module-name glob), uses_module (a module the file uses). correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     no_discarded_pure_expression / paths and pattern (only paths was read): the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: the rule has more than one selector (paths, pattern), but only the first is read (paths, then pattern, then uses_module); keep exactly one. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     no_discarded_pure_expression / pattern and uses_module (only pattern was read): the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: the rule has more than one selector (pattern, uses_module), but only the first is read (paths, then pattern, then uses_module); keep exactly one. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     no_discarded_pure_expression / recursive without paths (read by nothing): the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `recursive` applies only to `paths`, and the rule selects by pattern, so nothing reads it; remove `recursive`, or select by `paths`. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     no_discarded_pure_expression / recursive that is not a boolean: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `recursive` must be true or false, got: "yes". correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     no_discarded_pure_expression / min_files: 0 (no floor): the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `min_files` must be a positive integer (the fewest files the rule must select), got: 0. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     no_discarded_pure_expression / min_files that is not an integer: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `min_files` must be a positive integer (the fewest files the rule must select), got: "2". correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     no_discarded_pure_expression / an empty id: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `id` must be a non-empty string, got: "". correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     no_discarded_pure_expression / an id that is not a string: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `id` must be a non-empty string, got: 7. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     no_discarded_pure_expression / enforcement: warn (neither): the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `enforcement` must be report or enforce, got: "warn". correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     no_discarded_pure_expression / baseline on an ast rule (nothing reads it): the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `baseline` is read by graph rules only (mix anchor.graph); an ast rule's findings are not compared with a baseline yet, so it would ratchet nothing; remove `baseline`, and use `enforcement: report` while the rule's findings are being fixed. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     no_discarded_pure_expression / bucket on an ast rule (a graph selector): the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: unknown key "bucket" in a no_discarded_pure_expression rule (`bucket` applies to graph rules only); known keys for no_discarded_pure_expression: enforcement, id, min_files, paths, pattern, pure_patterns, recursive, type, uses_module. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     no_discarded_pure_expression / pure_patterns that is a string: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `pure_patterns` must be a list of non-empty strings, got: "MyApp.*". correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     no_discarded_pure_expression / pure_patterns of empty strings: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `pure_patterns` must be a list of non-empty strings, got: [""]. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     no_discarded_pure_expression / pure_patterns of a non-string: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `pure_patterns` must be a list of non-empty strings, got: [1]. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     no_discarded_pure_expression / an unknown key (pure_modules): the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: unknown key "pure_modules" in a no_discarded_pure_expression rule ("pure_modules": did you mean "uses_module"?); known keys for no_discarded_pure_expression: enforcement, id, min_files, paths, pattern, pure_patterns, recursive, type, uses_module. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     code: assert failures == [], Enum.join(failures, "\n")
     stacktrace:
       test/anchor/domain/rule_checks_nothing_test.exs:54: (test)

.

 11) test case_on_bare_arg: every rule that checks nothing is refused, and the positive rows load (Anchor.Domain.RuleChecksNothingTest)
     test/anchor/domain/rule_checks_nothing_test.exs:48
     case_on_bare_arg / no selector: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: the rule has no selector, so it would select no file; give it one of: paths (a non-empty list of path globs), pattern (a module-name glob), uses_module (a module the file uses). correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     case_on_bare_arg / paths: [] alone: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: the rule has no selector, so it would select no file; give it one of: paths (a non-empty list of path globs), pattern (a module-name glob), uses_module (a module the file uses). correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     case_on_bare_arg / paths and pattern (only paths was read): the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: the rule has more than one selector (paths, pattern), but only the first is read (paths, then pattern, then uses_module); keep exactly one. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     case_on_bare_arg / pattern and uses_module (only pattern was read): the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: the rule has more than one selector (pattern, uses_module), but only the first is read (paths, then pattern, then uses_module); keep exactly one. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     case_on_bare_arg / recursive without paths (read by nothing): the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `recursive` applies only to `paths`, and the rule selects by pattern, so nothing reads it; remove `recursive`, or select by `paths`. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     case_on_bare_arg / recursive that is not a boolean: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `recursive` must be true or false, got: "yes". correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     case_on_bare_arg / min_files: 0 (no floor): the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `min_files` must be a positive integer (the fewest files the rule must select), got: 0. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     case_on_bare_arg / min_files that is not an integer: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `min_files` must be a positive integer (the fewest files the rule must select), got: "2". correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     case_on_bare_arg / an empty id: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `id` must be a non-empty string, got: "". correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     case_on_bare_arg / an id that is not a string: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `id` must be a non-empty string, got: 7. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     case_on_bare_arg / enforcement: warn (neither): the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `enforcement` must be report or enforce, got: "warn". correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     case_on_bare_arg / baseline on an ast rule (nothing reads it): the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `baseline` is read by graph rules only (mix anchor.graph); an ast rule's findings are not compared with a baseline yet, so it would ratchet nothing; remove `baseline`, and use `enforcement: report` while the rule's findings are being fixed. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     case_on_bare_arg / bucket on an ast rule (a graph selector): the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: unknown key "bucket" in a case_on_bare_arg rule (`bucket` applies to graph rules only); known keys for case_on_bare_arg: enforcement, id, min_files, paths, pattern, recursive, type, uses_module. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     code: assert failures == [], Enum.join(failures, "\n")
     stacktrace:
       test/anchor/domain/rule_checks_nothing_test.exs:54: (test)



 12) test struct_owned_by_module: every rule that checks nothing is refused, and the positive rows load (Anchor.Domain.RuleChecksNothingTest)
     test/anchor/domain/rule_checks_nothing_test.exs:48
     struct_owned_by_module / no selector: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: the rule has no selector, so it would select no file; give it one of: paths (a non-empty list of path globs), pattern (a module-name glob), uses_module (a module the file uses). correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     struct_owned_by_module / paths: [] alone: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: the rule has no selector, so it would select no file; give it one of: paths (a non-empty list of path globs), pattern (a module-name glob), uses_module (a module the file uses). correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     struct_owned_by_module / paths and pattern (only paths was read): the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: the rule has more than one selector (paths, pattern), but only the first is read (paths, then pattern, then uses_module); keep exactly one. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     struct_owned_by_module / pattern and uses_module (only pattern was read): the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: the rule has more than one selector (pattern, uses_module), but only the first is read (paths, then pattern, then uses_module); keep exactly one. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     struct_owned_by_module / recursive without paths (read by nothing): the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `recursive` applies only to `paths`, and the rule selects by pattern, so nothing reads it; remove `recursive`, or select by `paths`. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     struct_owned_by_module / recursive that is not a boolean: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `recursive` must be true or false, got: "yes". correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     struct_owned_by_module / min_files: 0 (no floor): the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `min_files` must be a positive integer (the fewest files the rule must select), got: 0. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     struct_owned_by_module / min_files that is not an integer: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `min_files` must be a positive integer (the fewest files the rule must select), got: "2". correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     struct_owned_by_module / an empty id: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `id` must be a non-empty string, got: "". correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     struct_owned_by_module / an id that is not a string: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `id` must be a non-empty string, got: 7. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     struct_owned_by_module / enforcement: warn (neither): the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `enforcement` must be report or enforce, got: "warn". correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     struct_owned_by_module / baseline on an ast rule (nothing reads it): the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `baseline` is read by graph rules only (mix anchor.graph); an ast rule's findings are not compared with a baseline yet, so it would ratchet nothing; remove `baseline`, and use `enforcement: report` while the rule's findings are being fixed. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     struct_owned_by_module / bucket on an ast rule (a graph selector): the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: unknown key "bucket" in a struct_owned_by_module rule (`bucket` applies to graph rules only); known keys for struct_owned_by_module: enforcement, id, min_files, owned_namespaces, paths, pattern, recursive, type, uses_module. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     struct_owned_by_module / an owned_namespaces empty string: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `owned_namespaces` must be a list of non-empty strings, got: [""]. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     struct_owned_by_module / owned_namespaces that is a string: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `owned_namespaces` must be a list of non-empty strings, got: "App". correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     code: assert failures == [], Enum.join(failures, "\n")
     stacktrace:
       test/anchor/domain/rule_checks_nothing_test.exs:54: (test)



 13) test no_comparison_in_if: every rule that checks nothing is refused, and the positive rows load (Anchor.Domain.RuleChecksNothingTest)
     test/anchor/domain/rule_checks_nothing_test.exs:48
     no_comparison_in_if / no selector: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: the rule has no selector, so it would select no file; give it one of: paths (a non-empty list of path globs), pattern (a module-name glob), uses_module (a module the file uses). correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     no_comparison_in_if / paths: [] alone: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: the rule has no selector, so it would select no file; give it one of: paths (a non-empty list of path globs), pattern (a module-name glob), uses_module (a module the file uses). correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     no_comparison_in_if / paths and pattern (only paths was read): the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: the rule has more than one selector (paths, pattern), but only the first is read (paths, then pattern, then uses_module); keep exactly one. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     no_comparison_in_if / pattern and uses_module (only pattern was read): the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: the rule has more than one selector (pattern, uses_module), but only the first is read (paths, then pattern, then uses_module); keep exactly one. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     no_comparison_in_if / recursive without paths (read by nothing): the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `recursive` applies only to `paths`, and the rule selects by pattern, so nothing reads it; remove `recursive`, or select by `paths`. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     no_comparison_in_if / recursive that is not a boolean: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `recursive` must be true or false, got: "yes". correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     no_comparison_in_if / min_files: 0 (no floor): the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `min_files` must be a positive integer (the fewest files the rule must select), got: 0. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     no_comparison_in_if / min_files that is not an integer: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `min_files` must be a positive integer (the fewest files the rule must select), got: "2". correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     no_comparison_in_if / an empty id: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `id` must be a non-empty string, got: "". correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     no_comparison_in_if / an id that is not a string: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `id` must be a non-empty string, got: 7. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     no_comparison_in_if / enforcement: warn (neither): the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `enforcement` must be report or enforce, got: "warn". correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     no_comparison_in_if / baseline on an ast rule (nothing reads it): the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `baseline` is read by graph rules only (mix anchor.graph); an ast rule's findings are not compared with a baseline yet, so it would ratchet nothing; remove `baseline`, and use `enforcement: report` while the rule's findings are being fixed. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     no_comparison_in_if / bucket on an ast rule (a graph selector): the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: unknown key "bucket" in a no_comparison_in_if rule (`bucket` applies to graph rules only); known keys for no_comparison_in_if: enforcement, id, min_files, paths, pattern, recursive, type, uses_module. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     code: assert failures == [], Enum.join(failures, "\n")
     stacktrace:
       test/anchor/domain/rule_checks_nothing_test.exs:54: (test)

.

 14) test alphabetized_functions: every rule that checks nothing is refused, and the positive rows load (Anchor.Domain.RuleChecksNothingTest)
     test/anchor/domain/rule_checks_nothing_test.exs:48
     alphabetized_functions / no selector: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: the rule has no selector, so it would select no file; give it one of: paths (a non-empty list of path globs), pattern (a module-name glob), uses_module (a module the file uses). correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     alphabetized_functions / paths: [] alone: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: the rule has no selector, so it would select no file; give it one of: paths (a non-empty list of path globs), pattern (a module-name glob), uses_module (a module the file uses). correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     alphabetized_functions / paths and pattern (only paths was read): the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: the rule has more than one selector (paths, pattern), but only the first is read (paths, then pattern, then uses_module); keep exactly one. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     alphabetized_functions / pattern and uses_module (only pattern was read): the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: the rule has more than one selector (pattern, uses_module), but only the first is read (paths, then pattern, then uses_module); keep exactly one. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     alphabetized_functions / recursive without paths (read by nothing): the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `recursive` applies only to `paths`, and the rule selects by pattern, so nothing reads it; remove `recursive`, or select by `paths`. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     alphabetized_functions / recursive that is not a boolean: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `recursive` must be true or false, got: "yes". correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     alphabetized_functions / min_files: 0 (no floor): the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `min_files` must be a positive integer (the fewest files the rule must select), got: 0. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     alphabetized_functions / min_files that is not an integer: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `min_files` must be a positive integer (the fewest files the rule must select), got: "2". correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     alphabetized_functions / an empty id: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `id` must be a non-empty string, got: "". correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     alphabetized_functions / an id that is not a string: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `id` must be a non-empty string, got: 7. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     alphabetized_functions / enforcement: warn (neither): the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `enforcement` must be report or enforce, got: "warn". correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     alphabetized_functions / baseline on an ast rule (nothing reads it): the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `baseline` is read by graph rules only (mix anchor.graph); an ast rule's findings are not compared with a baseline yet, so it would ratchet nothing; remove `baseline`, and use `enforcement: report` while the rule's findings are being fixed. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     alphabetized_functions / bucket on an ast rule (a graph selector): the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: unknown key "bucket" in a alphabetized_functions rule (`bucket` applies to graph rules only); known keys for alphabetized_functions: enforcement, id, min_files, mode, paths, pattern, recursive, type, uses_module. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     code: assert failures == [], Enum.join(failures, "\n")
     stacktrace:
       test/anchor/domain/rule_checks_nothing_test.exs:54: (test)

.

 15) test no_direct_dependency: every rule that checks nothing is refused, and the positive rows load (Anchor.Domain.RuleChecksNothingTest)
     test/anchor/domain/rule_checks_nothing_test.exs:48
     no_direct_dependency / no selector: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: the rule has no selector, so it would select no file; give it one of: paths (a non-empty list of path globs), pattern (a module-name glob), uses_module (a module the file uses). correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     no_direct_dependency / paths: [] alone: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: the rule has no selector, so it would select no file; give it one of: paths (a non-empty list of path globs), pattern (a module-name glob), uses_module (a module the file uses). correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     no_direct_dependency / paths and pattern (only paths was read): the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: the rule has more than one selector (paths, pattern), but only the first is read (paths, then pattern, then uses_module); keep exactly one. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     no_direct_dependency / pattern and uses_module (only pattern was read): the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: the rule has more than one selector (pattern, uses_module), but only the first is read (paths, then pattern, then uses_module); keep exactly one. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     no_direct_dependency / recursive without paths (read by nothing): the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `recursive` applies only to `paths`, and the rule selects by pattern, so nothing reads it; remove `recursive`, or select by `paths`. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     no_direct_dependency / recursive that is not a boolean: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `recursive` must be true or false, got: "yes". correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     no_direct_dependency / min_files: 0 (no floor): the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `min_files` must be a positive integer (the fewest files the rule must select), got: 0. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     no_direct_dependency / min_files that is not an integer: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `min_files` must be a positive integer (the fewest files the rule must select), got: "2". correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     no_direct_dependency / an empty id: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `id` must be a non-empty string, got: "". correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     no_direct_dependency / an id that is not a string: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `id` must be a non-empty string, got: 7. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     no_direct_dependency / enforcement: warn (neither): the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `enforcement` must be report or enforce, got: "warn". correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     no_direct_dependency / baseline on an ast rule (nothing reads it): the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `baseline` is read by graph rules only (mix anchor.graph); an ast rule's findings are not compared with a baseline yet, so it would ratchet nothing; remove `baseline`, and use `enforcement: report` while the rule's findings are being fixed. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     no_direct_dependency / bucket on an ast rule (a graph selector): the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: unknown key "bucket" in a no_direct_dependency rule (`bucket` applies to graph rules only); known keys for no_direct_dependency: allowed_callers, context_depth, enforcement, forbidden_functions, forbidden_modules, forbidden_patterns, id, match, min_files, paths, pattern, recursive, same_context, type, uses_module. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     no_direct_dependency / no relation: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: a no_direct_dependency rule has no relation, so it checks nothing: forbidden_functions, forbidden_modules and forbidden_patterns are missing or empty; give it at least one non-empty list of: forbidden_functions (a list of "Module.function" or "Module.function/arity"), forbidden_modules (a list of module names), forbidden_patterns (a list of module-name globs). correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     no_direct_dependency / forbidden_modules: []: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: a no_direct_dependency rule has no relation, so it checks nothing: forbidden_functions, forbidden_modules and forbidden_patterns are missing or empty; give it at least one non-empty list of: forbidden_functions (a list of "Module.function" or "Module.function/arity"), forbidden_modules (a list of module names), forbidden_patterns (a list of module-name globs). correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     no_direct_dependency / forbidden_patterns: []: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: a no_direct_dependency rule has no relation, so it checks nothing: forbidden_functions, forbidden_modules and forbidden_patterns are missing or empty; give it at least one non-empty list of: forbidden_functions (a list of "Module.function" or "Module.function/arity"), forbidden_modules (a list of module names), forbidden_patterns (a list of module-name globs). correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     no_direct_dependency / both empty: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: a no_direct_dependency rule has no relation, so it checks nothing: forbidden_functions, forbidden_modules and forbidden_patterns are missing or empty; give it at least one non-empty list of: forbidden_functions (a list of "Module.function" or "Module.function/arity"), forbidden_modules (a list of module names), forbidden_patterns (a list of module-name globs). correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     no_direct_dependency / forbidden_modules of empty strings: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `forbidden_modules` must be a list of non-empty strings, got: [""]. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     no_direct_dependency / forbidden_modules of blank strings: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `forbidden_modules` must be a list of non-empty strings, got: ["  "]. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     no_direct_dependency / forbidden_patterns of empty strings: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `forbidden_patterns` must be a list of non-empty strings, got: [""]. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     no_direct_dependency / forbidden_modules that is a string: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `forbidden_modules` must be a list of non-empty strings, got: "A.B". correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     no_direct_dependency / a nil entry (a bare `-` in YAML): the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `forbidden_modules` must be a list of non-empty strings, got: [nil]. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     no_direct_dependency / same_context with nothing to scope: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: same_context: true requires forbidden_patterns to scope (nothing to scope) (rule type: no_direct_dependency). correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     no_direct_dependency / forbidden_functions: []: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: a no_direct_dependency rule has no relation, so it checks nothing: forbidden_functions, forbidden_modules and forbidden_patterns are missing or empty; give it at least one non-empty list of: forbidden_functions (a list of "Module.function" or "Module.function/arity"), forbidden_modules (a list of module names), forbidden_patterns (a list of module-name globs). correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     no_direct_dependency / forbidden_functions of empty strings: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `forbidden_functions` must be a list of non-empty strings, got: [""]. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     no_direct_dependency / forbidden_functions of blank strings: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `forbidden_functions` must be a list of non-empty strings, got: ["  "]. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     no_direct_dependency / forbidden_functions that is a string: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `forbidden_functions` must be a list of non-empty strings, got: "MyApp.Slack.user_info". correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     no_direct_dependency / a forbidden_functions nil entry (a bare `-` in YAML): the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `forbidden_functions` must be a list of non-empty strings, got: [nil]. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     no_direct_dependency / a forbidden_functions entry naming a module only: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `forbidden_functions` entry "MyApp.Slack" is not a function reference: it names no function; write each entry as "Module.function" or "Module.function/arity" (e.g. "MyApp.Repo.insert/2", ":ets.insert"). correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     no_direct_dependency / a forbidden_functions entry with a bad arity: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `forbidden_functions` entry "MyApp.Slack.user_info/x" is not a function reference: it has "x", which is not an arity (0 to 255); write each entry as "Module.function" or "Module.function/arity" (e.g. "MyApp.Repo.insert/2", ":ets.insert"). correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     no_direct_dependency / match on a rule with only forbidden_functions (nothing reads it): the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `match` applies only to `forbidden_modules` and `forbidden_patterns`, and the rule has neither, so nothing reads it (`forbidden_functions` matches every call shape whatever `match` says); remove `match`. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     no_direct_dependency / a forbidden_functions glob (globs are forbidden_patterns' job): the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `forbidden_functions` entry "MyApp.Slack.*" is not a function reference: it has "*", which is not a function name; write each entry as "Module.function" or "Module.function/arity" (e.g. "MyApp.Repo.insert/2", ":ets.insert"). correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     no_direct_dependency / a malformed entry after a valid one: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `forbidden_functions` entry "slack.user_info" is not a function reference: it has "slack", which is not a module name; write each entry as "Module.function" or "Module.function/arity" (e.g. "MyApp.Repo.insert/2", ":ets.insert"). correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     no_direct_dependency / forbidden_functions on no_transitive_dependency (not its key): the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: unknown key "forbidden_functions" in a no_transitive_dependency rule (`forbidden_functions` applies to: no_direct_dependency); known keys for no_transitive_dependency: enforcement, forbidden_modules, forbidden_patterns, id, min_files, paths, pattern, recursive, type, uses_module. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     no_direct_dependency / allowed_callers alone is no relation: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: a no_direct_dependency rule has no relation, so it checks nothing: forbidden_functions, forbidden_modules and forbidden_patterns are missing or empty; give it at least one non-empty list of: forbidden_functions (a list of "Module.function" or "Module.function/arity"), forbidden_modules (a list of module names), forbidden_patterns (a list of module-name globs). correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     no_direct_dependency / a match-all allowed_callers glob allows every caller, so the rule checks nothing: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `allowed_callers` entry "*" is a glob, and a glob allows every module a later change gives a matching name (`*` allows every caller, so the rule checks nothing); name each allowed module exactly, as its defmodule spells it in full (e.g. "MyApp.Priorities.SlackNameAdapter"). correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     no_direct_dependency / a ** allowed_callers glob allows every caller: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `allowed_callers` entry "**" is a glob, and a glob allows every module a later change gives a matching name (`*` allows every caller, so the rule checks nothing); name each allowed module exactly, as its defmodule spells it in full (e.g. "MyApp.Priorities.SlackNameAdapter"). correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     no_direct_dependency / an allowed_callers namespace glob widens with every new module: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `allowed_callers` entry "MyApp.Adapters.*" is a glob, and a glob allows every module a later change gives a matching name (`*` allows every caller, so the rule checks nothing); name each allowed module exactly, as its defmodule spells it in full (e.g. "MyApp.Priorities.SlackNameAdapter"). correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     no_direct_dependency / an allowed_callers Erlang module is never defined in source: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `allowed_callers` entry ":telemetry" names an Erlang module, which Elixir source never defines, so no caller could ever match it; name each allowed module exactly, as its defmodule spells it in full (e.g. "MyApp.Priorities.SlackNameAdapter"). correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     no_direct_dependency / an allowed_callers entry that is not a module name: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `allowed_callers` entry "my_app.adapter" is not a module name; name each allowed module exactly, as its defmodule spells it in full (e.g. "MyApp.Priorities.SlackNameAdapter"). correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     no_direct_dependency / an allowed_callers entry with an empty segment: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `allowed_callers` entry "MyApp..Adapter" is not a module name; name each allowed module exactly, as its defmodule spells it in full (e.g. "MyApp.Priorities.SlackNameAdapter"). correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     no_direct_dependency / an allowed_callers entry naming a function: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `allowed_callers` entry "MyApp.Adapter.call/1" is not a module name; name each allowed module exactly, as its defmodule spells it in full (e.g. "MyApp.Priorities.SlackNameAdapter"). correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     no_direct_dependency / a malformed allowed_callers entry after a valid one: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `allowed_callers` entry "MyApp.adapter" is not a module name; name each allowed module exactly, as its defmodule spells it in full (e.g. "MyApp.Priorities.SlackNameAdapter"). correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     no_direct_dependency / allowed_callers of empty strings: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `allowed_callers` must be a list of non-empty strings, got: [""]. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     no_direct_dependency / allowed_callers that is a string: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `allowed_callers` must be a list of non-empty strings, got: "MyApp.Adapter". correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     no_direct_dependency / an allowed_callers nil entry (a bare `-` in YAML): the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `allowed_callers` must be a list of non-empty strings, got: [nil]. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     no_direct_dependency / allowed_callers on no_transitive_dependency (not its key): the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: unknown key "allowed_callers" in a no_transitive_dependency rule (`allowed_callers` applies to: no_direct_dependency); known keys for no_transitive_dependency: enforcement, forbidden_modules, forbidden_patterns, id, min_files, paths, pattern, recursive, type, uses_module. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     code: assert failures == [], Enum.join(failures, "\n")
     stacktrace:
       test/anchor/domain/rule_checks_nothing_test.exs:54: (test)



 16) test no_transitive_dependency: every rule that checks nothing is refused, and the positive rows load (Anchor.Domain.RuleChecksNothingTest)
     test/anchor/domain/rule_checks_nothing_test.exs:48
     no_transitive_dependency / no selector: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: the rule has no selector, so it would select no file; give it one of: paths (a non-empty list of path globs), pattern (a module-name glob), uses_module (a module the file uses). correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     no_transitive_dependency / paths: [] alone: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: the rule has no selector, so it would select no file; give it one of: paths (a non-empty list of path globs), pattern (a module-name glob), uses_module (a module the file uses). correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     no_transitive_dependency / paths and pattern (only paths was read): the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: the rule has more than one selector (paths, pattern), but only the first is read (paths, then pattern, then uses_module); keep exactly one. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     no_transitive_dependency / pattern and uses_module (only pattern was read): the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: the rule has more than one selector (pattern, uses_module), but only the first is read (paths, then pattern, then uses_module); keep exactly one. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     no_transitive_dependency / recursive without paths (read by nothing): the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `recursive` applies only to `paths`, and the rule selects by pattern, so nothing reads it; remove `recursive`, or select by `paths`. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     no_transitive_dependency / recursive that is not a boolean: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `recursive` must be true or false, got: "yes". correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     no_transitive_dependency / min_files: 0 (no floor): the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `min_files` must be a positive integer (the fewest files the rule must select), got: 0. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     no_transitive_dependency / min_files that is not an integer: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `min_files` must be a positive integer (the fewest files the rule must select), got: "2". correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     no_transitive_dependency / an empty id: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `id` must be a non-empty string, got: "". correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     no_transitive_dependency / an id that is not a string: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `id` must be a non-empty string, got: 7. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     no_transitive_dependency / enforcement: warn (neither): the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `enforcement` must be report or enforce, got: "warn". correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     no_transitive_dependency / baseline on an ast rule (nothing reads it): the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `baseline` is read by graph rules only (mix anchor.graph); an ast rule's findings are not compared with a baseline yet, so it would ratchet nothing; remove `baseline`, and use `enforcement: report` while the rule's findings are being fixed. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     no_transitive_dependency / bucket on an ast rule (a graph selector): the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: unknown key "bucket" in a no_transitive_dependency rule (`bucket` applies to graph rules only); known keys for no_transitive_dependency: enforcement, forbidden_modules, forbidden_patterns, id, min_files, paths, pattern, recursive, type, uses_module. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     no_transitive_dependency / no relation: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: a no_transitive_dependency rule has no relation, so it checks nothing: forbidden_modules and forbidden_patterns are missing or empty; give it at least one non-empty list of: forbidden_modules (a list of module names), forbidden_patterns (a list of module-name globs). correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     no_transitive_dependency / forbidden_modules: []: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: a no_transitive_dependency rule has no relation, so it checks nothing: forbidden_modules and forbidden_patterns are missing or empty; give it at least one non-empty list of: forbidden_modules (a list of module names), forbidden_patterns (a list of module-name globs). correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     no_transitive_dependency / forbidden_patterns: []: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: a no_transitive_dependency rule has no relation, so it checks nothing: forbidden_modules and forbidden_patterns are missing or empty; give it at least one non-empty list of: forbidden_modules (a list of module names), forbidden_patterns (a list of module-name globs). correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     no_transitive_dependency / both empty: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: a no_transitive_dependency rule has no relation, so it checks nothing: forbidden_modules and forbidden_patterns are missing or empty; give it at least one non-empty list of: forbidden_modules (a list of module names), forbidden_patterns (a list of module-name globs). correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     no_transitive_dependency / forbidden_modules of empty strings: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `forbidden_modules` must be a list of non-empty strings, got: [""]. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     no_transitive_dependency / forbidden_modules of blank strings: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `forbidden_modules` must be a list of non-empty strings, got: ["  "]. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     no_transitive_dependency / forbidden_patterns of empty strings: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `forbidden_patterns` must be a list of non-empty strings, got: [""]. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     no_transitive_dependency / forbidden_modules that is a string: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `forbidden_modules` must be a list of non-empty strings, got: "A.B". correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     no_transitive_dependency / a nil entry (a bare `-` in YAML): the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `forbidden_modules` must be a list of non-empty strings, got: [nil]. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     code: assert failures == [], Enum.join(failures, "\n")
     stacktrace:
       test/anchor/domain/rule_checks_nothing_test.exs:54: (test)

.

 17) test layering: every rule that checks nothing is refused, and the positive rows load (Anchor.Domain.RuleChecksNothingTest)
     test/anchor/domain/rule_checks_nothing_test.exs:48
     layering / no selector: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: the rule has no selector, so it would select no module; give it one of: bucket (an architecture: bucket name), paths (a non-empty list of path globs), pattern (a module-name glob). correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     layering / bucket and pattern (only bucket was read): the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: the rule has more than one selector (bucket, pattern), but only the first is read (bucket, then paths, then pattern); keep exactly one. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     layering / bucket that is not a string: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `bucket` must be a non-empty string, got: ["domain"]. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     layering / an empty bucket: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `bucket` must be a non-empty string, got: "". correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     layering / uses_module (an ast selector): the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: unknown key "uses_module" in a layering rule (`uses_module` applies to ast rules only); known keys for layering: baseline, bucket, enforcement, id, min_modules, paths, pattern, type. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     layering / recursive (graph paths are always recursive): the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: unknown key "recursive" in a layering rule (`recursive` applies to ast rules only); known keys for layering: baseline, bucket, enforcement, id, min_modules, paths, pattern, type. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     layering / min_files (the graph floor is min_modules): the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: unknown key "min_files" in a layering rule ("min_files": did you mean "min_modules"?; `min_files` applies to ast rules only); known keys for layering: baseline, bucket, enforcement, id, min_modules, paths, pattern, type. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     layering / min_modules: 0 (no floor): the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `min_modules` must be a positive integer (the fewest modules the rule must select), got: 0. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     layering / min_modules that is not an integer: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `min_modules` must be a positive integer (the fewest modules the rule must select), got: "2". correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     layering / an empty id: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `id` must be a non-empty string, got: "". correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     layering / enforcement: warn: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `enforcement` must be report or enforce, got: "warn". correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     layering / baseline without id (entries start with it): the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `baseline` needs the rule's `id`: every baseline entry starts with it; give the rule an id. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     layering / an absolute baseline path: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1 (id: "r"): `baseline: /tmp/r.txt` must be a path relative to the project root with no `..` segment (convention: .anchor/baselines/<rule-id>.txt). correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     layering / a baseline path climbing out: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1 (id: "r"): `baseline: ../x.txt` must be a path relative to the project root with no `..` segment (convention: .anchor/baselines/<rule-id>.txt). correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     layering / a baseline path with an inner ..: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1 (id: "r"): `baseline: .anchor/../../x.txt` must be a path relative to the project root with no `..` segment (convention: .anchor/baselines/<rule-id>.txt). correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     layering / an empty baseline: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1 (id: "r"): `baseline` must be a non-empty path relative to the project root, got: " ". correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     layering / a bucket naming no architecture bucket: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `bucket: web` names no architecture: bucket, so the rule would select no module; name one of: domain. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     code: assert failures == [], Enum.join(failures, "\n")
     stacktrace:
       test/anchor/domain/rule_checks_nothing_test.exs:54: (test)



 18) test single_control_flow: every rule that checks nothing is refused, and the positive rows load (Anchor.Domain.RuleChecksNothingTest)
     test/anchor/domain/rule_checks_nothing_test.exs:48
     single_control_flow / no selector: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: the rule has no selector, so it would select no file; give it one of: paths (a non-empty list of path globs), pattern (a module-name glob), uses_module (a module the file uses). correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     single_control_flow / paths: [] alone: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: the rule has no selector, so it would select no file; give it one of: paths (a non-empty list of path globs), pattern (a module-name glob), uses_module (a module the file uses). correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     single_control_flow / paths and pattern (only paths was read): the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: the rule has more than one selector (paths, pattern), but only the first is read (paths, then pattern, then uses_module); keep exactly one. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     single_control_flow / pattern and uses_module (only pattern was read): the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: the rule has more than one selector (pattern, uses_module), but only the first is read (paths, then pattern, then uses_module); keep exactly one. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     single_control_flow / recursive without paths (read by nothing): the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `recursive` applies only to `paths`, and the rule selects by pattern, so nothing reads it; remove `recursive`, or select by `paths`. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     single_control_flow / recursive that is not a boolean: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `recursive` must be true or false, got: "yes". correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     single_control_flow / min_files: 0 (no floor): the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `min_files` must be a positive integer (the fewest files the rule must select), got: 0. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     single_control_flow / min_files that is not an integer: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `min_files` must be a positive integer (the fewest files the rule must select), got: "2". correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     single_control_flow / an empty id: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `id` must be a non-empty string, got: "". correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     single_control_flow / an id that is not a string: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `id` must be a non-empty string, got: 7. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     single_control_flow / enforcement: warn (neither): the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `enforcement` must be report or enforce, got: "warn". correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     single_control_flow / baseline on an ast rule (nothing reads it): the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `baseline` is read by graph rules only (mix anchor.graph); an ast rule's findings are not compared with a baseline yet, so it would ratchet nothing; remove `baseline`, and use `enforcement: report` while the rule's findings are being fixed. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     single_control_flow / bucket on an ast rule (a graph selector): the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: unknown key "bucket" in a single_control_flow rule (`bucket` applies to graph rules only); known keys for single_control_flow: enforcement, id, min_files, paths, pattern, recursive, type, uses_module. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     code: assert failures == [], Enum.join(failures, "\n")
     stacktrace:
       test/anchor/domain/rule_checks_nothing_test.exs:54: (test)



 19) test must_use_module: every rule that checks nothing is refused, and the positive rows load (Anchor.Domain.RuleChecksNothingTest)
     test/anchor/domain/rule_checks_nothing_test.exs:48
     must_use_module / no selector: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: the rule has no selector, so it would select no file; give it one of: paths (a non-empty list of path globs), pattern (a module-name glob), uses_module (a module the file uses). correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     must_use_module / paths: [] alone: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: the rule has no selector, so it would select no file; give it one of: paths (a non-empty list of path globs), pattern (a module-name glob), uses_module (a module the file uses). correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     must_use_module / paths and pattern (only paths was read): the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: the rule has more than one selector (paths, pattern), but only the first is read (paths, then pattern, then uses_module); keep exactly one. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     must_use_module / pattern and uses_module (only pattern was read): the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: the rule has more than one selector (pattern, uses_module), but only the first is read (paths, then pattern, then uses_module); keep exactly one. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     must_use_module / recursive without paths (read by nothing): the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `recursive` applies only to `paths`, and the rule selects by pattern, so nothing reads it; remove `recursive`, or select by `paths`. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     must_use_module / recursive that is not a boolean: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `recursive` must be true or false, got: "yes". correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     must_use_module / min_files: 0 (no floor): the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `min_files` must be a positive integer (the fewest files the rule must select), got: 0. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     must_use_module / min_files that is not an integer: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `min_files` must be a positive integer (the fewest files the rule must select), got: "2". correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     must_use_module / an empty id: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `id` must be a non-empty string, got: "". correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     must_use_module / an id that is not a string: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `id` must be a non-empty string, got: 7. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     must_use_module / enforcement: warn (neither): the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `enforcement` must be report or enforce, got: "warn". correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     must_use_module / baseline on an ast rule (nothing reads it): the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `baseline` is read by graph rules only (mix anchor.graph); an ast rule's findings are not compared with a baseline yet, so it would ratchet nothing; remove `baseline`, and use `enforcement: report` while the rule's findings are being fixed. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     must_use_module / bucket on an ast rule (a graph selector): the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: unknown key "bucket" in a must_use_module rule (`bucket` applies to graph rules only); known keys for must_use_module: enforcement, id, min_files, paths, pattern, recursive, required_modules, type, uses_module. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     must_use_module / no relation: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: a must_use_module rule has no relation, so it checks nothing: required_modules is missing or empty; give it a non-empty list: required_modules (a list of module names). correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     must_use_module / required_modules: []: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: a must_use_module rule has no relation, so it checks nothing: required_modules is missing or empty; give it a non-empty list: required_modules (a list of module names). correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     must_use_module / required_modules of empty strings: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `required_modules` must be a list of non-empty strings, got: [""]. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     must_use_module / required_modules that is a string: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `required_modules` must be a list of non-empty strings, got: "A". correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     code: assert failures == [], Enum.join(failures, "\n")
     stacktrace:
       test/anchor/domain/rule_checks_nothing_test.exs:54: (test)



 20) test interface: every rule that checks nothing is refused, and the positive rows load (Anchor.Domain.RuleChecksNothingTest)
     test/anchor/domain/rule_checks_nothing_test.exs:48
     interface / no selector: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: the rule has no selector, so it would select no module; give it one of: bucket (an architecture: bucket name), paths (a non-empty list of path globs), pattern (a module-name glob). correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     interface / bucket and pattern (only bucket was read): the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: the rule has more than one selector (bucket, pattern), but only the first is read (bucket, then paths, then pattern); keep exactly one. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     interface / bucket that is not a string: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `bucket` must be a non-empty string, got: ["domain"]. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     interface / an empty bucket: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `bucket` must be a non-empty string, got: "". correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     interface / uses_module (an ast selector): the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: unknown key "uses_module" in a interface rule (`uses_module` applies to ast rules only); known keys for interface: baseline, bucket, enforcement, id, max_width, min_modules, paths, pattern, type. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     interface / recursive (graph paths are always recursive): the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: unknown key "recursive" in a interface rule (`recursive` applies to ast rules only); known keys for interface: baseline, bucket, enforcement, id, max_width, min_modules, paths, pattern, type. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     interface / min_files (the graph floor is min_modules): the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: unknown key "min_files" in a interface rule ("min_files": did you mean "min_modules"?; `min_files` applies to ast rules only); known keys for interface: baseline, bucket, enforcement, id, max_width, min_modules, paths, pattern, type. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     interface / min_modules: 0 (no floor): the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `min_modules` must be a positive integer (the fewest modules the rule must select), got: 0. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     interface / min_modules that is not an integer: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `min_modules` must be a positive integer (the fewest modules the rule must select), got: "2". correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     interface / an empty id: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `id` must be a non-empty string, got: "". correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     interface / enforcement: warn: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `enforcement` must be report or enforce, got: "warn". correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     interface / baseline without id (entries start with it): the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `baseline` needs the rule's `id`: every baseline entry starts with it; give the rule an id. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     interface / an absolute baseline path: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1 (id: "r"): `baseline: /tmp/r.txt` must be a path relative to the project root with no `..` segment (convention: .anchor/baselines/<rule-id>.txt). correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     interface / a baseline path climbing out: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1 (id: "r"): `baseline: ../x.txt` must be a path relative to the project root with no `..` segment (convention: .anchor/baselines/<rule-id>.txt). correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     interface / a baseline path with an inner ..: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1 (id: "r"): `baseline: .anchor/../../x.txt` must be a path relative to the project root with no `..` segment (convention: .anchor/baselines/<rule-id>.txt). correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     interface / an empty baseline: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1 (id: "r"): `baseline` must be a non-empty path relative to the project root, got: " ". correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     interface / a bucket naming no architecture bucket: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `bucket: web` names no architecture: bucket, so the rule would select no module; name one of: domain. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     interface / max_width: 0 (fails every context with an interface): the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `max_width` must be a positive integer (the most public functions a context's interface may export), got: 0. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     interface / max_width that is not an integer: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `max_width` must be a positive integer (the most public functions a context's interface may export), got: "12". correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     code: assert failures == [], Enum.join(failures, "\n")
     stacktrace:
       test/anchor/domain/rule_checks_nothing_test.exs:54: (test)



 21) test no_forwarding_function: every rule that checks nothing is refused, and the positive rows load (Anchor.Domain.RuleChecksNothingTest)
     test/anchor/domain/rule_checks_nothing_test.exs:48
     no_forwarding_function / no selector: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: the rule has no selector, so it would select no file; give it one of: paths (a non-empty list of path globs), pattern (a module-name glob), uses_module (a module the file uses). correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     no_forwarding_function / paths: [] alone: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: the rule has no selector, so it would select no file; give it one of: paths (a non-empty list of path globs), pattern (a module-name glob), uses_module (a module the file uses). correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     no_forwarding_function / paths and pattern (only paths was read): the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: the rule has more than one selector (paths, pattern), but only the first is read (paths, then pattern, then uses_module); keep exactly one. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     no_forwarding_function / pattern and uses_module (only pattern was read): the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: the rule has more than one selector (pattern, uses_module), but only the first is read (paths, then pattern, then uses_module); keep exactly one. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     no_forwarding_function / recursive without paths (read by nothing): the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `recursive` applies only to `paths`, and the rule selects by pattern, so nothing reads it; remove `recursive`, or select by `paths`. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     no_forwarding_function / recursive that is not a boolean: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `recursive` must be true or false, got: "yes". correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     no_forwarding_function / min_files: 0 (no floor): the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `min_files` must be a positive integer (the fewest files the rule must select), got: 0. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     no_forwarding_function / min_files that is not an integer: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `min_files` must be a positive integer (the fewest files the rule must select), got: "2". correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     no_forwarding_function / an empty id: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `id` must be a non-empty string, got: "". correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     no_forwarding_function / an id that is not a string: the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `id` must be a non-empty string, got: 7. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     no_forwarding_function / enforcement: warn (neither): the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `enforcement` must be report or enforce, got: "warn". correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     no_forwarding_function / baseline on an ast rule (nothing reads it): the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `baseline` is read by graph rules only (mix anchor.graph); an ast rule's findings are not compared with a baseline yet, so it would ratchet nothing; remove `baseline`, and use `enforcement: report` while the rule's findings are being fixed. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     no_forwarding_function / bucket on an ast rule (a graph selector): the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: unknown key "bucket" in a no_forwarding_function rule (`bucket` applies to graph rules only); known keys for no_forwarding_function: enforcement, id, min_files, paths, pattern, recursive, type, uses_module. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     no_forwarding_function / an unknown key (pure_patterns belongs to another type): the issue carries 0 Fix: lines: Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: unknown key "pure_patterns" in a no_forwarding_function rule (`pure_patterns` applies to: no_discarded_pure_expression); known keys for no_forwarding_function: enforcement, id, min_files, paths, pattern, recursive, type, uses_module. correct .anchor.yml to match the README section "Config schema: rule keys at a glance" and its table "Keys each rule type accepts".
     code: assert failures == [], Enum.join(failures, "\n")
     stacktrace:
       test/anchor/domain/rule_checks_nothing_test.exs:54: (test)

....................................
```

## FA-C — the moved owned_namespaces: [] refusal loses its own Fix (the generic one replaces it)

Run summary: `84 tests, 1 failure`

```text
  1) test one Fix: per rejected config each moved load refusal keeps its own Fix, and only it (Anchor.Domain.FailuresTest)
     test/anchor/domain/failures_test.exs:286
     Assertion with =~ failed
     code:  assert message =~ fix
     left:  "Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `owned_namespaces: []` checks no struct. List module names, e.g. [\"MyApp\"], or leave owned_namespaces out to check every struct. Fix: correct .anchor.yml to match the README section \"Config schema: rule keys at a glance\" and its table \"Keys each rule type accepts\"."
     right: "Fix: list module names, e.g. [\"MyApp\"], or leave owned_namespaces out"
     stacktrace:
       test/anchor/domain/failures_test.exs:296: anonymous fn/2 in Anchor.Domain.FailuresTest."test one Fix: per rejected config each moved load refusal keeps its own Fix, and only it"/1
       (elixir 1.19.4) lib/enum.ex:2520: Enum."-reduce/3-lists^foldl/2-0-"/3
       test/anchor/domain/failures_test.exs:287: (test)

...........................................................................
```

## FA-D — the moved pure_patterns refusal loses its own Fix

Run summary: `84 tests, 1 failure`

```text
  1) test one Fix: per rejected config each moved load refusal keeps its own Fix, and only it (Anchor.Domain.FailuresTest)
     test/anchor/domain/failures_test.exs:286
     Assertion with =~ failed
     code:  assert message =~ fix
     left:  "Anchor rejected .anchor.yml, so no Anchor rule was checked: rule 1: `pure_patterns` entry \"*\" declares every module pure, so every call would read as having no effect. Name the pure namespaces, e.g. [\"MyApp.*.Domain.*\"]. Fix: correct .anchor.yml to match the README section \"Config schema: rule keys at a glance\" and its table \"Keys each rule type accepts\"."
     right: "Fix: name the pure namespaces, e.g. [\"MyApp.*.Domain.*\"]"
     stacktrace:
       test/anchor/domain/failures_test.exs:296: anonymous fn/2 in Anchor.Domain.FailuresTest."test one Fix: per rejected config each moved load refusal keeps its own Fix, and only it"/1
       (elixir 1.19.4) lib/enum.ex:2520: Enum."-reduce/3-lists^foldl/2-0-"/3
       test/anchor/domain/failures_test.exs:287: (test)

......................................................................
```

## RS-G — aggregate_declarations (main's new graph type) has no shape entry

Run summary: `7 tests, 1 failure`

```text
  1) test for/1 every rule type in RuleSchema.rule_types/0 has a non-empty shape (Anchor.Domain.RuleShapesTest)
     test/anchor/domain/rule_shapes_test.exs:30
     ** (FunctionClauseError) no function clause matching in Anchor.Domain.RuleShapes.for/1

     The following arguments were given to Anchor.Domain.RuleShapes.for/1:

         # 1
         %{id: nil, match: :reference, type: :aggregate_declarations, mode: nil, pattern: "MyApp.*", recursive: false, paths: nil, enforcement: :enforce, context_depth: 2, same_context: false, bucket: nil, min_modules: nil, uses_module: nil, baseline: nil, max_lines: nil, required_modules: [], allowed_functions: [], forbidden_modules: [], forbidden_patterns: [], forbidden_functions: [], allowed_callers: [], pure_patterns: [], owned_namespaces: nil, min_files: 1, max_width: nil}

     Attempted function clauses (showing 1 out of 1):

         def for(%{type: type} = rule) when -is_map_key(
       %{
         alphabetized_functions: Anchor.Domain.Checks.AlphabetizedFunctions,
         case_on_bare_arg: Anchor.Domain.Checks.CaseOnBareArg,
         context_acyclic: Anchor.Domain.GraphRules.ContextAcyclic,
         interface: Anchor.Domain.GraphRules.Interface,
         layering: Anchor.Domain.GraphRules.Layering,
         max_file_length: Anchor.Domain.Checks.MaxFileLength,
         module_pattern_restrictions: Anchor.Domain.Checks.ModulePatternRestrictions,
         must_use_module: Anchor.Domain.Checks.MustUseModule,
         no_comparison_in_if: Anchor.Domain.Checks.NoComparisonInIf,
         no_direct_dependency: Anchor.Domain.Checks.NoDependency,
         no_discarded_pure_expression: Anchor.Domain.Checks.NoDiscardedPureExpression,
         no_discarding_arrow_in_with: Anchor.Domain.Checks.NoDiscardingArrowInWith,
         no_forwarding_function: Anchor.Domain.Checks.NoForwardingFunction,
         no_transitive_dependency: Anchor.Domain.Checks.NoTransitiveDependency,
         no_tuple_match_in_head: Anchor.Domain.Checks.NoTupleMatchInHead,
         single_control_flow: Anchor.Domain.Checks.SingleControlFlow,
         struct_getter_convention: Anchor.Domain.Checks.StructGetterConvention,
         struct_owned_by_module: Anchor.Domain.Checks.StructOwnedByModule
       },
       type
     )-

     code: for type <- RuleSchema.rule_types() do
     stacktrace:
       (anchor 0.1.0) lib/anchor/domain/rule_shapes.ex:53: Anchor.Domain.RuleShapes.for/1
       test/anchor/domain/rule_shapes_test.exs:32: anonymous fn/2 in Anchor.Domain.RuleShapesTest."test for/1 every rule type in RuleSchema.rule_types/0 has a non-empty shape"/1
       (elixir 1.19.4) lib/enum.ex:2520: Enum."-reduce/3-lists^foldl/2-0-"/3
       test/anchor/domain/rule_shapes_test.exs:31: (test)

...
```

## RS-H — an aggregate_declarations finding (claimed twice) carries no Fix:

Run summary: `2 tests, 1 failure`

```text
  1) test N1: the violating module's table claim is claimed twice, at the config and at it (Anchor.Integration.AggregateDeclarationsIntegrationTest)
     test/anchor/integration/aggregate_declarations_integration_test.exs:79
     table "audit_rows" is claimed by Agg.Audit and AnchorFixtures.Agg.Threads.Space. List it in exactly one aggregate; the other reaches it through an outbox row consumed by the owner: aggregates: declare: - name: <Aggregate>, schemas: [<Schema>...], tables: ["<table>"...], owners: [<Module>...], or use Anchor.Aggregate, name: <Aggregate>, schemas: [<Schema>...]
     code: for finding <- [config_site, rogue_site] do
     stacktrace:
       test/anchor/integration/aggregate_declarations_integration_test.exs:95: anonymous fn/2 in Anchor.Integration.AggregateDeclarationsIntegrationTest."test N1: the violating module's table claim is claimed twice, at the config and at it"/1
       (elixir 1.19.4) lib/enum.ex:2520: Enum."-reduce/3-lists^foldl/2-0-"/3
       test/anchor/integration/aggregate_declarations_integration_test.exs:91: (test)
```

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

## EC-G — a Manager's effect finding carries no Fix:

Run summary: `3 tests, 1 failure`

```text
  1) test the violating modules give one finding per bad function, the compliant none (Anchor.Integration.EffectsCanaryTest)
     test/anchor/integration/effects_canary_test.exs:73
     AnchorFixtures.EffectsCanary.Direct.load/1 is in bucket managers (managers) but calls an effect itself: AnchorFixtures.EffectsCanary.Direct.load/1 -> File.read/1. Remedy: move the call into an adapter of this context and call the adapter.
     code: for finding <- report.findings do
     stacktrace:
       (elixir 1.19.4) lib/enum.ex:1688: Enum."-map/2-lists^map/1-1-"/2
       test/anchor/integration/effects_canary_test.exs:97: (test)

.
```

## EC-F — the fallback role's finding carries no Fix:

Run summary: `18 tests, 0 failures`

```text

```
