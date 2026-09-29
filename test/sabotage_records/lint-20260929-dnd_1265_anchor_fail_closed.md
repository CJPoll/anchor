# Sabotage record — Manager reports unparseable files (DND-1265)

- **Domain:** lint
- **Branch:** dnd-1265-anchor-fail-closed
- **Date:** 2026-09-29
- **Code under test:** `Anchor.Managers.Lint.run/4` (`result_for_parse/3`,
  `put_module_analyses/2`)
- **Suite run:** `mix test` (the whole suite; 534 tests)
- **Merge base:** `origin/main` = 8cff72b
- **Sibling records (same run):** `config-`, `failures-`, `base-`, `source-20260929-dnd_1265_anchor_fail_closed.md`

## Fail-first run

Against 8cff72b, verbatim. The unfixed Manager turned the unparseable file into
an empty AST, and `must_use_module` then reported a false violation on it:

```
 26) test run/4 unparseable source file the shared-failure reporter gets a parse violation for the file (Anchor.Managers.LintTest)
     Assertion with =~ failed
     code:  assert violation.message =~ "could not parse"
     left:  "Module must use MyApp.Base"
     right: "could not parse"

 25) test run/4 unparseable source file a non-reporter check gets no violation, and no detection runs on it (Anchor.Managers.LintTest)
     match (=) failed
     The following variables were pinned:
       broken = %SourceFile<lib/broken.ex>
     code:  assert {:ok, [{^broken, []}]} =
              Lint.run(MustUseModule, [broken], [],
                config_loader: ConfigLoaderMock,
                report_shared_failures: false
              )
     left:  {:ok, [{^broken, []}]}
     right: {:ok,
             [
               {%SourceFile<lib/broken.ex>,
                [
                  %Anchor.Domain.Violation{
                    line: 1,
                    trigger: "MyApp.Base",
                    message: "Module must use MyApp.Base"
                  }
                ]}
             ]}
```

## Mutations

Re-run after the review round made `run/4` parse each file lazily (534 tests).

| # | Mutation | Tests failed | Failure string |
|---|---|---|---|
| M | the reporter returns an empty list for an unparseable file | 5 | `code: assert {:ok, [{^broken, [%Violation{} = violation]}]} =` / `left: {:ok, [{^broken, [%Anchor.Domain.Violation{} = violation]}]}` / `right: {:ok, [{%SourceFile<lib/broken.ex>, []}]}`; e2e: `left: [issue]` / `right: []` (the file row and the once-per-run row) |
| U | drop `put_module_analyses/2`'s unparseable-file clause | 1 | `** (FunctionClauseError) no function clause matching in Anchor.Managers.Lint.put_module_analyses/2` / `code: Lint.run(NoTransitiveDependency, [broken, file_a, file_b], [],` |

**U was a measured zero until this run added its row.** No test ran a
graph-needing check over an unparseable file. The row "a graph-needing check
builds its graph from the parseable files only" was added, and U then reddened
it.

## Rows that stayed green, and why

- Under M, the non-reporter row stays green: it expects `[]` for the broken
  file, which is what M returns.
- Under U, only the graph row fails: every other unparseable-file row uses a
  check without the module graph, which never reaches `put_module_analyses/2`.

## Traps

- The first run of M reported `NO COUNT LINE`: replacing the result with
  `{source_file, []}` left `line` and `message` unused, a compile warning that
  `--warnings-as-errors` turns into a compile failure. It was rewritten as
  `Enum.take([...], 0)` and re-run.
- The rows above come from runs over a committed tree; the driver restored each
  file with `git checkout -- <file>`, and `git status --short` was clean after.
  U's first run (before the lazy-parse change) ran while its new test row was
  still uncommitted; the driver never checks out a test file, so the row was
  untouched.
