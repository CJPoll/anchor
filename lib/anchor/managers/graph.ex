defmodule Anchor.Managers.Graph do
  @moduledoc """
  Runs the graph engine once: the **Manager** (ADR 001) behind `mix
  anchor.graph` (DND-5440; shared contract section 7). It calls adapters and
  Domain only, never a Framework module (DND-1288's shape is forbidden here).

  `run/2` does, in order:

    1. load `.anchor.yml` (`Anchor.Adapters.ConfigLoader`); a missing or
       invalid config is COULD NOT MEASURE (exit 3), and so is a config with no
       `architecture:` section: nothing could be classified;
    2. read every beam of the project's ebins (`Anchor.Adapters.BeamSource`):
       a module is project code because its beam came from a project ebin,
       wherever its source sits (DND-5630). One compiled from a source
       outside the root (`elixirc_paths: ["../shared"]`) is judged and
       enforced like any other, keyed by its root-relative `../` path
       (`Anchor.Domain.Graph.ProjectFile`), and counted in the summary as
       `(<n> outside the root)`; a run that read no module is COULD NOT
       MEASURE (exit 3), and an app whose ebin gave no module while
       another's did is an issue on that ebin (exit 1, DND-5584);
    3. read each module's source file's facts (`Anchor.Adapters.SourceSource`):
       its literal `defmodule`s and `use`s (`Anchor.Domain.Graph.SourceFacts`),
       by its path relative to the root (an absolute path is made relative,
       through `..` when it is outside the root; a relative one is read
       against its app's directory in `Request.source_dirs`, an umbrella's
       `apps/<app>`, DND-5637);
    4. build the graph fresh (`Anchor.Domain.Graph.Builder`): never a cached
       one, and never a cached verdict;
    5. build the model (`Anchor.Domain.Model`): classify every module into
       exactly one bucket, and check the bucket floors;
    6. read each enabled graph rule's needs (`GraphRules.needs/1`, narrowed
       by `--only`, under the guard below) and, when any of them needs
       `:cfa`, run the higher-order flow analysis once
       (`Anchor.Domain.Cfa.analyze/3` with `Cfa.default_seed/1`, under the
       guard) and store it on `Model.cfa` (DND-5574). When none does, it is
       not run: rules that do not need it pay nothing. Likewise `:effects`:
       the effect inference (`Anchor.Domain.Effects.infer/2`, DND-5447) runs
       once after the flow analysis, under the guard, onto `Model.effects`;
    7. for each enabled graph rule (narrowed by `--only`): its floor
       (`min_modules`), then its `check/2` under a guard (`try` with `rescue`, `catch :throw` and
       `catch :exit`, DND-1312's lesson): a rule that crashes is one issue,
       and the other rules still run. A rule whose `needs/0` is refused, or
       whose needed analysis crashed, is one issue too and is not run;
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
       (`Anchor.Adapters.GraphStore`) under `<build_path>/anchor`, the build
       path the task gathered from Mix (DND-5585); the verdict never reads it;
    9. return the `%Anchor.Domain.GraphReport{}`, with the apply-site
       counts (`GraphReport.apply_sites/1`) when the analysis ran, and the
       effect counts (`GraphReport.effects/1`) when the effect inference ran,
       and declared aggregates' counts (`Anchor.Domain.Aggregates.Index`,
       DND-5476) when any is declared.

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
  `:graph_rules` (the rule modules, `Anchor.Domain.GraphRules.all/0`), `:cfa`
  (a one-argument function from the graph to its `%Anchor.Domain.Cfa{}`,
  default `Cfa.analyze(graph, Cfa.default_seed(graph))`; tests pass one that
  crashes), `:effects` (a two-argument function from the model and its
  options to its `%Anchor.Domain.Effects{}`, default `Effects.infer/2`), and
  `:behaviour_source` (`Anchor.Adapters.BehaviourReader`, the external
  behaviours' callbacks the inference's roots read).
  """

  alias Anchor.Adapters.BaselineFile
  alias Anchor.Adapters.BeamReader
  alias Anchor.Adapters.BehaviourReader
  alias Anchor.Adapters.ConfigFile
  alias Anchor.Adapters.GitShow
  alias Anchor.Adapters.GraphArtifact
  alias Anchor.Adapters.SourceReader
  alias Anchor.Config
  alias Anchor.Domain.Aggregates.Index
  alias Anchor.Domain.Baseline
  alias Anchor.Domain.BaselineBase
  alias Anchor.Domain.Cfa
  alias Anchor.Domain.DynamicCalls
  alias Anchor.Domain.Effects
  alias Anchor.Domain.Enforcement
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
  alias Anchor.Domain.Roots
  alias Anchor.Domain.Violation
  alias Anchor.Managers.Graph.Request

  @config_file ".anchor.yml"

  @doc "Runs the graph engine for `request`; see the moduledoc."
  @spec run(Request.t(), keyword()) :: GraphReport.t()
  def run(%Request{} = request, deps \\ []) do
    deps = deps(deps)

    with {:ok, config} <- load_config(deps.config_loader),
         {:ok, request} <- source_dirs(request, config),
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

  # DND-5655: an umbrella's app directories keyed against the root; an
  # absolute one outside it cannot be, and is refused before any beam is read.
  defp source_dirs(request, config) do
    case ProjectFile.source_dirs(request.source_dirs, request.root) do
      {:ok, dirs} ->
        {:ok, %{request | source_dirs: dirs}}

      {:error, outside} ->
        {:could_not_check,
         Failures.graph_apps_path_outside(outside, Path.expand(request.root), config.path)}
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
      graph_rules: Keyword.get(deps, :graph_rules, GraphRules.all()),
      cfa: Keyword.get(deps, :cfa, &analyze_cfa/1),
      effects: Keyword.get(deps, :effects, &Effects.infer/2),
      behaviour_source: Keyword.get(deps, :behaviour_source, BehaviourReader)
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

  # Every beam read came from a project ebin, so every one is the project's,
  # wherever its source sits (DND-5630).
  defp read_beams(source, %Request{apps: apps}) do
    beams = source.read_ebins(apps)

    if Enum.any?(beams, &match?(%Beam{}, &1)),
      do: {:ok, beams},
      else: {:could_not_check, Failures.graph_no_modules(Enum.map(apps, &elem(&1, 1)))}
  end

  # The modules compiled from a source outside the root: judged like every
  # other, and counted so the layout is visible. Counted over the graph's
  # modules, after the builder kept one beam per module (DND-5656): a stale
  # duplicate beam is its own issue, never a second module.
  defp outside_root_count(%Graph{modules: modules}) do
    Enum.count(modules, fn {_module, node} -> ProjectFile.outside_root?(node.source_file) end)
  end

  defp measured(request, config, rules, beams, deps) do
    {source_facts, source_issues} = source_facts(deps.source_source, request, beams)

    graph =
      Builder.build(beams, source_facts, root: request.root, source_dirs: request.source_dirs)

    {model, class_issues} = Model.build(graph, config, source_facts)

    unreadable_issues =
      empty_app_issues(request.apps, beams) ++ unreadable_issues(graph)

    rules = Enum.map(rules, fn {rule, module} -> {rule, module, guarded_needs(module)} end)
    cfa = cfa(rules, graph, deps.cfa)
    model = %{model | cfa: analysis(cfa)}
    effects = effects(rules, model, cfa, deps)
    model = %{model | effects: effects_analysis(effects)}

    deps =
      Map.merge(deps, %{base: base_config(deps.git_base, request, config), now: config.rules})

    analyses = %{cfa: cfa, effects: effects}
    ran = Enum.map(rules, &run_rule(&1, model, analyses, config.path, request, deps))

    artifact_notes =
      write_artifact(deps.graph_store, request, {beams, source_facts}, config, graph)

    fail_closed =
      (unreadable_issues ++ source_issues ++ class_issues)
      |> Enum.map(&Finding.fail_closed(&1, @config_file))

    GraphReport.new(
      fail_closed ++
        Enum.flat_map(ran, & &1.findings) ++ base_config_issues(deps, ran) ++ artifact_notes,
      [],
      request
      |> counts(map_size(graph.modules), length(rules), length(Model.opaque(model)))
      |> Map.put(:no_core, no_core_count(graph))
      |> Map.put(:outside_root, outside_root_count(graph))
      |> Map.put(:apply_sites, GraphReport.apply_sites(model.cfa))
      |> Map.put(:dynamic_calls, DynamicCalls.tally(graph))
      |> put_effects(GraphReport.effects(model.effects))
      |> put_aggregates(model.aggregates),
      held: Enum.flat_map(ran, & &1.held),
      refused: Enum.flat_map(ran, & &1.refused)
    )
  end

  # DND-5476: the declared aggregates and their unknown tables are counted
  # in the summary when there are any.
  defp put_aggregates(counts, index) do
    case Index.declared(index) do
      0 ->
        counts

      declared ->
        Map.put(counts, :aggregates, %{declared: declared, tables_unknown: index.tables_unknown})
    end
  end

  defp analyze_cfa(graph), do: Cfa.analyze(graph, Cfa.default_seed(graph))

  # DND-5447: the effect inference runs once, after the flow analysis it
  # reads, and only when a rule that runs needs it: `nil` when none does or
  # when the flow analysis crashed (that rule then reports the flow
  # analysis), else the guarded result.
  defp effects(rules, model, cfa, deps) do
    needed? = Enum.any?(rules, fn {_rule, _module, needs} -> needs?(needs, :effects) end)

    case {needed?, cfa} do
      {true, {:crashed, _kind, _reason, _stacktrace}} -> nil
      {true, _ok_or_not_run} -> guarded(fn -> effects!(infer(model, deps)) end)
      {false, _cfa} -> nil
    end
  end

  # The external behaviours' callbacks (the roots' one read of the world) come
  # through the BehaviourSource port, so the inference itself stays pure.
  defp infer(model, deps) do
    callbacks = deps.behaviour_source.callbacks(Roots.external_behaviours(model.graph))
    deps.effects.(model, callbacks: callbacks)
  end

  # An inference that returns anything but an `%Effects{}` is reported like
  # one that raised.
  defp effects!(%Effects{} = effects), do: effects

  defp effects!(other),
    do: raise(ArgumentError, "the inference returned #{inspect(other, limit: 5)}, not %Effects{}")

  # The effect counts appear only when the inference ran (DND-5447).
  defp put_effects(counts, nil), do: counts
  defp put_effects(counts, effects), do: Map.put(counts, :effects, effects)

  defp effects_analysis({:ok, %Effects{} = effects}), do: effects
  defp effects_analysis(_none_or_crashed), do: nil

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

  # A beam's source path, keyed against the root: a relative one is read
  # against the directory Mix compiled its app from (DND-5637).
  defp place(%Beam{app: app, elixir: %{relative_file: file}}, %Request{} = request),
    do: ProjectFile.place(file, request.root, Map.get(request.source_dirs, app, "."))

  defp source_facts(source, %Request{root: root} = request, beams) do
    files =
      beams
      |> Enum.flat_map(fn
        # Inside the root or outside it, by its root-relative path (DND-5630).
        %Beam{elixir: %{relative_file: file}} = beam when is_binary(file) ->
          {_side, relative} = place(beam, request)
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
  defp run_rule({rule, module, needs}, model, analyses, config_path, request, deps) do
    floor = floor_findings(rule, model, config_path)

    case run_check(needs, analyses, rule, module, model, config_path) do
      {:ok, findings} ->
        ran =
          ratchet(rule, findings, request, Map.put(deps, :rule_module, module))

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
         {:ok, base} <- base_entries(deps, request, rule) do
      context = %{
        rule: rule,
        label: Failures.rule_label(rule),
        path: path,
        ref: ref,
        rule_module: deps.rule_module
      }

      {standing, held} = Enforcement.judge(findings, entries, base, context)
      %{findings: standing, held: held, refused: []}
    else
      {:fail, violation} ->
        %{findings: findings ++ [Finding.fail_closed(violation, path)], held: [], refused: []}

      # The base config did not load: the rule's findings all stand, and the
      # run's one issue on that config names it (`base_config_issues/2`).
      :unjudged ->
        %{findings: findings, held: [], refused: [], base_unjudged: rule.id}
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

  # DND-5629: under `--base REF`, the graph rules of the config at REF, read
  # once and only when a rule has a baseline: each baseline's base copy is
  # found by its rule's id there, never by the branch's path. `nil` without
  # `--base`; a failed read leaves every baselined rule's GREW unjudged, never
  # "no growth", and is one issue naming them all (DND-5648).
  defp base_config(git, request, config) do
    ref = Map.get(request.opts, :base)

    if ref != nil and Enum.any?(config.rules, &is_binary(Map.get(&1, :baseline))),
      do: read_base_rules(git, request.root, ref, config_path(config.path, request.root)),
      else: nil
  end

  defp read_base_rules(git, root, ref, config) do
    case git.rules(root, ref, config) do
      {:ok, rules} -> {:ok, rules}
      {:error, :absent} -> {:ok, :absent}
      {:error, reason} -> {:unreadable, config, ref, reason}
    end
  end

  # DND-5648: a base config that does not load is one cause, so it is one
  # issue, naming every rule whose GREW it left unjudged; each of those rules
  # keeps every finding (nothing held), as before.
  defp base_config_issues(%{base: {:unreadable, config, ref, reason}}, ran) do
    case for(%{base_unjudged: id} <- ran, do: id) do
      [] ->
        []

      ids ->
        [
          config
          |> Failures.baseline_base_config_unreadable(ref, reason, ids)
          |> Finding.fail_closed(config)
        ]
    end
  end

  defp base_config_issues(_deps, _ran), do: []

  defp config_path(path, root),
    do: if(Path.type(path) == :relative, do: path, else: Path.relative_to(path, root))

  # The base branch's copy of `rule`'s baseline: `nil` without `--base`,
  # `{:new_rule, gone}` for a rule id the base config lacks (a first landing),
  # `:absent` for a file absent at REF, and `{:ok, []}` for a rule that had no
  # baseline there. A failed read is an issue, never "no growth".
  defp base_entries(%{base: nil}, _request, _rule), do: {:ok, nil}

  defp base_entries(%{base: {:unreadable, _config, _ref, _reason}}, _request, _rule),
    do: :unjudged

  defp base_entries(%{base: {:ok, base_rules}} = deps, request, rule) do
    case BaselineBase.locate(base_rules, rule.id) do
      :new_rule -> {:ok, {:new_rule, BaselineBase.gone(base_rules, deps.now)}}
      :no_baseline -> {:ok, {:ok, []}}
      {:path, base_path} -> show_base(deps.git_base, request.root, request.opts.base, base_path)
    end
  end

  defp show_base(git, root, ref, path) do
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

  # A rule whose needs could not be read, or whose analysis crashed, is not
  # run: run without what it reads, it would check nothing and read clean.
  defp run_check({:crashed, kind, reason, stacktrace}, _analyses, rule, _module, _model, path),
    do: {:crashed, rule |> Failures.rule_crashed(kind, reason, stacktrace, path) |> fail_closed()}

  defp run_check(
         {:ok, needs},
         %{cfa: {:crashed, kind, reason, stacktrace}} = analyses,
         rule,
         module,
         model,
         path
       ) do
    if :cfa in needs,
      do:
        {:crashed,
         rule |> Failures.rule_cfa_crashed(kind, reason, stacktrace, path) |> fail_closed()},
      else: run_check({:ok, needs}, %{analyses | cfa: nil}, rule, module, model, path)
  end

  defp run_check(
         {:ok, needs},
         %{effects: {:crashed, kind, reason, stacktrace}},
         rule,
         module,
         model,
         path
       ) do
    if :effects in needs,
      do:
        {:crashed,
         rule |> Failures.rule_effects_crashed(kind, reason, stacktrace, path) |> fail_closed()},
      else: check(rule, module, model, path)
  end

  defp run_check({:ok, _needs}, _analyses, rule, module, model, path),
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
        {:ok, Enum.map(violations, &finding(&1, rule, label, config_path || @config_file))}

      {:crashed, kind, reason, stacktrace} ->
        {:crashed,
         rule
         |> Failures.rule_crashed(kind, reason, stacktrace, config_path)
         |> Finding.fail_closed(@config_file)}
    end
  end

  # A rule's fail-closed violation (DND-5476: a rule that checks nothing)
  # is an issue of the run, like a floor: always enforced, and with no key it
  # is never held by a baseline. Every other violation takes the rule's
  # enforcement and is judged against its baseline.
  defp finding(%Violation{kind: :fail_closed} = violation, _rule, _label, file),
    do: Finding.fail_closed(%{violation | key: nil}, file)

  defp finding(violation, rule, label, file), do: Finding.from_rule(violation, rule, label, file)

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

  # The key covers every input the graph was built from: the project root
  # (DND-5638: the facts' paths are relative to it), the beams and each
  # source file's facts (DND-5586), the config and Anchor's version.
  defp write_artifact(store, request, {beams, source_facts}, config, graph) do
    dir = Path.join(request.build_path, "anchor")

    key =
      GraphKey.key(
        Path.expand(request.root),
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
      outside_root: 0,
      apply_sites: nil
    }

  # Every function the graph has no Core body for: no call in it was read, so
  # the summary counts them (DND-5549).
  defp no_core_count(graph) do
    graph |> Graph.functions_without_core() |> Map.values() |> Enum.map(&length/1) |> Enum.sum()
  end
end
