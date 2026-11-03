# Sabotage record — generated sabotage records and the kill map (DND-5484)

- **Domain:** sabotage
- **Branch:** dnd-5474-coverage-records
- **Date:** 2026-11-03
- **Code under test:** `Anchor.Domain.Sabotage.Config` (`records`),
  `Anchor.Domain.Sabotage.Scope.test_changes/1`,
  `Anchor.Adapters.ProjectModules`, `Anchor.Adapters.TestRunner` and
  `Anchor.Sabotage.ExUnitFormatter` (the project root),
  `Anchor.Domain.Sabotage.KillMap` (`render_block/1`,
  `parse/1`), `Anchor.Domain.Sabotage.RecordNaming` (`slot/2`, `path/2`),
  `Anchor.Domain.Sabotage.Record.render/2`,
  `Anchor.Domain.Sabotage.ChangedTests.in_ranges/3`,
  `Anchor.Domain.Sabotage.TestSelection.select/2` (the `:kill_map` source),
  `Anchor.Managers.Sabotage.Runner` (`existing_records`, `write_records`),
  `Anchor.Adapters.RecordFile.create/3`, `Anchor.Adapters.GitStatus.branch/1`,
  `Mix.Tasks.Anchor.Sabotage.run_facts/1`
- **Suite run:** per row, `mix test <the files the row names> --timeout 2000
  --max-cases 2` through `test-slot` (the sabotage load rule). Every file was
  green before and after every row.

Each mutation was applied alone by the same scratch driver as the DND-5474
record: it replaces one exact text, moves the file's mtime forward, runs the
files, then writes the original back with a later mtime. Failure strings are
copied from its output.

