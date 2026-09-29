# Sabotage record — config fails closed (DND-1265)

- **Domain:** config
- **Branch:** dnd-1265-anchor-fail-closed
- **Date:** 2026-09-29
- **Code under test:** `Anchor.Config.parse_config/1`, `Anchor.Config.parse_rule/1`
  (`parse_type/1`, `parse_match/2`, `parse_mode/2`, `parse_token/4`,
  `fetch_rules/1`, `validate_top_level_keys/1`, `rule_type/1`, `@rule_types`),
  `Anchor.Adapters.ConfigFile.load/0`, `Anchor.Domain.ConfigPaths.candidates/2`,
  and the data file `.anchor.yml`
- **Suite run:** `mix test` (the whole suite; 530 tests in round 1, 534 in round 2)
- **Merge base:** `origin/main` = 8cff72b
- **Sibling records (same run):** `failures-`, `lint-`, `base-`, `source-20260929-dnd_1265_anchor_fail_closed.md`

## Fail-first run

The tests were written first and run against the unfixed code on 8cff72b:
`526 tests, 47 failures`, every one a new or changed DND-1265 test. The config
rows, verbatim (long rule maps cut with `...`):

```
  3) test parse_rule/1 rule type (A8) an unknown type fails, naming the token and the known types (Anchor.Domain.ConfigFailClosedTest)
     match (=) failed
     code:  assert {:error, {:invalid_rule, reason}} =
              Config.parse_rule(%{"type" => "no_direct_dependancy", "forbidden_modules" => ["X"]})
     left:  {:error, {:invalid_rule, reason}}
     right: %{
              match: :reference,
              type: :no_direct_dependancy,
              ...

 17) test parse_rule/1 match token (A9) an unknown match token fails instead of falling back to :reference (Anchor.Domain.ConfigFailClosedTest)
     match (=) failed
     code:  assert {:error, {:invalid_rule, reason}} =
              Config.parse_rule(%{"type" => "no_direct_dependency", "match" => "sideways"})
     left:  {:error, {:invalid_rule, reason}}
     right: %{
              match: :reference,
              type: :no_direct_dependency,
              ...

  2) test parse_rule/1 mode token (same class as A9) the README's leading-colon mode tokens parse to their mode (Anchor.Domain.ConfigFailClosedTest)
     match (=) failed
     code:  assert %{mode: :all} = Config.parse_rule(%{"type" => "alphabetized_functions", "mode" => ":all"})
     left:  %{mode: :all}
     right: %{
              match: :reference,
              type: :alphabetized_functions,
              mode: :separate,
              ...

 15) test parse_config/1 document shape an empty document (nil) fails: an empty .anchor.yml checks nothing (Anchor.Domain.ConfigFailClosedTest)
     match (=) failed
     code:  assert {:error, {:invalid_config, reason}} = Config.parse_config(nil)
     left:  {:error, {:invalid_config, reason}}
     right: %Anchor.Config{rules: []}

 24) test parse_config/1 document shape an unknown top-level key fails (a typo such as `anchors:` for `rules:`) (Anchor.Domain.ConfigFailClosedTest)
     match (=) failed
     code:  assert {:error, {:invalid_config, reason}} = Config.parse_config(data)
     left:  {:error, {:invalid_config, reason}}
     right: %Anchor.Config{rules: []}

 40) test load/0 (test-matrix: config.ex -> load/0 and load_from_path/1) returns {:config_not_found, searched} when no candidate exists in the cwd (Anchor.Adapters.ConfigFileTest)
     match (=) failed
     code:  assert {:error, {:config_not_found, [searched]}} = ConfigFile.load()
     left:  {:error, {:config_not_found, [searched]}}
     right: {:ok, %Anchor.Config{rules: []}}

 46) test load/0 (test-matrix: config.ex -> load/0 and load_from_path/1) a config outside the computed candidates is reported, not read as empty (Anchor.Adapters.ConfigFileTest)
     match (=) failed
     code:  assert {:error, {:config_not_found, [searched]}} = ConfigFile.load()
     left:  {:error, {:config_not_found, [searched]}}
     right: {:ok, %Anchor.Config{rules: []}}
```

Row 2 is a live bug the README shipped: its example says `mode: :separate`, and
YAML decodes `mode: :all` to the string `":all"`, which the old parser turned
into `:separate`.

The `rule_types/0` rows failed first only because the function did not exist:

```
 12) test parse_rule/1 rule type (A8) the known types are exactly the rule types of Anchor.checks/0 (Anchor.Domain.ConfigFailClosedTest)
     ** (UndefinedFunctionError) function Anchor.Config.rule_types/0 is undefined or private
```

Mutation AE proves the drift row.

## Mutations

Each mutation was applied alone, the whole suite run, and the file restored.
Labels run A–AG. **T was never applied**: it was a placeholder entry in the
driver, skipped by design, not a dropped result. Every applied mutation
reddened at least one test.

