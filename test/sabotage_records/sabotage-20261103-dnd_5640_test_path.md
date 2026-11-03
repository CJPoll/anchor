# Sabotage record — one path rule for every path handed to mix test (DND-5640)

- **Domain:** sabotage
- **Branch:** dnd-5474-coverage-records
- **Date:** 2026-11-03
- **Code under test:** `Anchor.Domain.Sabotage.TestPath` (`check/1`,
  `check_arg/1`), `Anchor.Domain.Sabotage.KillMap.parse/1` (the parse-time
  check), `Anchor.Domain.Sabotage.TestSelection.select/2` (the emit-time
  check, for coverage refs, kill-map killers and mirror files),
  `Anchor.Domain.Sabotage.CoverageMap.check/1`, and the Runner's refusal
  note
- **Suite run:** per row, `mix test <the files the row names> --timeout 2000
  --max-cases 2` through `test-slot` (the sabotage load rule). Every file was
  green before and after every row.

The defect (introduced by DND-5484): a committed record's killer reached
`mix test`'s argv after only an existence check, so a killer `--<opt>` beside
a file of that name injected an option (one that fails every run marks every
mutant killed: the gate fails open), and `../x_test.exs` ran a test file
outside the repo. The fix is one Domain predicate, `TestPath.check/1`
(CoverageMap's old rule plus a `_test.exs` suffix), applied when a killer is
parsed (the record is refused, naming the record, its line and the reason)
and again to every path `TestSelection.select/2` emits, from every source.

Each row was applied alone by the scratch driver used for the DND-5474 and
DND-5484 records; failure strings are copied from its output.

| # | Mutation | Tests failed | First failure, verbatim |
|---|---|---|---|
| P1 | the option clause removed from `check/1` (`--opt`) | 4 of 39: test_path "an option is refused: --opt never reaches the argv"; kill_map "DND-5640: a killed row whose killer file is not a project test file is refused ..."; selection "a coverage ref that is an option ...", "a kill-map killer that is an option ..." | `code:  assert TestPath.check("--include") == {:error, :option}` `left:  {:error, :not_a_test_file}` |
| P2 | the absolute clause removed (`/abs`) | 2 of 39: test_path "an absolute path is refused"; kill_map "DND-5640: ..." | `code:  assert TestPath.check("/abs/x_test.exs") == {:error, :absolute}` `left:  {:error, :empty_segment}` |
| P3 | the `..` check removed (`../`, `a/../b`) | 6 of 39: test_path "../ is refused ...", "a/../b is refused ..."; kill_map "DND-5640: ..."; selection, all three refusal rows | `code:  assert TestPath.check("../x_test.exs") == {:error, :parent_segment}` `left:  :ok` |
| P4 | the `_test.exs` suffix check removed | 3 of 34: test_path "an empty path, an empty segment and a file that is not a _test.exs file are refused"; kill_map "DND-5640: ..."; coverage_map "check/1: ... a test file is a relative path inside the project that is not an option" | `code:  assert TestPath.check("test/a.exs") == {:error, :not_a_test_file}` `left:  :ok` |
| P5 | the emit-time check dropped for kill-map killers | 1 of 23: selection "a kill-map killer that is an option or outside the project is never selected" | `code:  assert TestSelection.select(...) == {:mirror, ["test/x_test.exs"]}` `left:  {:kill_map, ...` |
| P6 | the emit-time check dropped for coverage refs | 1 of 23: selection "a coverage ref that is an option or outside the project is never selected" | `code:  assert TestSelection.select(...) == {:mirror, ["test/x_test.exs"]}` `left:  {:coverage, ...` |
| P7 | the emit-time check dropped for the mirror file | 1 of 23: selection "a mirror target outside the project is never selected" | `code:  assert TestSelection.select(%{file: "lib/x.ex"}, inputs) == {:none, []}` `left:  {:mirror, ["../x_test.exs"]}` |
| P8 | the parse-time check skipped (the unfixed kill map) | 2 of 78: kill_map "DND-5640: ..."; run "DND-5640: a record whose killer is an option is refused loudly, never put in the argv" | `** (MatchError) no match of right hand side value: {:ok, ...` (the refused row parsed) |
| P9 | `CoverageMap.check/1` accepts any file | 1 of 18: coverage_map "check/1: ... a test file is a relative path inside the project that is not an option" | the loop's assertion for `"-x"` (`code: for file <- [...]`) |

P5, P6 and P7 are the emit-time check alone: their tests feed `select/2` an
index that skipped the parse-time check, so a red there shows the argv is
held even when a source's own reader is bypassed.

After the fix, every row restored: `mix test --max-cases 2
test/anchor/domain/sabotage/test_path_test.exs
test/anchor/domain/sabotage/kill_map_test.exs
test/anchor/domain/sabotage/test_selection_test.exs
test/anchor/domain/sabotage/coverage_map_test.exs`: `57 tests, 0 failures`;
`test/anchor/managers/sabotage_run_test.exs`: `69 tests, 0 failures`.
