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

### Buckets (ADR 001)

Every module is in one bucket; the full table, with why, is in
`adrs/001-five-bucket-architecture.md` ("How this maps to Anchor"). Framework
is the Credo checks **and the Mix tasks**: Framework calls Managers and Domain,
never an adapter.

| Bucket | Modules |
|---|---|
| Framework | `Anchor.Check.*` (Credo checks, `Anchor.Check.Base`, `Anchor.Check.Source`), `Mix.Tasks.Anchor.*` (`lib/mix/tasks/`; `Mix.Tasks.Anchor.Sabotage`), `Anchor.Sabotage.CoverageCollector` (an OTP process) |
| Managers | `Anchor.Managers.Lint`, `Anchor.Managers.Sabotage` (`.Runner`, `.Coverage`) |
| Side Effects | ports: `Anchor.Adapters.ConfigLoader`, `ChangeSource`, `BeamSource`, `Tracing`, `InProcessTests`, `ProjectModuleSource`, `CoverageStore`; adapters: `ConfigFile`, `GitChangeSource`, `BeamReader`, `CallTracer`, `SuiteRunner`, `ProjectModules`, `CoverageFile` (`lib/anchor/adapters/`) |
| Domain | everything under `lib/anchor/domain/`, including `Anchor.Domain.Sabotage.*` (`Mutator`, `Operators`, `DiffHunks`, `FunctionSpans`, `Scope`) and `Anchor.Domain.Graph.*` |

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
a `Fix:` line, never as a clean run. So is a check that raises on a file
(DND-1310): `Anchor.Managers.Lint` catches it per file (see its moduledoc,
"Analysis crashes"). `Anchor.Domain.Failures`
holds the messages.

An AST clause that matches a special form or directive by name (`quote`,
`import`, `case`, ...) matches the call only (`args` a list): a variable with that
name is `{name, meta, context_atom}` (DND-1310). The table in
`test/fixtures/special_variable_names.txt` drives the analyzer and every check.

A rule may carry only the keys its type reads, and needs a selector (`paths`,
`pattern` or `uses_module`); anything else fails the load (DND-1286). The
per-type key allowlist has one home, `Anchor.Domain.RuleSchema`. A new rule key
goes there, into `Anchor.Config.parse_rule/1`, and into the README table "Keys
each rule type accepts" (a test compares the table with the allowlist).

Globs (`paths`, `pattern`, `forbidden_patterns`, `allowed_functions`) are
compiled in one place, `Anchor.Domain.GlobPattern` (DND-1292): `*` and `**`
are the only wildcards, and every other character is escaped with
`Regex.escape/1`. No other `lib/` file builds or runs a regex (`Regex.`, `=~`,
`String.match?`, `~r`, `:re.`); a test in `glob_pattern_test.exs` enforces it.
A new glob-bearing key calls `GlobPattern`.

`no_direct_dependency` takes `forbidden_functions: ["Mod.fun", "Mod.fun/arity"]`
(DND-1267). The token grammar has one home, `Anchor.Domain.FunctionRef` (string
functions, no regex; globs are refused). Every call shape that reaches a
function is recorded in one place, `DependencyAnalyzer.function_references/1`;
a new shape goes there, with a row in the table test
`test/anchor/domain/checks/no_dependency_forbidden_functions_test.exs`. A call
the source cannot resolve is recorded as dynamic and reported when it could
reach a forbidden function, never dropped.

A rule that loads but checks nothing fails too (DND-1290), as one class:
more than one selector, `recursive` without `paths`, a relation-bearing rule
with no relation, a relation list of empty strings, a match-all
`allowed_functions` entry, a bad `min_files` or `id`. The relation each type
checks against has one home, `@relations_by_type` in `Anchor.Domain.RuleSchema`
(`[]` means the type has none). What load time cannot decide is reported at run
time by `Anchor.Managers.Lint` through `Anchor.Domain.RuleCoverage`: a rule that
selects fewer files than its `min_files` (default 1), and a rule whose check is
not enabled.

Extension rule:
- A key the rule checks against goes into its type's `@relations_by_type` list
  as well as `@keys_by_type`, and then satisfies the relation alone. T3
  (DND-1267) adds `forbidden_functions` to `no_direct_dependency` this way, so a
  rule with only `forbidden_functions` has a relation.
- A new key or rule type MUST add its rows to its type's table in
  `test/anchor/domain/rule_checks_nothing_test.exs`: a refused row per way it
  can make a rule check nothing, and a positive row. A test fails until every
  accepted key has a row, and compilation fails when a type has no
  `@relations_by_type` entry.

Every rule type has exactly one engine, `@engine_by_type` in
`Anchor.Domain.RuleSchema` (DND-5437): `:ast` (a Credo check) or `:graph`
(`mix anchor.graph`, DND-5440; no graph type ships yet). A new rule type adds its entry there too (compilation
fails without it) and to the README table's Engine column (a test compares
them). Credo never reports a `:graph` rule as unchecked
(`RuleCoverage.unchecked/3`).

