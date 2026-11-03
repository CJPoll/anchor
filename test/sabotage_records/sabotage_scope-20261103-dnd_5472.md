# Sabotage record — `mix anchor.sabotage scope`: the functions a diff changed (DND-5472)

- **Domain:** sabotage_scope
- **Branch:** dnd-5472
- **Date:** 2026-11-03
- **Code under test:** `Anchor.Domain.Sabotage.DiffHunks`, `Anchor.Domain.Sabotage.FunctionSpans`,
  `Anchor.Domain.Sabotage.Scope`, `Anchor.Domain.Failures.scope_could_not_measure/1`,
  `Anchor.Managers.Sabotage.scope/2`, `Anchor.Adapters.GitChangeSource`, `Mix.Tasks.Anchor.Sabotage`
- **Suite run:** per mutation, `MIX_ENV=test mix test <the test file in its row>`, each mutation applied
  alone to the branch's tree and restored byte-for-byte after its run.

Off-domain mutations in this record: `failures` (rows N, AG, BC, `Anchor.Domain.Failures`). The Mission's QA
plan names this one record for the whole change, so it is filed under its primary domain (see the
records README, "one combined record").

Every one of the 65 tests this change adds failed under at least one mutation below.

## Mutations

| # | Mutation | Test file | Tests that failed | Run |
|---|---|---|---|---|
| A | `Scope.map_hunk/4` maps a deletion point to nothing and counts nothing | `scope_test.exs` | S13, S3, S4 | `16 tests, 3 failures` |
| B | `Scope.kind/1` drops the `test` path-segment rule (only `_test.exs` is a test file) | `scope_test.exs` | S6 | `16 tests, 1 failure` |
| BH | `Scope.kind/1` drops the `deps` and `_build` segment rule | `scope_test.exs` | S7 | `16 tests, 1 failure` |
| C | `Scope.add_line/4` keeps the first clause's lines (clause union dropped) | `scope_test.exs` | R1, R2, S11, S2, S9 | `16 tests, 5 failures` |
| AX | `Scope.add_line/4` keys a function by `{identity, first line}` (identity carries a line) | `scope_test.exs` | R1, R2, S11, S2, S9 | `16 tests, 5 failures` |
| O | a changed line in no span no longer counts its hunk as outside a function | `scope_test.exs` | R1, R2, S12, S13, S4, S5 | `16 tests, 6 failures` |
| AA | a changed line held only by a macro no longer counts its hunk as a macro | `scope_test.exs` | S10, S12, S9 | `16 tests, 3 failures` |
| M | an added file's one all-lines hunk is dropped | `scope_test.exs` | S9 | `16 tests, 1 failure` |
| AE | an added file's own lines outside its functions count as a hunk outside a function | `scope_test.exs` | S9 | `16 tests, 1 failure` |
| AC | `Scope.between_clauses/2` never finds the function around a deleted middle clause | `scope_test.exs` | S13 | `16 tests, 1 failure` |
| AW | functions within a file are ordered by last line first | `scope_test.exs` | S12, S9 | `16 tests, 2 failures` |
| AY | `Scope.map_hunk/4` reads `start + 1..start + count` (off by one) | `scope_test.exs` | R1, R2, S1, S11, S12, S2, S5, S8 | `16 tests, 8 failures` |
| AY2 | as AY, run against the Manager tests | `sabotage_scope_test.exs` | M1 | `11 tests, 1 failure` |
| AY3 | as AY, run against the task tests | `anchor_sabotage_scope_test.exs` | F1, F2 | `5 tests, 2 failures` |
| AZ | the summary says `function(s) in` | `scope_test.exs` | R1, R3 | `16 tests, 2 failures` |
| D | `FunctionSpans.last_line/2` uses the def's own line when there is no `end` (keyword-def end from `line` only) | `function_spans_test.exs` | P3 | `13 tests, 1 failure` |
| G | `FunctionSpans.walk/3` does not mark defs inside `quote` | `function_spans_test.exs` | P8 | `13 tests, 1 failure` |
| Z | a def whose name `unquote` builds is not marked `excluded_macro` | `function_spans_test.exs` | P12 | `13 tests, 1 failure` |
| H | `defimpl` without `for:` names the protocol alone | `function_spans_test.exs` | P7 | `13 tests, 1 failure` |
| AD | `defimpl ..., for: [A, B]` walks the first type only | `function_spans_test.exs` | P13 | `13 tests, 1 failure` |
| AI | every arity is one too many | `function_spans_test.exs` | P1, P13, P2, P3, P4, P5, P6, P7, P8, P9 | `13 tests, 10 failures` |
| AJ | a nested `defmodule` drops its parent's name | `function_spans_test.exs` | P6 | `13 tests, 1 failure` |
| AK | every span's kind is `:def` | `function_spans_test.exs` | P10, P8 | `13 tests, 2 failures` |
| AL | a parse error's line is read from a key that is not there (`nil`) | `function_spans_test.exs` | P11 | `13 tests, 1 failure` |
| AL2 | as AL, run against the Manager tests | `sabotage_scope_test.exs` | M6 | `11 tests, 1 failure` |
| F | `DiffHunks.step/2` leaves a hunk body on a line that looks like a `---`/`+++`/`@@` header | `diff_hunks_test.exs` | H8 | `11 tests, 1 failure` |
| L | `DiffHunks` ignores `+++ /dev/null` | `diff_hunks_test.exs` | **none (measured zero)** | `11 tests, 0 failures` |
| L2 | `DiffHunks` ignores both `+++ /dev/null` and `deleted file mode` | `diff_hunks_test.exs` | H5 | `11 tests, 1 failure` |
| AN | `DiffHunks` ignores both `--- /dev/null` and `new file mode` | `diff_hunks_test.exs` | H4, H9 | `11 tests, 2 failures` |
| Q | `DiffHunks.finish/1` accepts a hunk whose body ended early | `diff_hunks_test.exs` | H10 | `11 tests, 1 failure` |
| R | `DiffHunks.step/2` skips a line before the first `diff --git` header | `diff_hunks_test.exs` | H10 | `11 tests, 1 failure` |
| Y | C-quoted paths: octal escapes are not decoded | `diff_hunks_test.exs` | H6 | `11 tests, 1 failure` |
| AM | a count missing from a hunk header defaults to 0, not 1 | `diff_hunks_test.exs` | H11, H3, H6, H8 | `11 tests, 4 failures` |
| AO | empty diff text is one empty line | `diff_hunks_test.exs` | H7 | `11 tests, 1 failure` |
| AP | `Binary files ...` is not an accepted header line | `diff_hunks_test.exs` | H9 | `11 tests, 1 failure` |
| AQ | the `\ No newline at end of file` marker is not accepted, in a body or after it | `diff_hunks_test.exs` | H11 | `11 tests, 1 failure` |
| BF | a hunk records the old-side count, not the new-side count | `diff_hunks_test.exs` | H1, H2, H4, H6, H8 | `11 tests, 5 failures` |
| BG | a zero new-side count is recorded as 1 | `diff_hunks_test.exs` | H2 | `11 tests, 1 failure` |
| N | the no-merge-base `Fix:` text changed | `scope_failures_test.exs` | scope_could_not_measure/1 each known reason has its exact text | `2 tests, 1 failure` |
| AG | an empty git output is quoted as nothing (the stderr note dropped) | `scope_failures_test.exs` | scope_could_not_measure/1 each known reason has its exact text | `2 tests, 1 failure` |
| BC | the unknown-reason `Fix:` text changed | `scope_failures_test.exs` | scope_could_not_measure/1 an unknown reason is still reported, with Fix: | `2 tests, 1 failure` |
| E | `Managers.Sabotage` reads a merge-base error as an empty diff | `sabotage_scope_test.exs` | M3 | `11 tests, 1 failure` |
| AR | `:not_a_work_tree` reaches the caller without its root | `sabotage_scope_test.exs` | M3b | `11 tests, 1 failure` |
| AS | a diff error is read as diff text | `sabotage_scope_test.exs` | M4 | `11 tests, 1 failure` |
| S | diff text Anchor cannot read becomes an empty change set | `sabotage_scope_test.exs` | M4b | `11 tests, 1 failure` |
| AT | an untracked-files error is read as no untracked files | `sabotage_scope_test.exs` | M4c | `11 tests, 1 failure` |
| AB | untracked files are dropped | `sabotage_scope_test.exs` | M2, M7 | `11 tests, 2 failures` |
| T | an unreadable changed file is scoped as having no functions | `sabotage_scope_test.exs` | M5 | `11 tests, 1 failure` |
| U | an unparseable changed file is scoped as having no functions | `sabotage_scope_test.exs` | M6 | `11 tests, 1 failure` |
| BD | a clean diff is an error | `sabotage_scope_test.exs` | scope/2 a clean diff is ok with zero functions | `11 tests, 1 failure` |
| I | `GitChangeSource.untracked/1` drops the `*.ex` pathspec | `git_change_source_test.exs` | G2 | `7 tests, 1 failure` |
| J | `GitChangeSource.resolve/2` drops `--end-of-options` | `git_change_source_test.exs` | **none (measured zero)** | `7 tests, 0 failures` |
| P | `GitChangeSource.diff/2` drops `--src-prefix=a/ --dst-prefix=b/` | `git_change_source_test.exs` | G1b | `7 tests, 1 failure` |
| AH | `GitChangeSource.diff/2` drops `--submodule=short` | `git_change_source_test.exs` | **none (measured zero)** | `7 tests, 0 failures` |
| AF | every failed `rev-parse` is no merge-base (not only exit 1) | `git_change_source_test.exs` | **none (measured zero)** | `7 tests, 0 failures` |
| V | `merge-base` exit 1 is a git failure, not no merge-base | `git_change_source_test.exs` | G3b | `7 tests, 1 failure` |
| W | the work-tree check is skipped | `git_change_source_test.exs` | G4 | `7 tests, 1 failure` |
| BA | the merge-base sha keeps its trailing newline | `git_change_source_test.exs` | G1, G1b | `7 tests, 2 failures` |
| BB | `read/2` ignores `root` | `git_change_source_test.exs` | read returns contents, or the posix error | `7 tests, 1 failure` |
| BE | `resolve/2` resolves `HEAD`, whatever the ref | `git_change_source_test.exs` | G3, G3b | `7 tests, 2 failures` |
| K | the task prints COULD NOT MEASURE but does not `exit({:shutdown, 3})` | `anchor_sabotage_scope_test.exs` | F3 | `5 tests, 1 failure` |
| X | an unknown `--format` value renders as text | `anchor_sabotage_scope_test.exs` | F4 | `5 tests, 1 failure` |
| AU | `--format json` renders as text | `anchor_sabotage_scope_test.exs` | F2 | `5 tests, 1 failure` |
| AV | the default base is `main` | `anchor_sabotage_scope_test.exs` | F1b | `5 tests, 1 failure` |

