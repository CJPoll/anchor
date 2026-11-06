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

## DND-5485: replaying landed records

The QA plan's three required breaks are P1 (treat drifted as lost power),
P2 (exit 0 on zero rows) and P3 (skip the baseline). P6 and P7 also ran the
integration test (a real tmp project, no doubles).

| # | Mutation | Tests failed | First failure, verbatim |
|---|---|---|---|
| P1 | `exit_code/1` counts every drifted row as lost power | 2 of 23: exit_code "4: rows, every one drifted: 3", "5: some drifted, the rest still killed: 0" | `code:  assert Replay.exit_code(r) == 3` `left:  1` `right: 3` |
| P2 | zero rows is exit 0 | 3 of 30: exit_code "3: zero rows: 3"; manager "zero rows: exit 3, naming the directories searched ...", "--records names the directory globs read ..." | `code:  assert Replay.exit_code(%Result{rows: 0}) == 3` `left:  0` `right: 3` |
| P3 | the baseline (killers with no mutant) skipped | 4 of 7: manager rows 1-4 | `** (Mox.VerificationError) error while verifying mocks` (row 1: the mutant was applied with main red) |
| P4 | `KillerRef.parse/1` splits on the last `:<digits> ` | 1 of 7: "2: a name holding : and digits is split on the first :<digits> only" | `left:  {:error, {:bad_path, :not_a_test_file}}` |
| P5 | the inside-the-project check on a row's file always passes | 1 of 23: plan "a row whose file is outside the project is drifted before anything is read" | `code:  assert plan([i], facts(%{sources: %{file => true}})).drifted == [{i, :file_outside}]` |
| P6 | `to_test_args/1` drops the `--only test:` filters (whole files) | 6 of 15: killer_ref row 3; manager rows 2, 3; the integration test (two tests ran, not one) | `** (FunctionClauseError) no function clause matching in anonymous fn/3 in Anchor.Managers.SabotageReplayTest."test 3: ..."` (the double was called with the file alone) |
| P7 | `judge/2` reads a survived run as still killed | 3 of 31: judge "3: passed"; manager row 3; the integration test | `code:  assert Replay.judge(item(), %{status: :survived, reason: nil}) ==` `left:  :still_killed` |
| P8 | the dirty-file check given no files | 5 of 7: "a replayable row's file with uncommitted changes refuses, exit 2 ..." and rows 1-4 | `** (Mox.UnexpectedCallError) no expectation defined for Anchor.TestExecutionMock.run/3` |
| P9 | (critic round 1 note) a baseline that ran no test read as a red main | 1 of 8: "every named killer gone (the baseline ran no test): exit 3, said as drift, not a red main" | `code:  assert message =~ "every test the rows name is gone (renamed or deleted)"` `left:  "COULD NOT MEASURE: the recorded killers did not pass with no mutant applied (no_tests): nothing can be judged. ..."` |

After every row was restored: `replay_test.exs` and `killer_ref_test.exs`
30 tests, 0 failures; `sabotage_replay_test.exs` 8 tests, 0 failures;
`sabotage_replay_integration_test.exs` 1 test, 0 failures.

### The frame atoms (a defect replay found)

The first real `mix anchor.sabotage run` on this branch crashed on its
baseline: `TestRunner` decodes the formatter's frames with
`binary_to_term(bin, [:safe])`, and the task's VM never loads ExUnit or the
formatter, so `:suite_started` did not exist there. Every test so far ran in
a test VM, where ExUnit had made the atom. The regression test R1
(`test_runner_test.exs`) decodes in a fresh `elixir` VM with only Anchor's
ebin on the path.

| # | Mutation | Tests failed | First failure, verbatim |
|---|---|---|---|
| R1 | the unfixed adapter (no `@frame_tags`); then `_tags = @frame_tags`, which the compiler drops | 1 of 19 both times: "R1: the frames decode in a VM that never loaded ExUnit or the formatter" | `** (ArgumentError) errors were found at the given arguments:` `* 1st argument: invalid or unsafe external representation of a term` `:erlang.binary_to_term(<<131, 104, 1, 119, 13, 115, 117, 105, 116, 101, 95, 115, 116, 97, 114, 116, 101, 100>>, [:safe])` |

After the fix (`Enum.each(@frame_tags, &Atom.to_string/1)` before each
decode): 19 tests, 0 failures.

## Run 14:52 UTC

- **Code under test:** `Anchor.Domain.Sabotage.KillerRef.parse/1`, `Anchor.Domain.Sabotage.KillerRef.split/1`, `Anchor.Domain.Sabotage.KillerRef.to_test_args/1`, `Anchor.Domain.Sabotage.Replay.exit_code/1`, `Anchor.Domain.Sabotage.Replay.inside?/1`, `Anchor.Domain.Sabotage.Replay.judge/2`
- **Generated by:** `mix anchor.sabotage run --only a42909400ea9 --only ab4e6c2528b1 --only ddec05bb88b0 --only 2847816286c4 --only 57820ad8253d --only 6a4e2dda24a0 --only 0c4c8944cdc9 --only f846683dba5d --only 3f57e7db56aa --only 5702dc500749` (Anchor 0.1.0), base 8cf5d64825b10de85f479143858ee4f1ac5b76da, head 347a9c58e8f13e4b7f6bba8983745d5cd4f58cfd

### Summary

| id | function | mutation | status | killers |
|---|---|---|---|---|
| a42909400ea9 | `Anchor.Domain.Sabotage.KillerRef.parse/1` | narrow_clause | killed | 1 |
| ab4e6c2528b1 | `Anchor.Domain.Sabotage.KillerRef.parse/1` | narrow_clause | killed | 1 |
| ddec05bb88b0 | `Anchor.Domain.Sabotage.KillerRef.parse/1` | narrow_clause | killed | 5 |
| 2847816286c4 | `Anchor.Domain.Sabotage.KillerRef.split/1` | return_input [0] | killed | 5 |
| 57820ad8253d | `Anchor.Domain.Sabotage.KillerRef.to_test_args/1` | return_input [0] | killed | 1 |
| 6a4e2dda24a0 | `Anchor.Domain.Sabotage.Replay.exit_code/1` | force_condition [true] | killed | 2 |
| 0c4c8944cdc9 | `Anchor.Domain.Sabotage.Replay.exit_code/1` | narrow_clause | killed | 6 |
| f846683dba5d | `Anchor.Domain.Sabotage.Replay.inside?/1` | return_input [0] | killed | 9 |
| 3f57e7db56aa | `Anchor.Domain.Sabotage.Replay.judge/2` | narrow_clause | killed | 1 |
| 5702dc500749 | `Anchor.Domain.Sabotage.Replay.judge/2` | narrow_clause | killed | 2 |

### Mutants

#### a42909400ea9 Anchor.Domain.Sabotage.KillerRef.parse/1 narrow_clause: killed

```diff
--- a/lib/anchor/domain/sabotage/killer_ref.ex
+++ b/lib/anchor/domain/sabotage/killer_ref.ex
@@ -27,7 +27,7 @@
   @spec parse(String.t()) ::
           {:ok, t()} | {:error, :not_a_test | {:not_a_ref, String.t()} | {:bad_path, atom()}}
   def parse(@test_timeout <> killer), do: parse(killer)
-  def parse("(" <> _placeholder), do: {:error, :not_a_test}
+  def parse("(" <> _placeholder) when node() == :__anchor_sabotage_never__, do: {:error, :not_a_test}
 
   def parse(killer) when is_binary(killer) do
     with {:ok, file, line, name} <- split(killer),
```

Command: `mix test --max-cases 2 --timeout 2000 test/anchor/domain/sabotage/killer_ref_test.exs` (7 tests, 1 failures; tests selected by mirror). Failed: test/anchor/domain/sabotage/killer_ref_test.exs:37 test 4: the bound's (timeout) names no test

```
test/anchor/domain/sabotage/killer_ref_test.exs:37 test 4: the bound's (timeout) names no test
** (ExUnit.AssertionError) 

Assertion with == failed
code:  assert KillerRef.parse("(timeout)") == {:error, :not_a_test}
left:  {:error, {:not_a_ref, "(timeout)"}}
right: {:error, :not_a_test}

```

#### ab4e6c2528b1 Anchor.Domain.Sabotage.KillerRef.parse/1 narrow_clause: killed

```diff
--- a/lib/anchor/domain/sabotage/killer_ref.ex
+++ b/lib/anchor/domain/sabotage/killer_ref.ex
@@ -26,7 +26,7 @@
   @doc "The test a killer names, or why it names none."
   @spec parse(String.t()) ::
           {:ok, t()} | {:error, :not_a_test | {:not_a_ref, String.t()} | {:bad_path, atom()}}
-  def parse(@test_timeout <> killer), do: parse(killer)
+  def parse(@test_timeout <> killer) when node() == :__anchor_sabotage_never__, do: parse(killer)
   def parse("(" <> _placeholder), do: {:error, :not_a_test}
 
   def parse(killer) when is_binary(killer) do
```

Command: `mix test --max-cases 2 --timeout 2000 test/anchor/domain/sabotage/killer_ref_test.exs` (7 tests, 1 failures; tests selected by mirror). Failed: test/anchor/domain/sabotage/killer_ref_test.exs:41 test a per-test timeout's killer names its test

