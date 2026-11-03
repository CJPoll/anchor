# Sabotage record — the survivors list (DND-5483)

- **Domain:** sabotage
- **Branch:** dnd-5483-survivors-replay
- **Date:** 2026-11-03
- **Code under test:** `Anchor.Domain.Sabotage.Survivors` (`parse/1`,
  `judge/2`, `grew/2`, `line_for/1`), `Anchor.Domain.Sabotage.Report` (the
  survivors exit code), `Anchor.Managers.Sabotage.Runner` (reading the list
  and its base copy, judging after the run)
- **Suite run:** per row, `mix test <the row's file> --timeout 2000
  --max-cases 2` through `test-slot` (the sabotage load rule). Every file was
  green before and after every row.

Each row was applied alone by a scratch driver that replaces one snippet,
runs the row's test file and writes the original back (checked byte-equal).
Failure strings are copied from its output. Rows the compiler refused first
(warnings as errors: an unused variable or clause) were rewritten so the
sabotage compiles; only the compiling form is recorded.

## DND-5483: the survivors list

The QA plan's four required breaks are U1 (accept a TODO reason), U2 (drop
the scope filter), U3 (judge unrun entries) and U4 (ignore `no_tests`).

| # | Mutation | Tests failed | First failure, verbatim |
|---|---|---|---|
| U1 | `@placeholder_words` emptied: a `TODO`, `TBD` or `FIXME` reason is accepted | 2 of 27: parse "2: a TODO, an empty and a fixme reason are refused, naming lines 1-3", "2b: TBD, a missing reason and the printed placeholder are refused too" | `code:  assert {:error, [{1, one}, {2, two}, {3, three}]} = Survivors.parse(lines)` `right: {:error,` (two lines, not three) |
| U2 | the scope filter made always true (`&1.mfa not in scope` added) | 1 of 27: judge "6: an entry for a function outside the scope is not judged at all" | `code: assert j.new == [] and j.stale == [] and j.unjudged == [] and j.held == []` |
| U3 | the `:not_run` check never matches: unrun entries are judged | 3 of 27: judge "5: a listed mutant the cap left unrun is not judged", "5b: a listed mutant --only left out is not judged", "violation?/1 ..." | `code:  assert j.stale == []` `left:  [ {%Anchor.Domain.Sabotage.Survivors.Entry{` |
| U4 | `@survivor_statuses [:survived]`: `no_tests` ignored | 1 of 27: judge "7: an unlisted no_tests mutant is new" | `code:  assert Enum.map(j.new, & &1.mutant.id) == [@d]` `left:  []` `right: ["dddddddddddd"]` |
| U5 | the id/file/operator mismatch check skipped | 2 of 27: judge "9: an entry whose file differs from its outcome's is malformed, never held", "9b: an operator mismatch is malformed too" | `code:  assert j.held == []` `left:  [ %Anchor.Domain.Sabotage.Survivors.Entry{` |
| U6 | `grew/2` compares with an empty base | 3 of 27: grew "1: working [A, B], base [A]: B", "3: working [A], base [A, B]", "a reason changed on the branch is not growth" | `code:  assert Survivors.grew([entry(@a), entry(@b)], base) == {:added, [entry(@b)]}` `left:  {:added, [` |
| U7 | duplicate ids not reported | 1 of 27: parse "3: a duplicate id names both lines" | `code:  assert {:error, [{3, message}]} = Survivors.parse(lines)` `right: {:ok,` |
| R1 | `Report`: the judgement never fails the run | 4 of 41: "the survivors list" S1, S2, S5, S7 | `code:  assert Report.exit_code(run) == 1` `left:  0` `right: 1` |
| R2 | `Report`: with the list judged, a crash no longer fails | 1 of 41: S6 "a crashed mutant fails the run even with the list judged" | `code:  assert Report.exit_code(run) == 1` `left:  0` `right: 1` |
| R3 | `Report`: with the list judged, a listed survivor still fails (the old rule) | 1 of 41: S3 "only held and GREW: exit 0 ..." | `code:  assert Report.exit_code(run) == 0` `left:  1` `right: 0` |
| M1 | `Runner`: the judgement dropped (an empty one set) | 10 of 86: SV1, SV1b, SV3, SV5, SV6, SV7, the DND-5484 record rows that assert exit 1, and "7: ... killed then survived, exit 1" | `code:  assert [%{id: id}] = run.survivors.judgement.held` `right: []` |
| M2 | `Runner`: a named survivors file that is absent read as the default | 1 of 86: SV2 "a survivors path named in the config that is absent: exit 1 ..." | `** (FunctionClauseError) no function clause matching in anonymous fn/3 in Anchor.Managers.SabotageRunTest.__ex_unit_setup_1/1` (the run went on to read the base copy at the default path) |
| M3 | `Runner`: an unreadable base copy read as absent | 1 of 86: SV4 "a base copy that cannot be read is exit 3; nothing applied" | `code: assert %{refusal: {3, message}} = Sabotage.run(@facts, @opts)` (`Mox.__dispatch__`: the run went on to the baseline) |
| M4 | `Runner`: a dry run reads the list | 1 of 86: SV8 "a dry run reads no list and judges nothing" | `** (Mox.UnexpectedCallError) expected Anchor.BaselineStoreMock.read/2 to be called 0 times but it has been called once` |

After every row was restored: `survivors_test.exs` 27 tests, 0 failures;
`report_test.exs` 41 tests, 0 failures; `sabotage_run_test.exs` 86 tests,
0 failures.