## Failure output (verbatim, the first failing test of each run)

### A

`test build/2 S4: a deletion point between two functions is outside every function (Anchor.Domain.Sabotage.ScopeTest)`

```
test/anchor/domain/sabotage/scope_test.exs:79
Assertion with == failed
code:  assert scope.counts == %{@zero | outside_hunks: 1}
left:  %{
         macros: 0,
         test_files: 0,
         non_source_files: 0,
         deleted_files: 0,
         outside_hunks: 0
       }
right: %{
         macros: 0,
         test_files: 0,
         non_source_files: 0,
         deleted_files: 0,
         outside_hunks: 1
       }
```

### B

`test build/2 S6: test files are counted, never read, never in scope (Anchor.Domain.Sabotage.ScopeTest)`

```
test/anchor/domain/sabotage/scope_test.exs:92
Assertion with == failed
code:  assert scope.counts == %{@zero | test_files: 3}
left:  %{
         macros: 0,
         test_files: 1,
         non_source_files: 2,
         deleted_files: 0,
         outside_hunks: 0
       }
right: %{
         macros: 0,
         test_files: 3,
         non_source_files: 0,
         deleted_files: 0,
         outside_hunks: 0
       }
```

### BH

`test build/2 S7: config, docs and deps files are non-source (Anchor.Domain.Sabotage.ScopeTest)`

```
test/anchor/domain/sabotage/scope_test.exs:105
** (KeyError) key "_build/dev/lib/y.ex" not found in:

    %{}

code: assert Scope.build(files, %{}).counts == %{@zero | non_source_files: 4}
```

### C

