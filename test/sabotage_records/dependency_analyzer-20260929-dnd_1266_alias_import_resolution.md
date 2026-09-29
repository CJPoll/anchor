# Sabotage record — alias and import resolution (DND-1266)

- **Domain:** dependency_analyzer
- **Branch:** dnd-1266-alias-import-resolution
- **Date:** 2026-09-29
- **Code under test:** `Anchor.Domain.DependencyAnalyzer`, the lexical walk behind
  `extract_direct_dependencies/1`, `extract_call_dependencies/1`,
  `dependency_lines/2`, `unresolved_directives/1` and `module_dependencies/1`
- **Suite run:** `mix test test/anchor/domain/dependency_analyzer_test.exs test/anchor/domain/checks/no_dependency_alias_resolution_test.exs test/anchor/domain/checks/no_dependency_test.exs test/anchor/check/no_dependency_test.exs` (156 tests)
- **Merge base:** `origin/main` = 6e02f3a
- **Sibling record:** `no_dependency-20260929-dnd_1266_alias_import_resolution.md`
  holds the mutations to `Anchor.Domain.Checks.NoDependency` (H, P, R).

## Fail-first runs

### Round 1: the new tests against `origin/main` production code

`477 tests, 38 failures`. Every failure was a new DND-1266 test. Verbatim samples:

```
  1) test alias and import resolution (DND-1266) reference mode records a multi-alias's full names, not its prefix or short names (Anchor.Domain.DependencyAnalyzerTest)
     test/anchor/domain/dependency_analyzer_test.exs:504
     Assertion with == failed
     code:  assert DependencyAnalyzer.extract_direct_dependencies(ast(src)) == [A.B, A.C]
     left:  [A, B, C]
     right: [A.B, A.C]

  3) test alias and import resolution (DND-1266) call mode resolves an aliased call to the full module (Anchor.Domain.DependencyAnalyzerTest)
     test/anchor/domain/dependency_analyzer_test.exs:526
     Assertion with == failed
     code:  assert DependencyAnalyzer.extract_call_dependencies(ast(src)) == [A.B]
     left:  [B]
     right: [A.B]

 16) test an aliased target is reported (match: reference) multi-alias alias A.{B, C} then B.f() and C.f() (Anchor.Domain.Checks.NoDependencyAliasResolutionTest)
     test/anchor/domain/checks/no_dependency_alias_resolution_test.exs:59
     Assertion with == failed
     code:  assert triggers(source, [Forbidden.Target, Forbidden.Other], mode) == [
              "Forbidden.Other",
              "Forbidden.Target"
            ]
     left:  []
     right: ["Forbidden.Other", "Forbidden.Target"]

 22) test an aliased target is reported (match: call) alias A.B then B.f() (Anchor.Domain.Checks.NoDependencyAliasResolutionTest)
     test/anchor/domain/checks/no_dependency_alias_resolution_test.exs:35
     Assertion with == failed
     code:  assert triggers(source, [Forbidden.Target], mode) == ["Forbidden.Target"]
     left:  []
     right: ["Forbidden.Target"]

 25) test an aliased target is reported (match: call) import A.B then bare f() (Anchor.Domain.Checks.NoDependencyAliasResolutionTest)
     test/anchor/domain/checks/no_dependency_alias_resolution_test.exs:172
     Assertion with == failed
     code:  assert triggers(source, [Forbidden.Target], mode) == ["Forbidden.Target"]
     left:  []
     right: ["Forbidden.Target"]
```