```
test/anchor/domain/sabotage/killer_ref_test.exs:41 test a per-test timeout's killer names its test
** (ExUnit.AssertionError) 

Assertion with == failed
code:  assert KillerRef.parse("(test timeout) test/a_test.exs:9 test slow") ==
              {:ok, %{file: "test/a_test.exs", line: 9, name: "test slow"}}
left:  {:error, :not_a_test}
right: {:ok, %{line: 9, name: "test slow", file: "test/a_test.exs"}}

```

#### ddec05bb88b0 Anchor.Domain.Sabotage.KillerRef.parse/1 narrow_clause: killed

```diff
--- a/lib/anchor/domain/sabotage/killer_ref.ex
+++ b/lib/anchor/domain/sabotage/killer_ref.ex
@@ -29,7 +29,7 @@
   def parse(@test_timeout <> killer), do: parse(killer)
   def parse("(" <> _placeholder), do: {:error, :not_a_test}
 
-  def parse(killer) when is_binary(killer) do
+  def parse(killer) when (is_binary(killer)) and node() == :__anchor_sabotage_never__ do
     with {:ok, file, line, name} <- split(killer),
          {:path, :ok} <- {:path, TestPath.check(file)} do
       {:ok, %{file: file, line: line, name: name}}
```

Command: `mix test --max-cases 2 --timeout 2000 test/anchor/domain/sabotage/killer_ref_test.exs` (7 tests, 5 failures; tests selected by mirror). Failed: test/anchor/domain/sabotage/killer_ref_test.exs:46 test a killer whose file is an option or outside the project is refused, test/anchor/domain/sabotage/killer_ref_test.exs:51 test text with no :<digits> <name> is not a ref, test/anchor/domain/sabotage/killer_ref_test.exs:41 test a per-test timeout's killer names its test, test/anchor/domain/sabotage/killer_ref_test.exs:8 test 1: file:line full name, test/anchor/domain/sabotage/killer_ref_test.exs:13 test 2: a name holding : and digits is split on the first :<digits> only

```
test/anchor/domain/sabotage/killer_ref_test.exs:46 test a killer whose file is an option or outside the project is refused
** (FunctionClauseError) no function clause matching in Anchor.Domain.Sabotage.KillerRef.parse/1
```

#### 2847816286c4 Anchor.Domain.Sabotage.KillerRef.split/1 return_input [0]: killed

```diff
--- a/lib/anchor/domain/sabotage/killer_ref.ex
+++ b/lib/anchor/domain/sabotage/killer_ref.ex
@@ -50,18 +50,5 @@
   # The first `:` followed by digits and a space.
   defp split(killer) do
     killer
-    |> :binary.matches(":")
-    |> Enum.find_value(:error, fn {at, 1} ->
-      file = binary_part(killer, 0, at)
-      rest = binary_part(killer, at + 1, byte_size(killer) - at - 1)
-
-      with [digits, name] <- String.split(rest, " ", parts: 2),
-           {line, ""} <- Integer.parse(digits),
-           true <- digits != "" and name != "" and line >= 0 do
-        {:ok, file, line, name}
-      else
-        _not_here -> nil
-      end
-    end)
   end
 end
```

Command: `mix test --max-cases 2 --timeout 2000 test/anchor/domain/sabotage/killer_ref_test.exs` (7 tests, 5 failures; tests selected by mirror). Failed: test/anchor/domain/sabotage/killer_ref_test.exs:41 test a per-test timeout's killer names its test, test/anchor/domain/sabotage/killer_ref_test.exs:13 test 2: a name holding : and digits is split on the first :<digits> only, test/anchor/domain/sabotage/killer_ref_test.exs:51 test text with no :<digits> <name> is not a ref, test/anchor/domain/sabotage/killer_ref_test.exs:46 test a killer whose file is an option or outside the project is refused, test/anchor/domain/sabotage/killer_ref_test.exs:8 test 1: file:line full name

```
test/anchor/domain/sabotage/killer_ref_test.exs:41 test a per-test timeout's killer names its test
** (WithClauseError) no with clause matching:

    "test/a_test.exs:9 test slow"

```

#### 57820ad8253d Anchor.Domain.Sabotage.KillerRef.to_test_args/1 return_input [0]: killed

```diff
--- a/lib/anchor/domain/sabotage/killer_ref.ex
+++ b/lib/anchor/domain/sabotage/killer_ref.ex
@@ -42,9 +42,7 @@
   @doc "The `mix test` arguments that run exactly `refs`, by file and name."
   @spec to_test_args([t()]) :: [String.t()]
   def to_test_args(refs) do
-    files = refs |> Enum.map(& &1.file) |> Enum.uniq()
-    names = refs |> Enum.map(& &1.name) |> Enum.uniq()
-    files ++ Enum.flat_map(names, &["--only", "test:" <> &1])
+    refs
   end
 
   # The first `:` followed by digits and a space.
```

Command: `mix test --max-cases 2 --timeout 2000 test/anchor/domain/sabotage/killer_ref_test.exs` (7 tests, 1 failures; tests selected by mirror). Failed: test/anchor/domain/sabotage/killer_ref_test.exs:18 test 3: two refs in one file and one in another: each file once, every name filter after

```
test/anchor/domain/sabotage/killer_ref_test.exs:18 test 3: two refs in one file and one in another: each file once, every name filter after
** (ExUnit.AssertionError) 

Assertion with == failed
code:  assert KillerRef.to_test_args(refs) == [
              "test/a_test.exs",
              "test/b_test.exs",
              "--only",
              "test:test x",
              "--only",
              "test:test y",
              "--only",
              "test:test z"
            ]
left:  [%{line: 1, name: "test x", file: "test/a_test.exs"}, %{line: 2, name: "test y", file: "test/a_test.exs"}, %{line: 3, name: "test z", file: "test/b_test.exs"}]
right: ["test/a_test.exs", "test/b_test.exs", "--only", "test:test x", "--only", "test:test y", "--only", "test:test z"]

```

#### 6a4e2dda24a0 Anchor.Domain.Sabotage.Replay.exit_code/1 force_condition [true]: killed

```diff
--- a/lib/anchor/domain/sabotage/replay.ex
+++ b/lib/anchor/domain/sabotage/replay.ex
@@ -228,7 +228,7 @@
 
     cond do
       Enum.any?(verdicts, &failed?/1) -> 1
-      not Enum.any?(verdicts, &(&1 == :still_killed)) -> 3
+      Process.get(:__anchor_sabotage__) == nil -> 3
       true -> 0
     end
   end
```

Command: `mix test --max-cases 2 --timeout 2000 test/anchor/domain/sabotage/replay_test.exs` (23 tests, 2 failures; tests selected by mirror). Failed: test/anchor/domain/sabotage/replay_test.exs:173 test exit_code/1 2: all still killed: 0, test/anchor/domain/sabotage/replay_test.exs:191 test exit_code/1 5: some drifted, the rest still killed: 0

```
test/anchor/domain/sabotage/replay_test.exs:173 test exit_code/1 2: all still killed: 0
** (ExUnit.AssertionError) 

Assertion with == failed
code:  assert Replay.exit_code(%Result{rows: 1, results: [{item(), :still_killed}]}) == 0
left:  3
right: 0

```

#### 0c4c8944cdc9 Anchor.Domain.Sabotage.Replay.exit_code/1 narrow_clause: killed

```diff
--- a/lib/anchor/domain/sabotage/replay.ex
+++ b/lib/anchor/domain/sabotage/replay.ex
@@ -223,7 +223,7 @@
   def exit_code(%Result{refusal: {code, _message}}), do: code
   def exit_code(%Result{rows: 0}), do: 3
 
-  def exit_code(%Result{results: results}) do
+  def exit_code(%Result{results: results}) when node() == :__anchor_sabotage_never__ do
     verdicts = Enum.map(results, &elem(&1, 1))
 
     cond do
```

Command: `mix test --max-cases 2 --timeout 2000 test/anchor/domain/sabotage/replay_test.exs` (23 tests, 6 failures; tests selected by mirror). Failed: test/anchor/domain/sabotage/replay_test.exs:173 test exit_code/1 2: all still killed: 0, test/anchor/domain/sabotage/replay_test.exs:196 test exit_code/1 a crashed row: 1; a refusal: its own code, test/anchor/domain/sabotage/replay_test.exs:203 test render/1 lost power names the mutant, the record and each killer, with a Fix, test/anchor/domain/sabotage/replay_test.exs:168 test exit_code/1 1: one lost power: 1, test/anchor/domain/sabotage/replay_test.exs:191 test exit_code/1 5: some drifted, the rest still killed: 0, test/anchor/domain/sabotage/replay_test.exs:181 test exit_code/1 4: rows, every one drifted: 3

```
test/anchor/domain/sabotage/replay_test.exs:173 test exit_code/1 2: all still killed: 0
** (FunctionClauseError) no function clause matching in Anchor.Domain.Sabotage.Replay.exit_code/1
```

#### f846683dba5d Anchor.Domain.Sabotage.Replay.inside?/1 return_input [0]: killed

```diff
--- a/lib/anchor/domain/sabotage/replay.ex
+++ b/lib/anchor/domain/sabotage/replay.ex
@@ -112,8 +112,7 @@
   @doc "Whether a row's file may be read and written: relative, no `..`."
   @spec inside?(String.t()) :: boolean()
   def inside?(file) do
-    segments = String.split(file, "/")
-    file != "" and not String.starts_with?(file, "/") and ".." not in segments
+    file
   end
 
   @doc "Replayable and drifted items; see the moduledoc."
```

