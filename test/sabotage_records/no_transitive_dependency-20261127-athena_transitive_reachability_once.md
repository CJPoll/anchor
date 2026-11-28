# Sabotage record — no_transitive_dependency walks each module once

- **Domain:** no_transitive_dependency
- **Branch:** athena/transitive-reachability-once
- **Date:** 2026-11-27
- **Code under test:** `Anchor.Domain.Checks.NoTransitiveDependency.detect_violations/3`,
  `detect_with_trees/3` (the violations and the trees the detection built) and
  the pattern test `forbidden?/3`. The first two rounds below ran against an
  earlier shape, `detect_violations/4` with an injected tree builder; see the
  third round
- **Suite run:** `mix test test/anchor/domain/dependency_tree_test.exs test/anchor/domain/checks/ test/anchor/check/no_transitive_dependency_test.exs test/anchor/domain/glob_pattern_test.exs`
  (562 tests), at commit b83b24e; each mutation applied alone, then `lib`
  restored with `git checkout`

The check searched the graph once per finding: one reachability walk per
module, then one targeted path search for every forbidden module it reached,
each over the reachable graph. It now walks each module once and reads every
finding's path from that walk's tree. The parity test compares every file of a
generated 5,000-module graph (`Anchor.Test.TransitiveGraphFixtures`) against
the detection as it was (`Anchor.Test.TransitiveDependencyOracle`); the
once-per-run test counts the walks the check reports (`detect_with_trees/3`).
Nothing reads a clock.

On the fixture as committed (`graph()`, 1,200 Domain files): 5,299 findings;
the old detection's per-finding searches expanded 460,231 modules on top of the
49,165 its reachability walks read, the new one reads 49,165 in all. On the
denser `graph(4)`: 56,472 findings, 39,445,911 modules expanded by the old
searches against 659,076 by the new walks. (Wall time is in the commit
message that makes the change, as information only.)

## Hand mutations