Tests that passed on the unfixed code, and why. In `match: reference`, `alias A.B`,
`as:`, `require ... as:`, outer-module aliases, `__MODULE__` aliases and every
`import` form were already reported through the directive line itself. The
negative rows (a same-named module, the scope-leak rows, "applies only after it is
declared") also passed, because the unfixed code resolved nothing. None of these
rows was accepted on the fail-first run alone: each is re-reddened by a mutation
below (A, J, L, M, N or P).

### Round 2: review-round tests against the first fix commit (d92b5a0)

`62 tests, 3 failures` (alias-resolution test file only). The analyzer row:

```
  1) test import only:/except: narrow which bare calls resolve (match: :call) import Kernel, except: hands a Kernel name to an unrestricted import (Anchor.Domain.Checks.NoDependencyAliasResolutionTest)
     test/anchor/domain/checks/no_dependency_alias_resolution_test.exs:410
     Assertion with == failed
     code:  assert triggers(source, [Forbidden.Target], :call) == ["Forbidden.Target"]
     left:  []
     right: ["Forbidden.Target"]
```

The other two rows are the `no_dependency` once-per-file rows (sibling record).

## Mutations

The fixed code was committed first (6af52db). Each mutation was applied alone and
restored with `git checkout -- <file>`. Every mutation compiled under
`--warnings-as-errors`. A first attempt at B and at J left a private function
unused and failed to **compile**. ADR 002 says that is not a test failure, so
both were rewritten to keep the function referenced and re-run. The counts below
are from the final run.

| # | Mutation | Tests failed |
|---|---|---|
| A | `alias_bindings(:alias, ...)` binds nothing: `{[], resolved_all?(targets)}` | **12** |
| B | A multi-alias resolves every element to the base module instead of `base.Elem` | **9** |
| C | `imports?({:only, _})` ignores the `only:` list | **3** |
| D | `imports?({:except, _})` ignores the `except:` list | **1** |
| E | `nested_module_alias/2` is a no-op | **2** |
| F | `record_bare_call/5` never consults `env.locals` | **1** |
| G | `builtin_call?/3` is always `false` | **1** |
| I | A piped bare call counts `length(args)`, not `length(args) + 1` | **1** |
| J | `__block__` walks its expressions without threading the environment | **28** |
| K | A module body starts with empty aliases and imports (outer scope not inherited) | **2** |
| L | Directives leak: a block returns its final environment, and a `defmodule` hands its body's environment to its later siblings | **4** |
| M | A block pre-scans its directives, so they apply before they are declared | **1** |
| N | `put_alias/3` uses `Map.put_new` (the first alias of a short name wins) | **1** |
| O | `record_reference/4` keeps the last occurrence's line (`Map.put`) | **4** |
| Q | `filter_covers?({:except, _}, ...)` ignores the `import Kernel, except:` list | **1** |
| S | Delete the `record_unresolved/4` clause that keeps a non-literal directive inside a `quote` opaque | **2** |

### First failure per mutation, verbatim

A:
```
  1) test alias and import resolution (DND-1266) module_dependencies resolves an outer alias inside a nested module's node (Anchor.Domain.DependencyAnalyzerTest)
     test/anchor/domain/dependency_analyzer_test.exs:552
     Assertion with == failed
     code:  assert nodes[Outer.Inner].direct_dependencies == [A.B]
     left:  [B]
     right: [A.B]
```

B:
```
  1) test an aliased target is reported (match: call) multi-alias with a multi-segment element aliases its last segment (Anchor.Domain.Checks.NoDependencyAliasResolutionTest)
     test/anchor/domain/checks/no_dependency_alias_resolution_test.exs:73
     Assertion with == failed
     code:  assert triggers(source, [Forbidden.Deep.Target], mode) == ["Forbidden.Deep.Target"]
     left:  []
     right: ["Forbidden.Deep.Target"]
```

C:
```
  1) test import only:/except: narrow which bare calls resolve (match: :call) a later import of the same module replaces the earlier filter (Anchor.Domain.Checks.NoDependencyAliasResolutionTest)
     test/anchor/domain/checks/no_dependency_alias_resolution_test.exs:369
     Assertion with == failed
     code:  assert detect(source, [Forbidden.Target], :call) == []
     left:  [
              %Anchor.Domain.Violation{
                line: 5,
                trigger: "Forbidden.Target",
                message: "Module has forbidden direct dependency on Forbidden.Target"
              }
            ]
     right: []
```

D:
```
  1) test import only:/except: narrow which bare calls resolve (match: :call) except: [f: 0] does not claim f/0 (Anchor.Domain.Checks.NoDependencyAliasResolutionTest)
     test/anchor/domain/checks/no_dependency_alias_resolution_test.exs:357
     Assertion with == failed
     code:  assert detect(source, [Forbidden.Target], :call) == []
     left:  [
              %Anchor.Domain.Violation{
                line: 4,
                trigger: "Forbidden.Target",
                message: "Module has forbidden direct dependency on Forbidden.Target"
              }
            ]
     right: []
```

E:
```
  1) test an aliased target is reported (match: reference) a nested defmodule aliases its name in the enclosing module (Anchor.Domain.Checks.NoDependencyAliasResolutionTest)
     test/anchor/domain/checks/no_dependency_alias_resolution_test.exs:136
     Assertion with == failed
     code:  assert triggers(source, [Outer.Target], mode) == ["Outer.Target"]
     left:  []
     right: ["Outer.Target"]
```

F:
```
  1) test import only:/except: narrow which bare calls resolve (match: :call) a local function is not claimed by an unrestricted import (Anchor.Domain.Checks.NoDependencyAliasResolutionTest)
     test/anchor/domain/checks/no_dependency_alias_resolution_test.exs:382
     Assertion with == failed
     code:  assert detect(source, [Forbidden.Target], :call) == []
     left:  [
              %Anchor.Domain.Violation{
                line: 4,
                trigger: "Forbidden.Target",
                message: "Module has forbidden direct dependency on Forbidden.Target"
              }
            ]
     right: []
```

G:
```
  1) test import only:/except: narrow which bare calls resolve (match: :call) Kernel calls, attributes and def heads are not claimed by an unrestricted import (Anchor.Domain.Checks.NoDependencyAliasResolutionTest)
     test/anchor/domain/checks/no_dependency_alias_resolution_test.exs:396
     Assertion with == failed
     code:  assert detect(source, [Forbidden.Target], :call) == []
     left:  [
              %Anchor.Domain.Violation{
                line: 6,
                trigger: "Forbidden.Target",
                message: "Module has forbidden direct dependency on Forbidden.Target"
              }
            ]
     right: []
```

I:
```
  1) test import only:/except: narrow which bare calls resolve (match: :call) a piped bare call counts the piped argument toward its arity (Anchor.Domain.Checks.NoDependencyAliasResolutionTest)
     test/anchor/domain/checks/no_dependency_alias_resolution_test.exs:423
     Assertion with == failed
     code:  assert triggers(source, [Forbidden.Target], :call) == ["Forbidden.Target"]
     left:  []
     right: ["Forbidden.Target"]
```

J:
```
  1) test alias and import resolution (DND-1266) call mode resolves an aliased call to the full module (Anchor.Domain.DependencyAnalyzerTest)
     test/anchor/domain/dependency_analyzer_test.exs:526
     Assertion with == failed
     code:  assert DependencyAnalyzer.extract_call_dependencies(ast(src)) == [A.B]
     left:  [B]
     right: [A.B]
```

K:
```
  1) test alias and import resolution (DND-1266) module_dependencies resolves an outer alias inside a nested module's node (Anchor.Domain.DependencyAnalyzerTest)
     test/anchor/domain/dependency_analyzer_test.exs:552
     Assertion with == failed
     code:  assert nodes[Outer.Inner].direct_dependencies == [A.B]
     left:  [B]
     right: [A.B]
```

L (failed: the sibling-leak `module_dependencies` row, and the three call-mode
rows "an import in one module does not resolve bare calls in its sibling", "an
alias in one top-level module does not apply in the next", "an alias inside a
nested module does not leak to its sibling"):
```
  1) test alias and import resolution (DND-1266) module_dependencies does not leak a nested module's alias to its sibling (Anchor.Domain.DependencyAnalyzerTest)
     test/anchor/domain/dependency_analyzer_test.exs:569
     Assertion with == failed
     code:  assert nodes[Outer.Sibling].direct_dependencies == [B]
     left:  [A.B]
     right: [B]
```

M:
```
  1) test resolution is lexically scoped (match: :call) an alias applies only after it is declared (Anchor.Domain.Checks.NoDependencyAliasResolutionTest)
     test/anchor/domain/checks/no_dependency_alias_resolution_test.exs:292
     Assertion with == failed
     code:  assert detect(source, [Forbidden.Target], :call) == []
     left:  [
              %Anchor.Domain.Violation{
                line: 2,
                trigger: "Forbidden.Target",
                message: "Module has forbidden direct dependency on Forbidden.Target"
              }
            ]
     right: []
```

N:
```
  1) test resolution is lexically scoped (match: :call) a later alias of the same short name replaces the earlier one (Anchor.Domain.Checks.NoDependencyAliasResolutionTest)
     test/anchor/domain/checks/no_dependency_alias_resolution_test.exs:304
     Assertion with == failed
     code:  assert detect(source, [Forbidden.Target], :call) == []
     left:  [
              %Anchor.Domain.Violation{
                line: 5,
                trigger: "Forbidden.Target",
                message: "Module has forbidden direct dependency on Forbidden.Target"
              }
            ]
     right: []
```

O (also re-reds three pre-existing first-line rows in the `no_dependency` suites,
which now depend on the analyzer's line):
```
  1) test detect_violations/2 — forbidden_patterns and match (Gap A + A') a pattern-matched module referenced twice is reported once at the first line (Anchor.Domain.Checks.NoDependencyTest)
     test/anchor/domain/checks/no_dependency_test.exs:99
     Assertion with == failed
     code:  assert violation.line == 2
     left:  4
     right: 2
```

Q:
```
  1) test import only:/except: narrow which bare calls resolve (match: :call) import Kernel, except: hands a Kernel name to an unrestricted import (Anchor.Domain.Checks.NoDependencyAliasResolutionTest)
     test/anchor/domain/checks/no_dependency_alias_resolution_test.exs:410
     Assertion with == failed
     code:  assert triggers(source, [Forbidden.Target], :call) == ["Forbidden.Target"]
     left:  []
     right: ["Forbidden.Target"]
```

S (both modes' "a non-literal directive inside a quote stays opaque" rows):
```
  1) test an unresolvable directive is reported, never read as no dependency (match: reference) a non-literal directive inside a quote stays opaque (Anchor.Domain.Checks.NoDependencyAliasResolutionTest)
     test/anchor/domain/checks/no_dependency_alias_resolution_test.exs:558
     Assertion with == failed
     code:  assert detect(source, [Forbidden.Target], mode) == []
     left:  [
              %Anchor.Domain.Violation{
                line: 4,
                trigger: "alias",
                message: "Anchor cannot statically resolve the target of this `alias`, so references made through it cannot be checked for forbidden dependencies. Fix: name the module literally (e.g. `alias MyApp.Foo`)."
              }
            ]
     right: []
```

## Rows no analyzer mutation isolates

- **"an alias inside a function body does not leak to the next function".**
  Measured zero under L: L leaks through blocks and module bodies, but a `def`
  body is walked by `visit/3`, which drops its environment by construction, so no
  one-line change makes it leak. The row is re-reddened only by the
  `no_dependency` mutation P (short-name matching), which is a different defect.
  It stands as a guard against a future walk that returns a `def` body's
  environment.
- **"a same-named module that is not the target is not reported"** is
  re-reddened only by P (sibling record). No analyzer mutation targets it,
  because the analyzer never guesses by short name.

## Traps

- Two mutations first failed to compile (unused private function under
  `--warnings-as-errors`). A compile failure prints no test names; the exit code
  alone would have logged them as red. Check for `N tests, M failures`.
