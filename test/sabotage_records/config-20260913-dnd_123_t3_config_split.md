# Sabotage record — Config split: BUG-2 coercion + BUG-5 umbrella candidate

- **Domain:** config
- **Branch:** dnd-123-t3-config-split
- **Date:** 2026-09-13
- **Code under test:** `Anchor.Config.parse_rule/1` / `parse_mode/1`,
  `Anchor.Domain.ConfigPaths.candidates/2`
- **Suite run:** `mix test test/anchor/domain/config_test.exs`,
  `mix test test/anchor/domain/config_paths_test.exs`

These mutations prove the two bug fixes this ticket delivers: BUG 2 (surface
`max_lines` and coerce `mode`) and BUG 5 (an umbrella app subdirectory reaches
the umbrella-root `.anchor.yml`). Each mutation lets the wrong value or the
default leak through; each was watched to fail and then reverted.

## Mutations

| # | Mutation | Suite | Tests failed | Failure string |
|---|---|---|---|---|
| A | `Anchor.Config.parse_mode/1`: change the `"all"` and `"public_only"` clause bodies to `:separate` (let the default leak where a specific mode is required) | `config_test.exs` | 2 | see A below |
| B | `Anchor.Config.parse_rule/1`: replace `max_lines: rule["max_lines"]` with `max_lines: nil` (drop BUG-2 surfacing) | `config_test.exs` | 1 | see B below |
| C | `Anchor.Config.parse_mode/1`: delete the catch-all `parse_mode(_token), do: :separate` clause | `config_test.exs` | 1 | see C below |
| D | `Anchor.Domain.ConfigPaths.in_apps_subdir?/1`: change `Path.basename() == "apps"` to `== "__never__"` (never recognise an umbrella app dir; BUG-5 fix disabled) | `config_paths_test.exs` | 1 | see D below |

### A — `mode` coercion clauses (rows 9, 10)

```
1) test parse_rule/1 ... bare mode: public_only coerced to :public_only
   code:  assert rule.mode == :public_only
   left:  :separate
   right: :public_only

2) test parse_rule/1 ... bare mode: all coerced to :all
   code:  assert rule.mode == :all
   left:  :separate
   right: :all
```

Rows 11 (`"separate"`) and 12 (unknown `"sideways"`) stayed **green** under this
mutation — both legitimately resolve to `:separate`, so the mutation is
invisible to them. That is expected: those rows assert a different property (the
`:separate` default), not the specific-token coercion. Their protection is
measured separately by mutations C (row 12) and, for row 11, its own passing
clause.

### B — `max_lines` surfacing (row 8, BUG 2)

```
1) test parse_rule/1 ... max_lines surfaced as an atom-keyed integer
   code:  assert rule.max_lines == 10
   left:  nil
   right: 10
```

### C — unknown-`mode` fallback clause (row 12)

```
1) test parse_rule/1 ... unknown mode token falls back to :separate without crashing
   ** (FunctionClauseError) no function clause matching in Anchor.Config.parse_mode/1
   code: rule = Config.parse_rule(%{"mode" => "sideways"})
```

Removing the catch-all turns an unknown token into a crash — the row's "without
crashing" clause is exactly what the fallback protects.

### D — umbrella-root candidate from an app subdirectory (config_paths row 3, BUG 5)

```
1) test candidates/2 ... run from inside an umbrella app dir finds the umbrella root
   Assertion with in failed
   code:  assert "/proj/.anchor.yml" in candidates
   left:  "/proj/.anchor.yml"
   right: ["/proj/apps/my_app/.anchor.yml"]
```

With the app-directory probe neutralised, `candidates("/proj/apps/my_app",
false)` returns only the app-local path and never offers the umbrella root — the
precise BUG-5 regression the fix removes.

## Trap encountered

The first attempt at mutation D deleted the whole `if apps? or in_apps_subdir?(cwd)`
disjunction down to `if apps?`, which left `in_apps_subdir?/1` **unused**. Under
`mix test` (which compiles with `--warnings-as-errors`) that surfaced as a
*compile failure*, not a test failure — the suite never ran. A sabotage mutation
must keep the code compiling: mutating the predicate's compared value
(`"apps"` → `"__never__"`) keeps the helper referenced while still letting the
wrong result through. (This is the "a compile failure read as a test failure"
trap catalogued in ADR 002 / ADR 003.)
