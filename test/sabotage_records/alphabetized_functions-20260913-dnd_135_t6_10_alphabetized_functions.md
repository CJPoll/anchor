# Sabotage record — AlphabetizedFunctions detection extracted to Domain

- **Domain:** alphabetized_functions
- **Branch:** dnd-135-t6-10-alphabetized-functions
- **Date:** 2026-09-13
- **Code under test:** `Anchor.Domain.Checks.AlphabetizedFunctions.detect_violations/2` (the pure Domain detector; the `Anchor.Check.AlphabetizedFunctions` shell delegates to it)
- **Suite run:** `mix test test/anchor/check/alphabetized_functions_test.exs` (the exhaustive #1–14 `check_file/3` matrix)

T6.10 (DND-135) extracted the detection out of the `Anchor.Check.AlphabetizedFunctions`
Framework shell into the pure `Anchor.Domain.Checks.AlphabetizedFunctions` module,
fixed the BUG-2 consumer (read `mode` from the T3 atom key, default `:separate`),
and adjudicated `defguard`/`defguardp` participation (#12) and multi-clause
collapse to a single first-clause-anchored unit (#13–14). Each mutation below was
applied to the Domain module, the suite re-run, the code restored. Failure
strings are verbatim, including `left:` / `right:`.

| # | Mutation | Rows failed | Failure string |
|---|---|---|---|
| A | Read `mode` from a **string** key instead of the T3 atom key (`Map.get(rule, :mode)` → `Map.get(rule, "mode")`), so every atom-keyed `mode` is ignored and the rule falls back to `:separate` | 3 (rows 1, 5, 6) | row 1: `code: assert banana.message ==` `left: "public function \`banana/0\` is not in alphabetical order. It should appear after apple/0."` `right: "function \`banana/0\` is not in alphabetical order. It should appear after apple/0."`; row 5: `code: assert [] == issues(source, %{type: :alphabetized_functions, mode: :public_only})` `left: []` `right: [ ...private zebra/aardvark issues... ]`; row 6: `code: refute Enum.any?(result, &(&1.trigger in ["zebra/0", "aardvark/0"]))` |
| C | Drop `:defguard`/`:defguardp` from `@public_defs`/`@private_defs` so guard macros are not extracted | 1 (row 12) | `code: assert Enum.any?(result, &(&1.trigger == "is_apple/1" and &1.message =~ "public function"))` `Expected truthy, got false` |
| D | Remove the multi-clause collapse (`\| > Enum.uniq_by(&{&1.name, &1.arity, &1.visibility})`) so each clause is counted | 1 (row 14) | `code: assert length(banana_issues) == 1` `left: 2` `right: 1` |
| E | Drop the case-fold from the sort key (`String.downcase(func.original_name)` → `func.original_name`) | 1 (row 4) | `code: assert [] == issues(ordered, %{type: :alphabetized_functions, mode: :all})` `left: []` `right: [ ...aa/aB flip... ]` |
| F | Blank the public prefix (`:separate_public -> "public "` → `""`) | 3 (rows 7, 11, 12) | row 7: `code: assert apple.message =~ "public function \`apple/0\` is not in alphabetical order"` `left: "function \`apple/0\` is not in alphabetical order. It should appear after the beginning."` `right: "public function \`apple/0\` is not in alphabetical order"`; rows 11, 12: `Expected truthy, got false` on the `&1.message =~ "public function"` controls |
| G | Invert the structural predicate (`&1.line < last_public_line` → `&1.line > last_public_line`) so a private function before public is no longer flagged | 4 (rows 9, 10, 11, 12) | row 9: `code: assert helper` `Expected truthy, got nil`; row 10: `code: assert [] == issues(ordered, %{type: :alphabetized_functions})` `left: []` `right: [ ... ]` (the default-mode structural control), rows 11/12 collateral |
| H | Anchor the collapsed unit at the **last** clause instead of the first (sort `:desc` before `uniq_by`, re-sort `:asc` after) | 1 (row 14) | `code: assert hd(banana_issues).line_no == 2` `left: 3` `right: 2` |
| I | Drop the arity tie-break from the sort key (`{String.downcase(name), func.arity}` → `{String.downcase(name)}`) | 1 (row 3) | `code: assert Enum.any?(...&(&1.trigger == "foo/1"))` `Expected truthy, got false` |
| J | Blank the private prefix (`:separate_private -> "private "` → `""`) | 1 (row 8) | `code: assert aardvark.message =~ "private function \`aardvark/0\` is not in alphabetical order"` `left: "function \`aardvark/0\` is not in alphabetical order. It should appear after the beginning."` `right: "private function \`aardvark/0\` is not in alphabetical order"` |

> There is no mutation **B**: the two default/dispatch mutations first tried under
> that label failed to compile under `--warnings-as-errors` (see "Traps
> encountered" below), so no failure string exists to record. The label is kept
> to preserve the one-to-one mapping between the letters and the mutations
> actually attempted.

## What each mutation proves

- **A** is the BUG-2 consumer fix (the T3 loop closed): `mode` must be read from
  the **atom** key `rule.mode`, not a string key. Reverting to a string read makes
  every atom-keyed `mode` invisible, so `:all` (row 1) and `:public_only` (rows 5,
  6) silently degrade to the `:separate` default — row 1 gains a spurious `public `
  prefix, and rows 5/6 start reporting the private group the `:public_only` mode is
  supposed to ignore.
- **C** proves the #12 adjudication: `defguard`/`defguardp` participate in ordering.
  Without them in the def-type lists the guard macros vanish from the extracted set
  and a mis-ordered public guard is no longer flagged.
- **D / H** protect the #13–14 adjudication from two angles. **D** proves a
  multi-clause function is collapsed to a *single* unit (without it, both `banana/1`
  clauses each produce an issue → 2, not 1). **H** proves that single unit is
  anchored at the **first** clause line (anchoring at the last clause moves the
  reported line from 2 to 3).
- **E / I** protect the two halves of the sort key: case-insensitive ordering
  (**E**) and the arity tie-break (**I**).
- **F / J** protect the visibility prefixes (`public ` / `private `) that
  discriminate the `:public_only` and `:separate` group messages per ADR 002.
- **G** proves the `:separate` structural rule (all public before all private),
  including that a rule with **no** `mode` key exercises it — row 10 uses
  `%{type: :alphabetized_functions}` (no mode) and reddens, so the default really is
  `:separate`.

## Traps encountered (ADR 002 catalogue)

Three mutations were rejected by Elixir 1.19's `--warnings-as-errors` compile before
they could prove anything about the tests — they are recorded here so a future run
does not re-attempt them:

1. **Default rewrite in `mode/1`** (`_ -> :separate` → `_ -> :all`): the dispatch
   `case` then has a provably-unreachable `:separate ->` clause. Elixir 1.19 reports
   `the following clause will never match: :separate ... typing violation` and the
   compile fails. The mode routing is therefore compiler-guarded: the documented
   default cannot be silently swapped for another valid mode.
2. **Dispatch rewrite** (`:separate -> check_separate_visibility(functions)` →
   `... check_public_functions_only(functions)`): leaves `check_separate_visibility/1`
   defined-but-unused → warnings-as-errors compile failure.
3. **`private_issues = []`**: leaves the `private_functions` binding from
   `Enum.split_with/2` unused → warnings-as-errors compile failure. The prefix
   mutation (**J**) was used instead to red row 8.

## Measured zeros

- **Row 2** (`:all` ordered → `[]`) and **Row 13** (multi-clause ordered → `[]`)
  each carry a **live positive control** (row 2 swaps the pair and asserts it
  flags; row 13 reorders the units and asserts it flags), but the `[]` half of each
  is not independently falsifiable by a single-line mutation to this module:
  - Row 2's `[]` is the negation of row 1, which mutation A already reddens with an
    exact message; no additional mutation makes an *already-ordered* `:all` input
    flag without also breaking a stronger row.
  - Row 13's `[]` is structural: multiple clauses of one function share
    name+arity, so they sort adjacently whether or not they are collapsed — the
    collapse's only *observable* effects are the count (row 14 / mutation D) and the
    anchor line (row 14 / mutation H), both reddened. Row 13 documents the
    absence-of-spurious-flag guarantee; its control keeps it non-vacuous.

## Note on the row-4 fixture (decision)

The pre-existing test used `def Apple()` / `def BANANA()` to "prove"
case-insensitivity, but an uppercase-*initial* name parses as an alias
(`{:__aliases__, _, [:Apple]}`), not a `def` head, so those functions were never
extracted — the old `[]` was vacuous and no mutation to `String.downcase` could red
it. Row 4 now uses two valid lowercase-initial names, `aa` and `aB`, whose ASCII
order (`aB` < `aa`) is the reverse of their case-insensitive order (`aa` < `aB`), so
mutation **E** (dropping the case-fold) genuinely reddens it.
