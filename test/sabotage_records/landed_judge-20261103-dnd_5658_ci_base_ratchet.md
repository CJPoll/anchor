# Sabotage record: the landed judge's rule split (DND-5658, architect decision (a))

- **Domain:** landed_judge
- **Branch:** dnd-5658-ci-base-ratchet
- **Date:** 2026-11-03
- **Code under test:**
  - `Anchor.Config.parse_config/2` (`defer_unknown_types`)
  - `Anchor.Adapters.ConfigFile.load_judged/1`
  - `Anchor.Domain.LandedJudge.judge/5` and `rules/2` (critic round: every base rule runs as the base defines it)
  - `Anchor.Domain.GraphReport.Finding.note/2`
  - `Anchor.Managers.Graph` (`load_config/2`, `landed/3`, `read_base_config/4`; `Anchor.Config.judged/3`)
- **Suite run:** `mix test --timeout 2000 --max-cases 2 <files>` through `test-slot`, on the files each row names. The unmutated self-test passed T1-T12 in 355 s, and T1-T13 in 465 s after the critic round added `rules/2`. S11-S12 ran `bin/tests/base-judge-test.sh` with `BASE_JUDGE_TEST_ONLY`.

Each Elixir mutation was one exact text replacement, made in Python. Each run compiled and printed an ExUnit summary, and the file was then restored with `git checkout --` after the work was committed. `git status` was clean after the batch. The S rows mutated the working-tree copy, which the self-test copies into its throwaway repo as the base. That means the landed judge itself ran mutated.

Positive controls that stayed green under every mutation, and why:

- An unchanged base gives no failure and no note.
- An honest shrink of a base rule's baseline passes (`GraphLandedJudgeTest`).
- Outside the judge, the config loads with `load/0` (`load_in/1` until the merge of main at 48c6728, which went back to main's call so main's graph tests keep their stubs) and nothing is compared.

