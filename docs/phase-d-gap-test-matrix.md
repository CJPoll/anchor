# Anchor — Phase D Functional Test Matrix (capability gaps for walt_ui enforcement)

Intended behavior for the four capability gaps (A, A′, B, D) that block full five-bucket
enforcement in walt_ui. Rows describe what each unit **should** do; where a row states behavior the
current code lacks, that row is the assertion the fix must make pass. Every check's Domain contract
is `detect_violations(...) -> [%Anchor.Domain.Violation{}]` (each violation carries `message`,
`trigger`, `line`); machinery units are pure functions (map/AST in → data out). All cases are pure
and unit-level: no IO, no sleeps, no real project tree.

Conventions: `ast:` is Elixir source parsed to a bare AST (as `Anchor.Check.Source` hands inward),
line numbers count from the first line of the shown snippet; `rule:` is a parsed rule map (atom
keys, as `Anchor.Config.parse_rule/1` produces); `facts:` is the `Anchor.Domain.RuleMatching` fact
map; `[]` means exactly zero violations. Module names in facts are the `to_string/1` of the module
atom (so `"Elixir.App.Schemas.User"`), matching `Anchor.Managers.Lint.file_facts/2`.

Gaps covered: **A** `forbidden_patterns:` (module-name globs); **A′** `match: call | reference`
mode; **B** Erlang-atom module targets (`:telemetry`); **D** rule-selection bug (empty `paths`
shadows `pattern`/`uses_module`). Gap C (path `excluded`) and Gap E (directory⇒bucket) are out of
scope.

---

## lib/anchor/config.ex

### parse_rule/1

Parses one decoded YAML rule map (string keys) into the internal rule map (atom keys). Covers new
keys `forbidden_patterns` (A) and `match` (A′), the `paths` absent⇒`nil` fix (D), and the raw-atom
module token (B).

| # | Test Case | Inputs | Expected Output | Category |
|---|---|---|---|---|
| 1 | surfaces `forbidden_patterns` as a list (A) | rule: `{"type"=>"no_direct_dependency", "forbidden_patterns"=>["*.Adapters.*"]}` | parsed rule has `forbidden_patterns: ["*.Adapters.*"]` | Happy Path |
| 2 | absent `forbidden_patterns` defaults to `[]` (A) | rule: `{"type"=>"no_direct_dependency"}` | `forbidden_patterns: []` | Validation |
| 3 | **absent `paths` surfaces as `nil`, not `[]` (D)** | rule: `{"type"=>"no_direct_dependency", "pattern"=>"*.Schemas.*"}` | `paths: nil` (intended-correct: no longer stamped `[]`) | Validation |
| 4 | present `paths` preserved as a list (D regression guard) | rule: `{"type"=>"no_direct_dependency", "paths"=>["lib/**/*.ex"]}` | `paths: ["lib/**/*.ex"]` | Happy Path |
| 5 | absent `match` defaults to `:reference` (A′) | rule: `{"type"=>"no_direct_dependency"}` | `match: :reference` | Validation |
| 6 | `match: "call"` coerced to `:call` (A′) | rule: `{"match"=>"call"}` | `match: :call` | Happy Path |
| 7 | `match: "reference"` coerced to `:reference` (A′) | rule: `{"match"=>"reference"}` | `match: :reference` | Validation |
| 8 | unknown `match` token falls back to `:reference`, no raise (A′) | rule: `{"match"=>"sideways"}` | parse succeeds; `match: :reference` | Error Handling |
| 9 | **Erlang-atom `forbidden_modules` token kept as a raw atom (B)** | rule: `{"forbidden_modules"=>[":telemetry"]}` | `forbidden_modules: [:telemetry]` (leading-`:` token → `String.to_atom`, NOT `Module.concat`) | Validation |
| 10 | ordinary module string still `Module.concat`'d (B regression guard) | rule: `{"forbidden_modules"=>["MyApp.Repo"]}` | `forbidden_modules: [MyApp.Repo]` | Happy Path |
| 11 | mixed atom + module list preserved element-wise (B) | rule: `{"forbidden_modules"=>[":telemetry", "MyApp.Repo"]}` | `forbidden_modules: [:telemetry, MyApp.Repo]` | Validation |
| 12 | `forbidden_patterns` and `forbidden_modules` coexist on one rule (A) | rule: `{"forbidden_modules"=>["MyApp.Repo"], "forbidden_patterns"=>["*.Adapters.*"]}` | both surfaced: `forbidden_modules: [MyApp.Repo]`, `forbidden_patterns: ["*.Adapters.*"]` | Control Flow Decisioning |

