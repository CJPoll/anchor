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
       zero modules read is COULD NOT MEASURE (exit 3), and an app whose
       ebin gave no module while another's did is an issue on that ebin
       (exit 1, DND-5584);
    3. read each module's source file's facts (`Anchor.Adapters.SourceSource`):
       its literal `defmodule`s and `use`s (`Anchor.Domain.Graph.SourceFacts`);
    4. build the graph fresh (`Anchor.Domain.Graph.Builder`): never a cached
       one, and never a cached verdict;
    5. build the model (`Anchor.Domain.Model`): classify every module into
       exactly one bucket, and check the bucket floors;
    6. for each enabled graph rule (narrowed by `--only`): its floor
       (`min_modules`), then its `check/2` under a guard (`try` with `rescue`, `catch :throw` and
       `catch :exit`, DND-1312's lesson): a rule that crashes is one issue,
       and the other rules still run;
    7. for each rule with a `baseline:` (DND-5441): read it
       (`Anchor.Adapters.BaselineStore`), and under `--base REF` its copy at
       `REF` (`Anchor.Adapters.GitBase`), and judge the rule's findings
       against it (`Anchor.Domain.Enforcement`): held findings are counted,
       NEW ones stand, STALE and GREW entries are findings. A baseline that is
       missing, not UTF-8 or holds another rule's entries is an issue on its
       path, and every finding of the rule stands. Under `--write-baseline
       ID` that rule's baseline is created instead (`BaselineStore.create/3`
       only creates: an existing file is refused, exit 2);
    8. write the graph artifact for `explain`/`place`
       (`Anchor.Adapters.GraphStore`) under `_build/<env>/anchor`; the
       verdict never reads it;
    9. return the `%Anchor.Domain.GraphReport{}`.

  Every per-module problem is an issue on that module (exit 1), never a
  skipped module: a beam it could not decode, a module whose graph walk
  crashed (`{:walk_crashed, _}`, DND-5548), an Erlang module no bucket
  classifies, a source file it could not read, an unclassified or ambiguous
  module.

  A rule that crashed is not compared with its baseline: its one issue
  stands, and its baseline is neither read nor written.

  ## Options (the adapters, for tests)

  `:config_loader` (default `Anchor.Adapters.ConfigFile`), `:beam_source`
  (`Anchor.Adapters.BeamReader`), `:source_source`
  (`Anchor.Adapters.SourceReader`), `:graph_store`
  (`Anchor.Adapters.GraphArtifact`), `:baseline_store`
  (`Anchor.Adapters.BaselineFile`), `:git_base` (`Anchor.Adapters.GitShow`),
  `:graph_rules` (the rule modules, `Anchor.Domain.GraphRules.all/0`).
  """

  alias Anchor.Adapters.BaselineFile
  alias Anchor.Adapters.BeamReader
  alias Anchor.Adapters.ConfigFile
  alias Anchor.Adapters.GitShow
  alias Anchor.Adapters.GraphArtifact
  alias Anchor.Adapters.SourceReader
  alias Anchor.Config
  alias Anchor.Domain.Baseline
  alias Anchor.Domain.Enforcement
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
         :ok <- write_target(rules, request, config),
         {:ok, beams} <- read_beams(deps.beam_source, request) do
      measured(request, config, rules, beams, deps)
    else
      {:could_not_check, violation} ->
        GraphReport.new(
          [],
          [Finding.fail_closed(violation, @config_file)],
          counts(request, 0, 0, 0)
        )

      {:refused, violation} ->
        GraphReport.new([], [], counts(request, 0, 0, 0),
          refused: [Finding.fail_closed(violation, @config_file)]
        )
    end
  end

  # DND-5441: `--write-baseline ID` must name a running graph rule with a
  # `baseline:` path; anything else would write nothing and read as done.
  defp write_target(rules, request, config) do
    case Map.get(request.opts, :write_baseline) do
      nil ->
        :ok

      id ->
        if Enum.any?(rules, fn {rule, _module} -> rule[:id] == id and rule[:baseline] end),
          do: :ok,
          else: {:refused, Failures.write_baseline_unknown(id, config.path)}
    end
  end

  defp deps(deps) do
    %{
      config_loader: Keyword.get(deps, :config_loader, ConfigFile),
      beam_source: Keyword.get(deps, :beam_source, BeamReader),
      source_source: Keyword.get(deps, :source_source, SourceReader),
      graph_store: Keyword.get(deps, :graph_store, GraphArtifact),
      baseline_store: Keyword.get(deps, :baseline_store, BaselineFile),
      git_base: Keyword.get(deps, :git_base, GitShow),
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
    unreadable_issues = empty_app_issues(request.apps, beams) ++ unreadable_issues(graph)
    ran = Enum.map(rules, &run_rule(&1, model, config.path, request, deps))
    artifact_notes = write_artifact(deps.graph_store, request, beams, config, graph)

    fail_closed =
      (unreadable_issues ++ source_issues ++ class_issues)
      |> Enum.map(&Finding.fail_closed(&1, @config_file))

    GraphReport.new(
      fail_closed ++ Enum.flat_map(ran, & &1.findings) ++ artifact_notes,
      [],
      counts(request, map_size(graph.modules), length(rules), length(Model.opaque(model))),
      held: Enum.flat_map(ran, & &1.held),
      refused: Enum.flat_map(ran, & &1.refused)
    )
  end

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

  # DND-5584: the run fails closed per app, not only over the total: an app
  # whose ebin gave no module (while another's did) is an issue on its ebin.
  defp empty_app_issues(apps, beams) do
    for {app, ebin} <- Beam.apps_without_modules(apps, beams),
        do: Failures.graph_app_no_modules(app, ebin)
  end

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
  defp run_rule({rule, module}, model, config_path, request, deps) do
    floor = floor_findings(rule, model, config_path)

    case check(rule, module, model, config_path) do
      {:ok, findings} ->
        ran = ratchet(rule, findings, request, deps)
        %{ran | findings: floor ++ ran.findings}

      {:crashed, finding} ->
        %{findings: floor ++ [finding], held: [], refused: []}
    end
  end

  # DND-5441: a rule with no `baseline:` keeps every finding; one with a
  # baseline is judged against it, or, under `--write-baseline` naming it, has
  # its baseline created.
  defp ratchet(%{baseline: path} = rule, findings, request, deps) when is_binary(path) do
    if Map.get(request.opts, :write_baseline) == rule.id,
      do: write_baseline(rule, path, findings, request, deps),
      else: compare_baseline(rule, path, findings, request, deps)
  end

  defp ratchet(_rule, findings, _request, _deps), do: %{findings: findings, held: [], refused: []}

  defp compare_baseline(rule, path, findings, request, deps) do
    ref = Map.get(request.opts, :base)

    with {:ok, entries} <- read_entries(deps.baseline_store, request.root, rule, path),
         :ok <- no_foreign(rule, path, entries),
         {:ok, base} <- base_entries(deps.git_base, request.root, ref, path) do
      context = %{rule: rule, label: Failures.rule_label(rule), path: path, ref: ref}
      {standing, held} = Enforcement.judge(findings, entries, base, context)
      %{findings: standing, held: held, refused: []}
    else
      {:fail, violation} ->
        %{findings: findings ++ [Finding.fail_closed(violation, path)], held: [], refused: []}
    end
  end

  defp read_entries(store, root, rule, path) do
    case store.read(root, path) do
      {:ok, entries} -> {:ok, entries}
      {:error, reason} -> {:fail, Failures.baseline_unreadable(rule, path, reason)}
    end
  end

  defp no_foreign(rule, path, entries) do
    case Baseline.foreign(rule.id, entries) do
      [] -> :ok
      [entry | _rest] -> {:fail, Failures.baseline_foreign(rule, path, entry)}
    end
  end

  # The base branch's copy under `--base REF`: `nil` without it, `:absent`
  # for a first landing. A failed read is an issue, never "no growth".
  defp base_entries(_git, _root, nil, _path), do: {:ok, nil}

  defp base_entries(git, root, ref, path) do
    case git.show(root, ref, path) do
      {:ok, entries} -> {:ok, {:ok, entries}}
      {:error, :absent} -> {:ok, :absent}
      {:error, reason} -> {:fail, Failures.baseline_base_unreadable(path, ref, reason)}
    end
  end

  # `--write-baseline`: the rule's current keys, sorted, into a file that must
  # not exist yet. A written finding is held; one with no key cannot be.
  defp write_baseline(rule, path, findings, request, deps) do
    {keyed, unkeyed} = Enum.split_with(findings, &is_binary(&1.key))
    contents = Baseline.render(rule.id, Enum.map(keyed, & &1.key))

    case deps.baseline_store.create(request.root, path, contents) do
      :ok ->
        note = Finding.fail_closed(Failures.baseline_written(path, length(keyed)), path)
        %{findings: unkeyed ++ [%{note | enforcement: :report}], held: keyed, refused: []}

      {:error, :exists} ->
        refused = Finding.fail_closed(Failures.baseline_exists(path), path)
        %{findings: findings, held: [], refused: [refused]}

      {:error, reason} ->
        issue = Finding.fail_closed(Failures.baseline_not_written(path, reason), path)
        %{findings: findings ++ [issue], held: [], refused: []}
    end
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
        {:ok,
         Enum.map(violations, &Finding.from_rule(&1, rule, label, config_path || @config_file))}

      {:crashed, kind, reason, stacktrace} ->
        {:crashed,
         rule
         |> Failures.rule_crashed(kind, reason, stacktrace, config_path)
         |> Finding.fail_closed(@config_file)}
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
    do: %{modules: modules, apps: length(apps), rules: rules, opaque: opaque}
end
