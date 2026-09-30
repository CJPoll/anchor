# Sabotage record — every call shape that reaches a function (DND-1267, DND-1280)

- **Domain:** dependency_analyzer
- **Branch:** dnd-1267-forbidden-functions
- **Date:** 2026-09-29
- **Code under test:** `Anchor.Domain.DependencyAnalyzer.function_references/1`
  and the call-mode walk behind it: `piped/2`; the remote-capture,
  unquote-fragment, `apply/3` and `defdelegate` clauses of `visit/3`;
  `visit_remote/8`, `record_remote/8`, `record_mfa_dispatch/4` and
  `@mfa_dispatchers`, `record_mfa_refs/4`, `record_delegate/5`,
  `head_signature/1`, the attribute binding in `step/3` and
  `step_defmodule/4`, `record_bare_call/5` and `kernel_owns?/3`,
  `record_call/6`, `record_dynamic/6`
- **Tests:** `test/anchor/domain/checks/no_dependency_forbidden_functions_test.exs`
  (the call-shape table in both `match` modes, the `Kernel` table, the DND-1280
  module-level table), `test/anchor/e2e/checks_e2e_test.exs`,
  `test/anchor/domain/checks/no_dependency_alias_resolution_test.exs`
- **Suite run:** `mix test` (689 tests)
- **Merge base:** `origin/main` = bfa7aa7; **fix commit:** the DND-1267 commit on
  this branch
- **Other records (same run):** `no_dependency-`, `function_ref-` and
  `rule_schema-20260929-dnd_1267_forbidden_functions.md`

## Fail-first

Round 1, the table written first and run against unfixed bfa7aa7 (`55 tests, 13
failures` over the three files run). Every positive and dynamic row failed with
`got []`:

```
remote call: want [{:call, "Bad.Mod.f/1", 2}], got []
piped remote call counts the piped argument: want [{:call, "Bad.Mod.g/2", 2}], got []
capture &M.f/n: want [{:call, "Bad.Mod.f/2", 2}], got []
defdelegate as:: want [{:call, "Bad.Mod.f/1", 2}], got []
a variable module: want [dynamic: 2], got []
defdelegate: want [{"Bad.X", 2}], got []
piped apply/3: want [{"Bad.X", 2}], got []
Kernel.apply/3: want [{"Bad.X", 2}], got []
```

Round 2, the review rows, run against the round-1 analyzer before its fix
(`689 tests, 4 failures`):

```
GenServer.call(M, :msg): a process name and a message: want [], got [{:call, "Bad.Mod.f", 2}]
a 2-tuple in a function-head pattern: want [], got [{:call, "Bad.Mod.f", 2}]
an attribute module: want [{:call, "Bad.Mod.f/1", 3}], got [dynamic: 3]
an attribute bound to another module: want [], got [dynamic: 3]
an unquote fragment's function on a forbidden module: want [dynamic: 3], got []
defdelegate with an unquote fragment head: want [dynamic: 3], got []
a call on an attribute bound to the module: want [{"Bad.X", 3}], got []
a bare call: want [{:call, "Kernel.send/2", 2}], got []
a bare apply/3: want [{:call, "Kernel.apply/3", 2}], got []
```

## Mutations

Each was applied alone to the final code, the whole suite run, and the file
restored (`git diff --stat` clean after the run). Failure strings are verbatim.

| # | Mutation | Failed | First failure |
|---|---|---|---|
| D1 | `piped/2` no longer builds the call | 6 of 689 | `piped remote call: want [{:call, "Bad.Mod.f/1", 2}], got []` |
| D2 | the remote-capture clause bypassed | 2 of 689 | `capture &M.f/n: want [{:call, "Bad.Mod.f/2", 2}], got [{:call, "Bad.Mod.f/0", 2}]` |
| D3 | `defdelegate` drops `record_delegate/5`'s result | 4 of 689 | `defdelegate: want [{:call, "Bad.Mod.f/1", 2}], got []` |
| D4 | a literal MFA dispatch records no call | 3 of 689 | `apply/3: want [{:call, "Bad.Mod.f/1", 2}], got []` |
| D5 | `record_mfa_refs/4` never runs | 2 of 689 | `an MFA passed to spawn/3: want [{:call, "Bad.Mod.f/1", 2}], got []` |
| D6 | `record_dynamic/6` never records | 4 of 689 | `a variable module: want [dynamic: 2], got []` |
| D7 | field access `m.f` recorded as dynamic | 2 of 689 | `field access without parens: want [], got [dynamic: 2]` |
| D8 | an imported bare call records no function call | 3 of 689 | `import: want [{:call, "Bad.Mod.f/1", 3}], got []` |
| D9 | `record_dynamic/6` ignores `in_quote` | 2 of 689 | `a dynamic call inside a quote is macro code: want [], got [dynamic: 4]` |
| D10 | `defdelegate`'s `to:` not a call-mode dependency | 1 of 689 | `defdelegate: want [{"Bad.X", 2}], got []` |
| D11 | `Function.capture/3` dropped from `@mfa_dispatchers` | 3 of 689 | `Function.capture/3: want [{:call, "Bad.Mod.f/1", 2}], got []`; `Function.capture/3: want [{"Bad.X", 2}], got []` |
| D12 | `head_signature/1` ignores default arguments | 2 of 689 | `defdelegate with a default argument reaches every arity it defines: want [{:call, "Bad.Mod.f/0", 2}, {:call, "Bad.Mod.f/1", 2}], got [{:call, "Bad.Mod.f/1", 2}]` |
| D13 | an MFA no longer needs a literal argument list | 2 of 689 | `GenServer.call(M, :msg, timeout): want [], got [{:call, "Bad.Mod.f", 2}]` |
| D14 | an attribute binding is never recorded | 3 of 689 | `an attribute module: want [{:call, "Bad.Mod.f/1", 3}], got [dynamic: 3]`; `a call on an attribute bound to the module: want [{"Bad.X", 3}], got []` |
| D15 | a bare call `Kernel` owns is not a call on `Kernel` | 1 of 689 | `a bare call: want [{:call, "Kernel.send/2", 2}], got []` |
| D16 | the unquote-fragment clause disabled | 2 of 689 | `an unquote fragment's function on a forbidden module: want [dynamic: 3], got []` |
| D17 | a nested module inherits the outer attributes | 2 of 689 | `an outer module's attribute is not bound in a nested module: want [dynamic: 4], got [{:call, "Bad.Mod.f/1", 4}]` |
| D18 | a local `apply/3` treated as `Kernel`'s dispatcher | 1 of 689 | `a local apply/3 is not Kernel's dispatcher: want [], got [{:call, "Kernel.apply/3", 3}]` |
| D19 | a non-literal `defdelegate` head records nothing | 2 of 689 | `defdelegate with an unquote fragment head and as:: want [{:call, "Bad.Mod.f", 3}], got []` |

D12 first survived (`689 tests, 0 failures`): the only default-argument row
used a `g/2` token, which both arities of the mutant still satisfied. Two rows
were added (a `defdelegate` default reaching `f/0` and `f/1`, and a local
default arity shadowing an import), and the re-run is the row above.

## Rows no mutation reddens

These negative rows passed on bfa7aa7 and are never reached by a mutation here:
"the module's own local call", "a string", "an alias alone", "the module held as
a value", "a typespec". Those shapes never reach `record_call/6`. They pin that a
future change does not start recording them. A measured zero, on purpose.
