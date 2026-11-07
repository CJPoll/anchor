# Anchor

An Elixir library that provides custom Credo checks to enforce architectural constraints on your codebase.

## Overview

Anchor allows you to define rules about module dependencies and usage patterns through a YAML configuration file. It integrates seamlessly with Credo to run as part of your standard code quality checks.

## Features

- **Dependency Constraints**: Prevent modules from depending on specific other modules
- **Transitive Dependency Analysis**: Track and prevent indirect dependencies through the module graph
- **Module Usage Requirements**: Enforce that certain directories must use specific modules
- **Pattern-based Function Restrictions**: Limit what functions modules matching patterns can define
- **Content-based Module Matching**: Apply rules to modules that use specific modules (e.g., all modules using `Ecto.Schema`)
- **Single Control-Flow Enforcement**: Ensure function clauses contain at most one control-flow structure for simpler code
- **No Tuple Pattern Matching in Function Heads**: Prevent coupling by disallowing :ok/:error tuple patterns in function heads
- **Case on Bare Arguments**: Discourage case statements on bare function arguments in favor of function head pattern matching
- **Alphabetized Functions**: Enforce alphabetical ordering of functions with flexible modes (all, public only, or separate public/private)
- **Maximum File Length**: Enforce maximum file length limits to encourage better code organization
- **No Comparison in If**: Enforce descriptive function names instead of direct comparisons in if statements
- **Struct Getter Convention**: Ensure getter functions follow a consistent naming pattern matching the fields they extract
- **Ask before you write**: `mix anchor.explain <path|Module>` prints a module's bucket, context, what it may call and the rules that select it, for a file that does not exist yet too
- **Flexible Configuration**: YAML-based rules with support for umbrella applications

## Installation

Add `anchor` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:anchor, "~> 0.1.0"},
    {:credo, "~> 1.7", only: [:dev, :test], runtime: false}
  ]
end
```

## Configuration

Create an `.anchor.yml` file in your project root:

```yaml
rules:
  - type: no_direct_dependency
    paths:
      - "lib/my_app/web/**/*.ex"
    forbidden_modules:
      - MyApp.Repo
    recursive: true

  - type: no_transitive_dependency
    pattern: "MyApp.Web.*"
    forbidden_modules:
      - MyApp.Repo  # Prevents Web layer from indirectly depending on Repo

  - type: must_use_module
    paths:
      - "lib/my_app/schemas/**/*.ex"
    required_modules:
      - MyApp.Schema
    recursive: true

  - type: module_pattern_restrictions
    pattern: "*.Schemas.*"
    allowed_functions: []  # Only generated functions allowed

  - type: module_pattern_restrictions
    uses_module: "Ecto.Schema"
    allowed_functions: ["changeset", "__changeset__", "__schema__", "__struct__"]

  - type: single_control_flow
    paths:
      - "lib/my_app/**/*.ex"
    recursive: true

  - type: no_tuple_match_in_head
    paths:
      - "lib/my_app/**/*.ex"
    recursive: true

  - type: case_on_bare_arg
    paths:
      - "lib/my_app/**/*.ex"
    recursive: true

  - type: alphabetized_functions
    mode: :separate
    paths:
      - "lib/my_app/**/*.ex"
    recursive: true

  - type: max_file_length
    max_lines: 400
    paths:
      - "lib/my_app/**/*.ex"
    recursive: true

  - type: no_comparison_in_if
    paths:
      - "lib/my_app/**/*.ex"
    recursive: true
```

For umbrella applications, you can place the configuration at the root or in individual apps.

### Where Anchor looks, and what happens when it cannot check

Anchor searches for `.anchor.yml` in the directory credo runs from. Run from an
umbrella app (`apps/<app>`), it also searches the umbrella root. Run from a
directory that holds an `apps/` directory, it also searches two directories up
(a long-standing quirk of the lookup; keep `.anchor.yml` in the directory you
run credo from). The first file found is used, and a "not found" issue names
every path searched.

Anchor **fails closed**: a run that could not check something reports it as a
Credo issue, never as a clean run. Each message says what was searched or what
failed, and ends with a `Fix:` line.

| Condition | Where the issue sits | Example message |
|---|---|---|
| No `.anchor.yml` found | the first searched path | `Anchor found no .anchor.yml, so no Anchor rule was checked. Searched: /proj/.anchor.yml. Fix: ...` |
| `.anchor.yml` exists but cannot be read (for example, it is a directory) | that path | `Anchor could not read /proj/.anchor.yml (:eisdir), so no Anchor rule was checked. Fix: ...` |
| Invalid YAML | that path | `Anchor could not parse /proj/.anchor.yml as YAML, so no Anchor rule was checked: ... Fix: ...` |
| A document or rule Anchor rejects (below) | that path | `Anchor rejected /proj/.anchor.yml, so no Anchor rule was checked: rule 2: unknown rule type "no_direct_dependancy"; known types: ... Fix: ...` |
| A source file that does not parse | that file, at the parser's line | `Anchor could not parse this file, so no Anchor rule was checked against it: ... Fix: ...` |
| Anchor crashed analysing a source file (a defect in Anchor) | that file | `Anchor crashed analysing this file, so no Anchor rule was checked against it: ... Fix: this is a defect in Anchor, not in this file; report it ...` |
| An Anchor check crashed on a source file (a defect in Anchor) | that file | `Anchor check Anchor.Check.NoDependency crashed on this file, so it checked no Anchor rule against it: FunctionClauseError: ... Fix: this is a defect in Anchor, not in this file; report it ...` |
| A rule that selected fewer files than its floor (`min_files`, default 1) | the config file | `Anchor rule 2 (id: "web-no-repo", no_direct_dependency) selected 0 of the 214 files this check ran on, below its floor of 1 (min_files), so it checked nothing. Fix: ...` |
| A rule whose type no enabled Credo check reads | the config file | `Anchor rule 3 (single_control_flow) is not checked: no enabled Credo check reads single_control_flow rules, so it checked nothing. Fix: enable Anchor.Check.SingleControlFlow in .credo.exs, ...` |

The load rejects, rather than silently ignoring:

- a document that is empty, has no `rules:` list, has a top-level key other than
  `rules`, `architecture`, `aggregates` and `sabotage` (for example `anchors:`;
  `aggregates:` is described in [Aggregates](#aggregates-the-aggregates-section-and-the-aggregate_declarations-rule-dnd-5476),
  `sabotage:` in [Sabotage: running the mutants](#sabotage-running-the-mutants)),
  or whose `rules` is not a list. An explicit `rules: []` is a deliberate empty config and loads;
- an `architecture:` section that could check nothing, or less than it says
  (see [The `architecture:` section](#the-architecture-section));
- a rule that is not a mapping, or has no `type`, or a `type` that no Anchor
  check reads (a typo such as `no_direct_dependancy`);
- a key inside a rule that its type does not read (a typo such as
  `forbiden_patterns:`, or a key of another type), and a rule with no selector
  or a selector of the wrong shape. See
  [Keys each rule type accepts](#keys-each-rule-type-accepts). The message
  names the rule's position, the unknown key, the nearest known key and every
  key the type accepts:
  `rule 1: unknown key "forbiden_patterns" in a no_direct_dependency rule
  ("forbiden_patterns": did you mean "forbidden_patterns"?); known keys for
  no_direct_dependency: context_depth, forbidden_modules, ...`;
- an unknown `match` token (`reference` or `call`) or `mode` token (`all`,
  `public_only`, `separate`). A leading colon is accepted on `type`, `match`
  and `mode`, so `mode: :all` means `:all`;
- the `same_context` / `context_depth` errors described under
  [Same-context scoping](#same-context-scoping-same_context--context_depth);
- any other rule that would load but check nothing. See
  [A rule that checks nothing](#a-rule-that-checks-nothing).

A config failure is reported **once per run**, by the first Anchor check in the
enabled list, whichever Anchor checks you enable. So is an unparseable file, and
so is a rule whose type no enabled check reads. A rule below its floor is
reported once per run by the check that reads it. A crash in Anchor's shared
analysis of a file is reported once per run too; a check that crashed on a file
is reported by that check. Either sits on that file, and the other files are
still checked.

### A rule that checks nothing

A rule that loads but checks nothing reads the same as a rule that found
nothing: green. Anchor refuses every such rule it can decide at load, naming the
rule's position (and its `id`, when it has one) and ending with `Fix:`:

- no selector, or **more than one** (`paths` with `pattern`, or `pattern` with
  `uses_module`). Only the first of `paths`, `pattern`, `uses_module` was ever
  read, so the second one narrowed nothing;
- `match` on a rule with neither `forbidden_modules` nor `forbidden_patterns`:
  `forbidden_functions` is matched in every call shape whatever `match` says,
  so nothing reads it;
- `recursive` without `paths` (nothing reads it), or a `recursive` that is not
  `true`/`false`;
- a relation-bearing rule with no **relation**: a `no_direct_dependency` rule
  whose `forbidden_functions`, `forbidden_modules` and `forbidden_patterns` are
  all missing or empty, a `no_transitive_dependency` rule whose
  `forbidden_modules` and `forbidden_patterns` are both missing or empty, or a
  `must_use_module` rule with no `required_modules`. The table below lists each
  type's relation;
- a relation list that is not a list of non-blank strings
  (`forbidden_modules: [""]`, or a bare `-` in YAML);
- a `forbidden_functions` entry that does not name exactly one function
  (`"MyApp.Repo"`, `"MyApp.Repo.*"`, `"MyApp.Repo.insert/x"`);
- an `allowed_callers` entry that is not exactly one Elixir module name: a glob
  (`"*"` allows every caller, so the rule checks nothing), an Erlang module
  (`":ets"`), or a malformed name (`"MyApp.adapter"`, `"MyApp.Repo.insert/1"`);
- an `owned_namespaces: []`, which checks no struct, and an `owned_namespaces`
  entry that is not an exact Elixir module name (a glob, an Erlang module);
- a `pure_patterns` entry of only wildcards (`*`, `**`), which declares every
  module pure;
- an `allowed_functions` entry of only wildcards (`*`, `**`), which allows
  every function. Every other glob character is a literal (see
  [Glob syntax](#glob-syntax)), so `*?` allows the functions ending in `?`, not
  every function;
- a `min_files` that is not a positive integer, an `id` that is not a
  non-empty string, and two rules sharing one `id`.

Three members depend on the files, so they are reported at run time instead:

- **A rule that selects too few files.** Every rule must select at least
  `min_files` of the files its check runs on (default 1). A moved directory
  used to turn a `paths` rule into a silent no-op. `min_files: N` raises the
  floor, like a guard that expects at least 50 modules:

  ```yaml
  - type: must_use_module
    id: contexts-use-base
    paths: ["lib/my_app/contexts/**/*.ex"]
    recursive: true
    min_files: 12
    required_modules:
      - MyApp.Context
  ```

  The floor applies only when credo ran over the whole project. It is skipped
  when files or a subdirectory were named on the command line
  (`mix credo lib/a.ex`), when `--files-excluded` was given, for stdin, and for
  a watch-mode rerun. A file that does not parse still counts for a `paths`
  rule, and counts as possibly selected by a `pattern` or `uses_module` rule
  (its parse error is reported on its own).
- **An allowed caller that no longer exists.** An `allowed_callers` entry that
  no file the rule selects defines allows nothing today, and would silently
  allow whatever module is given that name later. A rename or a move leaves
  the old name behind, so it is an issue on `.anchor.yml`, naming each such
  entry. Like the floor, it is checked only when credo ran over the whole
  project, and it is not reported for a rule that may select a file that does
  not parse. See [Allowing named callers](#allowing-named-callers-allowed_callers).
- **A rule whose check is not enabled.** Credo runs only the checks
  `.credo.exs` enables, so a `single_control_flow` rule does nothing while
  `Anchor.Check.SingleControlFlow` is off. This is skipped when
  `--checks`/`--ignore-checks` narrowed the run on purpose. One case stays
  silent: when **no** Anchor check is enabled, Credo never calls Anchor, so
  nothing can report it.

Each rule type's table of such configs is in
`test/anchor/domain/rule_checks_nothing_test.exs`. **A new rule key or rule
type must add its rows there**, one refused row per way it can make a rule check
nothing, plus a positive row; a test fails until every accepted key has a row.
These issues use `:higher` priority, so they show without `--strict`. They take
that first check's category, so which bit of the exit status they set depends
on which Anchor check is listed first; the exit status is non-zero either way.

A config issue sits on `.anchor.yml`, which is not one of credo's source files.
`mix credo` and `mix credo --strict` print it. `mix credo list` prints issues
per source file, so it omits it, though its exit status is still non-zero.

One limit comes from Credo itself: `mix credo` drops a file it cannot parse
before any check runs, and prints only `Some source files could not be parsed
correctly and are excluded`. Such a file never reaches Anchor, and the run can
still exit 0. `mix compile` fails on it (and `mix test`, for a test file), which
is the gate that catches it. Anchor's own report covers a file handed to a check
directly, as `Credo.Test.Case` and other callers do.

### Selecting which files a rule applies to

Every rule chooses the files it applies to with **exactly one** of three
selectors, tried in this order:

1. `paths` — a list of path globs matched against the file's path. Recursive
   `**` semantics apply when `recursive: true`, single-`*` semantics otherwise.
2. `pattern` — a module-name glob matched against any module the file defines
   (for example `"*.Schemas.*"`).
3. `uses_module` — selects files that `use` the named module (for example
   `"Ecto.Schema"`).

A rule that carries **none** of these selectors would match nothing, so it
fails the load instead of reading green. A rule that carries **two** would be
selected by the first alone, so it fails the load too. So does a selector of the wrong shape,
such as `paths: "lib/a.ex"` (a string, not a list).

Omitting `paths` is meaningful: a rule with no `paths` key is parsed with
`paths: nil` (an *absent* selector), so selection falls through to `pattern` or
`uses_module`. This differs from `paths: []` (an empty list), which is also
treated as "no path selector": valid beside a `pattern` or `uses_module`, and a
load error on its own. In other words, a `pattern`- or
`uses_module`-only rule does **not** need an empty or placeholder `paths` entry
— leave `paths` off entirely and the module selector is honored.

### Glob syntax

`paths`, `pattern`, `forbidden_patterns` and `allowed_functions` take globs. A
glob matches the **whole** string, and has exactly these wildcards:

| Wildcard | In `paths` | In `paths` with `recursive: true` | In `pattern`, `forbidden_patterns` | In `allowed_functions` |
|---|---|---|---|---|
| `*` | any run of characters within one path segment (not `/`) | same | any run of characters, dots included | any run of characters |
| `**` | same as `*` | any number of segments: `lib/**/*.ex` matches `lib/a.ex` and `lib/a/b/c.ex`; `lib/**` matches `lib` and everything under it | same as `*` | same as `*` |

**Every other character is a literal**, including `.`, `?`, `+`, `(`, `)`,
`[`, `]`, `{`, `}`, `|`, `^`, `$` and `\`. There is no `?` single-character
wildcard and no `[abc]` or `{a,b}` alternation. So `lib/c++/*.ex` selects the
`c++` directory, `*.Webs?` matches a module named `Webs?`, and
`allowed_functions: ["*?"]` allows exactly the functions whose names end in `?`.
(Before DND-1292 only `.` was literal, and the rest were live regex: `*?` was a
match-all, and `lib/(old/*.ex` crashed the check.)

### The `architecture:` section

`.anchor.yml` may carry an `architecture:` key beside `rules:` (`rules:` stays
required; a repo with no rules yet writes `rules: []`). It is the one model of
the codebase's architecture that the graph engine (`mix anchor.graph`, DND-5440)
and its placement answers are to read: every project module lands in exactly one bucket, and
the calls matrix says which buckets each bucket may call. A config with no
`architecture:` loads exactly as before.

```yaml
architecture:
  contexts:
    depth: 2                     # the first N module-name segments name the context
  buckets:                       # every project module lands in exactly one
    - name: domain               # unique, lower-case letters and _
      role: domain               # framework | ui | adapters | domain | managers
      select:                    # a module matching any selector is in the bucket
        - paths: ["apps/*/lib/**/domain/**/*.ex"]
      min_modules: 178           # positive integer floor, default 1
      infer: true                # default true
    - name: framework
      role: framework
      select:
        - paths: ["apps/*/lib/**/framework/**/*.ex"]
        - uses_module: GenServer
        - behaviour: Supervisor
        - exports_function: "__aggregate__/0"
        - pattern: "Mix.Tasks.*"
    # ... one bucket per remaining role
  calls:                         # a row per bucket; deny by default
    framework: [framework, ui, domain, managers]
    ui: [ui, domain]
    adapters: [adapters, domain, "managers:other_context"]
    domain: [domain]
    managers: [managers, adapters, domain]
  interfaces:
    buckets: [managers]          # these buckets' modules are their context's interface
    exports: []                  # extra exact module names callable from other contexts
  effects: ["Req", ":gen_tcp.connect"]   # extra effect primitives
  roots:                         # extra roots beyond role=framework buckets' public functions
    - pattern: "Mix.Tasks.*"
  extract_pure_regions_from: [managers, framework]
