defmodule Anchor.Managers.Graph do
  @moduledoc """
  Runs the graph engine once: the **Manager** (ADR 001) behind `mix
  anchor.graph` (DND-5440; shared contract section 7). It calls adapters and
  Domain only, never a Framework module (DND-1288's shape is forbidden here).

  `run/2` does, in order:

    1. load `.anchor.yml` (`Anchor.Adapters.ConfigLoader`); a missing or
       invalid config is COULD NOT MEASURE (exit 3), and so is a config with no
       `architecture:` section: nothing could be classified;
    2. read every beam of the project's ebins (`Anchor.Adapters.BeamSource`);
       zero modules read is COULD NOT MEASURE (exit 3);
    3. read each module's source file's facts (`Anchor.Adapters.SourceSource`):
       its literal `defmodule`s and `use`s (`Anchor.Domain.Graph.SourceFacts`);
    4. build the graph fresh (`Anchor.Domain.Graph.Builder`): never a cached
       one, and never a cached verdict;
    5. build the model (`Anchor.Domain.Model`): classify every module into
       exactly one bucket, and check the bucket floors;
    6. read each enabled graph rule's needs (`GraphRules.needs/1`, narrowed
       by `--only`, under the guard below) and, when any of them needs
       `:cfa`, run the higher-order flow analysis once
       (`Anchor.Domain.Cfa.analyze/3` with `Cfa.default_seed/1`, under the
       guard) and store it on `Model.cfa` (DND-5574). When none does, it is
       not run: rules that do not need it pay nothing;
    7. for each enabled graph rule (narrowed by `--only`): its floor
       (`min_modules`), then its `check/2` under a guard (`try` with `rescue`, `catch :throw` and
       `catch :exit`, DND-1312's lesson): a rule that crashes is one issue,
       and the other rules still run. A rule whose `needs/0` is refused, or
       whose needed analysis crashed, is one issue too and is not run;
    8. write the graph artifact for `explain`/`place`
       (`Anchor.Adapters.GraphStore`) under `_build/<env>/anchor`; the
       verdict never reads it;
    9. return the `%Anchor.Domain.GraphReport{}`, with the apply-site
       counts (`GraphReport.apply_sites/1`) when the analysis ran.

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
  `Anchor.Domain.GraphRules.all/0`), `:cfa` (a one-argument function from the
  graph to its `%Anchor.Domain.Cfa{}`, default `Cfa.analyze(graph,
  Cfa.default_seed(graph))`; tests pass one that crashes).
  """

  alias Anchor.Adapters.BeamReader
  alias Anchor.Adapters.ConfigFile
  alias Anchor.Adapters.GraphArtifact
  alias Anchor.Adapters.SourceReader
  alias Anchor.Config
  alias Anchor.Domain.Cfa
  alias Anchor.Domain.Failures
  alias Anchor.Domain.Graph
  alias Anchor.Domain.Graph.Beam
  alias Anchor.Domain.Graph.Builder
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
         {:ok, beams} <- read_beams(deps.beam_source, request) do
      measured(request, config, rules, beams, deps)
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
      graph_rules: Keyword.get(deps, :graph_rules, GraphRules.all()),
      cfa: Keyword.get(deps, :cfa, &analyze_cfa/1)
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

  defp read_beams(source, %Request{apps: apps}) do
    beams = source.read_ebins(apps)

    if Enum.any?(beams, &match?(%Beam{}, &1)),
      do: {:ok, beams},
      else: {:could_not_check, Failures.graph_no_modules(Enum.map(apps, &elem(&1, 1)))}
  end

  defp measured(request, config, rules, beams, deps) do
    {source_facts, source_issues} = source_facts(deps.source_source, request.root, beams)
    graph = Builder.build(beams, source_facts)
    {model, class_issues} = Model.build(graph, config, source_facts)
    unreadable_issues = unreadable_issues(graph)
    rules = Enum.map(rules, fn {rule, module} -> {rule, module, guarded_needs(module)} end)
    cfa = cfa(rules, graph, deps.cfa)
    model = %{model | cfa: analysis(cfa)}
    rule_findings = Enum.flat_map(rules, &run_rule(&1, model, cfa, config.path))
    artifact_notes = write_artifact(deps.graph_store, request, beams, config, graph)

    fail_closed =
      (unreadable_issues ++ source_issues ++ class_issues)
      |> Enum.map(&Finding.fail_closed(&1, @config_file))

    GraphReport.new(
      fail_closed ++ rule_findings ++ artifact_notes,
      [],
      request
      |> counts(map_size(graph.modules), length(rules), length(Model.opaque(model)))
      |> Map.put(:no_core, no_core_count(graph))
      |> Map.put(:apply_sites, GraphReport.apply_sites(model.cfa))
    )
  end

  defp analyze_cfa(graph), do: Cfa.analyze(graph, Cfa.default_seed(graph))

  # The analysis runs once, and only when a rule that runs needs it: `nil`
  # when none does, else the guarded result.
  defp cfa(rules, graph, analyze) do
    if Enum.any?(rules, fn {_rule, _module, needs} -> needs?(needs, :cfa) end),
      do: guarded(fn -> analysis!(analyze.(graph)) end),
      else: nil
  end

  # An analysis that returns anything but a `%Cfa{}` is reported like one
  # that raised: read as `nil`, its rules would run without it.
  defp analysis!(%Cfa{} = cfa), do: cfa

  defp analysis!(other),
    do: raise(ArgumentError, "the analysis returned #{inspect(other, limit: 5)}, not a %Cfa{}")

  defp needs?({:ok, needs}, need), do: need in needs
  defp needs?(_crashed, _need), do: false

  defp analysis({:ok, %Cfa{} = cfa}), do: cfa
  defp analysis(_none_or_crashed), do: nil

  defp guarded_needs(module), do: guarded(fn -> GraphRules.needs(module) end)

  defp source_facts(source, root, beams) do
    files =
      beams
      |> Enum.flat_map(fn
        %Beam{elixir: %{relative_file: file}} when is_binary(file) -> [file]
        _other -> []
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
  defp run_rule({rule, module, needs}, model, cfa, config_path) do
    floor_findings(rule, model, config_path) ++
      run_check(needs, cfa, rule, module, model, config_path)
  end

  # A rule whose needs could not be read, or whose analysis crashed, is not
  # run: run without what it reads, it would check nothing and read clean.
  defp run_check({:crashed, kind, reason, stacktrace}, _cfa, rule, _module, _model, path),
    do: [rule |> Failures.rule_crashed(kind, reason, stacktrace, path) |> fail_closed()]

  defp run_check({:ok, needs}, {:crashed, kind, reason, stacktrace}, rule, module, model, path) do
    if :cfa in needs,
      do: [rule |> Failures.rule_cfa_crashed(kind, reason, stacktrace, path) |> fail_closed()],
      else: check(rule, module, model, path)
  end

  defp run_check({:ok, _needs}, _cfa, rule, module, model, path),
    do: check(rule, module, model, path)

  defp fail_closed(violation), do: Finding.fail_closed(violation, @config_file)

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
  defp guarded_check(rule, module, model),
    do: guarded(fn -> violations!(module.check(model, rule)) end)

  defp guarded(fun) do
    {:ok, fun.()}
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

  defp write_artifact(store, request, beams, config, graph) do
    dir = Path.join([request.root, "_build", to_string(request.env), "anchor"])

    key =
      GraphKey.key(
        beam_entries(beams),
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
      apply_sites: nil
    }

  # Every function the graph has no Core body for: no call in it was read, so
  # the summary counts them (DND-5549).
  defp no_core_count(graph) do
    graph |> Graph.functions_without_core() |> Map.values() |> Enum.map(&length/1) |> Enum.sum()
  end
end
