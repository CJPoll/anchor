# Sabotage record — the ADR 001 module map canary (DND-5620)

- **Domain:** module_map
- **Branch:** dnd-5443-graph-rules-b
- **Date:** 2026-11-03
- **Code under test:** ADR 001's module map (*How this maps to Anchor*, the DND-5620 amendment's table) and the reader in `test/anchor/adr_module_map_test.exs` (`map_rows/1`, `covering_row/2`, `problem/4`)
- **Suite run:** each mutation ran `mix test --force --timeout 2000 --max-cases 2 test/anchor/adr_module_map_test.exs` inside one `test-slot`, by a driver that applied it, ran the file and restored the source. Every row is red. The checkout's absolute path in the output reads `<worktree>`.

MM-A to MM-C mutate the map itself: the guarded artifact is the document. A
first pass found MM-H (the bucket comparison dropped) green, because the real
map has no mismatch for it to find; a direct test of `problem/4` with a wrong
bucket and a missing row was added, and this table is the re-run.

The review floor found the test green on an empty module list (a `_build`
compiled at another path gives no `lib/` source). MM-I, run before the fix,
survived (`4 tests, 0 failures`); the test now requires the modules' sources to
be exactly the `.ex` files under `lib/`, and the MM-I row is from the run after.

| # | Mutation | Tests run | Result | Failing tests |
|---|---|---|---|---|
| MM-A | a module's row is dropped from the map (Managers.Explain) (`adrs/001-five-bucket-architecture.md`) | `adr_module_map_test.exs` | `4 tests, 1 failure` (red) | every lib module has a row in ADR 001's module map, under the bucket .anchor.yml gives it |
| MM-B | a row names the wrong bucket (Managers.Explain as Domain) (`adrs/001-five-bucket-architecture.md`) | `adr_module_map_test.exs` | `4 tests, 1 failure` (red) | every lib module has a row in ADR 001's module map, under the bucket .anchor.yml gives it |
| MM-C | a namespace row is dropped (Anchor.Domain.Checks.*) (`adrs/001-five-bucket-architecture.md`) | `adr_module_map_test.exs` | `4 tests, 1 failure` (red) | every lib module has a row in ADR 001's module map, under the bucket .anchor.yml gives it |
| MM-D | covering_row/2: first namespace row wins, not the longest (`test/anchor/adr_module_map_test.exs`) | `adr_module_map_test.exs` | `4 tests, 1 failure` (red) | covering_row/2 an exact row wins; else the longest namespace row; else none |
| MM-E | covering_row/2: a namespace row covers a sibling prefix (A.* covers AB.C) (`test/anchor/adr_module_map_test.exs`) | `adr_module_map_test.exs` | `4 tests, 1 failure` (red) | covering_row/2 an exact row wins; else the longest namespace row; else none |
| MM-F | map_rows/1: the e.g. aside is read as rows (`test/anchor/adr_module_map_test.exs`) | `adr_module_map_test.exs` | `4 tests, 1 failure` (red) | map_rows/1 (the reader this test relies on) reads the module column's code spans and the bucket, from every table in the section |
| MM-G | map_rows/1: tables after the section are read too (`test/anchor/adr_module_map_test.exs`) | `adr_module_map_test.exs` | `4 tests, 1 failure` (red) | map_rows/1 (the reader this test relies on) reads the module column's code spans and the bucket, from every table in the section |
| MM-H | the test ignores a bucket mismatch (`test/anchor/adr_module_map_test.exs`) | `adr_module_map_test.exs` | `4 tests, 1 failure` (red) | problem/4 a row whose bucket disagrees with .anchor.yml, and a module with no row, are each named |
| MM-I | lib_modules/1 finds no module (a _build compiled at another path) (`test/anchor/adr_module_map_test.exs`) | `adr_module_map_test.exs` | `4 tests, 1 failure` (red) | every lib module has a row in ADR 001's module map, under the bucket .anchor.yml gives it |

## MM-A — a module's row is dropped from the map (Managers.Explain)

Run summary: `4 tests, 1 failure`

```text
  1) test every lib module has a row in ADR 001's module map, under the bucket .anchor.yml gives it (Anchor.AdrModuleMapTest)
     test/anchor/adr_module_map_test.exs:104
     ADR 001's module map (adrs/001-five-bucket-architecture.md, "How this maps to Anchor") is out of date. Fix: add a row for each module below to the DND-5620 amendment's table, with the bucket .anchor.yml classifies it into:
       Anchor.Managers.Explain (lib/anchor/managers/explain.ex): no row; .anchor.yml buckets it managers
     code: assert problems == [],
     stacktrace:
       test/anchor/adr_module_map_test.exs:114: (test)
```

