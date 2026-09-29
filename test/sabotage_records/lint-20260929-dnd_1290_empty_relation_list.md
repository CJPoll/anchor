# Sabotage record — run-time "checked nothing" reports (DND-1290)

- **Domain:** lint
- **Branch:** dnd-1290-empty-relation-list
- **Date:** 2026-09-29
- **Code under test:** `Anchor.Managers.Lint.run/4`: the `{:config, violations}`
  entry, `floor_violations/4` (`enforce_selection_floors`),
  `unchecked_violations/2` (`report_shared_failures`, `enabled_rule_types`,
  `checks_by_type`), and `path_facts/1` for an unparseable file; end to end
  through `run_on_all_source_files/3`
- **Tests:** `test/anchor/managers/lint_test.exs`, the "a rule that checks
  nothing (DND-1290)" block of `test/anchor/e2e/checks_e2e_test.exs`, and one
  row of `test/anchor/integration/lint_composition_test.exs`
- **Suite run:** `mix test` (608 tests)
- **Merge base:** `origin/main` = 044f5ae; **fix commit:** d3f8a54
- **Primary record (same run):** `rule_schema-20260929-dnd_1290_empty_relation_list.md`

## Fail-first run (unfixed 044f5ae, plus `Config`'s `path: nil`)

```
 32) test run/4 selection floor (min_files) a rule that selects no file is one fail-closed violation on the config (Anchor.Managers.LintTest)
     match (=) failed
     code:  assert {:ok, [{^thing, []}, config: [violation]]} =
              Lint.run(MustUseModule, [thing], [], config_loader: ConfigLoaderMock)
     left:  {:ok, [{^thing, []}, config: [violation]]}

 35) test a rule that checks nothing (DND-1290) a relation-less rule is one issue on the config file (Anchor.E2E.ChecksE2ETest)
     code:  assert [issue] = issues
     left:  [issue]
     right: []

 36) test a rule that checks nothing (DND-1290) a rule whose check is not enabled is one issue on the config file (Anchor.E2E.ChecksE2ETest)
     code:  assert [issue] = issues
     left:  [issue]
     right: []
```

The e2e zero-files row first failed on its `id:` key (then unknown):
`left: "Anchor rejected /tmp/anchor_e2e_2053/.anchor.yml, so no Anchor rule was checked: rule 1: unknown key \"id\" in a no_direct_dependency rule; ..."`.
The Manager row above is the zero-files defect itself: a rule selecting no file
produced no entry.

## Existing rows changed

Two rows pinned the old behavior, "a rule that selects no file reads green":

- e2e "a file whose path the rule does not select produces no issues" now also
  passes a selected clean file, so the rule meets its floor and the row still
  tests selection.
- lint_composition "a uses_module rule does NOT select a file lacking that
  `use`" now also asserts the `{:config, [%Violation{kind: :fail_closed}]}`
  entry that the unselected run produces.

## Mutations

| # | Mutation | Tests failed | Failure string (first failing row) |
|---|---|---|---|
| M | the Manager ignores `enforce_selection_floors` | 2 | `a partial file set (enforce_selection_floors: false) reports no floor`: `code: assert {:ok, [{^thing, []}]} =` (and the e2e explicit-files row) |
| N | every check, not only the reporter, names an unchecked rule | 1 | `a non-reporter check does not name it`: `code: assert {:ok, [{^thing, []}]} =` |
| O | an unparseable file's path does not count toward the floor | 5 | `an unparseable file still counts toward a paths rule's floor`: `left: {:ok, [{^broken, [%Anchor.Domain.Violation{kind: :fail_closed}]}]}` / `right: {:ok,` |
