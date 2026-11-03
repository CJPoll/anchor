defmodule Anchor.Domain.Model do
  @moduledoc """
  The one model a graph run builds (DND-5440, shared contract section 2) — a
  **Domain** module (ADR 001). Pure.

  `build/3` classifies every module of the graph into exactly one bucket of
  the config's `architecture:` section (`Anchor.Domain.Classification`) and
  returns the model with the issues classification found: a module whose
  literal `use`s the source cannot show while a `uses_module` selector exists,
  an unclassified or ambiguous module, a bucket below its `min_modules`, and
  an `interfaces.exports` entry that names no module of the project. Every graph rule
  reads the model, and so do `explain` and `place` (DND-5446, DND-5449), so
  what a rule checks and what the generation side proposes come from one
  struct.

    * `graph` — the `%Anchor.Domain.Graph{}`;
    * `architecture` — the config's `%Anchor.Domain.Architecture{}`;
    * `classification` — `%{module => %Classification{}}`, the modules that
      classified into exactly one bucket;
    * `aggregates` — the aggregate declarations
      (`%Anchor.Domain.Aggregates.Index{}`, DND-5476), built from the config's
      `aggregates:` section and every module's persisted `@anchor_aggregate`;
      the index holds its own issues, which the `aggregate_declarations` rule
      reports;
    * `config` — the `%Anchor.Config{}`;
    * `cfa` — the higher-order flow analysis (`%Anchor.Domain.Cfa{}`,
      DND-5574), set by the runner only when a rule that runs declares
      `needs: [:cfa]` (`Anchor.Domain.GraphRule`); `nil` otherwise. `build/3`
      never computes it;
    * `effects` — the effects-inferred role of every function
      (`%Anchor.Domain.Effects{}`, DND-5447), set by the runner only when a
      rule that runs declares `needs: [:effects]`; `nil` otherwise;
    * `facts` — `%{module => Classification.facts()}`, the facts each module
      was classified by (DND-5447: `architecture.roots` selectors read them
      too, `uses_module` included).

  An Erlang module of the project (`{:not_elixir, _}` in the graph's
  `unreadable`) is classified by its name only; a classified one is an opaque
  node (`opaque/1`), an unclassified one an issue
  (`Anchor.Domain.Failures.graph_erlang_module/2`).

  A module's facts for classification come from its graph node (app, source
  file, behaviours, exported functions) and its source file's literal `use`s
  (`Anchor.Domain.Graph.SourceFacts`), never from loading it.
  """

  alias Anchor.Config
  alias Anchor.Domain.Aggregates.Index
  alias Anchor.Domain.Architecture
  alias Anchor.Domain.Cfa
  alias Anchor.Domain.Classification
  alias Anchor.Domain.Effects
  alias Anchor.Domain.Failures
  alias Anchor.Domain.Graph
  alias Anchor.Domain.Graph.ModuleNode
  alias Anchor.Domain.Violation

  @enforce_keys [:graph, :architecture, :classification, :config]
  defstruct [
    :graph,
    :architecture,
    :classification,
    :config,
    aggregates: %Index{},
    cfa: nil,
    effects: nil,
    facts: %{}
  ]

  @type t :: %__MODULE__{
          graph: Graph.t(),
          architecture: Architecture.t(),
          classification: %{module() => Classification.t()},
          aggregates: Index.t(),
          config: Config.t(),
          cfa: Cfa.t() | nil,
          effects: Effects.t() | nil,
          facts: %{module() => Classification.facts()}
        }

  @doc """
  Builds the model of `graph` under `config` (which must carry an
  `architecture:` section), classifying each module with the facts of
  `source_facts` (`%{file => SourceFacts.t() | {:error, _}}`). Returns the
  model and the classification issues, in module order.
  """
  @spec build(Graph.t(), Config.t(), map()) :: {t(), [Violation.t()]}
  def build(
        %Graph{} = graph,
        %Config{architecture: %Architecture{} = architecture} = config,
        source_facts
      ) do
    facts =
      graph.modules
      |> Map.values()
      |> Enum.sort_by(& &1.module)
      |> Enum.map(&facts(&1, source_facts))

    {classification, issues} =
      Classification.classify_all(facts ++ opaque_facts(graph), architecture, config.path)

    # A module the graph could not build is reported as unreadable already;
    # an export naming it is not also "no module of the project".
    unbuilt = MapSet.new(graph.unreadable, & &1.module)

    export_issues =
      for module <- architecture.interface_exports,
          not Map.has_key?(graph.modules, module),
          module not in unbuilt,
          do: Failures.interface_export_missing(module, config.path)

    model = %__MODULE__{
      graph: graph,
      architecture: architecture,
      classification: classification,
      config: config,
      aggregates: Index.build(config.aggregates, graph),
      facts: Map.new(facts, &{&1.module, &1})
    }

    {model, uses_unknown(facts, architecture, source_facts) ++ issues ++ export_issues}
  end

  @doc """
  The classification facts of one graph module (`Classification.facts/0`):
  its app, source file and def line, behaviours, exported functions (`def`
  only), and the literal `use`s its source file shows in its own body.
  """
  @spec facts(ModuleNode.t(), map()) :: Classification.facts()
  def facts(%ModuleNode{} = node, source_facts) do
    %{
      module: node.module,
      app: node.app,
      source_file: node.source_file,
      line: node.line,
      uses: uses(node, Map.get(source_facts, node.source_file)),
      behaviours: node.behaviours,
      exports: exports(node)
    }
  end

  @doc """
  The opaque modules of `classification`: Erlang modules a bucket classified
  by name. They are nodes with no edges (the graph engine reads Elixir only).
  """
  @spec opaque(t()) :: [module()]
  def opaque(%__MODULE__{classification: classification}) do
    classification |> Map.keys() |> Enum.reject(&elixir_module?/1) |> Enum.sort()
  end

  # An Erlang module of the project (`{:not_elixir, _}` in `unreadable`) is
  # classified by its name only: no source, no uses, no exports read. Its
  # `beam_path` lets an unclassified one be reported as Erlang source.
  defp opaque_facts(%Graph{unreadable: unreadable}) do
    for %{reason: {:not_elixir, _backend}, module: module, path: path} <- unreadable,
        is_atom(module) and module != nil do
      %{
        module: module,
        app: nil,
        source_file: nil,
        line: nil,
        uses: [],
        behaviours: [],
        exports: [],
        beam_path: path
      }
    end
  end

  # A module of a file with a non-literal `defmodule` (or a relative name after
  # a file-level alias) that the file's literal `defmodule`s do not name has
  # `use`s the text does not show: SourceFacts files them nowhere. Read as
  # "no uses", a `uses_module` selector could silently miss it, so when the
  # architecture has one, the module is an issue.
  defp uses_unknown(facts, architecture, source_facts) do
    if uses_module_selector?(architecture) do
      for %{module: module, source_file: file} <- facts,
          match?(%{nonliteral_defmodule?: true}, Map.get(source_facts, file)),
          module_name(module) not in Map.get(source_facts, file).defmodules,
          do: Failures.graph_uses_unknown(module, file)
    else
      []
    end
  end

  defp uses_module_selector?(%Architecture{buckets: buckets}) do
    Enum.any?(buckets, fn bucket ->
      Enum.any?(bucket.selectors, &match?({:uses_module, _}, &1))
    end)
  end

  defp exports(%ModuleNode{functions: functions}) do
    functions
    |> Enum.filter(fn {_name_arity, function} -> function.kind == :def end)
    |> Enum.map(fn {name_arity, _function} -> name_arity end)
    |> Enum.sort()
  end

  defp elixir_module?(module), do: String.starts_with?(Atom.to_string(module), "Elixir.")

  defp uses(node, %{uses: uses}) do
    uses
    |> Map.get(module_name(node.module), [])
    |> Enum.map(&Module.concat([&1]))
  end

  defp uses(_node, _no_facts), do: []

  defp module_name(module), do: module |> Atom.to_string() |> String.replace_prefix("Elixir.", "")
end
