defmodule Anchor.Domain.Model do
  @moduledoc """
  The one model a graph run builds (DND-5440, shared contract section 2) — a
  **Domain** module (ADR 001). Pure.

  `build/3` classifies every module of the graph into exactly one bucket of
  the config's `architecture:` section (`Anchor.Domain.Classification`) and
  returns the model with the issues classification found: an unclassified or
  ambiguous module, a bucket below its `min_modules`, and an
  `interfaces.exports` entry that names no module of the graph. Every graph rule
  reads the model, and so do `explain` and `place` (DND-5446, DND-5449), so
  what a rule checks and what the generation side proposes come from one
  struct.

    * `graph` — the `%Anchor.Domain.Graph{}`;
    * `architecture` — the config's `%Anchor.Domain.Architecture{}`;
    * `classification` — `%{module => %Classification{}}`, the modules that
      classified into exactly one bucket;
    * `aggregates` — the aggregate declarations (DND-5476; `[]` until then);
    * `config` — the `%Anchor.Config{}`.

  An Erlang module of the project (`{:not_elixir, _}` in the graph's
  `unreadable`) is classified by its name only; a classified one is an opaque
  node (`opaque/1`), an unclassified one an issue
  (`Anchor.Domain.Failures.graph_erlang_module/2`).

  A module's facts for classification come from its graph node (app, source
  file, behaviours, exported functions) and its source file's literal `use`s
  (`Anchor.Domain.Graph.SourceFacts`), never from loading it.
  """

  alias Anchor.Config
  alias Anchor.Domain.Architecture
  alias Anchor.Domain.Classification
  alias Anchor.Domain.Failures
  alias Anchor.Domain.Graph
  alias Anchor.Domain.Graph.ModuleNode
  alias Anchor.Domain.Violation

  @enforce_keys [:graph, :architecture, :classification, :config]
  defstruct [:graph, :architecture, :classification, :config, aggregates: []]

  @type t :: %__MODULE__{
          graph: Graph.t(),
          architecture: Architecture.t(),
          classification: %{module() => Classification.t()},
          aggregates: list(),
          config: Config.t()
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

    export_issues =
      for module <- architecture.interface_exports,
          not Map.has_key?(graph.modules, module),
          do: Failures.interface_export_missing(module, config.path)

    model = %__MODULE__{
      graph: graph,
      architecture: architecture,
      classification: classification,
      config: config
    }

    {model, issues ++ export_issues}
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
