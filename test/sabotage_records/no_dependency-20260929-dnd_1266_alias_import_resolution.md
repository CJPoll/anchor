# Sabotage record — no_direct_dependency over resolved names (DND-1266)

- **Domain:** no_dependency
- **Branch:** dnd-1266-alias-import-resolution
- **Date:** 2026-09-29
- **Code under test:** `Anchor.Domain.Checks.NoDependency.detect_violations/3`
  (unresolved-directive reporting, forbidden-module matching)
- **Suite run:** `mix test test/anchor/domain/dependency_analyzer_test.exs test/anchor/domain/checks/no_dependency_alias_resolution_test.exs test/anchor/domain/checks/no_dependency_test.exs test/anchor/check/no_dependency_test.exs` (156 tests)
- **Merge base:** `origin/main` = 6e02f3a
- **Sibling record:** `dependency_analyzer-20260929-dnd_1266_alias_import_resolution.md`
  (the analyzer mutations and the round-1 fail-first run)

## Fail-first runs

Round 1, against `origin/main` production code: the unresolved-directive rows
failed because nothing reported them. Verbatim:

```
 29) test an unresolvable directive is reported, never read as no dependency (match: reference) alias with a non-literal target (Anchor.Domain.Checks.NoDependencyAliasResolutionTest)
     test/anchor/domain/checks/no_dependency_alias_resolution_test.exs:475
     match (=) failed
     code:  assert [%Violation{} = violation] = detect(source, [Forbidden.Target], mode)
     left:  [%Anchor.Domain.Violation{} = violation]
     right: []
```

Round 2, the once-per-file rows against the first fix commit (d92b5a0), which
reported the directive once per rule. Verbatim (reference mode; call mode is
identical):

```
  2) test an unresolvable directive is reported, never read as no dependency (match: reference) is reported once per file, not once per rule (Anchor.Domain.Checks.NoDependencyAliasResolutionTest)
     test/anchor/domain/checks/no_dependency_alias_resolution_test.exs:542
     match (=) failed
     code:  assert [%Violation{trigger: "alias", line: 2}] =
              NoDependency.detect_violations(Code.string_to_quoted!(source), rules)
     left:  [%Anchor.Domain.Violation{trigger: "alias", line: 2}]
     right: [
              %Anchor.Domain.Violation{
                line: 2,
                trigger: "alias",
                message: "Anchor cannot statically resolve the target of this `alias`, so references made through it cannot be checked for forbidden dependencies. Fix: name the module literally (e.g. `alias MyApp.Foo`)."
              },
              %Anchor.Domain.Violation{
                line: 2,
                trigger: "alias",
                message: "Anchor cannot statically resolve the target of this `alias`, so references made through it cannot be checked for forbidden dependencies. Fix: name the module literally (e.g. `alias MyApp.Foo`)."
              }
            ]
```

## Mutations

Fixed code committed first (6af52db). Each mutation applied alone, restored with
`git checkout -- lib/anchor/domain/checks/no_dependency.ex`.

| # | Mutation | Tests failed |
|---|---|---|
| H | Drop the unresolved-directive violations (`Enum.take(unresolved_violations(ast), 0)`) | **6** |
| P | Match `forbidden_modules` by the last name segment instead of the resolved full name | **7** |
| R | Report unresolved directives once per rule (`Enum.flat_map(rules, fn _rule -> unresolved_violations(ast) end)`) | **2** |

H:
```
  1) test an unresolvable directive is reported, never read as no dependency (match: reference) import with a non-literal target (Anchor.Domain.Checks.NoDependencyAliasResolutionTest)
     test/anchor/domain/checks/no_dependency_alias_resolution_test.exs:530
     match (=) failed
     code:  assert [%Violation{trigger: "import", line: 2}] = detect(source, [Forbidden.Target], mode)
     left:  [%Anchor.Domain.Violation{trigger: "import", line: 2}]
     right: []
```

P (failed: both "a same-named module that is not the target" rows, "a later alias
of the same short name replaces the earlier one", and the four scope rows):
```
  1) test resolution is lexically scoped (match: :call) an alias inside a function body does not leak to the next function (Anchor.Domain.Checks.NoDependencyAliasResolutionTest)
     test/anchor/domain/checks/no_dependency_alias_resolution_test.exs:277
     Assertion with == failed
     code:  assert detect(source, [Forbidden.Target], :call) == []
     left:  [
              %Anchor.Domain.Violation{
                line: 7,
                trigger: "Target",
                message: "Module has forbidden direct dependency on Target"
              }
            ]
     right: []
```

R:
```
  1) test an unresolvable directive is reported, never read as no dependency (match: reference) is reported once per file, not once per rule (Anchor.Domain.Checks.NoDependencyAliasResolutionTest)
     test/anchor/domain/checks/no_dependency_alias_resolution_test.exs:542
     match (=) failed
     code:  assert [%Violation{trigger: "alias", line: 2}] =
              NoDependency.detect_violations(Code.string_to_quoted!(source), rules)
     left:  [%Anchor.Domain.Violation{trigger: "alias", line: 2}]
     right: [
              %Anchor.Domain.Violation{
                line: 2,
                trigger: "alias",
                message: "Anchor cannot statically resolve the target of this `alias`, so references made through it cannot be checked for forbidden dependencies. Fix: name the module literally (e.g. `alias MyApp.Foo`)."
              },
              %Anchor.Domain.Violation{
                line: 2,
                trigger: "alias",
                message: "Anchor cannot statically resolve the target of this `alias`, so references made through it cannot be checked for forbidden dependencies. Fix: name the module literally (e.g. `alias MyApp.Foo`)."
              }
            ]
```

## Rows that stayed green

- Under H, the "non-literal directive inside a quote stays opaque" rows stay
  green: they assert nothing is reported, which H also produces. They are guarded
  by the analyzer's `record_unresolved/4` quote clause, not by this check:
  mutation S in the sibling record re-reds both.
