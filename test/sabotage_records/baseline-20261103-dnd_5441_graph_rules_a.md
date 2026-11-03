# Sabotage record — report, baseline, enforce (DND-5441)

- **Domain:** baseline
- **Branch:** dnd-5441-graph-rules-a
- **Date:** 2026-11-03
- **Code under test:** `Anchor.Domain.Baseline`, `Anchor.Domain.ViolationKey`, `Anchor.Domain.Enforcement`, `Anchor.Domain.RuleSchema` (the engine common keys, `enforcement`, `baseline`, `min_modules`, `bucket`, `validate_architecture/3`), `Anchor.Config` (`enforcement`), `Anchor.Managers.Lint` (report-mode detection), `Anchor.Check.Base` (report issue options), `Anchor.Managers.Graph` (the ratchet), `Anchor.Domain.GraphReport` (held, refused, verbose), `Anchor.Adapters.BaselineFile`, `Anchor.Adapters.GitShow`, `Mix.Tasks.Anchor.Graph` (`--base`, `--write-baseline`, `--verbose`)
- **Suite run:** each mutation ran `mix test --max-cases 2 <its test files>` inside one `test-slot`, by a driver that applied it, ran the files and restored the source; `git status` after the run showed only this branch's own uncommitted work, unchanged. Every row is red.

## Earlier driver pass, and what changed

Seven mutations of the first pass proved nothing and were re-shaped: VK-B added
a second clause the first always shadowed (green: a mutation that changed
nothing), and EN-A, MG-D, MG-F, AD-E and TK-B did not compile under
`--warnings-as-errors` (an unused variable, function or alias); GR-C did not
apply after `mix format` wrapped its line. Each row below is the re-shaped
mutation, red.

## Not covered here