Command: `mix test --max-cases 2 --timeout 2000 test/anchor/domain/sabotage/replay_test.exs` (23 tests, 9 failures; tests selected by mirror). Failed: test/anchor/domain/sabotage/replay_test.exs:134 test plan/2 a module name that does not read: drifted, not a Module.fun/arity, test/anchor/domain/sabotage/replay_test.exs:89 test plan/2 4: the id is there, the killer file is gone: drifted, killer gone, test/anchor/domain/sabotage/replay_test.exs:113 test plan/2 a (timeout) row runs the killer files of the function's other killed rows, whole, test/anchor/domain/sabotage/replay_test.exs:97 test plan/2 5: all present: replayable with the regenerated mutant, run by name (positive control), test/anchor/domain/sabotage/replay_test.exs:72 test plan/2 1: a row for a file not in the sources is drifted, file gone, test/anchor/domain/sabotage/replay_test.exs:83 test plan/2 3: the regenerated ids lack the row's id: drifted, no mutant with id, test/anchor/domain/sabotage/replay_test.exs:129 test plan/2 a (timeout) row with no other killed row of its function: drifted, no killer test, test/anchor/domain/sabotage/replay_test.exs:77 test plan/2 2: file present, function absent: drifted, function gone, test/anchor/domain/sabotage/replay_test.exs:106 test plan/2 a row whose file is outside the project is drifted before anything is read

```
test/anchor/domain/sabotage/replay_test.exs:134 test plan/2 a module name that does not read: drifted, not a Module.fun/arity
** (FunctionClauseError) no function clause matching in Anchor.Domain.Sabotage.Replay.check/2
```

#### 3f57e7db56aa Anchor.Domain.Sabotage.Replay.judge/2 narrow_clause: killed

```diff
--- a/lib/anchor/domain/sabotage/replay.ex
+++ b/lib/anchor/domain/sabotage/replay.ex
@@ -214,7 +214,7 @@
           | {:crashed, String.t()}
   def judge(_item, %{status: status}) when status in [:killed, :timeout], do: :still_killed
   def judge(%{row: row}, %{status: :survived}), do: {:lost_power, row.killers}
-  def judge(_item, %{status: :invalid}), do: {:drifted, :no_longer_compiles}
+  def judge(_item, %{status: :invalid}) when node() == :__anchor_sabotage_never__, do: {:drifted, :no_longer_compiles}
   def judge(_item, %{status: :no_tests}), do: {:drifted, :killer_not_found}
   def judge(_item, %{status: :crashed, reason: reason}), do: {:crashed, reason || "crashed"}
 
```

Command: `mix test --max-cases 2 --timeout 2000 test/anchor/domain/sabotage/replay_test.exs` (23 tests, 1 failures; tests selected by mirror). Failed: test/anchor/domain/sabotage/replay_test.exs:154 test judge/2 4: a compile error is drifted, no longer compiles

```
test/anchor/domain/sabotage/replay_test.exs:154 test judge/2 4: a compile error is drifted, no longer compiles
** (FunctionClauseError) no function clause matching in Anchor.Domain.Sabotage.Replay.judge/2
```

#### 5702dc500749 Anchor.Domain.Sabotage.Replay.judge/2 narrow_clause: killed

```diff
--- a/lib/anchor/domain/sabotage/replay.ex
+++ b/lib/anchor/domain/sabotage/replay.ex
@@ -212,7 +212,7 @@
           | {:lost_power, [String.t()]}
           | {:drifted, :no_longer_compiles | :killer_not_found}
           | {:crashed, String.t()}
-  def judge(_item, %{status: status}) when status in [:killed, :timeout], do: :still_killed
+  def judge(_item, %{status: status}) when (status in [:killed, :timeout]) and node() == :__anchor_sabotage_never__, do: :still_killed
   def judge(%{row: row}, %{status: :survived}), do: {:lost_power, row.killers}
   def judge(_item, %{status: :invalid}), do: {:drifted, :no_longer_compiles}
   def judge(_item, %{status: :no_tests}), do: {:drifted, :killer_not_found}
```

Command: `mix test --max-cases 2 --timeout 2000 test/anchor/domain/sabotage/replay_test.exs` (23 tests, 2 failures; tests selected by mirror). Failed: test/anchor/domain/sabotage/replay_test.exs:145 test judge/2 2: timeout is still killed, test/anchor/domain/sabotage/replay_test.exs:141 test judge/2 1: failed (killed) is still killed

```
test/anchor/domain/sabotage/replay_test.exs:145 test judge/2 2: timeout is still killed
** (FunctionClauseError) no function clause matching in Anchor.Domain.Sabotage.Replay.judge/2
```

### Survivors

None.

### Kills by timeout

None.

### Skipped, invalid, not run

- skipped Anchor.Domain.Sabotage.Config.parse/1 return_input [0] `parse(section) when is_map(section)`: removes the last use of function `coverage_map/1`
- skipped Anchor.Domain.Sabotage.Config.survivors/1 delete_statement `segments = String.split(path, "/")`: orphans variable `segments` bound at line 272 and used at line 274
- skipped Anchor.Domain.Sabotage.Config.survivors/1 force_condition [true] `String.starts_with?(path, "/") or ".." in segments`: leaves variable `segments` bound at line 272 unused
- skipped Anchor.Domain.Sabotage.Config.survivors/1 force_condition [false] `String.starts_with?(path, "/") or ".." in segments`: leaves variable `segments` bound at line 272 unused
- skipped Anchor.Domain.Sabotage.KillerRef.parse/1 return_input [0] `parse(killer) when is_binary(killer)`: removes the last use of alias `TestPath`
- skipped Anchor.Domain.Sabotage.KillerRef.to_test_args/1 delete_statement `files = refs |> Enum.map(& &1.file()) |> Enum.uniq()`: orphans variable `files` bound at line 45 and used at line 47
- skipped Anchor.Domain.Sabotage.KillerRef.to_test_args/1 delete_statement `names = refs |> Enum.map(& &1.name()) |> Enum.uniq()`: orphans variable `names` bound at line 46 and used at line 47
- skipped Anchor.Domain.Sabotage.KillerRef.split/1 delete_statement `file = binary_part(killer, 0, at)`: orphans variable `file` bound at line 55 and used at line 52
- skipped Anchor.Domain.Sabotage.KillerRef.split/1 delete_statement `rest = binary_part(killer, at + 1, byte_size(killer) - at - 1)`: orphans variable `rest` bound at line 56 and used at line 52
- skipped Anchor.Domain.Sabotage.KillerRef.split/1 with_passthrough `[digits, name] <- String.split(rest, " ", parts: 2)`: the pattern has nothing to relax
- skipped Anchor.Domain.Sabotage.Replay.items/1 return_input [0] `items(rows_by_record)`: removes the last use of module attribute `@replayed`
- skipped Anchor.Domain.Sabotage.Replay.function/1 with_passthrough `[head, arity_text] <- String.split(mfa, "/")`: the pattern has nothing to relax
- skipped Anchor.Domain.Sabotage.Replay.function/1 with_passthrough `[_ | _] = parts <- String.split(head, ".")`: the pattern has nothing to relax
- skipped Anchor.Domain.Sabotage.Replay.inside?/1 delete_statement `segments = String.split(file, "/")`: orphans variable `segments` bound at line 115 and used at line 116
- skipped Anchor.Domain.Sabotage.Replay.plan/2 delete_statement `{replayable, drifted} =
  items
  |> Enum.map(&plan_item(&1, items, facts))
  |> Enum.split_with(&match?({:ok, _replayable}, &1))`: orphans variable `drifted` bound at line 122 and used at line 127
- skipped Anchor.Domain.Sabotage.Replay.plan/2 return_input [0] `plan(items, facts)`: removes the last use of function `plan_item/3`
- skipped Anchor.Domain.Sabotage.Replay.plan/2 return_input [1] `plan(items, facts)`: removes the last use of function `plan_item/3`
- skipped Anchor.Domain.Sabotage.Replay.plan_item/3 return_input [0] `plan_item(%{row: row} = item, items, facts)`: removes the last use of function `check/2`
- skipped Anchor.Domain.Sabotage.Replay.plan_item/3 return_input [1] `plan_item(%{row: row} = item, items, facts)`: removes the last use of function `check/2`
- skipped Anchor.Domain.Sabotage.Replay.plan_item/3 return_input [2] `plan_item(%{row: row} = item, items, facts)`: removes the last use of function `check/2`
- skipped Anchor.Domain.Sabotage.Replay.test_args/2 delete_statement `files =
  for %{record: ^record, row: other} <- items,
      other.mfa() == row.mfa() and other.status() == "killed",
      {:ok, ref} <- Enum.map(other.killers(), &KillerRef.parse/1),
      uniq: true,
      do: ref.file()`: orphans variable `files` bound at line 174 and used at line 181
- skipped Anchor.Domain.Sabotage.Replay.test_args/2 return_input [1] `test_args(%{record: record, row: row}, items)`: removes the last use of function `named/1`
- skipped Anchor.Domain.Sabotage.Replay.killers_exist/3 delete_statement `files =
  if by_file do
    args
  else
    Enum.take_while(args, &(&1 != "--only"))
  end`: orphans variable `files` bound at line 201 and used at line 203
