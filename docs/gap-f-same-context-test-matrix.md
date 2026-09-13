# Gap F — `same_context` / `context_depth` capability: test matrix

Enables anchor to express **"forbid a dependency only when it lives in the same
subdomain/context as the file being checked."** This is the missing feature
behind walt_ui's ADR-001 rule *"an adapter MUST NOT call a Manager within the
same subdomain, but a cross-subdomain adapter calling another subdomain's
Manager (its public API) IS allowed."* A static `forbidden_patterns` glob cannot
tell the two apart because it has no binding to the checked file's own context.

Scope of the capability:

- **A1** — config parsing/validation for two new `no_direct_dependency` rule
  keys: `same_context` (boolean, default `false`) and `context_depth`
  (pos_integer, default `2`).
- **A2** — domain detection scoping + framework/manager plumbing of the file's
  own context into detection.
- **A3** — docs, dogfood, release.

## Design (normative for the captains)

New rule keys on a `type: no_direct_dependency` rule:

| Key | Type | Default | Meaning |
|---|---|---|---|
| `same_context` | boolean | `false` | When `true`, a `forbidden_patterns` match is a violation **only if** the dependency shares the checked file's own context. |
| `context_depth` | pos_integer | `2` | Number of leading module-namespace segments that define a "context/subdomain". For walt_ui, `WaltUi.<Context>` = depth 2. |

**Context of a module** = the first `context_depth` dot-separated segments of its
name. `WaltUi.Contacts.Adapters.Foo` at depth 2 → `["WaltUi", "Contacts"]`.

**Scoping semantics** (only when `same_context: true`):

- A `forbidden_patterns` match is reported **iff** the dependency's context
  equals the checked file's own context.
- A dependency (or the file) with fewer than `context_depth` namespace segments
  has no derivable context → treated as **not same-context** → not reported
  under a `same_context` rule.
- `forbidden_modules` **exact** matches are **never** scoped by `same_context`
  (they name absolute IO modules like `Repo`/`:telemetry`; a same-subdomain
  qualifier is meaningless for them) — they always report.
- `same_context: false`/absent → today's behavior exactly (every
  `forbidden_patterns` match reported), a hard back-compat guarantee.

**Comparison is module-namespace vs. module-namespace on both sides** (the
file's own defining module name vs. the dependency's), which sidesteps the
snake_case-directory vs. CamelCase-module mismatch a path-capture design would
hit (`contact_tags/` dir ↔ `ContactTags` module).

### Plumbing (A2)

- `Anchor.Managers.Lint` already derives the file's own defining module names in
  `file_facts/2` via `DependencyAnalyzer.extract_module_names/1`. Thread those
  into the check `context` (e.g. `context.module_names`) so detection can derive
  the file's context. Compute `facts` once in `detect_for_file/5` and reuse for
  both rule selection and the context.
- `Anchor.Check.NoDependency.detect_violations/4` derives `file_context` from
  `context.module_names` (first module, first `context_depth` segments) and
  passes it into the domain detector.
- `Anchor.Domain.Checks.NoDependency` gains a `file_context`-aware arity;
  the existing `check_file/3` back-compat path passes `file_context: nil`
  (= "no scoping", identical to today).

---

## lib/anchor/domain/config.ex → `parse_rule/1` (A1)

| # | Test Case | Inputs | Expected Output | Category |
|---|---|---|---|---|
| 1 | parses `same_context: true` with default depth | rule yaml: `type: no_direct_dependency`, `forbidden_patterns: ["A.*.Managers.*"]`, `same_context: true` | parsed rule map has `same_context: true` and `context_depth: 2` | Happy Path |
| 2 | carries an explicit `context_depth` | above + `context_depth: 3` | parsed rule map has `context_depth: 3` | Happy Path |
| 3 | back-compat: keys absent | ordinary `no_direct_dependency` rule with `forbidden_patterns`, no new keys | `same_context: false`, `context_depth: 2` (or `context_depth` absent/nil — pick one and pin it); selection/detection unchanged | Control Flow Decisioning |
| 4 | rejects `same_context: true` with no `forbidden_patterns` | `same_context: true`, only `forbidden_modules: [Repo]`, no `forbidden_patterns` | load fails: `{:error, reason}` naming the rule (nothing to scope) | Validation |
| 5 | rejects non-boolean `same_context` | `same_context: "yes"` | `{:error, reason}` | Validation |
| 6 | rejects non-positive `context_depth` | `same_context: true`, `context_depth: 0`, valid `forbidden_patterns` | `{:error, reason}` | Validation |
| 7 | `context_depth` without `same_context` is inert | `context_depth: 3`, no `same_context` | parses; `same_context: false`; `context_depth` ignored at detection (no scoping) | Control Flow Decisioning |

Caveat: rows 4–6 assume config validation surfaces `{:error, _}` on load (the
same channel `Anchor.Config.load/0` already uses). If validation instead drops a
malformed rule, pin that behavior explicitly and keep the "malformed ⇒ never a
silent green no-op" guarantee.

## lib/anchor/domain/checks/no_dependency.ex → `detect_violations/3` (A2)

