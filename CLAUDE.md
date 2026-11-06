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
| Framework | `Anchor.Check.*` (Credo checks, `Anchor.Check.Base`, `Anchor.Check.Source`), `Anchor.Aggregate` (the compile-time macro, DND-5476), `Mix.Tasks.Anchor.*` (`lib/mix/tasks/`; `Mix.Tasks.Anchor.Sabotage`), `Anchor.Sabotage.CoverageCollector` (an OTP process, in `lib/mix/tasks/anchor/sabotage/` so `mix anchor.graph` buckets it as Framework) |
| Managers | `Anchor.Managers.Lint`, `Anchor.Managers.Sabotage` (`.Runner`, `.Coverage`) |
| Side Effects | ports: `Anchor.Adapters.ConfigLoader`, `ChangeSource`, `BeamSource`, `Tracing`, `InProcessTests`, `ProjectModuleSource`, `CoverageStore`, `BaselineStore`, `GitBase`; adapters: `ConfigFile`, `GitChangeSource`, `BeamReader`, `CallTracer`, `SuiteRunner`, `ProjectModules`, `CoverageFile`, `RecordFile` (port `RecordStore`), `BaselineFile`, `GitShow` (`lib/anchor/adapters/`); `GitEnv`, the environment the git adapters run git with (DND-5581) |
| Domain | everything under `lib/anchor/domain/`, including `Anchor.Domain.Sabotage.*` (`Mutator`, `Operators`, `DiffHunks`, `FunctionSpans`, `Scope`, `CoverageMap`, `Record`, `RecordNaming`, `KillMap`, `ChangedTests`, `TestPath`: the one rule for a path handed to `mix test`, DND-5640) and `Anchor.Domain.Graph.*` |

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
(`mix anchor.graph`, DND-5440; the graph types are `layering`, DND-5442,
`context_acyclic`, DND-5445, `aggregate_declarations`, DND-5476,
`effects_match_bucket`, DND-5447, `struct_owned_by_module_flow`, DND-5454, and
`analyses_complete`, DND-5715). A new rule type adds its entry there too (compilation
fails without it) and to the README table's Engine column (a test compares
them). Credo never reports a `:graph` rule as unchecked
(`RuleCoverage.unchecked/3`).

