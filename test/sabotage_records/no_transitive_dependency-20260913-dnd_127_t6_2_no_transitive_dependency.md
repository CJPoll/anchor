# Sabotage record — NoTransitiveDependency detection extracted to Domain

- **Domain:** no_transitive_dependency
- **Branch:** dnd-127-t6-2-no-transitive-dependency
- **Date:** 2026-09-13
- **Code under test:** `Anchor.Domain.Checks.NoTransitiveDependency.detect_violations/3` (the pure Domain detector; the `Anchor.Check.NoTransitiveDependency` shell delegates to it, threading `context.modules_map`)
- **Suite run:** `mix test test/anchor/domain/checks/no_transitive_dependency_test.exs`

T6.2 (DND-127) extracted the transitive-dependency detection out of the
`Anchor.Check.NoTransitiveDependency` Framework shell into the pure
`Anchor.Domain.Checks.NoTransitiveDependency` module — `find_dependency_path`,
`find_path_dfs`, `format_dependency_path`, and `find_module_reference_line` all
moved with it. Each mutation below was applied to that Domain module, the suite
re-run, and the code restored to a byte-identical pristine copy. Failure strings
are verbatim, including `left:` / `right:`.

The 9 acceptance-matrix rows (`docs/five-bucket-test-matrix.md`,
`no_transitive_dependency.ex → check_file/3 → #1–9`) are asserted against the
pure detector, which takes the cross-file `modules_map` explicitly (Base hands
`check_file/3` an empty map, so the positive rows cannot be exercised through
that entry point — each row supplies the map in-memory, as the matrix says).

| # | Mutation | Tests failed | Failure string |
|---|---|---|---|
| A | Drop `transitive ` from the message (`"Module has transitive dependency on forbidden module"` → `"Module has dependency on forbidden module"`) | 2 (rows 1, 3) | row 3: `code: assert violation.message == "Module has transitive dependency on forbidden module MyApp.Repo"` `left: "Module has dependency on forbidden module MyApp.Repo"` `right: "Module has transitive dependency on forbidden module MyApp.Repo"`; row 1: `code: assert violation.message =~ "transitive dependency on forbidden module MyApp.Repo"` `left: "Module has dependency on forbidden module MyApp.Repo (dependency chain: A -> B -> MyApp.Repo)"` `right: "transitive dependency on forbidden module MyApp.Repo"` |
| B | Null the trigger (`trigger: inspect(forbidden_module)` → `trigger: nil`) | 9 (rows 1–9) | row 1: `code: assert violation.trigger == "MyApp.Repo"` `left: nil` `right: "MyApp.Repo"`; the positive-control rows (4, 5, 7, 8, 9) fail their `[%Violation{trigger: ...}]` match: `left: [%Anchor.Domain.Violation{trigger: "MyApp.Repo"}]` `right: [ ... ]` |
| C | Report the path's **first** node's line instead of the direct hop's (`Enum.at(path, 0)` for `direct_dep` instead of `Enum.at(path, 1)`) | 3 (rows 1, 2, 3) | `code: assert violation.line == 2` `left: 1` `right: 2` (line 1 is the `defmodule A` alias, not the direct-hop reference on line 2) |
| D | Do **not** remove self from the reachable set (delete the `\|> MapSet.delete(module_name)` step) | 1 (row 5) | `code: assert NoTransitiveDependency.detect_violations(a_refs_b(), [rule([A])], modules_map) == []` `left: [%Anchor.Domain.Violation{line: nil, trigger: "A", message: "Module has transitive dependency on forbidden module A"}]` `right: []` |
| E | Move the chain-suffix boundary (`format_dependency_path(path) when length(path) <= 2` → `when length(path) < 2`), so a length-2 direct path gets a chain suffix | 1 (row 3) | `code: assert violation.message == "Module has transitive dependency on forbidden module MyApp.Repo"` `left: "Module has transitive dependency on forbidden module MyApp.Repo (dependency chain: A -> MyApp.Repo)"` `right: "Module has transitive dependency on forbidden module MyApp.Repo"` |
| F | Invert the reachability filter (`Enum.filter(&(&1 in transitive_deps))` → `&(&1 not in transitive_deps)`) | 9 (rows 1–9) | row 4 (positive control) now flags an **unreachable** module, whose path is `nil`, so `Enum.at(nil, 1)` raises: `** (Protocol.UndefinedError) protocol Enumerable not implemented for Atom ... Got value: nil` `code: assert NoTransitiveDependency.detect_violations(...) == []`; the happy-path rows (1, 2, 3, 6, 9) go red because the forbidden-but-reachable module is no longer flagged |

## Notes on what each mutation proves

- **A** protects the message's discriminating word. The check's whole reason to
  exist is *transitive* reachability; dropping `transitive ` reddens both the
  exact-message row (3) and the `=~` substring row (1).
- **B** protects the trigger on every row — the happy paths assert it directly
  and each absence row's positive control matches `%Violation{trigger: ...}`, so
  nulling it reddens all nine.
- **C** pins the reported line to the **direct hop** (`path[1]`), the module the
  file actually references, not the file's own module name (`path[0]`, the
  `defmodule` alias on line 1). Rows 1–3 all assert `line == 2`.
- **D** is the self-removal guarantee (matrix row 5): a module is never its own
  transitive dependency. Without the `MapSet.delete`, forbidding `A` in a graph
  with a self-edge `A → [A]` spuriously flags `A`. (Traversal still terminates
  either way — `find_transitive_dependencies/2` has its own visited set — so this
  mutation isolates *self-removal* from *cycle-termination*, which row 6 covers.)
- **E** pins the `≤ 2` boundary: a direct dependency that also counts as
  transitive (path `A → Repo`, length 2) must carry **no** chain suffix. Loosening
  the guard to `< 2` appends `(dependency chain: A -> MyApp.Repo)` and reddens
  row 3.
- **F** is the presence/absence proof: inverting the filter empties every
  happy-path row and makes the absence rows flag unreachable modules. Because an
  unreachable module has no path, `Enum.at(path, 1)` on `nil` raises
  `Protocol.UndefinedError` — an honest crash the mutation induces, never reached
  by the real code (which only builds a violation for a module that *is* in the
  reachable set, so its path is always non-nil).

## Trap encountered (ADR 002 catalogue)

The Domain module is a **new, untracked** file on this branch, so `git checkout
-- <file>` would **not** restore it (HEAD has no such path — it would delete the
uncommitted work). Each mutation was instead reverted from a byte-identical
pristine copy taken before the run, and the file was `diff`'d against that copy
after the last mutation to confirm the restore. The final suite was re-run green
(9 tests, 0 failures) before writing this record.

## Measured zeros

None. Every mutation reddened at least one row, and collectively every asserted
property of the nine matrix rows — the message's `transitive` wording, the
`dependency chain: ...` suffix and its `≤ 2` boundary, the trigger, the
direct-hop line, self-removal, cycle-termination, and presence/absence — is
protected by at least one mutation above.
