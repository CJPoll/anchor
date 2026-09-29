# Sabotage record — fail-closed messages (DND-1265)

- **Domain:** failures
- **Branch:** dnd-1265-anchor-fail-closed
- **Date:** 2026-09-29
- **Code under test:** `Anchor.Domain.Failures.config_violation/1`,
  `Anchor.Domain.Failures.unparseable_violation/2`
- **Suite run:** `mix test` (the whole suite; 530 tests in round 1, 534 in round 2)
- **Merge base:** `origin/main` = 8cff72b
- **Sibling records (same run):** `config-`, `lint-`, `base-`, `source-20260929-dnd_1265_anchor_fail_closed.md`

## Fail-first run

`Anchor.Domain.Failures` is new in this change. Against 8cff72b its rows could
only fail because the module did not exist. The compile warning, verbatim:

```
warning: Anchor.Domain.Failures.config_violation/1 is undefined (module Anchor.Domain.Failures is not available or is yet to be defined)
```

That is not a behavioural failure (ADR 002: a compile error is not a test
failure). The behaviour these messages carry was proven fail-first through the
e2e rows in the base record, and every row below was watched to fail under its
own mutation.

## Mutations

| # | Mutation | Tests failed | Failure string |
|---|---|---|---|
| K | the not-found message joins no searched paths | 2 | `code: assert violation.message =~ "Searched: /p/apps/a/.anchor.yml, /p/.anchor.yml."` / `left: "Anchor found no .anchor.yml, so no Anchor rule was checked. Searched: . Fix: create .anchor.yml at one of the searched paths (the project root, or the umbrella root), or run credo from the dir` (cut at 200 characters by the capture) / `right: "Searched: /p/apps/a/.anchor.yml, /p/.anchor.yml."`; e2e: `right: "Searched: /tmp/anchor_e2e_1676/.anchor.yml"` |
| L | the unparseable message loses its `Fix:` line | 4 | `code: assert violation.message =~ "Fix:"` / `left: "Anchor could not parse this file, so no Anchor rule was checked against it: missing terminator: end."` / `right: "Fix:"` (also the Lint, check_file and e2e rows) |
| X | the YAML message drops the parser's text | 1 | `code: assert violation.message =~ "bad indent at line 3"` / `left: "Anchor could not parse /p/.anchor.yml as YAML, so no Anchor rule was checked: . Fix: correct the YAML syntax in /p/.anchor.yml."` / `right: "bad indent at line 3"` |
| Y | the rejected-config message drops the validation text | 4 | `code: assert violation.message =~ "no \`rules:\` list"` / `left: "Anchor rejected /p/.anchor.yml, so no Anchor rule was checked: . Fix: correct /p/.anchor.yml to match the README section \"Config schema: rule keys at a glance\"."` / `right: "no \`rules:\` list"`; also the invalid-rule row and two e2e rows (`right: "\"no_direct_dependancy\""`, `right: "\"calls\""`) |
| Z | an unrecognised reason is reported without naming it | 1 | `code: assert violation.message =~ "{:something_new, 1}"` / `left: "Anchor could not load its configuration (), so no Anchor rule was checked. Fix: make .anchor.yml load; the reason above names what failed."` / `right: "{:something_new, 1}"` |
| AA | the unreadable-file message drops the posix reason | 1 | `code: assert violation.message =~ "eacces"` / `left: "Anchor could not read /p/.anchor.yml (), so no Anchor rule was checked. Fix: make /p/.anchor.yml a readable file."` / `right: "eacces"` |

K and L ran in round 1 (530 tests); X, Y, Z and AA in round 2 (534 tests), after
the review round asked for a mutation behind every message row.

No measured zeros.

## Rows that stayed green, and why

- Under X, Z and AA only the one Domain row failed: no e2e row asserts on the
  YAML text, an unrecognised reason, or a posix reason. The e2e YAML row checks
  only `"YAML"` and `"Fix:"`, which X leaves in place.

## Traps

- Round 1 mutation K first reported `NO COUNT LINE`: dropping the `"Searched: "`
  line outright left `searched` unused, and `mix test` compiles with
  `--warnings-as-errors`. That is a compile failure, not a test failure. It was
  rewritten as `Enum.take(searched, 0)` and re-run; the row above is from the
  clean run.
- Every run started from a committed tree, and the driver restored each file
  with `git checkout -- <file>`. `git status --short` was clean after each batch.
