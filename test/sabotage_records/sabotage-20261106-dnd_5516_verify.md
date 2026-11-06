# Sabotage record: mix anchor.sabotage verify

- **Domain:** sabotage
- **Branch:** dnd-5516-sabotage-verify
- **Date:** 2026-11-06
- **Code under test:** `Anchor.Domain.Sabotage.Verify` (`judge/4`, `survivors/1`, `record_path?/2`, `unmeasured_scope?/3`, `render/2`, `exit_code/1`), `Anchor.Domain.Sabotage.KillMap.parse_blocks/1`, `Anchor.Managers.Sabotage.Verify`, `Anchor.Domain.Sabotage.Scope.put_base_sha/2`, and the `verify` subcommand of `Mix.Tasks.Anchor.Sabotage` (DND-5516)
- **Suite run:** each mutation ran `mix test --timeout 2000 --max-cases 2 <its test files>` inside one `test-slot`, by a driver that applied it, moved the file's mtime ahead (so no same-second rewrite reuses a stale beam), ran the files and wrote the original back byte for byte. The checkout's absolute path in the output reads `<worktree>`.

Every mutation below reddens a test; each section shows the first failure, cut at 70 lines. The QA plan's constraint map: requirement 2 and AC6 (no compile, no test) are held by the Manager tests handing in the test-run and mutation doubles with no expectation; requirement 4 / AC3 (STALE) by VD-D, VD-E, VD-F; requirement 6 (a deleted record) by VD-K and VM-A; requirement 7 (exit codes) by VD-K, VM-B, VT-A, VT-B; requirement 8 (one `Fix:` per failure line) by VD-M.

Green first: every test file below, unmutated: `164 tests, 0 failures`.