- skipped Anchor.Domain.Sabotage.Replay.killers_exist/3 force_condition [true] `by_file`: leaves variable `by_file` bound at line 200 unused
- skipped Anchor.Domain.Sabotage.Replay.killers_exist/3 force_condition [false] `by_file`: leaves variable `by_file` bound at line 200 unused
- skipped Anchor.Domain.Sabotage.Replay.exit_code/1 delete_statement `verdicts = Enum.map(results, &elem(&1, 1))`: orphans variable `verdicts` bound at line 227 and used at line 229
- skipped Anchor.Domain.Sabotage.Replay.exit_code/1 force_condition [true] `Enum.any?(verdicts, &failed?/1)`: removes the last use of function `failed?/1`
- skipped Anchor.Domain.Sabotage.Replay.exit_code/1 force_condition [false] `Enum.any?(verdicts, &failed?/1)`: removes the last use of function `failed?/1`
- skipped Anchor.Domain.Sabotage.Replay.render/1 delete_statement `drifted =
  r.drifted() ++
    for {item, {:drifted, why}} <- r.results() do
      {item, why}
    end`: orphans variable `drifted` bound at line 259 and used at line 261
- skipped Anchor.Domain.Sabotage.Replay.render/1 delete_statement `lines =
  r.notes() ++
    unreadable(r) ++
    Enum.flat_map(r.results(), &result_lines/1) ++
    Enum.map(drifted, fn {item, why} ->
      "drifted (#{drift_text(why)}) #{item.row().id()} #{item.row().mfa()} #{item.row().operator()} " <>
        "(#{item.record()})"
    end) ++
    Enum.map(r.not_replayed(), fn item ->
      "not replayed (cap) #{item.row().id()} #{item.row().mfa()} #{item.row().operator()}; rerun with --max all"
    end) ++ [summary(r, drifted)] ++ conclusion(r)`: orphans variable `lines` bound at line 261 and used at line 273
- skipped Anchor.Domain.Sabotage.Replay.render/1 return_input [0] `render(%Result{} = r)`: removes the last use of function `conclusion/1`
- skipped Anchor.Domain.Sabotage.Replay.summary/2 delete_statement `replayed = Enum.count(r.results(), fn {_item, v} -> not match?({:drifted, _why}, v) end)`: orphans variable `replayed` bound at line 313 and used at line 316
- skipped Anchor.Domain.Sabotage.Replay.summary/2 delete_statement `count = fn pred -> Enum.count(r.results(), fn {_item, v} -> pred.(v) end) end`: orphans variable `count` bound at line 314 and used at line 316
- skipped Anchor.Domain.Sabotage.Replay.conclusion/1 force_condition [true] `exit_code(r) == 3`: leaves variable `r` bound at line 323 unused
- skipped Anchor.Domain.Sabotage.Replay.conclusion/1 force_condition [false] `exit_code(r) == 3`: leaves variable `r` bound at line 323 unused
- skipped Anchor.Domain.Sabotage.Report.verdict/1 force_condition [true] `survivors_violation?(run)`: leaves variable `run` bound at line 85 unused
- skipped Anchor.Domain.Sabotage.Report.verdict/1 force_condition [false] `survivors_violation?(run)`: leaves variable `run` bound at line 85 unused
- skipped Anchor.Domain.Sabotage.Report.verdict/1 delete_statement `statuses = Enum.map(outcomes, & &1.status())`: orphans variable `statuses` bound at line 89 and used at line 91
- skipped Anchor.Domain.Sabotage.Report.verdict/1 return_input [0] `verdict(%Run{outcomes: outcomes} = run)`: removes the last use of module attribute `@measured`
- skipped Anchor.Domain.Sabotage.Report.render/1 delete_statement `planned =
  Enum.map(run.planned(), fn {mutant, selection} ->
    tsv([mutant.id(), mfa(mutant), mutant.operator(), "planned", "", selected(selection)])
  end)`: orphans variable `planned` bound at line 115 and used at line 120
- skipped Anchor.Domain.Sabotage.Report.render/1 return_input [0] `render(%Run{} = run)`: removes the last use of function `conclusion/2`
- skipped Anchor.Domain.Sabotage.Report.outcome/2 delete_statement `base = [mutant.id(), mfa(mutant), mutant.operator(), status, killers(outcome.killers())]`: orphans variable `base` bound at line 182 and used at line 190
- skipped Anchor.Domain.Sabotage.Report.outcome/2 delete_statement `tail =
  case Map.fetch(held, mutant.id()) do
    {:ok, {path, reason}} -> ["listed in #{path}: #{reason}"]
    :error -> tail(status, outcome)
  end`: orphans variable `tail` bound at line 184 and used at line 190
- skipped Anchor.Domain.Sabotage.Report.outcome/2 return_input [0] `outcome(%{mutant: mutant, status: status} = outcome, held)`: removes the last use of function `killers/1`
- skipped Anchor.Domain.Sabotage.Report.outcome/2 return_input [1] `outcome(%{mutant: mutant, status: status} = outcome, held)`: removes the last use of function `killers/1`
- skipped Anchor.Domain.Sabotage.Survivors.parse/1 delete_statement `parsed =
  lines
  |> Enum.with_index(1)
  |> Enum.reject(fn {line, _n} -> skipped?(String.trim(line)) end)
  |> Enum.map(fn {line, n} -> {n, entry(String.trim(line), n)} end)`: orphans variable `parsed` bound at line 109 and used at line 115
- skipped Anchor.Domain.Sabotage.Survivors.parse/1 delete_statement `errors =
  for {n, {:error, message}} <- parsed do
    {n, message}
  end ++
    duplicates(
      for {_n, {:ok, entry}} <- parsed do
        entry
      end
    )`: orphans variable `errors` bound at line 115 and used at line 119
- skipped Anchor.Domain.Sabotage.Survivors.parse/1 return_input [0] `parse(lines) when is_list(lines)`: removes the last use of function `duplicates/1`
- skipped Anchor.Domain.Sabotage.Survivors.judge/2 delete_statement `unrun = run.not_run() ++ run.not_selected()`: orphans variable `unrun` bound at line 128 and used at line 129
- skipped Anchor.Domain.Sabotage.Survivors.judge/2 delete_statement `mutants = Map.new(Enum.map(run.outcomes(), & &1.mutant()) ++ unrun, &{&1.id(), &1})`: orphans variable `mutants` bound at line 129 and used at line 131
- skipped Anchor.Domain.Sabotage.Survivors.judge/2 delete_statement `{malformed, entries} =
  Enum.reduce(entries, {[], []}, fn entry, {bad, good} ->
    case mismatch(entry, Map.get(mutants, entry.id())) do
      nil -> {bad, [entry | good]}
      message -> {[{entry, message} | bad], good}
    end
  end)`: orphans variable `malformed` bound at line 131 and used at line 156
- skipped Anchor.Domain.Sabotage.Survivors.judge/2 delete_statement `scope = in_scope(run, unrun)`: orphans variable `scope` bound at line 139 and used at line 141
- skipped Anchor.Domain.Sabotage.Survivors.judge/2 delete_statement `in_scope =
  Enum.filter(Enum.reverse(entries), &(&1.mfa() in scope or Map.has_key?(mutants, &1.id())))`: orphans variable `in_scope` bound at line 141 and used at line 144
- skipped Anchor.Domain.Sabotage.Survivors.judge/2 delete_statement `by_id = Map.new(in_scope, &{&1.id(), &1})`: orphans variable `by_id` bound at line 144 and used at line 147
- skipped Anchor.Domain.Sabotage.Survivors.judge/2 delete_statement `survivors = Enum.filter(run.outcomes(), &(&1.status() in @survivor_statuses))`: orphans variable `survivors` bound at line 145 and used at line 147
- skipped Anchor.Domain.Sabotage.Survivors.judge/2 delete_statement `compared = Baseline.compare(Enum.map(survivors, & &1.mutant().id()), Map.keys(by_id))`: orphans variable `compared` bound at line 147 and used at line 148
- skipped Anchor.Domain.Sabotage.Survivors.judge/2 delete_statement `new_ids = MapSet.new(compared.new())`: orphans variable `new_ids` bound at line 148 and used at line 156
- skipped Anchor.Domain.Sabotage.Survivors.judge/2 delete_statement `{stale, unjudged} =
  compared.stale()
  |> Enum.map(&Map.fetch!(by_id, &1))
  |> Enum.sort_by(& &1.line_no())
  |> Enum.split_with(&(not_judged(&1, run, unrun) == nil))`: orphans variable `stale` bound at line 150 and used at line 156
- skipped Anchor.Domain.Sabotage.Survivors.judge/2 return_input [0] `judge(%Run{} = run, entries)`: removes the last use of module attribute `@survivor_statuses`
- skipped Anchor.Domain.Sabotage.Survivors.judge/2 return_input [1] `judge(%Run{} = run, entries)`: removes the last use of module attribute `@survivor_statuses`
- skipped Anchor.Domain.Sabotage.Survivors.grew/2 delete_statement `base_ids =
  base
  |> Enum.map(&String.trim/1)
  |> Enum.reject(&skipped?/1)
  |> Enum.map(&(&1 |> String.split() |> hd()))`: orphans variable `base_ids` bound at line 178 and used at line 184