`test render/2 R2: json decodes to the functions and the counts, the same values as text (Anchor.Domain.Sabotage.ScopeTest)`

```
test/anchor/domain/sabotage/scope_test.exs:216
Assertion with == failed
code:  assert JSON.decode!(Scope.render(scope, :json)) == %{
         "functions" => [
           %{
             "file" => "lib/m.ex",
             "module" => "M",
             "name" => "f",
             "arity" => 1,
             "function" => "f/1",
             "kind" => "def",
             "changed_lines" => [3, 4, 5, 8],
             "changed_line_ranges" => "3-5,8"
           }
         ],
         "function_count" => 1,
         "file_count" => 1,
         "excluded" => %{
           "test_files" => 1,
           "non_source_files" => 1,
           "deleted_files" => 0,
           "outside_hunks" => 1,
           "macros" => 0
         }
       }
left:  %{
         "excluded" => %{
           "deleted_files" => 0,
           "macros" => 0,
           "non_source_files" => 1,
           "outside_hunks" => 1,
           "test_files" => 1
         },
         "file_count" => 1,
         "function_count" => 1,
         "functions" => [
           %{
             "arity" => 1,
             "changed_line_ranges" => "3",
             "changed_lines" => [3],
             "file" => "lib/m.ex",
             "function" => "f/1",
             "kind" => "def",
             "module" => "M",
             "name" => "f"
           }
         ]
       }
right: %{
         "excluded" => %{
           "deleted_files" => 0,
           "macros" => 0,
           "non_source_files" => 1,
           "outside_hunks" => 1,
           "test_files" => 1
         },
         "file_count" => 1,
         "function_count" => 1,
         "functions" => [
           %{
             "arity" => 1,
             "changed_line_ranges" => "3-5,8",
             "changed_lines" => [3, 4, 5, 8],
             "file" => "lib/m.ex",
             "function" => "f/1",
             "kind" => "def",
             "module" => "M",
             "name" => "f"
           }
         ]
       }
```

### AX

`test build/2 S2: changed lines in two clauses of f/1 are one entry with the union of lines (Anchor.Domain.Sabotage.ScopeTest)`

```
test/anchor/domain/sabotage/scope_test.exs:58
match (=) failed
code:  assert [
         %ChangedFunction{
           file: "lib/m.ex",
           module: M,
           name: :f,
           arity: 1,
           kind: :def,
           changed_lines: [4, 8]
         }
       ] = scope.functions
left:  [
         %Anchor.Domain.Sabotage.ChangedFunction{
           file: "lib/m.ex",
           module: M,
           name: :f,
           arity: 1,
           kind: :def,
           changed_lines: [4, 8]
         }
       ]
right: [
         %Anchor.Domain.Sabotage.ChangedFunction{
           file: "lib/m.ex",
           module: M,
           name: :f,
           arity: 1,
           kind: :def,
           changed_lines: [4]
         },
         %Anchor.Domain.Sabotage.ChangedFunction{
           file: "lib/m.ex",
           module: M,
           name: :f,
           arity: 1,
           kind: :def,
           changed_lines: ~c"\b"
         }
       ]
```

### O

`test build/2 S5: a change on the @spec line above f is outside a function, and f is not in scope (Anchor.Domain.Sabotage.ScopeTest)`

```
test/anchor/domain/sabotage/scope_test.exs:86
Assertion with == failed
code:  assert scope.counts == %{@zero | outside_hunks: 1}
left:  %{
         macros: 0,
         test_files: 0,
         non_source_files: 0,
         deleted_files: 0,
         outside_hunks: 0
       }
right: %{
         macros: 0,
         test_files: 0,
         non_source_files: 0,
         deleted_files: 0,
         outside_hunks: 1
       }
```

### AA

`test build/2 S12: one hunk over two functions scopes both, in file then line order (Anchor.Domain.Sabotage.ScopeTest)`

```
test/anchor/domain/sabotage/scope_test.exs:178
Assertion with == failed
code:  assert scope.counts == %{@zero | outside_hunks: 1, macros: 1}
left:  %{
         macros: 0,
         test_files: 0,
         non_source_files: 0,
         deleted_files: 0,
         outside_hunks: 1
       }
right: %{
         macros: 1,
         test_files: 0,
         non_source_files: 0,
         deleted_files: 0,
         outside_hunks: 1
       }
```

### M

`test build/2 S9: an added file puts every function in scope, whatever its hunks say (Anchor.Domain.Sabotage.ScopeTest)`

```
test/anchor/domain/sabotage/scope_test.exs:129
Assertion with == failed
code:  assert Enum.map(scope.functions, &{&1.name, &1.arity}) == [f: 1, g: 1, h: 1]
left:  []
right: [f: 1, g: 1, h: 1]
```

### AE

`test build/2 S9: an added file puts every function in scope, whatever its hunks say (Anchor.Domain.Sabotage.ScopeTest)`

```
test/anchor/domain/sabotage/scope_test.exs:129
Assertion with == failed
code:  assert scope.counts.outside_hunks == 0
left:  1
right: 0
```

### AC

`test build/2 S13: a whole clause deleted from the middle of f/1 puts f/1 in scope (Anchor.Domain.Sabotage.ScopeTest)`

```
test/anchor/domain/sabotage/scope_test.exs:157
Assertion with == failed
code:  assert identities(scope) == [{M, :f, 1, [3]}]
left:  []
right: [{M, :f, 1, [3]}]
```

### AW

`test build/2 S12: one hunk over two functions scopes both, in file then line order (Anchor.Domain.Sabotage.ScopeTest)`

```
test/anchor/domain/sabotage/scope_test.exs:178
Assertion with == failed
code:  assert Enum.map(scope.functions, &{&1.file, &1.name}) == [
         {"lib/a.ex", :a},
         {"lib/m.ex", :g},
         {"lib/m.ex", :h}
       ]
left:  [{"lib/a.ex", :a}, {"lib/m.ex", :h}, {"lib/m.ex", :g}]
right: [{"lib/a.ex", :a}, {"lib/m.ex", :g}, {"lib/m.ex", :h}]
```

### AY

`test build/2 S2: changed lines in two clauses of f/1 are one entry with the union of lines (Anchor.Domain.Sabotage.ScopeTest)`