| # | Mutation | Tests failed | First failure, verbatim |
|---|---|---|---|
| D1 | `escape/1` drops the tab escape (QA required break) | 3 of 15: kill_map "2: parse(render) gives the rows back, a tab, a newline and a backslash included", "3: every block of an appended record is read", "1: the block equals the golden text" | `code:  assert KillMap.parse("# Record\n\n" <> KillMap.render_block(outcomes())) ==` `left:  {:error, {5, "a row has 7 fields, not 6"}}` |
| D2 | `ticket_nn_what` numbers from the count of names, not the highest (QA required break) | 1 of 22: record_naming "4: ticket_nn_what numbers one above the highest, not the count" | `code:  assert RecordNaming.path(@gen_saas, ctx(%{app: "core", slot: slot, existing_names: names})) == {:ok, "apps/core/test/sabotage_records/DND-77-04-anchor-sabotage-run.md"}` |
| D3 | every changed test is listed as lacking a red, killers included (QA required break) | 2 of 8: record "6: changed tests [T1, T2] with T1 a killer: only T2 lacks a red", "1: one :create entry whose content equals the golden record" | `code:  refute lacking =~ "calc_test.exs:4 "` `left:  "\n- test/anchor/domain/sabotage/calc_test.exs:4 \"test adds\": no generated mutant failed it. ...` |
| D4 | no record is written when the run exits 1 (a survivor) (QA required break) | 4 of 55: run "4: a run that exits 1 (a survivor) still writes its record", "1: a run's record is created at Record.render's path ...", "a record already there the same day is appended to", "a record that cannot be written is exit 2, after the outcomes" | `code:  assert Report.exit_code(run) == 2` `left:  1` `right: 2` |
| D5 | `RecordFile.create/3` opens without `:exclusive` (overwrites) | 1 of 4: record_file "2: create on an existing path is :eexist and leaves the file untouched" | `code:  assert RecordFile.create(root, "r/a.md", "new\n") == {:error, :eexist}` `left:  :ok` |
| D6 | a malformed kill map is read as empty, silently | 1 of 55: run "3: a malformed kill map in an existing record: selection falls back, the line is said" | `code:  assert run.notes == ["could not read kill map in #{bad}:3 (a row has 4 fields, not 6); not used for selection"]` `left:  []` |
| D7 | the mirror wins over the kill map (re-run after the review floor's fix below, which adds the mirror file to a kill-map selection) | 2 of 78: selection "1: a function earlier records show killed selects its killers' files, and the mirror's"; run "an earlier record's kill map selects the killers' files for the same function" | `code:  assert TestSelection.select(km_mutant({:f, 1}), inputs) == {:kill_map, ["test/t1_test.exs", "test/x_test.exs"]}` `left:  {:mirror, ["test/x_test.exs"]}` |
| D8 | the ticket key is not upper-cased (run before the slot became the branch, below) | 7 of 22: record_naming "1: a ticket key in the branch, matched case-insensitively and upper-cased" and six more | `code:  assert RecordNaming.slot("dnd-5473-runner") == {:ok, %{slot: "DND_5473", ticket: "DND-5473"}}` `left:  {:ok, %{slot: "dnd_5473", ticket: "dnd-5473"}}` |
| D9 | every test in a changed file counts as changed, whatever the ranges | 4 of 5: changed_tests "1: a range inside a describe's test ...", "2: a range on a line between tests gives none", "3: a range spanning two tests gives both", "a top-level one-line test, and a deletion point inside a test" | `code:  assert in_ranges([{12, 2}]) == {:ok, [%{file: "test/a_test.exs", line: 11, name: "test a second"}]}` |
| D10 | `branch/1` reads git's exit 1 (detached HEAD) as a failure | 1 of 5: git_status "branch/1 (DND-5484) the branch's short name; nil on a detached HEAD" | `code:  assert GitStatus.branch(root) == {:ok, nil}` `left:  {:error, {:git_failed, ["symbolic-ref", "--quiet", "--short", "HEAD"], 1, ""}}` |
| D11 | `--no-record` is ignored (`no_record: false`) | first run: **0 of 4, a measured zero**: the task test only proved the flags parse. Fixed by extracting `run_facts/1` and adding "DND-5484: run_facts/1 maps the record flags ..."; re-run: 1 of 5 | `code:  assert %{no_record: true, domain: "d", ticket: "DND-1", slot: "s"} = facts` |

Two driver mutations did not compile under `--warnings-as-errors` and were
rewritten before the rows above counted (D9's first form left `meets?/2`
unused; D11's first re-run hit a `run/2` clause-grouping warning from the
refactor itself, fixed before the row ran).

## Rows for tests the review floor found unbroken

The ADR reviewer found new tests citing a record with no row breaking them
(`ProjectModules`, `Config.records`, `Scope.test_changes`); they are broken
here.

| # | Mutation | Tests failed | First failure, verbatim |
|---|---|---|---|
| D12 | `ProjectModules.list/1` reads every file in an ebin dir, not only `*.beam` | 1 of 1: project_modules "each *.beam names a module; other files and other directories do not" | `code:  assert ProjectModules.list([a, b]) == [Anchor.Alpha, Anchor.Zed]` `left:  [Anchor.Alpha, Anchor.Zed, :"anchor.app"]` |
| D13 | `Config` takes any string as a `naming` | 1 of 7: config "2: each refusal names its key and ends with a Fix: line" | `** (KeyError) key "by_date" not found in: %{"domain_date_slot" => :domain_date_slot, "ticket_nn_what" => :ticket_nn_what}` |
| D14 | `Scope.test_changes/1` keeps a deleted test file | 1 of 20: scope "DND-5484: test_changes holds each changed _test.exs file's hunks, not a deleted one" | `left:  %{"apps/a/test/y_test.exs" => [{1, 3}], "test/gone_test.exs" => [], ...` |

## Critic round 1 and the review floor (DND-5484)

The critic found that the ExUnit formatter wrote each failed test's path
relative to the working directory, and an umbrella's `mix test` runs each
app's tests from inside `apps/<app>`: every killer in an umbrella would be
recorded as `test/x_test.exs`, so kill-map selection would drop it and "still
lacking a red" would list tests that had killed. The fix: `TestRunner` passes
the project root as `ANCHOR_SABOTAGE_ROOT`, and the formatter writes paths
relative to it.

The review floor found: the kill map selection never ran the mirror file (a
branch's new tests for a function a record already names); a `records.dir`
written `test/sabotage_records/` never matched the listed records, so a
second run that day failed `:eexist` instead of appending; `renumbered`
had no test; `--domain`/`--ticket` went into a file name unchecked; a dry
run was refused for a missing record slot; and the slot was the ticket key,
where ADR 003 says the sanitized branch, case kept. Each is fixed, and each
fix is broken here:

| # | Mutation | Tests failed | First failure, verbatim |
|---|---|---|---|
| D15 | the formatter ignores the root (`relative_to_cwd`) | 1 of 3: formatter "DND-5484: with a root, an umbrella app's test file keeps its apps/<app>/ prefix" | `left:  [{:test_failed, "tmp/Anchor.Sabotage.ExUnitFormatterTest/.../umbrella/apps/core/test/calc_test.exs", 4, "test adds", ...` |
| D16 | `TestRunner` passes an empty `ANCHOR_SABOTAGE_ROOT` | 1 of 1 (run alone, `test_runner_test.exs:88`): "the project root reaches the formatter as ANCHOR_SABOTAGE_ROOT". Run with the whole file under `--timeout 2000`, "5: a run that hangs is killed by the bound" also timed out: its bound needs more than the load rule's 2 s, unrelated to the mutation | `left:  "test/calc_test.exs --formatter Anchor.Sabotage.ExUnitFormatter --formatter ExUnit.CLIFormatter\nroot=\n"` |
| D17 | a kill-map selection drops the mirror file | 1 of 19: selection "1: a function earlier records show killed selects its killers' files, and the mirror's" | `left:  {:kill_map, ["test/t1_test.exs"]}` `right: {:kill_map, ["test/t1_test.exs", "test/x_test.exs"]}` |
| D18 | `records.dir` kept as written | 1 of 7: config "DND-5484: records.dir is read without a leading ./ or a trailing /" | `** (MatchError) no match of right hand side value: {:ok, %Anchor.Domain.Sabotage.Config{...` |
| D19 | the ticket retry ignores the fresh listing (retries the same number) | 1 of 59: run "ticket_nn_what: a number another run took meanwhile is retried once, at the next" | `code:  assert Sabotage.run(@rec_facts, @opts).records == [create: second]` `left:  []` |
| D20 | under `domain_date_slot`, a record that appeared meanwhile is appended to in place of the refusal | 1 of 59: run "domain_date_slot: a record that appeared meanwhile is never overwritten: exit 2" | `** (Mox.UnexpectedCallError) no expectation defined for Anchor.RecordStoreMock.append/3` |
| D21 | `--domain`/`--ticket` not checked | 1 of 59: run "--domain and --ticket must be names, never paths: exit 2 before anything is read" | `** (Mox.UnexpectedCallError) no expectation defined for Anchor.GitWorktreeMock.branch/1` |
| D22 | a dry run still checks what a record needs | 1 of 59: run "a dry run needs nothing a record needs: a detached HEAD is not refused" | `** (Mox.UnexpectedCallError) no expectation defined for Anchor.GitWorktreeMock.branch/1` |
| D23 | the slot is the ticket key again (the pre-ADR-003 behaviour) | 4 of 14: record_naming "1: the slot is the branch sanitized, case kept (ADR 003) ...", "3: domain_date_slot" and two more | `code:  assert RecordNaming.path(@anchor, ctx(%{})) == {:ok, "test/sabotage_records/sabotage-20261105-dnd_5473_runner.md"}` `left:  {:ok, "test/sabotage_records/sabotage-20261105-DND_5473.md"}` |

## Critic round 2 (one finding)

The critic found that the killers in a kill-map row were joined by ` ; `
without escaping it, so a test named `test a ; b` read back as two killers.
The fix: a `;` is escaped `\;` in every field, each killer is escaped on its
own before the join, and the field is split before it is unescaped.

| # | Mutation | Tests failed | First failure, verbatim |
|---|---|---|---|
| D24 | the `;` escape removed (the unfixed encoding) | 1 of 8: kill_map "a test name holding the separator ` ; ` reads back as one killer" | `code:  assert row.killers == ["t:1 test a ; b", "t:2 test c;d"]` `left:  ["t:1 test a", "b", "t:2 test c;d"]` |

## Merging origin/main (39f55e1)

The final gate found a textual conflict with main (the DND-5570, DND-5617
and DND-5618 batches). After the merge, main's DND-5617 task test (a changed
function that yields no mutant) failed: the run asked git for the branch to
name a record no mutant would fill. A run with no mutant to run now writes no
record and checks nothing a record needs. The root env for the formatter
moved into main's rewritten `TestRunner.execute/4`, and its test now reads
the injected command runner's env.

| # | Mutation | Tests failed | First failure, verbatim |
|---|---|---|---|
| D25 | a run with no mutant still checks what a record needs | 2 of 75: run "a run with no mutant to run writes no record and needs no branch"; task "DND-5617: changed functions that yield no mutant print a line each and the count, exit 0" | `** (Mox.UnexpectedCallError) no expectation defined for Anchor.GitWorktreeMock.branch/1 in process #PID<0.284.0> with args ["/repo"]` |

## The integration run

`test/anchor/integration/sabotage_run_integration_test.exs` runs the whole
command on a throwaway project on branch `dnd-77-calc`: one killed and one
survived mutant. It now asserts the record
`test/sabotage_records/calc-20261105-dnd_77_calc.md` is created, carries the
killer's `code:` line, lists no test lacking a red, and that its kill map
parses back to the run's two outcomes. Writing that assertion found that the
saved `last-run.etf` was written before the records, so it never named them;
the run is now saved after its records are written.