- skipped Anchor.Domain.Sabotage.Survivors.grew/2 delete_statement `added = MapSet.new(Baseline.grew(Enum.map(working, & &1.id()), base_ids))`: orphans variable `added` bound at line 184 and used at line 185
- skipped Anchor.Domain.Sabotage.Survivors.grew/2 return_input [0] `grew(working, base) when is_list(base)`: the guard reads `base`, which the mutant renames `_base`
- skipped Anchor.Domain.Sabotage.Survivors.entry/2 return_input [0] `entry(line, n)`: removes the last use of function `check/2`
- skipped Anchor.Domain.Sabotage.Survivors.entry/2 return_input [1] `entry(line, n)`: removes the last use of function `check/2`
- skipped Anchor.Domain.Sabotage.Survivors.hex_id?/1 return_input [0] `hex_id?(id)`: removes the last use of module attribute `@hex`
- skipped Anchor.Domain.Sabotage.Survivors.reason_ok/1 delete_statement `first = reason |> String.split() |> hd() |> String.trim_trailing(":") |> String.downcase()`: orphans variable `first` bound at line 263 and used at line 270
- skipped Anchor.Domain.Sabotage.Survivors.reason_ok/1 force_condition [true] `first in @placeholder_words`: leaves variable `first` bound at line 263 unused
- skipped Anchor.Domain.Sabotage.Survivors.reason_ok/1 force_condition [false] `first in @placeholder_words`: leaves variable `first` bound at line 263 unused
- skipped Anchor.Domain.Sabotage.Survivors.reason_ok/1 return_input [0] `reason_ok(reason)`: removes the last use of module attribute `@placeholder_words`
- skipped Anchor.Domain.Sabotage.Survivors.not_judged/3 force_condition [true] `Enum.any?(unrun, &(&1.id() == entry.id()))`: leaves variable `unrun` bound at line 311 unused
- skipped Anchor.Domain.Sabotage.Survivors.not_judged/3 force_condition [false] `Enum.any?(unrun, &(&1.id() == entry.id()))`: leaves variable `unrun` bound at line 311 unused
- skipped Anchor.Domain.Sabotage.Survivors.stale_reason/2 return_input [0] `stale_reason(entry, run)`: removes the last use of function `killer/1`
- skipped Anchor.Domain.Sabotage.Survivors.stale_reason/2 return_input [1] `stale_reason(entry, run)`: removes the last use of function `killer/1`
- skipped Anchor.Domain.Sabotage.Survivors.killer/1 return_input [0] `killer(text) when is_binary(text)`: the body already returns `text`
- skipped Anchor.Managers.Sabotage.replay/2 return_input [0] `replay(facts, opts \\ [])`: removes the last use of alias `Replay`
- skipped Anchor.Managers.Sabotage.replay/2 return_input [1] `replay(facts, opts \\ [])`: removes the last use of alias `Replay`
- skipped Anchor.Managers.Sabotage.Replay.run/2 delete_statement `ports = Runner.ports(opts)`: orphans variable `ports` bound at line 53 and used at line 55
- skipped Anchor.Managers.Sabotage.Replay.run/2 return_input [0] `run(%{root: root, build_path: build_path} = facts, opts) when is_binary(build_path)`: the guard reads `build_path`, which the mutant renames `_build_path`
- skipped Anchor.Managers.Sabotage.Replay.run/2 return_input [1] `run(%{root: root, build_path: build_path} = facts, opts) when is_binary(build_path)`: the guard reads `build_path`, which the mutant renames `_build_path`
- skipped Anchor.Managers.Sabotage.Replay.checked/3 return_input [0] `checked(result, %{root: root} = facts, ports)`: removes the last use of function `planned/5`
- skipped Anchor.Managers.Sabotage.Replay.checked/3 return_input [1] `checked(result, %{root: root} = facts, ports)`: removes the last use of function `planned/5`
- skipped Anchor.Managers.Sabotage.Replay.checked/3 return_input [2] `checked(result, %{root: root} = facts, ports)`: removes the last use of function `planned/5`
- skipped Anchor.Managers.Sabotage.Replay.records/4 delete_statement `globs =
  case Map.get(facts, :records, []) do
    [] -> [Record.dir_glob(config.records())]
    globs -> globs
  end`: orphans variable `globs` bound at line 77 and used at line 83
- skipped Anchor.Managers.Sabotage.Replay.records/4 delete_statement `paths = globs |> Enum.flat_map(&store.list(facts.root(), &1)) |> Enum.uniq() |> Enum.sort()`: orphans variable `paths` bound at line 83 and used at line 85
- skipped Anchor.Managers.Sabotage.Replay.records/4 delete_statement `{rows, unreadable} =
  Enum.reduce(paths, {[], []}, fn path, {rows, bad} ->
    with {:ok, text} <- store.read(facts.root(), path), {:ok, parsed} <- KillMap.parse(text) do
      {rows ++ [{path, parsed}], bad}
    else
      {:error, {line, message}} -> {rows, bad ++ ["kill map in #{path}:#{line} (#{message})"]}
      {:error, posix} -> {rows, bad ++ ["#{path} (#{inspect(posix)})"]}
    end
  end)`: orphans variable `rows` bound at line 85 and used at line 96
- skipped Anchor.Managers.Sabotage.Replay.records/4 delete_statement `items = Replay.items(rows)`: orphans variable `items` bound at line 96 and used at line 98
- skipped Anchor.Managers.Sabotage.Replay.records/4 delete_statement `result = %{
  result
  | searched: globs,
    records: length(paths),
    rows: length(items),
    unreadable: unreadable
}`: leaves variable `unreadable` bound at line 85 unused
- skipped Anchor.Managers.Sabotage.Replay.records/4 return_input [0] `records(result, facts, config, %{records: store})`: removes the last use of alias `KillMap`
- skipped Anchor.Managers.Sabotage.Replay.records/4 return_input [1] `records(result, facts, config, %{records: store})`: removes the last use of alias `KillMap`
- skipped Anchor.Managers.Sabotage.Replay.records/4 return_input [2] `records(result, facts, config, %{records: store})`: removes the last use of alias `KillMap`
- skipped Anchor.Managers.Sabotage.Replay.planned/5 delete_statement `sources = sources(items, facts.root(), ports)`: orphans variable `sources` bound at line 112 and used at line 115
- skipped Anchor.Managers.Sabotage.Replay.planned/5 delete_statement `tests = existing_tests(items, facts.root(), ports)`: orphans variable `tests` bound at line 113 and used at line 120
- skipped Anchor.Managers.Sabotage.Replay.planned/5 delete_statement `generated =
  for %{row: row} <- items, Map.has_key?(sources, row.file()), into: %{} do
    {{row.file(), row.mfa()}, generate(sources[row.file()], row, config)}
  end`: orphans variable `generated` bound at line 115 and used at line 120
- skipped Anchor.Managers.Sabotage.Replay.planned/5 delete_statement `plan =
  Replay.plan(items, %{
    sources: Map.new(sources, fn {file, _text} -> {file, true} end),
    generated: generated,
    tests: tests
  })`: orphans variable `plan` bound at line 120 and used at line 127
- skipped Anchor.Managers.Sabotage.Replay.planned/5 delete_statement `{kept, capped} = cap(plan.replayable(), Map.get(facts, :max) || config.max_mutants())`: orphans variable `capped` bound at line 127 and used at line 128
- skipped Anchor.Managers.Sabotage.Replay.planned/5 delete_statement `result = %{result | drifted: plan.drifted(), not_replayed: capped}`: leaves variable `capped` bound at line 127 unused
- skipped Anchor.Managers.Sabotage.Replay.planned/5 return_input [0] `planned(result, items, facts, config, ports)`: removes the last use of function `baseline/4`
- skipped Anchor.Managers.Sabotage.Replay.planned/5 return_input [1] `planned(result, items, facts, config, ports)`: removes the last use of function `baseline/4`
- skipped Anchor.Managers.Sabotage.Replay.planned/5 return_input [2] `planned(result, items, facts, config, ports)`: removes the last use of function `baseline/4`
- skipped Anchor.Managers.Sabotage.Replay.planned/5 return_input [3] `planned(result, items, facts, config, ports)`: removes the last use of function `baseline/4`
- skipped Anchor.Managers.Sabotage.Replay.planned/5 return_input [4] `planned(result, items, facts, config, ports)`: removes the last use of function `baseline/4`
- skipped Anchor.Managers.Sabotage.Replay.generate/3 delete_statement `opts = [operators: Operators.all(), effect_calls: config.effect_calls()]`: orphans variable `opts` bound at line 171 and used at line 173
- skipped Anchor.Managers.Sabotage.Replay.generate/3 return_input [0] `generate(text, row, config)`: removes the last use of alias `Mutator`
- skipped Anchor.Managers.Sabotage.Replay.generate/3 return_input [1] `generate(text, row, config)`: removes the last use of alias `Mutator`
- skipped Anchor.Managers.Sabotage.Replay.generate/3 return_input [2] `generate(text, row, config)`: removes the last use of alias `Mutator`
- skipped Anchor.Managers.Sabotage.Replay.cap/2 delete_statement `ordered = Enum.sort_by(replayable, &{&1.record(), &1.row().id()})`: orphans variable `ordered` bound at line 184 and used at line 185
- skipped Anchor.Managers.Sabotage.Replay.clean/3 delete_statement `files = kept |> Enum.map(& &1.mutant().file()) |> Enum.uniq()`: orphans variable `files` bound at line 191 and used at line 193
- skipped Anchor.Managers.Sabotage.Replay.baseline/4 delete_statement `{by_file, by_name} = Enum.split_with(kept, & &1.by_file())`: orphans variable `by_file` bound at line 209 and used at line 211
- skipped Anchor.Managers.Sabotage.Replay.baseline/4 delete_statement `runs =
  [
    by_name |> Enum.flat_map(&named_refs/1) |> KillerRef.to_test_args(),
    by_file |> Enum.flat_map(& &1.test_args()) |> Enum.uniq()
  ]
  |> Enum.reject(&(&1 == []))`: orphans variable `runs` bound at line 211 and used at line 218
