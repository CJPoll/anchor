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
```

For umbrella applications, you can place the configuration at the root or in individual apps.

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
          {Anchor.Check.CaseOnBareArg, []}
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