## MM-B — a row names the wrong bucket (Managers.Explain as Domain)

Run summary: `4 tests, 1 failure`

```text
  1) test every lib module has a row in ADR 001's module map, under the bucket .anchor.yml gives it (Anchor.AdrModuleMapTest)
     test/anchor/adr_module_map_test.exs:104
     ADR 001's module map (adrs/001-five-bucket-architecture.md, "How this maps to Anchor") is out of date. Fix: add a row for each module below to the DND-5620 amendment's table, with the bucket .anchor.yml classifies it into:
       Anchor.Managers.Explain (lib/anchor/managers/explain.ex): row `Anchor.Managers.Explain` says domain; .anchor.yml says managers
     code: assert problems == [],
     stacktrace:
       test/anchor/adr_module_map_test.exs:114: (test)

..
```

## MM-C — a namespace row is dropped (Anchor.Domain.Checks.*)

Run summary: `4 tests, 1 failure`

```text
  1) test every lib module has a row in ADR 001's module map, under the bucket .anchor.yml gives it (Anchor.AdrModuleMapTest)
     test/anchor/adr_module_map_test.exs:104
     ADR 001's module map (adrs/001-five-bucket-architecture.md, "How this maps to Anchor") is out of date. Fix: add a row for each module below to the DND-5620 amendment's table, with the bucket .anchor.yml classifies it into:
       Anchor.Domain.Checks.AlphabetizedFunctions (lib/anchor/domain/checks/alphabetized_functions.ex): no row; .anchor.yml buckets it domain
       Anchor.Domain.Checks.CaseOnBareArg (lib/anchor/domain/checks/case_on_bare_arg.ex): no row; .anchor.yml buckets it domain
       Anchor.Domain.Checks.MaxFileLength (lib/anchor/domain/checks/max_file_length.ex): no row; .anchor.yml buckets it domain
       Anchor.Domain.Checks.ModulePatternRestrictions (lib/anchor/domain/checks/module_pattern_restrictions.ex): no row; .anchor.yml buckets it domain
       Anchor.Domain.Checks.MustUseModule (lib/anchor/domain/checks/must_use_module.ex): no row; .anchor.yml buckets it domain
       Anchor.Domain.Checks.NoComparisonInIf (lib/anchor/domain/checks/no_comparison_in_if.ex): no row; .anchor.yml buckets it domain
       Anchor.Domain.Checks.NoDependency (lib/anchor/domain/checks/no_dependency.ex): no row; .anchor.yml buckets it domain
       Anchor.Domain.Checks.NoDiscardedPureExpression (lib/anchor/domain/checks/no_discarded_pure_expression.ex): no row; .anchor.yml buckets it domain
       Anchor.Domain.Checks.NoDiscardingArrowInWith (lib/anchor/domain/checks/no_discarding_arrow_in_with.ex): no row; .anchor.yml buckets it domain
       Anchor.Domain.Checks.NoForwardingFunction (lib/anchor/domain/checks/no_forwarding_function.ex): no row; .anchor.yml buckets it domain
       Anchor.Domain.Checks.NoTransitiveDependency (lib/anchor/domain/checks/no_transitive_dependency.ex): no row; .anchor.yml buckets it domain
       Anchor.Domain.Checks.NoTupleMatchInHead (lib/anchor/domain/checks/no_tuple_match_in_head.ex): no row; .anchor.yml buckets it domain
       Anchor.Domain.Checks.SingleControlFlow (lib/anchor/domain/checks/single_control_flow.ex): no row; .anchor.yml buckets it domain
       Anchor.Domain.Checks.StructGetterConvention (lib/anchor/domain/checks/struct_getter_convention.ex): no row; .anchor.yml buckets it domain
       Anchor.Domain.Checks.StructOwnedByModule (lib/anchor/domain/checks/struct_owned_by_module.ex): no row; .anchor.yml buckets it domain
     code: assert problems == [],
     stacktrace:
       test/anchor/adr_module_map_test.exs:114: (test)

...
```

## MM-D — covering_row/2: first namespace row wins, not the longest

Run summary: `4 tests, 1 failure`

