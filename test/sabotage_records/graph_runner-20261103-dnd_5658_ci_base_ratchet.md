# Sabotage record: `mix anchor.graph --project DIR` and the root-scoped config load (DND-5658)

- **Domain:** graph_runner
- **Branch:** dnd-5658-ci-base-ratchet
- **Date:** 2026-11-03
- **Code under test:** `Mix.Tasks.Anchor.Graph` (`target/3`, `refuse_project/1`), `Anchor.Managers.Graph` (`load_config/2`)
- **Suite run:** `mix test --timeout 2000 --max-cases 2 test/mix/tasks/anchor_graph_test.exs` (G1-G6, G8), and the same on `test/anchor/managers/graph_test.exs` (G7), through `test-slot`

Each mutation was one `perl -0pi` substitution in the named file. The suite ran, then `git checkout -- <file>` restored the file. That was safe because the branch's work was committed first. A mutation that did not change the file would have printed `MUTATION DID NOT APPLY`, and none did. The first try at G3-G7 used a literal `false ->` cond clause or dropped a variable's use. Under `warnings_as_errors` that failed to compile and ran no test, so those runs do not count. They were re-run with mutations that compile: `Process.get(:dnd_5658_sabotage) ->`, `x == :dnd_5658_never ->`, and `File.cwd!() || root`.

| # | Mutation | Tests failed | Failing test (failure) |
|---|---|---|---|
| G1 | `--project` keeps the working directory as root (`%{root: File.cwd!(), apps: ...}`) | 1 of 14 | `--project DIR reads DIR's config, beams, sources, baselines and git; the artifact stays the judge's` (`** (FunctionClauseError) no function clause matching in anonymous fn/1 in Mix.Tasks.Anchor.GraphTest."test --project DIR reads DIR's config, beams, sources, baselines and git; the artifact stays the judge's"/1`: the `load_in` expectation pins `^dir`) |
| G2 | the judged ebin is read under the working directory, not DIR | 1 of 14 | same test: `assert ebin == Path.join(dir, "_build/test/lib/anchor/ebin")`, left `.../dnd-5658-ci-base-ratchet/_build/test/lib/anchor/ebin`, right `/tmp/anchor-project-197/_build/test/lib/anchor/ebin` |
| G3 | `--write-baseline` with `--project` is not refused | 1 of 14 | `--project DIR a DIR that is not a directory, --write-baseline and an umbrella judge exit 2 with Fix:` (`Mox.UnexpectedCallError ... ConfigLoaderMock.load_in/1 ... with args ["/tmp/anchor-project-201"]`: the run went on) |
| G4 | a DIR that is not a directory is not refused | 1 of 14 | same test (`... load_in/1 ... with args ["/tmp/anchor-project-520/missing"]`) |
| G5 | an umbrella judge is not refused | 1 of 14 | same test (`... load_in/1 ... with args ["/tmp/anchor-project-324"]`) |
| G6 | a build path outside the checkout is not refused | 1 of 14 | `--project DIR a build path outside this checkout exits 2: DIR's ebin could not be found` (`... load_in/1 ... with args ["/tmp/anchor-project-8"]`) |
| G7 | the Manager loads the config from the working directory (`loader.load_in(File.cwd!() \|\| root)`) | 35 of 35 | every `Anchor.Managers.GraphTest` test whose `load_in` expectation pins `@root` (`FunctionClauseError in anonymous fn/1 in Anchor.Managers.GraphTest.expect_run/3`) |
| G8 | the graph artifact goes under DIR's build path, not the judge's | 2 of 14 | the `--project DIR` test (`assert artifact_dir == Path.join(Mix.Project.build_path(), "anchor")`, left `/tmp/anchor-project-9/_build/test/anchor`) and `the artifact goes under Mix's build path, as MIX_BUILD_PATH sets it` |

The verbatim run logs are at `ai-artifacts/coordination/2026-11-03-anchor-causal/logs/DND-5658/sab/` in the custom repo (machine-local).

**Later (2026-11-06, the merge of main at 48c6728):** the Manager outside `--project` went back to `loader.load()`, as main calls it, so main's new graph tests and in-flight branches keep their stubs. G7's seam (`load_in/1` under the request's root) is gone from the graph path, and the `@root` pins it counted in `graph_test.exs` went with it. Under `--project` the root still reaches the loader: L7 and G1 hold it (`load_judged/1`, `fn @root`). The `load_in/1` strings quoted above are the failures as they read then.