```
test/anchor/domain/sabotage/scope_test.exs:58
match (=) failed
code:  assert [
         %ChangedFunction{
           file: "lib/m.ex",
           module: M,
           name: :f,
           arity: 1,
           kind: :def,
           changed_lines: [4, 8]
         }
       ] = scope.functions
left:  [
         %Anchor.Domain.Sabotage.ChangedFunction{
           file: "lib/m.ex",
           module: M,
           name: :f,
           arity: 1,
           kind: :def,
           changed_lines: [4, 8]
         }
       ]
right: [
         %Anchor.Domain.Sabotage.ChangedFunction{
           file: "lib/m.ex",
           module: M,
           name: :f,
           arity: 1,
           kind: :def,
           changed_lines: [5, 9]
         }
       ]
```

### AY2

`test scope/2 M1: a modified file's changed function is in scope (Anchor.Managers.SabotageScopeTest)`

```
test/anchor/managers/sabotage_scope_test.exs:40
match (=) failed
code:  assert [%{file: "lib/m.ex", module: M, name: :f, arity: 1, changed_lines: [3]}] = scope.functions
left:  [%{file: "lib/m.ex", module: M, name: :f, arity: 1, changed_lines: [3]}]
right: [
         %Anchor.Domain.Sabotage.ChangedFunction{
           file: "lib/m.ex",
           module: M,
           name: :f,
           arity: 1,
           kind: :def,
           changed_lines: [4]
         }
       ]
```

### AY3

`test F1: text prints the TSV line and the summary (Mix.Tasks.Anchor.SabotageScopeTest)`

```
test/mix/tasks/anchor_sabotage_scope_test.exs:30
Assertion with == failed
code:  assert output ==
         "lib/m.ex\tM\tf/1\tdef\t3\n" <>
           "anchor.sabotage scope: 1 functions in 1 files; excluded: 0 test files, 0 non-source files, " <>
           "0 deleted files, 0 hunks outside a function, 0 macros\n"
left:  "lib/m.ex\tM\tf/1\tdef\t4\nanchor.sabotage scope: 1 functions in 1 files; excluded: 0 test files, 0 non-source files, 0 deleted files, 0 hunks outside a function, 0 macros\n"
right: "lib/m.ex\tM\tf/1\tdef\t3\nanchor.sabotage scope: 1 functions in 1 files; excluded: 0 test files, 0 non-source files, 0 deleted files, 0 hunks outside a function, 0 macros\n"
```

### AZ

`test render/2 R3: zero functions still prints the summary with every count (Anchor.Domain.Sabotage.ScopeTest)`

```
test/anchor/domain/sabotage/scope_test.exs:244
Assertion with == failed
code:  assert Scope.render(scope, :text) ==
         "anchor.sabotage scope: 0 functions in 0 files; excluded: 0 test files, " <>
           "1 non-source files, 0 deleted files, 0 hunks outside a function, 0 macros"
left:  "anchor.sabotage scope: 0 function(s) in 0 files; excluded: 0 test files, 1 non-source files, 0 deleted files, 0 hunks outside a function, 0 macros"
right: "anchor.sabotage scope: 0 functions in 0 files; excluded: 0 test files, 1 non-source files, 0 deleted files, 0 hunks outside a function, 0 macros"
```

### D

`test spans/2 P3: a keyword def whose body is a heredoc ends on the heredoc's closing line (Anchor.Domain.Sabotage.FunctionSpansTest)`

```
test/anchor/domain/sabotage/function_spans_test.exs:50
Assertion with == failed
code:  assert summary(spans!(source)) == [{M, :f, 1, :def, 2..6, false}, {M, :g, 0, :def, 8..8, false}]
left:  [{M, :f, 1, :def, 2..2, false}, {M, :g, 0, :def, 8..8, false}]
right: [{M, :f, 1, :def, 2..6, false}, {M, :g, 0, :def, 8..8, false}]
```

### G

`test spans/2 P8: macros and functions defined inside quote are marked excluded_macro (Anchor.Domain.Sabotage.FunctionSpansTest)`

```
test/anchor/domain/sabotage/function_spans_test.exs:141
Assertion with == failed
code:  assert summary(spans!(source)) == [
         {M, :m, 1, :defmacro, 2..6, true},
         {M, :generated, 1, :def, 4..4, true},
         {M, :p, 0, :defmacrop, 8..8, true},
         {M, :real, 0, :def, 10..10, false}
       ]
left:  [
         {M, :m, 1, :defmacro, 2..6, true},
         {M, :generated, 1, :def, 4..4, false},
         {M, :p, 0, :defmacrop, 8..8, true},
         {M, :real, 0, :def, 10..10, false}
       ]
right: [
         {M, :m, 1, :defmacro, 2..6, true},
         {M, :generated, 1, :def, 4..4, true},
         {M, :p, 0, :defmacrop, 8..8, true},
         {M, :real, 0, :def, 10..10, false}
       ]
```

### Z

`test spans/2 P12: a name built by unquote outside quote cannot be named, and is marked excluded_macro (Anchor.Domain.Sabotage.FunctionSpansTest)`

```
test/anchor/domain/sabotage/function_spans_test.exs:209
match (=) failed
code:  assert [%Span{excluded_macro: true, first: 3, last: 3}] = spans!(source)
left:  [%Anchor.Domain.Sabotage.Span{excluded_macro: true, first: 3, last: 3}]
right: [
         %Anchor.Domain.Sabotage.Span{
           module: M,
           name: nil,
           arity: 0,
           kind: :def,
           first: 3,
           last: 3,
           excluded_macro: false
         }
       ]
```

### H

`test spans/2 P7: defimpl names the protocol and the type, with or without for: inside a module (Anchor.Domain.Sabotage.FunctionSpansTest)`

```
test/anchor/domain/sabotage/function_spans_test.exs:120
Assertion with == failed
code:  assert summary(spans!(source)) == [
         {String.Chars.A, :to_string, 1, :def, 2..2, false},
         {Inspect.B, :inspect, 2, :def, 9..9, false}
       ]
left:  [
         {String.Chars.A, :to_string, 1, :def, 2..2, false},
         {Inspect, :inspect, 2, :def, 9..9, false}
       ]
right: [
         {String.Chars.A, :to_string, 1, :def, 2..2, false},
         {Inspect.B, :inspect, 2, :def, 9..9, false}
       ]
```

### AD