- skipped Anchor.Managers.Sabotage.Replay.baseline/4 return_input [0] `baseline(kept, facts, config, ports)`: removes the last use of function `named_refs/1`
- skipped Anchor.Managers.Sabotage.Replay.baseline/4 return_input [1] `baseline(kept, facts, config, ports)`: removes the last use of function `named_refs/1`
- skipped Anchor.Managers.Sabotage.Replay.baseline/4 return_input [2] `baseline(kept, facts, config, ports)`: removes the last use of function `named_refs/1`
- skipped Anchor.Managers.Sabotage.Replay.baseline/4 return_input [3] `baseline(kept, facts, config, ports)`: removes the last use of function `named_refs/1`
- skipped Anchor.Managers.Sabotage.Replay.replay/6 delete_statement `source_results = Map.new(sources, fn {file, text} -> {file, {:ok, text}} end)`: orphans variable `source_results` bound at line 250 and used at line 252
- skipped Anchor.Managers.Sabotage.Replay.replay/6 delete_statement `selection = {:kill_map, item.test_args()}`: orphans variable `selection` bound at line 253 and used at line 252
- skipped Anchor.Managers.Sabotage.Replay.replay/6 delete_statement `verdict = Replay.judge(item, outcome)`: orphans variable `verdict` bound at line 257 and used at line 252
- skipped Anchor.Managers.Sabotage.Replay.replay/6 delete_statement `item = Map.put(item, :tests_run, tests_run(outcome))`: removes the last use of function `tests_run/1`
- skipped Anchor.Managers.Sabotage.Replay.replay/6 return_input [0] `replay(result, kept, facts, config, sources, ports)`: removes the last use of function `tests_run/1`
- skipped Anchor.Managers.Sabotage.Replay.replay/6 return_input [1] `replay(result, kept, facts, config, sources, ports)`: removes the last use of function `tests_run/1`
- skipped Anchor.Managers.Sabotage.Replay.replay/6 return_input [2] `replay(result, kept, facts, config, sources, ports)`: removes the last use of function `tests_run/1`
- skipped Anchor.Managers.Sabotage.Replay.replay/6 return_input [3] `replay(result, kept, facts, config, sources, ports)`: removes the last use of function `tests_run/1`
- skipped Anchor.Managers.Sabotage.Replay.replay/6 return_input [4] `replay(result, kept, facts, config, sources, ports)`: removes the last use of function `tests_run/1`
- skipped Anchor.Managers.Sabotage.Replay.replay/6 return_input [5] `replay(result, kept, facts, config, sources, ports)`: removes the last use of function `tests_run/1`
- skipped Anchor.Managers.Sabotage.Runner.locked/4 return_input [0] `locked(run, root, %{patcher: patcher}, body)`: removes the last use of function `lock_held/1`
- skipped Anchor.Managers.Sabotage.Runner.locked/4 return_input [1] `locked(run, root, %{patcher: patcher}, body)`: removes the last use of function `lock_held/1`
- skipped Anchor.Managers.Sabotage.Runner.locked/4 return_input [3] `locked(run, root, %{patcher: patcher}, body)`: removes the last use of function `lock_held/1`
- skipped Anchor.Managers.Sabotage.Runner.checked_run/3 delete_statement `run = %{
  run
  | not_run: plan.not_run(),
    notes: run.notes() ++ notes ++ records.notes() ++ survivor_notes(list),
    scope_functions: Enum.map(scope.functions(), &mfa/1),
    not_selected: not_selected(mutants, plan),
    print_survivor_lines: Map.get(facts, :print_survivor_lines, false)
}`: leaves variable `notes` bound at line 250 unused
- skipped Anchor.Managers.Sabotage.Runner.checked_run/3 delete_statement `selection = select(plan.planned(), root, config, {coverage, records.kill_map()}, ports)`: orphans variable `selection` bound at line 269 and used at line 270
- skipped Anchor.Managers.Sabotage.Runner.checked_run/3 delete_statement `planned = Enum.zip(plan.planned(), selection)`: orphans variable `planned` bound at line 270 and used at line 273
- skipped Anchor.Managers.Sabotage.Runner.checked_run/3 return_input [0] `checked_run(run, %{root: root} = facts, ports)`: removes the last use of function `clean_targets/3`
- skipped Anchor.Managers.Sabotage.Runner.checked_run/3 return_input [1] `checked_run(run, %{root: root} = facts, ports)`: removes the last use of function `clean_targets/3`
- skipped Anchor.Managers.Sabotage.Runner.checked_run/3 return_input [2] `checked_run(run, %{root: root} = facts, ports)`: removes the last use of function `clean_targets/3`
- skipped Anchor.Managers.Sabotage.Runner.ports/1 return_input [0] `ports(opts)`: removes the last use of alias `BaselineFile`
- skipped Anchor.Managers.Sabotage.Runner.recover/3 return_input [0] `recover(run, root, %{patcher: patcher})`: removes the last use of function `recover_entry/4`
- skipped Anchor.Managers.Sabotage.Runner.recover/3 return_input [1] `recover(run, root, %{patcher: patcher})`: removes the last use of function `recover_entry/4`
- skipped Anchor.Managers.Sabotage.Runner.mutant_outcome/6 delete_statement `looked =
  TestSelection.mirror_path(mutant, config.test_mirror()) || "(no test_mirror rule matches)"`: orphans variable `looked` bound at line 728 and used at line 731
- skipped Anchor.Managers.Sabotage.Runner.mutant_outcome/6 delete_statement `{:ok, original} = Map.fetch!(sources, mutant.file())`: orphans variable `original` bound at line 742 and used at line 743
- skipped Anchor.Managers.Sabotage.Runner.mutant_outcome/6 delete_statement `mutated = Patch.apply_range(original, mutant.range(), mutant.replacement())`: orphans variable `mutated` bound at line 743 and used at line 744
- skipped Anchor.Managers.Sabotage.Runner.mutant_outcome/6 delete_statement `entry = Journal.entry(mutant.file(), mutant.id(), original, mutated)`: orphans variable `entry` bound at line 744 and used at line 746
- skipped Anchor.Managers.Sabotage.Runner.mutant_outcome/6 return_input [0] `mutant_outcome(%Mutant{} = mutant, {_source, tests} = selection, facts, config, sources, ports)`: removes the last use of alias `Patch`
- skipped Anchor.Managers.Sabotage.Runner.mutant_outcome/6 return_input [1] `mutant_outcome(%Mutant{} = mutant, {_source, tests} = selection, facts, config, sources, ports)`: removes the last use of alias `Patch`
- skipped Anchor.Managers.Sabotage.Runner.mutant_outcome/6 return_input [2] `mutant_outcome(%Mutant{} = mutant, {_source, tests} = selection, facts, config, sources, ports)`: removes the last use of alias `Patch`
- skipped Anchor.Managers.Sabotage.Runner.mutant_outcome/6 return_input [3] `mutant_outcome(%Mutant{} = mutant, {_source, tests} = selection, facts, config, sources, ports)`: removes the last use of alias `Patch`
- skipped Anchor.Managers.Sabotage.Runner.mutant_outcome/6 return_input [4] `mutant_outcome(%Mutant{} = mutant, {_source, tests} = selection, facts, config, sources, ports)`: removes the last use of alias `Patch`
- skipped Anchor.Managers.Sabotage.Runner.mutant_outcome/6 return_input [5] `mutant_outcome(%Mutant{} = mutant, {_source, tests} = selection, facts, config, sources, ports)`: removes the last use of alias `Patch`
- skipped Anchor.Managers.Sabotage.Runner.not_selected/2 delete_statement `kept = MapSet.new(plan.planned() ++ plan.not_run(), & &1.id())`: orphans variable `kept` bound at line 876 and used at line 877
- skipped Anchor.Managers.Sabotage.Runner.survivors_list/3 delete_statement `path = config.survivors() || Survivors.default_path()`: orphans variable `path` bound at line 889 and used at line 892
- skipped Anchor.Managers.Sabotage.Runner.survivors_list/3 delete_statement `base = Map.get(facts, :base, @default_base)`: orphans variable `base` bound at line 890 and used at line 892
- skipped Anchor.Managers.Sabotage.Runner.survivors_list/3 return_input [0] `survivors_list(facts, config, ports)`: removes the last use of function `base_survivors/4`
- skipped Anchor.Managers.Sabotage.Runner.survivors_list/3 return_input [1] `survivors_list(facts, config, ports)`: removes the last use of function `base_survivors/4`
- skipped Anchor.Managers.Sabotage.Runner.survivors_list/3 return_input [2] `survivors_list(facts, config, ports)`: removes the last use of function `base_survivors/4`
- skipped Anchor.Managers.Sabotage.Runner.read_survivors/4 return_input [0] `read_survivors(root, path, named, %{baseline_store: store})`: removes the last use of function `parsed_survivors/2`
- skipped Anchor.Managers.Sabotage.Runner.read_survivors/4 return_input [1] `read_survivors(root, path, named, %{baseline_store: store})`: removes the last use of function `parsed_survivors/2`
- skipped Anchor.Managers.Sabotage.Runner.read_survivors/4 return_input [2] `read_survivors(root, path, named, %{baseline_store: store})`: removes the last use of function `parsed_survivors/2`
- skipped Anchor.Managers.Sabotage.Runner.parsed_survivors/2 delete_statement `named = Enum.map_join(errors, "\n", fn {n, message} -> "  entry #{n}: #{message}" end)`: orphans variable `named` bound at line 921 and used at line 923
- skipped Anchor.Managers.Sabotage.Runner.judge_survivors/2 return_input [0] `judge_survivors(run, nil)`: the body already returns `run`
- skipped Anchor.Managers.Sabotage.Runner.judge_survivors/2 return_input [0] `judge_survivors(%Run{refusal: {_code, _message}} = run, _list)`: the body already returns `run`