| # | Mutation | Tests failed | Failure string |
|---|---|---|---|
| H | The defect's shape: one more walk per finding (`Enum.each(findings, fn _finding -> build_tree.(modules_map, module) end)` after the module's walk) | 1 | once-per-run test, `code:  assert Enum.map(walks, &elem(&1, 0)) == TransitiveGraphFixtures.domain_modules()` `left:  [MyApp.Domain.D1, MyApp.Domain.D2, MyApp.Domain.D3, MyApp.Domain.D4,` `MyApp.Domain.D5, MyApp.Domain.D6, MyApp.Domain.D6,` `MyApp.Domain.D6, MyApp.Domain.D6, MyApp.Domain.D6,` `MyApp.Domain.D7, ...` [excerpt: the first lines of ExUnit's list] `right: [MyApp.Domain.D1, MyApp.Domain.D2, MyApp.Domain.D3, MyApp.Domain.D4,` `MyApp.Domain.D5, MyApp.Domain.D6, MyApp.Domain.D7,` [excerpt] |
| A | A walk per rule, not per module (`Enum.flat_map(rules, &violations_for_module(build_tree.(modules_map, module), [&1], ast))`) | 1 | `left:  [MyApp.Domain.D1, MyApp.Domain.D1, MyApp.Domain.D2, MyApp.Domain.D2,` `right: [MyApp.Domain.D1, MyApp.Domain.D2, MyApp.Domain.D3, MyApp.Domain.D4,` [excerpt: each list's first line] |
| B | Two walks per module (`_ = build_tree.(modules_map, module)` before the walk used) | 1 | as A: `left:  [MyApp.Domain.D1, MyApp.Domain.D1, MyApp.Domain.D2, MyApp.Domain.D2,` [excerpt: the list's first line] |
| G | No pattern matches (`module in forbidden_modules or matches_pattern?.(...)` -> `module in forbidden_modules`) | 4 | parity: `code:  assert {module, new} == {module, old}` `left:  {MyApp.Domain.D6,` [excerpt: the first line of a two-sided diff of D6's violations]; once-per-run: `code:  assert length(findings) > length(walks)` `left:  1074` `right: 1200`; the two Gap A pattern rows in no_transitive_dependency_test.exs |

## Stayed green, and why

- Under **H**, **A** and **B**, the parity test and every row of
  no_transitive_dependency_test.exs: the extra walks change how much is
  searched, not what is found. Only the walk count tells them apart, which is
  what the once-per-run test is for.
- Under **G**, the rows that forbid by exact module only.

## Notes

- **H** is the pre-fix half of the refactor (ADR 002): the old check's
  per-finding search, rebuilt as one changed block on the new code so the same
  counter measures it. The unchanged old code reports no walks, so that count
  cannot be taken from it; the parity row compares the oracle's own count of
  its searches with the new walks instead (second round).
- The once-per-run test also asserts each walk's `expanded` equals its
  module's reachable set size; `dependency_tree-20261127-athena_transitive_reachability_once.md`
  holds that red (mutation E).

## Hand mutations, second round

Same suite, at commit cd3ecfe (after review: the oracle got its own copy of
the module-name glob, the parity test also compares the work of the two, the
matcher's agreement row became a table of literal answers). Each mutation
applied alone, then `lib` and `test/support` restored with `git checkout`.

| # | Mutation | Tests failed | Failure string |
|---|---|---|---|
| H | As H above, one more walk per finding | 2 | parity row's work comparison: `code:  assert old_searched > new_walked` `left:  460231` `right: 932760`; and the once-per-run row as before |
| K | The fixture shrinks by one service (`@services 3_500` -> `@services 3_499`) | 2 | `code:  assert map_size(modules_map) == 5000` `left:  4999` `right: 5000`; and the parity row |

## Hand mutations, third round

The injected builder is gone: `mix anchor.graph`'s `effects_match_bucket` rule
read a Domain function applying its own parameter (`build_tree.(...)`) as
reaching an effect, since the open world lets any caller pass any function.
The check now builds each tree itself and returns the trees it built from
`detect_with_trees/3`; the once-per-run and parity tests read them. H, A and B
run again on that code, at commit ea2e7da, same suite (562 tests), each
mutation applied alone, then `lib` and `test/support` restored with
`git checkout`. Each mutant reports every tree it builds.

| # | Mutation | Tests failed | Failure string |
|---|---|---|---|
| H | One more walk per finding (`[{findings, tree} \| Enum.map(findings, fn _f -> {[], DependencyTree.build(modules_map, module)} end)]`) | 2 | `code:  assert old_searched > new_walked` `left:  460231` `right: 932760`; and the once-per-run row |
| A | A walk per rule (`Enum.map(rules, &violations_and_tree(DependencyTree.build(modules_map, module), [&1], ast))`) | 1 | `code:  assert Enum.map(walks, &elem(&1, 0)) == TransitiveGraphFixtures.domain_modules()` `left:  [MyApp.Domain.D1, MyApp.Domain.D1, MyApp.Domain.D2, MyApp.Domain.D2,` `right: [MyApp.Domain.D1, MyApp.Domain.D2, MyApp.Domain.D3, MyApp.Domain.D4,` [excerpt: each list's first line] |
| B | Two walks per module (`[{[], DependencyTree.build(modules_map, module)}, violations_and_tree(...)]`) | 1 | as A |

## Run 18:27 UTC

- **Code under test:** `Anchor.Domain.Checks.NoTransitiveDependency.forbidden?/3`
- **Generated by:** `mix anchor.sabotage run --base 2bf3aae61e6c2d451701c862ed8a54099ddee011 --print-survivor-lines` (Anchor 0.1.0), base 2bf3aae61e6c2d451701c862ed8a54099ddee011, head c81425542f0b14708dd77182da40a7c69f77b2a5

### Summary

| id | function | mutation | status | killers |
|---|---|---|---|---|
| a08261e7d13f | `Anchor.Domain.Checks.NoTransitiveDependency.forbidden?/3` | return_input [0] | killed | 14 |
| cd05304857d5 | `Anchor.Domain.Checks.NoTransitiveDependency.forbidden?/3` | return_input [1] | killed | 14 |
| de246b909230 | `Anchor.Domain.Checks.NoTransitiveDependency.forbidden?/3` | return_input [2] | killed | 14 |

### Mutants

#### a08261e7d13f Anchor.Domain.Checks.NoTransitiveDependency.forbidden?/3 return_input [0]: killed

```diff
--- a/lib/anchor/domain/checks/no_transitive_dependency.ex
+++ b/lib/anchor/domain/checks/no_transitive_dependency.ex
@@ -115,8 +115,8 @@
   # A'-scoped to `NoDependency` and is not consulted here.
   # The patterns are compiled once per rule and module (`matches_pattern?`), not
   # once per reachable module (DND-8208).
-  defp forbidden?(module, forbidden_modules, matches_pattern?) do
-    module in forbidden_modules or matches_pattern?.(to_string(module))
+  defp forbidden?(module, _forbidden_modules, _matches_pattern?) do
+    module
   end
 
   # The path is read from the module's one search tree, and is the path
```

Command: `mix test --max-cases 2 test/anchor/domain/checks/no_transitive_dependency_detector_test.exs test/anchor/domain/checks/no_transitive_dependency_parity_test.exs test/anchor/domain/checks/no_transitive_dependency_test.exs` (24 tests, 14 failures; tests selected by mirror). Failed: test/anchor/domain/checks/no_transitive_dependency_parity_test.exs:59 test every file's violations are identical to the pre-change detection's, on 5,000 modules, test/anchor/domain/checks/no_transitive_dependency_test.exs:320 test detect_violations/3 — forbidden_patterns (Gap A / DND-142) the pattern is dot-bounded transitively — AdaptersHelper does not match, test/anchor/domain/checks/no_transitive_dependency_test.exs:169 test detect_violations/3 cycle in the graph terminates and still detects, test/anchor/domain/checks/no_transitive_dependency_test.exs:263 test detect_violations/3 — forbidden_patterns (Gap A / DND-142) forbidden_patterns flags a transitively-reached adapter, test/anchor/domain/checks/no_transitive_dependency_test.exs:70 test detect_violations/3 flags across a two-hop chain (A->B->C->Repo), test/anchor/domain/checks/no_transitive_dependency_test.exs:118 test detect_violations/3 chain that never reaches the forbidden module passes, test/anchor/domain/checks/no_transitive_dependency_test.exs:211 test detect_violations/3 empty forbidden list flags nothing, test/anchor/domain/checks/no_transitive_dependency_test.exs:49 test detect_violations/3 flags a forbidden module reached through one intermediary (A->B->Repo), test/anchor/domain/checks/no_transitive_dependency_test.exs:234 test detect_violations/3 no matching rules (empty rule list) flags nothing, test/anchor/domain/checks/no_transitive_dependency_test.exs:187 test detect_violations/3 module absent from the map yields nothing, test/anchor/domain/checks/no_transitive_dependency_test.exs:283 test detect_violations/3 — forbidden_patterns (Gap A / DND-142) a reachable set with no pattern match passes, test/anchor/domain/checks/no_transitive_dependency_test.exs:419 test find_dependency_path/3 detect_violations/3 reports the first path in dependency order, past a shared dead end, test/anchor/domain/checks/no_transitive_dependency_test.exs:298 test detect_violations/3 — forbidden_patterns (Gap A / DND-142) forbidden_modules and forbidden_patterns both fire transitively, test/anchor/domain/checks/no_transitive_dependency_parity_test.exs:81 test each module's reachability is computed once per run: one walk per module, each module expanded once

```
test/anchor/domain/checks/no_transitive_dependency_parity_test.exs:59 test every file's violations are identical to the pre-change detection's, on 5,000 modules
** (ExUnit.AssertionError) 

Assertion with == failed
code:  assert {module, new} == {module, old}
left:  {MyApp.Domain.D2, [%Anchor.Domain.Violation{line: 2, trigger: "MyApp.Domain.D1", message: "Module has transitive dependency on forbidden module MyApp.Domain.D1. Fix: no chain of dependencies from the module reaches MyApp.Repo, MyApp.Mailer, MyApp.Adapters.*; cut the chain where it first enters a module that depends on it", filename: nil, kind: :rule, key: nil, rule_id: nil, enforcement: :enforce}, %Anchor.Domain.Violation{line: 2, trigger: "MyApp.Domain.D1", message: "Module has transitive dependency on forbidden module MyApp.Domain.D1. Fix: no chain of dependencies from the module reaches MyApp.Services.S1, MyApp.Services.S2; cut the chain where it first enters a module that depends on it", filename: nil, kind: :rule, key: nil, rule_id: nil, enforcement: :enforce}]}
right: {MyApp.Domain.D2, []}

```

#### cd05304857d5 Anchor.Domain.Checks.NoTransitiveDependency.forbidden?/3 return_input [1]: killed

```diff
--- a/lib/anchor/domain/checks/no_transitive_dependency.ex
+++ b/lib/anchor/domain/checks/no_transitive_dependency.ex
@@ -115,8 +115,8 @@
   # A'-scoped to `NoDependency` and is not consulted here.
   # The patterns are compiled once per rule and module (`matches_pattern?`), not
   # once per reachable module (DND-8208).
-  defp forbidden?(module, forbidden_modules, matches_pattern?) do
-    module in forbidden_modules or matches_pattern?.(to_string(module))
+  defp forbidden?(_module, forbidden_modules, _matches_pattern?) do
+    forbidden_modules
   end
 
   # The path is read from the module's one search tree, and is the path
```

Command: `mix test --max-cases 2 test/anchor/domain/checks/no_transitive_dependency_detector_test.exs test/anchor/domain/checks/no_transitive_dependency_parity_test.exs test/anchor/domain/checks/no_transitive_dependency_test.exs` (24 tests, 14 failures; tests selected by mirror). Failed: test/anchor/domain/checks/no_transitive_dependency_parity_test.exs:59 test every file's violations are identical to the pre-change detection's, on 5,000 modules, test/anchor/domain/checks/no_transitive_dependency_test.exs:283 test detect_violations/3 — forbidden_patterns (Gap A / DND-142) a reachable set with no pattern match passes, test/anchor/domain/checks/no_transitive_dependency_test.exs:70 test detect_violations/3 flags across a two-hop chain (A->B->C->Repo), test/anchor/domain/checks/no_transitive_dependency_test.exs:169 test detect_violations/3 cycle in the graph terminates and still detects, test/anchor/domain/checks/no_transitive_dependency_test.exs:263 test detect_violations/3 — forbidden_patterns (Gap A / DND-142) forbidden_patterns flags a transitively-reached adapter, test/anchor/domain/checks/no_transitive_dependency_test.exs:211 test detect_violations/3 empty forbidden list flags nothing, test/anchor/domain/checks/no_transitive_dependency_test.exs:187 test detect_violations/3 module absent from the map yields nothing, test/anchor/domain/checks/no_transitive_dependency_test.exs:118 test detect_violations/3 chain that never reaches the forbidden module passes, test/anchor/domain/checks/no_transitive_dependency_test.exs:320 test detect_violations/3 — forbidden_patterns (Gap A / DND-142) the pattern is dot-bounded transitively — AdaptersHelper does not match, test/anchor/domain/checks/no_transitive_dependency_test.exs:419 test find_dependency_path/3 detect_violations/3 reports the first path in dependency order, past a shared dead end, test/anchor/domain/checks/no_transitive_dependency_test.exs:234 test detect_violations/3 no matching rules (empty rule list) flags nothing, test/anchor/domain/checks/no_transitive_dependency_test.exs:49 test detect_violations/3 flags a forbidden module reached through one intermediary (A->B->Repo), test/anchor/domain/checks/no_transitive_dependency_test.exs:298 test detect_violations/3 — forbidden_patterns (Gap A / DND-142) forbidden_modules and forbidden_patterns both fire transitively, test/anchor/domain/checks/no_transitive_dependency_parity_test.exs:81 test each module's reachability is computed once per run: one walk per module, each module expanded once

```
test/anchor/domain/checks/no_transitive_dependency_parity_test.exs:59 test every file's violations are identical to the pre-change detection's, on 5,000 modules
** (ExUnit.AssertionError) 

Assertion with == failed
code:  assert {module, new} == {module, old}
left:  {MyApp.Domain.D2, [%Anchor.Domain.Violation{line: 2, trigger: "MyApp.Domain.D1", message: "Module has transitive dependency on forbidden module MyApp.Domain.D1. Fix: no chain of dependencies from the module reaches MyApp.Repo, MyApp.Mailer, MyApp.Adapters.*; cut the chain where it first enters a module that depends on it", filename: nil, kind: :rule, key: nil, rule_id: nil, enforcement: :enforce}, %Anchor.Domain.Violation{line: 2, trigger: "MyApp.Domain.D1", message: "Module has transitive dependency on forbidden module MyApp.Domain.D1. Fix: no chain of dependencies from the module reaches MyApp.Services.S1, MyApp.Services.S2; cut the chain where it first enters a module that depends on it", filename: nil, kind: :rule, key: nil, rule_id: nil, enforcement: :enforce}]}
right: {MyApp.Domain.D2, []}

```

#### de246b909230 Anchor.Domain.Checks.NoTransitiveDependency.forbidden?/3 return_input [2]: killed

```diff
--- a/lib/anchor/domain/checks/no_transitive_dependency.ex
+++ b/lib/anchor/domain/checks/no_transitive_dependency.ex
@@ -115,8 +115,8 @@
   # A'-scoped to `NoDependency` and is not consulted here.
   # The patterns are compiled once per rule and module (`matches_pattern?`), not
   # once per reachable module (DND-8208).
-  defp forbidden?(module, forbidden_modules, matches_pattern?) do
-    module in forbidden_modules or matches_pattern?.(to_string(module))
+  defp forbidden?(_module, _forbidden_modules, matches_pattern?) do
+    matches_pattern?
   end
 
   # The path is read from the module's one search tree, and is the path
```

Command: `mix test --max-cases 2 test/anchor/domain/checks/no_transitive_dependency_detector_test.exs test/anchor/domain/checks/no_transitive_dependency_parity_test.exs test/anchor/domain/checks/no_transitive_dependency_test.exs` (24 tests, 14 failures; tests selected by mirror). Failed: test/anchor/domain/checks/no_transitive_dependency_test.exs:298 test detect_violations/3 — forbidden_patterns (Gap A / DND-142) forbidden_modules and forbidden_patterns both fire transitively, test/anchor/domain/checks/no_transitive_dependency_test.exs:118 test detect_violations/3 chain that never reaches the forbidden module passes, test/anchor/domain/checks/no_transitive_dependency_test.exs:169 test detect_violations/3 cycle in the graph terminates and still detects, test/anchor/domain/checks/no_transitive_dependency_test.exs:70 test detect_violations/3 flags across a two-hop chain (A->B->C->Repo), test/anchor/domain/checks/no_transitive_dependency_test.exs:320 test detect_violations/3 — forbidden_patterns (Gap A / DND-142) the pattern is dot-bounded transitively — AdaptersHelper does not match, test/anchor/domain/checks/no_transitive_dependency_test.exs:49 test detect_violations/3 flags a forbidden module reached through one intermediary (A->B->Repo), test/anchor/domain/checks/no_transitive_dependency_test.exs:419 test find_dependency_path/3 detect_violations/3 reports the first path in dependency order, past a shared dead end, test/anchor/domain/checks/no_transitive_dependency_test.exs:211 test detect_violations/3 empty forbidden list flags nothing, test/anchor/domain/checks/no_transitive_dependency_test.exs:283 test detect_violations/3 — forbidden_patterns (Gap A / DND-142) a reachable set with no pattern match passes, test/anchor/domain/checks/no_transitive_dependency_test.exs:187 test detect_violations/3 module absent from the map yields nothing, test/anchor/domain/checks/no_transitive_dependency_test.exs:234 test detect_violations/3 no matching rules (empty rule list) flags nothing, test/anchor/domain/checks/no_transitive_dependency_test.exs:263 test detect_violations/3 — forbidden_patterns (Gap A / DND-142) forbidden_patterns flags a transitively-reached adapter, test/anchor/domain/checks/no_transitive_dependency_parity_test.exs:81 test each module's reachability is computed once per run: one walk per module, each module expanded once, test/anchor/domain/checks/no_transitive_dependency_parity_test.exs:59 test every file's violations are identical to the pre-change detection's, on 5,000 modules

```
test/anchor/domain/checks/no_transitive_dependency_test.exs:298 test detect_violations/3 — forbidden_patterns (Gap A / DND-142) forbidden_modules and forbidden_patterns both fire transitively
** (ExUnit.AssertionError) 

Assertion with == failed
code:  assert length(violations) == 2
left:  3
right: 2

```

### Survivors

None.

### Kills by timeout

None.

### Skipped, invalid, not run

- skipped Anchor.Domain.Checks.NoTransitiveDependency.detect_violations/4 return_input [0] `detect_violations(ast, rules, modules_map, build_tree \\ &DependencyTree.build/2)`: removes the last use of alias `DependencyAnalyzer`
- skipped Anchor.Domain.Checks.NoTransitiveDependency.detect_violations/4 return_input [1] `detect_violations(ast, rules, modules_map, build_tree \\ &DependencyTree.build/2)`: removes the last use of alias `DependencyAnalyzer`
- skipped Anchor.Domain.Checks.NoTransitiveDependency.detect_violations/4 return_input [2] `detect_violations(ast, rules, modules_map, build_tree \\ &DependencyTree.build/2)`: removes the last use of alias `DependencyAnalyzer`
- skipped Anchor.Domain.Checks.NoTransitiveDependency.detect_violations/4 return_input [3] `detect_violations(ast, rules, modules_map, build_tree \\ &DependencyTree.build/2)`: removes the last use of alias `DependencyAnalyzer`
- skipped Anchor.Domain.Checks.NoTransitiveDependency.violations_for_module/3 delete_statement `transitive_deps =
  tree |> DependencyTree.reachable() |> MapSet.delete(tree.start()) |> MapSet.to_list()`: orphans variable `transitive_deps` bound at line 94 and used at line 100
- skipped Anchor.Domain.Checks.NoTransitiveDependency.violations_for_module/3 delete_statement `forbidden = rule.forbidden_modules() || []`: orphans variable `forbidden` bound at line 101 and used at line 100
- skipped Anchor.Domain.Checks.NoTransitiveDependency.violations_for_module/3 delete_statement `matches_pattern? = GlobPattern.module_pattern_matcher(Map.get(rule, :forbidden_patterns) || [])`: orphans variable `matches_pattern?` bound at line 103 and used at line 100
- skipped Anchor.Domain.Checks.NoTransitiveDependency.violations_for_module/3 return_input [0] `violations_for_module(tree, rules, ast)`: removes the last use of alias `GlobPattern`
- skipped Anchor.Domain.Checks.NoTransitiveDependency.violations_for_module/3 return_input [1] `violations_for_module(tree, rules, ast)`: removes the last use of alias `GlobPattern`
- skipped Anchor.Domain.Checks.NoTransitiveDependency.violations_for_module/3 return_input [2] `violations_for_module(tree, rules, ast)`: removes the last use of alias `GlobPattern`
- skipped Anchor.Domain.Checks.NoTransitiveDependency.build_violation/3 delete_statement `path = DependencyTree.path(tree, forbidden_module)`: orphans variable `path` bound at line 125 and used at line 126
- skipped Anchor.Domain.Checks.NoTransitiveDependency.build_violation/3 delete_statement `path_description = format_dependency_path(path)`: orphans variable `path_description` bound at line 126 and used at line 133
- skipped Anchor.Domain.Checks.NoTransitiveDependency.build_violation/3 delete_statement `line = find_module_reference_line(ast, Enum.at(path, 1))`: orphans variable `line` bound at line 131 and used at line 133
- skipped Anchor.Domain.Checks.NoTransitiveDependency.build_violation/3 return_input [0] `build_violation(forbidden_module, tree, ast)`: removes the last use of function `find_module_reference_line/2`
- skipped Anchor.Domain.Checks.NoTransitiveDependency.build_violation/3 return_input [1] `build_violation(forbidden_module, tree, ast)`: removes the last use of function `find_module_reference_line/2`
- skipped Anchor.Domain.Checks.NoTransitiveDependency.build_violation/3 return_input [2] `build_violation(forbidden_module, tree, ast)`: removes the last use of function `find_module_reference_line/2`

### Tests still lacking a red

None.

### Kill map

```anchor-kills
# id	file	mfa	operator	status	killers
a08261e7d13f	lib/anchor/domain/checks/no_transitive_dependency.ex	Anchor.Domain.Checks.NoTransitiveDependency.forbidden?/3	return_input	killed	test/anchor/domain/checks/no_transitive_dependency_parity_test.exs:59 test every file's violations are identical to the pre-change detection's, on 5,000 modules ; test/anchor/domain/checks/no_transitive_dependency_test.exs:320 test detect_violations/3 — forbidden_patterns (Gap A / DND-142) the pattern is dot-bounded transitively — AdaptersHelper does not match ; test/anchor/domain/checks/no_transitive_dependency_test.exs:169 test detect_violations/3 cycle in the graph terminates and still detects ; test/anchor/domain/checks/no_transitive_dependency_test.exs:263 test detect_violations/3 — forbidden_patterns (Gap A / DND-142) forbidden_patterns flags a transitively-reached adapter ; test/anchor/domain/checks/no_transitive_dependency_test.exs:70 test detect_violations/3 flags across a two-hop chain (A->B->C->Repo) ; test/anchor/domain/checks/no_transitive_dependency_test.exs:118 test detect_violations/3 chain that never reaches the forbidden module passes ; test/anchor/domain/checks/no_transitive_dependency_test.exs:211 test detect_violations/3 empty forbidden list flags nothing ; test/anchor/domain/checks/no_transitive_dependency_test.exs:49 test detect_violations/3 flags a forbidden module reached through one intermediary (A->B->Repo) ; test/anchor/domain/checks/no_transitive_dependency_test.exs:234 test detect_violations/3 no matching rules (empty rule list) flags nothing ; test/anchor/domain/checks/no_transitive_dependency_test.exs:187 test detect_violations/3 module absent from the map yields nothing ; test/anchor/domain/checks/no_transitive_dependency_test.exs:283 test detect_violations/3 — forbidden_patterns (Gap A / DND-142) a reachable set with no pattern match passes ; test/anchor/domain/checks/no_transitive_dependency_test.exs:419 test find_dependency_path/3 detect_violations/3 reports the first path in dependency order, past a shared dead end ; test/anchor/domain/checks/no_transitive_dependency_test.exs:298 test detect_violations/3 — forbidden_patterns (Gap A / DND-142) forbidden_modules and forbidden_patterns both fire transitively ; test/anchor/domain/checks/no_transitive_dependency_parity_test.exs:81 test each module's reachability is computed once per run: one walk per module, each module expanded once
cd05304857d5	lib/anchor/domain/checks/no_transitive_dependency.ex	Anchor.Domain.Checks.NoTransitiveDependency.forbidden?/3	return_input	killed	test/anchor/domain/checks/no_transitive_dependency_parity_test.exs:59 test every file's violations are identical to the pre-change detection's, on 5,000 modules ; test/anchor/domain/checks/no_transitive_dependency_test.exs:283 test detect_violations/3 — forbidden_patterns (Gap A / DND-142) a reachable set with no pattern match passes ; test/anchor/domain/checks/no_transitive_dependency_test.exs:70 test detect_violations/3 flags across a two-hop chain (A->B->C->Repo) ; test/anchor/domain/checks/no_transitive_dependency_test.exs:169 test detect_violations/3 cycle in the graph terminates and still detects ; test/anchor/domain/checks/no_transitive_dependency_test.exs:263 test detect_violations/3 — forbidden_patterns (Gap A / DND-142) forbidden_patterns flags a transitively-reached adapter ; test/anchor/domain/checks/no_transitive_dependency_test.exs:211 test detect_violations/3 empty forbidden list flags nothing ; test/anchor/domain/checks/no_transitive_dependency_test.exs:187 test detect_violations/3 module absent from the map yields nothing ; test/anchor/domain/checks/no_transitive_dependency_test.exs:118 test detect_violations/3 chain that never reaches the forbidden module passes ; test/anchor/domain/checks/no_transitive_dependency_test.exs:320 test detect_violations/3 — forbidden_patterns (Gap A / DND-142) the pattern is dot-bounded transitively — AdaptersHelper does not match ; test/anchor/domain/checks/no_transitive_dependency_test.exs:419 test find_dependency_path/3 detect_violations/3 reports the first path in dependency order, past a shared dead end ; test/anchor/domain/checks/no_transitive_dependency_test.exs:234 test detect_violations/3 no matching rules (empty rule list) flags nothing ; test/anchor/domain/checks/no_transitive_dependency_test.exs:49 test detect_violations/3 flags a forbidden module reached through one intermediary (A->B->Repo) ; test/anchor/domain/checks/no_transitive_dependency_test.exs:298 test detect_violations/3 — forbidden_patterns (Gap A / DND-142) forbidden_modules and forbidden_patterns both fire transitively ; test/anchor/domain/checks/no_transitive_dependency_parity_test.exs:81 test each module's reachability is computed once per run: one walk per module, each module expanded once
de246b909230	lib/anchor/domain/checks/no_transitive_dependency.ex	Anchor.Domain.Checks.NoTransitiveDependency.forbidden?/3	return_input	killed	test/anchor/domain/checks/no_transitive_dependency_test.exs:298 test detect_violations/3 — forbidden_patterns (Gap A / DND-142) forbidden_modules and forbidden_patterns both fire transitively ; test/anchor/domain/checks/no_transitive_dependency_test.exs:118 test detect_violations/3 chain that never reaches the forbidden module passes ; test/anchor/domain/checks/no_transitive_dependency_test.exs:169 test detect_violations/3 cycle in the graph terminates and still detects ; test/anchor/domain/checks/no_transitive_dependency_test.exs:70 test detect_violations/3 flags across a two-hop chain (A->B->C->Repo) ; test/anchor/domain/checks/no_transitive_dependency_test.exs:320 test detect_violations/3 — forbidden_patterns (Gap A / DND-142) the pattern is dot-bounded transitively — AdaptersHelper does not match ; test/anchor/domain/checks/no_transitive_dependency_test.exs:49 test detect_violations/3 flags a forbidden module reached through one intermediary (A->B->Repo) ; test/anchor/domain/checks/no_transitive_dependency_test.exs:419 test find_dependency_path/3 detect_violations/3 reports the first path in dependency order, past a shared dead end ; test/anchor/domain/checks/no_transitive_dependency_test.exs:211 test detect_violations/3 empty forbidden list flags nothing ; test/anchor/domain/checks/no_transitive_dependency_test.exs:283 test detect_violations/3 — forbidden_patterns (Gap A / DND-142) a reachable set with no pattern match passes ; test/anchor/domain/checks/no_transitive_dependency_test.exs:187 test detect_violations/3 module absent from the map yields nothing ; test/anchor/domain/checks/no_transitive_dependency_test.exs:234 test detect_violations/3 no matching rules (empty rule list) flags nothing ; test/anchor/domain/checks/no_transitive_dependency_test.exs:263 test detect_violations/3 — forbidden_patterns (Gap A / DND-142) forbidden_patterns flags a transitively-reached adapter ; test/anchor/domain/checks/no_transitive_dependency_parity_test.exs:81 test each module's reachability is computed once per run: one walk per module, each module expanded once ; test/anchor/domain/checks/no_transitive_dependency_parity_test.exs:59 test every file's violations are identical to the pre-change detection's, on 5,000 modules
```

## Run 20:16 UTC

- **Code under test:** `Anchor.Domain.Checks.NoTransitiveDependency.forbidden?/3`
- **Generated by:** `mix anchor.sabotage run --base 2bf3aae61e6c2d451701c862ed8a54099ddee011 --print-survivor-lines` (Anchor 0.1.0), base 2bf3aae61e6c2d451701c862ed8a54099ddee011, head 61e483f7d6aef1c94dfbb7b1a4f3401b07c54bad

### Summary

| id | function | mutation | status | killers |
|---|---|---|---|---|
| a08261e7d13f | `Anchor.Domain.Checks.NoTransitiveDependency.forbidden?/3` | return_input [0] | killed | 14 |
| cd05304857d5 | `Anchor.Domain.Checks.NoTransitiveDependency.forbidden?/3` | return_input [1] | killed | 14 |
| de246b909230 | `Anchor.Domain.Checks.NoTransitiveDependency.forbidden?/3` | return_input [2] | killed | 14 |

### Mutants

#### a08261e7d13f Anchor.Domain.Checks.NoTransitiveDependency.forbidden?/3 return_input [0]: killed

```diff
--- a/lib/anchor/domain/checks/no_transitive_dependency.ex
+++ b/lib/anchor/domain/checks/no_transitive_dependency.ex
@@ -115,8 +115,8 @@
   # A'-scoped to `NoDependency` and is not consulted here.
   # The patterns are compiled once per rule and module (`matches_pattern?`), not
   # once per reachable module (DND-8208).
-  defp forbidden?(module, forbidden_modules, matches_pattern?) do
-    module in forbidden_modules or matches_pattern?.(to_string(module))
+  defp forbidden?(module, _forbidden_modules, _matches_pattern?) do
+    module
   end
 
   # The path is read from the module's one search tree, and is the path
```

Command: `mix test --max-cases 2 test/anchor/domain/checks/no_transitive_dependency_detector_test.exs test/anchor/domain/checks/no_transitive_dependency_parity_test.exs test/anchor/domain/checks/no_transitive_dependency_test.exs` (24 tests, 14 failures; tests selected by kill_map). Failed: test/anchor/domain/checks/no_transitive_dependency_parity_test.exs:59 test every file's violations are identical to the pre-change detection's, on 5,000 modules, test/anchor/domain/checks/no_transitive_dependency_test.exs:70 test detect_violations/3 flags across a two-hop chain (A->B->C->Repo), test/anchor/domain/checks/no_transitive_dependency_test.exs:118 test detect_violations/3 chain that never reaches the forbidden module passes, test/anchor/domain/checks/no_transitive_dependency_test.exs:419 test find_dependency_path/3 detect_violations/3 reports the first path in dependency order, past a shared dead end, test/anchor/domain/checks/no_transitive_dependency_test.exs:283 test detect_violations/3 — forbidden_patterns (Gap A / DND-142) a reachable set with no pattern match passes, test/anchor/domain/checks/no_transitive_dependency_test.exs:169 test detect_violations/3 cycle in the graph terminates and still detects, test/anchor/domain/checks/no_transitive_dependency_test.exs:298 test detect_violations/3 — forbidden_patterns (Gap A / DND-142) forbidden_modules and forbidden_patterns both fire transitively, test/anchor/domain/checks/no_transitive_dependency_test.exs:49 test detect_violations/3 flags a forbidden module reached through one intermediary (A->B->Repo), test/anchor/domain/checks/no_transitive_dependency_test.exs:211 test detect_violations/3 empty forbidden list flags nothing, test/anchor/domain/checks/no_transitive_dependency_test.exs:263 test detect_violations/3 — forbidden_patterns (Gap A / DND-142) forbidden_patterns flags a transitively-reached adapter, test/anchor/domain/checks/no_transitive_dependency_test.exs:234 test detect_violations/3 no matching rules (empty rule list) flags nothing, test/anchor/domain/checks/no_transitive_dependency_test.exs:320 test detect_violations/3 — forbidden_patterns (Gap A / DND-142) the pattern is dot-bounded transitively — AdaptersHelper does not match, test/anchor/domain/checks/no_transitive_dependency_test.exs:187 test detect_violations/3 module absent from the map yields nothing, test/anchor/domain/checks/no_transitive_dependency_parity_test.exs:89 test each module's reachability is computed once per run: one walk per module, each module expanded once

```
test/anchor/domain/checks/no_transitive_dependency_parity_test.exs:59 test every file's violations are identical to the pre-change detection's, on 5,000 modules
** (ExUnit.AssertionError) 

Assertion with == failed
code:  assert {module, new} == {module, old}
left:  {MyApp.Domain.D2, [%Anchor.Domain.Violation{line: 2, trigger: "MyApp.Domain.D1", message: "Module has transitive dependency on forbidden module MyApp.Domain.D1. Fix: no chain of dependencies from the module reaches MyApp.Repo, MyApp.Mailer, MyApp.Adapters.*; cut the chain where it first enters a module that depends on it", filename: nil, kind: :rule, key: nil, rule_id: nil, enforcement: :enforce}, %Anchor.Domain.Violation{line: 2, trigger: "MyApp.Domain.D1", message: "Module has transitive dependency on forbidden module MyApp.Domain.D1. Fix: no chain of dependencies from the module reaches MyApp.Services.S1, MyApp.Services.S2; cut the chain where it first enters a module that depends on it", filename: nil, kind: :rule, key: nil, rule_id: nil, enforcement: :enforce}]}
right: {MyApp.Domain.D2, []}

```

#### cd05304857d5 Anchor.Domain.Checks.NoTransitiveDependency.forbidden?/3 return_input [1]: killed

```diff
--- a/lib/anchor/domain/checks/no_transitive_dependency.ex
+++ b/lib/anchor/domain/checks/no_transitive_dependency.ex
@@ -115,8 +115,8 @@
   # A'-scoped to `NoDependency` and is not consulted here.
   # The patterns are compiled once per rule and module (`matches_pattern?`), not
   # once per reachable module (DND-8208).
-  defp forbidden?(module, forbidden_modules, matches_pattern?) do
-    module in forbidden_modules or matches_pattern?.(to_string(module))
+  defp forbidden?(_module, forbidden_modules, _matches_pattern?) do
+    forbidden_modules
   end
 
   # The path is read from the module's one search tree, and is the path
```

Command: `mix test --max-cases 2 test/anchor/domain/checks/no_transitive_dependency_detector_test.exs test/anchor/domain/checks/no_transitive_dependency_parity_test.exs test/anchor/domain/checks/no_transitive_dependency_test.exs` (24 tests, 14 failures; tests selected by kill_map). Failed: test/anchor/domain/checks/no_transitive_dependency_test.exs:187 test detect_violations/3 module absent from the map yields nothing, test/anchor/domain/checks/no_transitive_dependency_test.exs:283 test detect_violations/3 — forbidden_patterns (Gap A / DND-142) a reachable set with no pattern match passes, test/anchor/domain/checks/no_transitive_dependency_test.exs:234 test detect_violations/3 no matching rules (empty rule list) flags nothing, test/anchor/domain/checks/no_transitive_dependency_test.exs:320 test detect_violations/3 — forbidden_patterns (Gap A / DND-142) the pattern is dot-bounded transitively — AdaptersHelper does not match, test/anchor/domain/checks/no_transitive_dependency_test.exs:49 test detect_violations/3 flags a forbidden module reached through one intermediary (A->B->Repo), test/anchor/domain/checks/no_transitive_dependency_test.exs:419 test find_dependency_path/3 detect_violations/3 reports the first path in dependency order, past a shared dead end, test/anchor/domain/checks/no_transitive_dependency_test.exs:169 test detect_violations/3 cycle in the graph terminates and still detects, test/anchor/domain/checks/no_transitive_dependency_test.exs:211 test detect_violations/3 empty forbidden list flags nothing, test/anchor/domain/checks/no_transitive_dependency_test.exs:118 test detect_violations/3 chain that never reaches the forbidden module passes, test/anchor/domain/checks/no_transitive_dependency_test.exs:263 test detect_violations/3 — forbidden_patterns (Gap A / DND-142) forbidden_patterns flags a transitively-reached adapter, test/anchor/domain/checks/no_transitive_dependency_test.exs:70 test detect_violations/3 flags across a two-hop chain (A->B->C->Repo), test/anchor/domain/checks/no_transitive_dependency_test.exs:298 test detect_violations/3 — forbidden_patterns (Gap A / DND-142) forbidden_modules and forbidden_patterns both fire transitively, test/anchor/domain/checks/no_transitive_dependency_parity_test.exs:89 test each module's reachability is computed once per run: one walk per module, each module expanded once, test/anchor/domain/checks/no_transitive_dependency_parity_test.exs:59 test every file's violations are identical to the pre-change detection's, on 5,000 modules

```
test/anchor/domain/checks/no_transitive_dependency_test.exs:187 test detect_violations/3 module absent from the map yields nothing
** (ExUnit.AssertionError) 

match (=) failed
code:  assert [%Violation{trigger: "MyApp.Repo"}] =
              NoTransitiveDependency.detect_violations(
                source,
                [rule([MyApp.Repo])],
                %{Z => %{direct_dependencies: [B]}, B => %{direct_dependencies: [MyApp.Repo]}}
              )
left:  [%Anchor.Domain.Violation{trigger: "MyApp.Repo"}]
right: [%Anchor.Domain.Violation{line: 2, trigger: "MyApp.Repo", message: "Module has transitive dependency on forbidden module MyApp.Repo (dependency chain: Z -> B -> MyApp.Repo). Fix: no chain of dependencies from the module reaches MyApp.Repo; cut the chain where it first enters a module that depends on it", filename: nil, kind: :rule, key: nil, rule_id: nil, enforcement: :enforce}, %Anchor.Domain.Violation{line: 2, trigger: "B", message: "Module has transitive dependency on forbidden module B. Fix: no chain of dependencies from the module reaches MyApp.Repo; cut the chain where it first enters a module that depends on it", filename: nil, kind: :rule, key: nil, rule_id: nil, enforcement: :enforce}]

```

#### de246b909230 Anchor.Domain.Checks.NoTransitiveDependency.forbidden?/3 return_input [2]: killed

```diff
--- a/lib/anchor/domain/checks/no_transitive_dependency.ex
+++ b/lib/anchor/domain/checks/no_transitive_dependency.ex
@@ -115,8 +115,8 @@
   # A'-scoped to `NoDependency` and is not consulted here.
   # The patterns are compiled once per rule and module (`matches_pattern?`), not
   # once per reachable module (DND-8208).
-  defp forbidden?(module, forbidden_modules, matches_pattern?) do
-    module in forbidden_modules or matches_pattern?.(to_string(module))
+  defp forbidden?(_module, _forbidden_modules, matches_pattern?) do
+    matches_pattern?
   end
 
   # The path is read from the module's one search tree, and is the path
```

Command: `mix test --max-cases 2 test/anchor/domain/checks/no_transitive_dependency_detector_test.exs test/anchor/domain/checks/no_transitive_dependency_parity_test.exs test/anchor/domain/checks/no_transitive_dependency_test.exs` (24 tests, 14 failures; tests selected by kill_map). Failed: test/anchor/domain/checks/no_transitive_dependency_test.exs:211 test detect_violations/3 empty forbidden list flags nothing, test/anchor/domain/checks/no_transitive_dependency_test.exs:187 test detect_violations/3 module absent from the map yields nothing, test/anchor/domain/checks/no_transitive_dependency_test.exs:298 test detect_violations/3 — forbidden_patterns (Gap A / DND-142) forbidden_modules and forbidden_patterns both fire transitively, test/anchor/domain/checks/no_transitive_dependency_test.exs:283 test detect_violations/3 — forbidden_patterns (Gap A / DND-142) a reachable set with no pattern match passes, test/anchor/domain/checks/no_transitive_dependency_test.exs:118 test detect_violations/3 chain that never reaches the forbidden module passes, test/anchor/domain/checks/no_transitive_dependency_test.exs:419 test find_dependency_path/3 detect_violations/3 reports the first path in dependency order, past a shared dead end, test/anchor/domain/checks/no_transitive_dependency_test.exs:49 test detect_violations/3 flags a forbidden module reached through one intermediary (A->B->Repo), test/anchor/domain/checks/no_transitive_dependency_test.exs:263 test detect_violations/3 — forbidden_patterns (Gap A / DND-142) forbidden_patterns flags a transitively-reached adapter, test/anchor/domain/checks/no_transitive_dependency_test.exs:234 test detect_violations/3 no matching rules (empty rule list) flags nothing, test/anchor/domain/checks/no_transitive_dependency_test.exs:169 test detect_violations/3 cycle in the graph terminates and still detects, test/anchor/domain/checks/no_transitive_dependency_test.exs:70 test detect_violations/3 flags across a two-hop chain (A->B->C->Repo), test/anchor/domain/checks/no_transitive_dependency_test.exs:320 test detect_violations/3 — forbidden_patterns (Gap A / DND-142) the pattern is dot-bounded transitively — AdaptersHelper does not match, test/anchor/domain/checks/no_transitive_dependency_parity_test.exs:89 test each module's reachability is computed once per run: one walk per module, each module expanded once, test/anchor/domain/checks/no_transitive_dependency_parity_test.exs:59 test every file's violations are identical to the pre-change detection's, on 5,000 modules

```
test/anchor/domain/checks/no_transitive_dependency_test.exs:211 test detect_violations/3 empty forbidden list flags nothing
** (ExUnit.AssertionError) 

Assertion with == failed
code:  assert NoTransitiveDependency.detect_violations(
              a_refs_b(),
              [rule([])],
              modules_map
            ) == []
left:  [%Anchor.Domain.Violation{line: 2, trigger: "MyApp.Repo", message: "Module has transitive dependency on forbidden module MyApp.Repo (dependency chain: A -> B -> MyApp.Repo). Fix: no chain of dependencies from the module reaches ; cut the chain where it first enters a module that depends on it", filename: nil, kind: :rule, key: nil, rule_id: nil, enforcement: :enforce}, %Anchor.Domain.Violation{line: 2, trigger: "B", message: "Module has transitive dependency on forbidden module B. Fix: no chain of dependencies from the module reaches ; cut the chain where it first enters a module that depends on it", filename: nil, kind: :rule, key: nil, rule_id: nil, enforcement: :enforce}]
right: []

```

### Survivors

None.

### Kills by timeout

None.

### Skipped, invalid, not run

- skipped Anchor.Domain.Checks.NoTransitiveDependency.detect_violations/4 return_input [0] `detect_violations(ast, rules, modules_map, build_tree \\ &DependencyTree.build/2)`: removes the last use of alias `DependencyAnalyzer`
- skipped Anchor.Domain.Checks.NoTransitiveDependency.detect_violations/4 return_input [1] `detect_violations(ast, rules, modules_map, build_tree \\ &DependencyTree.build/2)`: removes the last use of alias `DependencyAnalyzer`
- skipped Anchor.Domain.Checks.NoTransitiveDependency.detect_violations/4 return_input [2] `detect_violations(ast, rules, modules_map, build_tree \\ &DependencyTree.build/2)`: removes the last use of alias `DependencyAnalyzer`
- skipped Anchor.Domain.Checks.NoTransitiveDependency.detect_violations/4 return_input [3] `detect_violations(ast, rules, modules_map, build_tree \\ &DependencyTree.build/2)`: removes the last use of alias `DependencyAnalyzer`
- skipped Anchor.Domain.Checks.NoTransitiveDependency.violations_for_module/3 delete_statement `transitive_deps =
  tree |> DependencyTree.reachable() |> MapSet.delete(tree.start()) |> MapSet.to_list()`: orphans variable `transitive_deps` bound at line 94 and used at line 100
- skipped Anchor.Domain.Checks.NoTransitiveDependency.violations_for_module/3 delete_statement `forbidden = rule.forbidden_modules() || []`: orphans variable `forbidden` bound at line 101 and used at line 100
- skipped Anchor.Domain.Checks.NoTransitiveDependency.violations_for_module/3 delete_statement `matches_pattern? = GlobPattern.module_pattern_matcher(Map.get(rule, :forbidden_patterns) || [])`: orphans variable `matches_pattern?` bound at line 103 and used at line 100
- skipped Anchor.Domain.Checks.NoTransitiveDependency.violations_for_module/3 return_input [0] `violations_for_module(tree, rules, ast)`: removes the last use of alias `GlobPattern`
- skipped Anchor.Domain.Checks.NoTransitiveDependency.violations_for_module/3 return_input [1] `violations_for_module(tree, rules, ast)`: removes the last use of alias `GlobPattern`
- skipped Anchor.Domain.Checks.NoTransitiveDependency.violations_for_module/3 return_input [2] `violations_for_module(tree, rules, ast)`: removes the last use of alias `GlobPattern`
- skipped Anchor.Domain.Checks.NoTransitiveDependency.build_violation/3 delete_statement `path = DependencyTree.path(tree, forbidden_module)`: orphans variable `path` bound at line 125 and used at line 126
- skipped Anchor.Domain.Checks.NoTransitiveDependency.build_violation/3 delete_statement `path_description = format_dependency_path(path)`: orphans variable `path_description` bound at line 126 and used at line 133
- skipped Anchor.Domain.Checks.NoTransitiveDependency.build_violation/3 delete_statement `line = find_module_reference_line(ast, Enum.at(path, 1))`: orphans variable `line` bound at line 131 and used at line 133
- skipped Anchor.Domain.Checks.NoTransitiveDependency.build_violation/3 return_input [0] `build_violation(forbidden_module, tree, ast)`: removes the last use of function `find_module_reference_line/2`
- skipped Anchor.Domain.Checks.NoTransitiveDependency.build_violation/3 return_input [1] `build_violation(forbidden_module, tree, ast)`: removes the last use of function `find_module_reference_line/2`
- skipped Anchor.Domain.Checks.NoTransitiveDependency.build_violation/3 return_input [2] `build_violation(forbidden_module, tree, ast)`: removes the last use of function `find_module_reference_line/2`

### Tests still lacking a red

None.

### Kill map

```anchor-kills
# id	file	mfa	operator	status	killers
a08261e7d13f	lib/anchor/domain/checks/no_transitive_dependency.ex	Anchor.Domain.Checks.NoTransitiveDependency.forbidden?/3	return_input	killed	test/anchor/domain/checks/no_transitive_dependency_parity_test.exs:59 test every file's violations are identical to the pre-change detection's, on 5,000 modules ; test/anchor/domain/checks/no_transitive_dependency_test.exs:70 test detect_violations/3 flags across a two-hop chain (A->B->C->Repo) ; test/anchor/domain/checks/no_transitive_dependency_test.exs:118 test detect_violations/3 chain that never reaches the forbidden module passes ; test/anchor/domain/checks/no_transitive_dependency_test.exs:419 test find_dependency_path/3 detect_violations/3 reports the first path in dependency order, past a shared dead end ; test/anchor/domain/checks/no_transitive_dependency_test.exs:283 test detect_violations/3 — forbidden_patterns (Gap A / DND-142) a reachable set with no pattern match passes ; test/anchor/domain/checks/no_transitive_dependency_test.exs:169 test detect_violations/3 cycle in the graph terminates and still detects ; test/anchor/domain/checks/no_transitive_dependency_test.exs:298 test detect_violations/3 — forbidden_patterns (Gap A / DND-142) forbidden_modules and forbidden_patterns both fire transitively ; test/anchor/domain/checks/no_transitive_dependency_test.exs:49 test detect_violations/3 flags a forbidden module reached through one intermediary (A->B->Repo) ; test/anchor/domain/checks/no_transitive_dependency_test.exs:211 test detect_violations/3 empty forbidden list flags nothing ; test/anchor/domain/checks/no_transitive_dependency_test.exs:263 test detect_violations/3 — forbidden_patterns (Gap A / DND-142) forbidden_patterns flags a transitively-reached adapter ; test/anchor/domain/checks/no_transitive_dependency_test.exs:234 test detect_violations/3 no matching rules (empty rule list) flags nothing ; test/anchor/domain/checks/no_transitive_dependency_test.exs:320 test detect_violations/3 — forbidden_patterns (Gap A / DND-142) the pattern is dot-bounded transitively — AdaptersHelper does not match ; test/anchor/domain/checks/no_transitive_dependency_test.exs:187 test detect_violations/3 module absent from the map yields nothing ; test/anchor/domain/checks/no_transitive_dependency_parity_test.exs:89 test each module's reachability is computed once per run: one walk per module, each module expanded once
cd05304857d5	lib/anchor/domain/checks/no_transitive_dependency.ex	Anchor.Domain.Checks.NoTransitiveDependency.forbidden?/3	return_input	killed	test/anchor/domain/checks/no_transitive_dependency_test.exs:187 test detect_violations/3 module absent from the map yields nothing ; test/anchor/domain/checks/no_transitive_dependency_test.exs:283 test detect_violations/3 — forbidden_patterns (Gap A / DND-142) a reachable set with no pattern match passes ; test/anchor/domain/checks/no_transitive_dependency_test.exs:234 test detect_violations/3 no matching rules (empty rule list) flags nothing ; test/anchor/domain/checks/no_transitive_dependency_test.exs:320 test detect_violations/3 — forbidden_patterns (Gap A / DND-142) the pattern is dot-bounded transitively — AdaptersHelper does not match ; test/anchor/domain/checks/no_transitive_dependency_test.exs:49 test detect_violations/3 flags a forbidden module reached through one intermediary (A->B->Repo) ; test/anchor/domain/checks/no_transitive_dependency_test.exs:419 test find_dependency_path/3 detect_violations/3 reports the first path in dependency order, past a shared dead end ; test/anchor/domain/checks/no_transitive_dependency_test.exs:169 test detect_violations/3 cycle in the graph terminates and still detects ; test/anchor/domain/checks/no_transitive_dependency_test.exs:211 test detect_violations/3 empty forbidden list flags nothing ; test/anchor/domain/checks/no_transitive_dependency_test.exs:118 test detect_violations/3 chain that never reaches the forbidden module passes ; test/anchor/domain/checks/no_transitive_dependency_test.exs:263 test detect_violations/3 — forbidden_patterns (Gap A / DND-142) forbidden_patterns flags a transitively-reached adapter ; test/anchor/domain/checks/no_transitive_dependency_test.exs:70 test detect_violations/3 flags across a two-hop chain (A->B->C->Repo) ; test/anchor/domain/checks/no_transitive_dependency_test.exs:298 test detect_violations/3 — forbidden_patterns (Gap A / DND-142) forbidden_modules and forbidden_patterns both fire transitively ; test/anchor/domain/checks/no_transitive_dependency_parity_test.exs:89 test each module's reachability is computed once per run: one walk per module, each module expanded once ; test/anchor/domain/checks/no_transitive_dependency_parity_test.exs:59 test every file's violations are identical to the pre-change detection's, on 5,000 modules
de246b909230	lib/anchor/domain/checks/no_transitive_dependency.ex	Anchor.Domain.Checks.NoTransitiveDependency.forbidden?/3	return_input	killed	test/anchor/domain/checks/no_transitive_dependency_test.exs:211 test detect_violations/3 empty forbidden list flags nothing ; test/anchor/domain/checks/no_transitive_dependency_test.exs:187 test detect_violations/3 module absent from the map yields nothing ; test/anchor/domain/checks/no_transitive_dependency_test.exs:298 test detect_violations/3 — forbidden_patterns (Gap A / DND-142) forbidden_modules and forbidden_patterns both fire transitively ; test/anchor/domain/checks/no_transitive_dependency_test.exs:283 test detect_violations/3 — forbidden_patterns (Gap A / DND-142) a reachable set with no pattern match passes ; test/anchor/domain/checks/no_transitive_dependency_test.exs:118 test detect_violations/3 chain that never reaches the forbidden module passes ; test/anchor/domain/checks/no_transitive_dependency_test.exs:419 test find_dependency_path/3 detect_violations/3 reports the first path in dependency order, past a shared dead end ; test/anchor/domain/checks/no_transitive_dependency_test.exs:49 test detect_violations/3 flags a forbidden module reached through one intermediary (A->B->Repo) ; test/anchor/domain/checks/no_transitive_dependency_test.exs:263 test detect_violations/3 — forbidden_patterns (Gap A / DND-142) forbidden_patterns flags a transitively-reached adapter ; test/anchor/domain/checks/no_transitive_dependency_test.exs:234 test detect_violations/3 no matching rules (empty rule list) flags nothing ; test/anchor/domain/checks/no_transitive_dependency_test.exs:169 test detect_violations/3 cycle in the graph terminates and still detects ; test/anchor/domain/checks/no_transitive_dependency_test.exs:70 test detect_violations/3 flags across a two-hop chain (A->B->C->Repo) ; test/anchor/domain/checks/no_transitive_dependency_test.exs:320 test detect_violations/3 — forbidden_patterns (Gap A / DND-142) the pattern is dot-bounded transitively — AdaptersHelper does not match ; test/anchor/domain/checks/no_transitive_dependency_parity_test.exs:89 test each module's reachability is computed once per run: one walk per module, each module expanded once ; test/anchor/domain/checks/no_transitive_dependency_parity_test.exs:59 test every file's violations are identical to the pre-change detection's, on 5,000 modules
```

## Run 23:24 UTC

- **Code under test:** `Anchor.Domain.Checks.NoTransitiveDependency.detect_violations/3`, `Anchor.Domain.Checks.NoTransitiveDependency.forbidden?/3`
- **Generated by:** `mix anchor.sabotage run --base 2bf3aae61e6c2d451701c862ed8a54099ddee011 --print-survivor-lines` (Anchor 0.1.0), base 2bf3aae61e6c2d451701c862ed8a54099ddee011, head 4c613db48e96344ee1e37dc4e0d3fd4a5b179765

### Summary

| id | function | mutation | status | killers |
|---|---|---|---|---|
| 0a4e0f51c659 | `Anchor.Domain.Checks.NoTransitiveDependency.detect_violations/3` | return_input [0] | killed | 14 |
| 2a58bbb9a6f3 | `Anchor.Domain.Checks.NoTransitiveDependency.detect_violations/3` | return_input [1] | killed | 14 |
| 345a1ab881d7 | `Anchor.Domain.Checks.NoTransitiveDependency.detect_violations/3` | return_input [2] | killed | 14 |
| a08261e7d13f | `Anchor.Domain.Checks.NoTransitiveDependency.forbidden?/3` | return_input [0] | killed | 14 |
| cd05304857d5 | `Anchor.Domain.Checks.NoTransitiveDependency.forbidden?/3` | return_input [1] | killed | 14 |
| de246b909230 | `Anchor.Domain.Checks.NoTransitiveDependency.forbidden?/3` | return_input [2] | killed | 14 |

### Mutants

#### 0a4e0f51c659 Anchor.Domain.Checks.NoTransitiveDependency.detect_violations/3 return_input [0]: killed

```diff
--- a/lib/anchor/domain/checks/no_transitive_dependency.ex
+++ b/lib/anchor/domain/checks/no_transitive_dependency.ex
@@ -82,9 +82,8 @@
   also returns the trees, so a test can count the walks.
   """
   @spec detect_violations(Macro.t(), [map()], map()) :: [Violation.t()]
-  def detect_violations(ast, rules, modules_map) do
-    {violations, _trees} = detect_with_trees(ast, rules, modules_map)
-    violations
+  def detect_violations(ast, _rules, _modules_map) do
+    ast
   end
 
   @doc """
```

Command: `mix test --max-cases 2 test/anchor/domain/checks/no_transitive_dependency_detector_test.exs test/anchor/domain/checks/no_transitive_dependency_parity_test.exs test/anchor/domain/checks/no_transitive_dependency_test.exs` (24 tests, 14 failures; tests selected by mirror). Failed: test/anchor/domain/checks/no_transitive_dependency_test.exs:141 test detect_violations/3 self-reference does not produce a spurious hit (self removed), test/anchor/domain/checks/no_transitive_dependency_test.exs:91 test detect_violations/3 direct dependency also counts as transitive, with no chain suffix, test/anchor/domain/checks/no_transitive_dependency_test.exs:320 test detect_violations/3 — forbidden_patterns (Gap A / DND-142) the pattern is dot-bounded transitively — AdaptersHelper does not match, test/anchor/domain/checks/no_transitive_dependency_test.exs:169 test detect_violations/3 cycle in the graph terminates and still detects, test/anchor/domain/checks/no_transitive_dependency_test.exs:283 test detect_violations/3 — forbidden_patterns (Gap A / DND-142) a reachable set with no pattern match passes, test/anchor/domain/checks/no_transitive_dependency_test.exs:298 test detect_violations/3 — forbidden_patterns (Gap A / DND-142) forbidden_modules and forbidden_patterns both fire transitively, test/anchor/domain/checks/no_transitive_dependency_test.exs:49 test detect_violations/3 flags a forbidden module reached through one intermediary (A->B->Repo), test/anchor/domain/checks/no_transitive_dependency_test.exs:263 test detect_violations/3 — forbidden_patterns (Gap A / DND-142) forbidden_patterns flags a transitively-reached adapter, test/anchor/domain/checks/no_transitive_dependency_test.exs:211 test detect_violations/3 empty forbidden list flags nothing, test/anchor/domain/checks/no_transitive_dependency_test.exs:419 test find_dependency_path/3 detect_violations/3 reports the first path in dependency order, past a shared dead end, test/anchor/domain/checks/no_transitive_dependency_test.exs:118 test detect_violations/3 chain that never reaches the forbidden module passes, test/anchor/domain/checks/no_transitive_dependency_test.exs:187 test detect_violations/3 module absent from the map yields nothing, test/anchor/domain/checks/no_transitive_dependency_test.exs:234 test detect_violations/3 no matching rules (empty rule list) flags nothing, test/anchor/domain/checks/no_transitive_dependency_test.exs:70 test detect_violations/3 flags across a two-hop chain (A->B->C->Repo)

```
test/anchor/domain/checks/no_transitive_dependency_test.exs:141 test detect_violations/3 self-reference does not produce a spurious hit (self removed)
** (ExUnit.AssertionError) 

Assertion with == failed
code:  assert NoTransitiveDependency.detect_violations(
              a_refs_b(),
              [rule([MyApp.Repo])],
              modules_map
            ) == []
left:  {:defmodule, [line: 1], [{:__aliases__, [line: 1], [:A]}, [do: {:def, [line: 2], [{:f, [line: 2], nil}, [do: {{:., [line: 2], [{:__aliases__, [line: 2], [:B]}, :call]}, [line: 2], []}]]}]]}
right: []

```

#### 2a58bbb9a6f3 Anchor.Domain.Checks.NoTransitiveDependency.detect_violations/3 return_input [1]: killed

```diff
--- a/lib/anchor/domain/checks/no_transitive_dependency.ex
+++ b/lib/anchor/domain/checks/no_transitive_dependency.ex
@@ -82,9 +82,8 @@
   also returns the trees, so a test can count the walks.
   """
   @spec detect_violations(Macro.t(), [map()], map()) :: [Violation.t()]
-  def detect_violations(ast, rules, modules_map) do
-    {violations, _trees} = detect_with_trees(ast, rules, modules_map)
-    violations
+  def detect_violations(_ast, rules, _modules_map) do
+    rules
   end
 
   @doc """
```

Command: `mix test --max-cases 2 test/anchor/domain/checks/no_transitive_dependency_detector_test.exs test/anchor/domain/checks/no_transitive_dependency_parity_test.exs test/anchor/domain/checks/no_transitive_dependency_test.exs` (24 tests, 14 failures; tests selected by mirror). Failed: test/anchor/domain/checks/no_transitive_dependency_test.exs:234 test detect_violations/3 no matching rules (empty rule list) flags nothing, test/anchor/domain/checks/no_transitive_dependency_test.exs:118 test detect_violations/3 chain that never reaches the forbidden module passes, test/anchor/domain/checks/no_transitive_dependency_test.exs:141 test detect_violations/3 self-reference does not produce a spurious hit (self removed), test/anchor/domain/checks/no_transitive_dependency_test.exs:298 test detect_violations/3 — forbidden_patterns (Gap A / DND-142) forbidden_modules and forbidden_patterns both fire transitively, test/anchor/domain/checks/no_transitive_dependency_test.exs:169 test detect_violations/3 cycle in the graph terminates and still detects, test/anchor/domain/checks/no_transitive_dependency_test.exs:187 test detect_violations/3 module absent from the map yields nothing, test/anchor/domain/checks/no_transitive_dependency_test.exs:70 test detect_violations/3 flags across a two-hop chain (A->B->C->Repo), test/anchor/domain/checks/no_transitive_dependency_test.exs:211 test detect_violations/3 empty forbidden list flags nothing, test/anchor/domain/checks/no_transitive_dependency_test.exs:49 test detect_violations/3 flags a forbidden module reached through one intermediary (A->B->Repo), test/anchor/domain/checks/no_transitive_dependency_test.exs:91 test detect_violations/3 direct dependency also counts as transitive, with no chain suffix, test/anchor/domain/checks/no_transitive_dependency_test.exs:263 test detect_violations/3 — forbidden_patterns (Gap A / DND-142) forbidden_patterns flags a transitively-reached adapter, test/anchor/domain/checks/no_transitive_dependency_test.exs:419 test find_dependency_path/3 detect_violations/3 reports the first path in dependency order, past a shared dead end, test/anchor/domain/checks/no_transitive_dependency_test.exs:320 test detect_violations/3 — forbidden_patterns (Gap A / DND-142) the pattern is dot-bounded transitively — AdaptersHelper does not match, test/anchor/domain/checks/no_transitive_dependency_test.exs:283 test detect_violations/3 — forbidden_patterns (Gap A / DND-142) a reachable set with no pattern match passes

```
test/anchor/domain/checks/no_transitive_dependency_test.exs:234 test detect_violations/3 no matching rules (empty rule list) flags nothing
** (ExUnit.AssertionError) 

match (=) failed
code:  assert [%Violation{trigger: "MyApp.Repo"}] =
              NoTransitiveDependency.detect_violations(
                a_refs_b(),
                [rule([MyApp.Repo])],
                modules_map
              )
left:  [%Anchor.Domain.Violation{trigger: "MyApp.Repo"}]
right: [%{type: :no_transitive_dependency, forbidden_modules: [MyApp.Repo]}]

```

#### 345a1ab881d7 Anchor.Domain.Checks.NoTransitiveDependency.detect_violations/3 return_input [2]: killed

```diff
--- a/lib/anchor/domain/checks/no_transitive_dependency.ex
+++ b/lib/anchor/domain/checks/no_transitive_dependency.ex
@@ -82,9 +82,8 @@
   also returns the trees, so a test can count the walks.
   """
   @spec detect_violations(Macro.t(), [map()], map()) :: [Violation.t()]
-  def detect_violations(ast, rules, modules_map) do
-    {violations, _trees} = detect_with_trees(ast, rules, modules_map)
-    violations
+  def detect_violations(_ast, _rules, modules_map) do
+    modules_map
   end
 
   @doc """
```

Command: `mix test --max-cases 2 test/anchor/domain/checks/no_transitive_dependency_detector_test.exs test/anchor/domain/checks/no_transitive_dependency_parity_test.exs test/anchor/domain/checks/no_transitive_dependency_test.exs` (24 tests, 14 failures; tests selected by mirror). Failed: test/anchor/domain/checks/no_transitive_dependency_test.exs:211 test detect_violations/3 empty forbidden list flags nothing, test/anchor/domain/checks/no_transitive_dependency_test.exs:118 test detect_violations/3 chain that never reaches the forbidden module passes, test/anchor/domain/checks/no_transitive_dependency_test.exs:320 test detect_violations/3 — forbidden_patterns (Gap A / DND-142) the pattern is dot-bounded transitively — AdaptersHelper does not match, test/anchor/domain/checks/no_transitive_dependency_test.exs:141 test detect_violations/3 self-reference does not produce a spurious hit (self removed), test/anchor/domain/checks/no_transitive_dependency_test.exs:70 test detect_violations/3 flags across a two-hop chain (A->B->C->Repo), test/anchor/domain/checks/no_transitive_dependency_test.exs:263 test detect_violations/3 — forbidden_patterns (Gap A / DND-142) forbidden_patterns flags a transitively-reached adapter, test/anchor/domain/checks/no_transitive_dependency_test.exs:91 test detect_violations/3 direct dependency also counts as transitive, with no chain suffix, test/anchor/domain/checks/no_transitive_dependency_test.exs:169 test detect_violations/3 cycle in the graph terminates and still detects, test/anchor/domain/checks/no_transitive_dependency_test.exs:419 test find_dependency_path/3 detect_violations/3 reports the first path in dependency order, past a shared dead end, test/anchor/domain/checks/no_transitive_dependency_test.exs:234 test detect_violations/3 no matching rules (empty rule list) flags nothing, test/anchor/domain/checks/no_transitive_dependency_test.exs:298 test detect_violations/3 — forbidden_patterns (Gap A / DND-142) forbidden_modules and forbidden_patterns both fire transitively, test/anchor/domain/checks/no_transitive_dependency_test.exs:187 test detect_violations/3 module absent from the map yields nothing, test/anchor/domain/checks/no_transitive_dependency_test.exs:283 test detect_violations/3 — forbidden_patterns (Gap A / DND-142) a reachable set with no pattern match passes, test/anchor/domain/checks/no_transitive_dependency_test.exs:49 test detect_violations/3 flags a forbidden module reached through one intermediary (A->B->Repo)

```
test/anchor/domain/checks/no_transitive_dependency_test.exs:211 test detect_violations/3 empty forbidden list flags nothing
** (ExUnit.AssertionError) 

Assertion with == failed
code:  assert NoTransitiveDependency.detect_violations(
              a_refs_b(),
              [rule([])],
              modules_map
            ) == []
left:  %{A => %{direct_dependencies: [B]}, B => %{direct_dependencies: [MyApp.Repo]}}
right: []

```

#### a08261e7d13f Anchor.Domain.Checks.NoTransitiveDependency.forbidden?/3 return_input [0]: killed

```diff
--- a/lib/anchor/domain/checks/no_transitive_dependency.ex
+++ b/lib/anchor/domain/checks/no_transitive_dependency.ex
@@ -131,8 +131,8 @@
   # A'-scoped to `NoDependency` and is not consulted here.
   # The patterns are compiled once per rule and module (`matches_pattern?`), not
   # once per reachable module (DND-8208).
-  defp forbidden?(module, forbidden_modules, matches_pattern?) do
-    module in forbidden_modules or matches_pattern?.(to_string(module))
+  defp forbidden?(module, _forbidden_modules, _matches_pattern?) do
+    module
   end
 
   # The path is read from the module's one search tree, and is the path
```

Command: `mix test --max-cases 2 test/anchor/domain/checks/no_transitive_dependency_detector_test.exs test/anchor/domain/checks/no_transitive_dependency_parity_test.exs test/anchor/domain/checks/no_transitive_dependency_test.exs` (24 tests, 14 failures; tests selected by kill_map). Failed: test/anchor/domain/checks/no_transitive_dependency_parity_test.exs:39 test every file's violations are identical to the pre-change detection's, on 5,000 modules, test/anchor/domain/checks/no_transitive_dependency_test.exs:169 test detect_violations/3 cycle in the graph terminates and still detects, test/anchor/domain/checks/no_transitive_dependency_test.exs:298 test detect_violations/3 — forbidden_patterns (Gap A / DND-142) forbidden_modules and forbidden_patterns both fire transitively, test/anchor/domain/checks/no_transitive_dependency_test.exs:419 test find_dependency_path/3 detect_violations/3 reports the first path in dependency order, past a shared dead end, test/anchor/domain/checks/no_transitive_dependency_test.exs:211 test detect_violations/3 empty forbidden list flags nothing, test/anchor/domain/checks/no_transitive_dependency_test.exs:187 test detect_violations/3 module absent from the map yields nothing, test/anchor/domain/checks/no_transitive_dependency_test.exs:49 test detect_violations/3 flags a forbidden module reached through one intermediary (A->B->Repo), test/anchor/domain/checks/no_transitive_dependency_test.exs:118 test detect_violations/3 chain that never reaches the forbidden module passes, test/anchor/domain/checks/no_transitive_dependency_test.exs:263 test detect_violations/3 — forbidden_patterns (Gap A / DND-142) forbidden_patterns flags a transitively-reached adapter, test/anchor/domain/checks/no_transitive_dependency_test.exs:234 test detect_violations/3 no matching rules (empty rule list) flags nothing, test/anchor/domain/checks/no_transitive_dependency_test.exs:283 test detect_violations/3 — forbidden_patterns (Gap A / DND-142) a reachable set with no pattern match passes, test/anchor/domain/checks/no_transitive_dependency_test.exs:70 test detect_violations/3 flags across a two-hop chain (A->B->C->Repo), test/anchor/domain/checks/no_transitive_dependency_test.exs:320 test detect_violations/3 — forbidden_patterns (Gap A / DND-142) the pattern is dot-bounded transitively — AdaptersHelper does not match, test/anchor/domain/checks/no_transitive_dependency_parity_test.exs:66 test each module's reachability is computed once per run: one walk per module, each module expanded once

```
test/anchor/domain/checks/no_transitive_dependency_parity_test.exs:39 test every file's violations are identical to the pre-change detection's, on 5,000 modules
** (ExUnit.AssertionError) 

Assertion with == failed
code:  assert {module, new} == {module, old}
left:  {MyApp.Domain.D2, [%Anchor.Domain.Violation{line: 2, trigger: "MyApp.Domain.D1", message: "Module has transitive dependency on forbidden module MyApp.Domain.D1. Fix: no chain of dependencies from the module reaches MyApp.Repo, MyApp.Mailer, MyApp.Adapters.*; cut the chain where it first enters a module that depends on it", filename: nil, kind: :rule, key: nil, rule_id: nil, enforcement: :enforce}, %Anchor.Domain.Violation{line: 2, trigger: "MyApp.Domain.D1", message: "Module has transitive dependency on forbidden module MyApp.Domain.D1. Fix: no chain of dependencies from the module reaches MyApp.Services.S1, MyApp.Services.S2; cut the chain where it first enters a module that depends on it", filename: nil, kind: :rule, key: nil, rule_id: nil, enforcement: :enforce}]}
right: {MyApp.Domain.D2, []}

```

#### cd05304857d5 Anchor.Domain.Checks.NoTransitiveDependency.forbidden?/3 return_input [1]: killed

```diff
--- a/lib/anchor/domain/checks/no_transitive_dependency.ex
+++ b/lib/anchor/domain/checks/no_transitive_dependency.ex
@@ -131,8 +131,8 @@
   # A'-scoped to `NoDependency` and is not consulted here.
   # The patterns are compiled once per rule and module (`matches_pattern?`), not
   # once per reachable module (DND-8208).
-  defp forbidden?(module, forbidden_modules, matches_pattern?) do
-    module in forbidden_modules or matches_pattern?.(to_string(module))
+  defp forbidden?(_module, forbidden_modules, _matches_pattern?) do
+    forbidden_modules
   end
 
   # The path is read from the module's one search tree, and is the path
```

Command: `mix test --max-cases 2 test/anchor/domain/checks/no_transitive_dependency_detector_test.exs test/anchor/domain/checks/no_transitive_dependency_parity_test.exs test/anchor/domain/checks/no_transitive_dependency_test.exs` (24 tests, 14 failures; tests selected by kill_map). Failed: test/anchor/domain/checks/no_transitive_dependency_test.exs:283 test detect_violations/3 — forbidden_patterns (Gap A / DND-142) a reachable set with no pattern match passes, test/anchor/domain/checks/no_transitive_dependency_test.exs:169 test detect_violations/3 cycle in the graph terminates and still detects, test/anchor/domain/checks/no_transitive_dependency_test.exs:263 test detect_violations/3 — forbidden_patterns (Gap A / DND-142) forbidden_patterns flags a transitively-reached adapter, test/anchor/domain/checks/no_transitive_dependency_test.exs:419 test find_dependency_path/3 detect_violations/3 reports the first path in dependency order, past a shared dead end, test/anchor/domain/checks/no_transitive_dependency_test.exs:211 test detect_violations/3 empty forbidden list flags nothing, test/anchor/domain/checks/no_transitive_dependency_test.exs:320 test detect_violations/3 — forbidden_patterns (Gap A / DND-142) the pattern is dot-bounded transitively — AdaptersHelper does not match, test/anchor/domain/checks/no_transitive_dependency_test.exs:118 test detect_violations/3 chain that never reaches the forbidden module passes, test/anchor/domain/checks/no_transitive_dependency_test.exs:70 test detect_violations/3 flags across a two-hop chain (A->B->C->Repo), test/anchor/domain/checks/no_transitive_dependency_test.exs:49 test detect_violations/3 flags a forbidden module reached through one intermediary (A->B->Repo), test/anchor/domain/checks/no_transitive_dependency_test.exs:187 test detect_violations/3 module absent from the map yields nothing, test/anchor/domain/checks/no_transitive_dependency_test.exs:234 test detect_violations/3 no matching rules (empty rule list) flags nothing, test/anchor/domain/checks/no_transitive_dependency_test.exs:298 test detect_violations/3 — forbidden_patterns (Gap A / DND-142) forbidden_modules and forbidden_patterns both fire transitively, test/anchor/domain/checks/no_transitive_dependency_parity_test.exs:66 test each module's reachability is computed once per run: one walk per module, each module expanded once, test/anchor/domain/checks/no_transitive_dependency_parity_test.exs:39 test every file's violations are identical to the pre-change detection's, on 5,000 modules

```
test/anchor/domain/checks/no_transitive_dependency_test.exs:283 test detect_violations/3 — forbidden_patterns (Gap A / DND-142) a reachable set with no pattern match passes
** (ExUnit.AssertionError) 

Assertion with == failed
code:  assert NoTransitiveDependency.detect_violations(
              a_refs_b(),
              [pattern_rule(["*.Adapters.*"])],
              modules_map
            ) == []
left:  [%Anchor.Domain.Violation{line: 2, trigger: "B", message: "Module has transitive dependency on forbidden module B. Fix: no chain of dependencies from the module reaches *.Adapters.*; cut the chain where it first enters a module that depends on it", filename: nil, kind: :rule, key: nil, rule_id: nil, enforcement: :enforce}, %Anchor.Domain.Violation{line: 2, trigger: "C", message: "Module has transitive dependency on forbidden module C (dependency chain: A -> B -> C). Fix: no chain of dependencies from the module reaches *.Adapters.*; cut the chain where it first enters a module that depends on it", filename: nil, kind: :rule, key: nil, rule_id: nil, enforcement: :enforce}]
right: []

```

#### de246b909230 Anchor.Domain.Checks.NoTransitiveDependency.forbidden?/3 return_input [2]: killed

```diff
--- a/lib/anchor/domain/checks/no_transitive_dependency.ex
+++ b/lib/anchor/domain/checks/no_transitive_dependency.ex
@@ -131,8 +131,8 @@
   # A'-scoped to `NoDependency` and is not consulted here.
   # The patterns are compiled once per rule and module (`matches_pattern?`), not
   # once per reachable module (DND-8208).
-  defp forbidden?(module, forbidden_modules, matches_pattern?) do
-    module in forbidden_modules or matches_pattern?.(to_string(module))
+  defp forbidden?(_module, _forbidden_modules, matches_pattern?) do
+    matches_pattern?
   end
 
   # The path is read from the module's one search tree, and is the path
```

Command: `mix test --max-cases 2 test/anchor/domain/checks/no_transitive_dependency_detector_test.exs test/anchor/domain/checks/no_transitive_dependency_parity_test.exs test/anchor/domain/checks/no_transitive_dependency_test.exs` (24 tests, 14 failures; tests selected by kill_map). Failed: test/anchor/domain/checks/no_transitive_dependency_parity_test.exs:39 test every file's violations are identical to the pre-change detection's, on 5,000 modules, test/anchor/domain/checks/no_transitive_dependency_test.exs:70 test detect_violations/3 flags across a two-hop chain (A->B->C->Repo), test/anchor/domain/checks/no_transitive_dependency_test.exs:320 test detect_violations/3 — forbidden_patterns (Gap A / DND-142) the pattern is dot-bounded transitively — AdaptersHelper does not match, test/anchor/domain/checks/no_transitive_dependency_test.exs:187 test detect_violations/3 module absent from the map yields nothing, test/anchor/domain/checks/no_transitive_dependency_test.exs:234 test detect_violations/3 no matching rules (empty rule list) flags nothing, test/anchor/domain/checks/no_transitive_dependency_test.exs:283 test detect_violations/3 — forbidden_patterns (Gap A / DND-142) a reachable set with no pattern match passes, test/anchor/domain/checks/no_transitive_dependency_test.exs:49 test detect_violations/3 flags a forbidden module reached through one intermediary (A->B->Repo), test/anchor/domain/checks/no_transitive_dependency_test.exs:169 test detect_violations/3 cycle in the graph terminates and still detects, test/anchor/domain/checks/no_transitive_dependency_test.exs:419 test find_dependency_path/3 detect_violations/3 reports the first path in dependency order, past a shared dead end, test/anchor/domain/checks/no_transitive_dependency_test.exs:263 test detect_violations/3 — forbidden_patterns (Gap A / DND-142) forbidden_patterns flags a transitively-reached adapter, test/anchor/domain/checks/no_transitive_dependency_test.exs:118 test detect_violations/3 chain that never reaches the forbidden module passes, test/anchor/domain/checks/no_transitive_dependency_test.exs:211 test detect_violations/3 empty forbidden list flags nothing, test/anchor/domain/checks/no_transitive_dependency_test.exs:298 test detect_violations/3 — forbidden_patterns (Gap A / DND-142) forbidden_modules and forbidden_patterns both fire transitively, test/anchor/domain/checks/no_transitive_dependency_parity_test.exs:66 test each module's reachability is computed once per run: one walk per module, each module expanded once

```
test/anchor/domain/checks/no_transitive_dependency_parity_test.exs:39 test every file's violations are identical to the pre-change detection's, on 5,000 modules
** (ExUnit.AssertionError) 

Assertion with == failed
code:  assert {module, new} == {module, old}
left:  {MyApp.Domain.D2, [%Anchor.Domain.Violation{line: 2, trigger: "MyApp.Domain.D1", message: "Module has transitive dependency on forbidden module MyApp.Domain.D1. Fix: no chain of dependencies from the module reaches MyApp.Repo, MyApp.Mailer, MyApp.Adapters.*; cut the chain where it first enters a module that depends on it", filename: nil, kind: :rule, key: nil, rule_id: nil, enforcement: :enforce}, %Anchor.Domain.Violation{line: 2, trigger: "MyApp.Domain.D1", message: "Module has transitive dependency on forbidden module MyApp.Domain.D1. Fix: no chain of dependencies from the module reaches MyApp.Services.S1, MyApp.Services.S2; cut the chain where it first enters a module that depends on it", filename: nil, kind: :rule, key: nil, rule_id: nil, enforcement: :enforce}]}
right: {MyApp.Domain.D2, []}

```

### Survivors

None.

### Kills by timeout

None.

### Skipped, invalid, not run

- skipped Anchor.Domain.Checks.NoTransitiveDependency.detect_violations/3 delete_statement `{violations, _trees} = detect_with_trees(ast, rules, modules_map)`: orphans variable `violations` bound at line 86 and used at line 87
- skipped Anchor.Domain.Checks.NoTransitiveDependency.detect_with_trees/3 delete_statement `{per_module, trees} =
  ast
  |> DependencyAnalyzer.extract_module_names()
  |> Enum.map(&violations_and_tree(DependencyTree.build(modules_map, &1), rules, ast))
  |> Enum.unzip()`: orphans variable `per_module` bound at line 98 and used at line 104
- skipped Anchor.Domain.Checks.NoTransitiveDependency.detect_with_trees/3 return_input [0] `detect_with_trees(ast, rules, modules_map)`: removes the last use of alias `DependencyAnalyzer`
- skipped Anchor.Domain.Checks.NoTransitiveDependency.detect_with_trees/3 return_input [1] `detect_with_trees(ast, rules, modules_map)`: removes the last use of alias `DependencyAnalyzer`
- skipped Anchor.Domain.Checks.NoTransitiveDependency.detect_with_trees/3 return_input [2] `detect_with_trees(ast, rules, modules_map)`: removes the last use of alias `DependencyAnalyzer`
- skipped Anchor.Domain.Checks.NoTransitiveDependency.violations_and_tree/3 return_input [0] `violations_and_tree(tree, rules, ast)`: removes the last use of function `violations_for_module/3`
- skipped Anchor.Domain.Checks.NoTransitiveDependency.violations_and_tree/3 return_input [1] `violations_and_tree(tree, rules, ast)`: removes the last use of function `violations_for_module/3`
- skipped Anchor.Domain.Checks.NoTransitiveDependency.violations_and_tree/3 return_input [2] `violations_and_tree(tree, rules, ast)`: removes the last use of function `violations_for_module/3`
- skipped Anchor.Domain.Checks.NoTransitiveDependency.violations_for_module/3 delete_statement `transitive_deps =
  tree |> DependencyTree.reachable() |> MapSet.delete(tree.start()) |> MapSet.to_list()`: orphans variable `transitive_deps` bound at line 110 and used at line 116
- skipped Anchor.Domain.Checks.NoTransitiveDependency.violations_for_module/3 delete_statement `forbidden = rule.forbidden_modules() || []`: orphans variable `forbidden` bound at line 117 and used at line 116
- skipped Anchor.Domain.Checks.NoTransitiveDependency.violations_for_module/3 delete_statement `matches_pattern? = GlobPattern.module_pattern_matcher(Map.get(rule, :forbidden_patterns) || [])`: orphans variable `matches_pattern?` bound at line 119 and used at line 116
- skipped Anchor.Domain.Checks.NoTransitiveDependency.violations_for_module/3 return_input [0] `violations_for_module(tree, rules, ast)`: removes the last use of alias `GlobPattern`
- skipped Anchor.Domain.Checks.NoTransitiveDependency.violations_for_module/3 return_input [1] `violations_for_module(tree, rules, ast)`: removes the last use of alias `GlobPattern`
- skipped Anchor.Domain.Checks.NoTransitiveDependency.violations_for_module/3 return_input [2] `violations_for_module(tree, rules, ast)`: removes the last use of alias `GlobPattern`
- skipped Anchor.Domain.Checks.NoTransitiveDependency.build_violation/3 delete_statement `path = DependencyTree.path(tree, forbidden_module)`: orphans variable `path` bound at line 141 and used at line 142
- skipped Anchor.Domain.Checks.NoTransitiveDependency.build_violation/3 delete_statement `path_description = format_dependency_path(path)`: orphans variable `path_description` bound at line 142 and used at line 149
- skipped Anchor.Domain.Checks.NoTransitiveDependency.build_violation/3 delete_statement `line = find_module_reference_line(ast, Enum.at(path, 1))`: orphans variable `line` bound at line 147 and used at line 149
- skipped Anchor.Domain.Checks.NoTransitiveDependency.build_violation/3 return_input [0] `build_violation(forbidden_module, tree, ast)`: removes the last use of function `find_module_reference_line/2`
- skipped Anchor.Domain.Checks.NoTransitiveDependency.build_violation/3 return_input [1] `build_violation(forbidden_module, tree, ast)`: removes the last use of function `find_module_reference_line/2`
- skipped Anchor.Domain.Checks.NoTransitiveDependency.build_violation/3 return_input [2] `build_violation(forbidden_module, tree, ast)`: removes the last use of function `find_module_reference_line/2`

### Tests still lacking a red

None.

### Kill map

```anchor-kills
# id	file	mfa	operator	status	killers
0a4e0f51c659	lib/anchor/domain/checks/no_transitive_dependency.ex	Anchor.Domain.Checks.NoTransitiveDependency.detect_violations/3	return_input	killed	test/anchor/domain/checks/no_transitive_dependency_test.exs:141 test detect_violations/3 self-reference does not produce a spurious hit (self removed) ; test/anchor/domain/checks/no_transitive_dependency_test.exs:91 test detect_violations/3 direct dependency also counts as transitive, with no chain suffix ; test/anchor/domain/checks/no_transitive_dependency_test.exs:320 test detect_violations/3 — forbidden_patterns (Gap A / DND-142) the pattern is dot-bounded transitively — AdaptersHelper does not match ; test/anchor/domain/checks/no_transitive_dependency_test.exs:169 test detect_violations/3 cycle in the graph terminates and still detects ; test/anchor/domain/checks/no_transitive_dependency_test.exs:283 test detect_violations/3 — forbidden_patterns (Gap A / DND-142) a reachable set with no pattern match passes ; test/anchor/domain/checks/no_transitive_dependency_test.exs:298 test detect_violations/3 — forbidden_patterns (Gap A / DND-142) forbidden_modules and forbidden_patterns both fire transitively ; test/anchor/domain/checks/no_transitive_dependency_test.exs:49 test detect_violations/3 flags a forbidden module reached through one intermediary (A->B->Repo) ; test/anchor/domain/checks/no_transitive_dependency_test.exs:263 test detect_violations/3 — forbidden_patterns (Gap A / DND-142) forbidden_patterns flags a transitively-reached adapter ; test/anchor/domain/checks/no_transitive_dependency_test.exs:211 test detect_violations/3 empty forbidden list flags nothing ; test/anchor/domain/checks/no_transitive_dependency_test.exs:419 test find_dependency_path/3 detect_violations/3 reports the first path in dependency order, past a shared dead end ; test/anchor/domain/checks/no_transitive_dependency_test.exs:118 test detect_violations/3 chain that never reaches the forbidden module passes ; test/anchor/domain/checks/no_transitive_dependency_test.exs:187 test detect_violations/3 module absent from the map yields nothing ; test/anchor/domain/checks/no_transitive_dependency_test.exs:234 test detect_violations/3 no matching rules (empty rule list) flags nothing ; test/anchor/domain/checks/no_transitive_dependency_test.exs:70 test detect_violations/3 flags across a two-hop chain (A->B->C->Repo)
2a58bbb9a6f3	lib/anchor/domain/checks/no_transitive_dependency.ex	Anchor.Domain.Checks.NoTransitiveDependency.detect_violations/3	return_input	killed	test/anchor/domain/checks/no_transitive_dependency_test.exs:234 test detect_violations/3 no matching rules (empty rule list) flags nothing ; test/anchor/domain/checks/no_transitive_dependency_test.exs:118 test detect_violations/3 chain that never reaches the forbidden module passes ; test/anchor/domain/checks/no_transitive_dependency_test.exs:141 test detect_violations/3 self-reference does not produce a spurious hit (self removed) ; test/anchor/domain/checks/no_transitive_dependency_test.exs:298 test detect_violations/3 — forbidden_patterns (Gap A / DND-142) forbidden_modules and forbidden_patterns both fire transitively ; test/anchor/domain/checks/no_transitive_dependency_test.exs:169 test detect_violations/3 cycle in the graph terminates and still detects ; test/anchor/domain/checks/no_transitive_dependency_test.exs:187 test detect_violations/3 module absent from the map yields nothing ; test/anchor/domain/checks/no_transitive_dependency_test.exs:70 test detect_violations/3 flags across a two-hop chain (A->B->C->Repo) ; test/anchor/domain/checks/no_transitive_dependency_test.exs:211 test detect_violations/3 empty forbidden list flags nothing ; test/anchor/domain/checks/no_transitive_dependency_test.exs:49 test detect_violations/3 flags a forbidden module reached through one intermediary (A->B->Repo) ; test/anchor/domain/checks/no_transitive_dependency_test.exs:91 test detect_violations/3 direct dependency also counts as transitive, with no chain suffix ; test/anchor/domain/checks/no_transitive_dependency_test.exs:263 test detect_violations/3 — forbidden_patterns (Gap A / DND-142) forbidden_patterns flags a transitively-reached adapter ; test/anchor/domain/checks/no_transitive_dependency_test.exs:419 test find_dependency_path/3 detect_violations/3 reports the first path in dependency order, past a shared dead end ; test/anchor/domain/checks/no_transitive_dependency_test.exs:320 test detect_violations/3 — forbidden_patterns (Gap A / DND-142) the pattern is dot-bounded transitively — AdaptersHelper does not match ; test/anchor/domain/checks/no_transitive_dependency_test.exs:283 test detect_violations/3 — forbidden_patterns (Gap A / DND-142) a reachable set with no pattern match passes
345a1ab881d7	lib/anchor/domain/checks/no_transitive_dependency.ex	Anchor.Domain.Checks.NoTransitiveDependency.detect_violations/3	return_input	killed	test/anchor/domain/checks/no_transitive_dependency_test.exs:211 test detect_violations/3 empty forbidden list flags nothing ; test/anchor/domain/checks/no_transitive_dependency_test.exs:118 test detect_violations/3 chain that never reaches the forbidden module passes ; test/anchor/domain/checks/no_transitive_dependency_test.exs:320 test detect_violations/3 — forbidden_patterns (Gap A / DND-142) the pattern is dot-bounded transitively — AdaptersHelper does not match ; test/anchor/domain/checks/no_transitive_dependency_test.exs:141 test detect_violations/3 self-reference does not produce a spurious hit (self removed) ; test/anchor/domain/checks/no_transitive_dependency_test.exs:70 test detect_violations/3 flags across a two-hop chain (A->B->C->Repo) ; test/anchor/domain/checks/no_transitive_dependency_test.exs:263 test detect_violations/3 — forbidden_patterns (Gap A / DND-142) forbidden_patterns flags a transitively-reached adapter ; test/anchor/domain/checks/no_transitive_dependency_test.exs:91 test detect_violations/3 direct dependency also counts as transitive, with no chain suffix ; test/anchor/domain/checks/no_transitive_dependency_test.exs:169 test detect_violations/3 cycle in the graph terminates and still detects ; test/anchor/domain/checks/no_transitive_dependency_test.exs:419 test find_dependency_path/3 detect_violations/3 reports the first path in dependency order, past a shared dead end ; test/anchor/domain/checks/no_transitive_dependency_test.exs:234 test detect_violations/3 no matching rules (empty rule list) flags nothing ; test/anchor/domain/checks/no_transitive_dependency_test.exs:298 test detect_violations/3 — forbidden_patterns (Gap A / DND-142) forbidden_modules and forbidden_patterns both fire transitively ; test/anchor/domain/checks/no_transitive_dependency_test.exs:187 test detect_violations/3 module absent from the map yields nothing ; test/anchor/domain/checks/no_transitive_dependency_test.exs:283 test detect_violations/3 — forbidden_patterns (Gap A / DND-142) a reachable set with no pattern match passes ; test/anchor/domain/checks/no_transitive_dependency_test.exs:49 test detect_violations/3 flags a forbidden module reached through one intermediary (A->B->Repo)
a08261e7d13f	lib/anchor/domain/checks/no_transitive_dependency.ex	Anchor.Domain.Checks.NoTransitiveDependency.forbidden?/3	return_input	killed	test/anchor/domain/checks/no_transitive_dependency_parity_test.exs:39 test every file's violations are identical to the pre-change detection's, on 5,000 modules ; test/anchor/domain/checks/no_transitive_dependency_test.exs:169 test detect_violations/3 cycle in the graph terminates and still detects ; test/anchor/domain/checks/no_transitive_dependency_test.exs:298 test detect_violations/3 — forbidden_patterns (Gap A / DND-142) forbidden_modules and forbidden_patterns both fire transitively ; test/anchor/domain/checks/no_transitive_dependency_test.exs:419 test find_dependency_path/3 detect_violations/3 reports the first path in dependency order, past a shared dead end ; test/anchor/domain/checks/no_transitive_dependency_test.exs:211 test detect_violations/3 empty forbidden list flags nothing ; test/anchor/domain/checks/no_transitive_dependency_test.exs:187 test detect_violations/3 module absent from the map yields nothing ; test/anchor/domain/checks/no_transitive_dependency_test.exs:49 test detect_violations/3 flags a forbidden module reached through one intermediary (A->B->Repo) ; test/anchor/domain/checks/no_transitive_dependency_test.exs:118 test detect_violations/3 chain that never reaches the forbidden module passes ; test/anchor/domain/checks/no_transitive_dependency_test.exs:263 test detect_violations/3 — forbidden_patterns (Gap A / DND-142) forbidden_patterns flags a transitively-reached adapter ; test/anchor/domain/checks/no_transitive_dependency_test.exs:234 test detect_violations/3 no matching rules (empty rule list) flags nothing ; test/anchor/domain/checks/no_transitive_dependency_test.exs:283 test detect_violations/3 — forbidden_patterns (Gap A / DND-142) a reachable set with no pattern match passes ; test/anchor/domain/checks/no_transitive_dependency_test.exs:70 test detect_violations/3 flags across a two-hop chain (A->B->C->Repo) ; test/anchor/domain/checks/no_transitive_dependency_test.exs:320 test detect_violations/3 — forbidden_patterns (Gap A / DND-142) the pattern is dot-bounded transitively — AdaptersHelper does not match ; test/anchor/domain/checks/no_transitive_dependency_parity_test.exs:66 test each module's reachability is computed once per run: one walk per module, each module expanded once
cd05304857d5	lib/anchor/domain/checks/no_transitive_dependency.ex	Anchor.Domain.Checks.NoTransitiveDependency.forbidden?/3	return_input	killed	test/anchor/domain/checks/no_transitive_dependency_test.exs:283 test detect_violations/3 — forbidden_patterns (Gap A / DND-142) a reachable set with no pattern match passes ; test/anchor/domain/checks/no_transitive_dependency_test.exs:169 test detect_violations/3 cycle in the graph terminates and still detects ; test/anchor/domain/checks/no_transitive_dependency_test.exs:263 test detect_violations/3 — forbidden_patterns (Gap A / DND-142) forbidden_patterns flags a transitively-reached adapter ; test/anchor/domain/checks/no_transitive_dependency_test.exs:419 test find_dependency_path/3 detect_violations/3 reports the first path in dependency order, past a shared dead end ; test/anchor/domain/checks/no_transitive_dependency_test.exs:211 test detect_violations/3 empty forbidden list flags nothing ; test/anchor/domain/checks/no_transitive_dependency_test.exs:320 test detect_violations/3 — forbidden_patterns (Gap A / DND-142) the pattern is dot-bounded transitively — AdaptersHelper does not match ; test/anchor/domain/checks/no_transitive_dependency_test.exs:118 test detect_violations/3 chain that never reaches the forbidden module passes ; test/anchor/domain/checks/no_transitive_dependency_test.exs:70 test detect_violations/3 flags across a two-hop chain (A->B->C->Repo) ; test/anchor/domain/checks/no_transitive_dependency_test.exs:49 test detect_violations/3 flags a forbidden module reached through one intermediary (A->B->Repo) ; test/anchor/domain/checks/no_transitive_dependency_test.exs:187 test detect_violations/3 module absent from the map yields nothing ; test/anchor/domain/checks/no_transitive_dependency_test.exs:234 test detect_violations/3 no matching rules (empty rule list) flags nothing ; test/anchor/domain/checks/no_transitive_dependency_test.exs:298 test detect_violations/3 — forbidden_patterns (Gap A / DND-142) forbidden_modules and forbidden_patterns both fire transitively ; test/anchor/domain/checks/no_transitive_dependency_parity_test.exs:66 test each module's reachability is computed once per run: one walk per module, each module expanded once ; test/anchor/domain/checks/no_transitive_dependency_parity_test.exs:39 test every file's violations are identical to the pre-change detection's, on 5,000 modules
de246b909230	lib/anchor/domain/checks/no_transitive_dependency.ex	Anchor.Domain.Checks.NoTransitiveDependency.forbidden?/3	return_input	killed	test/anchor/domain/checks/no_transitive_dependency_parity_test.exs:39 test every file's violations are identical to the pre-change detection's, on 5,000 modules ; test/anchor/domain/checks/no_transitive_dependency_test.exs:70 test detect_violations/3 flags across a two-hop chain (A->B->C->Repo) ; test/anchor/domain/checks/no_transitive_dependency_test.exs:320 test detect_violations/3 — forbidden_patterns (Gap A / DND-142) the pattern is dot-bounded transitively — AdaptersHelper does not match ; test/anchor/domain/checks/no_transitive_dependency_test.exs:187 test detect_violations/3 module absent from the map yields nothing ; test/anchor/domain/checks/no_transitive_dependency_test.exs:234 test detect_violations/3 no matching rules (empty rule list) flags nothing ; test/anchor/domain/checks/no_transitive_dependency_test.exs:283 test detect_violations/3 — forbidden_patterns (Gap A / DND-142) a reachable set with no pattern match passes ; test/anchor/domain/checks/no_transitive_dependency_test.exs:49 test detect_violations/3 flags a forbidden module reached through one intermediary (A->B->Repo) ; test/anchor/domain/checks/no_transitive_dependency_test.exs:169 test detect_violations/3 cycle in the graph terminates and still detects ; test/anchor/domain/checks/no_transitive_dependency_test.exs:419 test find_dependency_path/3 detect_violations/3 reports the first path in dependency order, past a shared dead end ; test/anchor/domain/checks/no_transitive_dependency_test.exs:263 test detect_violations/3 — forbidden_patterns (Gap A / DND-142) forbidden_patterns flags a transitively-reached adapter ; test/anchor/domain/checks/no_transitive_dependency_test.exs:118 test detect_violations/3 chain that never reaches the forbidden module passes ; test/anchor/domain/checks/no_transitive_dependency_test.exs:211 test detect_violations/3 empty forbidden list flags nothing ; test/anchor/domain/checks/no_transitive_dependency_test.exs:298 test detect_violations/3 — forbidden_patterns (Gap A / DND-142) forbidden_modules and forbidden_patterns both fire transitively ; test/anchor/domain/checks/no_transitive_dependency_parity_test.exs:66 test each module's reachability is computed once per run: one walk per module, each module expanded once
```