`test spans/2 P13: defimpl for: a list of types gives a span per type (Anchor.Domain.Sabotage.FunctionSpansTest)`

```
test/anchor/domain/sabotage/function_spans_test.exs:196
Assertion with == failed
code:  assert summary(spans!(source)) == [
         {String.Chars.A, :to_string, 1, :def, 2..2, false},
         {String.Chars.B, :to_string, 1, :def, 2..2, false}
       ]
left:  [{String.Chars.A, :to_string, 1, :def, 2..2, false}]
right: [
         {String.Chars.A, :to_string, 1, :def, 2..2, false},
         {String.Chars.B, :to_string, 1, :def, 2..2, false}
       ]
```

### AI

`test spans/2 P8: macros and functions defined inside quote are marked excluded_macro (Anchor.Domain.Sabotage.FunctionSpansTest)`

```
test/anchor/domain/sabotage/function_spans_test.exs:141
Assertion with == failed
code:  assert summary(spans!(source)) == [
         {M, :m, 1, :defmacro, 2..6, true},
         {M, :generated, 1, :def, 4..4, true},
         {M, :p, 0, :defmacrop, 8..8, true},
         {M, :real, 0, :def, 10..10, false}
       ]
left:  [
         {M, :m, 2, :defmacro, 2..6, true},
         {M, :generated, 2, :def, 4..4, true},
         {M, :p, 0, :defmacrop, 8..8, true},
         {M, :real, 0, :def, 10..10, false}
       ]
right: [
         {M, :m, 1, :defmacro, 2..6, true},
         {M, :generated, 1, :def, 4..4, true},
         {M, :p, 0, :defmacrop, 8..8, true},
         {M, :real, 0, :def, 10..10, false}
       ]
```

### AJ

`test spans/2 P6: nested modules qualify the inner module's name (Anchor.Domain.Sabotage.FunctionSpansTest)`

```
test/anchor/domain/sabotage/function_spans_test.exs:98
Assertion with == failed
code:  assert summary(spans!(source)) == [
         {A, :outer, 0, :def, 2..2, false},
         {A.B, :g, 1, :def, 5..5, false},
         {C, :h, 0, :def, 9..9, false}
       ]
left:  [
         {A, :outer, 0, :def, 2..2, false},
         {B, :g, 1, :def, 5..5, false},
         {C, :h, 0, :def, 9..9, false}
       ]
right: [
         {A, :outer, 0, :def, 2..2, false},
         {A.B, :g, 1, :def, 5..5, false},
         {C, :h, 0, :def, 9..9, false}
       ]
```

### AK

`test spans/2 P10: defp is kind :defp (Anchor.Domain.Sabotage.FunctionSpansTest)`

```
test/anchor/domain/sabotage/function_spans_test.exs:174
match (=) failed
code:  assert [%Span{kind: :defp, name: :f, arity: 0}] = spans!(source)
left:  [%Anchor.Domain.Sabotage.Span{kind: :defp, name: :f, arity: 0}]
right: [
         %Anchor.Domain.Sabotage.Span{
           module: M,
           name: :f,
           arity: 0,
           kind: :def,
           first: 2,
           last: 2,
           excluded_macro: false
         }
       ]
```

### AL

`test spans/2 P11: unparseable source is {:error, {line, reason}} (Anchor.Domain.Sabotage.FunctionSpansTest)`

```
test/anchor/domain/sabotage/function_spans_test.exs:184
Assertion with == failed
code:  assert line == 2
left:  nil
right: 2
```

### AL2

`test scope/2 M6: a changed file that does not parse names the file and line (Anchor.Managers.SabotageScopeTest)`

```
test/anchor/managers/sabotage_scope_test.exs:106
match (=) failed
code:  assert {:error, {:unparseable, "lib/m.ex", 2, reason}} = Sabotage.scope(@args, @opts)
left:  {:error, {:unparseable, "lib/m.ex", 2, reason}}
right: {:error,
        {:unparseable, "lib/m.ex", nil,
         "unexpected reserved word: end"}}
```

### F

`test parse/1 H8: a removed line that reads like a header is body, not a new file (Anchor.Domain.Sabotage.DiffHunksTest)`

```
test/anchor/domain/sabotage/diff_hunks_test.exs:129
Assertion with == failed
code:  assert DiffHunks.parse(diff) == {:ok, %{"lib/a.ex" => %{status: :modified, hunks: [{3, 1}, {8, 2}]}}}
left:  {:error, {:unrecognised_diff_line, 7, "-+++ b/lib/b.ex"}}
right: {:ok,
        %{
          "lib/a.ex" => %{
            status: :modified,
            hunks: [{3, 1}, {8, 2}]
          }
        }}
```

### L2

`test parse/1 H5: a file deleted (+++ /dev/null) is :deleted with no hunks, keyed by its old path (Anchor.Domain.Sabotage.DiffHunksTest)`

```
test/anchor/domain/sabotage/diff_hunks_test.exs:75
Assertion with == failed
code:  assert DiffHunks.parse(diff) == {:ok, %{"lib/old.ex" => %{status: :deleted, hunks: []}}}
left:  {:ok, %{"lib/old.ex" => %{status: :modified, hunks: [{0, 0}]}}}
right: {:ok, %{"lib/old.ex" => %{status: :deleted, hunks: []}}}
```

### AN

`test parse/1 H4: a file added (--- /dev/null) is :added (Anchor.Domain.Sabotage.DiffHunksTest)`

```
test/anchor/domain/sabotage/diff_hunks_test.exs:60
Assertion with == failed
code:  assert DiffHunks.parse(diff) == {:ok, %{"lib/new.ex" => %{status: :added, hunks: [{1, 2}]}}}
left:  {:ok, %{"lib/new.ex" => %{status: :modified, hunks: [{1, 2}]}}}
right: {:ok, %{"lib/new.ex" => %{status: :added, hunks: [{1, 2}]}}}
```

### Q

`test parse/1 H10: text git would not print is refused, never read as no change (Anchor.Domain.Sabotage.DiffHunksTest)`

```
test/anchor/domain/sabotage/diff_hunks_test.exs:170
match (=) failed
code:  assert {:error, {:truncated_hunk, "lib/a.ex"}} = DiffHunks.parse(truncated)
left:  {:error, {:truncated_hunk, "lib/a.ex"}}
right: {:ok, %{"lib/a.ex" => %{status: :modified, hunks: [{3, 2}]}}}
```

