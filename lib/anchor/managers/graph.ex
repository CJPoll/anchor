defmodule Anchor.Managers.Graph do
  @moduledoc """
  Runs the graph engine once: the **Manager** (ADR 001) behind `mix
  anchor.graph` (DND-5440; shared contract section 7). It calls adapters and
  Domain only, never a Framework module (DND-1288's shape is forbidden here).

  `run/2` does, in order:

    1. load `.anchor.yml` (`Anchor.Adapters.ConfigLoader`); a missing or
       invalid config is COULD NOT MEASURE (exit 3), and so is a config with no
       `architecture:` section: nothing could be classified;
    2. read every beam of the project's ebins (`Anchor.Adapters.BeamSource`)
       and leave out each module whose source is an absolute path outside the
       root (`Anchor.Domain.Graph.ProjectFile`, DND-5588): counted in the
       summary and named, with its path, in a report-only note; a run that
       read no module inside the root is COULD NOT MEASURE (exit 3);
    3. read each module's source file's facts (`Anchor.Adapters.SourceSource`):
       its literal `defmodule`s and `use`s (`Anchor.Domain.Graph.SourceFacts`),
       by its path relative to the root (an absolute path inside the root is
       made relative);
    4. build the graph fresh (`Anchor.Domain.Graph.Builder`): never a cached
       one, and never a cached verdict;
    5. build the model (`Anchor.Domain.Model`): classify every module into
       exactly one bucket, and check the bucket floors;
    6. for each enabled graph rule (narrowed by `--only`): its floor
       (`min_modules`), then its `check/2` under a guard (`try` with `rescue`, `catch :throw` and
       `catch :exit`, DND-1312's lesson): a rule that crashes is one issue,
       and the other rules still run;
    7. write the graph artifact for `explain`/`place`
       (`Anchor.Adapters.GraphStore`) under `<build_path>/anchor`, the build
       path the task gathered from Mix (DND-5585); the verdict never reads it;
    8. return the `%Anchor.Domain.GraphReport{}`.

  Every per-module problem is an issue on that module (exit 1), never a
  skipped module: a beam it could not decode, a module whose graph walk
  crashed (`{:walk_crashed, _}`, DND-5548), an Erlang module no bucket
  classifies, a source file it could not read, an unclassified or ambiguous
  module. Baselines (DND-5441) are not compared yet: every rule finding
  stands.

  ## Options (the adapters, for tests)

  `:config_loader` (default `Anchor.Adapters.ConfigFile`), `:beam_source`
  (`Anchor.Adapters.BeamReader`), `:source_source`
  (`Anchor.Adapters.SourceReader`), `:graph_store`
  (`Anchor.Adapters.GraphArtifact`), `:graph_rules` (the rule modules,
  `Anchor.Domain.GraphRules.all/0`).
  """

  alias Anchor.Adapters.BeamReader
  alias Anchor.Adapters.ConfigFile
  alias Anchor.Adapters.GraphArtifact
  alias Anchor.Adapters.SourceReader
  alias Anchor.Config
  alias Anchor.Domain.Failures
  alias Anchor.Domain.Graph
  alias Anchor.Domain.Graph.Beam
  alias Anchor.Domain.Graph.Builder
  alias Anchor.Domain.Graph.ProjectFile
  alias Anchor.Domain.GraphKey
  alias Anchor.Domain.GraphReport
  alias Anchor.Domain.GraphReport.Finding
  alias Anchor.Domain.GraphRules
  alias Anchor.Domain.Model
  alias Anchor.Domain.Violation
  alias Anchor.Managers.Graph.Request

  @config_file ".anchor.yml"

  @doc "Runs the graph engine for `request`; see the moduledoc."
  @spec run(Request.t(), keyword()) :: GraphReport.t()
  def run(%Request{} = request, deps \\ []) do
    deps = deps(deps)

    with {:ok, config} <- load_config(deps.config_loader),
         {:ok, rules} <- graph_rules(config, request, deps.graph_rules),
         {:ok, beams, outside} <- read_beams(deps.beam_source, request) do
      measured(request, config, rules, {beams, outside}, deps)
    else
      {:could_not_check, violation} ->
        GraphReport.new(
          [],
          [Finding.fail_closed(violation, @config_file)],
          counts(request, 0, 0, 0)
        )
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
        {:could_not_check, Failures.graph_no_architecture(config.path)}

      {:ok, %Config{} = config} ->
        {:ok, config}

      {:error, reason} ->
        {:could_not_check, Failures.config_violation(reason)}
    end
  end

  # The config's graph rules: those whose type a graph rule module checks,
  # narrowed to `--only` ids when given, each with its module. An `--only` id
  # that names no graph rule would run nothing and read clean, so it is
  # COULD NOT MEASURE.
  defp graph_rules(config, request, modules) do
    by_type = GraphRules.by_type(modules)
    only = Map.get(request.opts, :only, [])

    all =
      for rule <- config.rules,
          module = Map.get(by_type, rule.type),
          module != nil,
          do: {rule, module}

    ids = Enum.map(all, fn {rule, _module} -> Map.get(rule, :id) end)

    case Enum.reject(only, &(&1 in ids)) do
      [] -> {:ok, Enum.filter(all, fn {rule, _module} -> only == [] or rule[:id] in only end)}
      unknown -> {:could_not_check, Failures.graph_unknown_only(unknown, config.path)}
    end
  end

  # A module whose source is outside the root is left out before anything is
  # built; it is counted and named (`outside_notes/2`), never dropped
  # silently. A run whose every module was outside the root read no project
  # module (DND-5588).
  defp read_beams(source, %Request{apps: apps, root: root}) do
    {outside, beams} = apps |> source.read_ebins() |> Enum.split_with(&outside_root?(&1, root))
    ebins = Enum.map(apps, &elem(&1, 1))

    cond do
      Enum.any?(beams, &match?(%Beam{}, &1)) ->
        {:ok, beams, outside}

      outside != [] ->
        {:could_not_check, Failures.graph_all_outside_root(length(outside), root, ebins)}

      true ->
        {:could_not_check, Failures.graph_no_modules(ebins)}
    end
  end

  defp outside_root?(%Beam{elixir: %{relative_file: file}}, root) when is_binary(file),
    do: ProjectFile.place(file, root) == :outside_root

  defp outside_root?(_beam, _root), do: false

  # One report-only note per module left out: the verdict stands, and the
  # module is named with its path.
  defp outside_notes(outside, root) do
    for %Beam{module: module, elixir: %{relative_file: file}} <- outside do
      violation = Failures.graph_module_outside_root(module, file, root)
      %{Finding.fail_closed(violation, file) | enforcement: :report}
    end
  end

  defp measured(request, config, rules, {beams, outside}, deps) do
    {source_facts, source_issues} = source_facts(deps.source_source, request.root, beams)
    graph = Builder.build(beams, source_facts, root: request.root)
    {model, class_issues} = Model.build(graph, config, source_facts)
    unreadable_issues = unreadable_issues(graph)
    rule_findings = Enum.flat_map(rules, &run_rule(&1, model, config.path))

    artifact_notes =
      write_artifact(deps.graph_store, request, {beams, source_facts}, config, graph)

    outside_notes = outside_notes(outside, request.root)

    fail_closed =
      (unreadable_issues ++ source_issues ++ class_issues)
      |> Enum.map(&Finding.fail_closed(&1, @config_file))

    GraphReport.new(
      fail_closed ++ rule_findings ++ outside_notes ++ artifact_notes,
      [],
      request
      |> counts(map_size(graph.modules), length(rules), length(Model.opaque(model)))
      |> Map.put(:no_core, no_core_count(graph))
      |> Map.put(:excluded, length(outside))
    )
  end

  defp source_facts(source, root, beams) do
    files =
      beams
      |> Enum.flat_map(fn
        # `read_beams/2` already left out every module outside the root, so
        # each path here places as the project's.
        %Beam{elixir: %{relative_file: file}} when is_binary(file) ->
          {:project, relative} = ProjectFile.place(file, root)
          [relative]

        _other ->
          []
      end)
      |> Enum.uniq()
      |> Enum.sort()

    source.read(root, files)
    |> Enum.sort()
    |> Enum.reduce({%{}, []}, &source_fact/2)
    |> then(fn {facts, issues} -> {facts, Enum.reverse(issues)} end)
  end

  # The adapter already turned each file into `SourceFacts` (ADR 001: no raw
  # text past the adapter); an error entry is reported, and an unparseable
  # file's `{:error, :unparseable}` is kept so the builder says `:unknown`.
  defp source_fact({file, {:error, :unparseable} = error}, {facts, issues}),
    do:
      {Map.put(facts, file, error),
       [Failures.graph_source_unreadable(file, :unparseable) | issues]}

  defp source_fact({file, {:error, reason}}, {facts, issues}),
    do: {facts, [Failures.graph_source_unreadable(file, reason) | issues]}

  defp source_fact({file, %{defmodules: _} = parsed}, {facts, issues}),
    do: {Map.put(facts, file, parsed), issues}

  # Every `unreadable` entry is an issue, except an Erlang module with a
  # known name: the model classifies those (an unclassified one is its issue).
  defp unreadable_issues(%Graph{unreadable: entries}) do
    for entry <- entries, not erlang_module?(entry), do: Failures.graph_unreadable(entry)
  end

  defp erlang_module?(%{reason: {:not_elixir, _backend}, module: module}),
    do: is_atom(module) and module != nil

  defp erlang_module?(_entry), do: false

  # A rule's floor is judged whenever it runs, `--only` or not: `--only`
  # narrows the rules, never the modules, so a rule selecting nothing must not
  # read as a pass.
  defp run_rule({rule, module}, model, config_path) do
    floor_findings(rule, model, config_path) ++ check(rule, module, model, config_path)
  end

  defp floor_findings(rule, model, config_path) do
    for {^rule, selected} <- GraphRules.below_floor(model, [rule]) do
      rule
      |> Failures.rule_below_floor(selected, GraphRules.min_modules(rule), config_path)
      |> Finding.fail_closed(@config_file)
    end
  end

  defp check(rule, module, model, config_path) do
    label = Failures.rule_label(rule)

    rule
    |> guarded_check(module, model)
    |> case do
      {:ok, violations} ->
        Enum.map(violations, &Finding.from_rule(&1, rule, label, config_path || @config_file))

      {:crashed, kind, reason, stacktrace} ->
        [
          rule
          |> Failures.rule_crashed(kind, reason, stacktrace, config_path)
          |> Finding.fail_closed(@config_file)
        ]
    end
  end

  # The rule's return is validated inside the guard: a rule that returns
  # anything but a list of violations is reported like one that raised.
  defp guarded_check(rule, module, model) do
    {:ok, violations!(module.check(model, rule))}
  rescue
    exception -> {:crashed, :error, exception, __STACKTRACE__}
  catch
    :throw, reason -> {:crashed, :throw, reason, __STACKTRACE__}
    :exit, reason -> {:crashed, :exit, reason, __STACKTRACE__}
  end

  defp violations!(violations) when is_list(violations) do
    if Enum.all?(violations, &match?(%Violation{}, &1)),
      do: violations,
      else: raise(ArgumentError, "check/2 returned a list holding a non-Violation")
  end

  defp violations!(other),
    do: raise(ArgumentError, "check/2 returned #{inspect(other, limit: 5)}, not a list")

  # The key covers every input the graph was built from: the beams and each
  # source file's facts (DND-5586), the config and Anchor's version.
  defp write_artifact(store, request, {beams, source_facts}, config, graph) do
    dir = Path.join(request.build_path, "anchor")

    key =
      GraphKey.key(
        beam_entries(beams),
        Enum.map(source_facts, fn {file, facts} ->
          {file, :erlang.term_to_binary(facts, [:deterministic])}
        end),
        :erlang.term_to_binary(config, [:deterministic]),
        version()
      )

    case store.write(dir, key, graph) do
      :ok ->
        []

      {:error, reason} ->
        [
          %{
            Finding.fail_closed(Failures.graph_artifact_not_written(dir, reason), dir)
            | enforcement: :report
          }
        ]
    end
  end

  defp beam_entries(beams) do
    Enum.map(beams, fn
      %Beam{path: path} = beam -> {path, :erlang.term_to_binary(beam, [:deterministic])}
      {:error, %{path: path} = error} -> {path, :erlang.term_to_binary(error, [:deterministic])}
    end)
  end

  defp version do
    case Application.spec(:anchor, :vsn) do
      nil -> "unknown"
      vsn -> to_string(vsn)
    end
  end

  defp counts(%Request{apps: apps}, modules, rules, opaque),
    do: %{
      modules: modules,
      apps: length(apps),
      rules: rules,
      opaque: opaque,
      no_core: 0,
      excluded: 0
    }

  # Every function the graph has no Core body for: no call in it was read, so
  # the summary counts them (DND-5549).
  defp no_core_count(graph) do
    graph |> Graph.functions_without_core() |> Map.values() |> Enum.map(&length/1) |> Enum.sum()
  end
end