Caveat: the same `:telemetry`-token rule applies to `forbidden_patterns` entries too if a pattern is
literally an atom, but patterns are module-name globs (strings) and are not run through
`parse_modules`; only `forbidden_modules`/`required_modules` are.

---

## lib/anchor/domain/rule_matching.ex

### rule_matches_file?/2

Pure rule selection. Gap D: with `parse_rule/1` now emitting `paths: nil` when YAML omits `paths`
(and the first clause guarded on a NON-EMPTY list), a `pattern`/`uses_module` rule falls through to
its own clause instead of being shadowed by `Enum.any?([], …)`.

| # | Test Case | Inputs | Expected Output | Category |
|---|---|---|---|---|
| 1 | **`pattern` rule with `paths: nil` selects by module name (D)** | rule: `%{pattern: "*.Schemas.*", paths: nil, uses_module: nil}`; facts: `%{module_names: ["Elixir.App.Schemas.User"], filename: "lib/x.ex", uses: []}` | `true` | Happy Path |
| 2 | `pattern` rule does not select a non-matching module | same rule; facts `module_names: ["Elixir.App.Service"]` | `false` | Validation |
| 3 | `paths` rule still selects by path (recursive) | rule: `%{paths: ["lib/**/*.ex"], recursive: true, pattern: nil, uses_module: nil}`; facts `filename: "lib/a/b.ex"` | `true` | Happy Path |
| 4 | **empty `paths: []` falls through to the `pattern` clause (D guard)** | rule: `%{paths: [], recursive: false, pattern: "*.Schemas.*", uses_module: nil}`; facts `module_names: ["Elixir.App.Schemas.User"]` | `true` (empty list no longer shadows selection) | Control Flow Decisioning |
| 5 | `uses_module` rule with `paths: nil` selects a file that uses it (D) | rule: `%{uses_module: "Ecto.Schema", paths: nil, pattern: nil}`; facts `uses: [Ecto.Schema]` | `true` | Happy Path |
| 6 | rule with no selector (all `nil`) selects nothing | rule: `%{paths: nil, pattern: nil, uses_module: nil}`; any facts | `false` (deny by default) | Validation |
| 7 | `paths` rule (non-recursive single-`*`) does not select a nested file | rule: `%{paths: ["lib/*.ex"], recursive: false, pattern: nil}`; facts `filename: "lib/a/b.ex"` | `false` | Validation |

Caveat: rows depend on `parse_rule/1` #3 (paths ⇒ nil). The first clause's new guard is
`when is_list(paths) and paths != []` (or an equivalent presence check); mutating it back to
`when is_list(paths)` should re-red rows 1, 4, 5 (sabotage target).

---

## lib/anchor/domain/dependency_analyzer.ex

### extract_direct_dependencies/1

Gap B: a remote call whose callee module is a **bare atom** (`{{:., _, [mod, fun]}, _, _}` with
`is_atom(mod)`) records `mod` as a dependency, keyed as that atom. Scoped to remote-call callees —
inert atom literals are not recorded. Existing alias/`__MODULE__` behavior is unchanged.

| # | Test Case | Inputs | Expected Output | Category |
|---|---|---|---|---|
| 1 | **bare-atom remote call records the atom module (B)** | ast: `:telemetry.execute([:a], %{}, %{})` | list contains `:telemetry` | Happy Path |
| 2 | bare `:ok` atom literal is not recorded | ast: `def f, do: :ok` | `:ok` NOT in the list | Positive Control |
| 3 | atom in non-call position (list element) is not recorded | ast: `x = [:telemetry, :other]` | `:telemetry` NOT recorded (not a call callee) | Validation |
| 4 | aliased remote call unchanged (Elixir `Logger`) | ast: `Logger.info("x")` | list contains `Logger` | Positive Control |
| 5 | atom call and alias call both recorded | ast: `:telemetry.execute(a, b, c)` and `MyApp.Repo.all(q)` in one body | list contains `:telemetry` and `MyApp.Repo` | Happy Path |
| 6 | atom callee keyed as the raw atom (not an `Elixir.`-prefixed module) | ast: `:cowboy.start_clear(a, b, c)` | list contains `:cowboy` (the atom), not `Elixir.cowboy` | Validation |