### R

`test parse/1 H10: text git would not print is refused, never read as no change (Anchor.Domain.Sabotage.DiffHunksTest)`

```
test/anchor/domain/sabotage/diff_hunks_test.exs:170
match (=) failed
code:  assert {:error, {:unrecognised_diff_line, 1, "warning: something"}} =
         DiffHunks.parse("warning: something\n")
left:  {:error, {:unrecognised_diff_line, 1, "warning: something"}}
right: {:ok, %{}}
```

### Y

`test parse/1 H6: three files, paths with spaces and quoted paths, all keyed by the b/ path (Anchor.Domain.Sabotage.DiffHunksTest)`

```
test/anchor/domain/sabotage/diff_hunks_test.exs:90
Assertion with == failed
code:  assert DiffHunks.parse(diff) ==
         {:ok,
          %{
            "lib/my file.ex" => %{status: :modified, hunks: [{2, 1}]},
            "lib/q\"é.ex" => %{status: :modified, hunks: [{1, 1}]},
            "README.md" => %{status: :modified, hunks: [{2, 3}]}
          }}
left:  {:ok,
        %{
          "README.md" => %{status: :modified, hunks: [{2, 3}]},
          "lib/my file.ex" => %{
            status: :modified,
            hunks: [{2, 1}]
          },
          "lib/q\"303251.ex" => %{
            status: :modified,
            hunks: [{1, 1}]
          }
        }}
right: {:ok,
        %{
          "README.md" => %{status: :modified, hunks: [{2, 3}]},
          "lib/my file.ex" => %{
            status: :modified,
            hunks: [{2, 1}]
          },
          "lib/q\"é.ex" => %{
            status: :modified,
            hunks: [{1, 1}]
          }
        }}
```

### AM

`test parse/1 H3: a hunk header without counts defaults each count to 1 (Anchor.Domain.Sabotage.DiffHunksTest)`

```
test/anchor/domain/sabotage/diff_hunks_test.exs:45
Assertion with == failed
code:  assert DiffHunks.parse(diff) == {:ok, %{"lib/a.ex" => %{status: :modified, hunks: [{7, 1}]}}}
left:  {:error, {:unrecognised_diff_line, 6, "-  x"}}
right: {:ok, %{"lib/a.ex" => %{status: :modified, hunks: [{7, 1}]}}}
```

### AO

`test parse/1 H7: empty text is an empty map (Anchor.Domain.Sabotage.DiffHunksTest)`

```
test/anchor/domain/sabotage/diff_hunks_test.exs:125
Assertion with == failed
code:  assert DiffHunks.parse("") == {:ok, %{}}
left:  {:error, {:unrecognised_diff_line, 1, ""}}
right: {:ok, %{}}
```

### AP

`test parse/1 H9: a binary or mode-only change has no hunks and is keyed by the header path (Anchor.Domain.Sabotage.DiffHunksTest)`

```
test/anchor/domain/sabotage/diff_hunks_test.exs:151
Assertion with == failed
code:  assert DiffHunks.parse(diff) ==
         {:ok,
          %{
            "lib/mode.ex" => %{status: :modified, hunks: []},
            "priv/logo.png" => %{status: :added, hunks: []}
          }}
left:  {:error,
        {:unrecognised_diff_line, 7,
         "Binary files /dev/null and b/priv/logo.png differ"}}
right: {:ok,
        %{
          "lib/mode.ex" => %{status: :modified, hunks: []},
          "priv/logo.png" => %{status: :added, hunks: []}
        }}
```

### AQ

`test parse/1 H11: a '\ No newline at end of file' marker inside a hunk is skipped (Anchor.Domain.Sabotage.DiffHunksTest)`

```
test/anchor/domain/sabotage/diff_hunks_test.exs:186
Assertion with == failed
code:  assert DiffHunks.parse(diff) == {:ok, %{"lib/a.ex" => %{status: :modified, hunks: [{4, 1}]}}}
left:  {:error,
        {:unrecognised_diff_line, 7,
         "\\ No newline at end of file"}}
right: {:ok, %{"lib/a.ex" => %{status: :modified, hunks: [{4, 1}]}}}
```

### BF

`test parse/1 H1: one modified file keeps the new-side start and count of its hunk (Anchor.Domain.Sabotage.DiffHunksTest)`

```
test/anchor/domain/sabotage/diff_hunks_test.exs:11
Assertion with == failed
code:  assert DiffHunks.parse(diff) == {:ok, %{"lib/a.ex" => %{status: :modified, hunks: [{3, 4}]}}}
left:  {:ok, %{"lib/a.ex" => %{status: :modified, hunks: [{3, 2}]}}}
right: {:ok, %{"lib/a.ex" => %{status: :modified, hunks: [{3, 4}]}}}
```

### BG

`test parse/1 H2: a zero-count hunk (a pure deletion) is kept with count 0 (Anchor.Domain.Sabotage.DiffHunksTest)`

```
test/anchor/domain/sabotage/diff_hunks_test.exs:30
Assertion with == failed
code:  assert DiffHunks.parse(diff) == {:ok, %{"lib/a.ex" => %{status: :modified, hunks: [{4, 0}]}}}
left:  {:ok, %{"lib/a.ex" => %{status: :modified, hunks: [{4, 1}]}}}
right: {:ok, %{"lib/a.ex" => %{status: :modified, hunks: [{4, 0}]}}}
```

### N

`test scope_could_not_measure/1 each known reason has its exact text (Anchor.Domain.Sabotage.ScopeFailuresTest)`

```
test/anchor/domain/sabotage/scope_failures_test.exs:31
Assertion with == failed
code:  assert Failures.scope_could_not_measure(reason) == text
left:  "COULD NOT MEASURE: no merge-base with origin/x. Fix: try again."
right: "COULD NOT MEASURE: no merge-base with origin/x. Fix: fetch it (git fetch origin) or pass --base <ref>."
```

### AG

`test scope_could_not_measure/1 each known reason has its exact text (Anchor.Domain.Sabotage.ScopeFailuresTest)`

```
test/anchor/domain/sabotage/scope_failures_test.exs:31
Assertion with == failed
code:  assert Failures.scope_could_not_measure(reason) == text
left:  "COULD NOT MEASURE: `git ls-files` exited 128: . Fix: run the command by hand to see why."
right: "COULD NOT MEASURE: `git ls-files` exited 128: (git's message is printed above, on stderr). Fix: run the command by hand to see why."
```

