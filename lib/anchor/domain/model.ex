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
    * `aggregate_analysis` — the write analysis
      (`%Anchor.Domain.Aggregates.Analysis{}`, DND-5459): every write, its
      source, every transaction's write set and the writes outside
      transactions. Built only when the config has an `aggregates:` section
      that is not `declare: none` (DND-5659),
      else `nil`. Its roots are the public functions of the framework
      bucket's modules (none when no bucket has the framework role);
    * `config` — the `%Anchor.Config{}`;
    * `cfa` — the higher-order flow analysis (`%Anchor.Domain.Cfa{}`,
      DND-5574), set by the runner only when a rule that runs declares
      `needs: [:cfa]` (`Anchor.Domain.GraphRule`); `nil` otherwise. `build/3`
      never computes it.

  An Erlang module of the project (`{:not_elixir, _}` in the graph's
  `unreadable`) is classified by its name only; a classified one is an opaque
  node (`opaque/1`), an unclassified one an issue
  (`Anchor.Domain.Failures.graph_erlang_module/2`).

  A module's facts for classification come from its graph node (app, source
  file, behaviours, exported functions) and its source file's literal `use`s
  (`Anchor.Domain.Graph.SourceFacts`), never from loading it.
  """

  alias Anchor.Config
  alias Anchor.Domain.Aggregates.Analysis
  alias Anchor.Domain.Aggregates.Index
  alias Anchor.Domain.Architecture
  alias Anchor.Domain.Cfa
  alias Anchor.Domain.Classification
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
    aggregate_analysis: nil,
    cfa: nil
  ]

  @type t :: %__MODULE__{
          graph: Graph.t(),
          architecture: Architecture.t(),
          classification: %{module() => Classification.t()},
          aggregates: Index.t(),
          aggregate_analysis: Analysis.t() | nil,
          config: Config.t(),
          cfa: Cfa.t() | nil
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
      aggregate_analysis: analysis(graph, config, classification)
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

  # DND-5459: the write analysis, only with an `aggregates:` section. Its
  # roots are the framework bucket's public functions; with no framework
  # bucket, every public function with no project caller is one. Under
  # `declare: none` (DND-5659) there is nothing to analyse: the
  # aggregate_declarations rule reports every module that persists.
  defp analysis(_graph, %Config{aggregates: nil}, _classification), do: nil

  defp analysis(_graph, %Config{aggregates: %{none: reason}}, _classification) when reason != nil,
    do: nil

  defp analysis(graph, %Config{aggregates: aggregates}, classification) do
    Analysis.build(graph, aggregates, roots: roots(graph, classification))
  end

  defp roots(graph, classification) do
    framework = for {module, %Classification{role: :framework}} <- classification, do: module

    if framework == [] do
      nil
    else
      for module <- framework,
          %ModuleNode{functions: functions} <- [Graph.module(graph, module)],
          {{name, arity}, %{kind: :def}} <- functions,
          into: MapSet.new(),
          do: {module, name, arity}
    end
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