### extract_call_dependencies/1

New pure function (A′). Records a module dependency ONLY when the module appears in **call
position**: an aliased/atom remote call `{{:., _, [mod, fun]}, _, args}`, or `apply(mod, fun, args)`
with a literal `mod`. A module appearing only as an inert atom (a router-map value, a plain
reference) or inside a typespec is NOT recorded — honoring ADR-001's "Domain-router-holds-atoms"
carve-out.

| # | Test Case | Inputs | Expected Output | Category |
|---|---|---|---|---|
| 1 | aliased remote call recorded | ast: `Foo.Bar.baz(x)` | list contains `Foo.Bar` | Happy Path |
| 2 | `apply/3` with a literal module recorded | ast: `apply(Foo.Bar, :baz, [x])` | list contains `Foo.Bar` | Happy Path |
| 3 | **inert alias as a map value is NOT recorded (router carve-out)** | ast: `%{yaml: Foo.Adapters.Loader}` (no call) | `Foo.Adapters.Loader` NOT recorded | Validation |
| 4 | **inert alias in a typespec is NOT recorded** | ast: `@spec f(Foo.Bar.t()) :: :ok` | `Foo.Bar` NOT recorded (typespec bodies are skipped) | Validation |
| 5 | bare-atom remote call recorded in call position (B∩A′) | ast: `:telemetry.execute(a, b, c)` | list contains `:telemetry` | Happy Path |
| 6 | plain alias reference (no call) is NOT recorded | ast: `x = Foo.Bar` | `Foo.Bar` NOT recorded | Positive Control |
| 7 | `__MODULE__.Sub.f()` call resolves and is recorded | ast inside `defmodule Enclosing`: `__MODULE__.Sub.f()` | `Enclosing.Sub` recorded | Control Flow Decisioning |

Caveat: `apply(mod, fun, args)` with a NON-literal `mod` (a variable) records nothing — dynamic
dispatch is out of the static-analysis boundary. Rows 3–4 are the load-bearing difference from
`extract_direct_dependencies/1`, which records those references; sabotage by pointing `call` mode at
`extract_direct_dependencies/1` should re-red rows 3, 4, 6.

---

## lib/anchor/domain/checks/no_dependency.ex

### detect_violations/2

Gap A adds `forbidden_patterns` matching (each recorded dependency `to_string`'d and matched with
`Anchor.Domain.GlobPattern.matches_module_pattern?/2`); Gap A′ switches the dependency set consulted
by `rule.match` (`:reference` ⇒ `extract_direct_dependencies/1`, `:call` ⇒
`extract_call_dependencies/1`); Gap B lets an Erlang-atom `forbidden_modules` entry match a
bare-atom remote call. Message/trigger/line preserve the existing shape: message
`"Module has forbidden direct dependency on <inspect(module)>"`, trigger `inspect(module)`, line =
first reference line.

