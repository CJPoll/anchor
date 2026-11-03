# Sabotage record — an empty uses map is a measured "uses nothing" (DND-5636)

- **Domain:** graph_runner
- **Branch:** dnd-5630-graph-hardening
- **Date:** 2026-11-03
- **Code under test:** the types `Anchor.Domain.Graph.SourceFacts.t/0` (`uses`) and
  `Anchor.Adapters.SourceSource.read/2`'s return, as Hammox checks them at the port
- **Suite run:** per mutation, `mix test --timeout 2000 --max-cases 2
  test/anchor/adapters/source_reader_test.exs test/anchor/managers/graph_test.exs
  test/anchor/domain/graph/source_facts_test.exs`, each mutation applied alone and restored byte-for-byte
  (sha256 compared) after its run.

A source file with no literal `defmodule` (a DSL file whose modules are macro output) has
`uses: %{}`. `SourceFacts.t/0` typed it `%{String.t() => [String.t()]}`; in an Elixir typespec a bare
non-literal key is *required*, so the type said "at least one entry" and Hammox refused the empty map at
the `SourceSource` port. An empty map is a measured "uses nothing", distinct from unknown (an unparseable
file, `{:error, :unparseable}`, which the builder reads as `generated?: :unknown`). The key is now
`optional(String.t())`. The same class held for the port's own return map, which a read of no paths makes
empty (seen in DND-5630's mutation D), and for the builder's `source_facts` and `Request.source_dirs`
specs; each is `optional` now.

## The regression, on the unfixed code

The two files ran `34 tests, 2 failures`:

```
  1) test a file with no defmodule, and a read of no paths, conform to the port's type (Anchor.Adapters.SourceReaderTest)
     Returned value %{"lib/broken.ex" => {:error, :unparseable}, "lib/dsl.ex" => %{uses: %{}, defmodules: [], nonliteral_defmodule?: false}} does not match type %{ required(String.t()) => Anchor.Domain.Graph.SourceFacts.t() | {:error, :unparseable} | {:error, term()}}.
       Map value %{uses: %{}, defmodules: [], nonliteral_defmodule?: false} for key "lib/dsl.ex" does not match map value type Anchor.Domain.Graph.SourceFacts.t() | {:error, :unparseable} | {:error, term()}.

  2) test run/2 source facts with no uses an empty uses map is read as facts, an unparseable file as unknown (Anchor.Managers.GraphTest)
     Returned value %{"lib/my_app/domain/user.ex" => %{uses: %{}, defmodules: [], nonliteral_defmodule?: false}, "lib/my_app/managers/accounts.ex" => {:error, :unparseable}} does not match type %{ required(String.t()) => Anchor.Domain.Graph.SourceFacts.t() | {:error, :unparseable} | {:error, term()}}.
```

After: the three files and the task test run `55 tests, 0 failures`.

## Mutations

| # | Mutation | Tests that failed | Run |
|---|---|---|---|
| A | `SourceFacts.t/0`'s `uses` key is required again | the adapter's port-type test, the Manager's no-uses test | `47 tests, 2 failures` |
| B | the port's return map key is required again | the adapter's port-type test (the read of no paths) | `47 tests, 1 failure` |

## Failure strings (verbatim)

### A

```
  1) test a file with no defmodule, and a read of no paths, conform to the port's type (Anchor.Adapters.SourceReaderTest)
     test/anchor/adapters/source_reader_test.exs:36
     ** (Hammox.TypeMatchError) 
     Returned value %{"lib/broken.ex" => {:error, :unparseable}, "lib/dsl.ex" => %{uses: %{}, defmodules: [], nonliteral_defmodule?: false}} does not match type %{ optional(String.t()) => Anchor.Domain.Graph.SourceFacts.t() | {:error, :unparseable} | {:error, term()}}.
       Map value %{uses: %{}, defmodules: [], nonliteral_defmodule?: false} for key "lib/dsl.ex" does not match map value type Anchor.Domain.Graph.SourceFacts.t() | {:error, :unparseable} | {:error, term()}.
```

### B

```
  1) test a file with no defmodule, and a read of no paths, conform to the port's type (Anchor.Adapters.SourceReaderTest)
     test/anchor/adapters/source_reader_test.exs:36
     ** (Hammox.TypeMatchError) 
     Returned value %{} does not match type %{ required(String.t()) => Anchor.Domain.Graph.SourceFacts.t() | {:error, :unparseable} | {:error, term()}}.
       Could not find a map entry matching required(String.t()) => Anchor.Domain.Graph.SourceFacts.t() | {:error, :unparseable} | {:error, term()}.
```