### BC

`test scope_could_not_measure/1 an unknown reason is still reported, with Fix: (Anchor.Domain.Sabotage.ScopeFailuresTest)`

```
test/anchor/domain/sabotage/scope_failures_test.exs:37
Assertion with == failed
code:  assert Failures.scope_could_not_measure({:something, :new}) ==
         "COULD NOT MEASURE: {:something, :new}. " <>
           "Fix: this is a defect in Anchor; report it with this text."
left:  "COULD NOT MEASURE: {:something, :new}. Fix: report it."
right: "COULD NOT MEASURE: {:something, :new}. Fix: this is a defect in Anchor; report it with this text."
```

### E

`test scope/2 M3: a merge-base error is returned, and nothing else is asked of git (Anchor.Managers.SabotageScopeTest)`

```
test/anchor/managers/sabotage_scope_test.exs:58
** (Mox.UnexpectedCallError) no expectation defined for Anchor.ChangeSourceMock.diff/2 in process #PID<0.243.0> with args ["/repo", ""]
code: assert Sabotage.scope(@args, @opts) == {:error, {:no_merge_base, "origin/main"}}
```

### AR

`test scope/2 M3b: not a work tree names the root (Anchor.Managers.SabotageScopeTest)`

```
test/anchor/managers/sabotage_scope_test.exs:66
Assertion with == failed
code:  assert Sabotage.scope(@args, @opts) == {:error, {:not_a_work_tree, @root}}
left:  {:error, :not_a_work_tree}
right: {:error, {:not_a_work_tree, "/repo"}}
```

### AS

`test scope/2 M4: a diff error carries the command and its output (Anchor.Managers.SabotageScopeTest)`

```
test/anchor/managers/sabotage_scope_test.exs:74
** (FunctionClauseError) no function clause matching in String.trim_trailing/2

The following arguments were given to String.trim_trailing/2:

    # 1
    {:git_failed, ["diff", "abc123"], 128, "fatal: bad object"}

    # 2
    "\n"

Attempted function clauses (showing 1 out of 1):

    def trim_trailing(string, to_trim) when -is_binary(string)- and is_binary(to_trim)

code: assert Sabotage.scope(@args, @opts) == {:error, failure}
```

### S

`test scope/2 M4b: diff text Anchor cannot read is an error, never an empty scope (Anchor.Managers.SabotageScopeTest)`

```
test/anchor/managers/sabotage_scope_test.exs:82
** (Mox.UnexpectedCallError) no expectation defined for Anchor.ChangeSourceMock.untracked/1 in process #PID<0.249.0> with args ["/repo"]
code: Sabotage.scope(@args, @opts)
```

### AT

`test scope/2 M4c: an untracked-files error is returned (Anchor.Managers.SabotageScopeTest)`

```
test/anchor/managers/sabotage_scope_test.exs:90
Assertion with == failed
code:  assert Sabotage.scope(@args, @opts) == {:error, failure}
left:  {:ok,
        %Anchor.Domain.Sabotage.Scope{
          functions: [],
          counts: %{
            macros: 0,
            test_files: 0,
            non_source_files: 0,
            deleted_files: 0,
            outside_hunks: 0
          }
        }}
right: {:error, {:git_failed, ["ls-files"], 128, "fatal"}}
```

### AB

`test scope/2 M7: only test files changed: zero functions, counted, and no file is read (Anchor.Managers.SabotageScopeTest)`

```
test/anchor/managers/sabotage_scope_test.exs:117
Assertion with == failed
code:  assert scope.counts.test_files == 3
left:  2
right: 3
```

### T

`test scope/2 M5: a changed file that cannot be read names the path (Anchor.Managers.SabotageScopeTest)`

```
test/anchor/managers/sabotage_scope_test.exs:99
Assertion with == failed
code:  assert Sabotage.scope(@args, @opts) == {:error, {:unreadable, "lib/m.ex", :eacces}}
left:  {:ok,
        %Anchor.Domain.Sabotage.Scope{
          functions: [],
          counts: %{
            macros: 0,
            test_files: 0,
            non_source_files: 0,
            deleted_files: 0,
            outside_hunks: 1
          }
        }}
right: {:error, {:unreadable, "lib/m.ex", :eacces}}
```

### U

`test scope/2 M6: a changed file that does not parse names the file and line (Anchor.Managers.SabotageScopeTest)`

```
test/anchor/managers/sabotage_scope_test.exs:106
match (=) failed
code:  assert {:error, {:unparseable, "lib/m.ex", 2, reason}} = Sabotage.scope(@args, @opts)
left:  {:error, {:unparseable, "lib/m.ex", 2, reason}}
right: {:ok,
        %Anchor.Domain.Sabotage.Scope{
          functions: [],
          counts: %{
            macros: 0,
            test_files: 0,
            non_source_files: 0,
            deleted_files: 0,
            outside_hunks: 1
          }
        }}
```

### BD

`test scope/2 a clean diff is ok with zero functions (Anchor.Managers.SabotageScopeTest)`

```
test/anchor/managers/sabotage_scope_test.exs:128
match (=) failed
code:  assert {:ok, %{functions: [], counts: counts}} = Sabotage.scope(@args, @opts)
left:  {:ok, %{functions: [], counts: counts}}
right: {:error, :nothing_changed}
```

### I

`test G2: untracked returns only untracked .ex files (Anchor.Adapters.GitChangeSourceTest)`

```
test/anchor/adapters/git_change_source_test.exs:65
Assertion with == failed
code:  assert GitChangeSource.untracked(root) == {:ok, ["lib/new.ex"]}
left:  {:ok, ["lib/new.ex", "notes.txt"]}
right: {:ok, ["lib/new.ex"]}
```

### P

`test G1b: staged changes are in the diff, and an ignored diff.noprefix cannot change it (Anchor.Adapters.GitChangeSourceTest)`

```
test/anchor/adapters/git_change_source_test.exs:52
Assertion with =~ failed
code:  assert diff =~ "diff --git a/lib/a.ex b/lib/a.ex"
left:  "diff --git lib/a.ex lib/a.ex\nindex 2576990..6e9d2da 100644\n--- lib/a.ex\n+++ lib/a.ex\n@@ -2 +2 @@ defmodule A do\n-  def f, do: 1\n+  def f, do: 3\n"
right: "diff --git a/lib/a.ex b/lib/a.ex"
```