The optional top-level `architecture:` section (DND-5437) is parsed by
`Anchor.Domain.Architecture.parse/1` into `%Anchor.Config{architecture: ...}`
(`nil` when absent). Every refusal starts with its key path and carries a
`Fix:`. A new key goes into its level's key list there (`key_paths/0`) and gets
a table in `test/anchor/domain/architecture_checks_nothing_test.exs` (a test
fails until it does). `Anchor.Domain.Classification` classifies a module's facts
into exactly one bucket, with no precedence between buckets. Until the graph
runner (DND-5440) lands, the section is parsed and validated only: nothing
reads it at run time.

## The causal graph (DND-5438)

The graph engine reads compiled beams, never source alone, so macro output is
visible. `Anchor.Adapters.BeamReader` (behaviour `Anchor.Adapters.BeamSource`)
reads each `.beam` with `:beam_lib` only and asks its debug-info backend for
`elixir_v1` (module facts) and `core_v1` with `[:no_copt]` (function bodies as
Core Erlang, the way Dialyzer reads them). It never loads or calls a project
module. A beam it cannot decode is an error value naming path, module and
cause, never skipped. `Anchor.Domain.Graph.Builder` builds `%Anchor.Domain.Graph{}`
from those records and `Anchor.Domain.Graph.SourceFacts` (literal `defmodule`s,
for `generated?`); `Anchor.Domain.Graph.CoreWalker` reads call and struct-use
edges from Core. A new Core shape goes into the walker with a row in
`test/anchor/domain/graph/core_walker_test.exs`. Graph test fixtures are
compiled in the test with `Anchor.Test.BeamFixtures.compile_unloaded/2`, which
unloads every fixture module and turns `debug_info` on per module (`mix test`
compiles with it off).

## Higher-order flow (DND-5497)

`Anchor.Domain.Cfa.analyze/3` is a whole-program 0-CFA over every
`def`/`defp`'s Core: each apply site (`fun.(x)`, `apply/2`, the invocation
inside an `Anchor.Domain.HigherOrder` function such as `Enum.map/2`) is
`{:ok, closures}` or `:any`, counted per function and in total, never dropped.
Lambdas, sites and container allocation sites are numbered by
`Anchor.Domain.Core.label/1`. Roots come in as a seed (`Cfa.default_seed/1` is
the open world: every exported function's parameters are `any`). The worklist
is bounded by `:max_steps`; a run that hits it reports every site `:any`. A
library function that calls an argument gets a row in `HigherOrder`'s table;
a missing row costs precision (its arguments escape), never soundness.

## Important Notes

- When running Elixir code, use: `mix run -e "<elixir code>"`
- The library is designed to be used as a dependency in other Elixir projects
- All checks produce Credo issues that can be suppressed with standard Credo comments
- The dependency analyzer builds a complete module graph for accurate transitive analysis

## Sabotage runs (DND-5473)

`mix anchor.sabotage run` applies one mutant at a time and must never load the
machine: sequential, capped, targeted tests, a `timeout` bound on every test
run, two test cases by default. It reads the optional top-level `sabotage:`
section (`Anchor.Domain.Sabotage.Config`; a new key goes into its `@keys`, its
moduledoc table and the README's `sabotage:` YAML block). The source tree is restored in an `after` block and a
journal (`.anchor/sabotage/in-flight.json`, which must be git-ignored) covers a
VM kill; a leftover journal is dealt with before anything else, unless its
owner (OS pid and `/proc` start time) is alive: then the run refuses. One run
at a time: each run holds `_build/anchor-sabotage.lock` from its first step to
its last (a dead holder's lock is taken over). A mutant that
does not compile is `invalid`, never killed. Failed tests come from
`Anchor.Sabotage.ExUnitFormatter`'s frames, never from parsed output; the
formatter calls no other Anchor module, so it loads alone in a project's test
VM. The flow is in `Anchor.Managers.Sabotage.Runner`'s moduledoc.

## Per-test coverage (DND-5474)

`mix anchor.sabotage coverage` builds the map test -> project functions it
executed, CI only unless `--local` (`.github/workflows/coverage-map.yml`,
artifact `anchor-coverage`). Windows come from traced
`ExUnit.EventManager.test_started/2`/`test_finished/2` calls with strict
monotonic stamps, never from a formatter (formatter events are async). The
windowing is pure (`Anchor.Domain.Sabotage.CoverageMap`); the collector
process (`Anchor.Sabotage.CoverageCollector`, Framework) is started by the
Mix task and reached by the Manager only through the `Tracing` port. The
`:arity` trace flag keeps every traced argument out of the collector. A test
that turns VM-wide tracing on is tagged `@moduletag :global_tracing`, and the
coverage build runs with `--exclude global_tracing`. `run --coverage PATH`
selects a mutant's tests from the map first (source `coverage`), then the
mirror.
