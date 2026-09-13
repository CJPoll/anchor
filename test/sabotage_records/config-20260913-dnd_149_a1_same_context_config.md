# Sabotage record — Config parse+validate same_context/context_depth (Gap F, A1)

- **Domain:** config
- **Branch:** dnd-149-a1-same-context-config
- **Date:** 2026-09-13
- **Code under test:** `Anchor.Config.parse_rule/1`, `Anchor.Config.parse_config/1` (validation + error propagation), `Anchor.Adapters.ConfigFile.load_from_path/1` (load-channel surfacing)
- **Suite run:** `mix test test/anchor/domain/config_test.exs` and `mix test test/anchor/adapters/config_file_test.exs`

DND-149 A1 adds two additive keys to `no_direct_dependency` rules —
`same_context` (boolean, default `false`) and `context_depth` (pos_integer,
default `2`) — parsed and validated in `parse_rule/1`. Validation failures
return `{:error, {:invalid_rule, reason}}`, which `parse_config/1` propagates and
`ConfigFile.load_from_path/1` wraps as `{:error, {:config_load_failed,
{:invalid_rule, _}}}` so a malformed rule fails the load rather than becoming a
silent green no-op. No detection change (that is A2).

## Mutation table

| # | Mutation | Suite | Tests failed | Failure string |
|---|---|---|---|---|
| A | Delete the `not is_boolean(same_context)` cond branch of `validate_new_keys/1` | config_test | 1 | `row 5: a non-boolean same_context is rejected` — `match (=) failed` — `code: assert {:error, {:invalid_rule, reason}} = result` — `left: {:error, {:invalid_rule, reason}}` — `right: %{... same_context: "yes" ...}` |
| B | `context_depth > 0` → `context_depth >= 0` (0 now passes) | config_test | 1 | `row 6: a non-positive context_depth is rejected` — `match (=) failed` — `code: assert {:error, {:invalid_rule, reason}} = result` — `left: {:error, {:invalid_rule, reason}}` — `right: %{... type: :no_direct_dependency ...}` |
| C | `forbidden_patterns == []` → `forbidden_patterns == [:__never__]` (branch never fires) | config_test | 2 | `row 4: same_context true with no forbidden_patterns is rejected, naming the rule` — `code: assert {:error, {:invalid_rule, reason}} = result` — `left: {:error, {:invalid_rule, reason}}` — `right: %{... type: :no_direct_dependency ...}`; and `parse_config/1 ... an invalid same_context rule makes parse_config surface an error` — `code: assert {:error, {:invalid_rule, _reason}} = Config.parse_config(data)` — `left: {:error, {:invalid_rule, _reason}}` — `right: %Anchor.Config{rules: [...]}` |
| C | (same mutation, load channel) | config_file_test | 1 | `load_from_path/1 ... an invalid same_context rule fails the load (not a silent no-op)` — `code: assert {:error, {:config_load_failed, {:invalid_rule, _reason}}} = ConfigFile.load_from_path(path)` — `left: {:error, {:config_load_failed, {:invalid_rule, _reason}}}` — `right: {:ok, %Anchor.Config{rules: [...]}}` |
| D1 | Default-application: `context_depth: Map.get(rule, "context_depth", 2)` → `..., nil)` | config_test | 2 | `row 3: keys absent default to same_context false and context_depth 2` — `Assertion with == failed` — `code: assert rule.context_depth == 2` — `left: nil` — `right: 2` (also re-reds `row 1`, which asserts `context_depth == 2` under a defaulted depth) |
| D2 | Default-application: `same_context: Map.get(rule, "same_context", false)` → `..., true)` | config_test | 2 | `row 3` — `code: assert rule.same_context == false` — `left: true` — `right: false`; and `row 7: context_depth without same_context parses inertly` — `code: assert rule.same_context == false` — `left: true` — `right: false` |

## Notes / traps

- **Trap (recorded):** two natural mutations for A and C — replacing the
  condition with a literal `... and false ->` — do NOT run as behavioral
  mutations. Elixir 1.18's type checker flags the dead branch as a
  `typing violation found at: ... and false`, and `--warnings-as-errors` turns
  that into `Compilation failed`, which reads as an aborted run, not a test
  failure. Use a mutation that stays reachable: delete the whole branch (A), or
  change the compared value so the branch is live but never taken (C:
  `[:__never__]`). Deleting C's branch instead orphans the `forbidden_patterns`
  binding → an unused-variable warning → same compile trap; the value-swap
  avoids it.
- **Measured multi-test rows are honest.** C reddens both the direct
  `parse_rule/1` row and the `parse_config/1` propagation row (plus the
  `ConfigFile` load row in the adapter suite), which is the point: the guarantee
  "malformed never silently greens on load" is proven end-to-end, not just at the
  pure parser.
- **Rows that stayed green under D1/D2 and why:** rows 2 and 7 supply an explicit
  `context_depth`, so D1's default change does not touch them; row 1/2 supply an
  explicit `same_context: true`, so D2's default change does not touch them. Each
  default mutation only moves the tests that exercise the absent-key path.