| # | Mutation | Tests run | Result | Failing tests |
|---|---|---|---|---|
| VD-A | a timeout row covers nothing (`lib/anchor/domain/sabotage/verify.ex`) | `verify_test.exs` | `28 tests, 1 failure` (red) | judge/4 2: timeout and invalid rows count as covered |
| VD-B | any row covers, whatever its status (`lib/anchor/domain/sabotage/verify.ex`) | `verify_test.exs` | `28 tests, 2 failures` (red) | judge/4 2: timeout and invalid rows count as covered; judge/4 survived, no_tests and crashed rows cover nothing (positive control: killed does) |
| VD-C | a survivors entry covers whatever its file, function and operator (`lib/anchor/domain/sabotage/verify.ex`) | `verify_test.exs` | `28 tests, 1 failure` (red) | judge/4 a survivors entry naming another operator covers nothing and is a bad survivor |
| VD-D | every block's rows can be stale, not only the last run's (`lib/anchor/domain/sabotage/verify.ex`) | `verify_test.exs` | `28 tests, 2 failures` (red) | judge/4 a later record's block is the later run; judge/4 a row of an earlier run of the function is history, never stale |
| VD-E | a row of an unchanged function can be stale (`lib/anchor/domain/sabotage/verify.ex`) | `verify_test.exs` | `28 tests, 1 failure` (red) | judge/4 6: a row for a function the diff did not change is not stale |
| VD-F | nothing is ever stale (`lib/anchor/domain/sabotage/verify.ex`) | `verify_test.exs`, `sabotage_verify_integration_test.exs` | `31 tests, 3 failures` (red) | judge/4 5: a row of a changed function's last run whose id is no longer generated is stale; judge/4 a row of an earlier run of the function is history, never stale; 2: editing the function after its record makes the record STALE |
| VD-G | a mutant id made twice is not noticed (`lib/anchor/domain/sabotage/verify.ex`) | `verify_test.exs` | `28 tests, 1 failure` (red) | judge/4 a mutant id generated twice is COULD NOT MEASURE |
| VD-H | a refused survivors entry hides the good ones (`lib/anchor/domain/sabotage/verify.ex`) | `verify_test.exs` | `28 tests, 1 failure` (red) | survivors/1 TODO, empty, duplicate and malformed entries are refused; the good ones still count |
| VD-I | a README is a record (`lib/anchor/domain/sabotage/verify.ex`) | `verify_test.exs` | `28 tests, 1 failure` (red) | record_path?/2 a record under the records dir, an app's dir by {app}; never README or another dir |
| VD-J | a macro hunk does not count as measured (`lib/anchor/domain/sabotage/verify.ex`) | `verify_test.exs` | `28 tests, 1 failure` (red) | unmeasured_scope?/3 changed source files with nothing counted measured nothing |
| VD-K | a deleted record does not fail the verdict (`lib/anchor/domain/sabotage/verify.ex`) | `verify_test.exs`, `sabotage_verify_test.exs` | `43 tests, 3 failures` (red) | judge/4 9: a deleted landed record is carried; exit_code/1 2: each failure kind is 1; verify/2 8: a landed record the branch deleted is RECORD REMOVED; it is not read |
| VD-L | a timeout is not counted as killed in the summary (`lib/anchor/domain/sabotage/verify.ex`) | `verify_test.exs` | `28 tests, 1 failure` (red) | render/2 2: the summary line of a clean verdict |
| VD-M | RECORD REMOVED has no Fix: (`lib/anchor/domain/sabotage/verify.ex`) | `verify_test.exs` | `28 tests, 1 failure` (red) | render/2 1: each failure line ends with exactly one Fix: |
| VD-N | survivors the branch added are not printed (`lib/anchor/domain/sabotage/verify.ex`) | `verify_test.exs` | `28 tests, 1 failure` (red) | render/2 4: survivors added are printed for review, exit unaffected |
| VD-O | an empty scope prints counts, not 'no changed functions' (`lib/anchor/domain/sabotage/verify.ex`) | `verify_test.exs`, `anchor_sabotage_verify_test.exs` | `34 tests, 2 failures` (red) | render/2 an empty scope says so; run/2 (verify) 1: a clean verdict prints its summary and exits 0 |
| VK-A | an empty block is dropped (`lib/anchor/domain/sabotage/kill_map.ex`) | `kill_map_test.exs` | `11 tests, 1 failure` (red) | parse_blocks/1 (DND-5516) each block of an appended record is its own list, oldest first |
| VK-B | blocks come newest first (`lib/anchor/domain/sabotage/kill_map.ex`) | `kill_map_test.exs`, `verify_test.exs` | `39 tests, 2 failures` (red) | parse_blocks/1 (DND-5516) each block of an appended record is its own list, oldest first; render_block/1 and parse/1 3: every block of an appended record is read |
| VM-A | a deleted record is not seen (`lib/anchor/managers/sabotage/verify.ex`) | `sabotage_verify_test.exs`, `anchor_sabotage_verify_test.exs` | `21 tests, 2 failures` (red) | verify/2 8: a landed record the branch deleted is RECORD REMOVED; it is not read; run/2 (verify) 1: a failing verdict exits 1, its lines on stderr |
| VM-B | a ref with no merge-base is COULD NOT MEASURE, not usage (`lib/anchor/managers/sabotage/verify.ex`) | `sabotage_verify_test.exs`, `anchor_sabotage_verify_test.exs` | `21 tests, 2 failures` (red) | verify/2 4: a ref with no merge-base is {:error, {:bad_ref, ref}}; run/2 (verify) 2: no --base, a ref git cannot read, or one Anchor refuses, exits 2 with a Fix: |
| VM-C | changed sources with nothing found read as an empty scope (`lib/anchor/managers/sabotage/verify.ex`) | `sabotage_verify_test.exs` | `15 tests, 1 failure` (red) | verify/2 6: changed source files with nothing found in them is COULD NOT MEASURE |
| VM-D | a record that cannot be read is skipped (`lib/anchor/managers/sabotage/verify.ex`) | `sabotage_verify_test.exs` | `15 tests, 1 failure` (red) | verify/2 5: a record that cannot be read is COULD NOT MEASURE |
| VM-E | a bad kill map is not named (`lib/anchor/managers/sabotage/verify.ex`) | `sabotage_verify_test.exs` | `15 tests, 1 failure` (red) | verify/2 7: a record whose kill map does not parse is named and covers nothing |
| VM-F | a named survivors file absent is an empty list (`lib/anchor/managers/sabotage/verify.ex`) | `sabotage_verify_test.exs` | `15 tests, 1 failure` (red) | verify/2 a survivors file the config names that is absent is a bad survivor |
| VM-G | a base copy that cannot be read is no growth (`lib/anchor/managers/sabotage/verify.ex`) | `sabotage_verify_test.exs` | `15 tests, 1 failure` (red) | verify/2 a survivors file, or its base copy, that cannot be read is COULD NOT MEASURE |
| VM-H | the record's rows give no coverage (`lib/anchor/managers/sabotage/verify.ex`) | `sabotage_verify_test.exs`, `sabotage_verify_integration_test.exs` | `18 tests, 4 failures` (red) | verify/2 a survivors entry covers its mutant, and the entry the branch added is shown; verify/2 a record that covers one mutant fewer leaves it uncovered; verify/2 1 and 2: it composes the ports and the Domain, and runs no test and no mutant; 1: a record that covers every mutant of the changed function passes |
| VT-A | no --base defaults to main (`lib/mix/tasks/anchor.sabotage.ex`) | `anchor_sabotage_verify_test.exs` | `6 tests, 1 failure` (red) | run/2 (verify) 2: no --base, a ref git cannot read, or one Anchor refuses, exits 2 with a Fix: |
| VT-B | a failing verdict exits 0 (`lib/mix/tasks/anchor.sabotage.ex`) | `anchor_sabotage_verify_test.exs` | `6 tests, 2 failures` (red) | run/2 (verify) 1: a failing verdict exits 1, its lines on stderr; run/2 (verify) 1: COULD NOT MEASURE exits 3 |
| VS-A | the scope loses its merge-base sha (`lib/anchor/domain/sabotage/scope.ex`) | `sabotage_scope_test.exs`, `sabotage_run_test.exs` | `101 tests, 1 failure` (red) | run/2: sabotage records (DND-5484) 1: a run's record is created at Record.render's path with its content |