The optional top-level `aggregates:` section (DND-5476) is parsed by
`Anchor.Domain.Aggregates.Config`; `Anchor.Domain.Aggregates.Index` merges it
with every module's persisted `@anchor_aggregate` (`use Anchor.Aggregate`,
Framework, `lib/anchor/aggregate.ex`, or the attribute by hand) into
`Model.aggregates`, and the `aggregate_declarations` graph rule reports what
names nothing or is claimed twice. Its canary has its own root,
`test/fixtures/graph_canary/aggregate_declarations/` (with its own config, so
the shared canary's counts do not move). A rule's fail-closed violation
(`kind: :fail_closed`, here "checks nothing") is an issue of the run: the
runner enforces it under `enforcement: report` and never holds it in a
baseline. A schema's table is read from its
`__schema__(:source)` clause in Core, never by calling it.

The optional top-level `architecture:` section (DND-5437) is parsed by
`Anchor.Domain.Architecture.parse/1` into `%Anchor.Config{architecture: ...}`
(`nil` when absent). Every refusal starts with its key path and carries a
`Fix:`. A new key goes into its level's key list there (`key_paths/0`) and gets
a table in `test/anchor/domain/architecture_checks_nothing_test.exs` (a test
fails until it does). `Anchor.Domain.Classification` classifies a module's facts
into exactly one bucket, with no precedence between buckets; the graph runner
(below) reads the section at run time.

## The causal graph (DND-5438)

The graph engine reads compiled beams, never source alone, so macro output is
visible. `Anchor.Adapters.BeamReader` (behaviour `Anchor.Adapters.BeamSource`)
reads each `.beam` with `:beam_lib` only and asks its debug-info backend for
`elixir_v1` (module facts) and `core_v1` with `[:no_copt]` (function bodies as
Core Erlang, the way Dialyzer reads them). It never loads or calls a project
module. A beam it cannot decode is an error value naming path, module and
cause, never skipped. The builder guards each module (DND-5548): a module
whose node or Core walk raises, throws or exits is an `unreadable` entry
`{:walk_crashed, summary}`, and every other module is still built. `Anchor.Domain.Graph.Builder` builds `%Anchor.Domain.Graph{}`
from those records and `Anchor.Domain.Graph.SourceFacts` (literal `defmodule`s,
for `generated?`); `Anchor.Domain.Graph.CoreWalker` reads call and struct-use
edges from Core. A new Core shape goes into the walker with a row in
`test/anchor/domain/graph/core_walker_test.exs`. Elixir rewrites some stdlib
calls before Core (`Map.merge/2` is `:maps.merge/2`; `Map.put/3` becomes a map
update, read back as `:maps.put/3`), so an edge names the Erlang function.
`Anchor.Domain.Graph.Inlines` carries the table, derived from Elixir's own
rewrite rules when Anchor compiles, never copied by hand (DND-5551). A rule
that names a stdlib function matches every spelling, through
`Inlines.spellings/1` (`Graph.calls_to/2` already does), and the AST engine
matches the same set through `Anchor.Domain.FunctionRef.names/1` (DND-5613). A
rewrite that adds a literal tag (`Process.monitor/1` is `:erlang.monitor(:process,
_)`) is read back into its Elixir name by the walker, and a tagged name's
spellings leave out a sibling with another tag; an inline no tag tells apart
stays ambiguous; `Inlines.describe/1` names every candidate, for the rule that
renders such a call edge in a finding. A function with no Core
body (`core: nil`: a `defmacrop`, a `defp` nothing calls) has no edges read
from it; `Graph.functions_without_core/1` counts them per module for the
runner's summary, and a public one is also an `unreadable` entry
`{:no_core, [{name, arity}]}` (DND-5549). Graph test fixtures are
compiled in the test with `Anchor.Test.BeamFixtures.compile_unloaded/2`, which
unloads every fixture module and turns `debug_info` on per module (`mix test`
compiles with it off).

## The graph runner: `mix anchor.graph` (DND-5440)

`Mix.Tasks.Anchor.Graph` (Framework) compiles, gathers `[{app, ebin}]` and,
in an umbrella, each app's directory (`Request.source_dirs`, from
`Mix.Project.apps_paths/0`: Mix compiles an app from its own directory, so its
beams' source paths are app-relative and are keyed from the umbrella root,
DND-5637) from Mix and makes one `Anchor.Managers.Graph.run/2` call; the Manager reaches
config, beams, sources and the artifact only through adapters
(`ConfigLoader`, `BeamSource`, `SourceSource`, `GraphStore`; tests double them
with Hammox, BeamSource with plain Mox because Hammox cannot match its
`:cerl` record type (see `test/test_helper.exs`), and pass them as options,
as `mix anchor.sabotage` does). `SourceSource` returns each file's
`SourceFacts`, never its text. A module is project code because its beam
came from a project ebin, wherever its source sits (DND-5630): one compiled
from outside the root (`elixirc_paths: ["../shared"]`) is judged and enforced
like any other, keyed by its root-relative `../shared/foo.ex` path, and
counted in the summary as `(<n> outside the root)`; an absolute path inside
the root is made relative (`Anchor.Domain.Graph.ProjectFile`). It builds
the graph fresh, builds `Anchor.Domain.Model` (classification of every
module), checks bucket and rule floors (`min_modules`), runs each graph rule
under a `try`/`rescue`/`catch` guard, and returns
`Anchor.Domain.GraphReport` (exit 0/1/3). It never reads the artifact
(`<build_path>/anchor/graph.etf`, Mix's build path as the task gathers it,
DND-5585) for a verdict.

