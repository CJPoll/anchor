# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Anchor is an Elixir library that provides architectural constraint enforcement through custom Credo checks. It allows developers to define and enforce module dependency rules, usage requirements, and function restrictions.

## Development Commands

- **Install dependencies**: `mix deps.get`
- **Run tests**: `mix test`
- **Run specific test**: `mix test path/to/test.exs:line_number`
- **Compile**: `mix compile`
- **Generate docs**: `mix docs`
- **Format code**: `mix format`

## Architecture

The codebase follows a clear separation between the core library logic and Credo check implementations:

### Core Modules
- `Anchor` - Main entry point, provides `check_anchors/1` function
- `Anchor.Config` - Parses and validates `.anchor.yml` configuration files
- `Anchor.DependencyAnalyzer` - Analyzes module dependencies and builds dependency graphs

### Credo Checks
All checks inherit from `Anchor.Check.Base` and are located in `lib/anchor/check/`:
- `NoDependency` - Enforces forbidden dependencies between modules
- `MustUseModule` - Ensures modules matching patterns use required modules
- `ModulePatternRestrictions` - Restricts functions that can be defined in pattern-matched modules
- `SingleControlFlow` - Ensures function clauses contain at most one control-flow structure
- `NoTupleMatchInHead` - Prevents pattern matching on :ok/:error tuples in function heads

### Key Architectural Decisions

1. **Configuration via YAML**: All rules are defined in `.anchor.yml` files, making them easily maintainable and version-controlled
2. **Credo Integration**: Leverages Credo's infrastructure for AST traversal and issue reporting
3. **Pattern Matching**: Uses Elixir pattern matching for flexible module selection (e.g., `MyApp.*.Controller`)
4. **Transitive Dependency Analysis**: Can enforce rules on entire dependency chains, not just direct dependencies

## Testing Approach

- Tests use `Hammox` for mocking external dependencies
- Each check has comprehensive test coverage in `test/anchor/check/`
- Tests follow the pattern of creating mock modules and asserting on Credo issues

## Configuration Format

Anchor rules are defined in `.anchor.yml`, as a `rules:` list. The README's
Configuration section is the reference; this is the shape:

```yaml
rules:
  - type: no_direct_dependency
    pattern: "*.Domain.*"
    forbidden_patterns:
      - "*.Web.*"

  - type: must_use_module
    pattern: "*.Controller"
    required_modules:
      - MyApp.ControllerHelpers

  - type: module_pattern_restrictions
    pattern: "*.Queries"
    allowed_functions:
      - with_*
      - new
```

Anchor fails closed (DND-1265): a missing `.anchor.yml`, a config that does not
load (bad YAML, an unknown top-level key, an unknown rule `type`, `match` or
`mode`), and an unparseable source file are each reported as a Credo issue with
a `Fix:` line, never as a clean run. `Anchor.Domain.Failures` holds the messages.

A rule may carry only the keys its type reads, and needs a selector (`paths`,
`pattern` or `uses_module`); anything else fails the load (DND-1286). The
per-type key allowlist has one home, `Anchor.Domain.RuleSchema`. A new rule key
goes there, into `Anchor.Config.parse_rule/1`, and into the README table "Keys
each rule type accepts" (a test compares the table with the allowlist).

## Important Notes

- When running Elixir code, use: `mix run -e "<elixir code>"`
- The library is designed to be used as a dependency in other Elixir projects
- All checks produce Credo issues that can be suppressed with standard Credo comments
- The dependency analyzer builds a complete module graph for accurate transitive analysis