```

| Key | Required | Default | Meaning |
|---|---|---|---|
| `contexts.depth` | yes | | Positive integer. A module's context is its first `depth` name segments; a module with fewer (or an Erlang module) has none. |
| `buckets` | yes | | Non-empty list. Each bucket has a unique `name` (`[a-z_]+`), a `role` (`framework`, `ui`, `adapters`, `domain`, `managers`) and a non-empty `select` list. |
| `buckets[].select[]` | yes | | Exactly one selector key per entry: `paths` (source-path globs, `**` always recursive), `pattern` (a module-name glob), `uses_module` (a literal `use` in the module's own `defmodule` body), `behaviour` (a declared behaviour; `:gen_server` for an Erlang one), `exports_function` (`"name/arity"`, arity required). |
| `buckets[].min_modules` | no | `1` | Positive integer: the fewest modules the bucket must select. |
| `buckets[].infer` | no | `true` | Boolean: whether placement compares the effects-inferred role. |
| `calls` | yes | | A row for every bucket, and only for buckets. Each value lists the buckets it may call: a bucket name, or `"<bucket>:same_context"` / `"<bucket>:other_context"` to restrict by context. `[]` calls nothing. A call within one module is always allowed; a call to a module outside the project is not a bucket edge. |
| `interfaces.buckets` | no | `[]` | Buckets whose modules are their context's interface. |
| `interfaces.exports` | no | `[]` | Extra modules callable from other contexts, each one exact Elixir module name. |
| `effects` | no | `[]` | Extra effect primitives: a module (`"Req"`, `":gen_tcp"`) or a function (`"File.write!/2"`, `":gen_tcp.connect"`). |
| `roots` | no | `[]` | Extra roots, as selector entries. |
| `extract_pure_regions_from` | no | `[managers, framework]` | Roles whose functions pure-region extraction reads. |

A module matched by one bucket is classified into it. There is no precedence
between buckets, ever: a module two buckets select is **ambiguous** and one no
bucket selects is **unclassified**. Anchor parses and validates the section at
load (below); `mix anchor.graph` (see
[The graph engine](#the-graph-engine-mix-anchorgraph)) classifies every
compiled module against it and reports both, a bucket below its `min_modules`
and an `interfaces.exports` entry that names no module.

An optional key given an empty YAML value (`effects:` with nothing after it)
reads as absent; a required key, or a bucket key, given one is refused.

The load refuses, each with a message that starts with the key path
(`architecture.buckets[1].select[0]`, 0-based indexes) and carries a `Fix:`:

- an unknown key at any level, and a section, `contexts` or `interfaces` that
  is not a mapping;
- a missing `contexts.depth`, or one that is not a positive integer;
- no buckets; a duplicate bucket name or one that is not `[a-z_]+`; an unknown
  `role`; a bucket with no `select` or an empty one; a selector entry with zero
  or two selector keys, an empty `paths` (or an empty glob in it), a `paths`
  glob or `pattern` with no literal character (`**`, `**/*`, `*`, `*.*`), a `uses_module` or `behaviour` that is not one module named
  exactly, an `exports_function` without an arity;
- a `min_modules` that is not a positive integer, an `infer` that is not a
  boolean;
- a missing `calls`, a row for an unknown bucket, a bucket with no row, a row
  that is not a list, an unknown bucket in a row, an unknown scope suffix;
- an `interfaces.buckets` entry naming an unknown bucket; an
  `interfaces.exports` entry that is not one exact Elixir module name (a glob,
  an Erlang module, a blank);
- an `effects` token that names no module or function;
- a `roots` entry refused as a `select` entry would be;
- an `extract_pure_regions_from` entry that is not a role.

### Config schema: rule keys at a glance

A single reference for the rule keys, including the four added for full
five-bucket enforcement. Each is shown with the minimal example that exercises
it; the per-check sections under [Check Types](#check-types) carry the full
semantics and edge cases.

| Key | Applies to | Meaning |
|---|---|---|
| `type` | every rule | Required. One of the rule types under [Check Types](#check-types). A missing or unknown type fails the load. |
| `paths` | any rule | Path-glob selector. **Absent** ⇒ parsed as `nil`, so selection falls through to `pattern`/`uses_module`; this differs only cosmetically from an explicit `[]` (also "no path selector"). A present list selects by path (recursive `**` when `recursive: true`). |
| `pattern` | any rule | Module-name-glob selector (`*` crosses dots). |
| `uses_module` | any rule | Selects files that `use` the named module. |
| `recursive` | any rule with `paths` | `true` gives `paths` globs `**` (across-segment) semantics. Without `paths`, nothing reads it, so it fails the load. |
| `min_files` | any rule | Positive integer, default `1`. The fewest files the rule must select in a whole-project run; fewer is an issue. See [A rule that checks nothing](#a-rule-that-checks-nothing). |
| `id` | any rule | A name for the rule, unique in the file. It appears beside the rule's position in its load errors and floor reports (`rule 2 (id: "web-no-repo", ...)`). A rule with a `baseline` needs one. |
| `enforcement` | any rule | `enforce` (default) or `report` (a leading colon is accepted). A `report` rule's findings print and never fail the run; fail-closed issues still fail. See [Adopting a rule](#adopting-a-rule-report-baseline-enforce-dnd-5441). |
| `baseline` | any rule | A path relative to the project root, no `..` (convention `.anchor/baselines/<id>.txt`): the rule's shrink-only baseline. Needs `id`. A graph rule's is judged by `mix anchor.graph`, an ast rule's by its Credo check and `mix anchor.baseline` (DND-5632). |
| `bucket` | graph rules | Selector: the modules of that `architecture:` bucket. Must name one of its buckets. |
| `min_modules` | graph rules | Positive integer, default `1`: the fewest modules the rule must select; fewer is an issue. A graph rule's floor (`min_files` is refused there). |
| `forbidden_modules` / `required_modules` | `no_direct_dependency`, `no_transitive_dependency` / `must_use_module` | Exact module tokens (see the token syntax below). |
| `forbidden_patterns` | `no_direct_dependency`, `no_transitive_dependency` | Module-name globs; forbids any referenced/reachable module whose name matches. |
| `forbidden_functions` | `no_direct_dependency` | `"Module.function"` or `"Module.function/arity"` tokens; forbids calling (or capturing) that function, in every call shape. A malformed token fails the load. See [Forbidding functions](#forbidding-functions-forbidden_functions). |
| `allowed_callers` | `no_direct_dependency` | Exact module names, default `[]`. Code in a listed module is exempt from every relation of this rule. A glob, an Erlang module or a malformed name fails the load; an entry no selected file defines is an issue. See [Allowing named callers](#allowing-named-callers-allowed_callers). |
| `match` | `no_direct_dependency` | `reference` (default) or `call` — which dependency set the rule inspects. Any other token fails the load. |
| `same_context` | `no_direct_dependency` | Boolean, default `false`. When `true`, a `forbidden_patterns` match is a violation **only if** the dependency shares the checked file's own context. Exact `forbidden_modules` matches are never scoped. |
| `context_depth` | `no_direct_dependency` | Positive integer, default `2`. Number of leading module-namespace segments that define a "context/subdomain". Inert unless `same_context: true`. |
| `allowed_functions` | `module_pattern_restrictions` | Function-name allow-list (globs). |
| `owned_namespaces` | `struct_owned_by_module`, `struct_owned_by_module_flow` | Exact module names, default: every struct. Limits the check to structs equal to or nested under an entry, and reports a selected top-level module outside them. `[]`, a glob, an Erlang module or a malformed name fails the load. See [`struct_owned_by_module`](#struct_owned_by_module). |
| `pure_patterns` | `no_discarded_pure_expression` | Module-name globs, default `[]`: modules whose functions are pure, beside the stdlib pure set. A non-list, a blank entry or a match-all glob (`*`, `**`) fails the load. See [`no_discarded_pure_expression`](#no_discarded_pure_expression). |
| `max_width` | `interface` | Positive integer, optional (DND-5443): a context whose interface exports more public functions is a violation; absent, the width is only printed. `0` or a non-integer fails the load. See [`interface`](#the-interface-rule-dnd-5443). |
| `mode`, `max_lines` | `alphabetized_functions`, `max_file_length` | Style-check parameters. `mode` is `all`, `public_only` or `separate` (a leading colon is accepted); any other token fails the load. |

#### Keys each rule type accepts

A rule may carry only the keys its type reads. Every type accepts its
engine's common keys: an `ast` type `type`, `paths`, `pattern`, `uses_module`,
`recursive`, `min_files`, `id` and `enforcement`; a `graph` type `type`, `id`,
`bucket`, `paths`, `pattern`, `min_modules`, `enforcement` and `baseline`
(DND-5441). The table lists
the keys each type accepts beyond those. Any other key fails the load, and the
message names the rule, the unknown key, the nearest known key and every key the
type accepts. So a misspelling such as `forbiden_patterns:` or `patern:` is an
error, not a rule that silently checks less than it says. A key that belongs to
another type (`match` on a `no_transitive_dependency` rule) is unknown too.

The Engine column is the one engine that runs the type: `ast` rules run as
Credo checks over source, `graph` rules run under `mix anchor.graph` over the
compiled code (DND-5440; `layering`, DND-5442, `context_acyclic`, DND-5445,
`aggregate_declarations`, DND-5476, `aggregate_write_sources`, DND-5459,
`effects_match_bucket`, DND-5447, `function_placement`, DND-5448,
`parameter_reaches_sink`, DND-5470, `reachable_from_root`, DND-5448,
`struct_owned_by_module_flow`, DND-5454,
`analyses_complete`, DND-5715, and `interface`, DND-5443). Credo never reports a
`graph` rule as unchecked.

| Rule type | Keys beyond the common ones | Relation (needs one, non-empty) | Engine |
|---|---|---|---|
| `aggregate_declarations` | none | none | `graph` |
| `aggregate_write_sources` | none | none | `graph` |
| `alphabetized_functions` | `mode` | none | `ast` |
| `analyses_complete` | `min_absent_parameters`, `min_apply_sites`, `min_functions` | none | `graph` |
| `case_on_bare_arg` | none | none | `ast` |
| `context_acyclic` | none | none | `graph` |
| `effects_match_bucket` | none | none | `graph` |
| `function_placement` | none | none | `graph` |
| `interface` | `max_width` | none | `graph` |
| `layering` | none | none | `graph` |
| `max_file_length` | `max_lines` | none | `ast` |
| `module_pattern_restrictions` | `allowed_functions` | none | `ast` |
| `must_use_module` | `required_modules` | `required_modules` | `ast` |
| `no_comparison_in_if` | none | none | `ast` |
| `no_direct_dependency` | `allowed_callers`, `context_depth`, `forbidden_functions`, `forbidden_modules`, `forbidden_patterns`, `match`, `same_context` | `forbidden_functions`, `forbidden_modules`, `forbidden_patterns` | `ast` |
| `no_discarded_pure_expression` | `pure_patterns` | none | `ast` |
| `no_discarding_arrow_in_with` | none | none | `ast` |
| `no_forwarding_function` | none | none | `ast` |
| `no_transitive_dependency` | `forbidden_modules`, `forbidden_patterns` | `forbidden_modules`, `forbidden_patterns` | `ast` |
| `no_tuple_match_in_head` | none | none | `ast` |
| `parameter_reaches_sink` | none | none | `graph` |
| `reachable_from_root` | none | none | `graph` |
| `single_control_flow` | none | none | `ast` |
| `struct_getter_convention` | none | none | `ast` |
| `struct_owned_by_module` | `owned_namespaces` | none | `ast` |
| `struct_owned_by_module_flow` | `owned_namespaces` | none | `graph` |

Every rule also needs exactly one **selector**: a non-empty `paths` list, a
`pattern` string or a `uses_module` string. A rule with none selects no file,
and a rule with two reads only the first, so both fail the load. `recursive`
alone is not a selector, and neither is `paths: []`. A selector of the wrong
shape fails the load too: `paths` must be a list of strings, and `pattern` and
`uses_module` must be non-empty strings.

A rule of a type with a **relation** (the last column) must carry at least one
of its relation keys as a non-empty list, or it checks nothing and fails the
load. A type with `none` has nothing to require: it checks every file it
selects, or (`module_pattern_restrictions`) an empty allow-list forbids every
function.

The allowlist and the relations live in one place, `Anchor.Domain.RuleSchema`.
A new key is added there, to its type's list (and to its relation list, if the
rule checks against it), to this table, and to its type's rows in
`test/anchor/domain/rule_checks_nothing_test.exs`. A test compares this table
with the module, and another fails until the new key has a row.

**`forbidden_patterns` — module-name globs (dot-bounded).** A `*` crosses dots,
so `*.Adapters.*` matches `MyApp.Contacts.Adapters.Repository`, but the `.`
between segments is literal, so the pattern is dot-bounded: it matches a
`.Adapters.` segment and does **not** match `Foo.AdaptersHelper`. A module name
matches in its alias form (`MyApp.Web.Foo`) and its fully-qualified form
(`Elixir.MyApp.Web.Foo`), so `MyApp.Web.*`, `Elixir.MyApp.Web.*` and `*.Web.*`
all match it. (Before DND-1290 only the fully-qualified form was tried, so a
pattern such as `MyApp.Web.*` matched nothing.) The same holds for the
`pattern` selector.

```yaml
- type: no_direct_dependency
  pattern: "*.Domain.*"
  forbidden_patterns:
    - "*.Adapters.*"   # forbid any module with a `.Adapters.` segment
```

**`match` — `call` vs `reference` (default `reference`).** `reference` flags a
forbidden module named in **any** position (a call, a value held in a map or
keyword list, a typespec). `call` flags it only when it is actually **called**
(`Foo.Adapters.L.enrich(x)` or `apply(Foo.Adapters.L, :enrich, [x])`) — a module
merely held as an atom passes. This is the "Domain-router-holds-atoms" carve-out.

```yaml
- type: no_direct_dependency
  pattern: "*.Domain.Router"
  forbidden_patterns:
    - "*.Adapters.*"
  match: call          # `%{yaml: Foo.Adapters.L}` passes; `Foo.Adapters.L.run()` fails
```

**Leading-colon `:atom` module syntax.** A `forbidden_modules` /
`required_modules` token that starts with `:` names an Erlang/OTP module and is
kept as the raw atom (via `String.to_atom`, **not** `Module.concat`), so it
matches a bare-atom remote call. Quote it so YAML keeps it a string.

```yaml
- type: no_direct_dependency
  paths: ["lib/my_app/domain/**/*.ex"]
  recursive: true
  forbidden_modules:
    - ":telemetry"     # matches `:telemetry.execute(...)`
    - MyApp.Repo       # CamelCase token stays an Elixir alias
```

**Paths-absent selection (`paths: nil`).** Omitting `paths` entirely is
meaningful: the rule parses with `paths: nil`, so a `pattern`- or
`uses_module`-only rule selects by its module selector instead of being shadowed
by an empty path list. The `forbidden_patterns` example above (no `paths` key)
relies on exactly this.

## Usage

Configure Credo to use the custom checks in `.credo.exs`:

```elixir
%{
  configs: [
    %{
      name: "default",
      checks: %{
        enabled: [
          # ... other checks ...
          {Anchor.Check.NoDependency, []},
          {Anchor.Check.NoTransitiveDependency, []},
          {Anchor.Check.MustUseModule, []},
          {Anchor.Check.ModulePatternRestrictions, []},
          {Anchor.Check.SingleControlFlow, []},
          {Anchor.Check.NoTupleMatchInHead, []},
          {Anchor.Check.CaseOnBareArg, []},
          {Anchor.Check.AlphabetizedFunctions, []},
          {Anchor.Check.MaxFileLength, []},
          {Anchor.Check.NoComparisonInIf, []},
          {Anchor.Check.StructGetterConvention, []},
          {Anchor.Check.NoDiscardedPureExpression, []},
          {Anchor.Check.NoForwardingFunction, []},
          {Anchor.Check.StructOwnedByModule, []}
        ]
      }
    }
  ]
}
```

Then run:

```bash
mix credo --strict
```

## The graph engine: `mix anchor.graph`

```bash
mix anchor.graph [--format text|json] [--only RULE_ID]... [--base REF]
                 [--write-baseline RULE_ID] [--project DIR] [--verbose]
```

Judges the project's compiled code against `.anchor.yml`'s `architecture:`
section and every enabled graph rule. It compiles the project, reads every
beam of every app (an umbrella's every `apps/*` app) with `:beam_lib` only, and
builds the causal graph fresh every run: it never loads or runs a project
module and never reads a cached verdict. Then it classifies every module into
exactly one bucket, checks every floor, and runs each graph rule under its own
guard. It is the command a CI step or a pre-commit gate runs after `mix
compile`; Anchor's own CI runs it. Run it from the umbrella root: Mix compiles
each app from its own directory, so a beam's source path is app-relative
(`lib/alpha.ex`), and the runner keys it from the umbrella root
(`apps/alpha/lib/alpha.ex`) for `paths:` selectors, issues and baselines
(DND-5637).

Text output is one line per finding, then a summary:

```
lib/my_app/stray.ex:1: [enforce] anchor.graph MyApp.Stray is in no architecture bucket. Fix: add a selector that matches lib/my_app/stray.ex to the bucket this module belongs in (mix anchor.explain lib/my_app/stray.ex shows the candidates).
anchor.graph: 214 modules in 1 apps, 0 rules, 1 violations (0 report-only, 0 baselined)
```

A graph rule takes the graph common keys (DND-5441): `type`, `id`, exactly
one selector of `bucket` (an `architecture:` bucket's modules), `paths`
(source globs, `**` always recursive) or `pattern` (a module-name glob),
`min_modules` (default 1), `enforcement` (`enforce`, the default, or `report`)
and `baseline` (below). Every graph rule needs the `architecture:` section,
and a `bucket` must name one of its buckets; both are refused at load
otherwise. `uses_module`, `recursive` and `min_files` are `ast` keys and are
refused on a graph rule. A finding of a rule with `enforcement: report` prints
`[report]` and does not fail the run. `--format json` prints `{"modules",
"apps", "rules", "opaque", "no_core", "outside_root", "apply_sites", "interface_width",
"dynamic_calls", "effects", "demand", "parameter_sinks", "aggregates", "writes", "exit_code",
"findings":
[{rule_id, type, enforcement, key, file, line, message, fix}],
"could_not_check": [...], "refused": [...], "held": [...]}`. `--only RULE_ID` (repeatable) runs only the
rules with those ids; each rule that runs is still judged against its floor and
its baseline (`--only` narrows the rules, never the modules), and an id that
names no graph rule is COULD NOT MEASURE.

### Adopting a rule: report, baseline, enforce (DND-5441)

A rule a codebase does not meet yet is adopted in three steps, and its
findings can only shrink along the way:

1. **Report.** `enforcement: report` prints every finding as `[report]` and
   never fails on them (fail-closed issues still fail). An `ast` rule in report
   mode gives Credo issues with exit status 0 and low priority, so `mix credo
   --strict` lists them and still passes.
2. **Baseline.** Give the rule an `id` and `baseline:
   .anchor/baselines/<id>.txt`, then run `mix anchor.graph --write-baseline
   <id>` (a graph rule) or `mix anchor.baseline --write <id>` (an ast rule):
   it writes the rule's current finding keys, sorted, and refuses (exit 2)
   when the file exists. Review the file in the change that adds it.
3. **Enforce.** Drop `enforcement: report`. A finding the baseline holds is
   counted (`<H> baselined`; `--verbose` prints each as `[held]`). A finding
   it does not hold (NEW) fails. A baseline line no finding matches (STALE)
   fails, with `Fix: delete that line`. With `--base REF`, every line the
   branch added to the baseline since `REF` fails as GREW, read from `REF`
   with git, never from the branch: a baseline only shrinks, and adding to it
   is a review decision on the base branch. A baseline absent at `REF` is a
   first landing, printed as a NOTE.

**The base branch judges a pull request (DND-5658).** `--base` reads the
baselines at `REF`, but the code that compares them (`Enforcement`,
`Baseline`, `BaselineBase`, each rule's `check/2`) is the
code that runs. In Anchor's own CI that is the pull request's code, so a pull
request could change the judge that judges it. CI therefore also runs
`bin/ci/judge-with-base.sh origin/<base>`: it takes `bin/ci/base-judge.sh` as
it is on the base branch (never the pull request's copy), which checks the
base out in a scratch worktree, builds it, compiles the pull request under
`MIX_ENV=dev`, and runs the base's `mix anchor.graph --project <pull request>
--base origin/<base>`. `--project DIR` judges the checkout at `DIR` (its
`.anchor.yml`, sources, baselines, git, and its beams at this checkout's
compile path relative to its root) with the Anchor of the checkout it runs
in; it refuses (exit 2) a `DIR` that is not a directory, an umbrella judge, a
build path outside the judge's own root, and `--write-baseline`. A base that
cannot be checked out or built, a pull request that does not compile, and a
judge that exits other than 0 or 1 are exit 3 (COULD NOT MEASURE), never a
pass. The landed judge (`--project`) loads the config with rule types it does
not know set aside, and judges by the BASE's config: every rule the base has as
the base defines it (its selector, keys and enforcement), plus the pull
request's rules the base does not have, all under the base's `architecture:`
and `aggregates:`. So a pull request that widens the calls matrix, moves a
module to another bucket or lowers a floor in `.anchor.yml` fails this step
when its code relies on that; the owner lands such a change. Per rule id:

| The pull request's rule | Landed judge | Exit |
|---|---|---|
| on the base, same type, only keys the base knows | ratchets the base's definition, as `--base` does | 0 / 1 |
| new, of a type the base does not know | `NOTE: FIRST LANDING ...`, report-only; the pull request's own `--base` step judges it | 0 |
| new, of a type the base knows | judged, its baseline a first landing | 0 / 1 |
| on the base, removed or renamed by the pull request | fails: a check removed | 1 |
| on the base, its type changed | fails: a check replaced | 1 |
| on the base, with a key the base does not know | COULD NOT MEASURE | 3 |
| any, beside a top-level section the base does not know | COULD NOT MEASURE | 3 |
| on the base, narrowed (a smaller selector, `enforcement: report`) with its baseline shrunk or grown to match | the base's definition still finds it: NEW or GREW | 1 |
| on the base, its new entry excused by a `narrows?/2` the pull request changed | the base's `narrows?/2` decides: GREW | 1 |
| any, with a `.anchor.yml` at the base that cannot be read | COULD NOT MEASURE | 3 |
| any, with `architecture:` or `aggregates:` changed | the base's sections are the ones judged: NEW, STALE or a bucket floor where the code relies on the change | 0 / 1 |

The refused rows are landed by the owner. The pull request's own `mix anchor.graph --base` step still runs:
it is the product under test. A base with no `bin/ci/base-judge.sh` prints
`BOOTSTRAP` and exits 0 only for a pull request whose diff adds the script;
any other pull request into such a base is exit 3. Self-test: `bin/tests/base-judge-test.sh` (CI job `Base judge
self-test`). Not caught: a pull request that edits `.github/workflows/ci.yml`
or `bin/ci/judge-with-base.sh` itself (GitHub runs the pull request's
workflow), and build-time code a deliberately hostile pull request runs
earlier in the same CI job; review is the gate for those. This guards
`mix anchor.graph` against a change to `lib/`, not against an attacker who
controls the job; `mix anchor.baseline --base` and `mix credo` still run the
pull request's own code, and a behaviour from a dependency the pull request
adds reads as having no callbacks here (the judge has the base's deps), so its
own `--base` step alone sees those implementations as roots.

A baseline file holds one key per line; `#` comments and blank lines are
ignored and the entries are a multiset (a key listed twice holds two
findings). A key is `<rule id>|<subject>|<detail>` (or `<rule id>|<subject>`
for a finding with no target, such as a `context_acyclic` cycle), such as
`layering|MyApp.Web.Page.show/2|-> MyApp.Repo.get/2`: no line numbers and no
message text, so moving code does not churn it. Every entry starts with the
rule's id; a file holding another rule's entry is refused.

### Baselines for ast rules (DND-5632)

An `ast` rule (a Credo check) takes the same `baseline:` and the same
ratchet. Its key is `<rule id>|<file>|<trigger>`, the file relative to the
project root and the trigger the check highlights (the forbidden module, the
function), such as `pure|lib/my_app/domain/order.ex|File`: no line and no
message, so moving code within a file does not churn it.

* **Every `mix credo` run** compares the rule's findings with its baseline,
  inside the rule's own check: a held finding is dropped, a NEW one stands,
  and a line no finding matches is a STALE issue on the baseline path (exit
  status 0 for a `report` rule). A baseline that cannot be read, or holds
  another rule's entry, is one issue there, and every finding stands.
* **A narrowed run** (`mix credo lib/a.ex`, `--files-included`, a watch
  rerun) judges only the lines on files it read: a line on a file it did not
  read, or could not parse, is not STALE, and one report-only NOTE counts
  them (`NOTE: 2 entries of .anchor/baselines/pure.txt name a file this run
  did not read or could not parse, so they were not judged STALE. Fix: run
  mix credo over the whole project ...`). A whole run judges every line, so
  a line on a deleted file is STALE.
* **`mix anchor.baseline --write <id>`** compiles the project, runs Credo
  over the whole file set (its report is not printed) and creates the rule's
  baseline from its finding keys, sorted. It only creates (exit 2 when the
  file exists). A rule whose check `.credo.exs` does not enable has no
  findings, so it writes nothing: COULD NOT MEASURE (exit 3).
* **`mix anchor.baseline --base REF`** fails every line the branch added to
  an ast rule's baseline since `REF` (GREW), found by the rule's id in the
  config at `REF`, exactly as `mix anchor.graph --base` judges a graph
  rule's (the first-landing NOTEs and the read failures are the same). CI
  runs it on a pull request. It prints one line per finding and
  `anchor.baseline: <B> ast baselines, <V> violations (<P> report-only)`.
  Exit codes: 0 pass or written, 1 GREW or an unreadable/unwritable
  baseline, 2 usage or a refused write, 3 COULD NOT MEASURE.

### The `layering` rule (DND-5442)

```yaml
rules:
  - type: layering
    id: layering
    paths: ["lib/**/*.ex"]

architecture:
  contexts:
    depth: 2
  buckets:
    - name: framework
      role: framework
      select:
        - paths: ["lib/my_app_web/**/*.ex"]
    - name: managers
      role: managers
      select:
        - paths: ["lib/my_app/managers/**/*.ex"]
    - name: adapters
      role: adapters
      select:
        - paths: ["lib/my_app/adapters/**/*.ex"]
    - name: domain
      role: domain
      select:
        - paths: ["lib/my_app/domain/**/*.ex"]
  calls:
    framework: [framework, managers, domain]
    managers: [managers, adapters, domain]
    adapters: [adapters, domain]
    domain: [domain]