## VD-A: a timeout row covers nothing

```

  1) test judge/4 2: timeout and invalid rows count as covered (Anchor.Domain.Sabotage.VerifyTest)
     test/anchor/domain/sabotage/verify_test.exs:70
     Assertion with == failed
     code:  assert v.uncovered == []
     left:  [
              %Anchor.Domain.Sabotage.Mutant{
                id: "m1",
                file: "lib/calc.ex",
                module: Calc,
                function: {:add, 2},
                operator: :return_input,
                variant: nil,
                target: "",
                range: {{1, 1}, {1, 2}},
                original: "",
                replacement: "",
                patch: ""
              }
            ]
     right: []
     stacktrace:
       test/anchor/domain/sabotage/verify_test.exs:79: (test)

..
```

## VD-B: any row covers, whatever its status

```

  1) test judge/4 2: timeout and invalid rows count as covered (Anchor.Domain.Sabotage.VerifyTest)
     test/anchor/domain/sabotage/verify_test.exs:70
     Assertion with == failed
     code:  assert v.covered == [{"m1", :timeout}, {"m2", :invalid}]
     left:  [{"m1", :killed}, {"m2", :killed}]
     right: [{"m1", :timeout}, {"m2", :invalid}]
     stacktrace:
       test/anchor/domain/sabotage/verify_test.exs:80: (test)

......
```

## VD-C: a survivors entry covers whatever its file, function and operator

```

  1) test judge/4 a survivors entry naming another operator covers nothing and is a bad survivor (Anchor.Domain.Sabotage.VerifyTest)
     test/anchor/domain/sabotage/verify_test.exs:99
     match (=) failed
     code:  assert [%Mutant{id: "m1"}] = v.uncovered
     left:  [%Anchor.Domain.Sabotage.Mutant{id: "m1"}]
     right: []
     stacktrace:
       test/anchor/domain/sabotage/verify_test.exs:102: (test)

...
```

## VD-D: every block's rows can be stale, not only the last run's

```

  1) test judge/4 a later record's block is the later run (Anchor.Domain.Sabotage.VerifyTest)
     test/anchor/domain/sabotage/verify_test.exs:138
     Assertion with == failed
     code:  assert Verify.judge([mutant("m1")], rows, [], ctx()).stale_rows == []
     left:  [{"test/sabotage_records/a.md", "x", "Calc.add/2"}]
     right: []
     stacktrace:
       test/anchor/domain/sabotage/verify_test.exs:144: (test)

.........
```

## VD-E: a row of an unchanged function can be stale

```



  1) test judge/4 6: a row for a function the diff did not change is not stale (Anchor.Domain.Sabotage.VerifyTest)
     test/anchor/domain/sabotage/verify_test.exs:147
     Assertion with == failed
     code:  assert v.stale_rows == []
     left:  [{"test/sabotage_records/a.md", "y", "Calc.sub/2"}]
     right: []
     stacktrace:
       test/anchor/domain/sabotage/verify_test.exs:156: (test)

...........................
```

## VD-F: nothing is ever stale

```

  1) test judge/4 5: a row of a changed function's last run whose id is no longer generated is stale (Anchor.Domain.Sabotage.VerifyTest)
     test/anchor/domain/sabotage/verify_test.exs:115
     Assertion with == failed
     code:  assert v.stale_rows == [{"test/sabotage_records/a.md", "x", @mfa}]
     left:  []
     right: [{"test/sabotage_records/a.md", "x", "Calc.add/2"}]
     stacktrace:
       test/anchor/domain/sabotage/verify_test.exs:118: (test)

...........
```

## VD-G: a mutant id made twice is not noticed

```

  1) test judge/4 a mutant id generated twice is COULD NOT MEASURE (Anchor.Domain.Sabotage.VerifyTest)
     test/anchor/domain/sabotage/verify_test.exs:189
     ** (FunctionClauseError) no function clause matching in Kernel.=~/2

     The following arguments were given to Kernel.=~/2:

         # 1
         nil

         # 2
         "COULD NOT MEASURE: the generator made one mutant id twice: m1 (Calc.add/2)"

     Attempted function clauses (showing 3 out of 3):

         def =~(left, -""-) when -is_binary(left)-
         def =~(left, right) when -is_binary(left)- and is_binary(right)
         def =~(left, right) when -is_binary(left)-

     code: assert v.could_not_measure =~
     stacktrace:
       (elixir 1.19.4) lib/kernel.ex:2394: Kernel.=~/2
       test/anchor/domain/sabotage/verify_test.exs:192: (test)

...
```

