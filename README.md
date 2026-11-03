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
  `rules`, `architecture` and `sabotage` (for example `anchors:`; `sabotage:` is
  described in [Sabotage: running the mutants](#sabotage-running-the-mutants)),
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
| `id` | any rule | A name for the rule, unique in the file. It appears beside the rule's position in its load errors and floor reports (`rule 2 (id: "web-no-repo", ...)`). |
| `forbidden_modules` / `required_modules` | `no_direct_dependency`, `no_transitive_dependency` / `must_use_module` | Exact module tokens (see the token syntax below). |
| `forbidden_patterns` | `no_direct_dependency`, `no_transitive_dependency` | Module-name globs; forbids any referenced/reachable module whose name matches. |
| `forbidden_functions` | `no_direct_dependency` | `"Module.function"` or `"Module.function/arity"` tokens; forbids calling (or capturing) that function, in every call shape. A malformed token fails the load. See [Forbidding functions](#forbidding-functions-forbidden_functions). |
| `allowed_callers` | `no_direct_dependency` | Exact module names, default `[]`. Code in a listed module is exempt from every relation of this rule. A glob, an Erlang module or a malformed name fails the load; an entry no selected file defines is an issue. See [Allowing named callers](#allowing-named-callers-allowed_callers). |
| `match` | `no_direct_dependency` | `reference` (default) or `call` — which dependency set the rule inspects. Any other token fails the load. |
| `same_context` | `no_direct_dependency` | Boolean, default `false`. When `true`, a `forbidden_patterns` match is a violation **only if** the dependency shares the checked file's own context. Exact `forbidden_modules` matches are never scoped. |
| `context_depth` | `no_direct_dependency` | Positive integer, default `2`. Number of leading module-namespace segments that define a "context/subdomain". Inert unless `same_context: true`. |
| `allowed_functions` | `module_pattern_restrictions` | Function-name allow-list (globs). |
| `owned_namespaces` | `struct_owned_by_module` | Exact module names, default: every struct. Limits the check to structs equal to or nested under an entry, and reports a selected top-level module outside them. `[]`, a glob, an Erlang module or a malformed name fails the load. See [`struct_owned_by_module`](#struct_owned_by_module). |
| `pure_patterns` | `no_discarded_pure_expression` | Module-name globs, default `[]`: modules whose functions are pure, beside the stdlib pure set. A non-list, a blank entry or a match-all glob (`*`, `**`) fails the load. See [`no_discarded_pure_expression`](#no_discarded_pure_expression). |
| `mode`, `max_lines` | `alphabetized_functions`, `max_file_length` | Style-check parameters. `mode` is `all`, `public_only` or `separate` (a leading colon is accepted); any other token fails the load. |

#### Keys each rule type accepts

A rule may carry only the keys its type reads. Every type accepts the common
keys: `type`, `paths`, `pattern`, `uses_module`, `recursive`, `min_files` and
`id`. The table lists
the keys each type accepts beyond those. Any other key fails the load, and the
message names the rule, the unknown key, the nearest known key and every key the
type accepts. So a misspelling such as `forbiden_patterns:` or `patern:` is an
error, not a rule that silently checks less than it says. A key that belongs to
another type (`match` on a `no_transitive_dependency` rule) is unknown too.

The Engine column is the one engine that runs the type: `ast` rules run as
Credo checks over source, `graph` rules run under `mix anchor.graph` over the
compiled code (DND-5440; no `graph` type ships yet). Credo never reports a
`graph` rule as unchecked.

| Rule type | Keys beyond the common ones | Relation (needs one, non-empty) | Engine |
|---|---|---|---|
| `alphabetized_functions` | `mode` | none | `ast` |
| `case_on_bare_arg` | none | none | `ast` |
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
| `single_control_flow` | none | none | `ast` |
| `struct_getter_convention` | none | none | `ast` |
| `struct_owned_by_module` | `owned_namespaces` | none | `ast` |

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
mix anchor.graph [--format text|json] [--only RULE_ID]...
```

Judges the project's compiled code against `.anchor.yml`'s `architecture:`
section and every enabled graph rule. It compiles the project, reads every
beam of every app (an umbrella's every `apps/*` app) with `:beam_lib` only, and
builds the causal graph fresh every run: it never loads or runs a project
module and never reads a cached verdict. Then it classifies every module into
exactly one bucket, checks every floor, and runs each graph rule under its own
guard. It is the command a CI step or a pre-commit gate runs after `mix
compile`; Anchor's own CI runs it.

Text output is one line per finding, then a summary:

```
lib/my_app/stray.ex:1: [enforce] anchor.graph MyApp.Stray is in no architecture bucket. Fix: add a selector that matches lib/my_app/stray.ex to the bucket this module belongs in (mix anchor.explain lib/my_app/stray.ex shows the candidates).
anchor.graph: 214 modules in 1 apps, 0 rules, 1 violations (0 report-only, 0 baselined)
```

No graph rule type ships yet: the rule tickets (layering, interfaces,
context_acyclic, ...) add them, with the graph rule keys `bucket`,
`min_modules` and `enforcement`. Until the first lands, a run classifies every
module and judges every bucket floor. A finding of a rule with
`enforcement: report` prints `[report]` and does not fail the run. `--format json` prints `{"modules", "apps", "rules", "opaque",
"exit_code", "findings": [{rule_id, type, enforcement, key, file, line,
message, fix}], "could_not_check": [...]}`. `--only RULE_ID` (repeatable) runs
only the rules with those ids; each rule that runs is still judged against its
floor (`--only` narrows the rules, never the modules), and an id that names no
graph rule is COULD NOT MEASURE. `--base` and
`--write-baseline` arrive with baselines (DND-5441); until then they are
refused as unknown options.

The only file it writes is `_build/<env>/anchor/graph.etf`, the graph keyed by
a sha256 of the beams, the config and Anchor's version, for `mix
anchor.explain` and `place`. The verdict never reads it; a write that fails is
a `[report]` note.

An Erlang module in the project is classified by its name only (a `pattern:`
selector): a classified one is an opaque node with no edges, counted in the
summary as `(<n> opaque)`; an unclassified one is an issue. No setting
excludes a module silently.

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
| Zero project modules read | 3 | the first ebin | `COULD NOT MEASURE: read 0 modules from _build/dev/lib/my_app/ebin. Fix: run mix compile in this project; ...` |
| A beam with no `debug_info` (or stripped) | 1 | the beam | `MyApp.X was compiled without debug_info, so Anchor cannot read it. Fix: remove debug_info: false from the project's elixirc_options ...` |
| The backend refuses `elixir_v1` (`{:elixir_v1_refused, _}`) | 1 | the beam | `MyApp.X the beam's backend could not produce its Elixir debug info (...). Fix: recompile with the project's own Elixir; ...` |
| The backend refuses `core_v1` (`{:core_v1_refused, _}`) | 1 | the beam | `MyApp.X the beam's backend could not produce Core Erlang (...). Fix: recompile with the project's own Elixir; ...` |
| A module compiled with a `parse_transform` or `core_transform` (`{:core_v1_refused, {:transform, _}}`) | 1 | the beam | `MyApp.X was compiled with {:parse_transform, :pt}, which lowering to Core Erlang would run, and Anchor runs no project code. Fix: remove the transform ...` |
| Decoding a beam crashed (`{:decode_crashed, _}`) | 1 | the beam | `MyApp.X could not be decoded: Anchor crashed reading it (...). Fix: this is an Anchor bug; file it with this line.` |
| Walking a module's Core crashed (`{:walk_crashed, _}`, DND-5548) | 1 | the beam | `MyApp.X could not be added to the graph: Anchor crashed walking it (...). Fix: this is an Anchor bug; ...` |
| One module in two ebins (`{:duplicate_module, _}`) | 1 | the extra beam | `MyApp.X is in two ebins: ... and ... (kept). Fix: run mix clean to remove a stale beam, or rename one of the two modules.` |
| A beam or ebin that cannot be read (`{:unreadable, _}`) | 1 | that path | `The beam ... could not be read (:eacces). Fix: make ... readable; ...` |
| An Erlang module no bucket classifies | 1 | the beam | `:my_erl is Erlang source; the graph engine reads Elixir only, and no architecture bucket classifies it. Fix: move it under a dependency, or classify it with a pattern: selector ...` |
| A module whose literal `use`s its source cannot show (a non-literal `defmodule` name), when a `uses_module` selector exists | 1 | the source file | `MyApp.X's literal uses cannot be read from lib/x.ex (its defmodule name is not literal there), so a uses_module selector cannot be judged for it. Fix: ...` |
| A module's source file that cannot be read or parsed | 1 | the source file | `Anchor could not read the source of lib/x.ex (:enoent), so its uses_module selectors and generated? are unknown. Fix: ...` |
| An unclassified module | 1 | its source file, at its `defmodule` line | `MyApp.X is in no architecture bucket. Fix: add a selector that matches lib/x.ex ...` |
| An ambiguous module | 1 | its source file, at its `defmodule` line | `MyApp.X is in buckets domain (by paths [...]) and framework (by uses_module GenServer). Fix: narrow one selector; buckets never take precedence.` |
| A bucket below its `min_modules` | 1 | the config | `architecture bucket domain selects 3 modules, below min_modules 10. Fix: correct the selector; lowering min_modules is the owner's call.` |
| An `interfaces.exports` entry that names no module | 1 | the config | `architecture interfaces.exports names MyApp.Gone, which is no module of the project ... Fix: ...` |
| A graph rule below its `min_modules` | 1 | the config | `rule 2 (id: "web", layering) selects 0 modules, below min_modules 1. Fix: correct the selector; ...` |
| A graph rule that raises, throws or exits | 1 | the config | `rule 2 (id: "web", layering) could not run: RuntimeError: ... Fix: this is an Anchor bug; file it with this line.` The other rules still run. |
| Findings of a `report` rule | 0 | the finding | printed `[report]` |

Exit 2 is a usage error (an unknown option, `--format` other than `text` or
`json`, an argument), with a `Fix:` line.

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

### Sabotage: running the mutants

```bash
mix anchor.sabotage run [--base REF] [--max N|all] [--only ID]... [--dry-run]
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
   and the next run refuses, exit 2, naming it to delete). Linux only: with no `/proc` the lock and the
   journal's owner name no process, and protect nothing.
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
4. Each mutant's tests are its mirror test file (`test_mirror`), if it exists.
5. The union of the selected tests runs once with no mutant (the baseline). If
   it fails, nothing can be judged: exit 3.
6. Per mutant: the journal is written (the file, the original bytes, both
   sha256s), then the mutant; its mtime is moved forward so Mix recompiles it;
   its tests run with Anchor's ExUnit formatter
   (`Anchor.Sabotage.ExUnitFormatter`, which writes each failed test to a
   results file; output is never parsed); then, in an `after` block, the
   original is written back, touched, its sha256 checked, and only then the
   journal deleted.
7. The run is saved to `_build/<env>/anchor/sabotage/last-run.etf`.

| Status | Meaning |
|---|---|
| `killed` | a selected test failed; those tests are the killers |
| `survived` | the selected tests ran and passed (`Fix: add a test that fails under this mutant`) |
| `timeout` | the time bound killed the run; counts as killed, killer `(timeout)` |
| `invalid` | the mutant did not compile (any reason, a type-checker warning under warnings-as-errors included: the compiler's first error line is shown), the test run crashed, or no test ran. Never killed, never survived; counted in the summary |
| `no_tests` | no test was selected (the line names the mirror path looked for) |

Skipped mutants are listed with their reason and never applied; a changed
function with no literal clause is listed as an error, never as killed.

| Condition | Exit |
|---|---|
| every mutant run killed, timed out or invalid | 0 |
| a mutant survived or had no test | 1 |
| a dirty target file; the journal not git-ignored; the run lock or a journal another live run holds; a leftover journal whose file changed; a restore that did not reproduce the original (the journal is kept); an unknown `--only` id; no `timeout` binary; bad flags | 2, with `Fix:` |
| no loadable config or no `sabotage:` section; the scope could not be measured; the baseline fails; changed functions whose files cannot be read | 3, `COULD NOT MEASURE` with `Fix:` |

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

Known limits, each a miss: a value bound to a function's return
(`s = Turn.new()`) or a field typed as a struct (`state.turn`) is not known,
because that needs another file's typespec: the graph rule DND-5454 judges
it. A name the source cannot resolve (an `unquote` in a struct literal, an
alias of a non-literal module) is not reported. A top-level module named by
an alias in scope inherits DND-1282's literal-`defmodule` naming.