### V

`test G3b: a ref with no history in common with HEAD is no merge-base (Anchor.Adapters.GitChangeSourceTest)`

```
test/anchor/adapters/git_change_source_test.exs:85
Assertion with == failed
code:  assert GitChangeSource.merge_base(root, "main") == {:error, {:no_merge_base, "main"}}
left:  {:error, {:git_failed, ["merge-base"], 1, ""}}
right: {:error, {:no_merge_base, "main"}}
```

### W

`test G4: a root that is not a git repository, or does not exist, is :not_a_work_tree (Anchor.Adapters.GitChangeSourceTest)`

```
test/anchor/adapters/git_change_source_test.exs:93
Assertion with == failed
code:  assert GitChangeSource.merge_base(outside, "main") == {:error, :not_a_work_tree}
left:  {:error,
        {:git_failed,
         ["rev-parse", "--verify", "--quiet",
          "--end-of-options", "main^{commit}"], 128,
         "fatal: not a git repository (or any of the parent directories): .git\n"}}
right: {:error, :not_a_work_tree}
```

### BA

`test G1b: staged changes are in the diff, and an ignored diff.noprefix cannot change it (Anchor.Adapters.GitChangeSourceTest)`

```
test/anchor/adapters/git_change_source_test.exs:52
match (=) failed
code:  assert {:ok, diff} = GitChangeSource.diff(root, sha)
left:  {:ok, diff}
right: {:error,
        {:git_failed,
         ["diff", "--unified=0", "--no-color", "--no-ext-diff",
          "--no-textconv", "--no-renames", "--relative",
          "--submodule=short", "--src-prefix=a/",
          "--dst-prefix=b/",
          "9d6453f5fe8ff2b3614aa642ab3318c83ac83dad\n", "--"],
         128, ""}}
```

### BB

`test read returns contents, or the posix error (Anchor.Adapters.GitChangeSourceTest)`

```
test/anchor/adapters/git_change_source_test.exs:110
** (FunctionClauseError) no function clause matching in Path.join/1

The following arguments were given to Path.join/1:

    # 1
    []

Attempted function clauses (showing 2 out of 2):

    def join(-[name1, name2 | rest]-)
    def join(-[name]-)

code: assert GitChangeSource.read(root, "lib/a.ex") ==
```

### BE

`test G3: an unresolvable ref, or one spelled like an option, is no merge-base (Anchor.Adapters.GitChangeSourceTest)`

```
test/anchor/adapters/git_change_source_test.exs:73
Assertion with == failed
code:  assert GitChangeSource.merge_base(root, "no-such-ref") == {:error, {:no_merge_base, "no-such-ref"}}
left:  {:ok, "08c016d47e6af71d105a56c0b3a27b85f633b32b"}
right: {:error, {:no_merge_base, "no-such-ref"}}
```

### K

`test F3: an unknown ref exits 3 with COULD NOT MEASURE and a Fix: line (Mix.Tasks.Anchor.SabotageScopeTest)`

```
test/mix/tasks/anchor_sabotage_scope_test.exs:60
Expected to catch exit, got nothing
code: capture_io(:stderr, fn ->
```

### X

`test F4: an unknown option, a bad format, or no subcommand is a usage error, exit 2 (Mix.Tasks.Anchor.SabotageScopeTest)`

```
test/mix/tasks/anchor_sabotage_scope_test.exs:74
** (Mox.UnexpectedCallError) no expectation defined for Anchor.ChangeSourceMock.merge_base/2 in process #PID<0.248.0> with args ["/home/cjpoll/.local/worktrees/anchor/dnd-5472", "origin/main"]
code: for argv <- [
```

### AU

`test F2: --format json prints valid JSON (Mix.Tasks.Anchor.SabotageScopeTest)`

```
test/mix/tasks/anchor_sabotage_scope_test.exs:47
** (JSON.DecodeError) invalid byte 108 at position (byte offset) 0
code: JSON.decode!(output)
```

### AV

`test F1b: the base defaults to origin/main (Mix.Tasks.Anchor.SabotageScopeTest)`

```
test/mix/tasks/anchor_sabotage_scope_test.exs:41
** (FunctionClauseError) no function clause matching in anonymous fn/2 in Mix.Tasks.Anchor.SabotageScopeTest.expect_one_change/1

The following arguments were given to anonymous fn/2 in Mix.Tasks.Anchor.SabotageScopeTest.expect_one_change/1:

    # 1
    "/home/cjpoll/.local/worktrees/anchor/dnd-5472"

    # 2
    "main"

code: assert capture_io(fn -> Sabotage.run(["scope"], @opts) end) =~ "1 functions in 1 files"
```

## Measured zeros, and why

- **J (`--end-of-options`).** No test reddens. The ref is passed as `<ref>^{commit}`, so an option-shaped
  `--base` (`--output=x`) is mangled into an argument rev-parse rejects with or without the separator. G3
  asserts the observable result (no merge-base), which holds either way. The flag is defence in depth.
- **L (`+++ /dev/null` alone).** No test reddens: git prints `deleted file mode` for every deleted file,
  and that line alone marks it deleted. L2 removes both signals and H5 fails, so the pair is protected.
  The same holds for an added file (AN removes both of its signals; H4 fails).
- **AH (`--submodule=short`).** No test reddens: no test makes a repository with a submodule and
  `diff.submodule=log`. Without the flag that config prints `Submodule ...` lines the parser refuses (exit
  3, never a wrong scope), so the gap fails closed.
- **AF (only rev-parse exit 1 is "no merge-base").** No test reddens: no test makes rev-parse fail any
  other way. The difference is the text of the `Fix:` line, not a pass or a failure.

## Traps

- D, L2 and X first failed to compile, not to test (`warnings_as_errors`): removing the only call of
  `max_line/2` or `deleted/1` is an unused function, and mapping every format to `:text` makes
  `scope(_base, :invalid, _opts)` an unused clause. Each was re-applied keeping the reference
  (`_ = {node, &max_line/2}`, `_ = {dev_null?(side), &deleted/1}`, `Enum.at([:text, :invalid], 0)`)
  before its row was taken.