| # | Test Case | Inputs | Expected Output | Category |
|---|---|---|---|---|
| 1 | **`forbidden_patterns` flags a matching dependency (A)** | ast references `WaltUi.Contacts.Adapters.Repositories.Repository` (line 3); rule: `%{forbidden_modules: [], forbidden_patterns: ["*.Adapters.*"], match: :reference}` | 1 violation<br>message: `Module has forbidden direct dependency on WaltUi.Contacts.Adapters.Repositories.Repository`<br>trigger: `WaltUi.Contacts.Adapters.Repositories.Repository`<br>line: 3 | Happy Path |
| 2 | Domain-only file passes the pattern rule (A positive control) | ast references only `WaltUi.Contacts.Domain.Foo`; same rule | `[]` | Positive Control |
| 3 | **pattern is dot-bounded — no substring match (A)** | ast references `Foo.AdaptersHelper`; rule `forbidden_patterns: ["*.Adapters.*"]` | `[]` (no dot-bounded `.Adapters.` segment) | Validation |
| 4 | `forbidden_modules` and `forbidden_patterns` both fire (A) | ast references `MyApp.Repo` (line 2) and `X.Adapters.Y` (line 3); rule `%{forbidden_modules: [MyApp.Repo], forbidden_patterns: ["*.Adapters.*"], match: :reference}` | 2 violations, triggers `MyApp.Repo` and `X.Adapters.Y` | Happy Path |
| 5 | a pattern-matched module is reported once at its first reference line (A) | ast references `X.Adapters.Y` on lines 2 and 4; pattern rule | 1 violation, line 2 | Control Flow Decisioning |
| 6 | `match: :reference` (default) flags an inert reference (A′) | ast holds `%{a: Foo.Adapters.L}` (no call, ref on line 2); rule `%{forbidden_patterns: ["*.Adapters.*"], match: :reference}` | 1 violation, line 2 | Happy Path |
| 7 | **`match: :call` passes an inert map value (A′ router carve-out)** | same ast; rule `%{forbidden_patterns: ["*.Adapters.*"], match: :call}` | `[]` (atom held, not called) | Validation |
| 8 | `match: :call` flags a real call (A′) | ast `Foo.Adapters.L.enrich(x)` (line 2); rule `%{forbidden_patterns: ["*.Adapters.*"], match: :call}` | 1 violation, line 2 | Happy Path |
| 9 | **Erlang-atom `forbidden_modules` flags a remote atom call (B)** | ast `:telemetry.execute(a, b, c)` (line 2); rule `%{forbidden_modules: [:telemetry], forbidden_patterns: [], match: :reference}` | 1 violation<br>trigger: `:telemetry`<br>line: 2 | Happy Path |
| 10 | clean file under both selectors (positive control) | ast references only `Enum`; rule `%{forbidden_modules: [MyApp.Repo], forbidden_patterns: ["*.Adapters.*"], match: :reference}` | `[]` | Positive Control |

Caveat: row 9 requires the first-reference-line lookup to handle a bare-atom callee (match the
`{{:., _, [:telemetry, _]}, _, _}` node) since `Module.split/1` raises on a non-Elixir atom; a `nil`
line here would be a partial fix and row 9 asserts line 2. Row 5's "first line" property is the same
one the existing `forbidden_modules` path guarantees, reused for patterns.

---

## lib/anchor/domain/checks/no_transitive_dependency.ex

### detect_violations/3

Gap A extends the transitive check with `forbidden_patterns`: every module in a defining module's
transitively-reachable set (self removed) is `to_string`'d and matched against the rule's patterns,
in addition to the exact `forbidden_modules` membership test. Message/trigger/chain shape is
unchanged (message contains `transitive dependency on forbidden module <inspect>` plus the
`A -> B -> ... -> Forbidden` chain when the path exceeds two nodes). Graph edges remain
reference-based (the `match` mode is A′-scoped to `NoDependency`; not applied to graph construction).

| # | Test Case | Inputs | Expected Output | Category |
|---|---|---|---|---|
| 1 | **`forbidden_patterns` flags a transitively-reached adapter (A)** | ast defines `A` referencing `B` (line 2); modules_map `A→[B]`, `B→[X.Adapters.Y]`; rule `%{forbidden_modules: [], forbidden_patterns: ["*.Adapters.*"]}` | 1 violation<br>message contains `transitive dependency on forbidden module X.Adapters.Y` and `dependency chain: A -> B -> X.Adapters.Y`<br>trigger: `X.Adapters.Y`<br>line: 2 | Happy Path |
| 2 | reachable set with no pattern match passes (A positive control) | modules_map `A→[B]`, `B→[C]` (no adapter); rule `forbidden_patterns: ["*.Adapters.*"]` | `[]` | Positive Control |
| 3 | `forbidden_modules` and `forbidden_patterns` both fire transitively (A) | modules_map reaching `MyApp.Repo` and `Z.Adapters.W`; rule `%{forbidden_modules: [MyApp.Repo], forbidden_patterns: ["*.Adapters.*"]}` | 2 violations, triggers `MyApp.Repo` and `Z.Adapters.W` | Happy Path |
| 4 | pattern dot-bounded transitively (A) | reachable set contains only `Foo.AdaptersHelper`; rule `forbidden_patterns: ["*.Adapters.*"]` | `[]` | Validation |
