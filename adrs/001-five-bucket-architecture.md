# ADR 001 -- Five-Bucket Architecture

## Status

Accepted. Ported from walt_ui `adrs/001-cross-project-engineering-principles.md`
and `backend/adrs/001-five-bucket-architecture.md` on 2026-09-12, adapted for a
single, standalone (non-umbrella) Elixir library.

## Context

Anchor is a small library, but the class of problems the five-bucket
architecture exists to prevent does not scale with size: business logic tangled
with framework code, side effects buried inside otherwise-pure functions, and
circular dependencies between modules that should have been one-way. Those
problems make code hard to test, hard to reason about, and hard to change
safely, and a library whose entire job is to *analyze other people's
architecture* has a particular obligation to keep its own honest.

To avoid that drift, every module is categorized into one of five buckets, and
the direction of allowed calls between buckets is constrained. The constraints
keep side effects at the edges, keep business logic pure and testable, and keep
the framework integration separable from the code it runs. Anchor genuinely has
all three shapes: it reads `.anchor.yml` from disk (a side effect), it analyzes
ASTs as pure functions (domain), and it integrates with Credo (framework).

This ADR is normative for Anchor. It carries the language-independent core —
the bucket definitions, the allowed-calls matrix, and the generic constraints —
together with the Elixir refinements that apply to a plain library. The
refinements that assume Phoenix, Ecto, Oban, or CQRS are explicitly marked
not-applicable so a reader does not go looking for machinery Anchor does not
have.

## Decision

Every module belongs to exactly one of five buckets:

1. **Framework** — controllers, middleware, routers, and other
   framework-specific code: the glue that a framework invokes. In Anchor this
   is the Credo integration surface — `Anchor.Check.*` modules that `use
   Anchor.Check.Base` and are called by Credo's check runner.
2. **UI Components** — presentational; receive state and render it. **Not
   applicable to Anchor** — a library with no user interface has no modules in
   this bucket, and so no directory for it. The bucket is retained in the
   definition because the allowed-calls matrix references it and because a
   future tool built on Anchor may acquire one.
3. **Side Effects** — ports/adapters in the Hexagonal Architecture sense.
   Repositories, external-API clients, file-system access — anything that does
   IO. In Anchor, `Anchor.Config` is the worked example: it reads `.anchor.yml`
   off disk (`File.exists?/1`, `File.read/1`) and parses it into a struct.
4. **Domain** — side-effect-free business logic. Pure functions, typed structs,
   value objects. Given the same inputs it always returns the same outputs: no
   IO, no clock reads, no disk. In Anchor, `Anchor.DependencyAnalyzer` is the
   worked example: it walks an AST and returns dependency data, computing
   transitive closures over an in-memory map, touching nothing outside its
   arguments.
5. **Managers** — orchestration between Side Effects and Domain. A Manager takes
   a use case end to end: call the adapter to fetch inputs, pass them through
   Domain functions, call the adapter to persist or return outputs. Anchor's
   orchestration today is thin, but any code that loads config (Side Effect)
   and then feeds it to analysis (Domain) belongs here rather than in either.

### Module organization

Anchor is a single Mix project, not an umbrella and not split into many
contexts. Its buckets map onto subdirectories under `lib/anchor/`:

```
lib/anchor/
  check/          # Framework — the Credo integration (Anchor.Check.*)
  config.ex       # Side Effect — reads .anchor.yml from disk
  dependency_analyzer.ex   # Domain — pure AST analysis
  <managers>/     # Managers — orchestration, added as it accrues
```

A bucket with no code gets no directory. The umbrella/many-context layout from
the source ADRs (`<context>/domain/`, `<context>/adapters/`,
`<context>/managers/`, `<context>/framework/`) is **not applicable** here: a
single small library has one context, so the bucket *distinction* is what
matters, not a per-context directory tree. If Anchor grows enough contexts to
warrant it, revisit; until then, keep the bucket boundary visible in module
naming and placement rather than in a heavyweight directory scheme.

#### Allowed calls

| From \\ To   | Framework | UI  | Side Effects | Domain | Managers |
|--------------|-----------|-----|--------------|--------|----------|
| Framework    | --        | yes | **no**       | yes    | yes      |
| UI           | no        | yes | **no**       | yes    | **no**   |
| Side Effects | no        | no  | yes          | yes    | **no**¹  |
| Domain       | **no**    | no  | **no**       | yes    | **no**   |
| Managers     | no        | no  | yes          | yes    | yes      |

¹ Side Effects **MUST NOT** call Managers within the same subdomain. See
"Cross-subdomain integration" below.

#### Specific constraints

