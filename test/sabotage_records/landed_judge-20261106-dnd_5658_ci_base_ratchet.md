# Sabotage record: the landed judge after the merge of main, by the base's whole config (DND-5658)

- **Domain:** landed_judge
- **Branch:** dnd-5658-ci-base-ratchet
- **Date:** 2026-11-06
- **Code under test:** `Anchor.Managers.Graph` (`landed/3`, `read_base_config/4`), `Anchor.Config.judged/3`, `Anchor.Adapters.GitShow.config/3`
- **Suite run:** `mix test --force --timeout 2000 --max-cases 2` on the file named by each failure, through `test-slot`.

Each mutation edited the committed file; the runner restored it with `git checkout -- <file>`. Earlier runs: `landed_judge-20261103-dnd_5658_ci_base_ratchet.md`. Outside the judge the config now loads with `load/0`, as main calls it.

| # | Mutation | Tests, failed | Failure |
|---|---|---|---|
| L6 | re-run on `landed/3` after the merge: the Manager drops the landed judge's findings (`landed = Enum.take(Map.get(deps, :landed, []), 0)`) | 7, 3 failed | `the judge loads with unknown types set aside; a new type is a FIRST LANDING, exit 0`, `a base rule the change retypes fails: exit 1`, `a base rule the change removes fails: exit 1` |
| L14 | a base config the judge cannot read reads as nothing removed (`{:ok, config, Map.put(deps, :landed, [])}` in place of `{:could_not_check, ...}`) | 7, 1 failed | `a base config that cannot be read is COULD NOT MEASURE, never nothing removed` |
| L15 | the Manager judges under the change's sections (`%{config \| rules: LandedJudge.rules(...)}`, the critic's finding on 9e308e1) | 9, 1 failed | `a bucket floor the change lowers is judged by the base's architecture: exit 1` |
| L16 | `Config.judged/3` keeps the change's `architecture` | 7, 1 failed | `judged/3 every section is the base's; only the path and the set-aside rules are the change's` |
| L17 | `Config.judged/3` keeps the change's `aggregates` | 7, 1 failed | same test |
| L18 | `GitShow.config/3` drops every section but `rules` and `path` | 16, 1 failed | `config/3 (DND-5658) every section as committed at the ref, not the working copy` |
| L19 | a base config with no `architecture` is not refused (`architecture: :dnd_5658_never` in the clause's pattern) | 9, 1 failed | `a base config with no architecture is COULD NOT MEASURE, never a crash` |
| L20 | no config at the base reads as no `--base` (`if no_base == :absent, do: nil`) | 11, 1 failed | `no config at the base: the change's own rules run, each baseline a first landing` |
| L21 | no `--base` reads as no config at the base (`if no_base in [:absent, nil], do: {:ok, :absent}`) | 11, 1 failed | `without --base nothing is compared and no base is read` |
| L22 | no `--base` still asks git (`read_base_config`'s `nil` clause never matches) | 11, 1 failed | same test |
