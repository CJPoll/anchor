defmodule Anchor.Managers.Explain do
  @moduledoc """
  Answers `mix anchor.explain <path|Module>`: the **Manager** (ADR 001)
  behind the task (DND-5446, shared contract section 9). It calls adapters and
  Domain only, and writes nothing: the graph artifact is `mix anchor.graph`'s
  to write.

  `explain/2` does, in order:

    1. load `.anchor.yml` (`Anchor.Adapters.ConfigLoader`); a missing or
       invalid config, or one with no `architecture:` section, is
       `{:error, {:could_not_check, violation}}` (the task exits 3);
    2. parse the subject (`Anchor.Domain.Subject`); one that is neither a
       module name nor an `.ex` path under the root is
       `{:error, {:usage, reason}}` (exit 2);
    3. when the project compiled, read its beams and source facts and compute
       the graph artifact's key exactly as `mix anchor.graph` does
       (`Anchor.Managers.Graph.artifact_inputs/2`), and read the artifact
       (`Anchor.Adapters.GraphStore.read/2`). Only an artifact under that
       key is used: a missing, unreadable or stale one means no model, never
       an old answer. A run that did not compile reads no beam;
    4. with the model, run every graph rule of the config over it, each
       guarded (a rule that crashes is named among the findings, never
       dropped), and keep the findings on the subject's source file;
    5. read the subject's source file (`Anchor.Adapters.SourceSource`) to
       know whether it exists and what it defines, and build the answer
       (`Anchor.Domain.Explain.build/3`).

  ## Options (the adapters, for tests)

  `:config_loader`, `:beam_source`, `:source_source`, `:graph_store`,
  `:graph_rules`, defaulting as `Anchor.Managers.Graph`'s do.
  """

  alias Anchor.Adapters.BeamReader
  alias Anchor.Adapters.ConfigFile
  alias Anchor.Adapters.GraphArtifact
  alias Anchor.Adapters.SourceReader
  alias Anchor.Config
  alias Anchor.Domain.Explain
  alias Anchor.Domain.Failures
  alias Anchor.Domain.Graph
  alias Anchor.Domain.GraphRules
  alias Anchor.Domain.Model
  alias Anchor.Domain.Subject
  alias Anchor.Domain.Violation
  alias Anchor.Managers.Graph, as: GraphManager
  alias Anchor.Managers.Graph.Request

  @typedoc """
  What the task gathered: the subject as given, and the plain Mix facts a
  graph run takes (`Anchor.Managers.Graph.Request`), and whether the
  project compiled.
  """
  @type request :: %{
          argument: String.t(),
          graph: Request.t(),
          compiled?: boolean()
        }

  @doc "Explains the request's subject; see the moduledoc."
  @spec explain(request(), keyword()) ::
          {:ok, Explain.t()}
          | {:error, {:could_not_check, Violation.t()} | {:usage, atom()}}
  def explain(%{argument: argument, graph: %Request{} = graph} = request, deps \\ []) do
    deps = deps(deps)

    with {:ok, config} <- load_config(deps.config_loader),
         {:ok, parsed} <- parse(argument, graph.root) do
      {model, facts} = model(request, config, deps)
      {module, path} = place(parsed, model)
      source = read_source(deps.source_source, graph.root, path)

      subject = %{
        argument: argument,
        module: module,
        path: path,
        exists?: exists?(source),
        source: facts_or_nil(Map.get(facts, path) || source),
        compiled?: request.compiled?,
        findings: findings(model, config, path, deps.graph_rules)
      }

      {:ok, Explain.build(config, model, subject)}
    end
  end

  defp deps(deps) do
    %{
      config_loader: Keyword.get(deps, :config_loader, ConfigFile),
      beam_source: Keyword.get(deps, :beam_source, BeamReader),
      source_source: Keyword.get(deps, :source_source, SourceReader),
      graph_store: Keyword.get(deps, :graph_store, GraphArtifact),
      graph_rules: Keyword.get(deps, :graph_rules, GraphRules.all())
    }
  end

  defp load_config(loader) do
    case loader.load() do
      {:ok, %Config{architecture: nil} = config} ->
        {:error, {:could_not_check, Failures.graph_no_architecture(config.path)}}

      {:ok, %Config{} = config} ->
        {:ok, config}

      {:error, reason} ->
        {:error, {:could_not_check, Failures.config_violation(reason)}}
    end
  end

  defp parse(argument, root) do
    case Subject.parse(argument, root) do
      {:error, reason} -> {:error, {:usage, reason}}
      parsed -> {:ok, parsed}
    end
  end

  # The model of the last graph run, only when its artifact's key is this
  # build's; `nil` otherwise. Also the source facts read for the key.
  defp model(%{compiled?: false}, _config, _deps), do: {nil, %{}}

  defp model(%{graph: graph_request}, config, deps) do
    case GraphManager.artifact_inputs(graph_request, Map.put(deps, :config, config)) do
      {:ok, %{key: key, dir: dir, source_facts: facts}} ->
        {stored(deps.graph_store.read(dir, key), config, facts), facts}

      :none ->
        {nil, %{}}
    end
  end

  defp stored({:ok, %Graph{} = graph}, config, facts),
    do: graph |> Model.build(config, facts) |> elem(0)

  defp stored(_missing_stale_or_unreadable, _config, _facts), do: nil

  # The module and its repo-relative path: the graph's when it places the
  # module (or a module at the path), else Elixir's naming convention.
  defp place({:module, module}, model) do
    case model && Map.get(model.graph.modules, module) do
      %{source_file: file} when is_binary(file) -> {module, file}
      _unplaced -> {module, Subject.implied_path(module)}
    end
  end

  defp place({:path, path, implied}, model) do
    in_graph =
      model &&
        model.graph.modules
        |> Map.values()
        |> Enum.filter(&(&1.source_file == path))
        |> Enum.map(& &1.module)
        |> Enum.sort()
        |> List.first()

    {in_graph || implied, path}
  end

  defp read_source(source, root, path), do: source.read(root, [path]) |> Map.get(path)

  defp exists?({:error, :enoent}), do: false
  defp exists?(nil), do: false
  defp exists?(_facts_or_other_error), do: true

  defp facts_or_nil(%{defmodules: _} = facts), do: facts
  defp facts_or_nil(_none), do: nil

  # The graph rules' findings on `path`, or `nil` with no model. A rule that
  # crashes is a finding naming it, never a silent omission.
  defp findings(nil, _config, _path, _modules), do: nil

  defp findings(%Model{} = model, config, path, modules) do
    by_type = GraphRules.by_type(modules)

    config.rules
    |> Enum.flat_map(fn rule ->
      case Map.get(by_type, rule.type) do
        nil -> []
        module -> guarded_check(module, model, rule, config.path)
      end
    end)
    |> Enum.filter(&(&1.filename == path or &1.kind == :fail_closed))
  end

  defp guarded_check(module, model, rule, config_path) do
    module.check(model, rule)
  rescue
    exception ->
      [Failures.rule_crashed(rule, :error, exception, __STACKTRACE__, config_path)]
  catch
    kind, reason -> [Failures.rule_crashed(rule, kind, reason, __STACKTRACE__, config_path)]
  end
end