## VD-H: a refused survivors entry hides the good ones

```

  1) test survivors/1 TODO, empty, duplicate and malformed entries are refused; the good ones still count (Anchor.Domain.Sabotage.VerifyTest)
     test/anchor/domain/sabotage/verify_test.exs:205
     match (=) failed
     code:  assert {[%Entry{id: "abcdef012345", line_no: 1}], refused} = Verify.survivors(lines)
     left:  {[%Anchor.Domain.Sabotage.Survivors.Entry{id: "abcdef012345", line_no: 1}], refused}
     right: {[],
             [
               {2,
                "the reason is a placeholder (TODO): write the real reason"},
               {3,
                "the reason is empty: say why no test can kill this mutant"},
               {4, "duplicate id abcdef012345: lines 1 and 4"},
               {5,
                "no reason: every entry ends `  # <why no test can kill it>` with a real reason"}
             ]}
     stacktrace:
       test/anchor/domain/sabotage/verify_test.exs:214: (test)

.........
```

## VD-I: a README is a record

```

  1) test record_path?/2 a record under the records dir, an app's dir by {app}; never README or another dir (Anchor.Domain.Sabotage.VerifyTest)
     test/anchor/domain/sabotage/verify_test.exs:226
     Expected false or nil, got true
     code: refute Verify.record_path?("test/sabotage_records/README.md", "test/sabotage_records")
     stacktrace:
       test/anchor/domain/sabotage/verify_test.exs:234: (test)

..........
```

## VD-J: a macro hunk does not count as measured

```

  1) test unmeasured_scope?/3 changed source files with nothing counted measured nothing (Anchor.Domain.Sabotage.VerifyTest)
     test/anchor/domain/sabotage/verify_test.exs:242
     Expected false or nil, got true
     code: refute Verify.unmeasured_scope?(1, 0, %{zero | macros: 1})
     arguments:

         # 1
         1

         # 2
         0

         # 3
         %{macros: 1, outside_hunks: 0}

     stacktrace:
       test/anchor/domain/sabotage/verify_test.exs:249: (test)

..............
```

## VD-K: a deleted record does not fail the verdict

```

  1) test judge/4 9: a deleted landed record is carried (Anchor.Domain.Sabotage.VerifyTest)
     test/anchor/domain/sabotage/verify_test.exs:167
     Assertion with == failed
     code:  assert Verify.exit_code(v) == 1
     left:  0
     right: 1
     stacktrace:
       test/anchor/domain/sabotage/verify_test.exs:171: (test)

........
```

## VD-L: a timeout is not counted as killed in the summary

```

  1) test render/2 2: the summary line of a clean verdict (Anchor.Domain.Sabotage.VerifyTest)
     test/anchor/domain/sabotage/verify_test.exs:325
     Assertion with == failed
     code:  assert Verify.render(v, :text) ==
              "sabotage verify: 3 functions, 9 mutants, all covered (7 killed, 1 survivors, 1 invalid)"
     left:  "sabotage verify: 3 functions, 9 mutants, all covered (6 killed, 1 survivors, 1 invalid)"
     right: "sabotage verify: 3 functions, 9 mutants, all covered (7 killed, 1 survivors, 1 invalid)"
     stacktrace:
       test/anchor/domain/sabotage/verify_test.exs:334: (test)

....
```

## VD-M: RECORD REMOVED has no Fix:

```

  1) test render/2 1: each failure line ends with exactly one Fix: (Anchor.Domain.Sabotage.VerifyTest)
     test/anchor/domain/sabotage/verify_test.exs:291
     RECORD REMOVED test/sabotage_records/c.md: a landed sabotage record was deleted. restore it; removing a record is a loosening (Cody's decision)
     code: for line <- failures do
     stacktrace:
       test/anchor/domain/sabotage/verify_test.exs:306: anonymous fn/2 in Anchor.Domain.Sabotage.VerifyTest."test render/2 1: each failure line ends with exactly one Fix:"/1
       (elixir 1.19.4) lib/enum.ex:2520: Enum."-reduce/3-lists^foldl/2-0-"/3
       test/anchor/domain/sabotage/verify_test.exs:305: (test)

......
```

## VD-N: survivors the branch added are not printed

```

  1) test render/2 4: survivors added are printed for review, exit unaffected (Anchor.Domain.Sabotage.VerifyTest)
     test/anchor/domain/sabotage/verify_test.exs:356
     Assertion with =~ failed
     code:  assert Verify.render(v, :text) =~
              "REVIEW survivor added: m1 lib/calc.ex Calc.add/2 return_input  # equivalent mutant"
     left:  "sabotage verify: 1 functions, 1 mutants, all covered (0 killed, 1 survivors, 0 invalid)"
     right: "REVIEW survivor added: m1 lib/calc.ex Calc.add/2 return_input  # equivalent mutant"
     stacktrace:
       test/anchor/domain/sabotage/verify_test.exs:364: (test)