| # | Mutation | Tests failed | Failure string (first failing row) |
|---|---|---|---|
| A | `parse_type/1`: an unknown type becomes `{:ok, String.to_atom(type)}` (the A8 defect) | 4 | `code: assert {:error, {:invalid_rule, reason}} = Config.parse_config(data)` / `left: {:error, {:invalid_rule, reason}}` / `right: %Anchor.Config{` (rule 2 position row); e2e: `left: [issue]` / `right: []` |
| B | `parse_match/2`: an unknown token becomes `{:ok, :reference}` (the A9 defect) | 3 | `left: {:error, {:invalid_rule, _reason}}` / `right: %{` then `match: :reference,` |
| C | `parse_mode/2`: an unknown token becomes `{:ok, :separate}` | 2 | `left: {:error, {:invalid_rule, reason}}` / `right: %{` then `match: :reference,` (the built rule map) |
| D | drop the leading-colon `parse_token/4` clause | 3 | `code: assert %{match: :call} = Config.parse_rule(%{"type" => "no_direct_dependency", "match" => ":call"})` / `left: %{match: :call}` / `right: {:error,`; the README example row: `left: {:ok, %Anchor.Config{rules: rules}}` / `right: {:error,` |
| E | `fetch_rules/1`: no `rules` key gives `{:ok, []}` | 3 | `code: assert {:error, {:invalid_config, _reason}} = Config.parse_config(%{})` / `right: %Anchor.Config{rules: []}`; adapter empty-file row: `right: {:ok, %Anchor.Config{rules: []}}` |
| F | `validate_top_level_keys/1` accepts any key | 1 | `code: assert reason =~ ~s("anchors")` / `left: "the document has no \`rules:\` list"` / `right: "\"anchors\""` |
| G | `parse_config(nil)` returns `%Config{}` | 2 | `code: assert {:error, {:invalid_config, _reason}} = Config.parse_config(nil)` / `right: %Anchor.Config{rules: []}` |
| H | `ConfigFile.load/0`: no candidate gives `{:ok, %Config{}}` (the A6 defect) | 5 | `code: assert {:error, {:config_not_found, [searched]}} = ConfigFile.load()` / `right: {:ok, %Anchor.Config{rules: []}}`; e2e: `left: [issue]` / `right: []` |
| I | `ConfigPaths.candidates/2` accepts a relative cwd | 1 | `Expected exception ArgumentError but nothing was raised` / `code: assert_raise ArgumentError, ~r/absolute/, fn -> ConfigPaths.candidates("proj", false) end` |
| J | `ConfigFile.load/0` uses `File.regular?/1`, so a directory named `.anchor.yml` is skipped | 1 | `left: {:error, {:config_load_failed, path, {:read, :eisdir}}}` / `right: {:error, {:config_not_found, ["/tmp/anchor_cwd_4098/.anchor.yml"]}}` |
| V | `rule_type/1` interpolates a non-string type raw | 1 | `** (Protocol.UndefinedError) protocol String.Chars not implemented for Map.` / `code: Config.parse_rule(%{"type" => %{"x" => 1}, "same_context" => "yes"})` |
| AE | drop `struct_getter_convention` from `@rule_types` | 2 | `code: assert Enum.sort(Config.rule_types()) == check_types` / `left: [:alphabetized_functions, :case_on_bare_arg, :max_file_length,` / `right: [:alphabetized_functions, :case_on_bare_arg, :max_file_length,` (the lists differ in their last element); `code: assert reason =~ "struct_getter_convention"` |
| AF | data: `.anchor.yml` says `type: must_use_modul` | 1 | `code: assert {:ok, %Config{rules: [_ \| _]}} = ConfigFile.load_from_path(".anchor.yml")` / `left: {:ok, %Anchor.Config{rules: [_ \| _]}}` / `right: {:error,` |
| AG | drop the leading-colon clause of `parse_type/1` | 1 | `code: assert %{type: :no_direct_dependency} = Config.parse_rule(%{"type" => ":no_direct_dependency"})` / `right: {:error,` |

A to J and V ran in round 1 (530 tests); AE, AF and AG in round 2 (534 tests).

**V was first a measured zero.** Its first run gave `529 tests, 0 failures`: no
test fed a non-string `type` into an earlier validation's message, so the crash
path was unprotected. The row "a mapping as the type fails with a reason, not a
crash" was added, and V then reddened it (the row above).

## Rows that stayed green, and why

- A mutation to the `type`/`match`/`mode` parse does not move the
  `same_context` rows (Gap F): those validate other keys, before the type parse.
- H does not move the `load_from_path/1` rows: they bypass the candidate search.
- Under AE, "every known type parses to its atom" stays green. It iterates
  `Config.rule_types()` itself, so it cannot see a type missing from that list;
  the drift row against `Anchor.checks/0` is what catches AE.

## Traps

- The first runs of F, K, M and O reported `NO COUNT LINE`: each mutation left
  an unused variable or an unreachable clause, and `mix test` compiles with
  `--warnings-as-errors`. That is a compile failure, not a test failure. Each was
  rewritten to compile cleanly (for F, `|> Enum.take(0)` instead of `case []`)
  and re-run; the rows are from the clean runs. F is recorded here; K, M and O
  in the failures, lint and base records.
- Every mutated file was committed before its run, so the driver's
  `git checkout -- <file>` restored exactly the committed code. One batch (the
  first U and V runs) ran while two new test rows were still uncommitted; the
  driver never checks out a test file, so they were untouched, and
  `git status --short` afterwards showed only those two test files. Every other
  batch ended with a clean `git status --short`.
