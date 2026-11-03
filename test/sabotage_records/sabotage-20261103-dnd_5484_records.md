# Sabotage record — generated sabotage records and the kill map (DND-5484)

- **Domain:** sabotage
- **Branch:** dnd-5474-coverage-records
- **Date:** 2026-11-03
- **Code under test:** `Anchor.Domain.Sabotage.KillMap` (`render_block/1`,
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
| D7 | the mirror wins over the kill map | 2 of 74: selection "1: a function earlier records show killed selects its killers' files, over the mirror"; run "an earlier record's kill map selects the killers' files for the same function" | `code:  assert TestSelection.select(km_mutant({:f, 1}), inputs) == {:kill_map, ["test/t1_test.exs"]}` `left:  {:mirror, ["test/x_test.exs"]}` |
| D8 | the slot's ticket key is not upper-cased | 7 of 22: record_naming "1: a ticket key in the branch, matched case-insensitively and upper-cased" and six more | `code:  assert RecordNaming.slot("dnd-5473-runner") == {:ok, %{slot: "DND_5473", ticket: "DND-5473"}}` `left:  {:ok, %{slot: "dnd_5473", ticket: "dnd-5473"}}` |
| D9 | every test in a changed file counts as changed, whatever the ranges | 4 of 5: changed_tests "1: a range inside a describe's test ...", "2: a range on a line between tests gives none", "3: a range spanning two tests gives both", "a top-level one-line test, and a deletion point inside a test" | `code:  assert in_ranges([{12, 2}]) == {:ok, [%{file: "test/a_test.exs", line: 11, name: "test a second"}]}` |
| D10 | `branch/1` reads git's exit 1 (detached HEAD) as a failure | 1 of 5: git_status "branch/1 (DND-5484) the branch's short name; nil on a detached HEAD" | `code:  assert GitStatus.branch(root) == {:ok, nil}` `left:  {:error, {:git_failed, ["symbolic-ref", "--quiet", "--short", "HEAD"], 1, ""}}` |
| D11 | `--no-record` is ignored (`no_record: false`) | first run: **0 of 4, a measured zero**: the task test only proved the flags parse. Fixed by extracting `run_facts/1` and adding "DND-5484: run_facts/1 maps the record flags ..."; re-run: 1 of 5 | `code:  assert %{no_record: true, domain: "d", ticket: "DND-1", slot: "s"} = facts` |

Two driver mutations did not compile under `--warnings-as-errors` and were
rewritten before the rows above counted (D9's first form left `meets?/2`
unused; D11's first re-run hit a `run/2` clause-grouping warning from the
refactor itself, fixed before the row ran).

## The integration run

`test/anchor/integration/sabotage_run_integration_test.exs` runs the whole
command on a throwaway project on branch `dnd-77-calc`: one killed and one
survived mutant. It now asserts the record
`test/sabotage_records/calc-20261105-DND_77.md` is created, carries the
killer's `code:` line, lists no test lacking a red, and that its kill map
parses back to the run's two outcomes. Writing that assertion found that the
saved `last-run.etf` was written before the records, so it never named them;
the run is now saved after its records are written.
