# Sabotage record — the module-pattern matcher

- **Domain:** glob_pattern
- **Branch:** athena/transitive-reachability-once
- **Date:** 2026-11-27
- **Code under test:** `Anchor.Domain.GlobPattern.module_pattern_matcher/1`
  (and `matches_module_pattern?/2`, now built on it)
- **Suite run:** `mix test test/anchor/domain/dependency_tree_test.exs test/anchor/domain/checks/ test/anchor/check/no_transitive_dependency_test.exs test/anchor/domain/glob_pattern_test.exs`
  (562 tests), at commit b83b24e; each mutation applied alone, then `lib`
  restored with `git checkout`

**Which code these runs describe.** The earlier hand rounds ran on local
commits made before the branch was squashed (b83b24e, cd3ecfe, ea2e7da), and
the three generated runs below ("Run 18:27 UTC", "20:16", "23:24") on others
(c814255, 61e483f, 4c613db; 4c613db had the same tree as eed0b93, an earlier
delivery candidate). None of those commits is in the delivered history, and
the code changed after them (the targeted search moved to the oracle, a
structural guard and a Lint walk-count test were added). The code that
ships is described by the final round below, run on 22c1c82 (the change) and
dd98c9a (its guard fix), and by the generated run in
`glob_pattern-20261128-athena_transitive_reachability_once.md`, made on 22c1c82.

## Hand mutations

| # | Mutation | Tests failed | Failure string |
|---|---|---|---|
| F | Only the first pattern is compiled (`Enum.map(patterns, ...)` -> `patterns \|> Enum.take(1) \|> Enum.map(...)`) | 1 | `test module_pattern_matcher/1 (DND-8208) matches a name when any pattern matches it, in either name form` `Expected truthy, got false` `code: assert matches?.("Elixir.MyApp.Repo")` |

## Stayed green, and why

- Under **F**, the agreement row and every `matches_module_pattern?/2` row:
  each passes one pattern, which `Enum.take(1)` keeps.

## Hand mutations, second round