| # | Mutation | Tests | Failing tests |
|---|---|---|---|
| L1 | no rule is ever set aside (`split_deferred(rules, :never)`) | 22, 3 failed | `ConfigDeferredTest`: `an unknown rule type is set aside with its position, id, type and baseline`, `a set-aside rule with no id or baseline keeps nil for both`; `ConfigFileTest`: `load_judged/1 (DND-5658) sets an unknown rule type aside under the root; load_in/1 still refuses it` |
| L2 | every rule type is set aside, known ones too | 6, 3 failed | `ConfigDeferredTest`: `an unknown key on a known rule is still refused (the base cannot vouch for it)`, `an unknown rule type is set aside ...`, `a known rule is parsed as before: deferred is empty` |
| L3 | a removed base rule is not reported | 14, 3 failed | `LandedJudgeTest`: `a base rule the change removes fails, naming it`, `a base rule renamed is a removal (the new id is not a base rule)`; `GraphLandedJudgeTest`: `a base rule the change removes fails: exit 1` |
| L4 | a base rule retyped to a known type passes (`{:ok, _type} -> []`) | 14, 2 failed | `LandedJudgeTest`: `a base rule retyped to a type the judge knows fails`; `GraphLandedJudgeTest`: `a base rule the change retypes fails: exit 1` |
| L5 | a base rule retyped to a set-aside type is also given a FIRST LANDING note | 8, 1 failed | `LandedJudgeTest`: `a base rule retyped to a type the judge set aside fails, and is no first landing` |
| L6 | the Manager drops the landed judge's findings (run before the critic round renamed `landed_judge/3` to `landed/3`; Re-run on the merged `landed/3`, 2026-11-06: `landed = Enum.take(Map.get(deps, :landed, []), 0)`, 7 tests, 3 failed: `the judge loads with unknown types set aside; a new type is a FIRST LANDING, exit 0`, `a base rule the change retypes fails: exit 1`, `a base rule the change removes fails: exit 1`.) | 6, 4 failed | `GraphLandedJudgeTest`: removes, retypes, base config unreadable, FIRST LANDING |
| L7 | the Manager never loads with `load_judged/1` | 20, 6 failed | the four `GraphLandedJudgeTest` judge tests (`Mox.UnexpectedCallError` on `load_in/1`) and the two `--project` tests in `Mix.Tasks.Anchor.GraphTest` |
| L8 | `Finding.note/2` gives an `:enforce` finding | 8, 3 failed | `FindingNoteTest`: both tests; `GraphLandedJudgeTest`: `the judge loads with unknown types set aside; a new type is a FIRST LANDING, exit 0` |
| L9 | the judge reads no base config when no rule has a baseline | 6, 4 failed | `GraphLandedJudgeTest`: base config unreadable, retypes, removes, FIRST LANDING (`GitBase.rules/3` expected, not called) |
| L10 | `ConfigFile.load_judged/1` does not defer | 16, 1 failed | `ConfigFileTest`: `load_judged/1 (DND-5658) sets an unknown rule type aside ...` |
| L11 | the landed judge runs the change's rule definitions, not the base's (`rules/2` returns the change's rules); the first try left a variable unused and failed to compile, so that run does not count, and this re-run compiles | 18, 3 failed | `LandedJudgeTest`: `rules/2: what the landed judge runs a base rule the change narrows or downgrades runs as the base defines it`, `... an id-less rule runs once when the base has it as written, and is added when new`; `GraphLandedJudgeTest`: `a base rule the change downgrades and shrinks is judged as the base defines it: exit 1` |
| L12 | an id-less base rule is compared with its position, so the change's copy also runs | 11, 1 failed | `LandedJudgeTest`: `rules/2: what the landed judge runs an id-less rule runs once when the base has it as written, and is added when new` |
| L13 | the Manager does not swap in the base's definitions (`judged_rules/2`, since folded into `landed/3`, keeps the change's rules) | 7, 1 failed | `GraphLandedJudgeTest`: `a base rule the change downgrades and shrinks is judged as the base defines it: exit 1` |
| L14 | a base config the judge cannot read reads as nothing removed (`{:ok, config, Map.put(deps, :landed, [])}` in place of `{:could_not_check, ...}`, 2026-11-06) | 7, 1 failed | `a base config that cannot be read is COULD NOT MEASURE, never nothing removed` |
| L15 | the Manager judges under the change's sections (`%{config \| rules: LandedJudge.rules(...)}`, the critic's finding on 9e308e1) | 9, 1 failed | `a bucket floor the change lowers is judged by the base's architecture: exit 1` |
| L16 | `Config.judged/3` keeps the change's `architecture` | 7, 1 failed | `judged/3 every section is the base's; only the path and the set-aside rules are the change's` |
| L17 | `Config.judged/3` keeps the change's `aggregates` | 7, 1 failed | same test |
| L18 | `GitShow.config/3` drops every section but `rules` and `path` | 16, 1 failed | `config/3 (DND-5658) every section as committed at the ref, not the working copy` |
| L19 | a base config with no `architecture` is not refused (`architecture: :dnd_5658_never` in the clause's pattern) | 9, 1 failed | `a base config with no architecture is COULD NOT MEASURE, never a crash` |
| L20 | no config at the base reads as no `--base` (`if no_base == :absent, do: nil`) | 11, 1 failed | `no config at the base: the change's own rules run, each baseline a first landing` |
| L21 | no `--base` reads as no config at the base (`if no_base in [:absent, nil], do: {:ok, :absent}`) | 11, 1 failed | `without --base nothing is compared and no base is read` |
| L22 | no `--base` still asks git (`read_base_config`'s `nil` clause never matches) | 11, 1 failed | same test |
| S11 | the landed judge never sets a rule aside (L1, in the base copy) | self-test T7 | `FAIL T7 a rule type new in the pull request is a FIRST LANDING, not a refusal: exit 3, wanted 0` |
| S12 | the landed judge passes a removed base rule (L3, in the base copy) | self-test T11 | `FAIL T11 a removed base rule fails the landed judge: exit 0, wanted 1` |
| S13 | the landed judge runs the change's rule definitions (L13, in the base copy) | self-test T13 | `FAIL T13 a downgraded base rule is judged as the base defines it: exit 0, wanted 1` |

The verbatim run logs are at `ai-artifacts/coordination/2026-11-03-anchor-causal/logs/DND-5658/sab3/` and `shsab4/` in the custom repo (machine-local).