```text
  1) test covering_row/2 an exact row wins; else the longest namespace row; else none (Anchor.AdrModuleMapTest)
     test/anchor/adr_module_map_test.exs:67
     Assertion with == failed
     code:  assert covering_row("A.B.C", @rows) == {"A.B.*", "adapters"}
     left:  {"A.*", "managers"}
     right: {"A.B.*", "adapters"}
     stacktrace:
       test/anchor/adr_module_map_test.exs:69: (test)

.
```

## MM-E — covering_row/2: a namespace row covers a sibling prefix (A.* covers AB.C)

Run summary: `4 tests, 1 failure`

```text
  1) test covering_row/2 an exact row wins; else the longest namespace row; else none (Anchor.AdrModuleMapTest)
     test/anchor/adr_module_map_test.exs:67
     Assertion with == failed
     code:  assert covering_row("A", @rows) == nil
     left:  {"A.*", "managers"}
     right: nil
     stacktrace:
       test/anchor/adr_module_map_test.exs:71: (test)

.
```

## MM-F — map_rows/1: the e.g. aside is read as rows

Run summary: `4 tests, 1 failure`

```text
  1) test map_rows/1 (the reader this test relies on) reads the module column's code spans and the bucket, from every table in the section (Anchor.AdrModuleMapTest)
     test/anchor/adr_module_map_test.exs:30
     Assertion with == failed
     code:  assert map_rows(adr) == [{"A.B", "adapters"}, {"A.C.*", "adapters"}, {"A.D", "domain"}]
     left:  [
              {"A.B", "adapters"},
              {"Ignored", "adapters"},
              {"A.C.*", "adapters"},
              {"A.D", "domain"}
            ]
     right: [{"A.B", "adapters"}, {"A.C.*", "adapters"}, {"A.D", "domain"}]
     stacktrace:
       test/anchor/adr_module_map_test.exs:56: (test)
```

## MM-G — map_rows/1: tables after the section are read too

Run summary: `4 tests, 1 failure`

```text
  1) test map_rows/1 (the reader this test relies on) reads the module column's code spans and the bucket, from every table in the section (Anchor.AdrModuleMapTest)
     test/anchor/adr_module_map_test.exs:30
     Assertion with == failed
     code:  assert map_rows(adr) == [{"A.B", "adapters"}, {"A.C.*", "adapters"}, {"A.D", "domain"}]
     left:  [
              {"A.B", "adapters"},
              {"A.C.*", "adapters"},
              {"A.D", "domain"},
              {"After.Section", "domain"}
            ]
     right: [{"A.B", "adapters"}, {"A.C.*", "adapters"}, {"A.D", "domain"}]
     stacktrace:
       test/anchor/adr_module_map_test.exs:56: (test)
```

## MM-H — the test ignores a bucket mismatch

Run summary: `4 tests, 1 failure`

```text
  1) test problem/4 a row whose bucket disagrees with .anchor.yml, and a module with no row, are each named (Anchor.AdrModuleMapTest)
     test/anchor/adr_module_map_test.exs:77
     Assertion with == failed
     code:  assert problem(
              Anchor.Managers.Explain,
              source,
              [{"Anchor.Managers.Explain", "domain"}],
              arch
            ) ==
              "  Anchor.Managers.Explain (#{source}): row `Anchor.Managers.Explain` says domain; " <>
                ".anchor.yml says managers"
     left:  nil
     right: "  Anchor.Managers.Explain (lib/anchor/managers/explain.ex): row `Anchor.Managers.Explain` says domain; .anchor.yml says managers"
     stacktrace:
       test/anchor/adr_module_map_test.exs:90: (test)

...
```

## MM-I — lib_modules/1 finds no module (a _build compiled at another path)

Run summary: `4 tests, 1 failure`

```text
  1) test every lib module has a row in ADR 001's module map, under the bucket .anchor.yml gives it (Anchor.AdrModuleMapTest)
     test/anchor/adr_module_map_test.exs:104
     the compiled :anchor modules' sources are not exactly the .ex files under lib/ (read 0 sources, 174 files; missing: ["lib/anchor/check/no_discarding_arrow_in_with.ex", "lib/anchor/domain/effect_primitives.ex", "lib/anchor/domain/checks/no_discarding_arrow_in_with.ex", "lib/anchor/managers/graph/request.ex", "lib/anchor/adapters/git_change_source.ex"]). Fix: run the suite from the project root on a _build compiled there (mix clean, then mix test).
     code: assert read == files,
     stacktrace:
       test/anchor/adr_module_map_test.exs:115: (test)

.
```
