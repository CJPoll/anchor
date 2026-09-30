defmodule Anchor.Managers.Lint do
  @moduledoc """
  Orchestrates a single check's run over a set of source files — the **Manager**
  (ADR 001), and the only module allowed to call both the config adapter (a Side
  Effect) and Domain code (`Anchor.Domain.RuleMatching` — which in turn uses
  `Anchor.Domain.GlobPattern` — and the check's own detection).

  It takes a check to completion:

    1. Load configuration through the `Anchor.Adapters.ConfigLoader` behaviour
       (defaulting to `Anchor.Adapters.ConfigFile`, overridable for tests via the
       `:config_loader` option).
    2. Build the cross-file module dependency graph once, but only when the check
       declares `needs_module_graph?/0` — the transitive-dependency check needs
       it; the others do not.
    3. For each file: acquire the AST at the framework edge, derive the pure
       facts the Domain selector operates on, select the rules that apply to this
       check and this file (`RuleMatching`, which uses `GlobPattern`), and — when at least
       one rule matches — call the check's Domain detection.
    4. Return `{:ok, [{source_file, [%Anchor.Domain.Violation{}]}]}` — Domain
       objects, never `Credo.Issue`s. Mapping violations to Credo issues is the
       Framework's job (`Anchor.Check.Base`).

  On a config-load failure it returns `{:error, reason}`, which the Framework
  reports as a Credo issue (DND-1265: Anchor fails closed, so a run that checked
  nothing never reads as a run that found nothing).

  A source file that does not parse yields one `:fail_closed` violation from
  `Anchor.Domain.Failures`, not an empty AST, when the `:report_shared_failures`
  option is `true` (the default). The Framework passes `false` to every Anchor
  check but one, so the report appears once per run; see
  `Anchor.Check.Base.shared_failure_reporter?/2`.

  ## Rules that checked nothing (DND-1290)

  After the per-file results comes one `{:config, violations}` entry, when a
  rule checked nothing in this run (`Anchor.Domain.RuleCoverage`):

    * a rule of this check's type that selected fewer of the run's files than
      its floor (`min_files`, default 1). The Framework turns this off with
      `enforce_selection_floors: false` when the run saw only some of the files
      (`Anchor.Check.Base.whole_file_set?/2`);
    * under the same switch, a rule of this check's type that lists an
      `allowed_callers` entry no file it selects defines (DND-1269);
    * for the shared-failure reporter only, a rule whose type is not in
      `:enabled_rule_types` (the types some enabled check reads; `:unknown`,
      the default, reports nothing). When no Anchor check is enabled at all,
      Credo never calls this Manager, so that case cannot be reported here.

  Each violation sits on the config the rule came from.

  ## Analysis crashes (DND-1310)

  A raise, throw or exit while analysing a file never escapes a check (Credo's
  runner would abort the run, or drop the check's issues and read as a pass).
  Each becomes one `:fail_closed` violation on that file
  (`Anchor.Domain.Failures.analysis_crash_violation/4`):

    * deriving the file's facts, shared by every check: reported once per run,
      by the shared-failure reporter, as an unparseable file is;
    * building the file's module-graph nodes, or the check's own detection:
      reported by that check.

  ## AST acquisition

  Acquisition goes through `Anchor.Check.Source` (the Framework edge, the only
  place Credo AST/source acquisition may appear); it unwraps Credo's
  `{:ok, ast}` once and hands the bare AST to the pure
  `Anchor.Domain.DependencyAnalyzer`, which derives the facts the Domain selector
  (`RuleMatching`, and `GlobPattern` beneath it) operates on. No Credo types
  cross into the Domain.
  """

  alias Anchor.Adapters.ConfigFile
  alias Anchor.Check.Source
  alias Anchor.Config
  alias Anchor.Domain.DependencyAnalyzer
  alias Anchor.Domain.Failures
  alias Anchor.Domain.RuleCoverage
  alias Anchor.Domain.RuleMatching

  @default_analyzer DependencyAnalyzer
  @default_config_loader ConfigFile

  @type result ::
          {:ok, [{Credo.SourceFile.t() | :config, [Anchor.Domain.Violation.t()]}]}
          | {:error, term()}

  @doc """
  Runs `check_module` over `source_files`, returning per-file violations.

  `params` are the Credo check params, threaded through to the check's detection.
  `opts` accepts `:config_loader` — a module implementing
  `Anchor.Adapters.ConfigLoader` — to inject a mock in tests; it defaults to the
  real `Anchor.Adapters.ConfigFile`. It also accepts `:report_shared_failures`
  (default `true`): whether an unparseable file yields its violation for this
  check. DND-1290 adds `:enforce_selection_floors` (default `true`),
  `:enabled_rule_types` (a list of rule types, or `:unknown`, the default) and
  `:checks_by_type` (rule type to check module, for naming the check to enable;
  default `%{}`). See "Rules that checked nothing" above.

  DND-1310 adds `:analyzer` (default `Anchor.Domain.DependencyAnalyzer`): the
  module that derives each file's facts and module-graph nodes, so a test can
  inject a crash there. A crash is reported, never escapes: see "Analysis
  crashes" above.
  """
  @spec run(module(), [Credo.SourceFile.t()], keyword(), keyword()) :: result()
  def run(check_module, source_files, params, opts \\ []) do
    config_loader = Keyword.get(opts, :config_loader, @default_config_loader)
    report_shared_failures? = Keyword.get(opts, :report_shared_failures, true)
    analyzer = Keyword.get(opts, :analyzer, @default_analyzer)

    case config_loader.load() do
      {:ok, %Config{rules: rules} = config} ->
        {modules_map, graph_crashes} = build_modules_map(check_module, analyzer, source_files)

        run_context = %{
          check: check_module,
          analyzer: analyzer,
          rules: rules,
          modules_map: modules_map,
          graph_crashes: graph_crashes,
          params: params,
          report_shared_failures?: report_shared_failures?,
          defined_modules?: lists_allowed_callers?(check_module, rules)
        }

        # Each file is parsed as it is checked and dropped afterwards, so a run
        # never holds every file's AST at once. Only its facts are kept, for the
        # selection floor.
        results = Enum.map(source_files, &result_for_file(&1, run_context))

        file_results =
          Enum.map(results, fn {source_file, violations, _facts} -> {source_file, violations} end)

        facts = Enum.map(results, fn {_source_file, _violations, facts} -> facts end)

        {:ok, file_results ++ config_results(check_module, config, facts, opts)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # DND-1290: the rules that checked nothing in this run, as one `{:config,
  # violations}` entry after the per-file results (none when every rule
  # checked something). Each check reports the floors of its own type's rules,
  # over the files it ran on; the shared-failure reporter also names the rules
  # no enabled check reads.
  defp config_results(check_module, config, facts, opts) do
    case floor_violations(check_module, config, facts, opts) ++ unchecked_violations(config, opts) do
      [] -> []
      violations -> [{:config, violations}]
    end
  end

  # DND-1269: an allowed caller no selected file defines needs the whole file
  # set to tell, as a floor does, so it is reported only when floors are.
  defp floor_violations(check_module, %Config{rules: rules, path: path}, facts, opts) do
    if Keyword.get(opts, :enforce_selection_floors, true) do
      own_rules = own_rules(check_module, rules)

      below_floor =
        own_rules
        |> RuleCoverage.below_floor(facts)
        |> Enum.map(fn {rule, selected} ->
          Failures.selection_floor_violation(rule, selected, length(facts), path)
        end)

      missing_callers =
        own_rules
        |> RuleCoverage.missing_allowed_callers(facts)
        |> Enum.map(fn {rule, missing} ->
          Failures.missing_allowed_callers_violation(rule, missing, path)
        end)

      below_floor ++ missing_callers
    else
      []
    end
  end

  defp own_rules(check_module, rules) do
    rule_type = check_module.rule_type()
    Enum.filter(rules, &RuleMatching.rule_matches_type?(&1, rule_type))
  end

  # Whether a file's facts need the modules it defines: only when a rule this
  # check reads lists allowed callers, so no other run pays for the walk.
  defp lists_allowed_callers?(check_module, rules) do
    check_module
    |> own_rules(rules)
    |> Enum.any?(&(Map.get(&1, :allowed_callers) not in [nil, []]))
  end

  defp unchecked_violations(%Config{rules: rules, path: path}, opts) do
    enabled_types = Keyword.get(opts, :enabled_rule_types, :unknown)

    if Keyword.get(opts, :report_shared_failures, true) and is_list(enabled_types) do
      checks_by_type = Keyword.get(opts, :checks_by_type, %{})

      rules
      |> RuleCoverage.unchecked(enabled_types)
      |> Enum.map(&Failures.unchecked_rule_violation(&1, checks_by_type[&1.type], path))
    else
      []
    end
  end

  defp result_for_file(source_file, run_context) do
    source_file
    |> Source.ast()
    |> result_for_parse(source_file, run_context)
  end

  # DND-1265: a file Anchor cannot parse is reported, never checked as if it
  # were empty. The report is not specific to this check, so only the run's
  # shared-failure reporter makes it (see `Anchor.Check.Base`); every other
  # check skips the file. Its path still counts toward a `paths` rule's floor.
  defp result_for_parse({:error, {line, message}}, source_file, %{report_shared_failures?: true}) do
    {source_file, [Failures.unparseable_violation(line, message)], path_facts(source_file)}
  end

  defp result_for_parse({:error, _parse_error}, source_file, _run_context) do
    {source_file, [], path_facts(source_file)}
  end

  # DND-1310: the file's facts are the same for every check, so a crash
  # deriving them is reported once per run, by the shared-failure reporter, as
  # an unparseable file is; the file counts toward a floor as an unparsed one
  # does. It covers the file, so a graph crash on it is not reported twice. A
  # crash building this file's module-graph nodes is this check's own.
  defp result_for_parse({:ok, ast}, source_file, run_context) do
    %{analyzer: analyzer, graph_crashes: graph_crashes} = run_context

    case guarded(:file_analysis, fn -> file_facts(analyzer, source_file, ast, run_context) end) do
      {:ok, facts} ->
        {source_file, violations, facts} = detect_for_file(source_file, ast, facts, run_context)
        graph_violations = graph_crashes |> Map.get(source_file.filename) |> List.wrap()
        {source_file, graph_violations ++ violations, facts}

      {:crashed, violation} ->
        {source_file, facts_crash(violation, run_context), path_facts(source_file)}
    end
  end

  defp facts_crash(violation, %{report_shared_failures?: true}), do: [violation]
  defp facts_crash(_violation, _run_context), do: []

  defp detect_for_file(source_file, ast, facts, run_context) do
    %{check: check_module, rules: rules, modules_map: modules_map, params: params} = run_context
    # Gap F (DND-150): the file's facts (its own module names among them) are
    # computed ONCE here and reused for BOTH rule selection and the check
    # context — no second AST walk. The file's `module_names` are threaded into
    # the check context so `same_context` detection can derive the file's context.
    matching_rules = matching_rules(check_module, facts, rules)

    violations =
      detect(check_module, source_file, ast, matching_rules, modules_map, facts, params)

    {source_file, violations, facts}
  end

  defp detect(_check_module, _source_file, _ast, [], _modules_map, _facts, _params), do: []

  defp detect(check_module, source_file, ast, matching_rules, modules_map, facts, params) do
    context = %{modules_map: modules_map, params: params, module_names: facts.module_names}
    detect_file(check_module, source_file, ast, matching_rules, context)
  end

  @doc """
  Runs `check_module`'s detection on one parsed file with the rules already
  selected for it, and returns the violations.

  A raise, throw or exit in the detection becomes one `:fail_closed` violation
  on that file, naming the check and the reason (DND-1310,
  `Anchor.Domain.Failures.analysis_crash_violation/4`). It never escapes: Credo's
  runner would either abort the whole run on it or, with `crash_on_error:
  false`, drop every issue the check found, which reads as a pass.
  """
  @spec detect_file(module(), Credo.SourceFile.t(), Macro.t(), [map()], map()) ::
          [Anchor.Domain.Violation.t()]
  def detect_file(check_module, source_file, ast, rules, context) do
    case guarded(check_module, fn ->
           check_module.detect_violations(source_file, ast, rules, context)
         end) do
      {:ok, violations} -> violations
      {:crashed, violation} -> [violation]
    end
  end

  # `{:ok, result}`, or `{:crashed, violation}` when `fun` raised, threw or
  # exited. `subject` is the check, or `:file_analysis`.
  defp guarded(subject, fun) do
    {:ok, fun.()}
  catch
    kind, reason ->
      {:crashed, Failures.analysis_crash_violation(subject, kind, reason, __STACKTRACE__)}
  end

  defp matching_rules(check_module, facts, rules) do
    rule_type = check_module.rule_type()

    rules
    |> Enum.filter(&RuleMatching.rule_matches_type?(&1, rule_type))
    |> Enum.filter(&RuleMatching.rule_matches_file?(&1, facts))
  end

  # The facts of a file with no AST: its path only, marked unparsed so the floor
  # does not read its missing module names as "selects nothing".
  defp path_facts(source_file) do
    %{filename: source_file.filename, module_names: [], uses: [], parsed?: false}
  end

  defp file_facts(analyzer, source_file, ast, run_context) do
    facts = %{
      filename: source_file.filename,
      module_names: Enum.map(analyzer.extract_module_names(ast), &to_string/1),
      uses: analyzer.extract_uses(ast)
    }

    put_defined_modules(facts, analyzer, ast, run_context)
  end

  # DND-1269: the modules code in the file can be attributed to, for
  # `RuleCoverage.missing_allowed_callers/2`.
  defp put_defined_modules(facts, analyzer, ast, %{defined_modules?: true}),
    do: Map.put(facts, :defined_modules, analyzer.defined_modules(ast))

  defp put_defined_modules(facts, _analyzer, _ast, _run_context), do: facts

  # `{modules_map, crashes}`: the graph, and, by filename, the violation for a
  # file whose graph nodes crashed (DND-1310), reported on that file.
  defp build_modules_map(check_module, analyzer, source_files) do
    if check_module.needs_module_graph?() do
      Enum.reduce(source_files, {%{}, %{}}, &put_module_analyses(check_module, analyzer, &1, &2))
    else
      {%{}, %{}}
    end
  end

  # An unparseable file contributes no modules to the graph; it is reported on
  # its own (see `result_for_parse/3`). Neither does a file whose analysis
  # crashed; its crash is reported on it.
  defp put_module_analyses(check_module, analyzer, source_file, {graph, crashes}) do
    with {:ok, ast} <- Source.ast(source_file),
         {:ok, nodes} <- guarded(check_module, fn -> analyzer.module_dependencies(ast) end) do
      {Enum.into(nodes, graph), crashes}
    else
      {:error, _parse_error} -> {graph, crashes}
      {:crashed, violation} -> {graph, Map.put(crashes, source_file.filename, violation)}
    end
  end
end