- Framework **MUST NOT** call adapters directly. Go through a Manager. (A Credo
  check that needs configuration goes through the orchestration that loads it,
  not straight into `Anchor.Config`'s file reads.)
- Framework **MAY** call Domain objects for simple response logic — for example,
  a check handing an AST to `Anchor.DependencyAnalyzer` and formatting the
  result is Framework calling Domain, which is allowed.
- Side Effects (adapters) receive Domain objects and return Domain objects. They
  do not leak raw file contents or external payloads past their boundary —
  `Anchor.Config.load/0` returns an `%Anchor.Config{}` struct, not a raw YAML
  map.
- Domain objects **MUST NOT** call Side Effects, Managers, UI Components, or
  Framework. They are pure. `Anchor.DependencyAnalyzer` never reads a file and
  never calls a check module.
- Managers coordinate between Side Effects and Domain. They generally return
  Domain objects.

#### Reference-holding: data in Domain, invocation in the Manager

Domain **MAY** hold, index, and return references to Side Effect components as
*data* — a lookup that answers "which adapter handles this input" and returns
that adapter's identity (typically a module atom). Returning the reference is a
pure lookup and does not breach the Domain→Side-Effect prohibition. Domain
**MUST NOT** *invoke* through such a reference — neither `router[key].run(args)`
nor `apply(mod, :run, args)` on a returned module. That call is a
Domain→Side-Effect invocation and is forbidden wherever it appears. The Manager
takes the reference Domain returned and makes the call.

This is the "router map" rule, and it is directly relevant to Anchor: Anchor's
own dependency detection treats a **reference to a module** and a **call
through that module** as different facts about the source it analyzes — the same
distinction this rule draws. Holding or returning a reference is data; calling
through it is IO.

```elixir
# ✅ Domain: a pure router — holds adapter atoms, returns the right one
defmodule MyLib.SourceRouter do
  @loaders %{"yaml" => MyLib.Adapters.YamlLoader,
             "json" => MyLib.Adapters.JsonLoader}
  def for(kind), do: Map.fetch(@loaders, kind)   # returns the atom, calls nothing
end

# ✅ Manager: takes the returned module and invokes it
with {:ok, loader} <- MyLib.SourceRouter.for(kind) do
  loader.load(path)                              # the call lives here
end

# ❌ Domain invoking through the returned atom
def load(kind, path), do: @loaders[kind].load(path)
```

#### Cross-subdomain integration

When one subdomain needs capabilities from another, it uses a cross-subdomain
adapter that calls the other's public API (its Manager). This does not violate
"Side Effects must not call Managers" — that rule applies **within** a
subdomain, to prevent an adapter reaching back into its own subdomain's
orchestration layer. Anchor is effectively one subdomain today, so this rule is
carried for completeness rather than because it currently binds anything.

### Amendments carried from the source, and those dropped

Two amendments from the backend's Elixir/Phoenix mapping are retained because
they are about the pure-vs-IO distinction itself, which applies to any Elixir
code:

- **Domain router maps hold module atoms but never invoke them** — retained in
  full above ("Reference-holding"), because it is the same test Anchor's own
  analysis draws.
- **The general principle that holding or returning a reference is data, while
  calling through it is IO** — retained, as the unifying rule behind the router
  map.

The following refinements from the source ADRs are **not applicable to Anchor**
and are dropped rather than adapted:

- **LiveView/HEEx view/template separation** — Anchor has no Phoenix, no
  LiveView, no HEEx.
- **Ecto schema modules are Domain; repositories are Side Effects** — Anchor has
  no Ecto and no schemas. (The underlying idea — that a struct definition is
  Domain while the thing that loads it is a Side Effect — is already covered by
  the generic Domain/Side-Effect definitions above; Anchor's `%Anchor.Config{}`
  struct is Domain data, and `Anchor.Config`'s file reads are the Side Effect.)
- **Oban workers are Framework** — Anchor has no Oban and no background jobs.
- **The CQRS-machinery exemption** (aggregates, commands, events, projectors,
  process managers follow Commanded's architecture, not the five buckets) —
  Anchor has no Commanded and no CQRS, so nothing is exempt: every module is
  bucketed.

## How this maps to Anchor

| Module | Bucket | Why |
|---|---|---|
| `Anchor.Check.*` (e.g. `NoDependency`, `NoTransitiveDependency`, `MustUseModule`) | Framework | They `use Anchor.Check.Base`, are registered in `.credo.exs`, and are invoked by Credo's runner — the framework's entry points. |
| `Anchor.Check.Base` | Framework | The shared `use`-target that wires a check into Credo. |
| `Anchor.Config` | Side Effect | Reads `.anchor.yml` off disk (`File.exists?/1`, `File.read/1`) and returns a struct. IO at the edge. |
| `Anchor.DependencyAnalyzer` | Domain | Pure AST analysis: extracts dependencies and `use`s, computes transitive closures over an in-memory map. Same input, same output, no IO. |
| `%Anchor.Config{}` struct | Domain (data) | A typed struct is Domain data; the adapter that produced it is the Side Effect. |
| Orchestration that loads config then runs analysis | Manager | Coordinates the Side Effect (config load) and Domain (analysis). Kept thin today. |

The load-bearing consequence for Anchor: a `Anchor.Check.*` module (Framework)
may call `Anchor.DependencyAnalyzer` (Domain) directly, and may go through a
Manager to obtain configuration, but it must not itself do the file IO that
`Anchor.Config` owns. And `Anchor.DependencyAnalyzer` must never grow a
`File.read/1` or a call into a check module — the moment it does, it has stopped
being Domain.

## Examples

### Correct

```elixir
# Framework (a Credo check) calls Domain directly — allowed.
defmodule Anchor.Check.NoDependency do
  use Anchor.Check.Base

  def check_file(source_file, rules, params) do
    ast = Credo.Code.ast(source_file)
    dependencies = Anchor.DependencyAnalyzer.extract_direct_dependencies(ast)
    # ... build issues from the pure analysis ...
  end
end

# Domain is pure — walks an AST, returns data, touches no disk.
defmodule Anchor.DependencyAnalyzer do
  def extract_direct_dependencies(ast) do
    ast
    |> Credo.Code.prewalk(&extract_module_references/2, MapSet.new())
    |> MapSet.to_list()
    |> Enum.sort()
  end
end

# Side Effect — reads the file, returns a Domain struct.
defmodule Anchor.Config do
  def load_from_path(path) do
    with {:ok, content} <- File.read(path),
         {:ok, data} <- YamlElixir.read_from_string(content) do
      {:ok, parse_config(data)}   # returns %Anchor.Config{}, not raw YAML
    end
  end
end
```

### Incorrect

```elixir
# BAD: Domain doing IO — the analyzer must never read a file.
defmodule Anchor.DependencyAnalyzer do
  def analyze_path(path) do
    {:ok, content} = File.read(path)   # Domain is supposed to be pure
    # ...
  end
end

# BAD: Domain invoking through a returned adapter reference.
defmodule Anchor.SourceRouter do
  @loaders %{"yaml" => Anchor.Adapters.YamlLoader}
  def load(kind, path), do: @loaders[kind].load(path)   # Domain→Side-Effect call
end

# BAD: Framework reaching past the Manager into the adapter's IO.
defmodule Anchor.Check.NoDependency do
  def check_file(source_file, _rules, _params) do
    {:ok, config} = Anchor.Config.load()   # skip orchestration; Framework doing config IO indirectly
    # ...
  end
end
```

## Consequences

### Benefits

- **Testability.** Domain (`DependencyAnalyzer`) is pure and trivial to test
  with plain inputs. The adapter (`Config`) is tested for its conversions.
  Framework (checks) can be tested against Credo's harness.
- **Replaceability.** The config source could change (a different file format,
  a different location) without touching the analysis or the checks.
- **Readability.** The module's bucket tells you what kind of code it is and
  bounds the blast radius of a change.
- **Boundaries are enforceable.** Anchor is, itself, a tool for enforcing
  exactly these boundaries — it can be pointed at its own tree.

### Tradeoffs

- **More indirection than a tiny library strictly needs.** Keeping config IO out
  of the analyzer and out of the checks means an orchestration seam that a
  hack-it-together library would skip. This is intentional: it is the difference
  between "the analyzer is pure" being true and being aspirational.
- **Requires discipline at review.** With no ADR review bot (see Enforcement),
  the boundary is held by human review and by Anchor's own checks.

## Enforcement

Enforced by code review, and — fittingly — by Anchor's own Credo checks, which
can express dependency-direction rules over Anchor's own modules in
`.anchor.yml`. There is no ADR review bot in this repository; the boundary is
maintained by reviewers reading changes against this ADR and by the linter
configuration.

## References

- Hexagonal Architecture / Ports and Adapters (Alistair Cockburn)
- Clean Architecture (Robert C. Martin)
- walt_ui `adrs/001-cross-project-engineering-principles.md` and
  `backend/adrs/001-five-bucket-architecture.md` — the source ADRs this is
  ported from.
- `lib/anchor/config.ex` (Side Effect), `lib/anchor/dependency_analyzer.ex`
  (Domain), `lib/anchor/check/` (Framework) — the modules that exemplify each
  bucket.