.......................
```

## VD-O: an empty scope prints counts, not 'no changed functions'

```

  1) test render/2 an empty scope says so (Anchor.Domain.Sabotage.VerifyTest)
     test/anchor/domain/sabotage/verify_test.exs:338
     Assertion with == failed
     code:  assert Verify.render(%Verdict{}, :text) == "sabotage verify: no changed functions"
     left:  "sabotage verify: 0 functions, 0 mutants, all covered (0 killed, 0 survivors, 0 invalid)"
     right: "sabotage verify: no changed functions"
     stacktrace:
       test/anchor/domain/sabotage/verify_test.exs:339: (test)

......
```

## VK-A: an empty block is dropped

```

  1) test parse_blocks/1 (DND-5516) each block of an appended record is its own list, oldest first (Anchor.Domain.Sabotage.KillMapTest)
     test/anchor/domain/sabotage/kill_map_test.exs:136
     match (=) failed
     code:  assert {:ok, [first, [], [last]]} = KillMap.parse_blocks(text)
     left:  {:ok, [first, [], [last]]}
     right: {:ok,
             [
               [
                 %{
                   id: "aaa",
                   status: "killed",
                   file: "lib/calc.ex",
                   mfa: "Calc.add/2",
                   operator: "return_input",
                   killers: ["test/calc_test.exs:4 test adds",
                    "test/other_test.exs:9 test tab\there and\nnewline \\ slash"]
                 },
                 %{
                   id: "bbb",
                   status: "survived",
                   file: "lib/calc.ex",
                   mfa: "Calc.add/2",
                   operator: "return_input",
                   killers: []
                 },
                 %{
                   id: "ccc",
                   status: "timeout",
                   file: "lib/calc.ex",
                   mfa: "Calc.add/2",
                   operator: "return_input",
                   killers: ["(timeout)"]
                 },
                 %{
                   id: "ddd",
                   status: "invalid",
                   file: "lib/calc.ex",
                   mfa: "Calc.sub/2",
                   operator: "return_input",
                   killers: []
                 }
               ],
               [
                 %{
                   id: "eee",
                   status: "killed",
                   file: "lib/calc.ex",
                   mfa: "Calc.add/2",
                   operator: "return_input",
                   killers: ["t_test.exs:1 x"]
                 }
               ]
             ]}
     stacktrace:
       test/anchor/domain/sabotage/kill_map_test.exs:144: (test)

......
```

## VK-B: blocks come newest first

```

  1) test parse_blocks/1 (DND-5516) each block of an appended record is its own list, oldest first (Anchor.Domain.Sabotage.KillMapTest)
     test/anchor/domain/sabotage/kill_map_test.exs:136
     match (=) failed
     code:  assert {:ok, [first, [], [last]]} = KillMap.parse_blocks(text)
     left:  {:ok, [first, [], [last]]}
     right: {:ok,
             [
               [
                 %{
                   id: "eee",
                   status: "killed",
                   file: "lib/calc.ex",
                   mfa: "Calc.add/2",
                   operator: "return_input",
                   killers: ["t_test.exs:1 x"]
                 }
               ],
               [],
               [
                 %{
                   id: "aaa",
                   status: "killed",
                   file: "lib/calc.ex",
                   mfa: "Calc.add/2",
                   operator: "return_input",
                   killers: ["test/calc_test.exs:4 test adds",
                    "test/other_test.exs:9 test tab\there and\nnewline \\ slash"]
                 },
                 %{
                   id: "bbb",
                   status: "survived",
                   file: "lib/calc.ex",
                   mfa: "Calc.add/2",
                   operator: "return_input",
                   killers: []
                 },
                 %{
                   id: "ccc",
                   status: "timeout",
                   file: "lib/calc.ex",
                   mfa: "Calc.add/2",
                   operator: "return_input",
                   killers: ["(timeout)"]
                 },
                 %{
                   id: "ddd",
                   status: "invalid",
                   file: "lib/calc.ex",
                   mfa: "Calc.sub/2",
                   operator: "return_input",
                   killers: []
                 }
               ]
             ]}
     stacktrace:
       test/anchor/domain/sabotage/kill_map_test.exs:144: (test)

