# Sabotage record — config fails closed (DND-1265)

- **Domain:** config
- **Branch:** dnd-1265-anchor-fail-closed
- **Date:** 2026-09-29
- **Code under test:** `Anchor.Config.parse_config/1`, `Anchor.Config.parse_rule/1`
  (`parse_type/1`, `parse_match/2`, `parse_mode/2`, `parse_token/4`,
  `fetch_rules/1`, `validate_top_level_keys/1`, `rule_type/1`),
  `Anchor.Adapters.ConfigFile.load/0`, `Anchor.Domain.ConfigPaths.candidates/2`
- **Suite run:** `mix test` (the whole suite, 530 tests, about 1 s)
- **Merge base:** `origin/main` = 8cff72b
- **Sibling records (same run):** `failures-`, `lint-`, `base-`, `source-20260929-dnd_1265_anchor_fail_closed.md`

## Fail-first run

The tests were written first and run against the unfixed code on 8cff72b:
`526 tests, 47 failures`, every one a new or changed DND-1265 test. The config
rows, verbatim:

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
     left:  {:error, {:invalid_rule, reason}}
     right: %{
              match: :reference,
              type: :no_direct_dependency,
              ...

  2) test parse_rule/1 mode token (same class as A9) the README's leading-colon mode tokens parse to their mode (Anchor.Domain.ConfigFailClosedTest)
     code:  assert %{mode: :all} = Config.parse_rule(%{"type" => "alphabetized_functions", "mode" => ":all"})
     left:  %{mode: :all}
     right: %{
              ...
              mode: :separate,

 15) test parse_config/1 document shape an empty document (nil) fails: an empty .anchor.yml checks nothing (Anchor.Domain.ConfigFailClosedTest)
     code:  assert {:error, {:invalid_config, reason}} = Config.parse_config(nil)
     left:  {:error, {:invalid_config, reason}}
     right: %Anchor.Config{rules: []}

 24) test parse_config/1 document shape an unknown top-level key fails (a typo such as `anchors:` for `rules:`) (Anchor.Domain.ConfigFailClosedTest)
     left:  {:error, {:invalid_config, reason}}
     right: %Anchor.Config{rules: []}

 40) test load/0 ... returns {:config_not_found, searched} when no candidate exists in the cwd (Anchor.Adapters.ConfigFileTest)
     code:  assert {:error, {:config_not_found, [searched]}} = ConfigFile.load()
     left:  {:error, {:config_not_found, [searched]}}
     right: {:ok, %Anchor.Config{rules: []}}

 46) test load/0 ... a config outside the computed candidates is reported, not read as empty (Anchor.Adapters.ConfigFileTest)
     left:  {:error, {:config_not_found, [searched]}}
     right: {:ok, %Anchor.Config{rules: []}}
```

Row 2 is a live bug the README shipped: its example says `mode: :separate`, and
YAML decodes `mode: :all` to the string `":all"`, which the old parser turned
into `:separate`.

## Mutations

Each mutation was applied alone, the whole suite run, and the file restored with
`git checkout`. Every one reddened at least one test.

| # | Mutation | Tests failed | Failure string (first failing row) |
|---|---|---|---|
| A | `parse_type/1`: an unknown type becomes `{:ok, String.to_atom(type)}` (the A8 defect) | 4 | `left: {:error, {:invalid_rule, reason}}` / `right: %Anchor.Config{` (rule 2 position row); e2e: `left: [issue]` / `right: []` |
| B | `parse_match/2`: an unknown token becomes `{:ok, :reference}` (the A9 defect) | 3 | `left: {:error, {:invalid_rule, _reason}}` / `right: %{ match: :reference,` |
| C | `parse_mode/2`: an unknown token becomes `{:ok, :separate}` | 2 | `left: {:error, {:invalid_rule, reason}}` / `right: %{ match: :reference,` (the rule map) |
| D | drop the leading-colon `parse_token/4` clause | 3 | `code: assert %{match: :call} = Config.parse_rule(%{"type" => "no_direct_dependency", "match" => ":call"})` / `right: {:error,`; also the README example row: `left: {:ok, %Anchor.Config{rules: rules}}` / `right: {:error,` |
| E | `fetch_rules/1`: no `rules` key gives `{:ok, []}` | 3 | `code: assert {:error, {:invalid_config, _reason}} = Config.parse_config(%{})` / `right: %Anchor.Config{rules: []}`; adapter empty-file row: `right: {:ok, %Anchor.Config{rules: []}}` |
| F | `validate_top_level_keys/1` accepts any key | 1 | `assert reason =~ ~s("anchors")` / `left: "the document has no \`rules:\` list"` / `right: "\"anchors\""` |
| G | `parse_config(nil)` returns `%Config{}` | 2 | `code: assert {:error, {:invalid_config, _reason}} = Config.parse_config(nil)` / `right: %Anchor.Config{rules: []}` |
| H | `ConfigFile.load/0`: no candidate gives `{:ok, %Config{}}` (the A6 defect) | 5 | `code: assert {:error, {:config_not_found, [searched]}} = ConfigFile.load()` / `right: {:ok, %Anchor.Config{rules: []}}`; e2e: `left: [issue]` / `right: []` |
| I | `ConfigPaths.candidates/2` accepts a relative cwd | 1 | `Expected exception ArgumentError but nothing was raised` / `code: assert_raise ArgumentError, ~r/absolute/, fn -> ConfigPaths.candidates("proj", false) end` |
| J | `ConfigFile.load/0` uses `File.regular?/1`, so a directory named `.anchor.yml` is skipped | 1 | `left: {:error, {:config_load_failed, path, {:read, :eisdir}}}` / `right: {:error, {:config_not_found, ["/tmp/anchor_cwd_4098/.anchor.yml"]}}` |
| V | `rule_type/1` interpolates a non-string type raw | 1 | `** (Protocol.UndefinedError) protocol String.Chars not implemented for Map.` / `code: Config.parse_rule(%{"type" => %{"x" => 1}, "same_context" => "yes"})` |

**V was first a measured zero.** Its first run: `530 tests, 0 failures` (before
the row existed, 529). No test fed a non-string `type` into an earlier
validation's message, so the crash path was unprotected. The row "a mapping as
the type fails with a reason, not a crash" was added, and V then reddened it
(the row above).

## Rows that stayed green, and why

- A mutation to the `type`/`match`/`mode` parse does not move the
  `same_context` rows (Gap F): those validate other keys, before the type parse.
- H does not move the `load_from_path/1` rows: they bypass the candidate search.

## Traps

- The first run of F, K, M and O reported `NO COUNT LINE`: the mutation left an
  unused variable or an unreachable clause, and `mix test` compiles with
  `--warnings-as-errors`. That is a compile failure, not a test failure. Each was
  rewritten to compile cleanly (for F, `|> Enum.take(0)` instead of `case []`)
  and re-run; the rows here are from the clean runs.
