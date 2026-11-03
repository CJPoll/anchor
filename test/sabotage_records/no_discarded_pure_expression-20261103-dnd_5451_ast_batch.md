# Sabotage record — no_discarded_pure_expression (DND-5451)

- **Domain:** no_discarded_pure_expression
- **Branch:** dnd-5451-ast-batch
- **Date:** 2026-11-03
- **Code under test:** `Anchor.Domain.Checks.NoDiscardedPureExpression`
  (`detect_violations/2`, `shape/1`), the `Anchor.Check.NoDiscardedPureExpression`
  shell, and `pure_patterns` in `Anchor.Config.build_rule/4`
- **Tests:** `test/anchor/domain/checks/no_discarded_pure_expression_test.exs`
  (rows D1-D19, S1), `test/anchor/check/no_discarded_pure_expression_test.exs`
  (F1, F3), `test/anchor/e2e/checks_e2e_test.exs` ("no_discarded_pure_expression
  through the real pipeline", F1, F2)
- **Merge base:** `origin/main` = 185ecc9; mutated tree: the ticket's code
  before its commit
- **Related records (same run):**
  `dependency_analyzer-20261103-dnd_5451_ast_batch.md` (`resolved_modules/1`),
  `rule_schema-20261103-dnd_5451_ast_batch.md` (the `pure_patterns` load rows)

Each mutation was applied to one file, the named suite run, the file restored.
Every mutation keeps every function called: an unused function or variable
fails `--warnings-as-errors` and proves nothing. Failure text is verbatim.

| # | Mutation | Failed | Failure |
|---|---|---|---|
| A | Pure is true for anything unknown (`pure?(_other, _ctx)` returns `true`) | D7 | `expression fun.()` (the row's loop names the first expression reported) |
| A2 | A name the resolver cannot place counts as pure (`:unknown -> true`) | "a call on a name the resolver cannot place" | `code: assert detect(source, [%{pure_patterns: ["*Calc*"]}]) == []` `left: [` (one violation) `right: []` |
| B | The final expression of a block is judged too | 18 of 22, D12 among them | D12: `code: assert detect(source) == []` `left: [` ... `line: 6,` `trigger: "Map.put(m, :a, 1)",` (the final expression of `g/1`) |
| C | The bang exclusion removed (`bang?/1` is `fun == :__never__`) | D8, D14 | `code: assert detect(discarded("Map.fetch!(m, :k)")) == []` `left: [` `right: []` |
| D | An `fn` clause body is not judged (`body_pure?(...) or true`) | D9 | `code: assert detect(discarded("Enum.each(xs, fn x -> send(self(), x) end)")) == []` `left: [` `right: []` |
| D2 | A capture's target is not judged (`capture_target_pure?(...) or true`) | D9 | `code: assert detect(discarded("Enum.each(xs, &IO.puts/1)")) == []` `left: [` `right: []` |
| E | `pure_patterns` ignored (`pure_patterns(rule) -- pure_patterns(rule)`) | D13, D14 | `code: assert [%{trigger: "Calc.add(a, b)"}] = detect(source, [%{pure_patterns: ["MyApp.*"]}])` `left: [%{trigger: "Calc.add(a, b)"}]` `right: []` |
| G | `quote` bodies are walked | D16 | `code: assert detect(source) == []` `left: [` `right: []` |
| H | An underscore binding never reports its right side | D5 | `code: assert [%{trigger: "_ = Enum.map(xs, &(&1 * 2))"}] = detect(discarded("_ = Enum.map(xs, &(&1 * 2))"))` `left: [%{trigger: "_ = Enum.map(xs, &(&1 * 2))"}]` `right: []` |
| I | `{Date, :utc_today}` dropped from the stdlib effects | D11 | `expression Date.utc_today()` |
| J | The message ends with another Fix | D1 | `code: assert String.ends_with?(violation.message, "Fix: " <> @shape)` |
| CFG | `Config.build_rule/4` drops `pure_patterns` (`pure_patterns: []`) | e2e F1 | `left: [{5, "Map.put(m, :a, 1)"}]` `right: [{5, "Map.put(m, :a, 1)"}, {6, "Calc.add(m, 1)"}]` |
| FW | The shell returns no violations (`\|> Enum.take(0)`) | check F1, e2e F1 | `code: assert [issue] = run_check(@violating)` `left: [issue]` `right: []`; e2e: `left: []` `right: [{5, "Map.put(m, :a, 1)"}, {6, "Calc.add(m, 1)"}]` |

## Measured zeros, fixed in the same run

- **A2** first passed: no row called a module through a name the resolver
  could not place. The row "a call on a name the resolver cannot place is not
  reported" was added, and A2 now fails it.
- **G** first passed: D16's quoted expression was `unquote(a) + 1`, and
  `unquote/1` is a special form, so it was never pure and the row passed with
  the quote walked. D16 now quotes `b + 1` (pure) with a positive control
  outside the quote, and G fails it.

## Critic round 1 (on d5db360): two false reports, fixed

The judge found two shapes the rule reported although they can have an
effect. Each regression row was run against d5db360's detector first:

```
1) test detect_violations/2 D9: a stdlib call that calls a function held in a value is not reported
   expression Enum.each(xs, fun)
2) test detect_violations/2 D14: a pure_patterns module's imported or injected calls are not reported
   code:  assert detect(source, [%{pure_patterns: ["MyApp.*"]}]) == []
   (left: violations with trigger: "field(:a, :string)", line: 6 and trigger: "helper(a)", line: 11)
25 tests, 2 failures
```

and both pass on the fix. Mutations of the fix:

| # | Mutation | Failed | Failure |
|---|---|---|---|
| K | No stdlib argument is callable (`... && []`) | D9 (value) | `expression Enum.each(xs, fun)` |
| K2 | A callable position accepts any pure value (`written_value?(arg) or true`) | D9 (value) | `expression Enum.each(xs, fun)` |
| L | A local call need not be the module's own function | D14 (imports) | `code: assert detect(source, [%{pure_patterns: ["MyApp.*"]}]) == []` `left: [` |

## Critic round 2 (on a3f6621): a setter and three callable written values, fixed

Run against a3f6621's detector first:

```
1) test every stdlib pure-set function that returns only :ok is treated as an effect
   URI.default_port(a1, a2) returns only :ok, so it is an effect
2) test detect_violations/2 D11: a clock or random read is not reported
   expression URI.default_port("ftp", 21)
3) test detect_violations/2 D9: a stdlib call that calls a function held in a value is not reported
   expression Enum.map(xs, &Enum.each(s, &1))
26 tests, 3 failures
```

The first row closes the class (a function of the pure set whose spec
returns only `:ok` exists for its effect): it reads every spec of the set,
so a setter a later Elixir adds fails it. Mutations of the fix:

| # | Mutation | Failed | Failure |
|---|---|---|---|
| M1 | A container in a callable position may name a module (`not found or true`) | D9 | `expression Enum.sort(xs, {:asc, MyApp.Effectful})` |
| M2 | Any atom is an option atom | D9 | `expression Enum.sort(xs, :lists)` |
| M3 | `&1` counts as a written function | D9 | `expression Enum.map(xs, &Enum.each(s, &1))` |