.....
```

## VM-A: a deleted record is not seen

```

  1) test verify/2 8: a landed record the branch deleted is RECORD REMOVED; it is not read (Anchor.Managers.SabotageVerifyTest)
     test/anchor/managers/sabotage_verify_test.exs:221
     Assertion with == failed
     code:  assert verdict.deleted_records == ["test/sabotage_records/old.md"]
     left:  []
     right: ["test/sabotage_records/old.md"]
     stacktrace:
       test/anchor/managers/sabotage_verify_test.exs:227: (test)

............sabotage verify: no changed functions
```

## VM-B: a ref with no merge-base is COULD NOT MEASURE, not usage

```

  1) test verify/2 4: a ref with no merge-base is {:error, {:bad_ref, ref}} (Anchor.Managers.SabotageVerifyTest)
     test/anchor/managers/sabotage_verify_test.exs:139
     ** (WithClauseError) no with clause matching:

         {:error, {:bad_ref_x, "origin/main"}}

     code: assert verify() == {:error, {:bad_ref, @base}}
     stacktrace:
       (anchor 0.1.0) lib/anchor/managers/sabotage/verify.ex:73: anonymous fn/2 in Anchor.Managers.Sabotage.Verify.verify/3
       test/anchor/managers/sabotage_verify_test.exs:146: (test)

......
```

## VM-C: changed sources with nothing found read as an empty scope

```

  1) test verify/2 6: changed source files with nothing found in them is COULD NOT MEASURE (Anchor.Managers.SabotageVerifyTest)
     test/anchor/managers/sabotage_verify_test.exs:179
     ** (Mox.UnexpectedCallError) no expectation defined for Anchor.BaselineStoreMock.read/2 in process #PID<0.1395.0> with args ["/repo", ".anchor/sabotage/survivors.txt"]
     code: assert {:ok, verdict} = verify()
     stacktrace:
       (mox 1.2.0) lib/mox.ex:903: Mox.__dispatch__/4
       (anchor 0.1.0) lib/anchor/managers/sabotage/verify.ex:210: Anchor.Managers.Sabotage.Verify.read_survivors/4
       (anchor 0.1.0) lib/anchor/managers/sabotage/verify.ex:202: Anchor.Managers.Sabotage.Verify.survivors/4
       (anchor 0.1.0) lib/anchor/managers/sabotage/verify.ex:77: Anchor.Managers.Sabotage.Verify.verify/3
       test/anchor/managers/sabotage_verify_test.exs:191: (test)

............
```

## VM-D: a record that cannot be read is skipped

```

  1) test verify/2 5: a record that cannot be read is COULD NOT MEASURE (Anchor.Managers.SabotageVerifyTest)
     test/anchor/managers/sabotage_verify_test.exs:167
     ** (Mox.UnexpectedCallError) no expectation defined for Anchor.BaselineStoreMock.read/2 in process #PID<0.1407.0> with args ["/repo", ".anchor/sabotage/survivors.txt"]
     code: assert {:ok, verdict} = verify()
     stacktrace:
       (mox 1.2.0) lib/mox.ex:903: Mox.__dispatch__/4
       (anchor 0.1.0) lib/anchor/managers/sabotage/verify.ex:207: Anchor.Managers.Sabotage.Verify.read_survivors/4
       (anchor 0.1.0) lib/anchor/managers/sabotage/verify.ex:199: Anchor.Managers.Sabotage.Verify.survivors/4
       (anchor 0.1.0) lib/anchor/managers/sabotage/verify.ex:77: Anchor.Managers.Sabotage.Verify.verify/3
       test/anchor/managers/sabotage_verify_test.exs:173: (test)

......
```

## VM-E: a bad kill map is not named

```

  1) test verify/2 7: a record whose kill map does not parse is named and covers nothing (Anchor.Managers.SabotageVerifyTest)
     test/anchor/managers/sabotage_verify_test.exs:205
     Assertion with == failed
     code:  assert verdict.bad_records == [{@record, 2, "a row has 2 fields, not 6"}]
     left:  []
     right: [
              {"test/sabotage_records/calc-20261106-x.md", 2,
               "a row has 2 fields, not 6"}
            ]
     stacktrace:
       test/anchor/managers/sabotage_verify_test.exs:217: (test)

.....
```

## VM-F: a named survivors file absent is an empty list

```

  1) test verify/2 a survivors file the config names that is absent is a bad survivor (Anchor.Managers.SabotageVerifyTest)
     test/anchor/managers/sabotage_verify_test.exs:250
     match (=) failed
     code:  assert [nil: message] = verdict.bad_survivors
     left:  [nil: message]
     right: []
     stacktrace:
       test/anchor/managers/sabotage_verify_test.exs:257: (test)