A graph rule implements `Anchor.Domain.GraphRule` (`rule_type/0`,
`check/2` over the model) and is listed in `Anchor.Domain.GraphRules.all/0`;
`graph_rules_test.exs` holds that list's types equal to RuleSchema's `:graph`
types. The graph common keys (`type`, `id`, one selector of `bucket`, `paths`
or `pattern`, `min_modules`, `enforcement`, `baseline`; DND-5441) are
`RuleSchema`'s `@common_keys_by_engine[:graph]`; `uses_module`, `recursive`
and `min_files` are refused on a graph rule. Their rows are
`graph_common_rows/0` in `rule_checks_nothing_test.exs`, run through
`RuleSchema.validate_common/4`; a graph type's own table starts with them. A
graph rule needs `architecture:` and its `bucket` must name a bucket
(`RuleSchema.validate_architecture/3`, called by `Anchor.Config`). Each new fail-closed case gets a `Failures` function, a row in
`failures_graph_test.exs` and a row in the README's graph fail-closed table.
The canary tree `test/fixtures/graph_canary/` gets a compliant and a violating
module per graph rule. Anchor's own `.anchor.yml` has an `architecture:`
section with floors at today's counts, and CI runs `MIX_ENV=dev mix
anchor.graph` after credo.

## Report, baseline, enforce (DND-5441)

Every rule takes `enforcement: report | enforce`. A report finding is
`Violation.enforcement: :report`: `Anchor.Managers.Lint.detect_file/5`
detects report rules apart from enforced ones (one call as before when there
are none), and `Anchor.Check.Base` gives their issues exit status 0 and low
priority. Graph rules also take `baseline:`: `Anchor.Managers.Graph` reads it
through `Anchor.Adapters.BaselineStore` (`BaselineFile`; `create/3` opens
`:exclusive`, never overwriting), and under `--base REF` its copy at `REF`
through `Anchor.Adapters.GitBase` (`GitShow`: argv only, the ref checked by
`Anchor.Domain.Baseline.valid_ref?/1` first). `Anchor.Domain.Baseline` parses
and compares (multisets: NEW, STALE, held; GREW against base), and
`Anchor.Domain.Enforcement.judge/4` turns the result into findings. A key is
`Anchor.Domain.ViolationKey.graph_key/3`: `<id or type>|<subject>|<detail>`,
no line, no message. `baseline` on an `ast` rule is refused at load until
Credo compares baselines.

## The layering rule (DND-5442)

`Anchor.Domain.GraphRules.Layering` judges every call in the graph whose
caller the rule selects against `Anchor.Domain.CallMatrix.allowed?/3` (deny
by default: a bucket and scope the caller's `calls` row lists).
`CallMatrix.route/3` is the shortest allowed bucket path, for the `Fix:`, and
`row/2` prints the caller's row. A dynamic call resolves through
`Anchor.Domain.DynamicCalls.candidates/2`: every project module with a `def`
of that name and arity (any arity for `nil`), behaviour or not, each judged
as a static call; none means the call reaches no project module, and nothing
is judged. A call with a computed function name (`{:dynamic, nil, ...}`) is
one unresolved violation (`DynamicCalls.computed_name_message/2`), except a
variable application
(`kind: :apply`, receiver `:variable`: `fun.(x)`), the one closure form,
left to the higher-order analysis. The walker gives `apply/2` and `apply/3`
with a computed name the same shape, so `apply(fun, args)` is reported. One violation per (caller, callee)
pair, at its first line. The canary has a framework bucket with
`layering/compliant.ex` and `layering/violating.ex`. Anchor's own
`.anchor.yml` runs the rule with a baseline (Lint's calls into
`Anchor.Check`, DND-1288, most of them dynamic calls fanned out to every
check module exporting the function).

## The context_acyclic rule (DND-5445)

`Anchor.Domain.ContextGraph.build/2` collapses the calls of the selected
modules to context edges `{a, b} => [witness]` (witness `{caller_mfa,
callee_mfa, file, line}`, sorted), skipping a call within one context, to an
unclassified or non-project module, with a nil context, a dynamic call no
project module exports, and a closure application. A call with a computed
function name goes into `unresolved`, and the rule reports each (caller,
arity) itself, keyed `<id>|<Caller.f/a>|-> dynamic ?/n`.
`Anchor.Domain.GraphRules.ContextAcyclic` runs `GraphAlgorithms.sccs/1` over
it and reports each SCC of two or more contexts once, keyed
`ViolationKey.graph_key/2` (`<id>|A,B,C`), at the first witness of the edge to
invert (fewest witnesses, ties lexical). The canary's cycle pair is
`lib/canary/domain/cycle/` (`AnchorFixtures.CycleA`/`CycleB`, their own
contexts). Anchor's own `.anchor.yml` runs it with a baseline holding one
five-context cycle through Lint's dynamic calls on the checks (DND-1288),
and `Mutator`'s `apply/3`.

## The effects_match_bucket rule (DND-5447)

`Anchor.Domain.Effects.infer/2` gives every `def`/`defp` a role from what it
causes: a root (`Anchor.Domain.Roots`: framework-bucket public functions,
`architecture.roots`, external behaviour callbacks, which the runner reads
through the `Anchor.Adapters.BehaviourSource` port (`BehaviourReader`) for
`Roots.external_behaviours/1` and passes in as `:callbacks`, so `Roots` stays
pure; the result keeps them as `Effects.roots`) is framework; a call of an effect primitive
(`EffectPrimitives.primitive?/2`, its inference list, not demand's) itself or
through its own module is adapters; reaching one through another module, or
an unresolved call, is managers; else domain. Apply sites are read from
`Model.cfa`, so the rule `needs: [:cfa, :effects]`; the runner computes
`Model.effects` once and prints its counts in the summary. The rule judges
public, non-root, non-`__name__` functions of `domain`/`adapters`/`managers`
buckets with `infer: true`. Its canary is its own tree,
`test/fixtures/graph_canary/effects/`, run by
`test/anchor/integration/effects_canary_test.exs`. Anchor's own config
declares its extra effects (tracing, `Path.wildcard`, `Mix.Task.run`) and a
first-landing baseline.

## The analyses_complete rule, and testing the analyses at their bucket's level (DND-5715)

`Anchor.Domain.GraphRules.AnalysesComplete` needs `[:cfa, :demand]` (the runner
computes the demand analysis once when a rule that runs needs it, onto
`Model.demand`, with `architecture.effects`) and fails the run closed on a hit
step bound, a hit round bound, a selected function with Core and no demand
summary, or a count below a floor it declares (`min_functions`, `min_apply_sites`,
`min_absent_parameters`). Anchor's own `.anchor.yml` declares it over lib/, with
those floors, so CI's `mix anchor.graph` is the whole-Anchor run of those
analyses. Its canary has its own root, `test/fixtures/graph_canary/analyses_complete/`,
compliant only: no small module can hit a default bound, so the violating cases
inject a bounded analysis or raise a floor in the test. **No test reads
Anchor's own beams or the whole stdlib as a Domain or Manager test:** a behaviour
of an analysis gets a row in `demand_test.exs`, `transfer_test.exs` or
`cfa_test.exs` on a small fixture, and `test/anchor/integration/analyses_complete_integration_test.exs`
is the one happy path over beams on disk, read from that canary. The table logic of `Inlines` is tested
on hand-built exports; the check against the real stdlib is
`test/anchor/adapters/inlines_stdlib_test.exs` (`@moduletag bucket: :adapter`),
which reads the stdlib once, in `setup_all`.

## The struct_owned_by_module_flow rule (DND-5454)

The graph half of struct ownership; the AST rule `struct_owned_by_module`
(DND-5453) is the literal half, and both read their scope from
`Anchor.Domain.StructOwnership` (`owned_namespaces`, exact names with a
prefix rule). `Anchor.Domain.StructTypes.index/1` reads `@type t` fields and
`@spec` returns from `ModuleNode.types`/`specs` (one project struct, named
exactly, or unknown). `Anchor.Domain.StructFlow` walks one function's Core
with a lexical environment (a `case` body is evaluated in its clause's
scope), finds a `fun`'s parameter from the `Map.update!/3`/`update/4` it is
handed to by a fixpoint over seeds, and returns writes `%{struct, op, line,
how}`. The rule owns a `defimpl` by its `__impl__(:for)` spec, or by its
protocol when several impls share protocol, file and line (`for: [A, B]`).
It skips the AST rule's sites: a line with another struct's `:build` or
`:update` struct use, and a `:matched` write in a function whose clauses
carry no macro `:context`. One violation per (function, line). In a `for`
comprehension a `x = expr` line is a filter: bind a value that may be false
with `x <- [expr]`. Fixtures that hold a `defimpl` put `@compile {:debug_info,
true}` in its body (BeamFixtures adds it to `defmodule`s only).

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
a missing row costs precision (its arguments escape), never soundness. A
`letrec` name is keyed per scope, the letrec node (DND-5575): an apply of it
reaches the innermost enclosing letrec that binds it (`Cfa` keeps each
lambda's lexical scope; `Eval` adds a letrec's names at the node), never a
same-named letrec elsewhere in the function.

The runner wires it lazily (DND-5574): a graph rule that reads it declares
`needs: [:cfa]` (`GraphRule`'s optional `needs/0`, read and checked by
`GraphRules.needs/1`), and `Anchor.Managers.Graph` runs
`Cfa.analyze(graph, Cfa.default_seed(graph))` once per run, under the rule
guard, only when a rule that runs needs it, and puts it on `Model.cfa` (`nil`
otherwise). The summary then ends `; apply sites: <r> resolved, <a> any`, and
the JSON carries `apply_sites` (`GraphReport.apply_sites/1`). A refused need
(`rule_crashed`) or a crashed analysis (`Failures.rule_cfa_crashed/5`) is one
issue per rule, and that rule is not run. A new analysis a rule can need goes
into `GraphRules`' `@provided_needs` and the Manager's needs wiring.

## Demand (DND-5498)

`Anchor.Domain.Demand.analyze/4` takes the graph and a `%Cfa{}` over it and
summarises every `def`/`defp`: per parameter, a demand
(`Anchor.Domain.Demand.Lattice`: `:absent`, `{:used, fields}` or `:all`) saying
whether it reaches the return value or an effect, and the calls it is passed to
(`passes`). `Demand.Transfer` is one backward pass over one function's Core;
`analyze/4` runs it to a fixpoint over the call graph's SCCs, bounded by
`:max_rounds` (a component that hits it is reported used and imprecise, never
unused). Effects and escapes are rows in `Anchor.Domain.EffectPrimitives`, pure
library calls in `Anchor.Domain.PureCalls`; a function that calls an argument
(`Anchor.Domain.HigherOrder`) uses every argument, precisely; any library call
in neither table uses its arguments and makes the function `imprecise` (the
passes run sound and optimistic, and a parameter whose two demands differ is
imprecise). Inside a `try` or `catch` a raise is observable, so a call there
uses its arguments. A new Core shape goes into `Transfer` with a row in
`test/anchor/domain/demand/transfer_test.exs`. A field map may hold the key
`:__struct__`: read it with `:maps`, never `Enum`.

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
its last (a dead holder's lock is taken over); a host with no `/proc` refuses
(exit 2), because the lock could name no owner. A mutant that
does not compile is `invalid`, never killed, and (beside a measured mutant) never changes the exit code. A
mutant whose run crashed or had no test is unmeasured: with no measured mutant
the run is exit 3, beside one it fails like a survivor (exit 1)
(`Anchor.Domain.Sabotage.Report`). Changed functions that yield no mutant
at all exit 0 but are never silent: a line per function with its reason
(`Anchor.Domain.Sabotage.NoMutant`) and a count (DND-5617). Failed tests come from
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

## Sabotage records (DND-5484)

`mix anchor.sabotage run` writes its own sabotage record after the run
(`Anchor.Domain.Sabotage.Record`, the golden file
`test/fixtures/sabotage/record_golden.md` is the authority for its text),
named per `sabotage.records` (`RecordNaming`: anchor and crew
`domain_date_slot`, gen_saas `ticket_nn_what`). Its `anchor-kills` block
(`KillMap`, render and parse) is what `run` selects tests from next time
(source `kill_map`, after `coverage`, before `mirror`) and what DND-5485
replays. `RecordFile.create/3` never overwrites; a README is never written;
nothing is staged or committed. The date is a fact the Mix task reads.