Same suite, at commit cd3ecfe (after review: the oracle got its own copy of
the module-name glob, the parity test also compares the work of the two, the
matcher's agreement row became a table of literal answers). Each mutation
applied alone, then `lib` and `test/support` restored with `git checkout`.

| # | Mutation | Tests failed | Failure string |
|---|---|---|---|
| I | An empty pattern list matches every name (`Enum.any?(regexes, ...)` -> `Enum.all?(regexes, ...)`) | 12 | `test module_pattern_matcher/1 (DND-8208) with no patterns, matches nothing` `Expected false or nil, got true` `code: refute GlobPattern.module_pattern_matcher([]).("Elixir.MyApp.Repo")`; the any-pattern row, the parity row, and nine `no_transitive_dependency` rows (eight in its Domain test, one in its Framework test) whose rules carry no patterns, so every reachable module became a finding |
| J | The matcher tries no name form (`module_name_forms(module_name) \|> Enum.take(0)`) | 91 | `test module_pattern_matcher/1 (DND-8208) a one-pattern matcher gives each name the documented answer` `code:  assert {name, pattern, GlobPattern.module_pattern_matcher([pattern]).(name)} == {name, pattern, expected}` `left:  {"Elixir.MyApp.Web.Foo", "MyApp.Web.*", false}` `right: {"Elixir.MyApp.Web.Foo", "MyApp.Web.*", true}`; with it every `matches_module_pattern?/2` row and both parity rows |

## Hand mutations, final round (the delivered code)

Suite: `mix test test/anchor/domain/dependency_tree_test.exs test/anchor/domain/checks/ test/anchor/check/no_transitive_dependency_test.exs test/anchor/domain/glob_pattern_test.exs test/anchor/managers/lint_transitive_walks_test.exs test/anchor/managers/lint_test.exs test/anchor/managers/lint_detector_test.exs`
(602 tests), at commit 22c1c82 unless a row says otherwise; each mutation
applied alone, then `lib` and `test/support` restored with `git checkout`.

Every string below is copied from this round's own run logs, on 22c1c82,
not from the earlier rounds.

| # | Mutation | Tests failed | Failure strings, at 22c1c82 |
|---|---|---|---|
| F | Only the first pattern is compiled | 1 | `test module_pattern_matcher/1 (DND-8208) matches a name when any pattern matches it, in either name form` `Expected truthy, got false` `code: assert matches?.("Elixir.MyApp.Repo")` |
| I | An empty pattern list matches every name | 15 | "with no patterns, matches nothing": `Expected false or nil, got true` `code: refute GlobPattern.module_pattern_matcher([]).("Elixir.MyApp.Repo")`; "matches a name when any pattern matches it": `Expected truthy, got false` `code: assert matches?.("Elixir.MyApp.Web.Foo")`; the parity row: `code:  assert {module, new} == {module, old}` `left:  {MyApp.Domain.D2, [ %Anchor.Domain.Violation{ line: 2, trigger: "MyApp.Domain.D1", message: "Module has transitive dependency on forbidden module MyApp.Domain.D1. Fix: no chain of dependencies from the module reaches MyApp.Services.S1, MyApp.Services.S2; cut the chain where it first enters a module that depends on it"` [excerpt] `right: {MyApp.Domain.D2, []}`; the other 12 by module: 8 in Anchor.Domain.Checks.NoTransitiveDependencyTest, 2 in Anchor.Managers.LintTest, 1 in Anchor.Check.NoTransitiveDependencyTest, 1 in Anchor.Managers.LintTransitiveWalksTest (rules with no patterns: every reachable module became a finding) |
| J | The matcher tries no name form | 96 | "a one-pattern matcher gives each name the documented answer": `code:  assert {name, pattern, GlobPattern.module_pattern_matcher([pattern]).(name)} == {name, pattern, expected}` `left:  {"Elixir.MyApp.Web.Foo", "MyApp.Web.*", false}` `right: {"Elixir.MyApp.Web.Foo", "MyApp.Web.*", true}`; "matches a name when any pattern matches it": `Expected truthy, got false` `code: assert matches?.("Elixir.MyApp.Web.Foo")`; the parity row: `code:  assert {module, new} == {module, old}` `left:  {MyApp.Domain.D6, [ %Anchor.Domain.Violation{ line: 3, trigger: "MyApp.Repo", message: "Module has transitive dependency on forbidden module MyApp.Repo (dependency chain: MyApp.Domain.D6 -> MyApp.Services.S3068 -> MyApp.Services.S3050 -> MyApp.Services.S3047 -> MyApp.Adapters.A140 -> MyApp.Repo).` [excerpt: the first line of a two-sided diff of D6's violations]; the 96 by module: 38 FrameworkTestMocksManagerAttributeNamesTest, 15 FrameworkTestMocksManagerTest, 13 GlobPatternTest, 11 NoDependencyTest, 5 LintTest, 4 NoDependencyAllowedCallersTest, 3 NoDiscardedPureExpressionTest, 2 NoTransitiveDependencyParityTest, 2 NoTransitiveDependencyTest, 1 each ModulePatternRestrictionsDetectorTest, ModulePatternRestrictionsTest, NoDependencyDetectorTest (every module-pattern caller) |

## Run 18:27 UTC

- **Code under test:** `Anchor.Domain.GlobPattern.matches_module_pattern?/2`
- **Generated by:** `mix anchor.sabotage run --base 2bf3aae61e6c2d451701c862ed8a54099ddee011 --print-survivor-lines` (Anchor 0.1.0), base 2bf3aae61e6c2d451701c862ed8a54099ddee011, head c81425542f0b14708dd77182da40a7c69f77b2a5

### Summary

| id | function | mutation | status | killers |
|---|---|---|---|---|
| 3d9ae53a8b1e | `Anchor.Domain.GlobPattern.matches_module_pattern?/2` | return_input [0] | killed | 10 |
| 6631735e5011 | `Anchor.Domain.GlobPattern.matches_module_pattern?/2` | return_input [1] | killed | 10 |

### Mutants

#### 3d9ae53a8b1e Anchor.Domain.GlobPattern.matches_module_pattern?/2 return_input [0]: killed

```diff
--- a/lib/anchor/domain/glob_pattern.ex
+++ b/lib/anchor/domain/glob_pattern.ex
@@ -74,8 +74,8 @@
   forbidding by one checked nothing.
   """
   @spec matches_module_pattern?(String.t(), String.t()) :: boolean()
-  def matches_module_pattern?(module_name, pattern),
-    do: module_pattern_matcher([pattern]).(module_name)
+  def matches_module_pattern?(module_name, _pattern),
+    do: module_name
 
   @doc """
   A predicate that is `true` for a module name matching any of `patterns`, as
```

Command: `mix test --max-cases 2 test/anchor/domain/glob_pattern_test.exs` (51 tests, 10 failures; tests selected by mirror). Failed: test/anchor/domain/glob_pattern_test.exs:128 test module_pattern_matcher/1 (DND-8208) agrees with matches_module_pattern?/2 on every name and pattern, test/anchor/domain/glob_pattern_test.exs:295 test the documented glob syntax still holds (DND-1292) module `*` crosses dots, and dots stay literal, test/anchor/domain/glob_pattern_test.exs:104 test matches_module_pattern?/2 (alias-form patterns, DND-1290) an alias-form pattern still does not match a different module, test/anchor/domain/glob_pattern_test.exs:83 test matches_module_pattern?/2 (module-name glob) #5 literal dots are escaped, test/anchor/domain/glob_pattern_test.exs:205 test regex metacharacters are literal (DND-1292) module: a metacharacter after a `*` is literal, test/anchor/domain/glob_pattern_test.exs:260 test regex metacharacters are literal (DND-1292) the match is anchored at the very end: a trailing newline is not ignored, test/anchor/domain/glob_pattern_test.exs:217 test regex metacharacters are literal (DND-1292) module: a regex construct is a literal string, test/anchor/domain/glob_pattern_test.exs:193 test regex metacharacters are literal (DND-1292) module: a metacharacter matches only itself, test/anchor/domain/glob_pattern_test.exs:79 test matches_module_pattern?/2 (module-name glob) #4 non-match, test/anchor/domain/glob_pattern_test.exs:109 test matches_module_pattern?/2 (alias-form patterns, DND-1290) an Erlang module name is matched as written

```
test/anchor/domain/glob_pattern_test.exs:128 test module_pattern_matcher/1 (DND-8208) agrees with matches_module_pattern?/2 on every name and pattern
** (ExUnit.AssertionError) 

Assertion with == failed
code:  assert {name, pattern, GlobPattern.module_pattern_matcher([pattern]).(name)} ==
              {name, pattern, GlobPattern.matches_module_pattern?(name, pattern)}
left:  {"Elixir.MyApp.Web.Foo", "MyApp.Web.*", true}
right: {"Elixir.MyApp.Web.Foo", "MyApp.Web.*", "Elixir.MyApp.Web.Foo"}

```

#### 6631735e5011 Anchor.Domain.GlobPattern.matches_module_pattern?/2 return_input [1]: killed

```diff
--- a/lib/anchor/domain/glob_pattern.ex
+++ b/lib/anchor/domain/glob_pattern.ex
@@ -74,8 +74,8 @@
   forbidding by one checked nothing.
   """
   @spec matches_module_pattern?(String.t(), String.t()) :: boolean()
-  def matches_module_pattern?(module_name, pattern),
-    do: module_pattern_matcher([pattern]).(module_name)
+  def matches_module_pattern?(_module_name, pattern),
+    do: pattern
 
   @doc """
   A predicate that is `true` for a module name matching any of `patterns`, as
```

Command: `mix test --max-cases 2 test/anchor/domain/glob_pattern_test.exs` (51 tests, 10 failures; tests selected by mirror). Failed: test/anchor/domain/glob_pattern_test.exs:260 test regex metacharacters are literal (DND-1292) the match is anchored at the very end: a trailing newline is not ignored, test/anchor/domain/glob_pattern_test.exs:79 test matches_module_pattern?/2 (module-name glob) #4 non-match, test/anchor/domain/glob_pattern_test.exs:193 test regex metacharacters are literal (DND-1292) module: a metacharacter matches only itself, test/anchor/domain/glob_pattern_test.exs:128 test module_pattern_matcher/1 (DND-8208) agrees with matches_module_pattern?/2 on every name and pattern, test/anchor/domain/glob_pattern_test.exs:109 test matches_module_pattern?/2 (alias-form patterns, DND-1290) an Erlang module name is matched as written, test/anchor/domain/glob_pattern_test.exs:295 test the documented glob syntax still holds (DND-1292) module `*` crosses dots, and dots stay literal, test/anchor/domain/glob_pattern_test.exs:83 test matches_module_pattern?/2 (module-name glob) #5 literal dots are escaped, test/anchor/domain/glob_pattern_test.exs:217 test regex metacharacters are literal (DND-1292) module: a regex construct is a literal string, test/anchor/domain/glob_pattern_test.exs:205 test regex metacharacters are literal (DND-1292) module: a metacharacter after a `*` is literal, test/anchor/domain/glob_pattern_test.exs:104 test matches_module_pattern?/2 (alias-form patterns, DND-1290) an alias-form pattern still does not match a different module

```
test/anchor/domain/glob_pattern_test.exs:260 test regex metacharacters are literal (DND-1292) the match is anchored at the very end: a trailing newline is not ignored
** (ExUnit.AssertionError) 

Assertion with == failed
code:  assert row_failure(flavor, "a", "a\n", false) == nil
left:  "module: glob \"a\" on \"a\\n\": want false, got \"a\""
right: nil

```

### Survivors

None.

### Kills by timeout

None.

### Skipped, invalid, not run

- skipped Anchor.Domain.GlobPattern.module_pattern_matcher/1 delete_statement `regexes = Enum.map(patterns, &to_regex(&1, :module))`: orphans variable `regexes` bound at line 88 and used at line 92
- skipped Anchor.Domain.GlobPattern.module_pattern_matcher/1 delete_statement `forms = module_name_forms(module_name)`: orphans variable `forms` bound at line 91 and used at line 92
- skipped Anchor.Domain.GlobPattern.module_pattern_matcher/1 return_input [0] `module_pattern_matcher(patterns)`: removes the last use of function `module_name_forms/1`

### Tests still lacking a red

None.

### Kill map

```anchor-kills
# id	file	mfa	operator	status	killers
3d9ae53a8b1e	lib/anchor/domain/glob_pattern.ex	Anchor.Domain.GlobPattern.matches_module_pattern?/2	return_input	killed	test/anchor/domain/glob_pattern_test.exs:128 test module_pattern_matcher/1 (DND-8208) agrees with matches_module_pattern?/2 on every name and pattern ; test/anchor/domain/glob_pattern_test.exs:295 test the documented glob syntax still holds (DND-1292) module `*` crosses dots, and dots stay literal ; test/anchor/domain/glob_pattern_test.exs:104 test matches_module_pattern?/2 (alias-form patterns, DND-1290) an alias-form pattern still does not match a different module ; test/anchor/domain/glob_pattern_test.exs:83 test matches_module_pattern?/2 (module-name glob) #5 literal dots are escaped ; test/anchor/domain/glob_pattern_test.exs:205 test regex metacharacters are literal (DND-1292) module: a metacharacter after a `*` is literal ; test/anchor/domain/glob_pattern_test.exs:260 test regex metacharacters are literal (DND-1292) the match is anchored at the very end: a trailing newline is not ignored ; test/anchor/domain/glob_pattern_test.exs:217 test regex metacharacters are literal (DND-1292) module: a regex construct is a literal string ; test/anchor/domain/glob_pattern_test.exs:193 test regex metacharacters are literal (DND-1292) module: a metacharacter matches only itself ; test/anchor/domain/glob_pattern_test.exs:79 test matches_module_pattern?/2 (module-name glob) #4 non-match ; test/anchor/domain/glob_pattern_test.exs:109 test matches_module_pattern?/2 (alias-form patterns, DND-1290) an Erlang module name is matched as written
6631735e5011	lib/anchor/domain/glob_pattern.ex	Anchor.Domain.GlobPattern.matches_module_pattern?/2	return_input	killed	test/anchor/domain/glob_pattern_test.exs:260 test regex metacharacters are literal (DND-1292) the match is anchored at the very end: a trailing newline is not ignored ; test/anchor/domain/glob_pattern_test.exs:79 test matches_module_pattern?/2 (module-name glob) #4 non-match ; test/anchor/domain/glob_pattern_test.exs:193 test regex metacharacters are literal (DND-1292) module: a metacharacter matches only itself ; test/anchor/domain/glob_pattern_test.exs:128 test module_pattern_matcher/1 (DND-8208) agrees with matches_module_pattern?/2 on every name and pattern ; test/anchor/domain/glob_pattern_test.exs:109 test matches_module_pattern?/2 (alias-form patterns, DND-1290) an Erlang module name is matched as written ; test/anchor/domain/glob_pattern_test.exs:295 test the documented glob syntax still holds (DND-1292) module `*` crosses dots, and dots stay literal ; test/anchor/domain/glob_pattern_test.exs:83 test matches_module_pattern?/2 (module-name glob) #5 literal dots are escaped ; test/anchor/domain/glob_pattern_test.exs:217 test regex metacharacters are literal (DND-1292) module: a regex construct is a literal string ; test/anchor/domain/glob_pattern_test.exs:205 test regex metacharacters are literal (DND-1292) module: a metacharacter after a `*` is literal ; test/anchor/domain/glob_pattern_test.exs:104 test matches_module_pattern?/2 (alias-form patterns, DND-1290) an alias-form pattern still does not match a different module
```

## Run 20:16 UTC

- **Code under test:** `Anchor.Domain.GlobPattern.matches_module_pattern?/2`
- **Generated by:** `mix anchor.sabotage run --base 2bf3aae61e6c2d451701c862ed8a54099ddee011 --print-survivor-lines` (Anchor 0.1.0), base 2bf3aae61e6c2d451701c862ed8a54099ddee011, head 61e483f7d6aef1c94dfbb7b1a4f3401b07c54bad

### Summary

| id | function | mutation | status | killers |
|---|---|---|---|---|
| 3d9ae53a8b1e | `Anchor.Domain.GlobPattern.matches_module_pattern?/2` | return_input [0] | killed | 9 |
| 6631735e5011 | `Anchor.Domain.GlobPattern.matches_module_pattern?/2` | return_input [1] | killed | 9 |

### Mutants

#### 3d9ae53a8b1e Anchor.Domain.GlobPattern.matches_module_pattern?/2 return_input [0]: killed

```diff
--- a/lib/anchor/domain/glob_pattern.ex
+++ b/lib/anchor/domain/glob_pattern.ex
@@ -74,8 +74,8 @@
   forbidding by one checked nothing.
   """
   @spec matches_module_pattern?(String.t(), String.t()) :: boolean()
-  def matches_module_pattern?(module_name, pattern),
-    do: module_pattern_matcher([pattern]).(module_name)
+  def matches_module_pattern?(module_name, _pattern),
+    do: module_name
 
   @doc """
   A predicate that is `true` for a module name matching any of `patterns`, as
```

Command: `mix test --max-cases 2 test/anchor/domain/glob_pattern_test.exs` (51 tests, 9 failures; tests selected by kill_map). Failed: test/anchor/domain/glob_pattern_test.exs:109 test matches_module_pattern?/2 (alias-form patterns, DND-1290) an Erlang module name is matched as written, test/anchor/domain/glob_pattern_test.exs:300 test the documented glob syntax still holds (DND-1292) module `*` crosses dots, and dots stay literal, test/anchor/domain/glob_pattern_test.exs:104 test matches_module_pattern?/2 (alias-form patterns, DND-1290) an alias-form pattern still does not match a different module, test/anchor/domain/glob_pattern_test.exs:83 test matches_module_pattern?/2 (module-name glob) #5 literal dots are escaped, test/anchor/domain/glob_pattern_test.exs:222 test regex metacharacters are literal (DND-1292) module: a regex construct is a literal string, test/anchor/domain/glob_pattern_test.exs:265 test regex metacharacters are literal (DND-1292) the match is anchored at the very end: a trailing newline is not ignored, test/anchor/domain/glob_pattern_test.exs:210 test regex metacharacters are literal (DND-1292) module: a metacharacter after a `*` is literal, test/anchor/domain/glob_pattern_test.exs:79 test matches_module_pattern?/2 (module-name glob) #4 non-match, test/anchor/domain/glob_pattern_test.exs:198 test regex metacharacters are literal (DND-1292) module: a metacharacter matches only itself

```
test/anchor/domain/glob_pattern_test.exs:109 test matches_module_pattern?/2 (alias-form patterns, DND-1290) an Erlang module name is matched as written
** (ExUnit.AssertionError) 

Expected false or nil, got "telemetry"
code: refute GlobPattern.matches_module_pattern?("telemetry", "Elixir.telemetry")

```

#### 6631735e5011 Anchor.Domain.GlobPattern.matches_module_pattern?/2 return_input [1]: killed

```diff
--- a/lib/anchor/domain/glob_pattern.ex
+++ b/lib/anchor/domain/glob_pattern.ex
@@ -74,8 +74,8 @@
   forbidding by one checked nothing.
   """
   @spec matches_module_pattern?(String.t(), String.t()) :: boolean()
-  def matches_module_pattern?(module_name, pattern),
-    do: module_pattern_matcher([pattern]).(module_name)
+  def matches_module_pattern?(_module_name, pattern),
+    do: pattern
 
   @doc """
   A predicate that is `true` for a module name matching any of `patterns`, as
```

Command: `mix test --max-cases 2 test/anchor/domain/glob_pattern_test.exs` (51 tests, 9 failures; tests selected by kill_map). Failed: test/anchor/domain/glob_pattern_test.exs:79 test matches_module_pattern?/2 (module-name glob) #4 non-match, test/anchor/domain/glob_pattern_test.exs:222 test regex metacharacters are literal (DND-1292) module: a regex construct is a literal string, test/anchor/domain/glob_pattern_test.exs:198 test regex metacharacters are literal (DND-1292) module: a metacharacter matches only itself, test/anchor/domain/glob_pattern_test.exs:265 test regex metacharacters are literal (DND-1292) the match is anchored at the very end: a trailing newline is not ignored, test/anchor/domain/glob_pattern_test.exs:104 test matches_module_pattern?/2 (alias-form patterns, DND-1290) an alias-form pattern still does not match a different module, test/anchor/domain/glob_pattern_test.exs:210 test regex metacharacters are literal (DND-1292) module: a metacharacter after a `*` is literal, test/anchor/domain/glob_pattern_test.exs:109 test matches_module_pattern?/2 (alias-form patterns, DND-1290) an Erlang module name is matched as written, test/anchor/domain/glob_pattern_test.exs:300 test the documented glob syntax still holds (DND-1292) module `*` crosses dots, and dots stay literal, test/anchor/domain/glob_pattern_test.exs:83 test matches_module_pattern?/2 (module-name glob) #5 literal dots are escaped

```
test/anchor/domain/glob_pattern_test.exs:79 test matches_module_pattern?/2 (module-name glob) #4 non-match
** (ExUnit.AssertionError) 

Expected false or nil, got "*.Schemas.*"
code: refute GlobPattern.matches_module_pattern?("App.Service", "*.Schemas.*")

```

### Survivors

None.

### Kills by timeout

None.

### Skipped, invalid, not run

- skipped Anchor.Domain.GlobPattern.module_pattern_matcher/1 delete_statement `regexes = Enum.map(patterns, &to_regex(&1, :module))`: orphans variable `regexes` bound at line 88 and used at line 92
- skipped Anchor.Domain.GlobPattern.module_pattern_matcher/1 delete_statement `forms = module_name_forms(module_name)`: orphans variable `forms` bound at line 91 and used at line 92
- skipped Anchor.Domain.GlobPattern.module_pattern_matcher/1 return_input [0] `module_pattern_matcher(patterns)`: removes the last use of function `module_name_forms/1`

### Tests still lacking a red

None.

### Kill map

```anchor-kills
# id	file	mfa	operator	status	killers
3d9ae53a8b1e	lib/anchor/domain/glob_pattern.ex	Anchor.Domain.GlobPattern.matches_module_pattern?/2	return_input	killed	test/anchor/domain/glob_pattern_test.exs:109 test matches_module_pattern?/2 (alias-form patterns, DND-1290) an Erlang module name is matched as written ; test/anchor/domain/glob_pattern_test.exs:300 test the documented glob syntax still holds (DND-1292) module `*` crosses dots, and dots stay literal ; test/anchor/domain/glob_pattern_test.exs:104 test matches_module_pattern?/2 (alias-form patterns, DND-1290) an alias-form pattern still does not match a different module ; test/anchor/domain/glob_pattern_test.exs:83 test matches_module_pattern?/2 (module-name glob) #5 literal dots are escaped ; test/anchor/domain/glob_pattern_test.exs:222 test regex metacharacters are literal (DND-1292) module: a regex construct is a literal string ; test/anchor/domain/glob_pattern_test.exs:265 test regex metacharacters are literal (DND-1292) the match is anchored at the very end: a trailing newline is not ignored ; test/anchor/domain/glob_pattern_test.exs:210 test regex metacharacters are literal (DND-1292) module: a metacharacter after a `*` is literal ; test/anchor/domain/glob_pattern_test.exs:79 test matches_module_pattern?/2 (module-name glob) #4 non-match ; test/anchor/domain/glob_pattern_test.exs:198 test regex metacharacters are literal (DND-1292) module: a metacharacter matches only itself
6631735e5011	lib/anchor/domain/glob_pattern.ex	Anchor.Domain.GlobPattern.matches_module_pattern?/2	return_input	killed	test/anchor/domain/glob_pattern_test.exs:79 test matches_module_pattern?/2 (module-name glob) #4 non-match ; test/anchor/domain/glob_pattern_test.exs:222 test regex metacharacters are literal (DND-1292) module: a regex construct is a literal string ; test/anchor/domain/glob_pattern_test.exs:198 test regex metacharacters are literal (DND-1292) module: a metacharacter matches only itself ; test/anchor/domain/glob_pattern_test.exs:265 test regex metacharacters are literal (DND-1292) the match is anchored at the very end: a trailing newline is not ignored ; test/anchor/domain/glob_pattern_test.exs:104 test matches_module_pattern?/2 (alias-form patterns, DND-1290) an alias-form pattern still does not match a different module ; test/anchor/domain/glob_pattern_test.exs:210 test regex metacharacters are literal (DND-1292) module: a metacharacter after a `*` is literal ; test/anchor/domain/glob_pattern_test.exs:109 test matches_module_pattern?/2 (alias-form patterns, DND-1290) an Erlang module name is matched as written ; test/anchor/domain/glob_pattern_test.exs:300 test the documented glob syntax still holds (DND-1292) module `*` crosses dots, and dots stay literal ; test/anchor/domain/glob_pattern_test.exs:83 test matches_module_pattern?/2 (module-name glob) #5 literal dots are escaped
```

## Run 23:24 UTC

- **Code under test:** `Anchor.Domain.GlobPattern.matches_module_pattern?/2`
- **Generated by:** `mix anchor.sabotage run --base 2bf3aae61e6c2d451701c862ed8a54099ddee011 --print-survivor-lines` (Anchor 0.1.0), base 2bf3aae61e6c2d451701c862ed8a54099ddee011, head 4c613db48e96344ee1e37dc4e0d3fd4a5b179765

### Summary

| id | function | mutation | status | killers |
|---|---|---|---|---|
| 3d9ae53a8b1e | `Anchor.Domain.GlobPattern.matches_module_pattern?/2` | return_input [0] | killed | 9 |
| 6631735e5011 | `Anchor.Domain.GlobPattern.matches_module_pattern?/2` | return_input [1] | killed | 9 |

### Mutants

#### 3d9ae53a8b1e Anchor.Domain.GlobPattern.matches_module_pattern?/2 return_input [0]: killed

```diff
--- a/lib/anchor/domain/glob_pattern.ex
+++ b/lib/anchor/domain/glob_pattern.ex
@@ -74,8 +74,8 @@
   forbidding by one checked nothing.
   """
   @spec matches_module_pattern?(String.t(), String.t()) :: boolean()
-  def matches_module_pattern?(module_name, pattern),
-    do: module_pattern_matcher([pattern]).(module_name)
+  def matches_module_pattern?(module_name, _pattern),
+    do: module_name
 
   @doc """
   A predicate that is `true` for a module name matching any of `patterns`, as
```

Command: `mix test --max-cases 2 test/anchor/domain/glob_pattern_test.exs` (51 tests, 9 failures; tests selected by kill_map). Failed: test/anchor/domain/glob_pattern_test.exs:198 test regex metacharacters are literal (DND-1292) module: a metacharacter matches only itself, test/anchor/domain/glob_pattern_test.exs:265 test regex metacharacters are literal (DND-1292) the match is anchored at the very end: a trailing newline is not ignored, test/anchor/domain/glob_pattern_test.exs:104 test matches_module_pattern?/2 (alias-form patterns, DND-1290) an alias-form pattern still does not match a different module, test/anchor/domain/glob_pattern_test.exs:83 test matches_module_pattern?/2 (module-name glob) #5 literal dots are escaped, test/anchor/domain/glob_pattern_test.exs:109 test matches_module_pattern?/2 (alias-form patterns, DND-1290) an Erlang module name is matched as written, test/anchor/domain/glob_pattern_test.exs:222 test regex metacharacters are literal (DND-1292) module: a regex construct is a literal string, test/anchor/domain/glob_pattern_test.exs:210 test regex metacharacters are literal (DND-1292) module: a metacharacter after a `*` is literal, test/anchor/domain/glob_pattern_test.exs:300 test the documented glob syntax still holds (DND-1292) module `*` crosses dots, and dots stay literal, test/anchor/domain/glob_pattern_test.exs:79 test matches_module_pattern?/2 (module-name glob) #4 non-match

```
test/anchor/domain/glob_pattern_test.exs:198 test regex metacharacters are literal (DND-1292) module: a metacharacter matches only itself
** (ExUnit.AssertionError) 

module: glob "a.b" on "a.b": want true, got "a.b"
     module: glob "a.b" on "ab": want false, got "ab"
     module: glob "a.b" on "aXb": want false, got "aXb"
     module: glob "a.b" on "a..b": want false, got "a..b"
     module: glob "a.b" on "aab": want false, got "aab"
     module: glob "a\\b" on "a\\b": want true, got "a\\b"
     module: glob "a\\b" on "ab": want false, got "ab"
     module: glob "a\\b" on "aXb": want false, got "aXb"
     module: glob "a\\b" on "a\\\\b": want false, got "a\\\\b"
     module: glob "a\\b" on "aab": want false, got "aab"
     module: glob "a+b" on "a+b": want true, got "a+b"
     module: glob "a+b" on "ab": want false, got "ab"
     module: glob "a+b" on "aXb": want false, got "aXb"
     module: glob "a+b" on "a++b": want false, got "a++b"
     module: glob "a+b" on "aab": want false, got "aab"
     module: glob "a?b" on "a?b": want true, got "a?b"
     module: glob "a?b" on "ab": want false, got "ab"
     module: glob "a?b" on "aXb": want false, got "aXb"
     module: glob "a?b" on "a??b": want false, got "a??b"
     module: glob "a?b" on "aab": want false, got "aab"
     module: glob "a[b" on "a[b": want true, got "a[b"
     module: glob "a[b" on "ab": want false, got "ab"
     module: glob "a[b" on "aXb": want false, got "aXb"
     module: glob "a[b" on "a[[b": want false, got "a[[b"
     module: glob "a[b" on "aab": want false, got "aab"
     module: glob "a]b" on "a]b": want true, got "a]b"
     module: glob "a]b" on "ab": want false, got "ab"
     module: glob "a]b" on "aXb": want false, got "aXb"
     module: glob "a]b" on "a]]b": want false, got "a]]b"
     module: glob "a]b" on "aab": want false, got "aab"
     module: glob "a^b" on "a^b": want true, got "a^b"
     module: glob "a^b" on "ab": want false, got "ab"
     module: glob "a^b" on "aXb": want false, got "aXb"
     module: glob "a^b" on "a^^b": want false, got "a^^b"
     module: glob "a^b" on "aab": want false, got "aab"
     module:
```

#### 6631735e5011 Anchor.Domain.GlobPattern.matches_module_pattern?/2 return_input [1]: killed

```diff
--- a/lib/anchor/domain/glob_pattern.ex
+++ b/lib/anchor/domain/glob_pattern.ex
@@ -74,8 +74,8 @@
   forbidding by one checked nothing.
   """
   @spec matches_module_pattern?(String.t(), String.t()) :: boolean()
-  def matches_module_pattern?(module_name, pattern),
-    do: module_pattern_matcher([pattern]).(module_name)
+  def matches_module_pattern?(_module_name, pattern),
+    do: pattern
 
   @doc """
   A predicate that is `true` for a module name matching any of `patterns`, as
```

Command: `mix test --max-cases 2 test/anchor/domain/glob_pattern_test.exs` (51 tests, 9 failures; tests selected by kill_map). Failed: test/anchor/domain/glob_pattern_test.exs:210 test regex metacharacters are literal (DND-1292) module: a metacharacter after a `*` is literal, test/anchor/domain/glob_pattern_test.exs:265 test regex metacharacters are literal (DND-1292) the match is anchored at the very end: a trailing newline is not ignored, test/anchor/domain/glob_pattern_test.exs:79 test matches_module_pattern?/2 (module-name glob) #4 non-match, test/anchor/domain/glob_pattern_test.exs:109 test matches_module_pattern?/2 (alias-form patterns, DND-1290) an Erlang module name is matched as written, test/anchor/domain/glob_pattern_test.exs:83 test matches_module_pattern?/2 (module-name glob) #5 literal dots are escaped, test/anchor/domain/glob_pattern_test.exs:300 test the documented glob syntax still holds (DND-1292) module `*` crosses dots, and dots stay literal, test/anchor/domain/glob_pattern_test.exs:104 test matches_module_pattern?/2 (alias-form patterns, DND-1290) an alias-form pattern still does not match a different module, test/anchor/domain/glob_pattern_test.exs:198 test regex metacharacters are literal (DND-1292) module: a metacharacter matches only itself, test/anchor/domain/glob_pattern_test.exs:222 test regex metacharacters are literal (DND-1292) module: a regex construct is a literal string

```
test/anchor/domain/glob_pattern_test.exs:210 test regex metacharacters are literal (DND-1292) module: a metacharacter after a `*` is literal
** (ExUnit.AssertionError) 

module: glob "x*." on "xy.": want true, got "x*."
     module: glob "x*." on "x.": want true, got "x*."
     module: glob "x*." on "xy": want false, got "x*."
     module: glob "x*\\" on "xy\\": want true, got "x*\\"
     module: glob "x*\\" on "x\\": want true, got "x*\\"
     module: glob "x*\\" on "xy": want false, got "x*\\"
     module: glob "x*+" on "xy+": want true, got "x*+"
     module: glob "x*+" on "x+": want true, got "x*+"
     module: glob "x*+" on "xy": want false, got "x*+"
     module: glob "x*?" on "xy?": want true, got "x*?"
     module: glob "x*?" on "x?": want true, got "x*?"
     module: glob "x*?" on "xy": want false, got "x*?"
     module: glob "x*[" on "xy[": want true, got "x*["
     module: glob "x*[" on "x[": want true, got "x*["
     module: glob "x*[" on "xy": want false, got "x*["
     module: glob "x*]" on "xy]": want true, got "x*]"
     module: glob "x*]" on "x]": want true, got "x*]"
     module: glob "x*]" on "xy": want false, got "x*]"
     module: glob "x*^" on "xy^": want true, got "x*^"
     module: glob "x*^" on "x^": want true, got "x*^"
     module: glob "x*^" on "xy": want false, got "x*^"
     module: glob "x*$" on "xy$": want true, got "x*$"
     module: glob "x*$" on "x$": want true, got "x*$"
     module: glob "x*$" on "xy": want false, got "x*$"
     module: glob "x*(" on "xy(": want true, got "x*("
     module: glob "x*(" on "x(": want true, got "x*("
     module: glob "x*(" on "xy": want false, got "x*("
     module: glob "x*)" on "xy)": want true, got "x*)"
     module: glob "x*)" on "x)": want true, got "x*)"
     module: glob "x*)" on "xy": want false, got "x*)"
     module: glob "x*{" on "xy{": want true, got "x*{"
     module: glob "x*{" on "x{": want true, got "x*{"
     module: glob "x*{" on "xy": want false, got "x*{"
     module: glob "x*}" on "xy}": want true, got "x*}"
     module: glob "x*}" on "x}": want true, got "x*}"
     module: glob "x*}" on "xy": want false, got "x*}"

```

### Survivors

None.

### Kills by timeout

None.

### Skipped, invalid, not run

- skipped Anchor.Domain.GlobPattern.module_pattern_matcher/1 delete_statement `regexes = Enum.map(patterns, &to_regex(&1, :module))`: orphans variable `regexes` bound at line 88 and used at line 92
- skipped Anchor.Domain.GlobPattern.module_pattern_matcher/1 delete_statement `forms = module_name_forms(module_name)`: orphans variable `forms` bound at line 91 and used at line 92
- skipped Anchor.Domain.GlobPattern.module_pattern_matcher/1 return_input [0] `module_pattern_matcher(patterns)`: removes the last use of function `module_name_forms/1`

### Tests still lacking a red

None.

### Kill map

```anchor-kills
# id	file	mfa	operator	status	killers
3d9ae53a8b1e	lib/anchor/domain/glob_pattern.ex	Anchor.Domain.GlobPattern.matches_module_pattern?/2	return_input	killed	test/anchor/domain/glob_pattern_test.exs:198 test regex metacharacters are literal (DND-1292) module: a metacharacter matches only itself ; test/anchor/domain/glob_pattern_test.exs:265 test regex metacharacters are literal (DND-1292) the match is anchored at the very end: a trailing newline is not ignored ; test/anchor/domain/glob_pattern_test.exs:104 test matches_module_pattern?/2 (alias-form patterns, DND-1290) an alias-form pattern still does not match a different module ; test/anchor/domain/glob_pattern_test.exs:83 test matches_module_pattern?/2 (module-name glob) #5 literal dots are escaped ; test/anchor/domain/glob_pattern_test.exs:109 test matches_module_pattern?/2 (alias-form patterns, DND-1290) an Erlang module name is matched as written ; test/anchor/domain/glob_pattern_test.exs:222 test regex metacharacters are literal (DND-1292) module: a regex construct is a literal string ; test/anchor/domain/glob_pattern_test.exs:210 test regex metacharacters are literal (DND-1292) module: a metacharacter after a `*` is literal ; test/anchor/domain/glob_pattern_test.exs:300 test the documented glob syntax still holds (DND-1292) module `*` crosses dots, and dots stay literal ; test/anchor/domain/glob_pattern_test.exs:79 test matches_module_pattern?/2 (module-name glob) #4 non-match
6631735e5011	lib/anchor/domain/glob_pattern.ex	Anchor.Domain.GlobPattern.matches_module_pattern?/2	return_input	killed	test/anchor/domain/glob_pattern_test.exs:210 test regex metacharacters are literal (DND-1292) module: a metacharacter after a `*` is literal ; test/anchor/domain/glob_pattern_test.exs:265 test regex metacharacters are literal (DND-1292) the match is anchored at the very end: a trailing newline is not ignored ; test/anchor/domain/glob_pattern_test.exs:79 test matches_module_pattern?/2 (module-name glob) #4 non-match ; test/anchor/domain/glob_pattern_test.exs:109 test matches_module_pattern?/2 (alias-form patterns, DND-1290) an Erlang module name is matched as written ; test/anchor/domain/glob_pattern_test.exs:83 test matches_module_pattern?/2 (module-name glob) #5 literal dots are escaped ; test/anchor/domain/glob_pattern_test.exs:300 test the documented glob syntax still holds (DND-1292) module `*` crosses dots, and dots stay literal ; test/anchor/domain/glob_pattern_test.exs:104 test matches_module_pattern?/2 (alias-form patterns, DND-1290) an alias-form pattern still does not match a different module ; test/anchor/domain/glob_pattern_test.exs:198 test regex metacharacters are literal (DND-1292) module: a metacharacter matches only itself ; test/anchor/domain/glob_pattern_test.exs:222 test regex metacharacters are literal (DND-1292) module: a regex construct is a literal string
```