.....
```

## VM-G: a base copy that cannot be read is no growth

```

  1) test verify/2 a survivors file, or its base copy, that cannot be read is COULD NOT MEASURE (Anchor.Managers.SabotageVerifyTest)
     test/anchor/managers/sabotage_verify_test.exs:273
     ** (FunctionClauseError) no function clause matching in Kernel.=~/2

     The following arguments were given to Kernel.=~/2:

         # 1
         nil

         # 2
         "cannot be read at origin/main"

     Attempted function clauses (showing 3 out of 3):

         def =~(left, -""-) when -is_binary(left)-
         def =~(left, right) when -is_binary(left)- and is_binary(right)
         def =~(left, right) when -is_binary(left)-

     code: assert message =~ "cannot be read at origin/main"
     stacktrace:
       (elixir 1.19.4) lib/kernel.ex:2394: Kernel.=~/2
       test/anchor/managers/sabotage_verify_test.exs:287: (test)

............
```

## VM-H: the record's rows give no coverage

```

  1) test verify/2 a survivors entry covers its mutant, and the entry the branch added is shown (Anchor.Managers.SabotageVerifyTest)
     test/anchor/managers/sabotage_verify_test.exs:231
     Assertion with == failed
     code:  assert verdict.uncovered == []
     left:  [
              %Anchor.Domain.Sabotage.Mutant{
                id: "05ccd80be8e0",
                file: "lib/calc.ex",
                module: Calc,
                function: {:add, 2},
                operator: :return_input,
                variant: 1,
                target: "add(a, b)",
                range: {{2, 7}, {3, 10}},
                original: "add(a, b) do\n    a + b",
                replacement: "add(_a, b) do\n    b",
                patch: "--- a/lib/calc.ex\n+++ b/lib/calc.ex\n@@ -1,5 +1,5 @@\n defmodule Calc do\n-  def add(a, b) do\n-    a + b\n+  def add(_a, b) do\n+    b\n   end\n end\n"
              }
            ]
     right: []
     stacktrace:
       test/anchor/managers/sabotage_verify_test.exs:244: (test)

