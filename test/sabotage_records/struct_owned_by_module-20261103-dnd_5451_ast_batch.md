# Sabotage record — struct_owned_by_module (DND-5453)

- **Domain:** struct_owned_by_module
- **Branch:** dnd-5451-ast-batch
- **Date:** 2026-11-03
- **Code under test:** `Anchor.Domain.Checks.StructOwnedByModule`
  (`detect_violations/2`, `shape/1`), the `Anchor.Check.StructOwnedByModule`
  shell, `owned_namespaces` in `Anchor.Domain.RuleSchema` and
  `Anchor.Config.build_rule/4`
- **Tests:** `test/anchor/domain/checks/struct_owned_by_module_test.exs` (the
  ported crew rows B1-B11, C1-C7, O1-O3, R1-R5, K1-K4, M1-M6, N1-N3, T2, S1),
  `test/anchor/check/struct_owned_by_module_test.exs`,
  `test/anchor/e2e/checks_e2e_test.exs` ("struct_owned_by_module through the
  real pipeline", F1, F2 = crew's test exemption as selection),
  `test/anchor/domain/rule_checks_nothing_test.exs` (`table(:struct_owned_by_module)`)
- **Suite run:** from the worktree root,
  `mix test test/anchor/domain/checks/struct_owned_by_module_test.exs` for
  every row but **shell** (`mix test test/anchor/check/struct_owned_by_module_test.exs
  test/anchor/e2e/checks_e2e_test.exs`) and **config**
  (`mix test test/anchor/e2e/checks_e2e_test.exs`)
- **Related record (same run):** `rule_schema-20261103-dnd_5451_ast_batch.md` (the
  `owned_namespaces` load refusals, mutations **empty** and **grammar**)
- **Base:** c733831 (DND-5452's commit); mutated tree: this ticket's code
  before its commit

Each mutation was applied to one file, the named suite run, the file
restored. Failure text is verbatim.

| # | Mutation | Failed | Failure |
|---|---|---|---|
| pattern | The left side of `=` is an expression | R1, C3 | C3: `left: ["%App.Turn{", "%{t \|", "%{t \|", "%{t \|"]` `right: ["%{t \|", "%{t \|", "%{t \|"]` |
| head | A head pattern is an expression | R1, C2 | C2: `left: ["%DescribeRequest{", "%{state \|"]` `right: ["%{state \|"]` |
| arrow | `->` patterns are expressions | R1 | `code: assert detect(source) == []` `left: [` |
| match | `match?/2`'s pattern is an expression | R1, M4 | `code: assert detect(source) == []` `left: [` |
| impl | A `defimpl`'s owner is its protocol, not `for:` | M2 | `code: assert detect(source) == []` `left: [` |
| agree | Any agreeing struct makes a variable known (`MapSet.delete(set, :unknown)`) | K1, K2, K3, R5 | K1: `code: assert detect(source) == []` `left: [` |
| unknown | An unknown variable counts (`module != :unknown or true`) | K4, R4 | K4: `code: assert detect(source) == []` `left: [` |
| drop | `Map.drop` of `:__struct__` not exempt | M5 | `code: assert detect(source) == []` `left: [` |
| delete | `Map.delete(v, :__struct__)` not exempt | M5 | `code:  assert detect(source) == []` `left: [` `trigger: "Map.delete",` `right: []` |
| owned | `owned_namespaces` ignored | N1, N3, the prefix row | N1: `code: assert detect(source, @owned) == []` `left: [`; N3: `left: "%NewApp.Other{"` `right: "NewApp.Thing"` |
| unowned | The unowned-module report removed | N3 | `code: assert [violation] = detect(source, @owned)` `left: [violation]` `right: []` |
| prefix | A namespace matches any name it prefixes | the prefix row | `left: ["%App.Deep.Turn{", "%AppOther.Turn{", "%App{"]` `right: ["%App.Deep.Turn{", "%App{"]` |
| quote | `quote` bodies walked | M6 | `code: assert detect(source) == []` `left: [` |
| type | Typespec attributes walked | R3 | `code: assert detect(source) == []` `left: [` |
| cond | A `cond` condition is not walked | B8 | `left: []` `right: ["%App.Turn{"]` |
| kernel | `Kernel.struct/put_in/match?` not treated as the bare forms | B10, C7, M4 | B10: `left: ["struct", "struct", "struct!"]` `right: ["struct", "struct", "struct", "struct!", "struct!"]` |
| pipe | Pipes not normalized | C5 | `left: []` `right: ["Map.put"]` |
| path | A path's root container not judged | C7 | `code: assert triggers(source) == [` |
| message | The message drops its Fix | B1 | `code: assert String.ends_with?(violation.message, "Fix: " <> @shape)` |
| shell | The shell returns no violations | check row 1, e2e F1 | `left: [issue]` `right: []`; e2e: `left: []` `right: [{2, "%App.Turn{"}]` |
| config | `owned_namespaces` not parsed (`nil && ...`) | e2e F1 | `left: [{2, "%App.Turn{"}, {3, "%{uri \|"}]` `right: [{2, "%App.Turn{"}]` |

## Measured zero, fixed in the same run

- **agree** first used `[module | _rest] <- [MapSet.to_list(set)]` and
  passed: `MapSet.to_list/1` puts `:unknown` before every `Elixir.` module
  here, so taking the first element still read as unknown. The mutation that
  lets any agreeing struct win (`MapSet.delete(set, :unknown)`) fails K1-K3
  and R5, so the "every binding agrees" rule is protected.
