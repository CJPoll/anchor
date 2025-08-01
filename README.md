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