### Tests still lacking a red

None.

### Kill map

```anchor-kills
# id	file	mfa	operator	status	killers
a42909400ea9	lib/anchor/domain/sabotage/killer_ref.ex	Anchor.Domain.Sabotage.KillerRef.parse/1	narrow_clause	killed	test/anchor/domain/sabotage/killer_ref_test.exs:37 test 4: the bound's (timeout) names no test
ab4e6c2528b1	lib/anchor/domain/sabotage/killer_ref.ex	Anchor.Domain.Sabotage.KillerRef.parse/1	narrow_clause	killed	test/anchor/domain/sabotage/killer_ref_test.exs:41 test a per-test timeout's killer names its test
ddec05bb88b0	lib/anchor/domain/sabotage/killer_ref.ex	Anchor.Domain.Sabotage.KillerRef.parse/1	narrow_clause	killed	test/anchor/domain/sabotage/killer_ref_test.exs:46 test a killer whose file is an option or outside the project is refused ; test/anchor/domain/sabotage/killer_ref_test.exs:51 test text with no :<digits> <name> is not a ref ; test/anchor/domain/sabotage/killer_ref_test.exs:41 test a per-test timeout's killer names its test ; test/anchor/domain/sabotage/killer_ref_test.exs:8 test 1: file:line full name ; test/anchor/domain/sabotage/killer_ref_test.exs:13 test 2: a name holding : and digits is split on the first :<digits> only
2847816286c4	lib/anchor/domain/sabotage/killer_ref.ex	Anchor.Domain.Sabotage.KillerRef.split/1	return_input	killed	test/anchor/domain/sabotage/killer_ref_test.exs:41 test a per-test timeout's killer names its test ; test/anchor/domain/sabotage/killer_ref_test.exs:13 test 2: a name holding : and digits is split on the first :<digits> only ; test/anchor/domain/sabotage/killer_ref_test.exs:51 test text with no :<digits> <name> is not a ref ; test/anchor/domain/sabotage/killer_ref_test.exs:46 test a killer whose file is an option or outside the project is refused ; test/anchor/domain/sabotage/killer_ref_test.exs:8 test 1: file:line full name
57820ad8253d	lib/anchor/domain/sabotage/killer_ref.ex	Anchor.Domain.Sabotage.KillerRef.to_test_args/1	return_input	killed	test/anchor/domain/sabotage/killer_ref_test.exs:18 test 3: two refs in one file and one in another: each file once, every name filter after
6a4e2dda24a0	lib/anchor/domain/sabotage/replay.ex	Anchor.Domain.Sabotage.Replay.exit_code/1	force_condition	killed	test/anchor/domain/sabotage/replay_test.exs:173 test exit_code/1 2: all still killed: 0 ; test/anchor/domain/sabotage/replay_test.exs:191 test exit_code/1 5: some drifted, the rest still killed: 0
0c4c8944cdc9	lib/anchor/domain/sabotage/replay.ex	Anchor.Domain.Sabotage.Replay.exit_code/1	narrow_clause	killed	test/anchor/domain/sabotage/replay_test.exs:173 test exit_code/1 2: all still killed: 0 ; test/anchor/domain/sabotage/replay_test.exs:196 test exit_code/1 a crashed row: 1\; a refusal: its own code ; test/anchor/domain/sabotage/replay_test.exs:203 test render/1 lost power names the mutant, the record and each killer, with a Fix ; test/anchor/domain/sabotage/replay_test.exs:168 test exit_code/1 1: one lost power: 1 ; test/anchor/domain/sabotage/replay_test.exs:191 test exit_code/1 5: some drifted, the rest still killed: 0 ; test/anchor/domain/sabotage/replay_test.exs:181 test exit_code/1 4: rows, every one drifted: 3
f846683dba5d	lib/anchor/domain/sabotage/replay.ex	Anchor.Domain.Sabotage.Replay.inside?/1	return_input	killed	test/anchor/domain/sabotage/replay_test.exs:134 test plan/2 a module name that does not read: drifted, not a Module.fun/arity ; test/anchor/domain/sabotage/replay_test.exs:89 test plan/2 4: the id is there, the killer file is gone: drifted, killer gone ; test/anchor/domain/sabotage/replay_test.exs:113 test plan/2 a (timeout) row runs the killer files of the function's other killed rows, whole ; test/anchor/domain/sabotage/replay_test.exs:97 test plan/2 5: all present: replayable with the regenerated mutant, run by name (positive control) ; test/anchor/domain/sabotage/replay_test.exs:72 test plan/2 1: a row for a file not in the sources is drifted, file gone ; test/anchor/domain/sabotage/replay_test.exs:83 test plan/2 3: the regenerated ids lack the row's id: drifted, no mutant with id ; test/anchor/domain/sabotage/replay_test.exs:129 test plan/2 a (timeout) row with no other killed row of its function: drifted, no killer test ; test/anchor/domain/sabotage/replay_test.exs:77 test plan/2 2: file present, function absent: drifted, function gone ; test/anchor/domain/sabotage/replay_test.exs:106 test plan/2 a row whose file is outside the project is drifted before anything is read
3f57e7db56aa	lib/anchor/domain/sabotage/replay.ex	Anchor.Domain.Sabotage.Replay.judge/2	narrow_clause	killed	test/anchor/domain/sabotage/replay_test.exs:154 test judge/2 4: a compile error is drifted, no longer compiles
5702dc500749	lib/anchor/domain/sabotage/replay.ex	Anchor.Domain.Sabotage.Replay.judge/2	narrow_clause	killed	test/anchor/domain/sabotage/replay_test.exs:145 test judge/2 2: timeout is still killed ; test/anchor/domain/sabotage/replay_test.exs:141 test judge/2 1: failed (killed) is still killed
```

## Review floor (code-reviewer and adr-reviewer, one round)

The ADR reviewer found tests with no recorded red; the code reviewer found
that a replayed record could steer a read or write through a committed
symlink, and that an unreadable record next to readable rows left the job
green. Rows F1-F20 cover each, with the same driver. F10's first form
(dropping `@replayed`) did not compile and was rewritten.

| # | Mutation | Tests failed | First failure, verbatim |
|---|---|---|---|
| F1 | `Config`: an absolute or `..` survivors path accepted | 1 of 7: "2: each refusal names its key and ends with a Fix: line" (the table holds the three survivors rows) | `** (MatchError) no match of right hand side value:` |
| F2 | `Config`: an empty survivors path accepted | 1 of 7: the same refusal table | `** (MatchError) no match of right hand side value:` |
| F3 | the task: `--records` outside the project accepted | 2 of 11: "replay_facts/1 maps --max and --records ...", "replay with a bad flag is a usage error ..." | `** (Mox.UnexpectedCallError) no expectation defined for Anchor.SourceMutationMock.read_journal/1` |
| F4 | the task: `--print-survivor-lines` not mapped | 1 of 11: "run_facts/1 maps --print-survivor-lines; off by default" | `code:  assert {:ok, %{print_survivor_lines: true}} = Sabotage.run_facts(["--print-survivor-lines"])` |
| F5 | `Report`: a first landing worded as an ordinary addition | 1 of 41: S3b | `code:  assert Report.render(run) =~ "Survivors added by this branch: review each reason (#{@path} is not on origin/main: " <>` |
| F6 | `Report`: the not-run wording changed | 1 of 41: S4 | `code:  assert Report.render(run) =~ "survivor aaaaaaaaaaaa Calc.add/2 return_input not judged (not run, cap)\n"` |
| F7 | `Report`: a run that measured nothing passes when nothing fails | 2 of 41: S8 and "exit-code policy" | `code: for statuses <- [` (the unmeasured row exits 0) |
| F8 | `Report`: the survivor lines never printed | 1 of 41: S9 | `code:  assert Report.render(run) =~ "Survivor lines to add to #{@path} (nothing was written; ...` |
| F9 | `Runner`: a malformed list not refused | 1 of 86: SV4b | `** (FunctionClauseError) no function clause matching in Anchor.Managers.Sabotage.Runner.parsed_survivors/2` |
| F10 | `Replay.items/1` keeps every status | 1 of 25: "items/1 keeps killed and timeout rows only" | `code:  assert [%{row: %{status: "killed"}}, %{row: %{status: "timeout"}}] = Replay.items([{@record, rows}])` |
| F11 | `judge/2`: no test ran read as still killed | 1 of 25: "no test ran is drifted ..." | `left:  :still_killed` |
| F12 | `render/1`: the zero-rows line reworded | 1 of 25: "zero rows says COULD NOT MEASURE and names the directories searched" | `code:  assert text =~ "COULD NOT MEASURE: anchor.sabotage replay found no killed or timeout row in 3 " <>` |
| F13 | the Manager: an unreadable kill map dropped silently | 2 of 11: "zero rows: ... a malformed kill map is named", "a record that cannot be read beside rows still killed: exit 3, never green" | `code:  assert text =~ "could not read kill map in test/sabotage_records/bad.md:2"` |
| F14 | the Manager: `--records` ignored | 1 of 11: "--records names the directory globs read instead of the configured one" | `** (FunctionClauseError) no function clause matching in anonymous fn/2 in ...` (the configured glob was listed) |
| F15 | `exit_code/1`: an unreadable record ignored | 2 of 36: the domain row and the Manager row | `code:  assert Replay.exit_code(r) == 3` `left:  0` |
| F16 | `plan/2`: a symlinked row file followed | 1 of 25: "a row file or killer file with a symlink on its path is drifted, never followed" | `code:  assert plan([i], facts(%{symlinked: MapSet.new(["lib/calc.ex"])})).drifted == [{i, :symlink}]` `left:  []` |
| F17 | `plan/2`: a symlinked killer file run | 1 of 25: the same test | `code:  assert plan(...).drifted == [{i, {:killer_symlink, "test/calc_test.exs"}}]` |
| F18 | `SourcePatcher.symlinked/2` never sees a symlink | 1 of 13: "symlinked/2 names each path with a symlink at the file or a directory above it" | `left:  []` |
| F19 | the Manager: the symlink answer dropped | 1 of 11: "a row file or killer file with a symlink on its path is drifted ..." | `** (Mox.UnexpectedCallError) no expectation defined for Anchor.ChangeSourceMock.read/2 ... with args ["/repo", "lib/calc.ex"]` |
| F20 | the Manager: the run lock not taken | 1 of 11: "the run lock is taken before anything else and released after; held, exit 2, nothing touched" | `code:  assert calls() == [:take_lock, :read_journal, :release_lock]` `left:  [:read_journal]` |