```

`layering` enforces the `architecture: calls` matrix over compiled code: every
call from a module the rule selects to another classified module of the
project must land in a bucket the caller's row allows, with the row's scope
(`same_context`, `other_context`). Anything a row does not list is denied.
Because it reads beams, a call a macro injects (`use MyApp.Web` expanding
into a `def` that calls `MyApp.Repo`) is the using module's call: the AST rule
`no_direct_dependency` cannot see it. A capture (`&M.f/1`) and `apply/3` with
a literal module are calls too.

- A call within one module is allowed. A call to a module outside the
  project (the standard library, a dependency) is not a bucket edge. A call
  to an unclassified module is skipped: the runner already reports that
  module.
- A dynamic call (`mod.fetch(x)`) resolves to every project module that
  exports `fetch/1` (a `def`), and each one is judged as a static call: any
  of them can be the receiver, whether it declares a `@behaviour` or not.
  When no project module exports it (`Mix.shell().info(msg)`), the call
  reaches no bucket of the project, and there is nothing to judge.
  The one narrowing is declared (DND-5633): when the receiver is a parameter
  the function's one `@spec` types as `B.t()`, where `B` is a project module
  with `@type t :: module()` and the function among its `@callback`s, the call
  is judged against the modules that declare `@behaviour B` and export it.
  A `@spec` is a declaration Dialyzer checks, not Anchor. Never on the
  function name alone. Each run ends its summary with `; dynamic calls: <f>
  fanned out to every exporter, <n> narrowed by behaviour`, and the JSON's
  `dynamic_calls` names each (`"MyApp.M.run/2 -> ?.fetch/1"`).
- A call whose function name is computed (`apply(MyApp.Repo, op, args)`,
  `mod.op_var(x)`, `&MyApp.Repo.op_var/1`) is one violation too, keyed
  `-> dynamic ?/n`: its target cannot be checked. Only applying a variable
  (`fun.(x)`) is a closure application, not judged by this rule; `apply(fun,
  args)` compiles to the same shape as `apply/3` with a computed name, so it
  is reported, and `fun.(args)` is the form that is not.
- Under `--base`, a `context_acyclic` cycle entry the branch replaced with a
  strict subset of its contexts (one edge of the cycle was broken) is a
  report-only NOTE, not GREW: a narrower entry is not growth (a rule's
  `narrows?/2`, DND-5633).
- One violation per caller function and callee function, at the first such
  call's line, keyed `<id>|<Caller.f/a>|-> <Callee.g/b>` (an unresolved call
  is `-> dynamic fetch/1`). The message names both modules' bucket and
  context and the caller's row, and the `Fix:` names the route through the
  matrix (`framework -> managers -> adapters`), the row's scope when only the
  scope forbids it, or "no route".

```
lib/my_app/web/page.ex:12: [enforce] rule 1 (id: "layering", layering) MyApp.Web.Page.show/2 (framework, MyApp.Web) calls MyApp.Repo.get/2 (adapters, MyApp.Repo); framework may call: framework, managers, domain. Fix: route it through managers: framework -> managers -> adapters (call a managers module of the right context, which calls adapters); framework may not call adapters directly.
```

Anchor's own `.anchor.yml` runs it over `lib/` with a baseline,
`.anchor/baselines/layering.txt`, holding what it found when it landed.

### The engine split: `layering` is the authority (DND-5491)

Layering is a property of what the program does, so the graph engine is its
authority: `layering` judges every call the compiler produced, including
calls a macro injects. The AST dependency rules, `no_direct_dependency` and
`no_transitive_dependency`, stay as its **write-time early warnings**: they
run before compile (in a pre-write hook, on one file), with the exact line
of the reference. `Anchor.Domain.RuleSchema.early_warning_of/1` declares the
pairing, and compilation fails if an early warning names anything but an
ast type warning of a graph type.

| Rule type | Engine | Role |
|---|---|---|
| `layering` | graph | the authority on which bucket may call which |
| `no_direct_dependency` | ast | early warning of `layering` |
| `no_transitive_dependency` | ast | early warning of `layering` |

The two are held equal by a test, not by trust.
`test/anchor/integration/layering_parity_test.exs` runs both engines over the
macro-free tree `test/fixtures/parity/` (five buckets, two contexts: allowed
calls, forbidden direct calls through an alias, a capture and `apply/3` with
a literal module, a forbidden transitive chain, `other_context` allowed and
refused). The AST rules come from the tree's own `architecture:` section
(`Anchor.Domain.Parity.ast_rules_for/1`: each row forbids the buckets it
omits, directly and transitively, and an `other_context` entry forbids its
bucket within the caller's context). Any `(caller, callee)` pair one engine
flags and the other does not fails the test, naming the pair and the engine
that flagged it; a transitive AST finding must pass through a call the graph
flags. The derivation needs `pattern:` bucket selectors and a matrix with no
`same_context` entry (no AST rule can say "only outside the caller's
context"); anything else raises.

Known divergences are listed in the test with a reason each, and the list
only shrinks (a listed pair that no longer diverges fails the test). At
landing it holds one: a dynamic call (`mod.save(x)`), which the graph
resolves to every module exporting `save/1` and the AST cannot see.

### The `context_acyclic` rule (DND-5445)

```yaml
rules:
  - type: context_acyclic
    id: context_acyclic
    paths: ["lib/**/*.ex"]

architecture:
  contexts:
    depth: 2
  buckets:
    - name: domain
      role: domain
      select:
        - paths: ["lib/**/*.ex"]
  calls:
    domain: [domain]
```

A cycle between contexts leaves the causal order between them undefined.
`context_acyclic` collapses the calls of the modules it selects into a context
graph: a call from one context to another (both known and different) is an
edge `A -> B`, and a dynamic call on a computed module is an edge to the
context of every project module exporting that function. Each strongly
connected component of more than one context is one violation; a context
calling itself is not a cycle. A call whose function name is computed
(`apply(MyApp.Repo, op, args)`) hides which contexts it reaches, so the rule
reports it too, one violation per caller function keyed
`<id>|<Caller.f/a>|-> dynamic ?/n`, whatever other rules the config runs; a
closure application (`fun.(x)`) is not.

The message lists every edge inside the cycle with one call that makes it,
and names the edge to invert: the one with the fewest calls (ties: the
lexically first), at its first call's line. Inverting `X -> Y` removes X's
dependency on Y: X publishes an event Y subscribes to, or X declares the
function it needs in an interface it owns and Y implements it. The key is
`<id>|<the cycle's contexts, sorted, joined by ",">`, so it stays the same
while the cycle's members do.

```
lib/my_app/billing/manager.ex:40: [enforce] rule 1 (id: "context_acyclic", context_acyclic) contexts MyApp.Billing, MyApp.Orders form a cycle: MyApp.Billing -> MyApp.Orders (MyApp.Billing.Manager.charge/1 calls MyApp.Orders.Manager.get/1), MyApp.Orders -> MyApp.Billing (MyApp.Orders.Manager.place/1 calls MyApp.Billing.Manager.charge/1). Fix: invert MyApp.Billing -> MyApp.Orders (its 1 call is the fewest): have MyApp.Billing publish an event MyApp.Orders subscribes to, or declare the function MyApp.Billing needs in an interface MyApp.Billing owns and have MyApp.Orders implement it.
```

Anchor's own `.anchor.yml` runs it over `lib/`, with a baseline holding what
it found when it landed: one cycle through the dynamic calls of
`Anchor.Managers.Lint` on the check modules, and `Mutator`'s `apply/3`.

### The `interface` rule (DND-5443)

```yaml
rules:
  - type: interface
    id: interface
    paths: ["lib/**/*.ex"]
    max_width: 40            # optional

architecture:
  contexts:
    depth: 2
  buckets:
    - name: managers
      role: managers
      select:
        - paths: ["lib/**/managers/**/*.ex"]
    - name: domain
      role: domain
      select:
        - paths: ["lib/**/domain/**/*.ex"]
  calls:
    managers: [managers, domain]
    domain: [domain]
  interfaces:
    buckets: [managers]      # a managers module is its context's interface
    exports: [MyApp.Accounts.Api]
```

A call from one context into another lands only on that context's interface:
a module of an `interfaces.buckets` bucket, or one listed in
`interfaces.exports`. This is Anchor's replacement for Boundary's exports and
deps: Anchor neither reads nor requires Boundary, and a repo may run both.
Every module is classified, so no module is left outside a boundary.
Widening an interface (`exports`, `interfaces.buckets`) removes findings
rather than adding baseline entries, so GREW does not see it: it is an
ordinary config change, and review is its gate.

Calls are resolved as `layering` resolves them, apps are not a bypass (a call
from another app of an umbrella is judged the same), and a call within one
context is not judged here. Each forbidden (caller function, callee function)
is one violation keyed `<id>|<Caller.f/a>|-> <Callee.g/b>`; its `Fix:` names
the one interface module that reaches the callee inside its context, or lists
the context's interface modules. A module with no context (fewer name segments
than `contexts.depth`) that calls or is called across contexts is one violation
keyed `<id>|<Mod>|no context`: its boundary cannot be checked, which is never
a pass. A call whose function name is computed is one violation too.

The run summary ends with each context's interface width, the public functions
its interface modules export (functions the compiler generates not counted),
and `--format json` carries it as `interface_width`. With `max_width: n`, a
context of a selected module whose width is above `n` is a violation on the
config, keyed `<id>|<context>|width`.

```
lib/my_app/billing/invoice.ex:12: [enforce] rule 1 (id: "interface", interface) MyApp.Billing.Invoice.issue/1 (context MyApp.Billing) calls MyApp.Accounts.User.name/1, which is not part of context MyApp.Accounts's interface. Fix: call MyApp.Accounts.Users instead.
anchor.graph: 40 modules in 1 apps, 1 rules, 1 violations (0 report-only, 0 baselined); interface width: MyApp.Accounts=6, MyApp.Billing=3
```

Anchor's own `.anchor.yml` runs it over `lib/` with a baseline. Its depth-2
contexts are its buckets, so `interfaces.buckets` names every bucket but
framework there, and the baseline holds what it found when it landed: the
calls of `Anchor.Managers.Lint` into the check modules (DND-1288),
`GraphRules.by_type/1`'s calls of each check's `rule_type/0`, the top-level
`Anchor` module (no context at depth 2), `Mutator.generate/4`'s dynamic call,
and the sabotage task starting `CoverageCollector`. The `.anchor.yml` comment
on the rule names the same groups.

### The `effects_match_bucket` rule (DND-5447)

```yaml
rules:
  - type: effects_match_bucket
    id: effects_match_bucket
    paths: ["lib/**/*.ex"]

architecture:
  contexts:
    depth: 2
  buckets:
    - name: domain
      role: domain
      select:
        - paths: ["lib/**/domain/**/*.ex"]
    - name: adapters
      role: adapters
      select:
        - paths: ["lib/**/adapters/**/*.ex"]
  calls:
    domain: [domain]
    adapters: [adapters, domain]
  effects: ["Req", ":gen_tcp.connect"]   # effects beyond the defaults
  roots:
    - pattern: "Mix.Tasks.*"             # entry points beyond the defaults
```

A function's bucket follows from what it causes. `mix anchor.graph` infers
every function's role from the compiled code (`Anchor.Domain.Effects`):

- **framework** when it is a root: a public function of a `framework` bucket,
  a function of a module an `architecture.roots` selector matches, or a
  callback of a behaviour defined outside the project (`GenServer`,
  `Mix.Task`, `Inspect`, ...);
- else **adapters** when it calls an effect primitive, itself or through
  functions of its own module (an adapter's public function that delegates to
  its private helper stays an adapter);
- else **managers** when it reaches an effect through another project
  module's function, or reaches a call Anchor cannot resolve;
- else **domain**.

The effect primitives are every function of `File`, `IO`, `Logger`,
`:logger`, `:telemetry`, `System`, `Process`, `Port`, `Node`, `GenServer`,
`Agent`, `Task`, `Task.Supervisor`, `Registry`, `:ets`, `:dets`,
`:persistent_term`, `:gen_tcp`, `:gen_udp`, `:ssl`, `:httpc`, `:os` and
`:file`; `send`, `spawn*`, the process dictionary; the clock reads
(`DateTime.utc_now/now/now!`, `NaiveDateTime.utc_now/local_now`,
`Time.utc_now`, `Date.utc_today`, `System.system_time/monotonic_time/os_time`,
`:os.timestamp/system_time/perf_counter`, `:erlang.timestamp/now/time/date/
localtime/universaltime/system_time/monotonic_time/time_offset`,
`:calendar.local_time/universal_time`) and the random draws (every function of
`:rand` and `:random`, `Enum.random/1`, `Enum.take_random/2`, `Enum.shuffle/1`,
`:crypto.strong_rand_bytes/1`, `:crypto.rand_seed`, `System.unique_integer`),
DND-5677: a chain that ends in one says so in the `Fix:` ("reads the clock",
"draws a random value"); and every project module declaring `@behaviour
Ecto.Repo`. `IO.iodata_to_binary/1`, `IO.iodata_length/1` and
`IO.chardata_to_string/1` are pure and no primitive, by exact name and arity
(DND-5678). `architecture.effects` adds to them; nothing removes one. A call is
matched by every name it may have been written as (`System.unique_integer/0`
reaches Core as `:erlang.unique_integer/0`, DND-5613).

A call on a computed module reaches every project module exporting the
function; with none it is unresolved. A call whose function name is computed
is unresolved. A closure application (`fun.(x)`, and the call inside
`Enum.map(list, fun)`) reaches the closures the higher-order flow analysis
finds there, and is unresolved where it finds a value from outside the
project. A comprehension's collector (`for ..., into: target`) applies
nothing to resolve when the target is a literal (no struct but a `MapSet`)
or a `Map.new`/`MapSet.new`
the function builds itself; into any other target (a parameter, which may be
an `IO.stream/0`), it is unresolved. A call of a project function whose body
Anchor did not read is unresolved too, naming the function and why (DND-5679):
a function of a project module the graph could not decode (an Erlang module,
`{:not_elixir, _}`, or a beam whose debug info is stripped) or a public
function with no Core body. **An unresolved call counts as an effect**: it never makes a
function look pure, and the run prints how many there were.

For each module the rule selects in a bucket of role `domain`, `adapters` or
`managers` with `infer: true` (the default), each public function that is not
a root must infer its bucket's role. Not judged: `framework` and `ui`
buckets, private functions, roots, and compiler-named functions
(`__struct__/1`). A bucket the rule selects modules of with no public function
analysed is below the rule's floor, an issue. A mismatch is one violation per
function at its def line, keyed `<id>|<Mod.fun/arity>|<inferred role>`, naming
the evidence: the call chain to the first effect, or that none is reachable.

```
lib/my_app/orders/pricing.ex:12: [enforce] rule 4 (id: "effects_match_bucket", effects_match_bucket) MyApp.Orders.Pricing.total/1 is in bucket domain (domain) but reaches an effect. Fix: move MyApp.Orders.Pricing.total/1 to the managers bucket of MyApp.Orders: MyApp.Orders.Pricing.total/1 -> MyApp.Orders.Rates.load/0 -> File.read!/1
```

The summary adds `; effects: <n> functions (domain <a>, managers <b>, adapters
<c>, framework <d>), <u> unresolved dynamic calls`. Anchor's own `.anchor.yml`
runs it over `lib/` with a baseline holding what it found when it landed.

### The `analyses_complete` rule (DND-5715)

Declares that the whole-program analyses finish over your project. It reads the
higher-order flow analysis and the demand analysis (`Anchor.Domain.Demand`), so
the run computes both once. Each of these is a fail-closed issue on the config,
never held by a baseline and never report-only:

- the flow analysis hit its step bound (every apply site reads `any`);
- the demand analysis hit its round bound on some component (its parameters
  read as used without being judged);
- a selected module has a `def` or `defp` with a Core body and no demand summary;
- the analyses judged fewer than a floor it declares.

```yaml
rules:
  - type: analyses_complete
    id: analyses_complete
    paths: ["lib/**/*.ex"]
    min_modules: 100
    min_functions: 500          # functions the demand analysis summarised
    min_apply_sites: 100        # apply sites the flow analysis counted
    min_absent_parameters: 1    # parameters it judged unused

architecture:
  contexts:
    depth: 2
  buckets:
    - name: domain
      role: domain
      select:
        - paths: ["lib/**/*.ex"]
  calls:
    domain: [domain]
```

The summary adds `; demand: <f> functions, <p> parameters, <a> absent, <i>
imprecise functions`, with `(round bound hit on <n> functions)` after it if the
analysis hit its bound, and the JSON's `demand` holds the same counts (`null`
when no rule that runs needs it). The bounds and floors are over the whole
program, since an analysis runs over all of it; the selector narrows only whose functions must be summarised. Each
floor is optional, a positive integer, and has no default: without it, that
count is not judged. A rule that reads the demand analysis declares `needs:
[:cfa, :demand]` in its module (`Anchor.Domain.GraphRule`). Anchor's own
`.anchor.yml` declares this rule, so CI's `mix anchor.graph` is the whole-Anchor
run of both analyses.

### The `struct_owned_by_module_flow` rule (DND-5454)

```yaml
rules:
  - type: struct_owned_by_module_flow
    id: struct_owned_by_module_flow
    paths: ["lib/**/*.ex"]
    owned_namespaces: ["MyApp"]   # optional, as in struct_owned_by_module

architecture:
  contexts:
    depth: 2
  buckets:
    - name: domain
      role: domain
      select:
        - paths: ["lib/**/*.ex"]
  calls:
    domain: [domain]
```

The graph half of struct ownership. `struct_owned_by_module` (above, under
the AST rules) decides what one file's text shows; this rule reads the
compiled code, so it knows what a value is from the typespecs of every
module and sees writes a macro injected. In each selected function's Core it
follows each value (`Anchor.Domain.StructFlow`) and reports a write that
changes a value known as another module's struct `S`:

- a map update (`%{v | k: x}`, op `map update`), `Map.put`, `merge`,
  `replace`, `replace!`, `update`, `update!`, `delete`, `drop`, `put_new`,
  `put_new_lazy`, `struct/2`, `struct!/2`, and `put_in`, `update_in`,
  `get_and_update_in`, `pop_in` (a dotted `put_in(g.turn.status, v)` judges
  `g` and `g.turn`, never the leaf).

A value is **known** as `S` when:

- a pattern matches it as `%S{}`;
- it is what a call returns whose every `@spec` returns `S` (`S.t()`,
  `%S{}`, a named type that is one of those; `nil | S.t()` counts as `S`):
  `Turn.new() |> Map.put(:status, :idle)`;
- it is a field of a known struct whose `@type t` types that field as `S`:
  `%{state.turn | status: :idle}`, `%Game{turn: t}` in a head;
- it flows unchanged through a `let` or a `case` clause variable.

Anything else is unknown and never reported: a union of two structs,
`map()`, a type outside the project, a type variable, a call on a variable
module, a variable rebound to `Map.from_struct/1`.

The owner and scope rules are the AST rule's: the struct's own module owns
it, `defimpl P, for: S` is `S`'s own code (`for: [A, B]` is the protocol's),
and `owned_namespaces` limits the structs judged; a selected module that
defines a struct outside them is itself a violation.

**One finding per site.** A site the AST rule reports is not reported again:
a line holding literal struct syntax for another module's struct (`%S{...}`,
`%S{s | ...}`), and a write on a value known only by a match in code the
source holds (the AST rule knows that variable). A match in code a macro
injected is this rule's, reported at the `use` line. A site with several
writes gives one violation, on the value the site starts from. Keyed
`<id>|<Mod.fun/a>|<S>|<op>`:

```
lib/my_app/decider.ex:12: [enforce] rule 5 (id: "struct_owned_by_module_flow", struct_owned_by_module_flow) MyApp.Decider.finish/1 changes MyApp.Turn (Map.put; known as MyApp.Turn by the @type t of MyApp.Game (field :turn)) outside MyApp.Turn: call a function on MyApp.Turn instead (e.g. MyApp.Turn.put_<field>/2). Fix: only a struct's own module builds or changes it: call a function on the struct's module (e.g. S.new/1, S.put_<field>/2) instead; read fields and pattern-match freely
```

Anchor's own `.anchor.yml` runs it over `lib/` with a baseline holding what
it found when it landed.

The only file it writes is `<build_path>/anchor/graph.etf` (Mix's build path:
`_build/<env>`, or the directory `MIX_BUILD_PATH` names), the graph keyed by
a sha256 of the project root's real path (two checkouts with the same build
output get two keys), the beams, each source file's facts (its literal `defmodule`s and
`use`s, which a source edit can change without changing a beam), the config and
Anchor's version, for `mix
anchor.explain` and `place`. The verdict never reads it; a write that fails is
a `[report]` note.

A graph rule that reads the higher-order flow analysis (`Anchor.Domain.Cfa`,
which closures reach each `fun.(x)`, `apply/2` and `Enum.map/2`-style call)
declares `needs: [:cfa]` in its module (`Anchor.Domain.GraphRule`'s optional
`needs/0`, DND-5574). When a rule that runs needs it, the run computes it once
and the summary ends with the apply-site precision counts, `; apply sites:
<r> resolved, <a> any` (a site is `any` when a value from outside the analysed
code can reach it), with `(step bound hit: every site reads any)` after them
if the analysis hit its bound. The JSON's `apply_sites` holds `total`,
`resolved`, `any`, `bound_hit` and the same counts `by_function`
(`"MyApp.X.run/1"`). When no rule that runs needs it, it is not computed: the
summary says nothing of apply sites and `apply_sites` is `null`.

Likewise a rule that reads the effect inference (`Anchor.Domain.Effects`,
DND-5447) declares `needs: [:cfa, :effects]` (`effects_match_bucket` adds
`:placement`, DND-5448): the run then infers it once,
after the flow analysis, and the summary and the JSON's `effects`
(`functions`, `by_role`, `unresolved`, `not_analysed`) carry its counts;
`effects` is `null` when no rule that runs needs it. A rule that reads the
demand analysis (`Anchor.Domain.Demand`, DND-5470) declares `needs: [:cfa,
:demand]`: the run then analyses once, with the external behaviours' callbacks
beside it; a zero in its counts was measured, and `null` means no such rule ran.

An Erlang module in the project is classified by its name only (a `pattern:`
selector): a classified one is an opaque node with no edges, counted in the
summary as `(<n> opaque)`; an unclassified one is an issue. No setting
excludes a module silently. A function whose Core body the graph lacks (a
`defmacrop`, a `defp` nothing calls) has no edges read from it, so the summary
counts those too, as `(<n> functions with no Core body)`, and the JSON as
`no_core`. A module is project code because its beam is in one of the
project's ebins, wherever its source sits (DND-5630). A module compiled from a
source outside the project root (an `elixirc_paths` entry such as `../shared`,
a generated file) is classified, judged and enforced like any other, under its
path relative to the root as `..` reaches it (`../shared/foo.ex`): the path its
issues name, a `paths:` selector matches (`../shared/**/*.ex`) and baselines
key on. The summary counts such modules as `(<n> outside the root)`, and the
JSON as `outside_root`, so the layout is visible. An absolute path inside the
root is made relative to it, so `paths:` selectors match it as they match
every other file.

### The placement rules: `function_placement` and `reachable_from_root` (DND-5448)

```yaml
rules:
  - type: function_placement
    id: function_placement
    paths: ["lib/**/*.ex"]
  - type: reachable_from_root
    id: reachable_from_root
    paths: ["lib/**/*.ex"]

architecture:
  contexts:
    depth: 2
  buckets:
    - name: domain
      role: domain
      select:
        - paths: ["lib/**/domain/**/*.ex"]
    - name: web
      role: framework
      select:
        - paths: ["lib/**/web/**/*.ex"]
  calls:
    domain: [domain]
    web: [domain]
