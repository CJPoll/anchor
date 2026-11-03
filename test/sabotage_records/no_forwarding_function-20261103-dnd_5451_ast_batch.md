# Sabotage record — no_forwarding_function (DND-5452)

- **Domain:** no_forwarding_function
- **Branch:** dnd-5451-ast-batch
- **Date:** 2026-11-03
- **Code under test:** `Anchor.Domain.Checks.NoForwardingFunction`
  (`detect_violations/2`, `shape/1`), the `Anchor.Check.NoForwardingFunction`
  shell, and the type's entry in `Anchor.Domain.RuleSchema`
- **Tests:** `test/anchor/domain/checks/no_forwarding_function_test.exs`
  (D1-D18, S1 and four extra rows), `test/anchor/check/no_forwarding_function_test.exs`,
  `test/anchor/e2e/checks_e2e_test.exs` ("no_forwarding_function through the
  real pipeline", F1, F2), `test/anchor/domain/rule_checks_nothing_test.exs`
  (`table(:no_forwarding_function)`)
- **Base:** 4251b38 (DND-5451's last commit); mutated tree: this ticket's code
  before its commit

Each mutation was applied to one file, the named suite run, the file
restored. Failure text is verbatim.

| # | Mutation | Failed | Failure |
|---|---|---|---|
| order | Argument order ignored (`Enum.sort(call_args) == Enum.sort(vars)`) | D6 | the row loop on `g(b, a)` |
| guard | A guarded clause can forward | D7 | the row loop on `f(a, b) when is_integer(a)` |
| impl | `@impl` no longer exempts | D12 | `code: assert triggers(module("@impl true\n  def f(a, b), do: g(a, b)")) == []` `left: ["f/2"]` `right: []` |
| deprecated | `@deprecated` no longer exempts | D13 | `left: ["f/2"]` `right: []` |
| defined | The target need not be defined here | D6, D9, D14 | D9: `code: assert triggers(source) == []` `left: ["f/2"]` `right: []` |
| any | One clause decides for all (`Enum.take(1)`) | D15 | `code: assert triggers(source) == []` `left: ["f/1"]` `right: []` |
| self | A call to itself counts | D11 | `code: assert triggers(module("def f(a), do: f(a)")) == []` `left: ["f/1"]` `right: []` |
| quote | `quote` bodies walked | D16 | `code: assert triggers(source) == []` `left: ["f/2"]` `right: []` |
| underscore | An `_name` head variable counts | D7 | the row loop on `f(a, _b)` |
| distinct | A repeated head variable counts | D7 | the row loop on `f(a, a)` |
| nested | Nested modules not visited | D14 | `code: assert [%{trigger: "h/1", line: 5}] = detect(source)` `right: []` |
| default | A default argument adds no arity | "a target with a default argument" | `code: assert triggers(source) == ["f/1"]` `left: []` `right: ["f/1"]` |
| body | A `do` with `rescue` counts as one expression | "a body with rescue" | `left: ["f/2"]` `right: []` |
| pipe | Pipes not normalized | D3 | `code: assert triggers(module("def f(a, b), do: a \|> g(b)")) == ["f/2"]` `left: []` `right: ["f/2"]` |
| delegate | A `defdelegate` to another module counts | D17 | `code: assert triggers(module("defdelegate f(a), to: Other, as: :g")) == []` `left: ["f/1"]` `right: []` |
| message | The message drops its Fix | D1 | `code: assert String.ends_with?(violation.message, "Fix: " <> @shape)` |
| shell | The shell returns no violations | check F1, e2e F1 | `code: assert [issue] = run_check(source)` `left: [issue]` `right: []`; e2e: `left: []` `right: [{2, "total/2"}]` |
| key | `pure_patterns` accepted on this type | the type's table | `no_forwarding_function / an unknown key (pure_patterns belongs to another type): LOADED: %Anchor.Config{rules: [%{id: nil, index: 1, ...}], ...}` |

## Measured zeros, fixed in the same run

- **quote** first passed: D16 quoted bare `def`s inside a `defmacro`, which a
  module body's direct statements never include, so the skip was not
  exercised. D16 now quotes a `defmodule`, which the walk would otherwise
  enter.
- **underscore** and **distinct** first passed: D7's rows called `g(a, b)`
  for every head, so `f(a, _b)` and `f(a, a)` failed on the argument match,
  not on the head. Each row now passes the head's own names.
- The `defimpl` skip was removed from the walk rather than tested: a `defimpl`
  is never a module body here, so the clause guarded nothing, and it also
  hid modules nested in a `defimpl`.