Signature: `detect_violations(ast, rules, file_context)` where `file_context` is
`[String.t()]` (the file's context segments) or `nil`. The existing
`detect_violations/2` remains as `detect_violations(ast, rules)` delegating with
`file_context: nil` (back-compat).

| # | Test Case | Inputs | Expected Output | Category |
|---|---|---|---|---|
| 1 | same-context dep flagged | file_context `["WaltUi","Contacts"]`; rule `same_context: true`, `context_depth: 2`, `forbidden_patterns: ["WaltUi.*.Managers.*"]`, `match: call`; ast calls `WaltUi.Contacts.Managers.Highlights` | 1 violation on that dep | Happy Path |
| 2 | cross-context dep allowed | same rule; file_context `["WaltUi","Contacts"]`; ast calls `WaltUi.Search.Managers.Index` | 0 violations | Control Flow Decisioning |
| 3 | `same_context: false` ⇒ every pattern match flagged (regression guard) | rule identical but `same_context: false`; ast calls `WaltUi.Search.Managers.Index` | 1 violation | Control Flow Decisioning |
| 4 | absent `same_context` ⇒ identical to `/2` behavior | rule with no `same_context`; ast calls two cross-context Managers | 2 violations (same as `detect_violations/2`) | Control Flow Decisioning |
| 5 | exact `forbidden_modules` ignores scoping | rule `same_context: true`, `forbidden_modules: [WaltUi.Repo]`; file_context `["WaltUi","Contacts"]`; ast calls `WaltUi.Repo` | 1 violation (exact matches never scoped) | Error Handling |
| 6 | dep with fewer than `context_depth` segments | `same_context: true`, depth 2; ast calls a 1-segment module `SomeMod` that matches a pattern | 0 violations (no derivable dep context) | Validation |
| 7 | `file_context: nil` under a `same_context` rule | `same_context: true`; `file_context = nil`; ast calls a matching same-name Manager | 0 violations (no file context to compare) — and document this as the deny-side default | Validation |
| 8 | mixed deps, only same-context reported | `same_context: true`, depth 2; file_context `["WaltUi","Contacts"]`; ast calls `WaltUi.Contacts.Managers.A` and `WaltUi.Search.Managers.B` | 1 violation (Contacts only), reported at the Contacts call's first line | Control Flow Decisioning |
| 9 | deeper depth narrows context | `same_context: true`, `context_depth: 3`; file_context `["WaltUi","Integrations","Processors"]`; ast calls `WaltUi.Integrations.Managers.X` | 0 violations (depth-3 contexts differ) | Control Flow Decisioning |
| 10 | violation line + trigger preserved | any single same-context match | violation `line` = first reference line of the dep, `trigger` = `inspect(dep)` (unchanged from today) | Happy Path |

## lib/anchor/check/no_dependency.ex → `detect_violations/4` (A2)

Signature stays `detect_violations(source_file, ast, rules, context)`; now
derives `file_context` from `context.module_names` and delegates to the domain
`/3`.

| # | Test Case | Inputs | Expected Output | Category |
|---|---|---|---|---|
| 1 | derives file context from the file's own module name | `context.module_names = ["WaltUi.Contacts.Adapters.Foo"]`, `context_depth: 2`, `same_context: true` rule; ast calls `WaltUi.Contacts.Managers.Bar` | 1 Credo issue | Happy Path |
| 2 | cross-context under derived context | same context module; ast calls `WaltUi.Search.Managers.Baz` | 0 issues | Control Flow Decisioning |
| 3 | non-`same_context` rule ⇒ unchanged issues | ordinary Rule-1-style rule (no `same_context`) | issues identical to the pre-feature path for the same ast/rules | Control Flow Decisioning |
| 4 | file defining multiple modules | `context.module_names` lists two modules in the same context | context derived from the first module; same-context deps flagged | Control Flow Decisioning |
| 5 | file with no derivable module name | `context.module_names = []`; `same_context: true` rule | `file_context = nil` ⇒ 0 issues from the scoped rule (no crash) | Error Handling |

## lib/anchor/managers/lint.ex → `run/4` (A2 plumbing)

| # | Test Case | Inputs | Expected Output | Category |
|---|---|---|---|---|
| 1 | threads file module names into check context | a source file defining `WaltUi.Contacts.Adapters.Foo`; a `same_context` rule selecting it | the check receives `context.module_names` including `"WaltUi.Contacts.Adapters.Foo"`; scoped detection runs | Happy Path |
| 2 | facts computed once, selection unchanged | any file + rules | rule selection results identical to before the refactor (no double AST walk regression) | Control Flow Decisioning |
| 3 | non-`same_context` checks unaffected | a transitive-dependency or plain no-dependency run | identical `{:ok, results}` to before | Control Flow Decisioning |

## A3 — docs / dogfood / release (acceptance, not a unit table)

- This matrix committed at the tracked path `docs/gap-f-same-context-test-matrix.md`.
- `same_context` and `context_depth` documented in anchor's config reference
  (`docs/` + README/moduledoc), including the exact-vs-pattern scoping rule and
  the fewer-than-depth edge.
- Dogfood: if anchor's own `.anchor.yml` has a same-context-expressible rule, add
  it; otherwise record why not (anchor is single-context) in the A3 notes.
- `mix compile --warnings-as-errors`, `mix test`, `mix credo --strict` green on
  `main`; a sabotage record (ADR 003) for each new detection branch:
  same-context match, cross-context skip, exact-module-not-scoped, and the
  fewer-than-depth edge.