```

Both read one model, `Anchor.Domain.Placement`: per function its inferred role, the
struct that owns it by its output and its input, its immediate dominator from the roots,
and whether a root reaches it. A check is the diff between where a function is and where
the model proposes it; its `Fix:` is the rendered proposal, the line `mix anchor.propose`
will list. The function rules run in this order, and the first that applies wins:

1. **Bucket from effects** (`effects_match_bucket`): a public function whose inferred role
   differs from its bucket's goes to a module of that role. A pure one whose type owner is
   known goes to that owner.
2. **Output-type owner** (`function_placement`): a pure public function of a Domain bucket
   whose `@spec` returns a project struct (`%S{}`, `S.t()`, or inside `{:ok, _}`) goes to
   `S`, when `S` is in a Domain bucket.
3. **Input-type owner** (`function_placement`): one returning a primitive goes to the owner
   of the one struct parameter on its return value's slice, in every clause.
4. **Dominated** (`function_placement`): a public, non-root function whose immediate
   dominator and every caller are in one other module of its bucket and context becomes
   that module's private function.

`reachable_from_root` (F5) reports a public function no root reaches, with the proposal
`delete`. A public macro counts as a root: the compiler calls it, and its expansion leaves
no edge to it.

```text
lib/billing/format.ex:4: [enforce] rule 1 (id: "function_placement", function_placement) Billing.Domain.Format.invoice_line/1 is in Billing.Domain.Format (bucket domain), but it returns %Billing.Domain.Invoice.Line{}. Fix: move Billing.Domain.Format.invoice_line/1 to Billing.Domain.Invoice.Line (it returns %Billing.Domain.Invoice.Line{}; the owner of a type holds its transitions)
lib/billing/dead.ex:2: [enforce] rule 2 (id: "reachable_from_root", reachable_from_root) Billing.Domain.Dead.unused/0 is public and no root reaches it. Fix: delete Billing.Domain.Dead.unused/0 (no root reaches it), or add the root that should call it
```

**Not judged by rules 2 to 4:** roots, generated functions, a project behaviour's callbacks,
`__name__`, `module_info/0,1`, `behaviour_info/1`, `child_spec/1`, and every function of an
interface module. Rule 4 also leaves a function a dynamic call or a literal `{M, :f, args}`
can reach, and a move into an interface module. Rules 2 and 3 need a `@spec`; a function
with none has no ownership proposal, and is counted. A function already in its owner stays,
whoever calls it. **Shared functions** (immediate dominator the virtual root: reached from
unrelated places) get no move from rules 2 to 4; rule 1 still names their bucket.

**Every run prints the model's precision**, whenever a rule needed it:

```text
; placement: 42 functions placed, 3 with no @spec (ownership unknown), 0 ambiguous owner, 0 with no clause to slice, 1 calls of a computed name, reachability lost at 1 call sites
```

A project module a function holds as a value (`children = [M, {N, arg}]`) reaches that
module's `child_spec/1`, so a supervised process is never read as dead. A call whose function
name is computed (`apply(mod, name, args)`, `spawn(mod, name, args)`,
and the `Task` and `:timer` forms in `Core.partial_mfa_calls/1`), in a reachable function,
could reach anything, so `reachable_from_root` then reports no function and fails closed,
naming each call site. A variable application (`fun.(x)`) does not: what it can reach was
captured somewhere, and a capture is an edge.

Over a project whose every non-framework bucket is an interface, `function_placement`
judges nothing, and says so. Anchor's own `.anchor.yml` is such a project, and it has one
computed name (`Mutator.generate/4`), so it enables neither rule yet; its
`effects_match_bucket` builds the model on every run.

### The `parameter_reaches_sink` rule (DND-5470)

```yaml
rules:
  - type: parameter_reaches_sink
    id: parameter_reaches_sink
    paths: ["lib/**/*.ex"]

architecture:
  contexts:
    depth: 2
  buckets:
    - name: domain
      role: domain
      select:
        - paths: ["lib/**/*.ex"]
  calls:
    domain: [domain]
```

Every parameter reaches the function's return value or an effect, directly or
through the callees it is passed to. The answer comes from the demand analysis
(`Anchor.Domain.Demand`) over Core Erlang, so a parameter bound, passed on and
finally dropped, which the compiler misses, is reported at each level, naming
the chain:

```text
lib/my_app/pricing.ex:6: [enforce] rule 1 (id: "parameter_reaches_sink", parameter_reaches_sink) MyApp.Pricing.f/2 parameter 2 (b) reaches no return value and no effect (chain: MyApp.Pricing.f/2 param 2 -> MyApp.Pricing.g/1 param 1 (dropped); call sites: 3). Fix: drop parameter 2 (b) of MyApp.Pricing.f/2 and stop passing it at its 3 call sites.
```

The key is `<id>|<Mod.fun/arity>|param <position>`, 1-based.

An underscore name (`_opts`) is reported too: an unused input of a function
that nothing obliges to take it is still a dead input. Reading part of a value
is a use, and so is matching it: a clause pattern other than a variable, or a
guard that reads the parameter.

**Exempt**, because something else fixes the signature: a callback of a
behaviour the module declares; a function captured anywhere in the project
(`&M.f/2`); a public function a dynamic call can reach (`mod.f(x)`, by
`Anchor.Domain.DynamicCalls`, and `apply(M, :f, args)` with args of unknown length,
which reaches every module's public `f`); a public function the code names in full, a literal
`{M, :f, args}` with a list of known length, in a term or a call (a child spec's
`start:`, `spawn(M, :f, [a])`); and a generated function (a module with no literal
`defmodule`, a `__name__`, a macro's output, the head a default argument
generates).

**Not analysed**, because an answer could be wrong: a function with no Core body;
a function of a module that may be generated (`generated?: :unknown`); a public
function of a module with an external behaviour whose callbacks could not be
read. If nothing the rule selects could be judged, that is one fail-closed issue.

Demand over-approximates what a function does with a parameter, so its imprecision
only hides a finding: a parameter passed to an unresolved call is used. Who calls a
function is another question, and there a finding can be false. A caller with no call
edge and no full name is unseen: `apply(M, name, args)`, `spawn(M, :f, args)`,
`spawn(mod, :f, [a])`, an MFA in variables. Reading any of them as naming every
candidate would let one such call silence the rule, so what they might reach stays
judged. A library that adds arguments to the MFA it is given is the same: `{M, :f, []}`
names `f/0`, so the `f/2` it really calls stays judged (Plug's `body_reader:`). Before
you drop a public function's parameter, check that no such caller relies on it. The run counts the `apply`s that compute a name, as a hint; a zero there
does not rule out the other shapes. Each run prints all of it:

```text
; parameter_reaches_sink: 1900 apply sites precise, 74 fell to any, 724 imprecise parameters, 7 calls of a computed name, 2142 functions judged, 906 exempt, 15 not analysed
```

An `apply/3` whose target Core does not name is no apply site; a parameter passed
to one is counted in the imprecise parameters. The JSON's `parameter_sinks` holds
`precise`, `any`, `imprecise`, `computed_names`, `judged`, `exempt` and `not_analysed`. A zero there
was measured; `null` means no such rule ran, or that its analysis crashed, which the
run reports as an issue.

### Aggregates: the `aggregates:` section and the `aggregate_declarations` rule (DND-5476)

An aggregate is the set of tables one transaction may write. Rules about
transactions (one aggregate per transaction, owner-only writes) need to know
which aggregate each schema and table belongs to, and which modules own it.
Three sources declare that, and all three mean the same thing; `mix
anchor.graph` merges them by aggregate name into one index
(`Anchor.Domain.Aggregates.Index`) every graph rule reads.

**1. The `aggregates:` section of `.anchor.yml`.**

```yaml
aggregates:
  declare:
    - name: MyApp.Threads.ThreadSpace       # a module-name token; need not be a module
      schemas: [MyApp.Threads.Thread, MyApp.Threads.Message]   # exact module names
      tables: ["thread_reads"]              # tables written by name, with no schema module
      owners: [MyApp.Threads.ThreadStore]   # exact module names allowed to write them
  repos: [MyApp.Repo]
  write_functions: ["MyApp.Repo.soft_delete/2"]
  transaction_functions: ["GenSaas.UnitOfWork.transaction/3"]
```

`declare` names the aggregates; `repos`, `write_functions` and
`transaction_functions` tell the write analysis what writes and what opens a
transaction, and `no_write_modules` (*What it does not read*) what it clears
unread, Erlang modules included, and are checked for shape (exact module names, and
`"Module.function/arity"` tokens). The load refuses, each with a `Fix:` giving this shape: a section that is not a
mapping; an unknown key at any level; a `declare` that is neither `none` nor a list; an entry
that is not a mapping, has no `name`, or a `name` that is not a module-name
token; `schemas`, `owners` or `repos` that are not lists of exact module names
(no glob, no Erlang module); `tables` that is not a list of non-empty strings;
two entries with one `name` (merge them); a malformed function token.

**2. `use Anchor.Aggregate`** in a module, which then owns the aggregate:

```elixir
defmodule MyApp.Threads.ThreadStore do
  use Anchor.Aggregate,
    name: MyApp.Threads.ThreadSpace,
    schemas: [MyApp.Threads.Thread, MyApp.Threads.Message],
    tables: ["thread_reads"]
end
```

Options: `name` (required), `schemas` (default `[]`), `tables` (default
`[]`), `owner` (default `true`). Aliases in scope resolve. A non-literal
option, an unknown key, a missing `name` or a value of the wrong type is an
`ArgumentError` at compile time. The macro defines no function and adds no
runtime call; it expands to exactly the two lines of form 3.

**3. The persisted attribute, written by hand** (the cross-tool contract; a
library such as gen_saas's DSL emits it):

```elixir
Module.register_attribute(__MODULE__, :anchor_aggregate, persist: true)
@anchor_aggregate [name: MyApp.Threads.ThreadSpace, schemas: [MyApp.Threads.Thread], tables: [], owner: true]
```

Keys: `name` (an alias atom, required), `schemas` (alias atoms, default `[]`),
`tables` (non-empty strings, default `[]`), `owner` (boolean, default
`false`), nothing else, and one value per module. A schema module that only
states its membership writes `schemas: [__MODULE__]` and leaves `owner` out.

The trade-off between forms 2 and 3: `use Anchor.Aggregate` needs Anchor at
compile time in every environment the module compiles in, so a repo that
keeps Anchor `only: [:dev, :test]` writes the two attribute lines by hand
instead, and needs no Anchor dependency in prod. Both are read identically.

Each schema's table is read from its `__schema__(:source)` clause in the
compiled code (Core Erlang), without loading the module. A source that is not
a literal string leaves that table unknown: it is counted, never dropped, in
the summary line, which ends `; aggregates: <N> declared, <U> tables unknown`
whenever an aggregate is declared (the JSON's `aggregates`).

```yaml
rules:
  - type: aggregate_declarations
    id: aggregate_declarations
    paths: ["lib/**/*.ex"]

aggregates:
  declare:
    - name: MyApp.Threads.ThreadSpace
      schemas: [MyApp.Threads.Thread]

architecture:
  contexts:
    depth: 2
  buckets:
    - name: domain
      role: domain
      select:
        - paths: ["lib/**/*.ex"]
  calls:
    domain: [domain]
```

The `aggregate_declarations` rule reports every declaration that names
nothing or claims too much, each at its site (the config, or the declaring
module's `defmodule` line), each message ending with `Fix:` and the
declaration shape:

| Issue | Example message |
|---|---|
| A schema or table two aggregates claim (one issue per claiming site; a schema's derived table counts) | `schema MyApp.Thread is claimed by MyApp.A and MyApp.B. Fix: list it in exactly one aggregate; the other reaches it through an outbox row consumed by the owner: ...` |
| A schema or owner naming no module of the project | `MyApp.Nope in aggregate MyApp.A names no module in this project. Fix: correct the module name or remove it: ...` |
| A schema module that is not an Ecto schema | `MyApp.Plain in aggregate MyApp.A is not an Ecto schema (no __schema__/1). Fix: list the schema module, or list its table under tables:: ...` |
| An aggregate with no schemas and no tables | `aggregate MyApp.A declares no schemas and no tables. Fix: add schemas: or tables:, or delete the declaration: ...` |
| An `@anchor_aggregate` of the wrong shape (the module contributes nothing) | `@anchor_aggregate on MyApp.X is not [name: atom, schemas: [atom], tables: [binary], owner: boolean]: it has no name. Fix: write it in this shape: ...` |
| No aggregate declared at all, and no `declare: none` (fail-closed: never baselined, never report-only) | `rule 1 (id: "aggregate_declarations", aggregate_declarations) checks nothing: no aggregate is declared in .anchor.yml or by an @anchor_aggregate attribute. Fix: declare one or remove the rule: ...` |
| Under `declare: none`, a module that persists (DND-5659) | `MyApp.Thread persists (it exports __schema__/1 (an Ecto schema)), but .anchor.yml says aggregates: declare: none (no database). Fix: declare the aggregate and remove declare: none: ...` |

An issue of the config section is always reported; one of a module's
attribute is reported when the rule's selector selects that module. The key
is `<id>|<.anchor.yml or the declaring module>|<kind> <aggregates> <subject>`,
with no line number. Which schemas a transaction may write together, and who
may write them, are the later transaction rules' (DND-5477, DND-5478); this
rule only makes the declarations trustworthy.

A module the selector leaves out still declares: its declarations count
toward the index and toward "declared", and only its issues are left out of
the report.

#### A repo with no persistence: `declare: none` (DND-5659)

A repo that persists nothing says so on purpose, with a reason, instead of
leaving the rule out:

```yaml
rules:
  - type: aggregate_declarations
    id: aggregate_declarations
    paths: ["lib/**/*.ex"]

aggregates:
  declare: none
  reason: "this service has no database: it reads files and calls APIs"

architecture:
  contexts:
    depth: 2
  buckets:
    - name: domain
      role: domain
      select:
        - paths: ["lib/**/*.ex"]
  calls:
    domain: [domain]
```

Under `none` the rule is not vacuous, and makes no checks-nothing violation:
it fails every selected module that persists, one violation at its
`defmodule` line keyed `<id>|<Module>|persists_under_none - <Module>`, whose
`Fix:` is to declare the aggregate and remove `declare: none`. A module
persists when it exports `__schema__/1` (`use Ecto.Schema`), declares
`@behaviour Ecto.Repo`, declares `@anchor_aggregate`, or calls a Repo write
(a write on a module whose name ends in `Repo`), raw SQL (`query`, `query!`,
`query_many`, `query_many!`) on such a module, any function of `Ecto.Repo` or
`Ecto.Multi`, or an `Ecto.Adapters.*` module; the first of these that holds
is the reason the message gives. Not seen: a read through a repo the project
does not define, and a call on a computed module.

The load refuses (exit 3, each with a `Fix:` naming both forms): `none`
without a `reason:` or with a blank one; a `reason:` without `none`; `none`
beside `repos`, `write_functions`, `transaction_functions` or `no_write_modules`; a `declare`
string other than `none`; and an explicit `declare: []`, so "nothing" is
always said on purpose. A missing `aggregates:` section keeps the fail-closed
checks-nothing violation above. Under `none` no write analysis is built, and
a config that also enables `aggregate_write_sources` is refused at load (exit
3): that rule reads a repo's writes, and `none` says there is no repo.

Anchor's own `.anchor.yml` runs the rule this way: `declare: none`, enforced,
no baseline.

### Writes and transactions: the `aggregate_write_sources` rule (DND-5459)

When a rule needs it, `mix anchor.graph` reads the database writes and
transactions it recognises from the compiled code (each function's Core Erlang,
so an alias, a pipe and an `@repo` attribute are already resolved). It reports
what it read; it does not claim to have seen all of them.

#### What it reads

- **Repos** are the modules whose beam declares `@behaviour Ecto.Repo`, plus
  `aggregates.repos`.
- **Writes** are the `Repo` writes on a repo (`insert`, `insert!`, `update`,
  `update!`, `delete`, `delete!`, `insert_or_update`, `insert_or_update!`,
  `insert_all`, `update_all`, `delete_all`), the `Ecto.Multi` writes (the same
  without bangs), the `aggregates.write_functions` entries, and a `Repo` write
  on the repo argument of a `Multi.run` callback. Raw SQL (`query`, `query!`,
  `query_many`, `query_many!` on a repo or a callback's repo, and
  `Ecto.Adapters.SQL.query*`) writes what no schema or table names: it is a
  gap, so a transaction that runs it is incomplete.
- **Each write's source** (its schema or table) is traced through Core: a
  struct, a changeset built from one, a schema module, a call on a schema, a
  `from` query, a literal table, `{table, schema}`, a parameter whose `@spec`
  is `Schema.t()`, or else the arguments its project callers pass. Anything
  else is **unresolved**, reported with what was seen, never dropped.
- **Transactions** are `Repo.transaction/1,2` (and `Repo.transact/1,2` when the
  repo exports it) and `aggregates.transaction_functions` calls, given a
  function, a capture or an `Ecto.Multi`. A transaction's write set is the
  writes read in its body and those of the project functions it calls,
  transitively. A call Anchor cannot resolve, a function value it cannot follow
  (a `fn` defined outside the body, a capture of a write, an unknown function
  handed to a library function that invokes it), a call it does not read (below),
  or an unresolved write, makes it **incomplete**. Calls into dependencies are not
  followed.
- **With no transaction read around it,** raw SQL, a write or transaction on a
  computed module, and an `apply/3` that may be one are reported, in the function
  they are written in: no schema or table names what it writes. A caller's
  transaction may still hold it; the report says what was read.

#### What it does not read

Core Erlang has a closed set of forms, and only a `call` or an `apply` can reach
code that writes. So every `call` and `apply` is one of: a form read above; a
project function, followed; a call on the no-write list, cleared and counted; or
a gap at its line. A dependency call, say, is `unread: call of Lib.save/1`: the
transaction around it is incomplete, and a function with no transaction around
it has a gap. So is a `transaction_functions` call with a non-literal argument
Anchor cannot trace beside the one it can. A function value handed to a listed
module is a gap too, unless `Anchor.Domain.HigherOrder` names that place.

A `fn` is read once, where it is defined and in any transaction it is given to. A
run of it anywhere else is a gap there, so a `fn` both called and passed to a
transaction (`f.(); Repo.transaction(f)`) is a gap at the call (DND-5885). So is a
`fn` or a Multi bound outside a body and given to a repo call or a
`transaction_functions` call inside it, and a `fn` bound outside a body and logged
inside it. The rule is one: a form that opens a transaction (`Repo.transaction`,
`Repo.transact`, a `transaction_functions` call) needs the bodies around it to be
among the value's own; anything else that runs a value needs exactly the value's
own, so `Repo.transaction(f); Repo.checkout(f)` is a gap at the checkout.

A Multi that comes back from a project helper is read from what the helper returns
(DND-5884): an argument it is built on that Anchor cannot trace is a gap, even when
the helper also makes its own Multi. A helper whose return Anchor cannot follow is
a gap too, and that includes a recursive helper and one that builds the Multi with
`Enum.reduce`.

What is left is not read by construction:

- **the built-in no-write list** (`Anchor.Domain.Aggregates.NoWrite`): modules
  that cannot reach a database connection, such as `Enum`, `Map`, `Ecto.Changeset`,
  `Ecto.Query`, `Logger`, and the pure `:erlang` functions. `GenServer`, `Task` and
  `Agent` are not on it, and neither is `Stream`, whose functions run later;
- **the modules under `aggregates.no_write_modules`,** your own assumption: a
  listed module's writes are not read, and the run counts the calls it cleared. A
  project module is followed whether it is listed or not;
- **dependencies' own internals,** for a function listed in
  `aggregates.write_functions` or a listed module alike;
- **an unknown value given to a listed module,** which Anchor cannot tell from
  data, in a place `HigherOrder` does not name;
- **a function a repo defines at a name and arity `use Ecto.Repo` generates.** Anchor
  reads that call as Ecto's. The same name at another arity is followed.

```yaml
aggregates:
  no_write_modules: [SomeLib, ":ets"]   # a listed module's writes are not read
```

The summary line ends `; writes: <W> read, <R> resolved, <U> unresolved;
transactions: <S> read, <N> no gap noticed, <I> incomplete; <G> gaps with no
transaction read around them; <D> dependency calls cleared by the no-write list;
not read: the modules under aggregates.no_write_modules, the built-in no-write
list, an unknown value given to one of them and dependencies' own internals; see
the README's What it does not read` (the JSON's `writes`, whose keys include
`no_gap_noticed`, `cleared`, and `unread_by_callee`: each `unread:` gap's text with
its count, so a run shows what a list would have to hold). `no gap noticed` is a
count of what Anchor noticed, not a statement that a write set is whole. An
unresolved write, an incomplete transaction and a call Anchor could not follow
with no transaction read around it are counted.

```yaml
rules:
  - type: aggregate_write_sources
    id: aggregate_write_sources
    paths: ["lib/**/*.ex"]

aggregates:
  repos: [MyApp.Repo]

architecture:
  contexts:
    depth: 2
  buckets:
    - name: domain
      role: domain
      select:
        - paths: ["lib/**/*.ex"]
  calls:
    domain: [domain]
```

| Finding | Example message |
|---|---|
| A write whose source is unresolved (at the write) | `Repo.insert in MyApp.X.save/1 writes a value Anchor cannot trace to a schema or table (parameter 1 of MyApp.X.save/1 has no @spec and no project caller). Fix: pass a struct, changeset or schema the call can see; add @spec with Schema.t() for the parameter; or list a wrapper under aggregates.write_functions.` |
| Raw SQL, or a write or transaction on a computed module, with no transaction read around it (at the call) | `MyApp.X.purge/0 writes, or may write, with no transaction read around it in a way no schema or table names: raw SQL (MyApp.Repo.query!/1) Anchor cannot attribute. Fix: write through a schema with Repo, or name the module the call is on.` |
| An incomplete transaction (at the transaction) | `transaction 1 in MyApp.X.run/1 reaches 1 call(s) Anchor cannot resolve (first: MyApp.X.run/1 line 12), so its write set is incomplete. Fix: call a named function instead of a variable, ...` |
| A transaction that reaches a call it does not read (at the transaction) | `transaction 1 in MyApp.X.run/1 reaches 1 call(s) it does not read (first: unread: call of Lib.save/1 in MyApp.X.run/1 line 12), so its write set is incomplete. Fix: ...; list a dependency that cannot write under aggregates.no_write_modules, or one that writes under aggregates.write_functions; ...` |

The key is `<id>|<M.f/a>|unresolved <op> <seen>`, `<id>|<M.f/a>|unattributed <what>` or `<id>|<M.f/a>|incomplete
<ordinal>`, where the ordinal is the transaction's position in its function:
no line number. The rule's selector chooses whose findings are reported.

