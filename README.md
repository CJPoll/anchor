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

### Selecting which files a rule applies to

Every rule chooses the files it applies to with **exactly one** of three
selectors, tried in this order:

1. `paths` — a list of path globs matched against the file's path. Recursive
   `**` semantics apply when `recursive: true`, single-`*` semantics otherwise.
2. `pattern` — a module-name glob matched against any module the file defines
   (for example `"*.Schemas.*"`).
3. `uses_module` — selects files that `use` the named module (for example
   `"Ecto.Schema"`).

A rule that carries **none** of these selectors matches nothing (deny by
default).

Omitting `paths` is meaningful: a rule with no `paths` key is parsed with
`paths: nil` (an *absent* selector), so selection falls through to `pattern` or
`uses_module`. This differs from `paths: []` (an empty list), which is also
treated as "no path selector". In other words, a `pattern`- or
`uses_module`-only rule does **not** need an empty or placeholder `paths` entry
— leave `paths` off entirely and the module selector is honored.

### Config schema: rule keys at a glance

A single reference for the rule keys, including the four added for full
five-bucket enforcement. Each is shown with the minimal example that exercises
it; the per-check sections under [Check Types](#check-types) carry the full
semantics and edge cases.

| Key | Applies to | Meaning |
|---|---|---|
| `paths` | any rule | Path-glob selector. **Absent** ⇒ parsed as `nil`, so selection falls through to `pattern`/`uses_module`; this differs only cosmetically from an explicit `[]` (also "no path selector"). A present list selects by path (recursive `**` when `recursive: true`). |
| `pattern` | any rule | Module-name-glob selector (`*` crosses dots). |
| `uses_module` | any rule | Selects files that `use` the named module. |
| `recursive` | any rule | `true` gives `paths` globs `**` (across-segment) semantics. |
| `forbidden_modules` / `required_modules` | dependency / `must_use_module` | Exact module tokens (see the token syntax below). |
| `forbidden_patterns` | `no_direct_dependency`, `no_transitive_dependency` | Module-name globs; forbids any referenced/reachable module whose name matches. |
| `match` | `no_direct_dependency` | `reference` (default) or `call` — which dependency set the rule inspects. |
| `same_context` | `no_direct_dependency` | Boolean, default `false`. When `true`, a `forbidden_patterns` match is a violation **only if** the dependency shares the checked file's own context. Exact `forbidden_modules` matches are never scoped. |
| `context_depth` | `no_direct_dependency` | Positive integer, default `2`. Number of leading module-namespace segments that define a "context/subdomain". Inert unless `same_context: true`. |
| `allowed_functions` | `module_pattern_restrictions` | Function-name allow-list (globs). |
| `mode`, `max_lines` | `alphabetized_functions`, `max_file_length` | Style-check parameters. |

**`forbidden_patterns` — module-name globs (dot-bounded).** A `*` crosses dots,
so `*.Adapters.*` matches `MyApp.Contacts.Adapters.Repository`, but the `.`
between segments is literal, so the pattern is dot-bounded: it matches a
`.Adapters.` segment and does **not** match `Foo.AdaptersHelper`. Patterns are
matched against the fully-qualified name (`Elixir.MyApp…`), so lead with `*`.

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
          {Anchor.Check.StructGetterConvention, []}
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

A pattern is matched against the module's **fully-qualified** name, which
includes the `Elixir.` prefix for Elixir modules (e.g.
`Elixir.MyApp.Contacts.Adapters.Repository`). Because `*` crosses dots, lead a
pattern with `*` (as every example here does) to match from the front — a
start-anchored pattern such as `MyApp.Adapters.*` would never match, since the
name begins with `Elixir.`. Write `*.Adapters.*` (or `*MyApp.Adapters.*`)
instead.

```yaml
# Forbid any adapter module, named or not, plus one exact module.
- type: no_direct_dependency
  pattern: "*.Domain.*"        # applies to Domain modules
  forbidden_patterns:
    - "*.Adapters.*"           # any module with an .Adapters. segment
  forbidden_modules:
    - MyApp.Repo
```

#### Reference vs. call matching (`match`)

`match` selects which dependencies the rule inspects:

- `match: reference` (the **default**) flags a forbidden module referenced in
  **any** position — a call, a value held in a map or keyword list, a typespec.
- `match: call` flags a forbidden module only when it appears in **call
  position** (`Foo.Adapters.L.enrich(x)` or `apply(Foo.Adapters.L, :enrich, [x])`).
  A module merely **held as an atom** — e.g. a Domain router keeping an adapter
  module as a map value it never itself calls — passes under `call`. This honors
  the "Domain-router-holds-atoms" carve-out: holding an adapter atom is allowed,
  calling it is not.

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