After every row was restored, each file named above was green.

## The move to Domain (`effects_match_bucket`, on main from 4930a78)

CI's graph check on the merged tree flagged `Runner.runner_error/1`,
`runner_error_code/1` and `ports/1` as public and pure in a Manager. The
refusal moved to `TestRunRefusal`; `ports/1` is private, and the replay names
its own. T7's first form (`RecordFile` alone) did not compile: it left the
`TestRunner` alias unused. Each row ran `mix test --force --timeout 2000
--max-cases 2`.

| # | Mutation | Tests failed | First failure, verbatim |
|---|---|---|---|
| T1 | `code(:timeout_not_found)` is 3 | 1 of 3: "a missing timeout binary is exit 2, a tool to install" | `left:  3` |
| T2 | `code({:results_not_removed, ...})` is 2 | 1 of 3: "a results file not removed is exit 3, naming the file and the posix" | `left:  2` |
| T3 | `code({:results_dir_not_created, ...})` is 2 | 1 of 3: "a results directory not made is exit 3, naming the directory and the posix" | `left:  2` |
| T4 | the timeout message's `Fix:` reworded | 1 of 3: "a missing timeout binary ..." | ``left:  "the `timeout` binary was not found, so a test run could not be bounded. Fix: install timeout"`` |
| T5 | the results-file message loses its posix | 1 of 3: "a results file not removed ..." | `left:  "COULD NOT MEASURE: the previous results file _build/r.bin could not be removed (:x) false, so a test run's failures could be an earlier run's. Fix: remove _build/r.bin by hand"` |
| T6 | the results-directory message's `Fix:` loses the directory | 1 of 3: "a results directory not made ..." | `left:  "COULD NOT MEASURE: the results directory _build/d could not be made (:eacces), so no test run's failures can be read. Fix: make it (or its parent) a writable directory"` |
| T7 | the replay's default test port is the wrong adapter | 1 of 1: integration "1-2: a recorded killer still kills (by name alone), then loses its power" | `** (UndefinedFunctionError) function Anchor.Adapters.RecordFile.run/3 is undefined or private` |
| T8 | the replay's ports have no `records:` (seen while writing them) | 11 of 100 run, all in `SabotageReplayTest` | `** (FunctionClauseError) no function clause matching in Anchor.Managers.Sabotage.Replay.records/4` |

After every row was restored, each file named above was green.

## A row run by file (critic, whole MR)

A row killed by the time bound alone reached the Manager with no test. B3's
first form (the refusal dropped outright) did not compile: it left `red_main/1`
unused.

| # | Mutation | Tests failed | First failure, verbatim |
|---|---|---|---|
| B1 | the baseline leaves out the killer files run whole | 2 of 13: "a killer file run whole that fails with no mutant ...", "a row killed by the time bound alone ..." | `** (Mox.UnexpectedCallError) no expectation defined for Anchor.SourceMutationMock.write_journal/2` |
| B2 | the by-file note never printed | 2 of 39: "a row run by file says so; a row run by name does not", "a row killed by the time bound alone ..." | `left:  "still killed aaaaaaaaaaaa Calc.add/2 return_input\nstill killed 3f9a01c2b7de Calc.add/2 return_input\nanchor.sabotage replay: 2 rows in 1 records; ...` |
| B3 | a failed baseline read as a pass | 2 of 13: "a killer file run whole that fails ...", "1: the killers fail with no mutant ..." | `** (Mox.UnexpectedCallError) no expectation defined for Anchor.SourceMutationMock.write_journal/2` |

After every row was restored, each file named above was green.

## The replay's failure branches (critic, whole MR)

The critic found no test on a killer that does not read as a test. The sweep of
that class (a branch of the replay that ends a row or the run other than by a
pass) found five more: a function never read, git failing on the dirty check, a
baseline ending in neither a pass nor a failure, a test run that cannot start
(baseline and row), and a record the store cannot read. G8's and G6's rows show
a write the test did not expect: Hammox fails it. Each row ran `mix test --force
--timeout 2000 --max-cases 2`.

| # | Mutation | Tests failed | First failure, verbatim |
|---|---|---|---|
| G1 | a killer that does not read is dropped | 1 of 30: "a killer that does not read as a test is drifted, never dropped" | `left:  []` |
| G2 | `(timeout)` drifts as a bad killer | 3 of 30: "a (timeout) row runs the killer files ...", "a (timeout) row with no other killed row ...", "(timeout) beside a named killer ..." | `left:  %{replayable: [t, _k], drifted: []}` |
| G3 | a function never read gives no mutants | 1 of 30: "a function the plan never read is drifted, function gone" | `left:  [` |
| G4 | the drift line loses why the killer does not read | 1 of 30: "a killer that does not read names itself in the drift line" | ``left:  "drifted (killer \"--include:1 test x\": false) 3f9a01c2b7de Calc.add/2 return_input ...`` |
| G5 | git failing on the dirty check is exit 2 | 1 of 18: "git cannot say what is dirty: exit 3, before any test runs" | `left:  %{refusal: {3, message}}` |
| G6 | a baseline that timed out reads as a pass | 1 of 18: "the baseline ends any other way (a timeout) ..." | `** (Mox.UnexpectedCallError) no expectation defined for Anchor.SourceMutationMock.write_journal/2` |
| G7 | a baseline that cannot start is always exit 3 | 1 of 18: "the baseline cannot start: the run ends on the refusal's own code and message" | `left:  %{refusal: {2, message}}` |
| G8 | a row's refusal does not end the run | 1 of 18: "a row's test run cannot start: the file is restored, and the run ends on the refusal" | `** (Mox.UnexpectedCallError) expected Anchor.SourceMutationMock.write_journal/2 to be called once but it has been called 2 times` |
| G9 | a record the store cannot read is dropped silently | 1 of 18: "a record that cannot be read at all is named by its path and error; alone, exit 3" | `left:  []` |

After every row was restored, each file named above was green (`48 tests, 0
failures`).

## The replay's task and its cap (critic, whole MR)

The weekly job fails only through the task's exit code, and no test reached it;
nor did any reach the documented cap with no `--max`. The test file drives
`mix anchor.sabotage replay` itself, every adapter doubled.

| # | Mutation | Tests failed | First failure, verbatim |
|---|---|---|---|
| H1 | the task never exits non-zero | 2 of 14: "a row lost power: exit 1, and the row is printed", "no rows: exit 3, COULD NOT MEASURE is printed" | `Expected to catch exit, got nothing` |
| H2 | every failure is exit 1 | 1 of 14: "no rows: exit 3 ..." | `left:  {:shutdown, 1}` |
| H3 | every run is exit 1 | 2 of 14: "no rows: exit 3 ...", "every row still killed: exit 0, and the row is printed" | `left:  {:shutdown, 1}` |
| H4 | the result never printed | 3 of 14: each of the three | `left:  ""` |
| H5 | no `--max` lifts the cap | 1 of 19: "no --max: the cap is the config's max_mutants" | `** (Mox.UnexpectedCallError) expected Anchor.SourceMutationMock.write_journal/2 to be called once but it has been called 2 times` |

After every row was restored, each file named above was green (`33 tests, 0
failures`).
