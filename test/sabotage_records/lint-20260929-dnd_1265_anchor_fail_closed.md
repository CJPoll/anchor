# Sabotage record — Manager reports unparseable files (DND-1265)

- **Domain:** lint
- **Branch:** dnd-1265-anchor-fail-closed
- **Date:** 2026-09-29
- **Code under test:** `Anchor.Managers.Lint.run/4` (`result_for_file/6`,
  `put_module_analyses/2`)
- **Suite run:** `mix test` (the whole suite, 530 tests)
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
```

## Mutations

| # | Mutation | Tests failed | Failure string |
|---|---|---|---|
| M | the reporter returns `{source_file, []}` for an unparseable file | 4 | `code: assert {:ok, [{^broken, [%Violation{} = violation]}]} =` / `right: {:ok, [{%SourceFile<lib/broken.ex>, []}]}`; e2e: `left: [issue]` / `right: []` |
| U | drop `put_module_analyses/2`'s unparseable-file clause | 1 | `** (FunctionClauseError) no function clause matching in Anchor.Managers.Lint.put_module_analyses/2` / `code: Lint.run(NoTransitiveDependency, [broken, file_a, file_b], [],` |

U would have been a measured zero without the row "a graph-needing check builds
its graph from the parseable files only", added in this run: no other test runs
a graph-needing check over an unparseable file.