.......
```

## VT-A: no --base defaults to main

```



  1) test run/2 (verify) 2: no --base, a ref git cannot read, or one Anchor refuses, exits 2 with a Fix: (Mix.Tasks.Anchor.SabotageVerifyTest)
     test/mix/tasks/anchor_sabotage_verify_test.exs:99
     ** (FunctionClauseError) no function clause matching in anonymous fn/2 in Mix.Tasks.Anchor.SabotageVerifyTest."test run/2 (verify) 2: no --base, a ref git cannot read, or one Anchor refuses, exits 2 with a Fix:"/1

     The following arguments were given to anonymous fn/2 in Mix.Tasks.Anchor.SabotageVerifyTest."test run/2 (verify) 2: no --base, a ref git cannot read, or one Anchor refuses, exits 2 with a Fix:"/1:

         # 1
         "<worktree>"

         # 2
         "main"

     code: for {argv, said} <- [
     stacktrace:
       test/mix/tasks/anchor_sabotage_verify_test.exs:102: anonymous fn/2 in Mix.Tasks.Anchor.SabotageVerifyTest."test run/2 (verify) 2: no --base, a ref git cannot read, or one Anchor refuses, exits 2 with a Fix:"/1
       (hammox 0.7.0) lib/hammox.ex:402: anonymous fn/2 in Hammox.protected_code/3
       (hammox 0.7.0) lib/hammox/telemetry.ex:12: Hammox.Telemetry.NoOp.span/3
       (hammox 0.7.0) lib/hammox.ex:398: Hammox.protected_code/3
       (anchor 0.1.0) lib/anchor/managers/sabotage.ex:155: Anchor.Managers.Sabotage.merge_base/3
       (anchor 0.1.0) lib/anchor/managers/sabotage.ex:140: Anchor.Managers.Sabotage.changes/2
       (anchor 0.1.0) lib/anchor/managers/sabotage/verify.ex:105: Anchor.Managers.Sabotage.Verify.changes/3
       (anchor 0.1.0) lib/anchor/managers/sabotage/verify.ex:74: Anchor.Managers.Sabotage.Verify.verify/3
       (anchor 0.1.0) lib/mix/tasks/anchor.sabotage.ex:435: Mix.Tasks.Anchor.Sabotage.verify/3
       test/mix/tasks/anchor_sabotage_verify_test.exs:113: anonymous fn/1 in Mix.Tasks.Anchor.SabotageVerifyTest."test run/2 (verify) 2: no --base, a ref git cannot read, or one Anchor refuses, exits 2 with a Fix:"/1
       (ex_unit 1.19.4) lib/ex_unit/capture_io.ex:296: ExUnit.CaptureIO.do_with_io/3
       (ex_unit 1.19.4) lib/ex_unit/capture_io.ex:166: ExUnit.CaptureIO.capture_io/2
       test/mix/tasks/anchor_sabotage_verify_test.exs:112: anonymous fn/2 in Mix.Tasks.Anchor.SabotageVerifyTest."test run/2 (verify) 2: no --base, a ref git cannot read, or one Anchor refuses, exits 2 with a Fix:"/1
       (elixir 1.19.4) lib/enum.ex:2520: Enum."-reduce/3-lists^foldl/2-0-"/3
       test/mix/tasks/anchor_sabotage_verify_test.exs:106: (test)

.....
```

## VT-B: a failing verdict exits 0

```


  1) test run/2 (verify) 1: a failing verdict exits 1, its lines on stderr (Mix.Tasks.Anchor.SabotageVerifyTest)
     test/mix/tasks/anchor_sabotage_verify_test.exs:64
     Expected to catch exit, got nothing
     code: capture_io(:stderr, fn ->
     stacktrace:
       test/mix/tasks/anchor_sabotage_verify_test.exs:69: anonymous fn/0 in Mix.Tasks.Anchor.SabotageVerifyTest."test run/2 (verify) 1: a failing verdict exits 1, its lines on stderr"/1
       (ex_unit 1.19.4) lib/ex_unit/capture_io.ex:296: ExUnit.CaptureIO.do_with_io/3
       (ex_unit 1.19.4) lib/ex_unit/capture_io.ex:166: ExUnit.CaptureIO.capture_io/2
       test/mix/tasks/anchor_sabotage_verify_test.exs:68: (test)

..COULD NOT MEASURE: <worktree> is not a git work tree. Fix: run from the repository checkout.
```

## VS-A: the scope loses its merge-base sha

```

  1) test run/2: sabotage records (DND-5484) 1: a run's record is created at Record.render's path with its content (Anchor.Managers.SabotageRunTest)
     test/anchor/managers/sabotage_run_test.exs:1080
     Assertion with =~ failed
     code:  assert content =~ "- **Generated by:** `mix anchor.sabotage run` (Anchor 0.1.0), base abc, head"
     left:  "# Sabotage record: generated causal sabotage\n\n- **Domain:** calc\n- **Branch:** dnd-5484-records\n- **Date:** 2026-11-05\n- **Code under test:** `Calc.add/2`\n- **Suite run:** per mutant below (`mix test --max-cases 2` and its tests)\n- **Generated by:** `mix anchor.sabotage run` (Anchor 0.1.0), base (unknown), head 2222222222222222222222222222222222222222\n\n## Summary\n\n| id | function | mutation | status | killers |\n|---|---|---|---|---|\n| 05ccd80be8e0 | `Calc.add/2` | return_input [1] | killed | 1 |\n| d91ac044da9d | `Calc.add/2` | return_input [0] | survived | 0 |\n\n## Mutants\n\n### 05ccd80be8e0 Calc.add/2 return_input [1]: killed\n\n```diff\n--- a/lib/calc.ex\n+++ b/lib/calc.ex\n@@ -1,5 +1,5 @@\n defmodule Calc do\n-  def add(a, b) do\n-    a + b\n+  def add(_a, b) do\n+    b\n   end\n end\n```\n\nCommand: `mix test --max-cases 2 test/calc_test.exs` (2 tests, 1 failures; tests selected by mirror). Failed: test/calc_test.exs:4 test adds\n\n```\ntest/calc_test.exs:4 test adds\nAssertion failed\n```\n\n### d91ac044da9d Calc.add/2 return_input [0]: survived\n\n```diff\n--- a/lib/calc.ex\n+++ b/lib/calc.ex\n@@ -1,5 +1,5 @@\n defmodule Calc do\n-  def add(a, b) do\n-    a + b\n+  def add(a, _b) do\n+    a\n   end\n end\n```\n\nCommand: `mix test --max-cases 2 test/calc_test.exs` (2 tests, 0 failures; tests selected by mirror). Failed: none\n\n```\n(no test failed)\n```\n\n## Survivors\n\n- d91ac044da9d Calc.add/2 return_input [0]: the selected tests ran and passed. Fix: add a test that fails under this mutant\n\n## Kills by timeout\n\nNone.\n\n## Skipped, invalid, not run\n\nNone.\n\n## Tests still lacking a red\n\nNone.\n\n## Kill map\n\n```anchor-kills\n# id\tfile\tmfa\toperator\tstatus\tkillers\n05ccd80be8e0\tlib/calc.ex\tCalc.add/2\treturn_input\tkilled\ttest/calc_test.exs:4 test adds\nd91ac044da9d\tlib/calc.ex\tCalc.add/2\treturn_input\tsurvived\t\n```\n"
     right: "- **Generated by:** `mix anchor.sabotage run` (Anchor 0.1.0), base abc, head"
     stacktrace:
       test/anchor/managers/sabotage_run_test.exs:1095: (test)

............
```