`Anchor.Domain.Aggregates.Inference` turns the analysis into proposed
aggregates: the connected components of the co-write graph (each
transaction's written schemas are written together), printed as the exact
`aggregates:` YAML above. Its first line is always `# not read: the modules under
aggregates.no_write_modules, the built-in no-write list, an unknown value given
to one of them and dependencies' own internals; a write there is not in this
proposal; see the README's What it does not read`. `mix anchor.propose
--level aggregate` prints it once DND-5449's `mix anchor.propose` lands.

### The test-time backstop: `Anchor.Backstop` (DND-5480)

The static rules cannot read a transaction's write set whole when a write
goes through a callback passed as a variable, a variable repo or a
`Multi.merge` function. The tests already run those paths, so the backstop
watches the repo's query telemetry while they do, and fails a test whose
transaction wrote tables of two declared aggregates. Two calls are the whole
integration:

```elixir
# test/test_helper.exs
Anchor.Backstop.attach!(repo: MyApp.Repo)
ExUnit.start()

# test/support/data_case.ex
setup tags do
  Anchor.Backstop.watch(tags)
  :ok
end
```

`attach!/1` takes `repo:` (required), `ebins:` (default
`[Mix.Project.compile_path()]`), `root:` (where `.anchor.yml` is looked up,
default the working directory) and `escapes: :report | :fail` (default
`:report`). Call it in `test_helper.exs`: its ETS table belongs to the
process that calls it. It reads the declarations the static rules read
(`aggregates:` and every persisted `@anchor_aggregate`) from the compiled
beams, never by loading a project module. It needs `:telemetry` (an optional
dependency of Anchor, and one every Ecto project has).

How it reads the events (DND-5479's spike, pinned in gen_saas's
`Todos.RepoTelemetryFactsTest`): `"begin"` opens a transaction in the
emitting process and `"commit"` or `"rollback"` closes it (only the outermost
`Repo.transaction` emits them; a `BEGIN ...` or `START TRANSACTION` spelling
opens one too); a write's table is the event's `source`. An
event belongs to a test when the emitting process is the test or has it in
`$callers`, so async tests never see each other's writes. It records table
names, statement kinds and pids, never `params`, `cast_params` or a result.
The verdict runs in the test's `on_exit`, never in the handler: no sleep, no
polling, no clock.

A failure:

```
MyApp.OrdersTest test pays: transaction wrote aggregates MyApp.Orders (table orders) and MyApp.Billing (table invoices). Fix: write MyApp.Billing's change as an outbox row in MyApp.Orders, consumed by MyApp.Billing's owner; or declare one aggregate holding both.
```

Two transactions in one test that each write one aggregate do not fail it:
a non-atomic crossing is the static rules' T2. What it cannot tie to a
transaction is never read as clean. Each is counted per test and summed in
one line when the suite ends; the first four fail the test under
`escapes: :fail`:

| Kind | What |
|---|---|
| `other-process` | a write from a process the test started or called (a Task, a GenServer): DND-5479 saw a Task's write land after its parent's commit, outside the transaction |
| `unclassified` | a statement read as neither a read nor a write (`WITH`, `MERGE`, `TRUNCATE`, ...): never dropped as a read |
| `no-source` | a write with no table (`Repo.query/2` raw SQL) |
| `undeclared` | a table no aggregate declares |
| `outside a transaction` | a write with no transaction open in its process: one statement, one table, so it cannot cross; counted only |
| `unattributed` | a write from a process with no watched test in itself or its `$callers` (a sandbox allowance, a GenServer the test called, an unwatched test), or one that landed after its test's verdict: counted for the whole suite, never failing a test. A transaction a GenServer runs for the test is therefore not judged here |

```
anchor backstop: 120 tests watched, 0 crossings; escapes: 2 other-process, 0 no-source, 1 undeclared, 0 unclassified; not judged: 40 outside a transaction, 3 unattributed
```

It fails closed: the suite does not start with a backstop that checks
nothing.

| Case | Result |
|---|---|
| no `.anchor.yml`, or one that does not load | `attach!/1` raises `ArgumentError`: `anchor backstop: could not load .anchor.yml under <root>: <reason>. Fix: ...` |
| no `aggregates:` section | raises: `anchor backstop: <path> has no aggregates: section. Fix: declare aggregates ...` |
| `declare: none`, or zero aggregates declared | raises: `anchor backstop: the backstop checks nothing: no aggregate is declared. Fix: declare aggregates (mix anchor.propose --level aggregate).` |
| zero beams read from `ebins` | raises, naming the paths |
| `repo:` with no `telemetry_prefix` | raises, naming the repo |
| `escapes:` other than `:report` or `:fail` | raises, naming the value |
| no `repo:`, or an option `attach!/1` does not know (`escape: :fail`) | raises with `Fix:`, never read as the default |
| `attach!/1` called a second time in one test VM | raises: `the backstop watches one repo. Fix: call Anchor.Backstop.attach!/1 once, in test_helper.exs.` |
| `watch/1` before `attach!/1` | raises: `Fix: call Anchor.Backstop.attach!/1 in test_helper.exs.` |
| the handler raised (`:telemetry` detached it) | every later verdict fails its test: `the backstop handler was detached` |

### Graph rows of the fail-closed table

Like the Credo checks, the graph engine fails closed: a run that could not
check something says so, never reads clean. Each message ends with a `Fix:`
line.

| Condition | Exit | Where | Example message |
|---|---|---|---|
| No `.anchor.yml`, unreadable, invalid YAML, a rejected document | 3 | the config path | the same text as the Credo issue above |
| `--only` naming no graph rule of the config | 3 | the config path | `COULD NOT MEASURE: --only "typo" names no graph rule of .anchor.yml, so the run would check nothing. Fix: ...` |
| No `architecture:` section | 3 | the config path | `COULD NOT MEASURE: .anchor.yml has no architecture: section, so mix anchor.graph could classify no module and run no graph rule. Fix: add an architecture: section ...` |
| `mix compile` fails | mix's own | | |
| An umbrella `apps_path` that is absolute and outside the project root (DND-5655; an absolute one under the root is made relative) | 3 | the config | `COULD NOT MEASURE: the apps_path of :alpha is /elsewhere/alpha, outside the project root /work/my_app, so its source paths cannot be keyed against the root. Fix: set apps_path in the umbrella's mix.exs to a directory under the project root ...` |
| Zero project modules read | 3 | the first ebin | `COULD NOT MEASURE: read 0 modules from _build/dev/lib/my_app/ebin. Fix: run mix compile in this project; ...` |
| One app of the project read no module while another did (an umbrella app not compiled, under another build path, or renamed; DND-5584) | 1 | that app's ebin | `read 0 modules for app :other from _build/dev/lib/other/ebin, so none of its code was checked. Fix: run mix compile for :other; ...` |
| A beam with no `debug_info` (or stripped) | 1 | the beam | `MyApp.X was compiled without debug_info, so Anchor cannot read it. Fix: remove debug_info: false from the project's elixirc_options ...` |
| The backend refuses `elixir_v1` (`{:elixir_v1_refused, _}`) | 1 | the beam | `MyApp.X the beam's backend could not produce its Elixir debug info (...). Fix: recompile with the project's own Elixir; ...` |
| The backend refuses `core_v1` (`{:core_v1_refused, _}`) | 1 | the beam | `MyApp.X the beam's backend could not produce Core Erlang (...). Fix: recompile with the project's own Elixir; ...` |
| A module compiled with a `parse_transform` or `core_transform` (`{:core_v1_refused, {:transform, _}}`) | 1 | the beam | `MyApp.X was compiled with {:parse_transform, :pt}, which lowering to Core Erlang would run, and Anchor runs no project code. Fix: remove the transform ...` |
| A module compiled with any other option not on the reader's allowlist of options known to run no code (`{:core_v1_refused, {:option, _}}`, DND-5552) | 1 | the beam | `MyApp.X was compiled with the option {:plugins, [...]}, which is not on Anchor's list of options that run no code when lowered to Core Erlang, so it was not lowered (DND-5552). Fix: remove the option from the module's compile options, or move the module into a dependency; ...` |
| Decoding a beam crashed (`{:decode_crashed, _}`) | 1 | the beam | `MyApp.X could not be decoded: Anchor crashed reading it (...). Fix: this is an Anchor bug; file it with this line.` |
| Walking a module's Core crashed (`{:walk_crashed, _}`, DND-5548) | 1 | the beam | `MyApp.X could not be added to the graph: Anchor crashed walking it (...). Fix: this is an Anchor bug; ...` |
| A public function or macro with no Core body (`{:no_core, _}`, DND-5549) | 1 | the beam | `MyApp.X has no Core Erlang body for run/1, so no call in them was read (DND-5549). Fix: this is an Anchor bug; file it with this line.` Every function with no Core body, private ones included (a `defmacrop`, a `defp` nothing calls), is counted in the summary line as `(N functions with no Core body)`. |
| One module in two ebins (`{:duplicate_module, _}`) | 1 | the extra beam | `MyApp.X is in two ebins: ... and ... (kept). Fix: run mix clean to remove a stale beam, or rename one of the two modules.` |
| A beam or ebin that cannot be read (`{:unreadable, _}`) | 1 | that path | `The beam ... could not be read (:eacces). Fix: make ... readable; ...` |
| An Erlang module no bucket classifies | 1 | the beam | `:my_erl is Erlang source; the graph engine reads Elixir only, and no architecture bucket classifies it. Fix: move it under a dependency, or classify it with a pattern: selector ...` |
| A module whose literal `use`s its source cannot show (a non-literal `defmodule` name), when a `uses_module` selector exists | 1 | the source file | `MyApp.X's literal uses cannot be read from lib/x.ex (its defmodule name is not literal there), so a uses_module selector cannot be judged for it. Fix: ...` |
| A module's source file that cannot be read or parsed | 1 | the source file | `Anchor could not read the source of lib/x.ex (:enoent), so its uses_module selectors and generated? are unknown. Fix: ...` |
| An unclassified module | 1 | its source file, at its `defmodule` line | `MyApp.X is in no architecture bucket. Fix: add a selector that matches lib/x.ex ...` |
| An ambiguous module | 1 | its source file, at its `defmodule` line | `MyApp.X is in buckets domain (by paths [...]) and framework (by uses_module GenServer). Fix: narrow one selector; buckets never take precedence.` |
| A bucket below its `min_modules` | 1 | the config | `architecture bucket domain selects 3 modules, below min_modules 10. Fix: correct the selector; lowering min_modules is the owner's call.` |
| An `interfaces.exports` entry that names no module | 1 | the config | `architecture interfaces.exports names MyApp.Gone, which is no module of the project ... Fix: ...` |
| An `aggregates:` section with `declare: []`, or `declare: none` with no `reason:` (DND-5659) | 3 | the config path | `aggregates.declare is an empty list, which says nothing on purpose. Fix: write declare: none with reason: "<why this repo persists nothing>" and no other key, or list the aggregates: ...` |
| An `aggregates:` section of the wrong shape (DND-5476) | 3 | the config path | `aggregates.declare[1].schemas must be a list of exact module names: "MyApp.*" is not an exact Elixir module name (no glob, no Erlang module). Fix: name each module in full, as its defmodule spells it; aggregates: declare: - name: <Aggregate>, ...` |
| An `analyses_complete` rule when the flow analysis hit its step bound (DND-5715) | 1, even under `enforcement: report`; never held by a baseline | the config | `rule 1 (id: "analyses_complete", analyses_complete): the higher-order flow analysis (Anchor.Domain.Cfa) hit its step bound after 40 steps, so every apply site reads any and no closure was resolved. Fix: this is a scale limit of Anchor; ...` |
| An `analyses_complete` rule when the demand analysis hit its round bound (DND-5715) | 1, even under `enforcement: report`; never held by a baseline | the config | `rule 1 (id: "analyses_complete", analyses_complete): the demand analysis (Anchor.Domain.Demand) hit its round bound on 2 function(s) (MyApp.X.f/1, MyApp.X.g/2), so their parameters read as used without being judged. Fix: this is a scale limit of Anchor; ...` |
| A `struct_owned_by_module_flow` rule when the struct value flow did not settle within its pass bound on some function (DND-5676) | 1, even under `enforcement: report`; never held by a baseline | the config | `rule 1 (id: "struct_owned_by_module_flow", struct_owned_by_module_flow): the struct value flow (Anchor.Domain.StructFlow) hit its bound of 6 passes on 1 function(s) (MyApp.X.f/1), so a write to a struct there may not be judged. Fix: split the function's nested anonymous functions apart, ...` |
| An `analyses_complete` rule when a selected function with a Core body has no demand summary (DND-5715) | 1, even under `enforcement: report`; never held by a baseline | the config | `rule 1 (id: "analyses_complete", analyses_complete): 1 function(s) have a Core body and no demand summary (MyApp.X.f/1), so the analysis judged none of their parameters. Fix: this is an Anchor bug; ...` |
| An `analyses_complete` rule when the analyses judged fewer than a floor it declares (DND-5715) | 1, even under `enforcement: report`; never held by a baseline | the config | `rule 1 (id: "analyses_complete", analyses_complete): the whole-program analyses judged 3, below min_functions 501, so they may be judging nothing. Fix: find what stopped them reading this code; ...` |
| An `aggregate_declarations` rule with no aggregate declared anywhere (DND-5476) | 1, even under `enforcement: report`; never held by a baseline | the config | `rule 1 (id: "aggregate_declarations", aggregate_declarations) checks nothing: no aggregate is declared in .anchor.yml or by an @anchor_aggregate attribute. Fix: declare one or remove the rule: ...` |
| A schema whose `__schema__(:source)` is not a literal (DND-5476) | 0 | the summary | counted as `; aggregates: <N> declared, <U> tables unknown`, never dropped |
| An `aggregate_write_sources` rule beside `aggregates: declare: none` (DND-5659) | 3 | the config path | `rule 1 (id: "aggregate_write_sources"): aggregate_write_sources reads the writes of a project with a repo, but .anchor.yml says aggregates: declare: none. Fix: remove the rule, or declare the aggregates and the repo instead of none.` |
| An `aggregate_write_sources` rule with no `aggregates:` section (DND-5459) | 3 | the config path | `rule 1 (id: "aggregate_write_sources"): aggregate_write_sources needs an aggregates: section in .anchor.yml. Fix: add aggregates: (repos:, declare:) or remove the rule.` |
| An `aggregate_write_sources` rule in a project with no Ecto repo (DND-5459) | 1, even under `enforcement: report`; never held by a baseline | the config | `rule 1 (id: "aggregate_write_sources", aggregate_write_sources): no Ecto repo found: no module declares @behaviour Ecto.Repo and aggregates.repos is empty. Fix: list the repo under aggregates.repos.` |
| An `aggregate_write_sources` rule whose modules hold no write (DND-5459) | 1, even under `enforcement: report`; never held by a baseline | the config | `rule 1 (id: "aggregate_write_sources", aggregate_write_sources) checks nothing: no write found in paths ["lib/**/*.ex"]. Fix: correct the selector or aggregates.repos.` |
| A write Anchor cannot trace, or a transaction that reaches one or a call it cannot resolve (DND-5459) | the rule's enforcement | the write or transaction | an `aggregate_write_sources` finding, and counted in the summary as `; writes: ... unresolved; transactions: ... incomplete` |
| A graph rule below its `min_modules` | 1 | the config | `rule 2 (id: "web", layering) selects 0 modules, below min_modules 1. Fix: correct the selector; ...` |
| A graph rule that raises, throws or exits | 1 | the config | `rule 2 (id: "web", layering) could not run: RuntimeError: ... Fix: this is an Anchor bug; file it with this line.` The other rules still run. |
| A `baseline:` file that is missing, unreadable, not UTF-8, or holds another rule's entry | 1 | the baseline path | `rule 2 (id: "web", layering)'s baseline .anchor/baselines/web.txt could not be read (:enoent), so none of its findings is held. Fix: create it with mix anchor.graph --write-baseline web ...` |
| A symlink on a baseline's path, a directory or the file, on disk or at `--base REF` (DND-5628) | 1 | the baseline path | `rule 2 (id: "web", layering)'s baseline .anchor/baselines/web.txt was not read: .anchor is a symlink, and Anchor never follows one out of the project root, so none of its findings is held. Fix: replace the symlink .anchor with a real directory or file inside the project, ...` `--write-baseline` creates nothing through one. |
| A directory on the baseline's path replaced by a symlink while `--write-baseline` writes it (DND-5647): the written file's real path is checked after the write | 1 | the baseline path | `Anchor did not create .anchor/baselines/web.txt: a directory on its path became a symlink while it was written, so the file landed at /elsewhere/web.txt, outside the project root, and was removed there. Fix: find what is replacing directories in this checkout during the run, ...` |
| A baseline entry no finding matches (STALE) | 1 (0 for a `report` rule) | the baseline path | `web\|A.f/1\|-> B.g/0 in .anchor/baselines/web.txt matches no finding (it was fixed). Fix: delete that line ...` |
| A baseline entry the branch added since `--base REF` (GREW) | 1 (0 for a `report` rule) | the baseline path | `... was added to .anchor/baselines/web.txt since main. Fix: fix the finding instead; a baseline only shrinks ...` |
| A baseline that could not be read at `--base REF` (git failed) | 1 | the baseline path | `Anchor could not read .anchor/baselines/web.txt at main (...), so whether the branch added to it (GREW) could not be judged. Fix: ...` |
| A baseline absent at `--base REF` (first landing) | 0 | the baseline path | `NOTE: first landing of .anchor/baselines/web.txt (absent at main); review is the gate. ...` |
| A rule id with no baseline at `--base REF` (DND-5629: the base copy is found by the rule's `id` in the config at REF, so renaming `baseline:` is still judged; a rule there with no `baseline:` compares with an empty one, every entry GREW) | 0 | the baseline path | `NOTE: first landing of rule "web": no rule with that id had a baseline at main; rules with a baseline at main that this config no longer has: "old_web". Fix: review every line ...` |
| The config at `--base REF` cannot be read or loaded (DND-5629); one issue per run, naming every baselined rule it left unjudged, whose findings all stand (DND-5648) | 1 | the config | `Anchor could not read .anchor.yml at main (...), so no baseline's copy there could be found by its rule's id and GREW could not be judged for rules "layering", "context_acyclic". Fix: ...` |
| `--write-baseline` that could not create the file (not `:exists`: `:eacces`, ...) | 1 | the baseline path | `Anchor could not create .anchor/baselines/web.txt (:eacces). Fix: make its directory writable.` |
| `--write-baseline` that created the file | 0 | the baseline path | `anchor.graph wrote 3 entries to .anchor/baselines/web.txt. Fix: review it in this change; from here it only shrinks.` (`[report]`) |
| `--write-baseline` over an existing file, or naming no rule with a `baseline:` | 2 | the baseline path, or the config | `.anchor/baselines/web.txt exists; --write-baseline only creates, and never rewrites a baseline. Fix: ...` |
| A `--base` ref with a character git must not see (a leading `-`, a space, `;`, `$`, `:`) | 2 | | usage, with a `Fix:` line |
| A graph rule whose `needs/0` names an analysis the runner does not compute, or is not a list (DND-5574) | 1 | the config | `rule 2 (id: "web", layering) could not run: ArgumentError: MyApp.Rule.needs/0 names [:nope], which the graph runner does not compute (it computes [:aggregate_analysis, :cfa, :effects, :demand]), so it checked nothing. Fix: this is an Anchor bug; file it with this line.` The rule is not run; the other rules still run. |
| A graph rule whose `needs/0` names an analysis without one it reads: `:effects` or `:demand` without `:cfa`, `:placement` without `:cfa` and `:effects` (DND-5675) | 1 | the config | `rule 2 (id: "effects", effects_match_bucket) could not run: ArgumentError: MyApp.Rule.needs/0 names :effects without :cfa, which :effects reads, so it would run degraded; add :cfa to MyApp.Rule.needs/0. Fix: this is an Anchor bug; file it with this line.` The rule is not run; the other rules still run. |
| The higher-order flow analysis a rule needs raises, throws or exits (DND-5574) | 1 | the config | `rule 2 (id: "web", layering) could not run: the higher-order flow analysis it needs (Anchor.Domain.Cfa) crashed: RuntimeError: ..., so it checked nothing. Fix: this is an Anchor bug; file it with this line.` One per rule that needs it; the rules that do not still run. |
| The effect inference a rule needs raises, throws or exits, or returns no `%Effects{}` (DND-5447) | 1 | the config | `rule 2 (id: "effects", effects_match_bucket) could not run: the effect inference it needs (Anchor.Domain.Effects) crashed: RuntimeError: ..., so it checked nothing. Fix: this is an Anchor bug; file it with this line.` One per rule that needs it; the rules that do not still run. |
| The demand analysis a rule needs raises, throws or exits, or returns no `%Demand{}` (DND-5715) | 1 | the config | `rule 1 (id: "analyses_complete", analyses_complete) could not run: the demand analysis it needs (Anchor.Domain.Demand) crashed: ... Fix: this is an Anchor bug; file it with this line.` The other rules still run. |
| The write analysis a rule needs raises, throws or exits, or returns no `%Analysis{}` (DND-5459) | 1 | the config | `rule 2 (id: "writes", aggregate_write_sources) could not run: the write analysis it needs (Anchor.Domain.Aggregates.Analysis) crashed: RuntimeError: ..., so it checked nothing. Fix: this is an Anchor bug; file it with this line.` |
| An `effects_match_bucket` rule selects modules of a judged bucket of which no public function was analysed (DND-5447) | 1 | the config | `rule 4 (id: "effects", effects_match_bucket) judged no public function of bucket domain: the modules it selects there have none that was analysed (every one is a root, generated, or has no Core body), so the bucket is below the rule's floor. Fix: select modules of domain with public functions, or set infer: false on domain in a reviewed change.` |
| The demand analysis a rule needs, or the behaviour read beside it, raises, throws or exits, or the analysis returns no `%Demand{}` (DND-5470) | 1 | the config | `rule 2 (id: "sinks", parameter_reaches_sink) could not run: the demand analysis it needs (Anchor.Domain.Demand) crashed: RuntimeError: ..., so it checked nothing. Fix: this is an Anchor bug; file it with this line.` One per rule that needs it; the rules that do not still run. |
| The placement model a rule needs raises, throws or exits, or is no `%Placement{}` (DND-5448) | 1 | the config | `rule 2 (id: "placed", function_placement) could not run: the placement model it needs (Anchor.Domain.Placement) crashed: RuntimeError: ..., so it checked nothing. Fix: this is an Anchor bug; file it with this line.` One per rule that needs it; the rules that do not still run. |
| A reachable function calls a function whose name is computed, under a `reachable_from_root` rule (DND-5448) | 1 | the config | `rule 3 (id: "reach", reachable_from_root) reachability is imprecise: lib/a.ex:3 calls an unknown function dynamically. Fix: resolve it through a behaviour, or accept that reachable_from_root cannot judge this repo.` Names each call site; the rule reports no function that run. |
| A `reachable_from_root` rule over a model with no root (DND-5448) | 1 | the config | `rule 3 (id: "reach", reachable_from_root) no roots: no framework-role bucket matched a module and architecture.roots is empty. Fix: classify the entry points.` |
| A `reachable_from_root` rule selects no public function an author wrote (DND-5448) | 1 | the config | `rule 3 (id: "reach", reachable_from_root) judged no function: the modules it selects have no public function an author wrote, so it checked nothing. Fix: select modules with public functions of their own, or remove the rule.` |
| A `function_placement` rule can judge no function of what it selects (DND-5448) | 1 | the config | `rule 2 (id: "placed", function_placement) judged no function: every public function of the modules it selects is a root, generated, a callback or in an interface module, so it checked nothing. Fix: select modules outside architecture.interfaces, or remove the rule.` |
| A `parameter_reaches_sink` rule selects modules of which no function could be judged (DND-5470) | 1 | the config | `rule 2 (id: "sinks", parameter_reaches_sink) judged no function: every function of the modules it selects is exempt, has no Core body, or could not be analysed, so it checked nothing. Fix: select modules with functions of their own, or remove the rule.` |
| Findings of a `report` rule | 0 | the finding | printed `[report]` |

Exit 2 is a usage error (an unknown option, `--format` other than `text` or
`json`, an argument, a `--base` ref Anchor refuses), a refused `--project`, or
a refused `--write-baseline` (the file exists, or the id names no rule with a
`baseline:`), with a `Fix:` line.

## Ask Anchor before you write: `mix anchor.explain` (DND-5446)

```bash
mix anchor.explain <path|Module> [--format text|json]
```

Before you write a module, ask Anchor what it will be held to. Given a module
name, or a source path (one that exists, or one you are about to create), it
prints, from `.anchor.yml` and the compiled graph only:

- **classification**: the bucket and its role, the context, the app, whether
  the module is its context's interface, and its aggregate. A module in no
  bucket shows every bucket's selectors and the unclassified `Fix:`.
- **may call**: its bucket's `calls` row, resolved to concrete modules: every
  module of its own context in each callable bucket, and only the interface
  modules of other contexts. It also lists the buckets the module must not call.
- **rules**: every rule of either engine (Credo or graph) that selects it,
  with its enforcement and its *shape*, the sentence its findings' `Fix:`
  ends with.
- **findings**: what the graph rules find on its source file, run over the
  graph the last `mix anchor.graph` run wrote, used only when that graph's key
  matches this build. Otherwise it prints `not computed (run mix anchor.graph)`;
  a stale graph is never used. These are the rules' raw findings: a finding a
  baseline holds is shown too, and a fail-closed one (a rule that could not run
  or selects nothing) wherever it sits, while another finding on the config file
  (an interface width) is not, so `mix anchor.graph` stays the verdict.

A path that does not exist yet is classified by its path and the module name
Elixir's file naming implies (`lib/my_app/domain/new_thing.ex` is
`MyApp.Domain.NewThing`). Facts only a beam has (its app, behaviours, `use`s
and exported functions) are listed under `unknown`. A bucket that only such a
selector could still match is listed under `possible`, so a definite path
classification never hides an ambiguity the compiled module would have. If the
project does not compile, it still answers from the config and the paths and
says `compile failed; beam facts unknown`. It writes no file of its own (the
compile it runs writes `_build` as `mix compile` does; the graph artifact is
`mix anchor.graph`'s) and calls no project module (the compile it runs
loads them, as `mix compile` does).

```text
anchor.explain: lib/my_app/orders/manager.ex
  module: MyApp.Orders.Manager
  path: lib/my_app/orders/manager.ex (exists)
classification:
  status: classified
  bucket: managers (role managers)
  context: MyApp.Orders
  app: my_app
  interface: yes
  aggregate: unknown (no aggregates declared)
may call:
  managers (any): same context: MyApp.Orders.Manager; other contexts (interface only): MyApp.Billing: MyApp.Billing.Manager
  domain (any): same context: MyApp.Orders.Order; other contexts (interface only): none
must not call: framework
rules:
  [enforce] layering (id: layering, graph): every call between two project modules is one the architecture: calls matrix allows; a call the matrix forbids goes through a bucket the caller may call
findings: none
```

`--format json` prints `{subject, module, path, exists, notes,
classification, may_call, must_not_call, rules, findings, unknown}` for agents;
`findings` is `null` when not computed. Exit 0 answered; 2 usage (no subject,
two subjects, an unknown option, or a subject that is neither a module name nor
an `.ex` path under the project root); 3 no or invalid config, no
`architecture:` section, or an umbrella app directory outside the project root.

### One `Fix:` per finding

Every finding of every rule type, Credo or graph, ends with exactly one `Fix:`.
Each rule type declares its conforming shape (`shape/1`), and a finding whose
message has no specific `Fix:` gets `Fix: <shape>` appended
(`Anchor.Domain.RuleShapes`). A graph rule's `Fix:` names the instance: the
route to call, the edge to invert. A config refusal that already carries a
specific `Fix:` no longer gets the generic one appended after it.
`test/anchor/domain/fix_shape_invariant_test.exs` and the graph canary hold this
for every type.

## Generated sabotage: the functions a change touched

```bash
mix anchor.sabotage scope [--base REF] [--format text|json]
```

Prints the functions the working tree changed relative to the merge-base of
`REF` (default `origin/main`) and `HEAD`: committed, staged and unstaged
changes from `git diff --unified=0`, plus every untracked `.ex` file as wholly
added. Each changed line inside a `def` or `defp` clause puts that function,
`{module, name, arity}`, in scope; a multi-clause function appears once. A
removed line maps to the function it was in at the merge-base (read with
`git show`), so deleting lines or a whole clause of a function that still
exists keeps it in scope; a function deleted whole is gone, and counted as a
hunk outside a function. It reads git and source files only: nothing
is compiled and no project code runs. Generated sabotage (`mix anchor.sabotage
run`, below) mutates only these functions.

Text output is one TSV line per function (`file, module, name/arity, kind,
changed line ranges`), then a summary that counts what was left out:

```
lib/a.ex	A	f/1	def	3-5,8
anchor.sabotage scope: 1 functions in 1 files; excluded: 0 test files, 0 non-source files, 0 deleted files, 1 hunks outside a function, 0 macros
```

Left out, and counted: test files (a `test` path segment or `_test.exs`),
non-source files (not `.ex`, or under `deps`/`_build`), deleted files, hunks
outside any function (attributes, docs, a deleted function), and macros
(`defmacro`, `defmacrop`, `defguard`, `defguardp`, and any def inside `quote`).
`--format json` carries the same fields.

| Condition | Exit |
|---|---|
| measured (a clean diff prints `0 functions`) | 0 |
| an unknown option, format or subcommand | 2 |
| not a git work tree; `REF` unresolvable or no merge-base; git failing; a diff Anchor cannot read; a changed `.ex` file that does not parse or cannot be read | 3, `COULD NOT MEASURE` with `Fix:` |

### The mutants of one function

`Anchor.Domain.Sabotage.Mutator.generate(source, path, {module, name, arity},
opts)` (DND-5471) returns every mutant of one function's literal `def`/`defp`
clauses. It only parses the source (with Sourceror, so each edit replaces
exactly its range and nothing else is reformatted); it compiles nothing and
writes nothing. The runner (`mix anchor.sabotage run`, below) applies them.

| Operator | The mutant |
|---|---|
| `delete_statement` | a non-final statement that is not an effect call is deleted (its whole lines) |
| `drop_effect_call` | a non-final statement that is an effect call (a Repo write, `send`, `GenServer.call/cast`, a `Logger` call, a `File`/`System`/`IO` write, ...; extra calls by `effect_calls:`) is replaced by `_ = {arg1, ..., argN}`, which keeps its arguments evaluated (so a variable only the call read stays used) and removes the effect; a call with no argument is deleted (DND-5564) |
| `narrow_clause` | one clause of a function or `case` with two or more clauses never matches (`when node() == :__anchor_sabotage_never__`) |
| `with_passthrough` | one `pat <- expr` step of a `with` stops checking (its literals become `_`, `%Mod{}` becomes `%{}`, its guard goes) |
| `force_condition` | an `if`/`unless`/`cond` condition is forced true, and separately false |
| `return_input` | a clause returns one of its parameters unchanged |

Each mutant carries a stable id (sha256 of the module, function, operator,
variant, normalized target node and its occurrence index; never a line), the
range it replaces, the original and replacement text, and a unified diff. An
edit that would not compile under `--warnings-as-errors` (a variable left
unbound or unused; the last use of a private function, module attribute, alias
or import removed) is returned as skipped, with the reason, never as a mutant.
A function no literal `def`/`defp` defines is `{:error, :not_in_source}`.

A protocol implementation's function is found as `scope` names it (DND-5624):
`defimpl P, for: T` is `P.T`; a `defimpl P` with no `for:` inside
`defmodule T` is `P.T`; `for: [T1, T2]` makes each `P.Tn` resolve to the one
block, so each target gets the same edits under its own ids. Targets whose
mutants select the same tests share one run: the edit is applied and its tests
run once, and each target is listed with that verdict (DND-5639). A `defimpl` whose
`for:` is not a literal module name (a variable, an attribute), or that has no
`for:` inside an unnamed module, has no module name to give, so its functions
are `{:error, :defimpl_target_not_literal}`, reported as `defimpl target not a
literal`, never as a macro. A `for: nil` or `for: []` is the enclosing module,
as `scope` reads it. A module nested in a `defprotocol` or a `defimpl` is
found by its joined name (`P.Helpers`, `P.T.Helpers`); a `defprotocol`'s own
declarations (`def area(shape)`) have no body, so they yield no mutant (`no
mutable site`).

### Sabotage: running the mutants

```bash
mix anchor.sabotage run [--base REF] [--max N|all] [--only ID]... [--dry-run] [--coverage PATH]
                        [--no-record] [--domain D] [--ticket KEY] [--slot S]
                        [--print-survivor-lines] [--scope diff|all] [--shard I/N|auto]
                        [--report PATH]
mix anchor.sabotage restore
```

`run` (DND-5473) takes the functions `scope` finds, makes their mutants, and
applies them **one at a time**: it writes the mutant, runs only the tests
selected for it, puts the original back, and says what happened. It is built
to be safe on a desktop: sequential, capped (30 mutants by default; `--max all`
lifts the cap, for CI), targeted tests only, two test cases at once, every
test run bounded by `timeout_seconds`, and the source tree always restored.

It needs a `sabotage:` section in `.anchor.yml` (every key optional; the
defaults are shown) and the journal path in `.gitignore`:

```yaml
sabotage:
  test_command: ["mix", "test", "--max-cases", "2"]  # argv prefix, no shell
  max_mutants: 30                    # --max N overrides; --max all lifts it
  timeout_seconds: 300               # per test run, then `timeout --kill-after=10`
  operators: [delete_statement, drop_effect_call, narrow_clause, with_passthrough, force_condition, return_input]
  effect_calls: []                   # extra effect calls, "Module.fun" or "Module.fun/arity"
  test_mirror:                       # lib file -> test file; the first matching `from` wins
    - from: "apps/*/lib/**/*.ex"     # one `*` segment binds {app}; `**/*.ex` binds {rest}
      to: "apps/{app}/test/{rest}_test.exs"
    - from: "lib/**/*.ex"
      to: "test/{rest}_test.exs"
  coverage_map: anchor-coverage.etf  # optional: a per-test coverage map; --coverage PATH overrides
  records:                           # where the run's sabotage record goes (DND-5484)
    dir: "test/sabotage_records"     # may hold {app}: "apps/{app}/test/sabotage_records"
    naming: domain_date_slot         # <domain>-YYYYMMDD-<slot>.md; or ticket_nn_what: <TICKET>-<NN>-anchor-sabotage-run.md
    domain_from: module              # or context_dir: the directory under lib/<app>/
    domain_strip_prefixes: []        # e.g. ["MyApp.Domain.", "MyApp."]; the longest match is dropped
    adr: "the repo's sabotage-record ADR"  # named next to each test still lacking a red
  survivors: .anchor/sabotage/survivors.txt  # the survivors list (DND-5483); named here, it must exist
  behaviour_locality_baseline: .anchor/baselines/behaviour-locality.txt  # DND-5489; named here, it must exist
  behaviour_locality_enforcement: report  # or enforce: fail on NEW, STALE or GREW
  scan_shards: 7                     # the nightly scan's shards (DND-5490): --shard auto is days since 1970-01-01 mod 7
```

```gitignore
/.anchor/sabotage/in-flight.json
*.anchor-tmp
```

(`*.anchor-tmp` is a file mid-write, left only if the VM is killed during
the write.)

An unknown key or a bad value fails the load, naming the key, with a `Fix:`.

How a run goes:

0. The run takes the run lock (`_build/anchor-sabotage.lock`, the holder's OS
   pid and `/proc` start time) for its whole length, `restore` included: while
   a live run holds it a second run refuses, exit 2, and touches nothing, so
   two runs never share the journal, the results file or `_build`. A killed
   run's lock is taken over, one run at a time (under
   `_build/anchor-sabotage.lock.takeover`; a run killed in that step leaves it,
   and the next run refuses, exit 2, naming it to delete). Linux only: the lock and the journal's owner are
   read from `/proc`, so on a host without one (macOS) `run` and `restore`
   refuse, exit 2, with `Fix: run mix anchor.sabotage on Linux (a dev machine
   or CI)`, and touch nothing (DND-5571).
1. A journal left by a killed run (`.anchor/sabotage/in-flight.json`) is dealt
   with first: the file still holding the mutant is restored (and the run says
   so); a file already back loses only the journal; a file that matches
   neither is refused and left alone. A journal whose owner (the OS pid and
   start time of the run that wrote it, read from `/proc`) is still alive
   belongs to a run still going: the second run refuses, exit 2, and touches
   nothing. `mix anchor.sabotage restore` does this step alone.
2. Every target file must be committed: sabotage starts from committed code.
3. Mutants are ordered by file, function, operator and id; `--only` keeps the
   named ids; the cap keeps the first N and lists the rest `not run (cap)`.
   `--dry-run` prints this plan and writes nothing.
4. Each mutant's tests come from the first source that has any (the report
   names it on each line, and counts them in `tests selected by:`):
   `coverage`, the tests a per-test coverage map (`--coverage PATH` or
   `coverage_map`; below) lists for its `Module.fun/arity`, as `file:line`;
   else `mirror`, its mirror test file (`test_mirror`), if it exists; else
   `none`. Between coverage and the mirror comes `kill_map`: the test files
   whose tests killed a mutant of the same function in the records already
   there, with the mirror file when it exists, so a branch's new tests run
   too. Every path handed to `mix test`, from any source, must be a project
   `_test.exs` path: never starting with `-` or `/`, with no `..` or empty
   segment (DND-5640). A record holding a killer that fails this is skipped
   and named, as is one whose kill map does not parse (said:
   `could not read kill map in <path>:<line>`). A map that cannot be read,
   is exit 2 (`Fix: download the anchor-coverage artifact again`), and so is one that
   is not a version-2 map (`Fix: download a current anchor-coverage artifact, or
   rebuild it with mix anchor.sabotage coverage`); one built from a
   commit that is not an ancestor of `HEAD` is used, with a warning naming
   both commits.
5. The union of the selected tests runs once with no mutant (the baseline). If
   it fails, nothing can be judged: exit 3.
6. Per mutant: the journal is written (the file, the original bytes, both
   sha256s), then the mutant; its mtime is moved forward so Mix recompiles it;
   its tests run with Anchor's ExUnit formatter
   (`Anchor.Sabotage.ExUnitFormatter`, which writes each failed test to a
   results file; output is never parsed); then, in an `after` block, the
   original is written back, touched, its sha256 checked, and only then the
   journal deleted. A mutant whose run another target of the same
   `defimpl ..., for: [...]` edit already made (the same tests) is not applied
   again: it takes that run's verdict (DND-5639).
7. The run is saved to `<build_path>/anchor/sabotage/last-run.etf`: Mix's build
   path, `_build/<env>` or the directory `MIX_BUILD_PATH` names.
8. The sabotage record is written (DND-5484), unless `--no-record`: one
   file per (app, domain) the run touched (per app under `ticket_nn_what`),
   in the repo's naming. A second run the same day, in the same domain and
   slot, appends a `## Run HH:MM UTC` section; a file is never overwritten,
   and a README is never written. The slot is the branch
   sanitized, case kept (ADR 003: `dnd-5473-runner` -> `dnd_5473_runner`). Each record
   holds the header (Domain, Branch, Date, Code under test, Suite run,
   Generated by: the command, the Anchor version, the base and head SHAs),
   a **summary table** (one row per mutant: id, function, mutation, status,
   killer count; DND-5643), each mutant's patch, command, counts, failed tests and first failure as
   ExUnit printed it, the survivors, the kills by timeout, the skipped, invalid and not-run
   mutants, the **tests still lacking a red** (each new or changed test the
   diff touched that no mutant's run failed: it still needs a hand
   sabotage), and the **kill map**: a fenced `anchor-kills` block, one
   tab-separated row per mutant (`id, file, Module.fun/arity, operator,
   status, killers`; killers `file:line name` joined by ` ; `; a tab, a
   newline and a backslash written `\t`, `\n`, `\\`). A run that exits 1
   still writes its record; committing it is yours. Before any mutant is
   applied, a record that could not be named is refused, exit 2: a detached
   `HEAD` with no `--slot`, `ticket_nn_what` with no ticket key and no
   `--ticket` (`Fix: pass --ticket DND-NNN`), `{app}` in `dir` for a file
   outside `apps/<app>/`.

| Status | Meaning |
|---|---|
| `killed` | a selected test failed an assertion; those tests are the killers |
| `survived` | the selected tests ran and passed (`Fix: add a test that fails under this mutant`) |
| `timeout` | the time bound killed the run (killer `(timeout)`), or every failed test hit ExUnit's per-test timeout (killers `(test timeout) file:line name`; DND-5653). Counts as killed, but no assertion failed: the run names these on a `sabotage: N kills rest on time alone` line, and the record lists them under `## Kills by timeout` |
| `invalid` | the mutant did not compile (any reason, a type-checker warning under warnings-as-errors included: the compiler's first error line is shown). Never killed, never survived; listed and counted, and beside a measured mutant it never changes the exit code |
| `crashed` | the test run crashed or raised, so the tests could not judge the mutant (the line says why; an exit 137 inside the time bound reads `killed by signal 9`, an out-of-memory kill for one, and is never a timeout). Unmeasured |
| `no_tests` | no test was selected (the line names the mirror path looked for), or the selected tests ran none under the mutant. Unmeasured |

A test run's output is kept bounded (the first and last 32 KiB; the line of a
crashed run says how many bytes were dropped), so a mutant that prints without
end cannot fill the VM's memory.

A mutant is **measured** when it is `killed`, `survived` or `timeout`.
`crashed` and `no_tests` mutants are **unmeasured**: the tests could have
killed them and did not get to say.

Skipped mutants are listed with their reason and never applied; a changed
function with no literal clause is listed as an error, never as killed.

| Condition | Exit |
|---|---|
| every measured mutant killed or timed out (an `invalid` one beside them changes nothing) | 0 |
| zero changed functions from a good diff read (an empty scope: `sabotage: 0 changed functions in <base>..HEAD`) | 0 |
| changed functions that yielded no mutant at all (every edit skipped, no literal clause, a `defimpl` target not a literal, no mutable site): one `sabotage: no mutant from M.f/a (file): <reason>` line per function, then `sabotage: no mutants generated from N changed functions: nothing was measured` (DND-5617) | 0 |
| a mutant survived or had no test and is not on the survivors list (NEW), beside a measured one; a mutant crashed beside a measured one; a survivors entry now killed or no longer generated (STALE); a malformed survivors entry; a survivors file named in `sabotage.survivors` that does not exist (DND-5483) | 1 (a scan with `--report`: 0, see the nightly scan below) |
| mutants were run and none was measured (all `invalid`, `crashed` or without a test) | 3, `COULD NOT MEASURE` with `Fix:` |
| a record that could not be named (above); a record that could not be written, when every measured mutant passed (after the outcomes: a survivor stays 1 and an unmeasured run 3, each with `sabotage: record not written: <why>`; DND-5641); a dirty target file; the journal not git-ignored; the run lock or a journal another live run holds; a host with no `/proc`; a leftover journal whose file changed; a restore that did not reproduce the original (the journal is kept); an unknown `--only` id; no `timeout` binary; bad flags | 2, with `Fix:` |
| no loadable config or no `sabotage:` section; the scope could not be measured; the baseline fails; changed functions whose files cannot be read; the survivors file, or its copy at `--base`, cannot be read (DND-5483) | 3, `COULD NOT MEASURE` with `Fix:` |

### Sabotage: the survivors list

Some mutants no test can kill: dropping a log line nobody asserts on, or
narrowing a clause that only exists as a defensive fallback. Each such
survivor is listed, with its reason, in `.anchor/sabotage/survivors.txt`
(`sabotage.survivors` names another path; DND-5483):

```text
# One entry per line; blank lines and `#` lines are ignored.
3f9a01c2b7de lib/calc.ex Calc.validate/1 delete_statement  # logging only; no behaviour depends on it
```

The reason is required, and a placeholder (`TODO`, `TBD`, `FIXME`, the
`<why no test can kill it>` the run prints, or nothing) is refused. So is a
bad id, a missing field, an unknown operator or a duplicate id: the run
refuses before applying any mutant, exit 1, naming each entry.

`run` judges the list for the functions in its scope (the changed functions
and the functions of the mutants it generated), through the same comparator
as the graph baselines (`Anchor.Domain.Baseline.compare/2`), keyed on the
mutant id:

| Case | Printed | Exit |
|---|---|---|
| a `survived` or `no_tests` mutant the list does not hold | `NEW survivor <id> ...`, then a `Fix:` with the exact line to add | 1 |
| a listed mutant now killed, timed out or invalid, or no longer generated (its function changed) | `STALE survivor <id> ... Fix: delete its line from <path>` | 1 |
| an entry whose id names a mutant of another file, function or operator | `survivors file <path>, entry N (...)` with a `Fix:` | 1 |
| a listed survivor | its run line ends `listed in <path>: <reason>` | 0 |
| a listed mutant past the cap, left out by `--only`, whose run crashed, or whose function could not be mutated this run | `survivor <id> ... not judged (...)` | 0 |
| an entry for a function outside the scope | nothing | 0 |

The default path absent is an empty list (`no survivors file at ...: every
survivor is NEW`); a path named in the config that is absent is exit 1. A
crashed mutant cannot be listed: it fails the run as before.

The list only shrinks without review. The run reads the list's copy at
`--base` (default `origin/main`, the ref the scope reads) and prints the
entries this branch adds under `Survivors added by this branch: review each
reason` (all of them, said so, when the base has no list). That block never
changes the exit code: adding a survivor is allowed, and the reviewer sees
it. A base copy that cannot be read for any reason but its absence is exit 3.

`--print-survivor-lines` prints, at the end, the line to add for each NEW
survivor, with the placeholder reason to replace. The run never writes the
list.

### Sabotage: verifying a branch's records

```bash
mix anchor.sabotage verify --base REF [--format text|json]
```

The cheap check a gate runs once a branch's `run` has committed its record
(DND-5516). For the functions the diff since `REF` changes (the scope above),
it regenerates every mutant id from the working tree's source and checks each
is covered: by its latest row (records in path order, blocks in file order)
in the `anchor-kills` blocks of the records the branch added or appended to,
when that row is `killed`, `timeout` or `invalid`, or by a survivors entry
with that id, file, function and operator. It compiles nothing, runs no test,
applies no mutant and writes nothing, so it takes seconds and loads nothing.

A record is append-only, a block per run. A changed function's latest block
(records in path order, blocks in file order) is its last run; a row of that
block whose id the current source no longer generates means the function
changed after it was sabotaged. Older blocks are history.

| Finding | Line | Exit |
|---|---|---|
| a mutant with no covering row and no survivors entry | `UNCOVERED <id> <file> <M.f/a> <operator>: ...` | 1 |
| a row of a changed function's last run that is no longer generated | `STALE RECORD <path>: <M.f/a> changed after it was sabotaged ...` | 1 |
| a survivors entry with an empty, `TODO` or placeholder reason, a duplicate id, a malformed line, or an id that names another file, function or operator; a survivors file `sabotage.survivors` names that is absent | `BAD SURVIVOR <path>, entry N: ...` | 1 |
| a record the branch added or appended to whose kill map does not parse (it covers nothing) | `BAD RECORD <path>:<line>: ...` | 1 |
| a landed record the branch deleted | `RECORD REMOVED <path>: ...` | 1 |
| a changed function no literal clause defines | `NOT IN SOURCE <M.f/a>: ...` | unchanged |
| a survivors entry the branch added against `REF` | `REVIEW survivor added: ...` | unchanged |
| every mutant covered | `sabotage verify: F functions, M mutants, all covered (K killed, S survivors, I invalid)` (`K` counts timeouts too) | 0 |
| no changed function | `sabotage verify: no changed functions` | 0 |
| no `--base`, a `REF` git cannot read or Anchor refuses, an unknown flag | the usage, with a `Fix:` | 2 |
| no `sabotage:` config; the scope, a record or the survivors list (or its copy at `REF`) cannot be read; changed source files in which no function, outside hunk or macro was found; one mutant id generated twice | `COULD NOT MEASURE: ...` with a `Fix:` | 3 |

Every failure line ends with exactly one `Fix:`. `--format json` prints the
verdict's fields, and its exit code, for agents.

### Sabotage: replaying landed records

```bash
mix anchor.sabotage replay [--max N|all] [--records DIR_GLOB]...
```

A record proves a test failed once; a test can lose that power later (an
assertion loosened, a setup changed). `replay` (DND-5485) reads every
`killed` or `timeout` row of the `anchor-kills` blocks under
`sabotage.records.dir` (or each `--records` directory glob, inside the
project), and for each row:

1. regenerates the mutants of its `Module.fun/arity` on the current tree,
   with every operator, and finds the one with the recorded id (ids do not
   depend on lines, so a moved function still replays);
2. checks its killers' test files exist;
3. applies the mutant under `run`'s journal and lock, runs the killers by
   file and test name (`<file> --only test:<full name>`, so a moved test
   still runs), and restores the file.

Before any row, every killer runs once with no mutant; if any fails, main is
red and nothing can be judged (exit 3). The cap is `--max` (else
`max_mutants`); rows past it are listed `not replayed (cap)`. A `timeout`
row that names no test (`(timeout)`) runs the killer files of its
function's other killed rows in the same record, whole, and says so.

| Row | Printed | Exit |
|---|---|---|
| a killer failed (or the run timed out) | `still killed <id> ...` | 0 |
| every killer passed | `LOST POWER <id> M.f/a operator (<record>)`, each killer on `no longer failed by:`, and a `Fix:` | 1 |
| the run crashed | `CRASHED <id> ...` with a `Fix:` | 1 |
| it cannot be replayed as recorded: its file is gone or outside the project, a symlink is on its file's or a killer's path, its function is gone, no mutant has its id (the function changed), a killer's file or test is gone, a killer does not read as a test, a row killed by the time bound has no killed row to take its killer files from, it no longer compiles | `drifted (<reason>) <id> ...` | never on its own |
| zero rows, every row drifted, or a record that could not be read | `COULD NOT MEASURE` with `Fix:` | 3 |

A record whose kill map does not parse is named (`could not read ...`), and
the replay ends exit 3 however its other rows fare, unless a row lost power or
crashed (exit 1): its kills went unchecked. Like `run`, a replay refuses (exit 2) on a dirty row file, the run
lock held, or the journal not git-ignored, and never writes a record or the
survivors list. Anchor runs it weekly and on demand in CI
(`.github/workflows/sabotage-replay.yml`, `--max all`).

### Sabotage: the nightly improvement scan

```bash
mix anchor.sabotage run --scope all --shard I/N|auto --max all --report PATH [--coverage MAP]
```

Diff-scoped sabotage only checks what a branch touched; code that landed
before the tool, or was never touched since, is never sabotaged. The scan
runs the generator over every function with a literal clause in the
project's `lib` files (`--scope all`, DND-5490), one shard at a time:
`--shard I/N` keeps the mutants whose id, read as a hexadecimal number, is
`I` modulo `N`. An id hashes the mutant's function, operator and target,
never its line, so shards `0..N-1` together hold every mutant exactly once.
`--shard auto` runs the day's shard, the days since 1970-01-01 modulo
`sabotage.scan_shards` (default 7), so any 7 nights in a row scan all of main,
across a new year too, and no night runs everything.

`--report PATH` writes the report, markdown at `PATH` and its term beside it
as `.etf` (`Anchor.Domain.Sabotage.ScanReport`), and never a record
(`--scope all` writes none either). Its first line says how tests were
selected: from the coverage map, or, with none, from the kill maps and the
test mirror. Then the shard, the totals by status and by module, the
**findings** (the survivors the survivors list does not hold), and the
functions whose mutants had no test. Survivors never fail a scan: it exits 0
when it measured, 2 when the report could not be written (or a refusal), 3
`COULD NOT MEASURE` (no function in scope, a failing baseline, nothing
measured). A malformed `--shard` or `--scope` is a usage error, 2.

Anchor runs it nightly and on demand in CI (`.github/workflows/sabotage-scan.yml`):
it downloads the latest `anchor-coverage` artifact main's Coverage map
workflow uploaded (none is said, not a failure), runs the day's shard with
`--max all`, writes the report to the job summary and uploads it as the
`anchor-sabotage-scan` artifact. The job's token only reads. Whoever reads
the summary files one ticket per module with findings; the job files nothing
and fixes nothing.

### Sabotage: the per-test coverage map

```bash
MIX_ENV=test mix anchor.sabotage coverage [--out PATH] [--local] [-- TEST_ARGS]
```

`coverage` (DND-5474) runs the whole suite in its own VM, one test at a time
(`--max-cases 1`), with every call of the project's own modules traced (the
beams in the project's ebin directories; never a dependency or the standard
library). It writes the map test -> functions that test executed, private ones
included, to `PATH` (default `_build/test/anchor/coverage.etf`). `TEST_ARGS`
go to `mix test`, filters only (`--only`, `--exclude`, `--include`,
`--name-pattern`) when they narrow the run: the map is of the whole suite, so one that chooses files is
refused.

Every test file compiles first, then the suite runs, so no compiler runs while a
test does (DND-5691). Mix prints "There are no tests to run" between the two: it
ran none itself.

A call is credited to the test it ran on behalf of, whenever its trace message
arrives (DND-5691). The VM reads two values at the call (a match spec, so nothing
depends on time): a **window word** (the trace control word, odd while a test
runs) and the process's **seq_trace label**. Once the run is over:

1. **Ownership decides first.** A process is owned by a test when it was spawned,
   through any chain, by a process ExUnit's module runner spawned inside that
   test's window: the test process, its `on_exit` runner and all they start, even
   after a parent has died. A Task under a supervisor belongs to whoever started
   it (the owner pid in its spawn event's arguments). What the runner spawned
   between windows, setup_all's process above all, belongs to the module, and its
   calls are credited to every test of the module that ran.
2. **A label decides for a process with no owner**, and only inside its own
   window: a server handling a test's call or cast under the test's label is
   credited to that test, a server handling setup_all's request to every test of
   the module.
3. **Everything else is ambient**: compile-time calls, application boot, a server's
   own work, listed in the map and credited to no test.

A **leak fails the run, exit 1**. It is a call of project code by a process a test
(or a setup_all) owns, after that test (or module) ended; the map lists it as a
`(test or module, function)` pair and the run prints one line per pair and a
`Fix:` line. The call also stays in its owner's set. So these fail: a spinner a
test left running, a process the next test releases (with or without a label), a
grandchild whose parent is gone, a process that holds a port and calls project
code afterwards, a Task under an application's supervisor, a process from setup_all
that outlives its module.

What this does not fail, stated plainly:

- A process that outlives its test and never calls project code. It adds nothing
  to the map, so no result depends on it.
- Work handed to an application-owned server that finishes after the test returns
  (a cast with no reply), or a stale label on a server's timer, or
  `:timer.apply_after` past close. Past its label's window the call is ambient. A
  test makes it deterministic by syncing with the server. A server's own timer that
  fires inside the window of the test that last called it is credited to that test:
  the call looks the same as real work, and it can only select one more test.
- A worker an application supervisor starts on a test's behalf: application state.
- A test that lost its label (a message from a process with no token clears it)
  and then calls a server: that handler is ambient, listed, and selection falls
  through to the kill map or the mirror.
- A process a parameterized module's `setup_all` started, still calling while that
  module's next run goes: one name, so it is credited to the module. Only its last
  run's end counts as past the module.

The file is map version 2: `tests` (each test that ran, with its functions),
`leaks`, `ambient`, the commit, the Elixir and OTP versions, `suite_exit`, and
`counters`, which the summary line prints and which are not compared.
`CoverageMap.canonical/1` is the part two builds of one commit must share, byte for
byte, when neither leaked and no process with no owner works across a window's
close (the cast and the timer above). Those lists need not repeat: which call lands
past a window is scheduling. The repeatability check below still fails on such a
difference, and the fix is in the test: sync with the server.

It is **CI only by default**: without `CI=true` it refuses, exit 2, and
traces nothing (`Fix: run it in CI, or pass --local where that load is
acceptable`). Anchor's own map is built by `.github/workflows/coverage-map.yml`
(on a pull request, on push to main, weekly, and by hand) and, except on a pull
request, uploaded as the artifact `anchor-coverage` (30 days).

`mix anchor.sabotage coverage` exits:

| Condition | Exit |
|---|---|
| the map was written | 0 |
| the map was written, but a test leaked (each pair named, with a `Fix:` line), or the suite failed (`suite_exit: 1`; `Fix: make the suite green first`) | 1 |
| not CI and no `--local`; `MIX_ENV` not `test`; `TEST_ARGS` that set `--max-cases` (two tests at once would share their calls) or that choose files (a path, `--failed`, `--stale`, `--partitions`); another tracer already on; the map not writable | 2, with `Fix:` |
| zero project modules or zero tests (with the suite's own message when it failed before any test; a test file that does not compile is one), a project module that cannot load (named, with nothing traced), fewer windows than ExUnit's `total`, a test that ran with no entry message, a module that never reported finishing, a private ExUnit function that cannot be traced, a `Task.Supervised` spawn in an unknown shape, a seq_trace label from outside this run, or a trace message that cannot be read: no map is written | 3, `COULD NOT MEASURE` |

That workflow builds the map **twice in one job**, at one commit and one `--seed`,
and judges the two files with `mix anchor.sabotage coverage-compare FIRST SECOND`. It
is the guard for the rule that a tool or test whose result differs between identical
runs is wrong. `coverage-compare` exits:

| Condition | Exit |
|---|---|
| the canonical bytes are identical, and neither build leaked | 0 |
| a leak in either build: each build's pairs are printed, with a line saying a leak list is identical only at empty and a `Fix:` line. The lists are never compared | 1 |
| the suite failed in either build (`Fix: make the suite green first`) | 1 |
| the canonical bytes differ: each differing (test, function), each test in one build only and each ambient function is named, with a `Fix:` line. The fix goes in the test or the tool, never in an exclusion | 1 |
| wrong arguments | 2 |
| a map absent (a missing second build is never a pass), unreadable, of another version or measuring nothing; one file given as both builds; two maps not of one commit, Elixir and OTP; a map with no commit | 3, `COULD NOT MEASURE` |


### Sabotage: behaviours and how far they spread

```bash
mix anchor.sabotage behaviours [--coverage PATH] [--format text|json] [--write-baseline] [--base REF]
```

A test case is a behaviour. Its **confirmed causes** are the functions it executed (the
coverage map) and killed a mutant of (a `killed` row of a kill map). A function it only
executed may be incidental, so it does not count. A test with no confirmed cause is
**unconfirmed**, and the run counts those, so the gap shows: a function never mutated
confirms nothing yet. `--format json` lists them, and each behaviour's functions.

A behaviour's **directories** are the parent directories of its confirmed causes' files.
A behaviour whose causes sit in many directories takes many places to change, so each
directory is one line of a shrink-only baseline, keyed `<test file>::<full test name>`.
There is no line number in the key, so moving a test changes nothing. A cause with no
source file shows as `(generated)` and counts as no directory.

The command runs no test. It prints up to 20 behaviours, widest first, the totals, then:

| Line | Meaning |
|---|---|
| `NEW <key>` | the behaviour reaches one more directory than the baseline holds |
| `STALE <key>` | it reaches one fewer: delete that line |
| `GREW <key>` | with `--base`: the branch added this line to the baseline |

Killers that name no test of the map, and kills of a function the map says their test
never ran, confirm nothing and are counted on their own lines.

`--write-baseline` creates `sabotage.behaviour_locality_baseline` (default
`.anchor/baselines/behaviour-locality.txt`) and never replaces one. A default path with
no file is an empty baseline, and says so.

| Condition | Exit |
|---|---|
| measured, in `report` mode (the default), whatever the verdict; the baseline written | 0 |
| in `enforce` mode: NEW, STALE or GREW | 1 |
| in either mode: a baseline named in the config that is absent, or a malformed one | 1 |
| usage; `--write-baseline` over an existing file | 2 |
| no `sabotage:` config; no usable coverage map (`Fix: download a current anchor-coverage artifact (CI) and pass --coverage`) or one with no tests; a record that cannot be read; no `killed` row anywhere, or none that confirms a behaviour (`nothing confirms any cause yet`); the baseline unreadable, here or at `--base` | 3 |

Anchor runs it in report mode after each successful coverage map on main
(`.github/workflows/behaviour-locality.yml`).

## Check Types

### `no_direct_dependency`

Prevents direct dependencies on forbidden modules.

```yaml
- type: no_direct_dependency
  paths:
    - "lib/my_app/web/**/*.ex"
  forbidden_modules:
    - MyApp.Repo
  recursive: true
```

#### Module token syntax (`forbidden_modules` / `required_modules`)

Each entry in `forbidden_modules` and `required_modules` names a module in one of
two forms:

- **Elixir alias** — a CamelCase token such as `MyApp.Repo` or `Ecto.Query`.
  This targets the Elixir module of that name.
- **Erlang/OTP atom** — a **leading-colon** token such as `:telemetry` or
  `:cowboy`. This targets a bare Erlang module, matching a remote call like
  `:telemetry.execute(...)`. The token is kept as the raw atom, so quote it if
  your YAML parser would otherwise treat the leading `:` specially.

```yaml
# Forbid a direct dependency on an Erlang/OTP module.
- type: no_direct_dependency
  paths:
    - "lib/my_app/domain/**/*.ex"
  forbidden_modules:
    - ":telemetry"   # matches `:telemetry.execute(...)`
    - MyApp.Repo     # matches `MyApp.Repo.all(...)`
  recursive: true
```

#### Forbidding by pattern (`forbidden_patterns`)

Alongside the exact `forbidden_modules` list, `forbidden_patterns` forbids any
referenced module whose name matches a **module-name glob**. A `*` in the glob
crosses dots (module separators), so `*.Adapters.*` matches
`MyApp.Contacts.Adapters.Repository`. The `.` between segments is literal, so the
pattern is **dot-bounded**: `*.Adapters.*` matches a `.Adapters.` segment but
does **not** match `Foo.AdaptersHelper` (there is no dot after `Adapters`).
`forbidden_modules` and `forbidden_patterns` may be combined on one rule; a
module matched by both is reported once.

A pattern is matched against the module's fully-qualified name
(`Elixir.MyApp.Contacts.Adapters.Repository`) **and** its alias form
(`MyApp.Contacts.Adapters.Repository`), so a start-anchored pattern such as
`MyApp.Adapters.*` matches, as do `Elixir.MyApp.Adapters.*` and `*.Adapters.*`.
(Before DND-1290 only the fully-qualified name was tried, and a pattern had to
lead with `*`.) Every character other than `*` is a literal; see
[Glob syntax](#glob-syntax).

```yaml
# Forbid any adapter module, named or not, plus one exact module.
- type: no_direct_dependency
  pattern: "*.Domain.*"        # applies to Domain modules
  forbidden_patterns:
    - "*.Adapters.*"           # any module with an .Adapters. segment
  forbidden_modules:
    - MyApp.Repo
```

#### Forbidding functions (`forbidden_functions`)

`forbidden_functions` forbids calling one function of a module, not the whole
module. Use it when many files may use a module but only a few may call one of
its functions:

```yaml
- type: no_direct_dependency
  paths: ["lib/**/*.ex"]
  recursive: true
  forbidden_functions:
    - "Athena.Slack.user_info"        # every arity
    - "Athena.Slack.rule_post/2"      # only rule_post/2
    - ":ets.delete_all_objects"       # an Erlang/OTP module
```

Each entry is `"Module.function"` or `"Module.function/arity"`. The module is an
Elixir alias or a leading-colon Erlang module, as in `forbidden_modules`. The
function is an identifier, optionally ending in `?` or `!`. An entry that does
not name exactly one function fails the load: `"MyApp.Repo"` (no function),
`"MyApp.Repo.*"` (a glob; use `forbidden_patterns`), `"MyApp.Repo.insert/x"`.
`forbidden_functions` alone is a relation, so a rule may carry only it.

A call is resolved the way the compiler resolves it (aliases, imports,
`__MODULE__`; see below), and **every shape that reaches the function** is
reported, whatever `match` says. (`match` still governs the rule's
`forbidden_modules` and `forbidden_patterns`; on a rule with only
`forbidden_functions` it fails the load, because nothing reads it.)

| Shape | Example |
|---|---|
| Remote call, through any alias | `Athena.Slack.user_info(id)`, `Slack.user_info(id)`, `S.user_info(id)` after `alias Athena.Slack, as: S` or `alias Athena.{Slack, Other}` |
| Imported bare call (`only:`/`except:` honoured) | `user_info(id)` after `import Athena.Slack` |
| Pipe (the piped value counts toward the arity) | `id \|> Slack.user_info()`, `id \|> user_info()` |
| Capture | `&Slack.user_info/1`, `&Slack.user_info(&1)`, `&user_info/1` via import |
| `apply/3` and the other MFA dispatchers | `apply(Slack, :user_info, [id])`, `Slack \|> apply(:user_info, [id])`, `Kernel.apply/3`, `:erlang.apply/3`, `Function.capture/3`, `:erlang.make_fun/3` |
| An MFA held as data (module, atom and a literal argument list, in a row) | `spawn(Slack, :user_info, [id])`, `Task.start(Slack, :user_info, [id])`, `{Slack, :user_info, [id]}` |
| `defdelegate` | `defdelegate lookup(id), to: Athena.Slack, as: :user_info` |
| A module attribute bound to a literal module in the same module | `@slack Athena.Slack` then `@slack.user_info(id)` or `apply(@slack, :user_info, [id])` |
| A bare `Kernel` call (for a `Kernel.*` token) | `send(pid, msg)`, `pid \|> send(msg)`, `&send/2` match `"Kernel.send/2"` while `Kernel` owns `send/2` |

**One function, every spelling (DND-5613).** Elixir compiles some stdlib calls
into Erlang ones before the graph engine sees them (`Map.put/3` is
`:maps.put/3`, `Process.monitor/1` is `:erlang.monitor(:process, pid)`). An
entry may name either spelling, and both engines match a call written in
either: `":maps.put/3"` matches a source `Map.put(m, k, v)`, and `"Map.put/3"`
matches `:maps.put(k, v, m)`. Two Elixir names the compiled call tells apart by
a literal tag stay apart: `"Process.monitor/1"` never matches
`Port.monitor(p)`. Two it cannot tell apart (`Bitwise.band/2` and
`Bitwise.&&&/2`) match each other; `Inlines.describe/1` names every candidate
of such a call (`effects_match_bucket` names an effect primitive that way).
Residuals: a `Map.put` onto a literal map folds into the literal when compiled,
so the graph sees no call (the AST rule still does); and a source call written
in Erlang spelling with a tag (`:erlang.monitor(:port, p)`) matches every Elixir
name of that Erlang function in the AST rule, which does not read arguments. A
token in `architecture.effects` is matched the same way, so the demand analysis
reads a token `Process.monitor/1` against a Core `:erlang.monitor(:port, p)`
too: a false positive there, never a miss.

Each function reached is reported once per rule, at its first line. Where the
source does not show an arity (`apply(M, :f, args)`), the call matches every
arity. An arity token matches that arity only, as Elixir counts it:
`"MyApp.Repo.insert/2"` does not match `Repo.insert(changeset)`, even when a
default argument makes that call reach `insert/2`. Leave the arity off to
forbid every arity. A module's call to its **own** function (`user_info(id)` inside
`Athena.Slack`) is local, not a call on the module, and is not reported.
Neither is a module held as a value, an `alias` line, a typespec, or a string.
A module next to an atom without an argument list is not an MFA:
`GenServer.call(Athena.Slack, :user_info)` sends a message to a process, and
`%{Athena.Slack => :user_info}` and `{Athena.Slack, :user_info}` are data.

A call whose module or function the source cannot show is reported, not
skipped, when it **could** reach a forbidden function: `mod.user_info(id)` on a
variable or call-result module, or on an attribute not bound to a literal
module, `apply(mod, :user_info, args)`, `apply(Athena.Slack, fun, args)`,
`apply(mod, fun, args)`, `&mod.user_info/1`, `&apply/3`,
`defdelegate ..., to: @unbound`, and an unquote fragment outside a `quote`
(`Athena.Slack.unquote(name)(id)`, `defdelegate unquote(name)(id), to:
Athena.Slack` in a comprehension). The issue names the functions it could reach
and ends with `Fix:`. A dynamic call that cannot reach one (`mod.fetch(x)` when
only `user_info` is forbidden) is not reported. Each such call site is reported
once, however many rules apply.

Limits a source check cannot close:

- A call a macro injects (`use Foo` that expands into `Athena.Slack.user_info`)
  is not in the source. Keep a compiled-code check for it.
- An anonymous call `fun.(x)` is not reported: the function value was made by
  a capture, `Function.capture/3` or `:erlang.make_fun/3`, and that site is
  checked. `map.field` without parens reads a field and is not a call.
- An MFA-taking API other than the dispatchers above is matched only when its
  module and function are literal. Anchor cannot know which arguments of an
  arbitrary function are an MFA, so a dynamic one there is not reported.
- A call inside a `quote` is checked (the macro emits it), but a dynamic one
  there (`unquote(mod).f()`) is macro code and is skipped, as a non-literal
  directive in a `quote` is.

#### Allowing named callers (`allowed_callers`)

`allowed_callers` names the modules that may do what the rule forbids every
other module. Use it for a single sanctioned caller, such as the one adapter
that may read Slack user names:

```yaml
- type: no_direct_dependency
  id: slack-name-reads-single-caller
  paths: ["lib/**/*.ex"]
  recursive: true
  forbidden_functions:
    - "Athena.Slack.user_info"
  allowed_callers:
    - Athena.Priorities.SlackNameAdapter
```

- **Exact names only.** Each entry is one Elixir module, spelled as its
  `defmodule` spells it in full. The entry is not resolved through aliases,
  but the source is: Anchor names each module the way Elixir does, so after a
  top-level `alias Evil.Ns, as: MyApp`, `defmodule MyApp.Adapter` defines
  `Evil.Ns.Adapter`, which is not exempt. A glob
  fails the load: it would widen the rule every time a later change adds a
  module with a matching name, with no config change to review.
- **Per defining module, not per file.** Each call and reference belongs to
  the module whose body it is in. A second module in the allowed module's
  file is not exempt, so a file cannot launder a call through its second
  module. A module nested in an allowed one is its own module and is not
  exempt; an allowed module nested in another is exempt, and the code of the
  enclosing module after it is not.
- **Protocols.** A `defprotocol` is a module. A `defimpl Proto, for: Type` is
  the module `Proto.Type` (aliases resolved; without `for:`, the enclosing
  module), so list that name to exempt it. A `defimpl` with a `for:` list
  defines one module per type, so its code is never exempt.
- **Never exempt:** code outside every module, code inside a `quote` (it runs
  in whichever module the macro expands into), and a `defmodule` whose name is
  not a literal, with everything in it.
- **What it exempts.** Every relation of this rule: `forbidden_modules`,
  `forbidden_patterns`, `forbidden_functions`, and a dynamic call that could
  reach one of its forbidden functions. For this rule only: another rule that
  does not list the module still reports it. A directive whose target cannot be
  resolved is reported whatever the rules say. `same_context` still scopes the
  callers that are not listed.
- **A listed module that no longer exists** is an issue on `.anchor.yml` in a
  whole-project run (see [A rule that checks nothing](#a-rule-that-checks-nothing)).

`allowed_callers` narrows a rule, so it is not a relation: a rule needs one of
`forbidden_functions`, `forbidden_modules` or `forbidden_patterns` beside it.

#### Reference vs. call matching (`match`)

`match` selects which dependencies the rule inspects:

- `match: reference` (the **default**) flags a forbidden module referenced in
  **any** position — a call, a value held in a map or keyword list, a typespec.
- `match: call` flags a forbidden module only when it appears in **call
  position** (`Foo.Adapters.L.enrich(x)` or `apply(Foo.Adapters.L, :enrich, [x])`).
  Call position includes a pipe (`Foo.Adapters.L |> apply(:enrich, [x])`), the
  other MFA dispatchers (`Kernel.apply/3`, `:erlang.apply/3`,
  `Function.capture/3`, `:erlang.make_fun/3`), `defdelegate ..., to:
  Foo.Adapters.L` (DND-1280), and a call on a module attribute bound to a
  literal module (`@loader Foo.Adapters.L` then `@loader.run(x)`). An existing
  `match: call` rule may report these new call sites. A call on a variable
  module is dynamic dispatch and is not reported at module level: any such call
  could reach any module. An MFA held as data (`{Foo.Adapters.L, :run, []}`) is
  held, not called, so it is not a call dependency; a `forbidden_functions`
  rule does count it.
  A module merely **held as an atom** — e.g. a Domain router keeping an adapter
  module as a map value it never itself calls — passes under `call`. This honors
  the "Domain-router-holds-atoms" carve-out: holding an adapter atom is allowed,
  calling it is not.

Both modes resolve modules the way the compiler does, lexically per module:

- `alias A.B`, `alias A.B, as: C`, `alias A.{B, C}` and `require A.B, as: C`
  make `B.f()` / `C.f()` a dependency on the **full** module (`A.B`, `A.C`). A
  multi-alias never counts as a dependency on its bare prefix `A`.
- A nested `defmodule Child` makes `Child` mean `Parent.Child`, and
  `alias __MODULE__.Sub` / `__MODULE__.Sub.f()` resolve against the enclosing
  module.
- Under `match: call`, `import A.B` makes a bare call (`f(x)`, `x |> f()`,
  `&f/1`) a call on `A.B`. `only: [f: 1]` narrows that to exactly the listed
  name/arity pairs, and `except:` removes pairs. An unrestricted import claims
  every bare call that is not a function the module defines itself or a
  `Kernel`/special-form call, because the imported module's exports are not
  visible to a source-only check.
- A directive applies to the code after it in the same block and to everything
  nested in it. It never leaks out of its module or function.
- A directive whose target is not a literal module (`alias @target, as: T`) is
  itself reported, with a `Fix:` line: references made through it cannot be
  checked, and the rule must not read green over them.

```yaml
# A Domain router may HOLD adapter atoms (a lookup table) but must never CALL them.
- type: no_direct_dependency
  pattern: "*.Domain.Router"
  forbidden_patterns:
    - "*.Adapters.*"
  match: call                  # `%{yaml: Foo.Adapters.Loader}` passes; `Foo.Adapters.Loader.run()` fails
```

#### Same-context scoping (`same_context` / `context_depth`)

By default a `forbidden_patterns` match is a violation wherever it occurs.
`same_context` narrows a pattern so it fires **only when the forbidden dependency
lives in the same context (subdomain) as the file being checked**. This expresses
a rule a static glob cannot: *"an adapter must not call a Manager in **its own**
subdomain, but calling **another** subdomain's Manager (its public API) is
allowed."*

Two keys, both on a `no_direct_dependency` rule:

- **`same_context`** — boolean, default `false`. `true` turns scoping on.
- **`context_depth`** — positive integer, default `2`. How many leading
  namespace segments define a context. A module's **context** is the first
  `context_depth` dot-separated segments of its name: at depth 2,
  `MyApp.Contacts.Managers.Foo` has context `["MyApp", "Contacts"]`.

Scoping semantics, and their edges (all grounded in the shipped detection):

- **A pattern match is reported iff the dependency's context equals the file's
  own context**, both truncated to `context_depth`. The file's own context is
  derived from the file's first defining module name.
- **Exact `forbidden_modules` matches are never scoped.** They name absolute IO
  modules (`MyApp.Repo`, `:telemetry`) for which "same subdomain" is meaningless,
  so they always report regardless of `same_context`. Only `forbidden_patterns`
  matches are scoped.
- **Fewer than `context_depth` segments ⇒ no context ⇒ not reported.** If either
  the dependency **or** the file has fewer than `context_depth` namespace
  segments, it has no derivable context, is treated as *not* same-context, and
  the match is not reported.
- **A file with no derivable module name ⇒ nothing reported (deny-side default).**
  Under a `same_context` rule, a file whose context cannot be derived (`nil`
  context) reports nothing for that rule's pattern matches — with no file context
  to compare against, a scoped match cannot be confirmed same-context.
- **`same_context: false` or absent ⇒ today's behavior exactly** — every pattern
  match is reported. This is a hard back-compat guarantee; a `context_depth` on a
  rule without `same_context: true` is inert.

A `same_context: true` rule that has no `forbidden_patterns` (nothing to scope) is
rejected at config load with `{:error, {:invalid_rule, _}}`, as are a non-boolean
`same_context` and a non-positive `context_depth` — a malformed rule fails the
load rather than silently becoming a green no-op.

```yaml
# Forbid an adapter from calling a Manager IN ITS OWN subdomain, while still
# allowing it to call another subdomain's Manager (the cross-subdomain public API).
- type: no_direct_dependency
  paths:
    - "lib/my_app/*/adapters/**/*.ex"
  recursive: true
  forbidden_patterns:
    - "*.Managers.*"     # any Manager module...
  same_context: true     # ...but only when it shares the adapter's own subdomain
  context_depth: 2       # context = MyApp.<Subdomain>
  match: call
```

Because patterns are matched against the module's fully-qualified name (which
carries the `Elixir.` prefix), lead the pattern with `*` — `"*.Managers.*"`, not
`"MyApp.*.Managers.*"` — exactly as for `forbidden_patterns` generally. The
`same_context`/`context_depth` comparison, by contrast, is done on the plain
namespace segments (`Elixir.` stripped) of both the file's and the dependency's
module names.

### `no_transitive_dependency`

Prevents transitive (indirect) dependencies on forbidden modules. This check analyzes the entire dependency graph to ensure that a module doesn't depend on forbidden modules through intermediary modules.

```yaml
- type: no_transitive_dependency
  pattern: "MyApp.Web.*"  # Apply to all Web modules
  forbidden_modules:
    - MyApp.Repo  # Web shouldn't depend on Repo, even indirectly
```

Example violation:
- `MyApp.Web.UserController` → `MyApp.Core.Users` → `MyApp.Repo` ❌
- The Web layer indirectly depends on Repo through the Core layer

Like `no_direct_dependency`, this check also accepts `forbidden_patterns` —
module-name globs (dot-bounded `*` crosses dots) matched against every
transitively-reachable module, in addition to the exact `forbidden_modules`
list. (The `match` mode is specific to `no_direct_dependency`; the transitive
graph is always reference-based.)

```yaml
- type: no_transitive_dependency
  pattern: "MyApp.Web.*"
  forbidden_patterns:
    - "*.Adapters.*"           # Web must not reach any adapter, even indirectly
```

### `must_use_module`

Ensures modules in specific directories use required modules.

```yaml
- type: must_use_module
  paths:
    - "lib/my_app/schemas/**/*.ex"
  required_modules:
    - MyApp.Schema
  recursive: true
```

### `module_pattern_restrictions`

Restricts which functions modules matching certain patterns can define.

```yaml
# By module name pattern
- type: module_pattern_restrictions
  pattern: "*.Queries"
  allowed_functions: ["new", "with_*"]

# By used module
- type: module_pattern_restrictions
  uses_module: "Ecto.Schema"
  allowed_functions: ["changeset", "__changeset__", "__schema__", "__struct__"]
```

### `single_control_flow`

Ensures function clauses contain at most one control-flow structure (case, cond, with, if).

```yaml
- type: single_control_flow
  paths:
    - "lib/my_app/**/*.ex"
  recursive: true
```

### `no_tuple_match_in_head`

Prevents pattern matching on :ok/:error tuples in function heads to avoid coupling.

```yaml
- type: no_tuple_match_in_head
  paths:
    - "lib/my_app/**/*.ex"
  recursive: true
```

### `case_on_bare_arg`

Discourages case statements on bare function arguments.

```yaml
- type: case_on_bare_arg
  paths:
    - "lib/my_app/**/*.ex"
  recursive: true
```

### `alphabetized_functions`

Ensures functions in modules are ordered alphabetically. Supports three modes:
- `:all` - All functions must be in alphabetical order
- `:public_only` - Only public functions must be in alphabetical order
- `:separate` (default) - Public and private functions are alphabetized separately

Functions with the same name but different arities are sorted by arity (e.g., `foo/0` before `foo/1`).
Sorting is case-insensitive.

```yaml
- type: alphabetized_functions
  mode: :separate  # :all, :public_only, or :separate (default)
  paths:
    - "lib/my_app/**/*.ex"
  recursive: true
```

### `max_file_length`

Ensures files do not exceed a maximum number of lines. Large files are harder to understand, navigate, and maintain. By limiting file length, you encourage better code organization and separation of concerns.

The default maximum is 400 lines, but this can be configured.

```yaml
- type: max_file_length
  max_lines: 400  # default is 400
  paths:
    - "lib/my_app/**/*.ex"
  recursive: true
```

### `no_comparison_in_if`

Ensures that `if` statements do not contain direct comparisons in their conditionals. Instead, comparisons should be extracted to functions with descriptive names that convey domain meaning.

This improves code readability by expressing intent rather than implementation.

Bad:
```elixir
if user.age >= 18 do
  # ...
end

if user.status == :active and user.verified? do
  # ...
end
```

Good:
```elixir
if adult?(user) do
  # ...
end

if eligible_user?(user) do
  # ...
end

defp adult?(user), do: user.age >= 18
defp eligible_user?(user), do: user.status == :active and user.verified?
```

```yaml
- type: no_comparison_in_if
  paths:
    - "lib/my_app/**/*.ex"
  recursive: true
```

### `struct_getter_convention`

Ensures that getter functions follow a consistent pattern. A function is considered a getter if ALL of the following are true:
1. The function takes exactly one argument
2. The function pattern matches a struct type on that argument
3. The pattern match extracts a value from the struct
4. The function returns that value with no additional processing

For getter functions, this check validates:
1. The function name matches the field being extracted
2. The function is defined in the struct's module

This promotes a clean, predictable API where field access is simple and consistent.

Bad:
```elixir
defmodule MyApp.User do
  defstruct [:name, :email, :profile]
  
  # Wrong: function name doesn't match field
  def get_name(%__MODULE__{name: name}), do: name
  
  # Wrong: processes the value (not a getter)
  def email(%__MODULE__{email: email}), do: String.downcase(email)
end
```

Good:
```elixir
defmodule MyApp.User do
  defstruct [:name, :email, :profile]
  
  def name(%__MODULE__{name: name}), do: name
  def email(%__MODULE__{email: email}), do: email
  def profile(%__MODULE__{profile: profile}), do: profile
end
```

Note: This check allows getters to return `%Ecto.Association.NotLoaded{}` structs, as this is the natural behavior when associations aren't loaded.

```yaml
- type: struct_getter_convention
  paths:
    - "lib/my_app/**/*.ex"
  recursive: true
```

### `no_discarded_pure_expression`

Reports an expression whose value nobody uses and which has no effect, so it
causes nothing (DND-5451). It is dead code that reads as if it mattered: a
leftover computation, or a `Map.put/3` whose result was meant to be rebound.
The compiler warns about an unused variable, but not about
`Map.put(state, :k, v)` on its own line, nor about `_ = Enum.map(xs, f)`.

Two positions are checked:

- every expression of a block except the last (the last is the block's value):
  function, `fn`, clause, `do`/`else` and module bodies;
- the right side of `_ = expr` or `_name = expr` written in such a position.
  `x = expr` binds a value and `:ok = call()` asserts a match, so neither is
  reported.

Code inside `quote` is skipped (it is a macro's output).

An expression is **pure**, by Anchor's definition, exactly when it is:

1. a literal: an atom, a number, a string, `nil`, `true`, `false`;
2. a variable, or a module attribute read (`@attr`);
3. a list, tuple, map, map update, struct, binary or interpolated string whose
   every element is pure;
4. an operator over pure operands: `+ - * / ++ -- <> == != === !== < > <= >=
   and or not && || ! in .. |>` (a pipe is the call it builds), or a field
   read `x.field` / `x[:k]` on a pure value;
5. a call `M.f(args)` where `M`, resolved through the aliases in scope, is in
   the **stdlib pure set** or matches a `pure_patterns` glob, `f` does not end
   in `!`, and every argument is pure. The stdlib pure set is `Access`,
   `Atom`, `Base`, `Bitwise`, `Date`, `Enum`, `Float`, `Integer`, `Keyword`,
   `List`, `Map`, `MapSet`, `NaiveDateTime`, `Range`, `Stream`, `String`,
   `Time`, `Tuple`, `URI`, except the clock reads (`Date.utc_today`,
   `NaiveDateTime.utc_now`, `NaiveDateTime.local_now`, `Time.utc_now`), the
   random reads (`Enum.random`, `Enum.shuffle`, `Enum.take_random`), the
   atom-table writes and lookups (`String.to_atom`, `List.to_atom`,
   `String.to_existing_atom`, `List.to_existing_atom`), `Stream.run` and
   `URI.default_port/2` (a setter). An argument a stdlib function may call (its `@spec` types it
   as a function, or as a `Collectable.t()`) must be written out: an `fn` or
   a capture literal that is pure (not the `&1` placeholder), `:asc`,
   `:desc`, a boolean or `nil`, or a container literal naming no module. A
   function held in a variable, a field or an attribute may be any function,
   and a module there has its `compare/2` called, so
   `Enum.each(xs, notify)` is not pure. A stdlib function with no spec is
   judged as calling every argument;
6. a local call `f(args)` to a function its own module defines (`def` or
   `defp`), in a module whose name matches a `pure_patterns` glob, `f` not
   ending in `!`, every argument pure. A name an `import` or a `use` brings in
   (`field/2` inside `embedded_schema`) is unknown, so not pure;
7. a `Kernel` pure function over pure arguments: `abs div rem max min length
   elem hd tl tuple_size map_size byte_size bit_size to_string inspect` and the
   `is_*` guards;
8. an `fn` whose every clause body is pure, `&(...)` of a pure expression, or
   a capture `&M.f/n` / `&f/n` of a pure function.

Anything else is not pure, so it is never reported: an unknown call (it may be
an effect), a dynamic call (`mod.f()`, `apply/3`, `fun.()`), `send`, `raise`,
`throw`, `exit`, `spawn`, a bang function, and every `case`, `cond`, `if`,
`with`, `receive` or `try` (control flow is judged inside, not as a whole).
So `Enum.each(xs, &IO.puts/1)` is not reported and
`Enum.each(xs, fn x -> x + 1 end)` is.

```elixir
def put(state, value) do
  Map.put(state, :key, value)   # reported: its result is thrown away
  state
end
```

Each issue ends with `Fix: use the value (bind it and use the binding, or make
it the block's last expression), or delete it. A call kept for its effect must
be to a module outside pure_patterns and the stdlib pure set.`

```yaml
- type: no_discarded_pure_expression
  paths:
    - "lib/my_app/**/*.ex"
  recursive: true
  pure_patterns:          # optional: your own pure modules
    - "MyApp.*.Domain.*"
```

Known limits. The first four can report code that does have an effect; the
rest are misses or cosmetic:

- Raising is an effect only for a bang function and `raise`/`throw`/`exit`. A
  non-bang call kept only for its raise (`String.to_integer(s)` as
  validation) is reported; bind and use it, or check explicitly.
- A variable holding a lazy stream with effects (`File.stream!/1`) is a pure
  value here, so `Enum.each(stream, fn _ -> nil end)` on it is reported. The
  graph engine's effects inference (DND-5447) knows better. The same holds
  for any value whose protocol implementation has an effect: `inspect/1` or
  `to_string/1` on a struct with its own `Inspect` or `String.Chars`, or an
  `Enum` call on a struct with its own `Enumerable`.
- A `pure_patterns` module's arguments are judged as data: a function value
  passed to one of its functions is trusted to be called purely, because the
  declaration says the module is pure. Keep callbacks with effects out of
  `pure_patterns` modules.
- `mod.f` written without parentheses on a variable reads as a field read, so
  a zero-arity call through a module held in a variable is judged pure
  (Elixir warns on that form).
- A bare literal carries no line in the parsed source, so its issue sits on
  the nearest enclosing line.
- Purity of your own functions is not inferred from the call graph: that is
  the graph engine's (DND-5447, DND-5470). Declare pure namespaces with
  `pure_patterns`.

### `no_forwarding_function`

Reports a function whose every clause only hands its arguments, unchanged and
in order, to another function of the same module (DND-5452, proposal F4). The
hop adds depth and causes nothing: inside one module no boundary is crossed.

```elixir
def total(items, tax), do: do_total(items, tax)   # reported: total/2
defp do_total(items, tax), do: Enum.sum(items) * (1 + tax)
```

A clause forwards when its head is distinct bare variables (no pattern, no
`_` name, no default, no guard) and its body is exactly one call, `g(a, b)`,
`__MODULE__.g(a, b)` or `a |> g(b)`, passing exactly those variables in the
same order to a `def`/`defp` of the same module that is not itself. A
multi-clause function is reported only when every clause forwards to the same
function. `defdelegate f(a, b), to: __MODULE__, as: :g` is reported the same
way.

Not reported: any change to an argument, a reordering, a dropped or added
argument, a body of more than one expression, a call to a function the module
does not define (imported, aliased or remote), a call to itself, a function
marked `@impl` (a behaviour callback is a boundary) or `@deprecated` (an API
transition), a `defimpl` body (protocol callbacks), and code inside `quote`. A
nested `defmodule` is its own module.

Each issue names both functions and ends with `Fix: inline the hop: make the
callers of f/n call g/n directly and delete f/n, or rename g/n to f/n (public
if f/n was). Keep a forwarding function only where it crosses a boundary (a
behaviour callback marked @impl, another module's public API).`

**The split with `no_inert_hop` (DND-5463).** This rule judges only what one
file shows: a hop within one module, where no boundary can be crossed. A hop
to another module, a `defdelegate` to another module and a facade module may
cross a bucket, context, app, aggregate or interface boundary, which only the
architecture model knows, so those are the graph rule `no_inert_hop`'s.

```yaml
- type: no_forwarding_function
  paths:
    - "lib/my_app/**/*.ex"
  recursive: true
```

### `struct_owned_by_module`

Only a struct's own module builds or changes it, so each invariant has one
home (DND-5453, proposal M2). This is the part of crew's
`StructOnlyChangedByOwnModule` that one file's text decides.

Outside the struct `S`'s own module, in an expression position, it reports:

- `%S{...}` and `%S{s | ...}`;
- `struct(S)`, `struct(S, kw)`, `struct!(S)`, `struct!(S, kw)` (bare or
  `Kernel.`) naming another module;
- on a variable known, in the same function clause, to be another module's
  struct: `%{s | ...}`, `Map.put`, `put_new`, `put_new_lazy`, `merge`,
  `replace`, `replace!`, `update`, `update!`, `delete`, `drop` (piped or
  not), `struct(s, ...)`, and `put_in`/`update_in`/`pop_in`/`get_and_update_in`
  on a path through it.

A variable is **known** as `S` when every place the clause binds it (the
head, `=`, a `case`/`with`/`fn`/`receive` clause pattern, a `<-`) matches it
as `%S{}` (`%S{} = s`), or binds it to a `%S{...}` literal. Any other binding
of that name in the clause (bare, rebound to a call, matched as a different
struct, an `fn` argument of the same name) makes it unknown, and nothing is
reported on it.

**Allowed:** reading fields, `Map.get/2,3`, `Map.from_struct/1`,
`Map.delete(s, :__struct__)` and a `Map.drop/2` that drops `:__struct__`
(both convert to a plain map), struct patterns anywhere (heads, `case`,
`with`, `fn`, `receive`, `for`, `=`, `match?`), and typespec attributes. The
owner is the innermost `defmodule`, and inside `defimpl P, for: M` it is `M`:
a protocol implementation for a struct is that struct's own code. Code
outside every module owns no struct. Names resolve the way Elixir resolves
them (aliases, `as:`, multi-aliases, a nested module's automatic alias,
`__MODULE__`). Code inside `quote` is skipped.

**Test code** is exempt by selection, not by a hard-coded path: select `lib`
paths.

```yaml
- type: struct_owned_by_module
  paths:
    - "lib/**/*.ex"
  recursive: true
  owned_namespaces:      # optional: only these namespaces' structs
    - MyApp
```

With `owned_namespaces`, only structs equal to or nested under an entry are
checked, so a stdlib or dependency struct (`URI`, `DateTime`, `MapSet`), which
your code cannot give a function, is out of scope. A selected top-level
`defmodule` outside them is itself an issue, so a new namespace is never
silently unchecked: `Module NewApp.Thing is outside owned_namespaces, so its
structs would never be checked. Fix: add its namespace to owned_namespaces,
or stop selecting this file.`

Each build or change issue names the struct and ends with `Fix: call a
function on S's own module that builds or changes it (e.g. S.new/1,
S.put_<field>/2); read fields and pattern-match freely.`

What a typespec in another file says (a field typed as a struct, a
function's return) and what a macro injects is the graph rule
[`struct_owned_by_module_flow`](#the-struct_owned_by_module_flow-rule-dnd-5454)'s.

Known limits, each a miss: a value bound to a function's return
(`s = Turn.new()`) or a field typed as a struct (`state.turn`) is not known,
because that needs another file's typespec: the graph rule DND-5454 judges
it. A name the source cannot resolve (an `unquote` in a struct literal, an
alias of a non-literal module) is not reported. A top-level module named by
an alias in scope inherits DND-1282's literal-`defmodule` naming.