`Anchor.Config`'s call of `RuleSchema.validate_architecture/3` at load needs a
graph rule type, and none ships in this ticket: the call is covered when the
first one does (DND-5442's `layering` table in `rule_checks_nothing_test.exs`).
`validate_architecture/3` itself is covered (RS-F, RS-G).

## Review-floor re-run (2026-11-03, on 637a6b7)

The review floor (ADR 003) found that the rows below gave only counts and test
names. Every mutation was re-run on 637a6b7, the head after the review-floor
fixes, by a driver that keeps each failing test's ExUnit block verbatim; the
table and the sections after it are that run. A mutation whose source text the
fixes changed was re-anchored to the same defect in the new code. A row marked
"regression" is the unfixed code itself, not a mutation: its block is quoted
from the run that showed it red before the fix, as the fix commit records it.
The checkout's absolute path in the output reads `<worktree>`. Each run
forced compilation (`mix test --force`, and a write never in the same second
as the last): a first pass of this re-run measured BL-C on BL-B's stale beam,
which the critic caught from its verbatim output.

| # | Mutation | Tests run | Result | Failing tests |
|---|---|---|---|---|
| BL-A | comment lines are kept as keys (`lib/anchor/domain/baseline.ex`) | `baseline_test.exs` | `15 tests, 2 failures` (red) | parse/1 keys in file order; comments, blank lines and trailing spaces dropped; render/2 header comment, keys sorted, trailing newline; parse round-trips to the sorted keys |
| BL-B | invalid UTF-8 is not detected (`lib/anchor/domain/baseline.ex`) | `baseline_test.exs`, `graph_baseline_test.exs` | `32 tests, 2 failures` (red) | parse/1 invalid UTF-8 on line 3 is refused, naming the line; run/2 comparing with a baseline a baseline line that is not UTF-8 is an issue on that line |
| BL-C | compare is a set, not a multiset: an entry is never consumed (`lib/anchor/domain/baseline.ex`) | `baseline_test.exs`, `enforcement_test.exs` | `23 tests, 8 failures` (red) | compare/2 a key found twice and listed once is one new; compare/2 a key listed twice and found once leaves one stale; compare/2 equal multisets: all held, none new or stale; judge/4 a baseline absent at the ref is a report-only first-landing NOTE; judge/4 a covered finding is held; an uncovered one (NEW) stands; judge/4 base entries: what the working file added is GREW, naming the ref; judge/4 positive control for GREW: the same files with nothing added give none; judge/4 two findings with one key and one entry: one held, one stands (multiset) |
| BL-D | grew never reports growth (`lib/anchor/domain/baseline.ex`) | `baseline_test.exs`, `enforcement_test.exs`, `graph_baseline_test.exs` | `40 tests, 4 failures` (red) | grew/2 a new key is growth; grew/2 one more copy of a key than base is that key once; judge/4 base entries: what the working file added is GREW, naming the ref; run/2 --base REF (GREW) an entry the branch added since REF fails as GREW (exit 1) |
| BL-E | foreign drops the \| so another id with the same prefix passes (`lib/anchor/domain/baseline.ex`) | `baseline_test.exs` | `15 tests, 1 failure` (red) | foreign/2 entries not starting with the rule id and \| are foreign |
| BL-F | render does not sort (`lib/anchor/domain/baseline.ex`) | `baseline_test.exs` | `15 tests, 1 failure` (red) | render/2 header comment, keys sorted, trailing newline; parse round-trips to the sorted keys |
| BL-G | a ref starting with - is valid (read as a git option) (`lib/anchor/domain/baseline.ex`) | `baseline_test.exs`, `git_show_test.exs`, `anchor_graph_test.exs` | `32 tests, 2 failures` (red) | a ref Anchor refuses never reaches git; valid_ref?/1 an option, a shell metacharacter, a space, empty or a non-string is refused |
| BL-H | any character is a ref character (`lib/anchor/domain/baseline.ex`) | `baseline_test.exs`, `git_show_test.exs`, `anchor_graph_test.exs` | `32 tests, 3 failures` (red) | a ref Anchor refuses never reaches git; an unknown flag, a bad format, an argument or a --base ref git must not see is usage: exit 2 with Fix:; valid_ref?/1 an option, a shell metacharacter, a space, empty or a non-string is refused |
| VK-A | a newline in a key segment is allowed (`lib/anchor/domain/violation_key.ex`) | `violation_key_test.exs` | `6 tests, 2 failures` (red) | graph_key/2 <id>\|<subject>, for a finding with no target; a newline raises; graph_key/3 a newline in any segment raises |
| VK-B | the key names the type even when the rule has an id (`lib/anchor/domain/violation_key.ex`) | `violation_key_test.exs` | `6 tests, 4 failures` (red) | graph_key/2 <id>\|<subject>, for a finding with no target; a newline raises; graph_key/3 <id>\|<subject>\|<detail>, the id when the rule has one, else its type; graph_key/3 a newline in any segment raises; graph_key/3 two violations differing only in line give the same key (no line in a key) |
| RS-A | any enforcement token is accepted (`lib/anchor/domain/rule_schema.ex`) | `rule_checks_nothing_test.exs` | `26 tests, 18 failures` (red) | alphabetized_functions: every rule that checks nothing is refused, and the positive rows load; case_on_bare_arg: every rule that checks nothing is refused, and the positive rows load; context_acyclic: every rule that checks nothing is refused, and the positive rows load; graph common keys: every rule that checks nothing is refused, the positive rows load; layering: every rule that checks nothing is refused, and the positive rows load; max_file_length: every rule that checks nothing is refused, and the positive rows load; module_pattern_restrictions: every rule that checks nothing is refused, and the positive rows load; must_use_module: every rule that checks nothing is refused, and the positive rows load; no_comparison_in_if: every rule that checks nothing is refused, and the positive rows load; no_direct_dependency: every rule that checks nothing is refused, and the positive rows load; no_discarded_pure_expression: every rule that checks nothing is refused, and the positive rows load; no_discarding_arrow_in_with: every rule that checks nothing is refused, and the positive rows load; no_forwarding_function: every rule that checks nothing is refused, and the positive rows load; no_transitive_dependency: every rule that checks nothing is refused, and the positive rows load; no_tuple_match_in_head: every rule that checks nothing is refused, and the positive rows load; single_control_flow: every rule that checks nothing is refused, and the positive rows load; struct_getter_convention: every rule that checks nothing is refused, and the positive rows load; struct_owned_by_module: every rule that checks nothing is refused, and the positive rows load |
| RS-B | a baseline without an id is accepted (`lib/anchor/domain/rule_schema.ex`) | `rule_checks_nothing_test.exs` | `26 tests, 3 failures` (red) | context_acyclic: every rule that checks nothing is refused, and the positive rows load; graph common keys: every rule that checks nothing is refused, the positive rows load; layering: every rule that checks nothing is refused, and the positive rows load |
| RS-C | a baseline path with .. is accepted (`lib/anchor/domain/rule_schema.ex`) | `rule_checks_nothing_test.exs` | `26 tests, 3 failures` (red) | context_acyclic: every rule that checks nothing is refused, and the positive rows load; graph common keys: every rule that checks nothing is refused, the positive rows load; layering: every rule that checks nothing is refused, and the positive rows load |
| RS-D | baseline on an ast rule is not refused (`lib/anchor/domain/rule_schema.ex`) | `rule_checks_nothing_test.exs` | `26 tests, 15 failures` (red) | alphabetized_functions: every rule that checks nothing is refused, and the positive rows load; case_on_bare_arg: every rule that checks nothing is refused, and the positive rows load; max_file_length: every rule that checks nothing is refused, and the positive rows load; module_pattern_restrictions: every rule that checks nothing is refused, and the positive rows load; must_use_module: every rule that checks nothing is refused, and the positive rows load; no_comparison_in_if: every rule that checks nothing is refused, and the positive rows load; no_direct_dependency: every rule that checks nothing is refused, and the positive rows load; no_discarded_pure_expression: every rule that checks nothing is refused, and the positive rows load; no_discarding_arrow_in_with: every rule that checks nothing is refused, and the positive rows load; no_forwarding_function: every rule that checks nothing is refused, and the positive rows load; no_transitive_dependency: every rule that checks nothing is refused, and the positive rows load; no_tuple_match_in_head: every rule that checks nothing is refused, and the positive rows load; single_control_flow: every rule that checks nothing is refused, and the positive rows load; struct_getter_convention: every rule that checks nothing is refused, and the positive rows load; struct_owned_by_module: every rule that checks nothing is refused, and the positive rows load |
| RS-E | min_modules 0 is accepted (`lib/anchor/domain/rule_schema.ex`) | `rule_checks_nothing_test.exs` | `26 tests, 3 failures` (red) | context_acyclic: every rule that checks nothing is refused, and the positive rows load; graph common keys: every rule that checks nothing is refused, the positive rows load; layering: every rule that checks nothing is refused, and the positive rows load |
| RS-F | a bucket naming no architecture bucket is accepted (`lib/anchor/domain/rule_schema.ex`) | `rule_schema_test.exs` | `33 tests, 1 failure` (red) | validate_architecture/3 a bucket naming no architecture bucket is refused, listing the buckets |
| RS-G | a graph rule with no architecture section is accepted (`lib/anchor/domain/rule_schema.ex`) | `rule_schema_test.exs` | `33 tests, 1 failure` (red) | validate_architecture/3 a graph rule with no architecture: section is refused |
| RS-H | graph selectors read as ast selectors (bucket is no selector) (`lib/anchor/domain/rule_schema.ex`) | `rule_checks_nothing_test.exs` | `26 tests, 3 failures` (red) | context_acyclic: every rule that checks nothing is refused, and the positive rows load; graph common keys: every rule that checks nothing is refused, the positive rows load; layering: every rule that checks nothing is refused, and the positive rows load |
| CF-A | enforcement is never parsed (always :enforce) (`lib/anchor/domain/config.ex`) | `rule_schema_test.exs` | `33 tests, 1 failure` (red) | enforcement/1 and parse_enforcement/1 a parsed rule carries its enforcement, enforce by default |
| LT-A | report rules' findings are not marked :report (`lib/anchor/managers/lint.ex`) | `lint_test.exs`, `base_test.exs` | `58 tests, 2 failures` (red) | check_file/3 enforcement: report a report rule's issue has exit_status 0 and low priority; run/4 enforcement: report a report rule's finding is :report; an enforced rule's beside it stays :enforce |
| BS-A | a report issue keeps a failing exit status (`lib/anchor/check/base.ex`) | `base_test.exs` | `28 tests, 1 failure` (red) | check_file/3 enforcement: report a report rule's issue has exit_status 0 and low priority |
| EN-A | held findings also stand (`lib/anchor/domain/enforcement.ex`) | `enforcement_test.exs`, `graph_baseline_test.exs` | `25 tests, 10 failures` (red) | judge/4 a baseline absent at the ref is a report-only first-landing NOTE; judge/4 a covered finding is held; an uncovered one (NEW) stands; judge/4 positive control for GREW: the same files with nothing added give none; judge/4 two findings with one key and one entry: one held, one stands (multiset); run/2 --base REF (GREW) a baseline absent at REF is a first landing: a NOTE, exit 0; run/2 --base REF (GREW) a baseline that only shrank since REF is not growth; run/2 --base REF (GREW) without --base, git is never asked; run/2 comparing with a baseline a baseline holding exactly the finding's key: exit 0, held, counted; run/2 comparing with a baseline a report rule's STALE entry is reported, never failing (exit 0); run/2 comparing with a baseline an entry no finding consumes is STALE, on the baseline path (exit 1) |
| EN-B | STALE entries are dropped (`lib/anchor/domain/enforcement.ex`) | `enforcement_test.exs`, `graph_baseline_test.exs` | `25 tests, 4 failures` (red) | judge/4 a report rule's STALE entry is :report; judge/4 an entry no finding consumes is a STALE finding on the baseline path; run/2 comparing with a baseline a report rule's STALE entry is reported, never failing (exit 0); run/2 comparing with a baseline an entry no finding consumes is STALE, on the baseline path (exit 1) |
| EN-C | a first landing fails (the NOTE is enforced) (`lib/anchor/domain/enforcement.ex`) | `enforcement_test.exs`, `graph_baseline_test.exs` | `25 tests, 2 failures` (red) | judge/4 a baseline absent at the ref is a report-only first-landing NOTE; run/2 --base REF (GREW) a baseline absent at REF is a first landing: a NOTE, exit 0 |
| MG-A | an existing baseline is overwritten: :exists read as written (`lib/anchor/managers/graph.ex`) | `graph_baseline_test.exs`, `anchor_graph_test.exs` | `25 tests, 2 failures` (red) | baseline flags --write-baseline over an existing file exits 2; run/2 --write-baseline RULE_ID an existing file is refused (exit 2), and the findings stand |
| MG-B | a failed read at --base is read as no growth (`lib/anchor/managers/graph.ex`) | `graph_baseline_test.exs` | `17 tests, 1 failure` (red) | run/2 --base REF (GREW) a failed read at REF is an issue naming the ref, never no growth (exit 1) |
| MG-C | a missing baseline holds nothing and is not reported (`lib/anchor/managers/graph.ex`) | `graph_baseline_test.exs` | `17 tests, 4 failures` (red) | run/2 --base REF (GREW) a failed read at REF is an issue naming the ref, never no growth (exit 1); run/2 comparing with a baseline a baseline holding another rule's entry is an issue; nothing is held; run/2 comparing with a baseline a baseline line that is not UTF-8 is an issue on that line; run/2 comparing with a baseline a missing baseline is an issue on its path; the finding stands (exit 1) |
| MG-D | --write-baseline naming no baselined rule is not refused (`lib/anchor/managers/graph.ex`) | `graph_baseline_test.exs` | `17 tests, 1 failure` (red) | run/2 --write-baseline RULE_ID an id naming no rule with a baseline is refused (exit 2) before any beam is read |
| MG-E | a rule's baseline is ignored (never compared) (`lib/anchor/managers/graph.ex`) | `graph_baseline_test.exs`, `anchor_graph_test.exs` | `25 tests, 18 failures` (red) | baseline flags --base REF reads the baseline at REF; a growth fails with GREW; baseline flags --write-baseline RULE_ID creates the file; held findings print with --verbose; baseline flags --write-baseline over an existing file exits 2; run/2 --base REF (GREW) a baseline absent at REF is a first landing: a NOTE, exit 0; run/2 --base REF (GREW) a baseline that only shrank since REF is not growth; run/2 --base REF (GREW) a failed read at REF is an issue naming the ref, never no growth (exit 1); run/2 --base REF (GREW) an entry the branch added since REF fails as GREW (exit 1); run/2 --base REF (GREW) without --base, git is never asked; run/2 --write-baseline RULE_ID an existing file is refused (exit 2), and the findings stand; run/2 --write-baseline RULE_ID creates the rule's baseline from its keys, sorted under the header; held, exit 0; run/2 comparing with a baseline a baseline holding another rule's entry is an issue; nothing is held; run/2 comparing with a baseline a baseline holding exactly the finding's key: exit 0, held, counted; run/2 comparing with a baseline a baseline line that is not UTF-8 is an issue on that line; run/2 comparing with a baseline a finding no entry covers is NEW: it stands and fails (exit 1); run/2 comparing with a baseline a missing baseline is an issue on its path; the finding stands (exit 1); run/2 comparing with a baseline a report rule's STALE entry is reported, never failing (exit 0); run/2 comparing with a baseline a rule with no baseline never reads one; run/2 comparing with a baseline an entry no finding consumes is STALE, on the baseline path (exit 1) |
| MG-F | another rule's entries are accepted (`lib/anchor/managers/graph.ex`) | `graph_baseline_test.exs`, `anchor_graph_test.exs` | `25 tests, 1 failure` (red) | run/2 comparing with a baseline a baseline holding another rule's entry is an issue; nothing is held |
| GR-A | a refusal is not exit 2 (`lib/anchor/domain/graph_report.ex`) | `graph_report_test.exs`, `graph_baseline_test.exs`, `anchor_graph_test.exs` | `39 tests, 5 failures` (red) | baseline flags --write-baseline over an existing file exits 2; held and refused JSON carries the refused and held findings; held and refused a refusal is exit 2; 3 still wins over it; held findings never fail; run/2 --write-baseline RULE_ID an existing file is refused (exit 2), and the findings stand; run/2 --write-baseline RULE_ID an id naming no rule with a baseline is refused (exit 2) before any beam is read |
| GR-B | the summary never counts held findings (`lib/anchor/domain/graph_report.ex`) | `graph_report_test.exs`, `graph_baseline_test.exs` | `31 tests, 2 failures` (red) | held and refused the summary counts held findings; refusals count as violations; run/2 comparing with a baseline a baseline holding exactly the finding's key: exit 0, held, counted |
| GR-C | held findings print without --verbose (`lib/anchor/domain/graph_report.ex`) | `graph_report_test.exs` | `14 tests, 1 failure` (red) | held and refused held findings print only with verbose: true |
| AD-A | create overwrites an existing file (`lib/anchor/adapters/baseline_file.ex`) | `baseline_file_test.exs` | `5 tests, 1 failure` (red) | create/3 on an existing file returns {:error, :exists} and leaves its bytes |
| AD-B | the path is not confined (`lib/anchor/adapters/baseline_file.ex`) | `baseline_file_test.exs` | `5 tests, 1 failure` (red) | an absolute path or a .. segment is refused before any file is touched |
| AD-C | a ref that does not resolve reads as an absent file (`lib/anchor/adapters/git_show.ex`) | `git_show_test.exs` | `9 tests, 2 failures` (red) | a ref that does not resolve is a git error, never :absent; no git on the PATH is a git error, never a crash |
| AD-D | the ref is not checked before git runs (`lib/anchor/adapters/git_show.ex`) | `git_show_test.exs` | `9 tests, 1 failure` (red) | a ref Anchor refuses never reaches git |
| AD-E | the working copy is read instead of the ref's (`lib/anchor/adapters/git_show.ex`) | `git_show_test.exs` | `9 tests, 2 failures` (red) | a committed file returns its bytes at the ref, not the working copy; an absolute path or a .. segment never reaches git |
| TK-A | --base never reaches the Manager (`lib/mix/tasks/anchor.graph.ex`) | `anchor_graph_test.exs` | `8 tests, 1 failure` (red) | baseline flags --base REF reads the baseline at REF; a growth fails with GREW |
| TK-B | --base is not checked (any ref passes to git) (`lib/mix/tasks/anchor.graph.ex`) | `anchor_graph_test.exs` | `8 tests, 1 failure` (red) | an unknown flag, a bad format, an argument or a --base ref git must not see is usage: exit 2 with Fix: |
| AD-G | a failed path probe at a resolved ref reads as absent (`lib/anchor/adapters/git_show.ex`) | `git_show_test.exs` | `9 tests, 1 failure` (red) | a path git cannot look up at a resolved ref is a git error, never :absent |
| AD-H | an absolute or .. path reaches git (`lib/anchor/adapters/git_show.ex`) | `git_show_test.exs` | `9 tests, 1 failure` (red) | an absolute path or a .. segment never reaches git |
| AD-I | no git on the PATH crashes (`lib/anchor/adapters/git_show.ex`) | `git_show_test.exs` | `9 tests, 1 failure` (red) | no git on the PATH is a git error, never a crash |
| AD-J | GitShow returns the bytes unparsed (`lib/anchor/adapters/git_show.ex`) | `git_show_test.exs` | `9 tests, 3 failures` (red) | a committed file returns its bytes at the ref, not the working copy; a line that is not UTF-8 at the ref is its error, naming the line; an absolute path or a .. segment never reaches git |
| AD-K | BaselineFile does not refuse a line that is not UTF-8 (`lib/anchor/adapters/baseline_file.ex`) | `baseline_file_test.exs` | `5 tests, 1 failure` (red) | read/2 parses: comments dropped, a line that is not UTF-8 refused |
| AD-F | regression: the existence probe was `git cat-file -e`, which printed git's fatal: line on every first landing (`lib/anchor/adapters/git_show.ex`) | `git_show_test.exs` | `5 tests, 1 failure` (red) | an absent file prints nothing: git's stderr never reaches the terminal |
| AD-L | regression (review floor on d9a61de): GitShow read a failed path probe as absent, returned raw bytes, and passed any path to git (`lib/anchor/adapters/git_show.ex`) | `git_show_test.exs`, `baseline_file_test.exs` | `13 tests, 4 failures` (red) | an absolute path or a .. segment never reaches git; a path git cannot look up at a resolved ref is a git error, never :absent; a line that is not UTF-8 at the ref is its error, naming the line |

## BL-A — comment lines are kept as keys

Run summary: `15 tests, 2 failures`

```text
  1) test parse/1 keys in file order; comments, blank lines and trailing spaces dropped (Anchor.Domain.BaselineTest)
     test/anchor/domain/baseline_test.exs:11
     Assertion with == failed
     code:  assert Baseline.parse(bytes) == {:ok, ["r|A|-> B", "r|C|-> D", "r|A|-> B"]}
     left:  {:ok,
             ["# anchor baseline for r; shrink only", "r|A|-> B",
              "# note", "r|C|-> D", "r|A|-> B"]}
     right: {:ok, ["r|A|-> B", "r|C|-> D", "r|A|-> B"]}
     stacktrace:
       test/anchor/domain/baseline_test.exs:13: (test)

  2) test render/2 header comment, keys sorted, trailing newline; parse round-trips to the sorted keys (Anchor.Domain.BaselineTest)
     test/anchor/domain/baseline_test.exs:72
     Assertion with == failed
     code:  assert Baseline.parse(rendered) == {:ok, ~w(r|a r|b r|b)}
     left:  {:ok, ["# anchor baseline for r; shrink only", "r|a", "r|b", "r|b"]}
     right: {:ok, ["r|a", "r|b", "r|b"]}
     stacktrace:
       test/anchor/domain/baseline_test.exs:75: (test)
```

## BL-B — invalid UTF-8 is not detected

Run summary: `32 tests, 2 failures`

```text
  1) test parse/1 invalid UTF-8 on line 3 is refused, naming the line (Anchor.Domain.BaselineTest)
     test/anchor/domain/baseline_test.exs:16
     Assertion with == failed
     code:  assert Baseline.parse("r|A\nr|B\nr|\xFF\n") == {:error, {:line, 3, :invalid_utf8}}
     left:  {:ok, ["r|A", "r|B", <<114, 124, 255>>]}
     right: {:error, {:line, 3, :invalid_utf8}}
     stacktrace:
       test/anchor/domain/baseline_test.exs:17: (test)

  2) test run/2 comparing with a baseline a baseline line that is not UTF-8 is an issue on that line (Anchor.Managers.GraphBaselineTest)
     test/anchor/managers/graph_baseline_test.exs:177
     match (=) failed
     code:  assert [%{key: @key}, %{file: @path, line: 2, message: message}] = report.findings
     left:  [
              %{key: "f|AnchorFixtures.GraphBaselineTest.User|found"},
              %{file: ".anchor/baselines/f.txt", line: 2, message: message}
            ]
     right: [
              %Anchor.Domain.GraphReport.Finding{
                rule_id: "f",
                type: :stub_finds,
                label: "rule 1 (id: \"f\", stub_finds)",
                enforcement: :enforce,
                key: "f|AnchorFixtures.GraphBaselineTest.User|found",
                file: "lib/my_app/domain/user.ex",
                line: 2,
                message: "AnchorFixtures.GraphBaselineTest.User was found. Fix: do not be found."
              },
              %Anchor.Domain.GraphReport.Finding{
                rule_id: nil,
                type: nil,
                label: "anchor.graph",
                enforcement: :enforce,
                key: nil,
                file: ".anchor/baselines/f.txt",
                line: nil,
                message: ".anchor/baselines/f.txt is the baseline of \"f\" but holds <<255>>, an entry of another rule, so it could not be compared. Fix: one baseline per rule; move that line to its own rule's baseline, or delete it."
              }
            ]
     stacktrace:
       test/anchor/managers/graph_baseline_test.exs:184: (test)
```

## BL-C — compare is a set, not a multiset: an entry is never consumed

Run summary: `23 tests, 8 failures`

```text
  1) test compare/2 a key listed twice and found once leaves one stale (Anchor.Domain.BaselineTest)
     test/anchor/domain/baseline_test.exs:30
     Assertion with == failed
     code:  assert Baseline.compare(~w(a), ~w(a a)) == %{new: [], stale: ~w(a), held: ~w(a)}
     left:  %{new: [], stale: ["a", "a"], held: ["a"]}
     right: %{new: [], stale: ["a"], held: ["a"]}
     stacktrace:
       test/anchor/domain/baseline_test.exs:31: (test)

  2) test compare/2 a key found twice and listed once is one new (Anchor.Domain.BaselineTest)
     test/anchor/domain/baseline_test.exs:34
     Assertion with == failed
     code:  assert Baseline.compare(~w(a a), ~w(a)) == %{new: ~w(a), stale: [], held: ~w(a)}
     left:  %{new: [], stale: ["a"], held: ["a", "a"]}
     right: %{new: ["a"], stale: [], held: ["a"]}
     stacktrace:
       test/anchor/domain/baseline_test.exs:35: (test)

  3) test compare/2 equal multisets: all held, none new or stale (Anchor.Domain.BaselineTest)
     test/anchor/domain/baseline_test.exs:26
     Assertion with == failed
     code:  assert Baseline.compare(~w(a b a), ~w(a a b)) == %{new: [], stale: [], held: ~w(a b a)}
     left:  %{new: [], stale: ["a", "a", "b"], held: ["a", "b", "a"]}
     right: %{new: [], stale: [], held: ["a", "b", "a"]}
     stacktrace:
       test/anchor/domain/baseline_test.exs:27: (test)

  4) test judge/4 a covered finding is held; an uncovered one (NEW) stands (Anchor.Domain.EnforcementTest)
     test/anchor/domain/enforcement_test.exs:33
     Assertion with == failed
     code:  assert Enum.map(standing, & &1.key) == ["r|B|y"]
     left:  ["r|B|y", "r|A|x"]
     right: ["r|B|y"]
     stacktrace:
       test/anchor/domain/enforcement_test.exs:38: (test)

  5) test judge/4 positive control for GREW: the same files with nothing added give none (Anchor.Domain.EnforcementTest)
     test/anchor/domain/enforcement_test.exs:82
     Assertion with == failed
     code:  assert standing == []
     left:  [
              %Anchor.Domain.GraphReport.Finding{
                rule_id: "r",
                type: :layering,
                label: "rule 1 (id: \"r\", layering)",
                enforcement: :enforce,
                key: "r|A|x",
                file: ".anchor/baselines/r.txt",
                line: nil,
                message: "r|A|x in .anchor/baselines/r.txt matches no finding (it was fixed). Fix: delete that line from .anchor/baselines/r.txt; a baseline only shrinks."
              }
            ]
     right: []
     stacktrace:
       test/anchor/domain/enforcement_test.exs:91: (test)

  6) test judge/4 base entries: what the working file added is GREW, naming the ref (Anchor.Domain.EnforcementTest)
     test/anchor/domain/enforcement_test.exs:67
     match (=) failed
     code:  assert [grew] = Enum.filter(standing, &(&1.file == @path))
     left:  [grew]
     right: [
              %Anchor.Domain.GraphReport.Finding{
                rule_id: "r",
                type: :layering,
                label: "rule 1 (id: \"r\", layering)",
                enforcement: :enforce,
                key: "r|A|x",
                file: ".anchor/baselines/r.txt",
                line: nil,
                message: "r|A|x in .anchor/baselines/r.txt matches no finding (it was fixed). Fix: delete that line from .anchor/baselines/r.txt; a baseline only shrinks."
              },
              %Anchor.Domain.GraphReport.Finding{
                rule_id: "r",
                type: :layering,
                label: "rule 1 (id: \"r\", layering)",
                enforcement: :enforce,
                key: "r|B|y",
                file: ".anchor/baselines/r.txt",
                line: nil,
                message: "r|B|y in .anchor/baselines/r.txt matches no finding (it was fixed). Fix: delete that line from .anchor/baselines/r.txt; a baseline only shrinks."
              },
              %Anchor.Domain.GraphReport.Finding{
                rule_id: "r",
                type: :layering,
                label: "rule 1 (id: \"r\", layering)",
                enforcement: :enforce,
                key: "r|B|y",
                file: ".anchor/baselines/r.txt",
                line: nil,
                message: "r|B|y was added to .anchor/baselines/r.txt since main. Fix: fix the finding instead; a baseline only shrinks (adding to it is a review decision on the base branch)."
              }
            ]
     ... (block cut at 40 lines)

  7) test judge/4 a baseline absent at the ref is a report-only first-landing NOTE (Anchor.Domain.EnforcementTest)
     test/anchor/domain/enforcement_test.exs:94
     ** (MatchError) no match of right hand side value:

         {[
            %Anchor.Domain.GraphReport.Finding{
              rule_id: "r",
              type: :layering,
              label: "rule 1 (id: \"r\", layering)",
              enforcement: :enforce,
              key: "r|A|x",
              file: ".anchor/baselines/r.txt",
              line: nil,
              message: "r|A|x in .anchor/baselines/r.txt matches no finding (it was fixed). Fix: delete that line from .anchor/baselines/r.txt; a baseline only shrinks."
            },
            %Anchor.Domain.GraphReport.Finding{
              rule_id: nil,
              type: nil,
              label: "anchor.graph",
              enforcement: :report,
              key: nil,
              file: ".anchor/baselines/r.txt",
              line: nil,
              message: "NOTE: first landing of .anchor/baselines/r.txt (absent at main); review is the gate. Fix: review every line of .anchor/baselines/r.txt in this change; from here it only shrinks."
            }
          ],
          [
            %Anchor.Domain.GraphReport.Finding{
              rule_id: "r",
              type: :layering,
              label: "rule 1 (id: \"r\", layering)",
              enforcement: :enforce,
              key: "r|A|x",
              file: "lib/a.ex",
              line: 3,
              message: "r|A|x found. Fix: do not."
            }
     ... (block cut at 40 lines)

  8) test judge/4 two findings with one key and one entry: one held, one stands (multiset) (Anchor.Domain.EnforcementTest)
     test/anchor/domain/enforcement_test.exs:56
     Expected truthy, got false
     code: assert length(standing) == 1 and length(held) == 1
     stacktrace:
       test/anchor/domain/enforcement_test.exs:60: (test)
```

## BL-D — grew never reports growth

Run summary: `40 tests, 4 failures`

```text
  1) test grew/2 one more copy of a key than base is that key once (Anchor.Domain.BaselineTest)
     test/anchor/domain/baseline_test.exs:49
     Assertion with == failed
     code:  assert Baseline.grew(~w(a a b), ~w(a b)) == ~w(a)
     left:  []
     right: ["a"]
     stacktrace:
       test/anchor/domain/baseline_test.exs:50: (test)

  2) test grew/2 a new key is growth (Anchor.Domain.BaselineTest)
     test/anchor/domain/baseline_test.exs:57
     Assertion with == failed
     code:  assert Baseline.grew(~w(a c), ~w(a)) == ~w(c)
     left:  []
     right: ["c"]
     stacktrace:
       test/anchor/domain/baseline_test.exs:58: (test)

  3) test judge/4 base entries: what the working file added is GREW, naming the ref (Anchor.Domain.EnforcementTest)
     test/anchor/domain/enforcement_test.exs:67
     match (=) failed
     code:  assert [grew] = Enum.filter(standing, &(&1.file == @path))
     left:  [grew]
     right: []
     stacktrace:
       test/anchor/domain/enforcement_test.exs:76: (test)

  4) test run/2 --base REF (GREW) an entry the branch added since REF fails as GREW (exit 1) (Anchor.Managers.GraphBaselineTest)
     test/anchor/managers/graph_baseline_test.exs:218
     match (=) failed
     code:  assert [%{file: @path, key: "f|Added|found", enforcement: :enforce}] = grew
     left:  [%{file: ".anchor/baselines/f.txt", key: "f|Added|found", enforcement: :enforce}]
     right: []
     stacktrace:
       test/anchor/managers/graph_baseline_test.exs:227: (test)
```

## BL-E — foreign drops the | so another id with the same prefix passes

Run summary: `15 tests, 1 failure`

```text
  1) test foreign/2 entries not starting with the rule id and | are foreign (Anchor.Domain.BaselineTest)
     test/anchor/domain/baseline_test.exs:63
     Assertion with == failed
     code:  assert Baseline.foreign("web", ["web|A|x", "webx|A|x", "other|B|y"]) == ["webx|A|x", "other|B|y"]
     left:  ["other|B|y"]
     right: ["webx|A|x", "other|B|y"]
     stacktrace:
       test/anchor/domain/baseline_test.exs:64: (test)
```

## BL-F — render does not sort

Run summary: `15 tests, 1 failure`

```text
  1) test render/2 header comment, keys sorted, trailing newline; parse round-trips to the sorted keys (Anchor.Domain.BaselineTest)
     test/anchor/domain/baseline_test.exs:72
     Assertion with == failed
     code:  assert rendered == "# anchor baseline for r; shrink only\nr|a\nr|b\nr|b\n"
     left:  "# anchor baseline for r; shrink only\nr|b\nr|a\nr|b\n"
     right: "# anchor baseline for r; shrink only\nr|a\nr|b\nr|b\n"
     stacktrace:
       test/anchor/domain/baseline_test.exs:74: (test)
```

## BL-G — a ref starting with - is valid (read as a git option)

Run summary: `32 tests, 2 failures`

```text
  1) test valid_ref?/1 an option, a shell metacharacter, a space, empty or a non-string is refused (Anchor.Domain.BaselineTest)
     test/anchor/domain/baseline_test.exs:86
     "-x"
     code: for ref <- ["-x", "--output=/tmp/x", "main; rm -rf /", "a b", "a$b", "a:b", "", nil, 1] do
     stacktrace:
       test/anchor/domain/baseline_test.exs:88: anonymous fn/2 in Anchor.Domain.BaselineTest."test valid_ref?/1 an option, a shell metacharacter, a space, empty or a non-string is refused"/1
       (elixir 1.19.4) lib/enum.ex:2520: Enum."-reduce/3-lists^foldl/2-0-"/3
       test/anchor/domain/baseline_test.exs:87: (test)

  2) test a ref Anchor refuses never reaches git (Anchor.Adapters.GitShowTest)
     test/anchor/adapters/git_show_test.exs:129
     Assertion with == failed
     code:  assert GitShow.show(root, "--output=/tmp/x", ".anchor/baselines/r.txt") == {:error, :bad_ref}
     left:  {:error, {:git, 1, ""}}
     right: {:error, :bad_ref}
     stacktrace:
       test/anchor/adapters/git_show_test.exs:134: (test)
```

## BL-H — any character is a ref character

Run summary: `32 tests, 3 failures`

```text
  1) test valid_ref?/1 an option, a shell metacharacter, a space, empty or a non-string is refused (Anchor.Domain.BaselineTest)
     test/anchor/domain/baseline_test.exs:86
     "main; rm -rf /"
     code: for ref <- ["-x", "--output=/tmp/x", "main; rm -rf /", "a b", "a$b", "a:b", "", nil, 1] do
     stacktrace:
       test/anchor/domain/baseline_test.exs:88: anonymous fn/2 in Anchor.Domain.BaselineTest."test valid_ref?/1 an option, a shell metacharacter, a space, empty or a non-string is refused"/1
       (elixir 1.19.4) lib/enum.ex:2520: Enum."-reduce/3-lists^foldl/2-0-"/3
       test/anchor/domain/baseline_test.exs:87: (test)

  2) test a ref Anchor refuses never reaches git (Anchor.Adapters.GitShowTest)
     test/anchor/adapters/git_show_test.exs:129
     Assertion with == failed
     code:  assert GitShow.show(root, "main; rm -rf /", ".anchor/baselines/r.txt") == {:error, :bad_ref}
     left:  {:error, {:git, 1, ""}}
     right: {:error, :bad_ref}
     stacktrace:
       test/anchor/adapters/git_show_test.exs:133: (test)

  3) test an unknown flag, a bad format, an argument or a --base ref git must not see is usage: exit 2 with Fix: (Mix.Tasks.Anchor.GraphTest)
     test/mix/tasks/anchor_graph_test.exs:135
     ** (Mox.UnexpectedCallError) no expectation defined for Anchor.ConfigLoaderMock.load/0 in process #PID<0.1110.0> with args []
     code: for argv <- [
     stacktrace:
       (mox 1.2.0) lib/mox.ex:903: Mox.__dispatch__/4
       (anchor 0.1.0) lib/anchor/managers/graph.ex:134: Anchor.Managers.Graph.load_config/1
       (anchor 0.1.0) lib/anchor/managers/graph.ex:87: Anchor.Managers.Graph.run/2
       (anchor 0.1.0) lib/mix/tasks/anchor.graph.ex:113: Mix.Tasks.Anchor.Graph.run_parsed/2
       test/mix/tasks/anchor_graph_test.exs:145: anonymous fn/1 in Mix.Tasks.Anchor.GraphTest."test an unknown flag, a bad format, an argument or a --base ref git must not see is usage: exit 2 with Fix:"/1
       (ex_unit 1.19.4) lib/ex_unit/capture_io.ex:296: ExUnit.CaptureIO.do_with_io/3
       (ex_unit 1.19.4) lib/ex_unit/capture_io.ex:166: ExUnit.CaptureIO.capture_io/2
       test/mix/tasks/anchor_graph_test.exs:144: anonymous fn/2 in Mix.Tasks.Anchor.GraphTest."test an unknown flag, a bad format, an argument or a --base ref git must not see is usage: exit 2 with Fix:"/1
       (elixir 1.19.4) lib/enum.ex:2520: Enum."-reduce/3-lists^foldl/2-0-"/3
       test/mix/tasks/anchor_graph_test.exs:136: (test)
```

## VK-A — a newline in a key segment is allowed

Run summary: `6 tests, 2 failures`

```text
  1) test graph_key/3 a newline in any segment raises (Anchor.Domain.ViolationKeyTest)
     test/anchor/domain/violation_key_test.exs:19
     Expected exception ArgumentError but nothing was raised
     code: for {subject, detail} <- [{"A\n", "d"}, {"A", "d\r"}] do
     stacktrace:
       test/anchor/domain/violation_key_test.exs:21: anonymous fn/2 in Anchor.Domain.ViolationKeyTest."test graph_key/3 a newline in any segment raises"/1
       (elixir 1.19.4) lib/enum.ex:2520: Enum."-reduce/3-lists^foldl/2-0-"/3
       test/anchor/domain/violation_key_test.exs:20: (test)

  2) test graph_key/2 <id>|<subject>, for a finding with no target; a newline raises (Anchor.Domain.ViolationKeyTest)
     test/anchor/domain/violation_key_test.exs:48
     Expected exception ArgumentError but nothing was raised
     code: assert_raise ArgumentError, fn -> ViolationKey.graph_key(%{type: :t}, "A\nB") end
     stacktrace:
       test/anchor/domain/violation_key_test.exs:51: (test)
```

## VK-B — the key names the type even when the rule has an id

Run summary: `6 tests, 4 failures`

```text
  1) test graph_key/2 <id>|<subject>, for a finding with no target; a newline raises (Anchor.Domain.ViolationKeyTest)
     test/anchor/domain/violation_key_test.exs:48
     Assertion with == failed
     code:  assert ViolationKey.graph_key(%{type: :context_acyclic, id: "c"}, "A,B") == "c|A,B"
     left:  "context_acyclic|A,B"
     right: "c|A,B"
     stacktrace:
       test/anchor/domain/violation_key_test.exs:50: (test)

  2) test graph_key/3 a newline in any segment raises (Anchor.Domain.ViolationKeyTest)
     test/anchor/domain/violation_key_test.exs:19
     Expected exception ArgumentError but nothing was raised
     code: assert_raise ArgumentError, fn ->
     stacktrace:
       test/anchor/domain/violation_key_test.exs:26: (test)

  3) test graph_key/3 two violations differing only in line give the same key (no line in a key) (Anchor.Domain.ViolationKeyTest)
     test/anchor/domain/violation_key_test.exs:31
     Assertion with == failed
     code:  assert violation.key == "r|A.f/1|-> B.g/0"
     left:  "layering|A.f/1|-> B.g/0"
     right: "r|A.f/1|-> B.g/0"
     stacktrace:
       test/anchor/domain/violation_key_test.exs:41: anonymous fn/1 in Anchor.Domain.ViolationKeyTest."test graph_key/3 two violations differing only in line give the same key (no line in a key)"/1
       (elixir 1.19.4) lib/enum.ex:1688: Enum."-map/2-lists^map/1-1-"/2
       test/anchor/domain/violation_key_test.exs:34: (test)

  4) test graph_key/3 <id>|<subject>|<detail>, the id when the rule has one, else its type (Anchor.Domain.ViolationKeyTest)
     test/anchor/domain/violation_key_test.exs:11
     Assertion with == failed
     code:  assert ViolationKey.graph_key(%{type: :layering, id: "web"}, "A.f/1", "-> B.g/0") == "web|A.f/1|-> B.g/0"
     left:  "layering|A.f/1|-> B.g/0"
     right: "web|A.f/1|-> B.g/0"
     stacktrace:
       test/anchor/domain/violation_key_test.exs:12: (test)
```

## RS-A — any enforcement token is accepted

Run summary: `26 tests, 18 failures`

```text
  1) test no_forwarding_function: every rule that checks nothing is refused, and the positive rows load (Anchor.Domain.RuleChecksNothingTest)
     test/anchor/domain/rule_checks_nothing_test.exs:46
     no_forwarding_function / enforcement: warn (neither): RAISED: key "warn" not found in:
     code: assert failures == [], Enum.join(failures, "\n")
     stacktrace:
       test/anchor/domain/rule_checks_nothing_test.exs:52: (test)

  2) test must_use_module: every rule that checks nothing is refused, and the positive rows load (Anchor.Domain.RuleChecksNothingTest)
     test/anchor/domain/rule_checks_nothing_test.exs:46
     must_use_module / enforcement: warn (neither): RAISED: key "warn" not found in:
     code: assert failures == [], Enum.join(failures, "\n")
     stacktrace:
       test/anchor/domain/rule_checks_nothing_test.exs:52: (test)

  3) test max_file_length: every rule that checks nothing is refused, and the positive rows load (Anchor.Domain.RuleChecksNothingTest)
     test/anchor/domain/rule_checks_nothing_test.exs:46
     max_file_length / enforcement: warn (neither): RAISED: key "warn" not found in:
     code: assert failures == [], Enum.join(failures, "\n")
     stacktrace:
       test/anchor/domain/rule_checks_nothing_test.exs:52: (test)

  4) test alphabetized_functions: every rule that checks nothing is refused, and the positive rows load (Anchor.Domain.RuleChecksNothingTest)
     test/anchor/domain/rule_checks_nothing_test.exs:46
     alphabetized_functions / enforcement: warn (neither): RAISED: key "warn" not found in:
     code: assert failures == [], Enum.join(failures, "\n")
     stacktrace:
       test/anchor/domain/rule_checks_nothing_test.exs:52: (test)

  5) test no_discarding_arrow_in_with: every rule that checks nothing is refused, and the positive rows load (Anchor.Domain.RuleChecksNothingTest)
     test/anchor/domain/rule_checks_nothing_test.exs:46
     no_discarding_arrow_in_with / enforcement: warn (neither): RAISED: key "warn" not found in:
     code: assert failures == [], Enum.join(failures, "\n")
     stacktrace:
       test/anchor/domain/rule_checks_nothing_test.exs:52: (test)

  6) test no_direct_dependency: every rule that checks nothing is refused, and the positive rows load (Anchor.Domain.RuleChecksNothingTest)
     test/anchor/domain/rule_checks_nothing_test.exs:46
     no_direct_dependency / enforcement: warn (neither): RAISED: key "warn" not found in:
     code: assert failures == [], Enum.join(failures, "\n")
     stacktrace:
       test/anchor/domain/rule_checks_nothing_test.exs:52: (test)

  7) test layering: every rule that checks nothing is refused, and the positive rows load (Anchor.Domain.RuleChecksNothingTest)
     test/anchor/domain/rule_checks_nothing_test.exs:46
     layering / enforcement: warn: RAISED: key "warn" not found in:
     code: assert failures == [], Enum.join(failures, "\n")
     stacktrace:
       test/anchor/domain/rule_checks_nothing_test.exs:52: (test)

  8) test case_on_bare_arg: every rule that checks nothing is refused, and the positive rows load (Anchor.Domain.RuleChecksNothingTest)
     test/anchor/domain/rule_checks_nothing_test.exs:46
     case_on_bare_arg / enforcement: warn (neither): RAISED: key "warn" not found in:
     code: assert failures == [], Enum.join(failures, "\n")
     stacktrace:
       test/anchor/domain/rule_checks_nothing_test.exs:52: (test)

  9) test single_control_flow: every rule that checks nothing is refused, and the positive rows load (Anchor.Domain.RuleChecksNothingTest)
     test/anchor/domain/rule_checks_nothing_test.exs:46
     single_control_flow / enforcement: warn (neither): RAISED: key "warn" not found in:
     code: assert failures == [], Enum.join(failures, "\n")
     stacktrace:
       test/anchor/domain/rule_checks_nothing_test.exs:52: (test)

 10) test struct_getter_convention: every rule that checks nothing is refused, and the positive rows load (Anchor.Domain.RuleChecksNothingTest)
     test/anchor/domain/rule_checks_nothing_test.exs:46
     struct_getter_convention / enforcement: warn (neither): RAISED: key "warn" not found in:
     code: assert failures == [], Enum.join(failures, "\n")
     stacktrace:
       test/anchor/domain/rule_checks_nothing_test.exs:52: (test)

 11) test no_tuple_match_in_head: every rule that checks nothing is refused, and the positive rows load (Anchor.Domain.RuleChecksNothingTest)
     test/anchor/domain/rule_checks_nothing_test.exs:46
     no_tuple_match_in_head / enforcement: warn (neither): RAISED: key "warn" not found in:
     code: assert failures == [], Enum.join(failures, "\n")
     stacktrace:
       test/anchor/domain/rule_checks_nothing_test.exs:52: (test)

 12) test module_pattern_restrictions: every rule that checks nothing is refused, and the positive rows load (Anchor.Domain.RuleChecksNothingTest)
     test/anchor/domain/rule_checks_nothing_test.exs:46
     module_pattern_restrictions / enforcement: warn (neither): RAISED: key "warn" not found in:
     code: assert failures == [], Enum.join(failures, "\n")
     stacktrace:
       test/anchor/domain/rule_checks_nothing_test.exs:52: (test)

 13) test no_comparison_in_if: every rule that checks nothing is refused, and the positive rows load (Anchor.Domain.RuleChecksNothingTest)
     test/anchor/domain/rule_checks_nothing_test.exs:46
     no_comparison_in_if / enforcement: warn (neither): RAISED: key "warn" not found in:
     code: assert failures == [], Enum.join(failures, "\n")
     stacktrace:
       test/anchor/domain/rule_checks_nothing_test.exs:52: (test)

 14) test struct_owned_by_module: every rule that checks nothing is refused, and the positive rows load (Anchor.Domain.RuleChecksNothingTest)
     test/anchor/domain/rule_checks_nothing_test.exs:46
     struct_owned_by_module / enforcement: warn (neither): RAISED: key "warn" not found in:
     code: assert failures == [], Enum.join(failures, "\n")
     stacktrace:
       test/anchor/domain/rule_checks_nothing_test.exs:52: (test)

 15) test no_discarded_pure_expression: every rule that checks nothing is refused, and the positive rows load (Anchor.Domain.RuleChecksNothingTest)
     test/anchor/domain/rule_checks_nothing_test.exs:46
     no_discarded_pure_expression / enforcement: warn (neither): RAISED: key "warn" not found in:
     code: assert failures == [], Enum.join(failures, "\n")
     stacktrace:
       test/anchor/domain/rule_checks_nothing_test.exs:52: (test)

 16) test graph common keys: every rule that checks nothing is refused, the positive rows load (Anchor.Domain.RuleChecksNothingTest)
     test/anchor/domain/rule_checks_nothing_test.exs:182
     enforcement: warn: :ok
     code: assert failures == [], Enum.join(failures, "\n")
     stacktrace:
       test/anchor/domain/rule_checks_nothing_test.exs:201: (test)

 17) test no_transitive_dependency: every rule that checks nothing is refused, and the positive rows load (Anchor.Domain.RuleChecksNothingTest)
     test/anchor/domain/rule_checks_nothing_test.exs:46
     no_transitive_dependency / enforcement: warn (neither): RAISED: key "warn" not found in:
     code: assert failures == [], Enum.join(failures, "\n")
     stacktrace:
       test/anchor/domain/rule_checks_nothing_test.exs:52: (test)

 18) test context_acyclic: every rule that checks nothing is refused, and the positive rows load (Anchor.Domain.RuleChecksNothingTest)
     test/anchor/domain/rule_checks_nothing_test.exs:46
     context_acyclic / enforcement: warn: RAISED: key "warn" not found in:
     code: assert failures == [], Enum.join(failures, "\n")
     stacktrace:
       test/anchor/domain/rule_checks_nothing_test.exs:52: (test)
```

## RS-B — a baseline without an id is accepted

Run summary: `26 tests, 3 failures`

```text
  1) test layering: every rule that checks nothing is refused, and the positive rows load (Anchor.Domain.RuleChecksNothingTest)
     test/anchor/domain/rule_checks_nothing_test.exs:46
     layering / baseline without id (entries start with it): LOADED: %Anchor.Config{rules: [%{id: nil, index: 1, ...}], ...}
     code: assert failures == [], Enum.join(failures, "\n")
     stacktrace:
       test/anchor/domain/rule_checks_nothing_test.exs:52: (test)

  2) test graph common keys: every rule that checks nothing is refused, the positive rows load (Anchor.Domain.RuleChecksNothingTest)
     test/anchor/domain/rule_checks_nothing_test.exs:182
     baseline without id (entries start with it): :ok
     code: assert failures == [], Enum.join(failures, "\n")
     stacktrace:
       test/anchor/domain/rule_checks_nothing_test.exs:201: (test)

  3) test context_acyclic: every rule that checks nothing is refused, and the positive rows load (Anchor.Domain.RuleChecksNothingTest)
     test/anchor/domain/rule_checks_nothing_test.exs:46
     context_acyclic / baseline without id (entries start with it): LOADED: %Anchor.Config{rules: [%{id: nil, index: 1, ...}], ...}
     code: assert failures == [], Enum.join(failures, "\n")
     stacktrace:
       test/anchor/domain/rule_checks_nothing_test.exs:52: (test)
```

## RS-C — a baseline path with .. is accepted

Run summary: `26 tests, 3 failures`

```text
  1) test graph common keys: every rule that checks nothing is refused, the positive rows load (Anchor.Domain.RuleChecksNothingTest)
     test/anchor/domain/rule_checks_nothing_test.exs:182
     a baseline path climbing out: :ok
     a baseline path with an inner ..: :ok
     code: assert failures == [], Enum.join(failures, "\n")
     stacktrace:
       test/anchor/domain/rule_checks_nothing_test.exs:201: (test)

  2) test context_acyclic: every rule that checks nothing is refused, and the positive rows load (Anchor.Domain.RuleChecksNothingTest)
     test/anchor/domain/rule_checks_nothing_test.exs:46
     context_acyclic / a baseline path climbing out: LOADED: %Anchor.Config{rules: [%{id: "r", index: 1, ...}], ...}
     context_acyclic / a baseline path with an inner ..: LOADED: %Anchor.Config{rules: [%{id: "r", index: 1, ...}], ...}
     code: assert failures == [], Enum.join(failures, "\n")
     stacktrace:
       test/anchor/domain/rule_checks_nothing_test.exs:52: (test)

  3) test layering: every rule that checks nothing is refused, and the positive rows load (Anchor.Domain.RuleChecksNothingTest)
     test/anchor/domain/rule_checks_nothing_test.exs:46
     layering / a baseline path climbing out: LOADED: %Anchor.Config{rules: [%{id: "r", index: 1, ...}], ...}
     layering / a baseline path with an inner ..: LOADED: %Anchor.Config{rules: [%{id: "r", index: 1, ...}], ...}
     code: assert failures == [], Enum.join(failures, "\n")
     stacktrace:
       test/anchor/domain/rule_checks_nothing_test.exs:52: (test)
```

## RS-D — baseline on an ast rule is not refused

Run summary: `26 tests, 15 failures`

```text
  1) test no_tuple_match_in_head: every rule that checks nothing is refused, and the positive rows load (Anchor.Domain.RuleChecksNothingTest)
     test/anchor/domain/rule_checks_nothing_test.exs:46
     no_tuple_match_in_head / baseline on an ast rule (nothing reads it): wrong reason (want "`baseline` is read by graph rules only"): rule 1: unknown key "baseline" in a no_tuple_match_in_head rule (`baseline` applies to graph rules only); known keys for no_tuple_match_in_head: enforcement, id, min_files, paths, pattern, recursive, type, uses_module
     code: assert failures == [], Enum.join(failures, "\n")
     stacktrace:
       test/anchor/domain/rule_checks_nothing_test.exs:52: (test)

  2) test single_control_flow: every rule that checks nothing is refused, and the positive rows load (Anchor.Domain.RuleChecksNothingTest)
     test/anchor/domain/rule_checks_nothing_test.exs:46
     single_control_flow / baseline on an ast rule (nothing reads it): wrong reason (want "`baseline` is read by graph rules only"): rule 1: unknown key "baseline" in a single_control_flow rule (`baseline` applies to graph rules only); known keys for single_control_flow: enforcement, id, min_files, paths, pattern, recursive, type, uses_module
     code: assert failures == [], Enum.join(failures, "\n")
     stacktrace:
       test/anchor/domain/rule_checks_nothing_test.exs:52: (test)

  3) test struct_getter_convention: every rule that checks nothing is refused, and the positive rows load (Anchor.Domain.RuleChecksNothingTest)
     test/anchor/domain/rule_checks_nothing_test.exs:46
     struct_getter_convention / baseline on an ast rule (nothing reads it): wrong reason (want "`baseline` is read by graph rules only"): rule 1: unknown key "baseline" in a struct_getter_convention rule (`baseline` applies to graph rules only); known keys for struct_getter_convention: enforcement, id, min_files, paths, pattern, recursive, type, uses_module
     code: assert failures == [], Enum.join(failures, "\n")
     stacktrace:
       test/anchor/domain/rule_checks_nothing_test.exs:52: (test)

  4) test no_discarded_pure_expression: every rule that checks nothing is refused, and the positive rows load (Anchor.Domain.RuleChecksNothingTest)
     test/anchor/domain/rule_checks_nothing_test.exs:46
     no_discarded_pure_expression / baseline on an ast rule (nothing reads it): wrong reason (want "`baseline` is read by graph rules only"): rule 1: unknown key "baseline" in a no_discarded_pure_expression rule (`baseline` applies to graph rules only); known keys for no_discarded_pure_expression: enforcement, id, min_files, paths, pattern, pure_patterns, recursive, type, uses_module
     code: assert failures == [], Enum.join(failures, "\n")
     stacktrace:
       test/anchor/domain/rule_checks_nothing_test.exs:52: (test)

  5) test alphabetized_functions: every rule that checks nothing is refused, and the positive rows load (Anchor.Domain.RuleChecksNothingTest)
     test/anchor/domain/rule_checks_nothing_test.exs:46
     alphabetized_functions / baseline on an ast rule (nothing reads it): wrong reason (want "`baseline` is read by graph rules only"): rule 1: unknown key "baseline" in a alphabetized_functions rule (`baseline` applies to graph rules only); known keys for alphabetized_functions: enforcement, id, min_files, mode, paths, pattern, recursive, type, uses_module
     code: assert failures == [], Enum.join(failures, "\n")
     stacktrace:
       test/anchor/domain/rule_checks_nothing_test.exs:52: (test)

  6) test no_forwarding_function: every rule that checks nothing is refused, and the positive rows load (Anchor.Domain.RuleChecksNothingTest)
     test/anchor/domain/rule_checks_nothing_test.exs:46
     no_forwarding_function / baseline on an ast rule (nothing reads it): wrong reason (want "`baseline` is read by graph rules only"): rule 1: unknown key "baseline" in a no_forwarding_function rule (`baseline` applies to graph rules only); known keys for no_forwarding_function: enforcement, id, min_files, paths, pattern, recursive, type, uses_module
     code: assert failures == [], Enum.join(failures, "\n")
     stacktrace:
       test/anchor/domain/rule_checks_nothing_test.exs:52: (test)

  7) test max_file_length: every rule that checks nothing is refused, and the positive rows load (Anchor.Domain.RuleChecksNothingTest)
     test/anchor/domain/rule_checks_nothing_test.exs:46
     max_file_length / baseline on an ast rule (nothing reads it): wrong reason (want "`baseline` is read by graph rules only"): rule 1: unknown key "baseline" in a max_file_length rule (`baseline` applies to graph rules only); known keys for max_file_length: enforcement, id, max_lines, min_files, paths, pattern, recursive, type, uses_module
     code: assert failures == [], Enum.join(failures, "\n")
     stacktrace:
       test/anchor/domain/rule_checks_nothing_test.exs:52: (test)

  8) test no_comparison_in_if: every rule that checks nothing is refused, and the positive rows load (Anchor.Domain.RuleChecksNothingTest)
     test/anchor/domain/rule_checks_nothing_test.exs:46
     no_comparison_in_if / baseline on an ast rule (nothing reads it): wrong reason (want "`baseline` is read by graph rules only"): rule 1: unknown key "baseline" in a no_comparison_in_if rule (`baseline` applies to graph rules only); known keys for no_comparison_in_if: enforcement, id, min_files, paths, pattern, recursive, type, uses_module
     code: assert failures == [], Enum.join(failures, "\n")
     stacktrace:
       test/anchor/domain/rule_checks_nothing_test.exs:52: (test)

  9) test no_transitive_dependency: every rule that checks nothing is refused, and the positive rows load (Anchor.Domain.RuleChecksNothingTest)
     test/anchor/domain/rule_checks_nothing_test.exs:46
     no_transitive_dependency / baseline on an ast rule (nothing reads it): wrong reason (want "`baseline` is read by graph rules only"): rule 1: unknown key "baseline" in a no_transitive_dependency rule (`baseline` applies to graph rules only); known keys for no_transitive_dependency: enforcement, forbidden_modules, forbidden_patterns, id, min_files, paths, pattern, recursive, type, uses_module
     code: assert failures == [], Enum.join(failures, "\n")
     stacktrace:
       test/anchor/domain/rule_checks_nothing_test.exs:52: (test)

 10) test must_use_module: every rule that checks nothing is refused, and the positive rows load (Anchor.Domain.RuleChecksNothingTest)
     test/anchor/domain/rule_checks_nothing_test.exs:46
     must_use_module / baseline on an ast rule (nothing reads it): wrong reason (want "`baseline` is read by graph rules only"): rule 1: unknown key "baseline" in a must_use_module rule (`baseline` applies to graph rules only); known keys for must_use_module: enforcement, id, min_files, paths, pattern, recursive, required_modules, type, uses_module
     code: assert failures == [], Enum.join(failures, "\n")
     stacktrace:
       test/anchor/domain/rule_checks_nothing_test.exs:52: (test)

 11) test case_on_bare_arg: every rule that checks nothing is refused, and the positive rows load (Anchor.Domain.RuleChecksNothingTest)
     test/anchor/domain/rule_checks_nothing_test.exs:46
     case_on_bare_arg / baseline on an ast rule (nothing reads it): wrong reason (want "`baseline` is read by graph rules only"): rule 1: unknown key "baseline" in a case_on_bare_arg rule (`baseline` applies to graph rules only); known keys for case_on_bare_arg: enforcement, id, min_files, paths, pattern, recursive, type, uses_module
     code: assert failures == [], Enum.join(failures, "\n")
     stacktrace:
       test/anchor/domain/rule_checks_nothing_test.exs:52: (test)

 12) test module_pattern_restrictions: every rule that checks nothing is refused, and the positive rows load (Anchor.Domain.RuleChecksNothingTest)
     test/anchor/domain/rule_checks_nothing_test.exs:46
     module_pattern_restrictions / baseline on an ast rule (nothing reads it): wrong reason (want "`baseline` is read by graph rules only"): rule 1: unknown key "baseline" in a module_pattern_restrictions rule (`baseline` applies to graph rules only); known keys for module_pattern_restrictions: allowed_functions, enforcement, id, min_files, paths, pattern, recursive, type, uses_module
     code: assert failures == [], Enum.join(failures, "\n")
     stacktrace:
       test/anchor/domain/rule_checks_nothing_test.exs:52: (test)

 13) test no_direct_dependency: every rule that checks nothing is refused, and the positive rows load (Anchor.Domain.RuleChecksNothingTest)
     test/anchor/domain/rule_checks_nothing_test.exs:46
     no_direct_dependency / baseline on an ast rule (nothing reads it): wrong reason (want "`baseline` is read by graph rules only"): rule 1: unknown key "baseline" in a no_direct_dependency rule (`baseline` applies to graph rules only); known keys for no_direct_dependency: allowed_callers, context_depth, enforcement, forbidden_functions, forbidden_modules, forbidden_patterns, id, match, min_files, paths, pattern, recursive, same_context, type, uses_module
     code: assert failures == [], Enum.join(failures, "\n")
     stacktrace:
       test/anchor/domain/rule_checks_nothing_test.exs:52: (test)

 14) test no_discarding_arrow_in_with: every rule that checks nothing is refused, and the positive rows load (Anchor.Domain.RuleChecksNothingTest)
     test/anchor/domain/rule_checks_nothing_test.exs:46
     no_discarding_arrow_in_with / baseline on an ast rule (nothing reads it): wrong reason (want "`baseline` is read by graph rules only"): rule 1: unknown key "baseline" in a no_discarding_arrow_in_with rule (`baseline` applies to graph rules only); known keys for no_discarding_arrow_in_with: enforcement, id, min_files, paths, pattern, recursive, type, uses_module
     code: assert failures == [], Enum.join(failures, "\n")
     stacktrace:
       test/anchor/domain/rule_checks_nothing_test.exs:52: (test)

 15) test struct_owned_by_module: every rule that checks nothing is refused, and the positive rows load (Anchor.Domain.RuleChecksNothingTest)
     test/anchor/domain/rule_checks_nothing_test.exs:46
     struct_owned_by_module / baseline on an ast rule (nothing reads it): wrong reason (want "`baseline` is read by graph rules only"): rule 1: unknown key "baseline" in a struct_owned_by_module rule (`baseline` applies to graph rules only); known keys for struct_owned_by_module: enforcement, id, min_files, owned_namespaces, paths, pattern, recursive, type, uses_module
     code: assert failures == [], Enum.join(failures, "\n")
     stacktrace:
       test/anchor/domain/rule_checks_nothing_test.exs:52: (test)
```

## RS-E — min_modules 0 is accepted

Run summary: `26 tests, 3 failures`

```text
  1) test layering: every rule that checks nothing is refused, and the positive rows load (Anchor.Domain.RuleChecksNothingTest)
     test/anchor/domain/rule_checks_nothing_test.exs:46
     layering / min_modules: 0 (no floor): LOADED: %Anchor.Config{rules: [%{id: nil, index: 1, ...}], ...}
     code: assert failures == [], Enum.join(failures, "\n")
     stacktrace:
       test/anchor/domain/rule_checks_nothing_test.exs:52: (test)

  2) test context_acyclic: every rule that checks nothing is refused, and the positive rows load (Anchor.Domain.RuleChecksNothingTest)
     test/anchor/domain/rule_checks_nothing_test.exs:46
     context_acyclic / min_modules: 0 (no floor): LOADED: %Anchor.Config{rules: [%{id: nil, index: 1, ...}], ...}
     code: assert failures == [], Enum.join(failures, "\n")
     stacktrace:
       test/anchor/domain/rule_checks_nothing_test.exs:52: (test)

  3) test graph common keys: every rule that checks nothing is refused, the positive rows load (Anchor.Domain.RuleChecksNothingTest)
     test/anchor/domain/rule_checks_nothing_test.exs:182
     min_modules: 0 (no floor): :ok
     code: assert failures == [], Enum.join(failures, "\n")
     stacktrace:
       test/anchor/domain/rule_checks_nothing_test.exs:201: (test)
```

## RS-F — a bucket naming no architecture bucket is accepted

Run summary: `33 tests, 1 failure`

```text
  1) test validate_architecture/3 a bucket naming no architecture bucket is refused, listing the buckets (Anchor.Domain.RuleSchemaTest)
     test/anchor/domain/rule_schema_test.exs:364
     match (=) failed
     code:  assert {:error, reason} =
              RuleSchema.validate_architecture(%{type: :x, bucket: "web"}, :graph, ~w(domain ui))
     left:  {:error, reason}
     right: :ok
     stacktrace:
       test/anchor/domain/rule_schema_test.exs:365: (test)
```

## RS-G — a graph rule with no architecture section is accepted

Run summary: `33 tests, 1 failure`

```text
  1) test validate_architecture/3 a graph rule with no architecture: section is refused (Anchor.Domain.RuleSchemaTest)
     test/anchor/domain/rule_schema_test.exs:356
     ** (Protocol.UndefinedError) protocol Enumerable not implemented for Atom. This protocol is implemented for: Date.Range, File.Stream, Function, GenEvent.Stream, HashDict, HashSet, IO.Stream, Jason.OrderedObject, List, Map, MapSet, Range, Stream

     Got value:

         nil

     code: RuleSchema.validate_architecture(%{type: :x, bucket: "domain"}, :graph, nil)
     stacktrace:
       (elixir 1.19.4) lib/enum.ex:5: Enumerable.impl_for!/1
       (elixir 1.19.4) lib/enum.ex:198: Enumerable.member?/2
       (elixir 1.19.4) lib/enum.ex:1994: Enum.member?/2
       (anchor 0.1.0) lib/anchor/domain/rule_schema.ex:442: Anchor.Domain.RuleSchema.validate_architecture/3
       test/anchor/domain/rule_schema_test.exs:358: (test)
```

## RS-H — graph selectors read as ast selectors (bucket is no selector)

Run summary: `26 tests, 3 failures`

```text
  1) test graph common keys: every rule that checks nothing is refused, the positive rows load (Anchor.Domain.RuleChecksNothingTest)
     test/anchor/domain/rule_checks_nothing_test.exs:182
     positive: a bucket selector: {:error, "the rule has no selector, so it would select no module; give it one of: paths (a non-empty list of path globs), pattern (a module-name glob), uses_module (a module the file uses)"}
     positive: min_modules, id, enforcement and baseline: {:error, "the rule has no selector, so it would select no module; give it one of: paths (a non-empty list of path globs), pattern (a module-name glob), uses_module (a module the file uses)"}
     bucket and pattern (only bucket was read): :ok
     bucket that is not a string: the rule has no selector, so it would select no module; give it one of: paths (a non-empty list of path globs), pattern (a module-name glob), uses_module (a module the file uses)
     an empty bucket: the rule has no selector, so it would select no module; give it one of: paths (a non-empty list of path globs), pattern (a module-name glob), uses_module (a module the file uses)
     min_modules: 0 (no floor): the rule has no selector, so it would select no module; give it one of: paths (a non-empty list of path globs), pattern (a module-name glob), uses_module (a module the file uses)
     min_modules that is not an integer: the rule has no selector, so it would select no module; give it one of: paths (a non-empty list of path globs), pattern (a module-name glob), uses_module (a module the file uses)
     an empty id: the rule has no selector, so it would select no module; give it one of: paths (a non-empty list of path globs), pattern (a module-name glob), uses_module (a module the file uses)
     enforcement: warn: the rule has no selector, so it would select no module; give it one of: paths (a non-empty list of path globs), pattern (a module-name glob), uses_module (a module the file uses)
     baseline without id (entries start with it): the rule has no selector, so it would select no module; give it one of: paths (a non-empty list of path globs), pattern (a module-name glob), uses_module (a module the file uses)
     an absolute baseline path: the rule has no selector, so it would select no module; give it one of: paths (a non-empty list of path globs), pattern (a module-name glob), uses_module (a module the file uses)
     a baseline path climbing out: the rule has no selector, so it would select no module; give it one of: paths (a non-empty list of path globs), pattern (a module-name glob), uses_module (a module the file uses)
     a baseline path with an inner ..: the rule has no selector, so it would select no module; give it one of: paths (a non-empty list of path globs), pattern (a module-name glob), uses_module (a module the file uses)
     an empty baseline: the rule has no selector, so it would select no module; give it one of: paths (a non-empty list of path globs), pattern (a module-name glob), uses_module (a module the file uses)
     code: assert failures == [], Enum.join(failures, "\n")
     stacktrace:
       test/anchor/domain/rule_checks_nothing_test.exs:201: (test)

  2) test layering: every rule that checks nothing is refused, and the positive rows load (Anchor.Domain.RuleChecksNothingTest)
     test/anchor/domain/rule_checks_nothing_test.exs:46
     layering / positive: a bucket selector: refused: {:error, {:invalid_rule, "rule 1: the rule has no selector, so it would select no module; give it one of: paths (a non-empty list of path globs), pattern (a module-name glob), uses_module (a module the file uses)"}}
     layering / positive: min_modules, id, enforcement and baseline: refused: {:error, {:invalid_rule, "rule 1 (id: \"r\"): the rule has no selector, so it would select no module; give it one of: paths (a non-empty list of path globs), pattern (a module-name glob), uses_module (a module the file uses)"}}
     layering / bucket and pattern (only bucket was read): LOADED: %Anchor.Config{rules: [%{id: nil, index: 1, ...}], ...}
     layering / bucket that is not a string: wrong reason (want "`bucket` must be a non-empty string"): rule 1: the rule has no selector, so it would select no module; give it one of: paths (a non-empty list of path globs), pattern (a module-name glob), uses_module (a module the file uses)
     layering / an empty bucket: wrong reason (want "`bucket` must be a non-empty string"): rule 1: the rule has no selector, so it would select no module; give it one of: paths (a non-empty list of path globs), pattern (a module-name glob), uses_module (a module the file uses)
     layering / min_modules: 0 (no floor): wrong reason (want "`min_modules` must be a positive integer"): rule 1: the rule has no selector, so it would select no module; give it one of: paths (a non-empty list of path globs), pattern (a module-name glob), uses_module (a module the file uses)
     layering / min_modules that is not an integer: wrong reason (want "`min_modules` must be a positive integer"): rule 1: the rule has no selector, so it would select no module; give it one of: paths (a non-empty list of path globs), pattern (a module-name glob), uses_module (a module the file uses)
     layering / an empty id: wrong reason (want "`id` must be a non-empty string"): rule 1: the rule has no selector, so it would select no module; give it one of: paths (a non-empty list of path globs), pattern (a module-name glob), uses_module (a module the file uses)
     layering / enforcement: warn: wrong reason (want "`enforcement` must be report or enforce"): rule 1: the rule has no selector, so it would select no module; give it one of: paths (a non-empty list of path globs), pattern (a module-name glob), uses_module (a module the file uses)
     layering / baseline without id (entries start with it): wrong reason (want "`baseline` needs the rule's `id`"): rule 1: the rule has no selector, so it would select no module; give it one of: paths (a non-empty list of path globs), pattern (a module-name glob), uses_module (a module the file uses)
     layering / an absolute baseline path: wrong reason (want "must be a path relative to the project root with no `..`"): rule 1 (id: "r"): the rule has no selector, so it would select no module; give it one of: paths (a non-empty list of path globs), pattern (a module-name glob), uses_module (a module the file uses)
     layering / a baseline path climbing out: wrong reason (want "must be a path relative to the project root with no `..`"): rule 1 (id: "r"): the rule has no selector, so it would select no module; give it one of: paths (a non-empty list of path globs), pattern (a module-name glob), uses_module (a module the file uses)
     layering / a baseline path with an inner ..: wrong reason (want "with no `..` segment"): rule 1 (id: "r"): the rule has no selector, so it would select no module; give it one of: paths (a non-empty list of path globs), pattern (a module-name glob), uses_module (a module the file uses)
     layering / an empty baseline: wrong reason (want "`baseline` must be a non-empty path"): rule 1 (id: "r"): the rule has no selector, so it would select no module; give it one of: paths (a non-empty list of path globs), pattern (a module-name glob), uses_module (a module the file uses)
     layering / a bucket naming no architecture bucket: wrong reason (want "`bucket: web` names no architecture: bucket"): rule 1: the rule has no selector, so it would select no module; give it one of: paths (a non-empty list of path globs), pattern (a module-name glob), uses_module (a module the file uses)
     code: assert failures == [], Enum.join(failures, "\n")
     stacktrace:
       test/anchor/domain/rule_checks_nothing_test.exs:52: (test)

  3) test context_acyclic: every rule that checks nothing is refused, and the positive rows load (Anchor.Domain.RuleChecksNothingTest)
     test/anchor/domain/rule_checks_nothing_test.exs:46
     context_acyclic / positive: a bucket selector: refused: {:error, {:invalid_rule, "rule 1: the rule has no selector, so it would select no module; give it one of: paths (a non-empty list of path globs), pattern (a module-name glob), uses_module (a module the file uses)"}}
     context_acyclic / positive: min_modules, id, enforcement and baseline: refused: {:error, {:invalid_rule, "rule 1 (id: \"r\"): the rule has no selector, so it would select no module; give it one of: paths (a non-empty list of path globs), pattern (a module-name glob), uses_module (a module the file uses)"}}
     context_acyclic / bucket and pattern (only bucket was read): LOADED: %Anchor.Config{rules: [%{id: nil, index: 1, ...}], ...}
     context_acyclic / bucket that is not a string: wrong reason (want "`bucket` must be a non-empty string"): rule 1: the rule has no selector, so it would select no module; give it one of: paths (a non-empty list of path globs), pattern (a module-name glob), uses_module (a module the file uses)
     context_acyclic / an empty bucket: wrong reason (want "`bucket` must be a non-empty string"): rule 1: the rule has no selector, so it would select no module; give it one of: paths (a non-empty list of path globs), pattern (a module-name glob), uses_module (a module the file uses)
     context_acyclic / min_modules: 0 (no floor): wrong reason (want "`min_modules` must be a positive integer"): rule 1: the rule has no selector, so it would select no module; give it one of: paths (a non-empty list of path globs), pattern (a module-name glob), uses_module (a module the file uses)
     context_acyclic / min_modules that is not an integer: wrong reason (want "`min_modules` must be a positive integer"): rule 1: the rule has no selector, so it would select no module; give it one of: paths (a non-empty list of path globs), pattern (a module-name glob), uses_module (a module the file uses)
     context_acyclic / an empty id: wrong reason (want "`id` must be a non-empty string"): rule 1: the rule has no selector, so it would select no module; give it one of: paths (a non-empty list of path globs), pattern (a module-name glob), uses_module (a module the file uses)
     context_acyclic / enforcement: warn: wrong reason (want "`enforcement` must be report or enforce"): rule 1: the rule has no selector, so it would select no module; give it one of: paths (a non-empty list of path globs), pattern (a module-name glob), uses_module (a module the file uses)
     context_acyclic / baseline without id (entries start with it): wrong reason (want "`baseline` needs the rule's `id`"): rule 1: the rule has no selector, so it would select no module; give it one of: paths (a non-empty list of path globs), pattern (a module-name glob), uses_module (a module the file uses)
     context_acyclic / an absolute baseline path: wrong reason (want "must be a path relative to the project root with no `..`"): rule 1 (id: "r"): the rule has no selector, so it would select no module; give it one of: paths (a non-empty list of path globs), pattern (a module-name glob), uses_module (a module the file uses)
     context_acyclic / a baseline path climbing out: wrong reason (want "must be a path relative to the project root with no `..`"): rule 1 (id: "r"): the rule has no selector, so it would select no module; give it one of: paths (a non-empty list of path globs), pattern (a module-name glob), uses_module (a module the file uses)
     context_acyclic / a baseline path with an inner ..: wrong reason (want "with no `..` segment"): rule 1 (id: "r"): the rule has no selector, so it would select no module; give it one of: paths (a non-empty list of path globs), pattern (a module-name glob), uses_module (a module the file uses)
     context_acyclic / an empty baseline: wrong reason (want "`baseline` must be a non-empty path"): rule 1 (id: "r"): the rule has no selector, so it would select no module; give it one of: paths (a non-empty list of path globs), pattern (a module-name glob), uses_module (a module the file uses)
     context_acyclic / a bucket naming no architecture bucket: wrong reason (want "`bucket: web` names no architecture: bucket"): rule 1: the rule has no selector, so it would select no module; give it one of: paths (a non-empty list of path globs), pattern (a module-name glob), uses_module (a module the file uses)
     code: assert failures == [], Enum.join(failures, "\n")
     stacktrace:
       test/anchor/domain/rule_checks_nothing_test.exs:52: (test)
```

## CF-A — enforcement is never parsed (always :enforce)

Run summary: `33 tests, 1 failure`

```text
  1) test enforcement/1 and parse_enforcement/1 a parsed rule carries its enforcement, enforce by default (Anchor.Domain.RuleSchemaTest)
     test/anchor/domain/rule_schema_test.exs:397
     match (=) failed
     code:  assert %{enforcement: :report} = Config.parse_rule(Map.put(base, "enforcement", "report"))
     left:  %{enforcement: :report}
     right: %{
              id: nil,
              match: :reference,
              type: :single_control_flow,
              mode: nil,
              pattern: nil,
              recursive: false,
              paths: ["lib/**/*.ex"],
              enforcement: :enforce,
              context_depth: 2,
              same_context: false,
              bucket: nil,
              min_modules: nil,
              uses_module: nil,
              max_lines: nil,
              allowed_functions: [],
              required_modules: [],
              forbidden_modules: [],
              forbidden_patterns: [],
              forbidden_functions: [],
              allowed_callers: [],
              pure_patterns: [],
              owned_namespaces: nil,
              min_files: 1,
              baseline: nil
            }
     stacktrace:
       test/anchor/domain/rule_schema_test.exs:401: (test)
```

## LT-A — report rules' findings are not marked :report

Run summary: `58 tests, 2 failures`

```text
  1) test check_file/3 enforcement: report a report rule's issue has exit_status 0 and low priority (Anchor.Check.BaseTest)
     test/anchor/check/base_test.exs:200
     Assertion with == failed
     code:  assert issue.exit_status == 0
     left:  2
     right: 0
     stacktrace:
       test/anchor/check/base_test.exs:206: (test)

  2) test run/4 enforcement: report a report rule's finding is :report; an enforced rule's beside it stays :enforce (Anchor.Managers.LintTest)
     test/anchor/managers/lint_test.exs:78
     Assertion with == failed
     code:  assert violations |> Enum.map(&{&1.trigger, &1.enforcement}) |> Enum.sort() == [
              {"MyApp.Enforced", :enforce},
              {"MyApp.Reported", :report}
            ]
     left:  [{"MyApp.Enforced", :enforce}, {"MyApp.Reported", :enforce}]
     right: [{"MyApp.Enforced", :enforce}, {"MyApp.Reported", :report}]
     stacktrace:
       test/anchor/managers/lint_test.exs:91: (test)
```

## BS-A — a report issue keeps a failing exit status

Run summary: `28 tests, 1 failure`

```text
  1) test check_file/3 enforcement: report a report rule's issue has exit_status 0 and low priority (Anchor.Check.BaseTest)
     test/anchor/check/base_test.exs:200
     Assertion with == failed
     code:  assert issue.exit_status == 0
     left:  2
     right: 0
     stacktrace:
       test/anchor/check/base_test.exs:206: (test)
```

## EN-A — held findings also stand

Run summary: `25 tests, 10 failures`

```text
  1) test judge/4 a covered finding is held; an uncovered one (NEW) stands (Anchor.Domain.EnforcementTest)
     test/anchor/domain/enforcement_test.exs:33
     Assertion with == failed
     code:  assert Enum.map(standing, & &1.key) == ["r|B|y"]
     left:  ["r|B|y", "r|A|x"]
     right: ["r|B|y"]
     stacktrace:
       test/anchor/domain/enforcement_test.exs:38: (test)

  2) test judge/4 a baseline absent at the ref is a report-only first-landing NOTE (Anchor.Domain.EnforcementTest)
     test/anchor/domain/enforcement_test.exs:94
     ** (MatchError) no match of right hand side value:

         {[
            %Anchor.Domain.GraphReport.Finding{
              rule_id: "r",
              type: :layering,
              label: "rule 1 (id: \"r\", layering)",
              enforcement: :enforce,
              key: "r|A|x",
              file: "lib/a.ex",
              line: 3,
              message: "r|A|x found. Fix: do not."
            },
            %Anchor.Domain.GraphReport.Finding{
              rule_id: nil,
              type: nil,
              label: "anchor.graph",
              enforcement: :report,
              key: nil,
              file: ".anchor/baselines/r.txt",
              line: nil,
              message: "NOTE: first landing of .anchor/baselines/r.txt (absent at main); review is the gate. Fix: review every line of .anchor/baselines/r.txt in this change; from here it only shrinks."
            }
          ],
          [
            %Anchor.Domain.GraphReport.Finding{
              rule_id: "r",
              type: :layering,
              label: "rule 1 (id: \"r\", layering)",
              enforcement: :enforce,
              key: "r|A|x",
              file: "lib/a.ex",
              line: 3,
              message: "r|A|x found. Fix: do not."
            }
          ]}

     ... (block cut at 40 lines)

  3) test judge/4 positive control for GREW: the same files with nothing added give none (Anchor.Domain.EnforcementTest)
     test/anchor/domain/enforcement_test.exs:82
     Assertion with == failed
     code:  assert standing == []
     left:  [
              %Anchor.Domain.GraphReport.Finding{
                rule_id: "r",
                type: :layering,
                label: "rule 1 (id: \"r\", layering)",
                enforcement: :enforce,
                key: "r|A|x",
                file: "lib/a.ex",
                line: 3,
                message: "r|A|x found. Fix: do not."
              }
            ]
     right: []
     stacktrace:
       test/anchor/domain/enforcement_test.exs:91: (test)

  4) test judge/4 two findings with one key and one entry: one held, one stands (multiset) (Anchor.Domain.EnforcementTest)
     test/anchor/domain/enforcement_test.exs:56
     Expected truthy, got false
     code: assert length(standing) == 1 and length(held) == 1
     stacktrace:
       test/anchor/domain/enforcement_test.exs:60: (test)

  5) test run/2 comparing with a baseline a baseline holding exactly the finding's key: exit 0, held, counted (Anchor.Managers.GraphBaselineTest)
     test/anchor/managers/graph_baseline_test.exs:114
     match (=) failed
     code:  assert %GraphReport{exit_code: 0, findings: [], held: [held]} = report
     left:  %Anchor.Domain.GraphReport{exit_code: 0, findings: [], held: [held]}
     right: %Anchor.Domain.GraphReport{
              findings: [
                %Anchor.Domain.GraphReport.Finding{
                  rule_id: "f",
                  type: :stub_finds,
                  label: "rule 1 (id: \"f\", stub_finds)",
                  enforcement: :enforce,
                  key: "f|AnchorFixtures.GraphBaselineTest.User|found",
                  file: "lib/my_app/domain/user.ex",
                  line: 2,
                  message: "AnchorFixtures.GraphBaselineTest.User was found. Fix: do not be found."
                }
              ],
              could_not_check: [],
              held: [
                %Anchor.Domain.GraphReport.Finding{
                  rule_id: "f",
                  type: :stub_finds,
                  label: "rule 1 (id: \"f\", stub_finds)",
                  enforcement: :enforce,
                  key: "f|AnchorFixtures.GraphBaselineTest.User|found",
                  file: "lib/my_app/domain/user.ex",
                  line: 2,
                  message: "AnchorFixtures.GraphBaselineTest.User was found. Fix: do not be found."
                }
              ],
              refused: [],
              counts: %{modules: 1, opaque: 0, apps: 1, rules: 1},
              exit_code: 1
            }
     stacktrace:
       test/anchor/managers/graph_baseline_test.exs:120: (test)

  6) test run/2 comparing with a baseline an entry no finding consumes is STALE, on the baseline path (exit 1) (Anchor.Managers.GraphBaselineTest)
     test/anchor/managers/graph_baseline_test.exs:136
     match (=) failed
     code:  assert [stale] = report.findings
     left:  [stale]
     right: [
              %Anchor.Domain.GraphReport.Finding{
                rule_id: "f",
                type: :stub_finds,
                label: "rule 1 (id: \"f\", stub_finds)",
                enforcement: :enforce,
                key: "f|AnchorFixtures.GraphBaselineTest.User|found",
                file: "lib/my_app/domain/user.ex",
                line: 2,
                message: "AnchorFixtures.GraphBaselineTest.User was found. Fix: do not be found."
              },
              %Anchor.Domain.GraphReport.Finding{
                rule_id: "f",
                type: :stub_finds,
                label: "rule 1 (id: \"f\", stub_finds)",
                enforcement: :enforce,
                key: "f|Gone|found",
                file: ".anchor/baselines/f.txt",
                line: nil,
                message: "f|Gone|found in .anchor/baselines/f.txt matches no finding (it was fixed). Fix: delete that line from .anchor/baselines/f.txt; a baseline only shrinks."
              }
            ]
     stacktrace:
       test/anchor/managers/graph_baseline_test.exs:143: (test)

  7) test run/2 --base REF (GREW) without --base, git is never asked (Anchor.Managers.GraphBaselineTest)
     test/anchor/managers/graph_baseline_test.exs:267
     match (=) failed
     code:  assert %{exit_code: 0} = Graph.run(request(), deps())
     left:  %{exit_code: 0}
     right: %Anchor.Domain.GraphReport{
              findings: [
                %Anchor.Domain.GraphReport.Finding{
                  rule_id: "f",
                  type: :stub_finds,
                  label: "rule 1 (id: \"f\", stub_finds)",
                  enforcement: :enforce,
                  key: "f|AnchorFixtures.GraphBaselineTest.User|found",
                  file: "lib/my_app/domain/user.ex",
                  line: 2,
                  message: "AnchorFixtures.GraphBaselineTest.User was found. Fix: do not be found."
                }
              ],
              could_not_check: [],
              held: [
                %Anchor.Domain.GraphReport.Finding{
                  rule_id: "f",
                  type: :stub_finds,
                  label: "rule 1 (id: \"f\", stub_finds)",
                  enforcement: :enforce,
                  key: "f|AnchorFixtures.GraphBaselineTest.User|found",
                  file: "lib/my_app/domain/user.ex",
                  line: 2,
                  message: "AnchorFixtures.GraphBaselineTest.User was found. Fix: do not be found."
                }
              ],
              refused: [],
              counts: %{modules: 1, opaque: 0, apps: 1, rules: 1},
              exit_code: 1
            }
     stacktrace:
       test/anchor/managers/graph_baseline_test.exs:272: (test)

  8) test run/2 --base REF (GREW) a baseline that only shrank since REF is not growth (Anchor.Managers.GraphBaselineTest)
     test/anchor/managers/graph_baseline_test.exs:231
     match (=) failed
     code:  assert %{exit_code: 0, findings: []} = Graph.run(request(%{base: "main"}), deps())
     left:  %{exit_code: 0, findings: []}
     right: %Anchor.Domain.GraphReport{
              findings: [
                %Anchor.Domain.GraphReport.Finding{
                  rule_id: "f",
                  type: :stub_finds,
                  label: "rule 1 (id: \"f\", stub_finds)",
                  enforcement: :enforce,
                  key: "f|AnchorFixtures.GraphBaselineTest.User|found",
                  file: "lib/my_app/domain/user.ex",
                  line: 2,
                  message: "AnchorFixtures.GraphBaselineTest.User was found. Fix: do not be found."
                }
              ],
              could_not_check: [],
              held: [
                %Anchor.Domain.GraphReport.Finding{
                  rule_id: "f",
                  type: :stub_finds,
                  label: "rule 1 (id: \"f\", stub_finds)",
                  enforcement: :enforce,
                  key: "f|AnchorFixtures.GraphBaselineTest.User|found",
                  file: "lib/my_app/domain/user.ex",
                  line: 2,
                  message: "AnchorFixtures.GraphBaselineTest.User was found. Fix: do not be found."
                }
              ],
              refused: [],
              counts: %{modules: 1, opaque: 0, apps: 1, rules: 1},
              exit_code: 1
            }
     stacktrace:
       test/anchor/managers/graph_baseline_test.exs:239: (test)

  9) test run/2 --base REF (GREW) a baseline absent at REF is a first landing: a NOTE, exit 0 (Anchor.Managers.GraphBaselineTest)
     test/anchor/managers/graph_baseline_test.exs:242
     Assertion with == failed
     code:  assert report.exit_code == 0
     left:  1
     right: 0
     stacktrace:
       test/anchor/managers/graph_baseline_test.exs:249: (test)

 10) test run/2 comparing with a baseline a report rule's STALE entry is reported, never failing (exit 0) (Anchor.Managers.GraphBaselineTest)
     test/anchor/managers/graph_baseline_test.exs:151
     match (=) failed
     code:  assert [%{enforcement: :report, message: message}] = report.findings
     left:  [%{enforcement: :report, message: message}]
     right: [
              %Anchor.Domain.GraphReport.Finding{
                rule_id: "f",
                type: :stub_finds,
                label: "rule 1 (id: \"f\", stub_finds)",
                enforcement: :report,
                key: "f|AnchorFixtures.GraphBaselineTest.User|found",
                file: "lib/my_app/domain/user.ex",
                line: 2,
                message: "AnchorFixtures.GraphBaselineTest.User was found. Fix: do not be found."
              },
              %Anchor.Domain.GraphReport.Finding{
                rule_id: "f",
                type: :stub_finds,
                label: "rule 1 (id: \"f\", stub_finds)",
                enforcement: :report,
                key: "f|Gone|found",
                file: ".anchor/baselines/f.txt",
                line: nil,
                message: "f|Gone|found in .anchor/baselines/f.txt matches no finding (it was fixed). Fix: delete that line from .anchor/baselines/f.txt; a baseline only shrinks."
              }
            ]
     stacktrace:
       test/anchor/managers/graph_baseline_test.exs:158: (test)
```

## EN-B — STALE entries are dropped

Run summary: `25 tests, 4 failures`

```text
  1) test judge/4 an entry no finding consumes is a STALE finding on the baseline path (Anchor.Domain.EnforcementTest)
     test/anchor/domain/enforcement_test.exs:41
     ** (MatchError) no match of right hand side value:

         {[], []}

     code: {[stale], []} = Enforcement.judge([], ["r|Gone|x"], nil, context())
     stacktrace:
       test/anchor/domain/enforcement_test.exs:42: (test)

  2) test judge/4 a report rule's STALE entry is :report (Anchor.Domain.EnforcementTest)
     test/anchor/domain/enforcement_test.exs:51
     ** (MatchError) no match of right hand side value:

         {[], []}

     code: {[stale], []} = Enforcement.judge([], ["r|Gone|x"], nil, context(rule(:report)))
     stacktrace:
       test/anchor/domain/enforcement_test.exs:52: (test)

  3) test run/2 comparing with a baseline an entry no finding consumes is STALE, on the baseline path (exit 1) (Anchor.Managers.GraphBaselineTest)
     test/anchor/managers/graph_baseline_test.exs:136
     Assertion with == failed
     code:  assert report.exit_code == 1
     left:  0
     right: 1
     stacktrace:
       test/anchor/managers/graph_baseline_test.exs:142: (test)

  4) test run/2 comparing with a baseline a report rule's STALE entry is reported, never failing (exit 0) (Anchor.Managers.GraphBaselineTest)
     test/anchor/managers/graph_baseline_test.exs:151
     match (=) failed
     code:  assert [%{enforcement: :report, message: message}] = report.findings
     left:  [%{enforcement: :report, message: message}]
     right: []
     stacktrace:
       test/anchor/managers/graph_baseline_test.exs:158: (test)
```

## EN-C — a first landing fails (the NOTE is enforced)

Run summary: `25 tests, 2 failures`

```text
  1) test judge/4 a baseline absent at the ref is a report-only first-landing NOTE (Anchor.Domain.EnforcementTest)
     test/anchor/domain/enforcement_test.exs:94
     Assertion with == failed
     code:  assert note.enforcement == :report
     left:  :enforce
     right: :report
     stacktrace:
       test/anchor/domain/enforcement_test.exs:98: (test)

  2) test run/2 --base REF (GREW) a baseline absent at REF is a first landing: a NOTE, exit 0 (Anchor.Managers.GraphBaselineTest)
     test/anchor/managers/graph_baseline_test.exs:242
     Assertion with == failed
     code:  assert report.exit_code == 0
     left:  1
     right: 0
     stacktrace:
       test/anchor/managers/graph_baseline_test.exs:249: (test)
```

## MG-A — an existing baseline is overwritten: :exists read as written

Run summary: `25 tests, 2 failures`

```text
  1) test run/2 --write-baseline RULE_ID an existing file is refused (exit 2), and the findings stand (Anchor.Managers.GraphBaselineTest)
     test/anchor/managers/graph_baseline_test.exs:295
     Assertion with == failed
     code:  assert report.exit_code == 2
     left:  1
     right: 2
     stacktrace:
       test/anchor/managers/graph_baseline_test.exs:301: (test)

  2) test baseline flags --write-baseline over an existing file exits 2 (Mix.Tasks.Anchor.GraphTest)
     test/mix/tasks/anchor_graph_test.exs:200
     Assertion with == failed
     code:  assert catch_exit(Graph.run(~w(--write-baseline a), baseline_opts())) == {:shutdown, 2}
     left:  {:shutdown, 1}
     right: {:shutdown, 2}
     stacktrace:
       (ex_unit 1.19.4) lib/ex_unit/capture_io.ex:325: ExUnit.CaptureIO.do_capture_gl/2
       (ex_unit 1.19.4) lib/ex_unit/capture_io.ex:283: ExUnit.CaptureIO.do_with_io/3
       (ex_unit 1.19.4) lib/ex_unit/capture_io.ex:152: ExUnit.CaptureIO.capture_io/1
       test/mix/tasks/anchor_graph_test.exs:208: (test)
```

## MG-B — a failed read at --base is read as no growth

Run summary: `17 tests, 1 failure`

```text
  1) test run/2 --base REF (GREW) a failed read at REF is an issue naming the ref, never no growth (exit 1) (Anchor.Managers.GraphBaselineTest)
     test/anchor/managers/graph_baseline_test.exs:254
     Assertion with == failed
     code:  assert report.exit_code == 1
     left:  0
     right: 1
     stacktrace:
       test/anchor/managers/graph_baseline_test.exs:263: (test)
```

## MG-C — a missing baseline holds nothing and is not reported

Run summary: `17 tests, 4 failures`

```text
  1) test run/2 comparing with a baseline a baseline line that is not UTF-8 is an issue on that line (Anchor.Managers.GraphBaselineTest)
     test/anchor/managers/graph_baseline_test.exs:177
     match (=) failed
     code:  assert [%{key: @key}, %{file: @path, line: 2, message: message}] = report.findings
     left:  [
              %{key: "f|AnchorFixtures.GraphBaselineTest.User|found"},
              %{file: ".anchor/baselines/f.txt", line: 2, message: message}
            ]
     right: [
              %Anchor.Domain.GraphReport.Finding{
                rule_id: "f",
                type: :stub_finds,
                label: "rule 1 (id: \"f\", stub_finds)",
                enforcement: :enforce,
                key: "f|AnchorFixtures.GraphBaselineTest.User|found",
                file: "lib/my_app/domain/user.ex",
                line: 2,
                message: "AnchorFixtures.GraphBaselineTest.User was found. Fix: do not be found."
              }
            ]
     stacktrace:
       test/anchor/managers/graph_baseline_test.exs:184: (test)

  2) test run/2 comparing with a baseline a baseline holding another rule's entry is an issue; nothing is held (Anchor.Managers.GraphBaselineTest)
     test/anchor/managers/graph_baseline_test.exs:188
     Expected truthy, got false
     code: assert Enum.any?(messages(report), &(&1 =~ ~s(holds "other|X|found", an entry of another)))
     arguments:

         # 1
         ["AnchorFixtures.GraphBaselineTest.User was found. Fix: do not be found."]

         # 2
         #Function<19.102768249/1 in Anchor.Managers.GraphBaselineTest."test run/2 comparing with a baseline a baseline holding another rule's entry is an issue; nothing is held"/1>

     stacktrace:
       test/anchor/managers/graph_baseline_test.exs:196: (test)

  3) test run/2 comparing with a baseline a missing baseline is an issue on its path; the finding stands (exit 1) (Anchor.Managers.GraphBaselineTest)
     test/anchor/managers/graph_baseline_test.exs:162
     match (=) failed
     code:  assert [finding, issue] = report.findings
     left:  [finding, issue]
     right: [
              %Anchor.Domain.GraphReport.Finding{
                rule_id: "f",
                type: :stub_finds,
                label: "rule 1 (id: \"f\", stub_finds)",
                enforcement: :enforce,
                key: "f|AnchorFixtures.GraphBaselineTest.User|found",
                file: "lib/my_app/domain/user.ex",
                line: 2,
                message: "AnchorFixtures.GraphBaselineTest.User was found. Fix: do not be found."
              }
            ]
     stacktrace:
       test/anchor/managers/graph_baseline_test.exs:169: (test)

  4) test run/2 --base REF (GREW) a failed read at REF is an issue naming the ref, never no growth (exit 1) (Anchor.Managers.GraphBaselineTest)
     test/anchor/managers/graph_baseline_test.exs:254
     Expected truthy, got false
     code: assert Enum.any?(messages(report), &(&1 =~ "could not read #{@path} at nosuch"))
     arguments:

         # 1
         ["AnchorFixtures.GraphBaselineTest.User was found. Fix: do not be found."]

         # 2
         #Function<9.102768249/1 in Anchor.Managers.GraphBaselineTest."test run/2 --base REF (GREW) a failed read at REF is an issue naming the ref, never no growth (exit 1)"/1>

     stacktrace:
       test/anchor/managers/graph_baseline_test.exs:264: (test)
```

## MG-D — --write-baseline naming no baselined rule is not refused

Run summary: `17 tests, 1 failure`

```text
  1) test run/2 --write-baseline RULE_ID an id naming no rule with a baseline is refused (exit 2) before any beam is read (Anchor.Managers.GraphBaselineTest)
     test/anchor/managers/graph_baseline_test.exs:307
     ** (Mox.UnexpectedCallError) expected Anchor.BeamSourceMock.read_ebins/1 to be called 0 times but it has been called once in process #PID<0.1051.0>
     code: report = Graph.run(request(%{write_baseline: "f"}), deps())
     stacktrace:
       (mox 1.2.0) lib/mox.ex:909: Mox.__dispatch__/4
       (anchor 0.1.0) lib/anchor/managers/graph.ex:169: Anchor.Managers.Graph.read_beams/2
       (anchor 0.1.0) lib/anchor/managers/graph.ex:90: Anchor.Managers.Graph.run/2
       test/anchor/managers/graph_baseline_test.exs:312: (test)
```

## MG-E — a rule's baseline is ignored (never compared)

Run summary: `25 tests, 18 failures`

```text
  1) test run/2 comparing with a baseline an entry no finding consumes is STALE, on the baseline path (exit 1) (Anchor.Managers.GraphBaselineTest)
     test/anchor/managers/graph_baseline_test.exs:136
     Assertion with == failed
     code:  assert stale.file == @path
     left:  "lib/my_app/domain/user.ex"
     right: ".anchor/baselines/f.txt"
     stacktrace:
       test/anchor/managers/graph_baseline_test.exs:144: (test)

  2) test run/2 comparing with a baseline a report rule's STALE entry is reported, never failing (exit 0) (Anchor.Managers.GraphBaselineTest)
     test/anchor/managers/graph_baseline_test.exs:151
     Assertion with =~ failed
     code:  assert message =~ "Fix: delete that line"
     left:  "AnchorFixtures.GraphBaselineTest.User was found. Fix: do not be found."
     right: "Fix: delete that line"
     stacktrace:
       test/anchor/managers/graph_baseline_test.exs:159: (test)

  3) test run/2 --base REF (GREW) an entry the branch added since REF fails as GREW (exit 1) (Anchor.Managers.GraphBaselineTest)
     test/anchor/managers/graph_baseline_test.exs:218
     match (=) failed
     code:  assert [%{file: @path, key: "f|Added|found", enforcement: :enforce}] = grew
     left:  [%{file: ".anchor/baselines/f.txt", key: "f|Added|found", enforcement: :enforce}]
     right: []
     stacktrace:
       test/anchor/managers/graph_baseline_test.exs:227: (test)

  4) test run/2 --base REF (GREW) a failed read at REF is an issue naming the ref, never no growth (exit 1) (Anchor.Managers.GraphBaselineTest)
     test/anchor/managers/graph_baseline_test.exs:254
     Expected truthy, got false
     code: assert Enum.any?(messages(report), &(&1 =~ "could not read #{@path} at nosuch"))
     arguments:

         # 1
         ["AnchorFixtures.GraphBaselineTest.User was found. Fix: do not be found."]

         # 2
         #Function<9.102768249/1 in Anchor.Managers.GraphBaselineTest."test run/2 --base REF (GREW) a failed read at REF is an issue naming the ref, never no growth (exit 1)"/1>

     stacktrace:
       test/anchor/managers/graph_baseline_test.exs:264: (test)

  5) test run/2 --base REF (GREW) a baseline that only shrank since REF is not growth (Anchor.Managers.GraphBaselineTest)
     test/anchor/managers/graph_baseline_test.exs:231
     match (=) failed
     code:  assert %{exit_code: 0, findings: []} = Graph.run(request(%{base: "main"}), deps())
     left:  %{exit_code: 0, findings: []}
     right: %Anchor.Domain.GraphReport{
              findings: [
                %Anchor.Domain.GraphReport.Finding{
                  rule_id: "f",
                  type: :stub_finds,
                  label: "rule 1 (id: \"f\", stub_finds)",
                  enforcement: :enforce,
                  key: "f|AnchorFixtures.GraphBaselineTest.User|found",
                  file: "lib/my_app/domain/user.ex",
                  line: 2,
                  message: "AnchorFixtures.GraphBaselineTest.User was found. Fix: do not be found."
                }
              ],
              could_not_check: [],
              held: [],
              refused: [],
              counts: %{modules: 1, opaque: 0, apps: 1, rules: 1},
              exit_code: 1
            }
     stacktrace:
       test/anchor/managers/graph_baseline_test.exs:239: (test)

  6) test run/2 --base REF (GREW) without --base, git is never asked (Anchor.Managers.GraphBaselineTest)
     test/anchor/managers/graph_baseline_test.exs:267
     match (=) failed
     code:  assert %{exit_code: 0} = Graph.run(request(), deps())
     left:  %{exit_code: 0}
     right: %Anchor.Domain.GraphReport{
              findings: [
                %Anchor.Domain.GraphReport.Finding{
                  rule_id: "f",
                  type: :stub_finds,
                  label: "rule 1 (id: \"f\", stub_finds)",
                  enforcement: :enforce,
                  key: "f|AnchorFixtures.GraphBaselineTest.User|found",
                  file: "lib/my_app/domain/user.ex",
                  line: 2,
                  message: "AnchorFixtures.GraphBaselineTest.User was found. Fix: do not be found."
                }
              ],
              could_not_check: [],
              held: [],
              refused: [],
              counts: %{modules: 1, opaque: 0, apps: 1, rules: 1},
              exit_code: 1
            }
     stacktrace:
       test/anchor/managers/graph_baseline_test.exs:272: (test)

  7) test run/2 --base REF (GREW) a baseline absent at REF is a first landing: a NOTE, exit 0 (Anchor.Managers.GraphBaselineTest)
     test/anchor/managers/graph_baseline_test.exs:242
     Assertion with == failed
     code:  assert report.exit_code == 0
     left:  1
     right: 0
     stacktrace:
       test/anchor/managers/graph_baseline_test.exs:249: (test)

  8) test run/2 --write-baseline RULE_ID an existing file is refused (exit 2), and the findings stand (Anchor.Managers.GraphBaselineTest)
     test/anchor/managers/graph_baseline_test.exs:295
     Assertion with == failed
     code:  assert report.exit_code == 2
     left:  1
     right: 2
     stacktrace:
       test/anchor/managers/graph_baseline_test.exs:301: (test)

  9) test run/2 comparing with a baseline a baseline holding another rule's entry is an issue; nothing is held (Anchor.Managers.GraphBaselineTest)
     test/anchor/managers/graph_baseline_test.exs:188
     Expected truthy, got false
     code: assert Enum.any?(messages(report), &(&1 =~ ~s(holds "other|X|found", an entry of another)))
     arguments:

         # 1
         ["AnchorFixtures.GraphBaselineTest.User was found. Fix: do not be found."]

         # 2
         #Function<19.102768249/1 in Anchor.Managers.GraphBaselineTest."test run/2 comparing with a baseline a baseline holding another rule's entry is an issue; nothing is held"/1>

     stacktrace:
       test/anchor/managers/graph_baseline_test.exs:196: (test)

 10) test run/2 comparing with a baseline a missing baseline is an issue on its path; the finding stands (exit 1) (Anchor.Managers.GraphBaselineTest)
     test/anchor/managers/graph_baseline_test.exs:162
     match (=) failed
     code:  assert [finding, issue] = report.findings
     left:  [finding, issue]
     right: [
              %Anchor.Domain.GraphReport.Finding{
                rule_id: "f",
                type: :stub_finds,
                label: "rule 1 (id: \"f\", stub_finds)",
                enforcement: :enforce,
                key: "f|AnchorFixtures.GraphBaselineTest.User|found",
                file: "lib/my_app/domain/user.ex",
                line: 2,
                message: "AnchorFixtures.GraphBaselineTest.User was found. Fix: do not be found."
              }
            ]
     stacktrace:
       test/anchor/managers/graph_baseline_test.exs:169: (test)

 11) test run/2 comparing with a baseline a rule with no baseline never reads one (Anchor.Managers.GraphBaselineTest)
     test/anchor/managers/graph_baseline_test.exs:199
     ** (Mox.UnexpectedCallError) expected Anchor.BaselineStoreMock.read/2 to be called 0 times but it has been called once in process #PID<0.1068.0>
     code: assert %{exit_code: 1, held: []} = Graph.run(request(), deps())
     stacktrace:
       (mox 1.2.0) lib/mox.ex:909: Mox.__dispatch__/4
       (anchor 0.1.0) lib/anchor/managers/graph.ex:288: Anchor.Managers.Graph.read_entries/4
       (anchor 0.1.0) lib/anchor/managers/graph.ex:275: Anchor.Managers.Graph.compare_baseline/5
       (anchor 0.1.0) lib/anchor/managers/graph.ex:253: Anchor.Managers.Graph.run_rule/5
       (elixir 1.19.4) lib/enum.ex:1688: Enum."-map/2-lists^map/1-1-"/2
       (anchor 0.1.0) lib/anchor/managers/graph.ex:181: Anchor.Managers.Graph.measured/5
       test/anchor/managers/graph_baseline_test.exs:203: (test)

 12) test run/2 comparing with a baseline a baseline line that is not UTF-8 is an issue on that line (Anchor.Managers.GraphBaselineTest)
     test/anchor/managers/graph_baseline_test.exs:177
     match (=) failed
     code:  assert [%{key: @key}, %{file: @path, line: 2, message: message}] = report.findings
     left:  [
              %{key: "f|AnchorFixtures.GraphBaselineTest.User|found"},
              %{file: ".anchor/baselines/f.txt", line: 2, message: message}
            ]
     right: [
              %Anchor.Domain.GraphReport.Finding{
                rule_id: "f",
                type: :stub_finds,
                label: "rule 1 (id: \"f\", stub_finds)",
                enforcement: :enforce,
                key: "f|AnchorFixtures.GraphBaselineTest.User|found",
                file: "lib/my_app/domain/user.ex",
                line: 2,
                message: "AnchorFixtures.GraphBaselineTest.User was found. Fix: do not be found."
              }
            ]
     stacktrace:
       test/anchor/managers/graph_baseline_test.exs:184: (test)

 13) test run/2 comparing with a baseline a baseline holding exactly the finding's key: exit 0, held, counted (Anchor.Managers.GraphBaselineTest)
     test/anchor/managers/graph_baseline_test.exs:114
     match (=) failed
     code:  assert %GraphReport{exit_code: 0, findings: [], held: [held]} = report
     left:  %Anchor.Domain.GraphReport{exit_code: 0, findings: [], held: [held]}
     right: %Anchor.Domain.GraphReport{
              findings: [
                %Anchor.Domain.GraphReport.Finding{
                  rule_id: "f",
                  type: :stub_finds,
                  label: "rule 1 (id: \"f\", stub_finds)",
                  enforcement: :enforce,
                  key: "f|AnchorFixtures.GraphBaselineTest.User|found",
                  file: "lib/my_app/domain/user.ex",
                  line: 2,
                  message: "AnchorFixtures.GraphBaselineTest.User was found. Fix: do not be found."
                }
              ],
              could_not_check: [],
              held: [],
              refused: [],
              counts: %{modules: 1, opaque: 0, apps: 1, rules: 1},
              exit_code: 1
            }
     stacktrace:
       test/anchor/managers/graph_baseline_test.exs:120: (test)

 14) test run/2 --write-baseline RULE_ID creates the rule's baseline from its keys, sorted under the header; held, exit 0 (Anchor.Managers.GraphBaselineTest)
     test/anchor/managers/graph_baseline_test.exs:277
     Assertion with == failed
     code:  assert report.exit_code == 0
     left:  1
     right: 0
     stacktrace:
       test/anchor/managers/graph_baseline_test.exs:290: (test)

 15) test run/2 comparing with a baseline a finding no entry covers is NEW: it stands and fails (exit 1) (Anchor.Managers.GraphBaselineTest)
     test/anchor/managers/graph_baseline_test.exs:125
     ** (Mox.VerificationError) error while verifying mocks for #PID<0.1086.0>:

       * expected Anchor.BaselineStoreMock.read/2 to be invoked once but it was invoked 0 times
     stacktrace:
       (mox 1.2.0) lib/mox.ex:862: Mox.__verify_mock_or_all__/2
       (mox 1.2.0) lib/mox.ex:819: anonymous fn/1 in Mox.verify_on_exit!/1
       (ex_unit 1.19.4) lib/ex_unit/on_exit_handler.ex:140: ExUnit.OnExitHandler.exec_callback/1
       (ex_unit 1.19.4) lib/ex_unit/on_exit_handler.ex:126: ExUnit.OnExitHandler.on_exit_runner_loop/0

 16) test baseline flags --write-baseline RULE_ID creates the file; held findings print with --verbose (Mix.Tasks.Anchor.GraphTest)
     test/mix/tasks/anchor_graph_test.exs:180
     ** (exit) shutdown: 1
     code: capture_io(fn ->
     stacktrace:
       (anchor 0.1.0) lib/mix/tasks/anchor.graph.ex:140: Mix.Tasks.Anchor.Graph.finish/1
       test/mix/tasks/anchor_graph_test.exs:192: anonymous fn/0 in Mix.Tasks.Anchor.GraphTest."test baseline flags --write-baseline RULE_ID creates the file; held findings print with --verbose"/1
       (ex_unit 1.19.4) lib/ex_unit/capture_io.ex:325: ExUnit.CaptureIO.do_capture_gl/2
       (ex_unit 1.19.4) lib/ex_unit/capture_io.ex:283: ExUnit.CaptureIO.do_with_io/3
       (ex_unit 1.19.4) lib/ex_unit/capture_io.ex:152: ExUnit.CaptureIO.capture_io/1
       test/mix/tasks/anchor_graph_test.exs:191: (test)

 17) test baseline flags --write-baseline over an existing file exits 2 (Mix.Tasks.Anchor.GraphTest)
     test/mix/tasks/anchor_graph_test.exs:200
     Assertion with == failed
     code:  assert catch_exit(Graph.run(~w(--write-baseline a), baseline_opts())) == {:shutdown, 2}
     left:  {:shutdown, 1}
     right: {:shutdown, 2}
     stacktrace:
       (ex_unit 1.19.4) lib/ex_unit/capture_io.ex:325: ExUnit.CaptureIO.do_capture_gl/2
       (ex_unit 1.19.4) lib/ex_unit/capture_io.ex:283: ExUnit.CaptureIO.do_with_io/3
       (ex_unit 1.19.4) lib/ex_unit/capture_io.ex:152: ExUnit.CaptureIO.capture_io/1
       test/mix/tasks/anchor_graph_test.exs:208: (test)

 18) test baseline flags --base REF reads the baseline at REF; a growth fails with GREW (Mix.Tasks.Anchor.GraphTest)
     test/mix/tasks/anchor_graph_test.exs:161
     Assertion with =~ failed
     code:  assert output =~ "a|Extra|x was added to .anchor/baselines/a.txt since origin/main."
     left:  "lib/app/domain/thing.ex:2: [enforce] rule 1 (id: \"a\", stub_finds) AnchorFixtures.AnchorGraphTaskTest.Thing was found. Fix: do not be found.\nanchor.graph: 1 modules in 1 apps, 1 rules, 1 violations (0 report-only, 0 baselined)\n"
     right: "a|Extra|x was added to .anchor/baselines/a.txt since origin/main."
     stacktrace:
       test/mix/tasks/anchor_graph_test.exs:177: (test)
```

## MG-F — another rule's entries are accepted

Run summary: `25 tests, 1 failure`

```text
  1) test run/2 comparing with a baseline a baseline holding another rule's entry is an issue; nothing is held (Anchor.Managers.GraphBaselineTest)
     test/anchor/managers/graph_baseline_test.exs:188
     Assertion with == failed
     code:  assert report.held == []
     left:  [
              %Anchor.Domain.GraphReport.Finding{
                rule_id: "f",
                type: :stub_finds,
                label: "rule 1 (id: \"f\", stub_finds)",
                enforcement: :enforce,
                key: "f|AnchorFixtures.GraphBaselineTest.User|found",
                file: "lib/my_app/domain/user.ex",
                line: 2,
                message: "AnchorFixtures.GraphBaselineTest.User was found. Fix: do not be found."
              }
            ]
     right: []
     stacktrace:
       test/anchor/managers/graph_baseline_test.exs:195: (test)
```

## GR-A — a refusal is not exit 2

Run summary: `39 tests, 5 failures`

```text
  1) test held and refused a refusal is exit 2; 3 still wins over it; held findings never fail (Anchor.Domain.GraphReportTest)
     test/anchor/domain/graph_report_test.exs:61
     Assertion with == failed
     code:  assert GraphReport.new([], [], @counts, refused: [refusal]).exit_code == 2
     left:  0
     right: 2
     stacktrace:
       test/anchor/domain/graph_report_test.exs:63: (test)

  2) test held and refused JSON carries the refused and held findings (Anchor.Domain.GraphReportTest)
     test/anchor/domain/graph_report_test.exs:87
     match (=) failed
     code:  assert %{"held" => [%{"key" => _}], "refused" => [_], "exit_code" => 2} =
              JSON.decode!(GraphReport.render(report, :json))
     left:  %{"held" => [%{"key" => _}], "refused" => [_], "exit_code" => 2}
     right: %{
              "apps" => 2,
              "could_not_check" => [],
              "exit_code" => 0,
              "findings" => [],
              "held" => [
                %{
                  "enforcement" => "enforce",
                  "file" => "lib/my_app/web.ex",
                  "fix" => "call a manager instead.",
                  "key" => "MyApp.Web->MyApp.Repo",
                  "line" => 7,
                  "message" => "MyApp.Web calls MyApp.Repo.",
                  "rule_id" => "web",
                  "type" => "layering"
                }
              ],
              "modules" => 12,
              "opaque" => 0,
              "refused" => [
                %{
                  "enforcement" => "enforce",
                  "file" => "lib/my_app/web.ex",
                  "fix" => "call a manager instead.",
                  "key" => "MyApp.Web->MyApp.Repo",
                  "line" => 7,
                  "message" => "MyApp.Web calls MyApp.Repo.",
                  "rule_id" => "web",
                  "type" => "layering"
                }
              ],
              "rules" => 3
            }
     ... (block cut at 40 lines)

  3) test run/2 --write-baseline RULE_ID an id naming no rule with a baseline is refused (exit 2) before any beam is read (Anchor.Managers.GraphBaselineTest)
     test/anchor/managers/graph_baseline_test.exs:307
     Assertion with == failed
     code:  assert report.exit_code == 2
     left:  0
     right: 2
     stacktrace:
       test/anchor/managers/graph_baseline_test.exs:314: (test)

  4) test run/2 --write-baseline RULE_ID an existing file is refused (exit 2), and the findings stand (Anchor.Managers.GraphBaselineTest)
     test/anchor/managers/graph_baseline_test.exs:295
     Assertion with == failed
     code:  assert report.exit_code == 2
     left:  1
     right: 2
     stacktrace:
       test/anchor/managers/graph_baseline_test.exs:301: (test)

  5) test baseline flags --write-baseline over an existing file exits 2 (Mix.Tasks.Anchor.GraphTest)
     test/mix/tasks/anchor_graph_test.exs:200
     Assertion with == failed
     code:  assert catch_exit(Graph.run(~w(--write-baseline a), baseline_opts())) == {:shutdown, 2}
     left:  {:shutdown, 1}
     right: {:shutdown, 2}
     stacktrace:
       (ex_unit 1.19.4) lib/ex_unit/capture_io.ex:325: ExUnit.CaptureIO.do_capture_gl/2
       (ex_unit 1.19.4) lib/ex_unit/capture_io.ex:283: ExUnit.CaptureIO.do_with_io/3
       (ex_unit 1.19.4) lib/ex_unit/capture_io.ex:152: ExUnit.CaptureIO.capture_io/1
       test/mix/tasks/anchor_graph_test.exs:208: (test)
```

## GR-B — the summary never counts held findings

Run summary: `31 tests, 2 failures`

```text
  1) test held and refused the summary counts held findings; refusals count as violations (Anchor.Domain.GraphReportTest)
     test/anchor/domain/graph_report_test.exs:68
     Assertion with =~ failed
     code:  assert GraphReport.summary(report) =~ "1 violations (0 report-only, 2 baselined)"
     left:  "anchor.graph: 12 modules in 2 apps, 3 rules, 1 violations (0 report-only, 0 baselined)"
     right: "1 violations (0 report-only, 2 baselined)"
     stacktrace:
       test/anchor/domain/graph_report_test.exs:75: (test)

  2) test run/2 comparing with a baseline a baseline holding exactly the finding's key: exit 0, held, counted (Anchor.Managers.GraphBaselineTest)
     test/anchor/managers/graph_baseline_test.exs:114
     Assertion with =~ failed
     code:  assert GraphReport.summary(report) =~ "(0 report-only, 1 baselined)"
     left:  "anchor.graph: 1 modules in 1 apps, 1 rules, 0 violations (0 report-only, 0 baselined)"
     right: "(0 report-only, 1 baselined)"
     stacktrace:
       test/anchor/managers/graph_baseline_test.exs:122: (test)
```

## GR-C — held findings print without --verbose

Run summary: `14 tests, 1 failure`

```text
  1) test held and refused held findings print only with verbose: true (Anchor.Domain.GraphReportTest)
     test/anchor/domain/graph_report_test.exs:78
     Refute with =~ failed
     code:  refute GraphReport.render(report, :text) =~ "[held]"
     left:  "lib/my_app/web.ex:7: [held] rule 1 (id: \"web\", layering) MyApp.Web calls MyApp.Repo. Fix: call a manager instead.\nanchor.graph: 12 modules in 2 apps, 3 rules, 0 violations (0 report-only, 1 baselined)"
     right: "[held]"
     stacktrace:
       test/anchor/domain/graph_report_test.exs:81: (test)
```

## AD-A — create overwrites an existing file

Run summary: `5 tests, 1 failure`

```text
  1) test create/3 on an existing file returns {:error, :exists} and leaves its bytes (Anchor.Adapters.BaselineFileTest)
     test/anchor/adapters/baseline_file_test.exs:19
     Assertion with == failed
     code:  assert BaselineFile.create(root, "r.txt", "new\n") == {:error, :exists}
     left:  :ok
     right: {:error, :exists}
     stacktrace:
       test/anchor/adapters/baseline_file_test.exs:24: (test)
```

## AD-B — the path is not confined

Run summary: `5 tests, 1 failure`

```text
  1) test an absolute path or a .. segment is refused before any file is touched (Anchor.Adapters.BaselineFileTest)
     test/anchor/adapters/baseline_file_test.exs:42
     Assertion with == failed
     code:  assert BaselineFile.create(root, outside, "x") == {:error, :outside_root}
     left:  :ok
     right: {:error, :outside_root}
     stacktrace:
       test/anchor/adapters/baseline_file_test.exs:47: (test)
```

## AD-C — a ref that does not resolve reads as an absent file

Run summary: `9 tests, 2 failures`

```text
  1) test a ref that does not resolve is a git error, never :absent (Anchor.Adapters.GitShowTest)
     test/anchor/adapters/git_show_test.exs:73
     match (=) failed
     code:  assert {:error, {:git, status, _out}} = GitShow.show(root, "nosuch", ".anchor/baselines/r.txt")
     left:  {:error, {:git, status, _out}}
     right: {:error, :absent}
     stacktrace:
       test/anchor/adapters/git_show_test.exs:76: (test)

  2) test no git on the PATH is a git error, never a crash (Anchor.Adapters.GitShowTest)
     test/anchor/adapters/git_show_test.exs:100
     Assertion with == failed
     code:  assert System.cmd("elixir", ["-pa", ebin, "-e", code], stderr_to_stdout: true) ==
              {~s|{:error, {:git, :enoent, "git was not found on the PATH"}}\n|, 0}
     left:  {"{:error, :absent}\n", 0}
     right: {"{:error, {:git, :enoent, \"git was not found on the PATH\"}}\n",
             0}
     stacktrace:
       test/anchor/adapters/git_show_test.exs:108: (test)
```

## AD-D — the ref is not checked before git runs

Run summary: `9 tests, 1 failure`

```text
  1) test a ref Anchor refuses never reaches git (Anchor.Adapters.GitShowTest)
     test/anchor/adapters/git_show_test.exs:129
     Assertion with == failed
     code:  assert GitShow.show(root, "main; rm -rf /", ".anchor/baselines/r.txt") == {:error, :bad_ref}
     left:  {:error, {:git, 1, ""}}
     right: {:error, :bad_ref}
     stacktrace:
       test/anchor/adapters/git_show_test.exs:133: (test)
```

## AD-E — the working copy is read instead of the ref's

Run summary: `9 tests, 2 failures`

```text
  1) test a committed file returns its bytes at the ref, not the working copy (Anchor.Adapters.GitShowTest)
     test/anchor/adapters/git_show_test.exs:42
     Assertion with == failed
     code:  assert GitShow.show(root, "main", ".anchor/baselines/r.txt") == {:ok, ["r|A|x"]}
     left:  {:ok, ["r|A|x", "r|B|y"]}
     right: {:ok, ["r|A|x"]}
     stacktrace:
       test/anchor/adapters/git_show_test.exs:44: (test)

  2) test an absolute path or a .. segment never reaches git (Anchor.Adapters.GitShowTest)
     test/anchor/adapters/git_show_test.exs:112
     match (=) failed
     code:  assert {:ok, ["r|A|x"]} = GitShow.show(root, "main", ".anchor/baselines/r.txt")
     left:  {:ok, ["r|A|x"]}
     right: {:ok, ["r|A|x", "r|B|y"]}
     stacktrace:
       test/anchor/adapters/git_show_test.exs:116: (test)
```

## TK-A — --base never reaches the Manager

Run summary: `8 tests, 1 failure`

```text
  1) test baseline flags --base REF reads the baseline at REF; a growth fails with GREW (Mix.Tasks.Anchor.GraphTest)
     test/mix/tasks/anchor_graph_test.exs:161
     Assertion with =~ failed
     code:  assert output =~ "a|Extra|x was added to .anchor/baselines/a.txt since origin/main."
     left:  ".anchor/baselines/a.txt:1: [enforce] rule 1 (id: \"a\", stub_finds) a|Extra|x in .anchor/baselines/a.txt matches no finding (it was fixed). Fix: delete that line from .anchor/baselines/a.txt; a baseline only shrinks.\nanchor.graph: 1 modules in 1 apps, 1 rules, 1 violations (0 report-only, 1 baselined)\n"
     right: "a|Extra|x was added to .anchor/baselines/a.txt since origin/main."
     stacktrace:
       test/mix/tasks/anchor_graph_test.exs:177: (test)
```

## TK-B — --base is not checked (any ref passes to git)

Run summary: `8 tests, 1 failure`

```text
  1) test an unknown flag, a bad format, an argument or a --base ref git must not see is usage: exit 2 with Fix: (Mix.Tasks.Anchor.GraphTest)
     test/mix/tasks/anchor_graph_test.exs:135
     ** (Mox.UnexpectedCallError) no expectation defined for Anchor.ConfigLoaderMock.load/0 in process #PID<0.1048.0> with args []
     code: for argv <- [
     stacktrace:
       (mox 1.2.0) lib/mox.ex:903: Mox.__dispatch__/4
       (anchor 0.1.0) lib/anchor/managers/graph.ex:134: Anchor.Managers.Graph.load_config/1
       (anchor 0.1.0) lib/anchor/managers/graph.ex:87: Anchor.Managers.Graph.run/2
       (anchor 0.1.0) lib/mix/tasks/anchor.graph.ex:113: Mix.Tasks.Anchor.Graph.run_parsed/2
       test/mix/tasks/anchor_graph_test.exs:145: anonymous fn/1 in Mix.Tasks.Anchor.GraphTest."test an unknown flag, a bad format, an argument or a --base ref git must not see is usage: exit 2 with Fix:"/1
       (ex_unit 1.19.4) lib/ex_unit/capture_io.ex:296: ExUnit.CaptureIO.do_with_io/3
       (ex_unit 1.19.4) lib/ex_unit/capture_io.ex:166: ExUnit.CaptureIO.capture_io/2
       test/mix/tasks/anchor_graph_test.exs:144: anonymous fn/2 in Mix.Tasks.Anchor.GraphTest."test an unknown flag, a bad format, an argument or a --base ref git must not see is usage: exit 2 with Fix:"/1
       (elixir 1.19.4) lib/enum.ex:2520: Enum."-reduce/3-lists^foldl/2-0-"/3
       test/mix/tasks/anchor_graph_test.exs:136: (test)
```

## AD-G — a failed path probe at a resolved ref reads as absent

Run summary: `9 tests, 1 failure`

```text
  1) test a path git cannot look up at a resolved ref is a git error, never :absent (Anchor.Adapters.GitShowTest)
     test/anchor/adapters/git_show_test.exs:85
     match (=) failed
     code:  assert {:error, {:git, status, _out}} = GitShow.show(root, "main", ".anchor/baselines/r.txt")
     left:  {:error, {:git, status, _out}}
     right: {:error, :absent}
     stacktrace:
       test/anchor/adapters/git_show_test.exs:93: (test)
```

## AD-H — an absolute or .. path reaches git

Run summary: `9 tests, 1 failure`

```text
  1) test an absolute path or a .. segment never reaches git (Anchor.Adapters.GitShowTest)
     test/anchor/adapters/git_show_test.exs:112
     Assertion with == failed
     code:  assert GitShow.show(root, "main", "/etc/passwd") == {:error, :outside_root}
     left:  {:error, {:git, 128, ""}}
     right: {:error, :outside_root}
     stacktrace:
       test/anchor/adapters/git_show_test.exs:114: (test)
```

## AD-I — no git on the PATH crashes

Run summary: `9 tests, 1 failure`

```text
  1) test no git on the PATH is a git error, never a crash (Anchor.Adapters.GitShowTest)
     test/anchor/adapters/git_show_test.exs:100
     Assertion with == failed
     code:  assert System.cmd("elixir", ["-pa", ebin, "-e", code], stderr_to_stdout: true) ==
              {~s|{:error, {:git, :enoent, "git was not found on the PATH"}}\n|, 0}
     left:  {"** (ErlangError) Erlang error: :enoent\n    (elixir 1.19.4) lib/system.ex:1140: System.cmd(\"git\", [\"rev-parse\", \"--verify\", \"--quiet\", \"--end-of-options\", \"main^{commit}\"], [cd: \"<worktree>/tmp/Anchor.Adapters.GitShowTest/test-no-git-on-the-PATH-is-a-git-error,-never-a-crash-5e710641\", stderr_to_stdout: false, env: [{\"GIT_OPTIONAL_LOCKS\", \"0\"}]])\n    lib/anchor/adapters/git_show.ex:57: Anchor.Adapters.GitShow.git/2\n    lib/anchor/adapters/git_show.ex:51: Anchor.Adapters.GitShow.resolve/2\n    lib/anchor/adapters/git_show.ex:38: Anchor.Adapters.GitShow.show_valid/3\n    nofile:1: (file)\n    (stdlib 7.1) erl_eval.erl:924: :erl_eval.do_apply/7\n    (stdlib 7.1) erl_eval.erl:1504: :erl_eval.expr_list/7\n",
             1}
     right: {"{:error, {:git, :enoent, \"git was not found on the PATH\"}}\n",
             0}
     stacktrace:
       test/anchor/adapters/git_show_test.exs:108: (test)
```

## AD-J — GitShow returns the bytes unparsed

Run summary: `9 tests, 3 failures`

```text
  1) test an absolute path or a .. segment never reaches git (Anchor.Adapters.GitShowTest)
     test/anchor/adapters/git_show_test.exs:112
     match (=) failed
     code:  assert {:ok, ["r|A|x"]} = GitShow.show(root, "main", ".anchor/baselines/r.txt")
     left:  {:ok, ["r|A|x"]}
     right: {:ok, ["r|A|x\n"]}
     stacktrace:
       test/anchor/adapters/git_show_test.exs:116: (test)

  2) test a committed file returns its bytes at the ref, not the working copy (Anchor.Adapters.GitShowTest)
     test/anchor/adapters/git_show_test.exs:42
     Assertion with == failed
     code:  assert GitShow.show(root, "main", ".anchor/baselines/r.txt") == {:ok, ["r|A|x"]}
     left:  {:ok, ["r|A|x\n"]}
     right: {:ok, ["r|A|x"]}
     stacktrace:
       test/anchor/adapters/git_show_test.exs:44: (test)

  3) test a line that is not UTF-8 at the ref is its error, naming the line (Anchor.Adapters.GitShowTest)
     test/anchor/adapters/git_show_test.exs:119
     Assertion with == failed
     code:  assert GitShow.show(root, "main", ".anchor/baselines/bad.txt") == {:error, {:line, 2, :invalid_utf8}}
     left:  {:ok, [<<114, 124, 65, 124, 120, 10, 255, 10>>]}
     right: {:error, {:line, 2, :invalid_utf8}}
     stacktrace:
       test/anchor/adapters/git_show_test.exs:125: (test)
```

## AD-K — BaselineFile does not refuse a line that is not UTF-8

Run summary: `5 tests, 1 failure`

```text
  1) test read/2 parses: comments dropped, a line that is not UTF-8 refused (Anchor.Adapters.BaselineFileTest)
     test/anchor/adapters/baseline_file_test.exs:30
     Assertion with == failed
     code:  assert BaselineFile.read(root, "bad.txt") == {:error, {:line, 2, :invalid_utf8}}
     left:  {:ok, ["r|A|x"]}
     right: {:error, {:line, 2, :invalid_utf8}}
     stacktrace:
       test/anchor/adapters/baseline_file_test.exs:35: (test)
```

## AD-F — regression: the existence probe was `git cat-file -e`, which printed git's fatal: line on every first landing

Run summary: `5 tests, 1 failure`

```text
  1) test an absent file prints nothing: git's stderr never reaches the terminal (Anchor.Adapters.GitShowTest)
     test/anchor/adapters/git_show_test.exs:56
     Assertion with == failed
     code:  assert System.cmd("elixir", ["-pa", ebin, "-e", code], stderr_to_stdout: true) ==
              {"{:error, :absent}\n", 0}
     left:  {"fatal: path '.anchor/baselines/other.txt' does not exist in '87a244ccf9309419756fb9b670f0676c015d56b3'\n{:error, :absent}\n",
             0}
     right: {"{:error, :absent}\n", 0}
     stacktrace:
       (elixir 1.19.4) lib/enum.ex:1688: Enum."-map/2-lists^map/1-1-"/2
       test/anchor/adapters/git_show_test.exs:62: (test)
```

## AD-L — regression (review floor on d9a61de): GitShow read a failed path probe as absent, returned raw bytes, and passed any path to git

Run summary: `13 tests, 4 failures`

```text
  1) test an absolute path or a .. segment never reaches git (Anchor.Adapters.GitShowTest)
     test/anchor/adapters/git_show_test.exs:99
     Assertion with == failed
     code:  assert GitShow.show(root, "main", "/etc/passwd") == {:error, :outside_root}
     left:  {:error, :absent}
     right: {:error, :outside_root}
     stacktrace:
       test/anchor/adapters/git_show_test.exs:101: (test)

  3) test a path git cannot look up at a resolved ref is a git error, never :absent (Anchor.Adapters.GitShowTest)
     test/anchor/adapters/git_show_test.exs:85
     match (=) failed
     code:  assert {:error, {:git, status, _out}} = GitShow.show(root, "main", ".anchor/baselines/r.txt")
     left:  {:error, {:git, status, _out}}
     right: {:error, :absent}
     stacktrace:
       test/anchor/adapters/git_show_test.exs:93: (test)

  4) test a line that is not UTF-8 at the ref is its error, naming the line (Anchor.Adapters.GitShowTest)
     test/anchor/adapters/git_show_test.exs:106
     Assertion with == failed
     code:  assert GitShow.show(root, "main", ".anchor/baselines/bad.txt") == {:error, {:line, 2, :invalid_utf8}}
     left:  {:ok, <<114, 124, 65, 124, 120, 10, 255, 10>>}
     right: {:error, {:line, 2, :invalid_utf8}}
     stacktrace:
       test/anchor/adapters/git_show_test.exs:112: (test)
```
