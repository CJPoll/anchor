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

  alias Anchor.Adapters.BaselineFile
  alias Anchor.Adapters.ConfigFile
  alias Anchor.Check.Source
  alias Anchor.Config
  alias Anchor.Domain.AstBaseline
  alias Anchor.Domain.Baseline
  alias Anchor.Domain.DependencyAnalyzer
  alias Anchor.Domain.EnforcementPasses
  alias Anchor.Domain.Failures
  alias Anchor.Domain.RuleCoverage
  alias Anchor.Domain.RuleMatching
  alias Anchor.Domain.RuleSchema
  alias Anchor.Domain.Violation
  alias Anchor.Domain.ViolationKey

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
          defined_modules?: lists_allowed_callers?(check_module, rules),
          root: Keyword.get_lazy(opts, :root, &File.cwd!/0)
        }

        # Each file is parsed as it is checked and dropped afterwards, so a run
        # never holds every file's AST at once. Only its facts are kept, for the
        # selection floor.
        results = Enum.map(source_files, &result_for_file(&1, run_context))

        file_results =
          Enum.map(results, fn {source_file, violations, _facts} -> {source_file, violations} end)

        facts = Enum.map(results, fn {_source_file, _violations, facts} -> facts end)

        {file_results, ratchet_violations} =
          ratchet(file_results, own_baselined(check_module, rules), facts, run_context, opts)

        # A finding two passes made (two rules forbidding one module, a
        # check's once-per-file `alias` report) is printed once, enforced when
        # either copy is; each baselined rule's keyed copy was judged first,
        # so no copy is lost to its comparison (DND-5632).
        file_results =
          Enum.map(file_results, fn {file, violations} ->
            {file, EnforcementPasses.unique(violations)}
          end)

        {:ok,
         file_results ++ config_results(check_module, config, facts, opts, ratchet_violations)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # DND-1290: the rules that checked nothing in this run, as one `{:config,
  # violations}` entry after the per-file results (none when every rule
  # checked something). Each check reports the floors of its own type's rules,
  # over the files it ran on; the shared-failure reporter also names the rules
  # no enabled check reads.
  defp config_results(check_module, config, facts, opts, ratchet_violations) do
    case floor_violations(check_module, config, facts, opts) ++
           unchecked_violations(config, opts) ++ ratchet_violations do
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
    {baselined, plain} =
      check_module |> matching_rules(facts, rules) |> Enum.split_with(&baselined?/1)

    violations = detect(check_module, source_file, ast, plain, modules_map, facts, params)

    keyed =
      Enum.flat_map(baselined, fn rule ->
        check_module
        |> detect(source_file, ast, [rule], modules_map, facts, params)
        |> keyed(check_module, rule, relative(source_file.filename, run_context.root))
      end)

    {source_file, violations ++ keyed, facts}
  end

  # DND-5632: a rule with a `baseline:` is detected on its own, so each of its
  # findings carries the rule's id and its key (`ViolationKey.ast_key/3`). A
  # key that cannot be built (a file holding `|`) is a crash on the file,
  # reported as one, never escaping the check.
  defp keyed(violations, check_module, rule, file) do
    case guarded(check_module, fn -> Enum.map(violations, &key(&1, rule, file)) end) do
      {:ok, keyed} -> keyed
      {:crashed, violation} -> [violation]
    end
  end

  defp key(%Violation{kind: :rule, filename: nil} = violation, rule, file),
    do: %{violation | rule_id: rule.id, key: ViolationKey.ast_key(rule, file, violation.trigger)}

  defp key(violation, _rule, _file), do: violation

  defp baselined?(rule), do: is_binary(Map.get(rule, :baseline))

  defp own_baselined(check_module, rules),
    do: check_module |> own_rules(rules) |> Enum.filter(&baselined?/1)

  # A file's path relative to the project root, as an ast key names it.
  defp relative(filename, root), do: filename |> Path.expand(root) |> Path.relative_to(root)

  # DND-5632: each of this check's rules with a `baseline:` has its findings
  # compared with the file (`AstBaseline.judge/4`): held ones are dropped,
  # NEW ones stand, and STALE entries are findings on the baseline path. A
  # run that read only some files judges only the entries on files it read,
  # and says how many it did not. A baseline that cannot be read, or holds
  # another rule's entry, is one fail-closed issue, and every finding stands.
  defp ratchet(file_results, [], _facts, _run_context, _opts), do: {file_results, []}

  defp ratchet(file_results, rules, facts, run_context, opts) do
    store = Keyword.get(opts, :baseline_store, BaselineFile)
    scope = scope(facts, run_context.root, Keyword.get(opts, :enforce_selection_floors, true))

    Enum.reduce(rules, {file_results, []}, fn rule, {results, extra} ->
      case read_entries(store, run_context.root, rule) do
        {:ok, entries} ->
          {held, findings} = judge_rule(rule, entries, results, scope)
          {drop_held(results, rule.id, held), extra ++ name_rule(findings, rule)}

        {:fail, violation} ->
          {results, extra ++ name_rule([violation], rule)}
      end
    end)
  end

  # Each baseline issue names its rule, so `mix anchor.baseline --write`
  # can tell the rule's check ran.
  defp name_rule(violations, rule), do: Enum.map(violations, &%{&1 | rule_id: rule.id})

  defp read_entries(store, root, %{baseline: path} = rule) do
    case store.read(root, path) do
      {:ok, entries} ->
        case Baseline.foreign(rule.id, entries) do
          [] -> {:ok, entries}
          [entry | _rest] -> {:fail, Failures.baseline_foreign(rule, path, entry)}
        end

      {:error, reason} ->
        {:fail, Failures.ast_baseline_unreadable(rule, path, reason)}
    end
  end

  defp judge_rule(%{baseline: path} = rule, entries, results, scope) do
    keys =
      for {_file, violations} <- results,
          %{rule_id: id, key: key} <- violations,
          id == rule.id and is_binary(key),
          do: key

    %{held: held, stale: stale, unjudged: unjudged} =
      AstBaseline.judge(rule.id, keys, entries, scope)

    enforcement = RuleSchema.enforcement(rule)
    stale = Enum.map(stale, &%{Failures.baseline_stale(path, &1) | enforcement: enforcement})

    {held, stale ++ unjudged_note(path, unjudged)}
  end

  defp unjudged_note(_path, []), do: []
  defp unjudged_note(path, unjudged), do: [Failures.ast_baseline_unjudged(path, unjudged)]

  # The findings of `rule_id` whose keys are among `held` (a multiset) are
  # dropped, in file order.
  defp drop_held(results, rule_id, held) do
    {results, _left} =
      Enum.map_reduce(results, Enum.frequencies(held), fn {file, violations}, left ->
        {kept, left} = Enum.flat_map_reduce(violations, left, &hold(&1, &2, rule_id))
        {{file, kept}, left}
      end)

    results
  end

  defp hold(%Violation{rule_id: rule_id, key: key} = violation, left, rule_id) do
    case Map.get(left, key, 0) do
      0 -> {[violation], left}
      n -> {[], Map.put(left, key, n - 1)}
    end
  end

  defp hold(violation, left, _rule_id), do: {[violation], left}

  defp scope(facts, root, whole?) do
    files = fn keep? ->
      for %{filename: file} = fact <- facts,
          keep?.(fact),
          into: MapSet.new(),
          do: relative(file, root)
    end

    %{
      whole?: whole?,
      read: files.(fn _fact -> true end),
      unparsed: files.(&(&1[:parsed?] == false))
    }
  end

  defp detect(_check_module, _source_file, _ast, [], _modules_map, _facts, _params), do: []

  defp detect(check_module, source_file, ast, matching_rules, modules_map, facts, params) do
    context = %{modules_map: modules_map, params: params, module_names: facts.module_names}
    detect_file(check_module, source_file, ast, matching_rules, context)
  end

  @doc """
  Runs `check_module`'s detection on one parsed file with the rules already
  selected for it, and returns the violations. The findings of rules in
  `enforcement: report` are marked `:report` (DND-5441). A violation both
  passes found (one a check makes once per file, such as an unresolvable
  `alias`) is returned once, enforced, naming both modes
  (`Anchor.Domain.EnforcementPasses.merge/2`, DND-5631).

  A raise, throw or exit in the detection becomes one `:fail_closed` violation
  on that file, naming the check and the reason (DND-1310,
  `Anchor.Domain.Failures.analysis_crash_violation/4`). It never escapes: Credo's
  runner would either abort the whole run on it or, with `crash_on_error:
  false`, drop every issue the check found, which reads as a pass.
  """
  @spec detect_file(module(), Credo.SourceFile.t(), Macro.t(), [map()], map()) ::
          [Anchor.Domain.Violation.t()]
  def detect_file(check_module, source_file, ast, rules, context) do
    case Enum.split_with(rules, &(RuleSchema.enforcement(&1) == :report)) do
      {[], _enforce} ->
        detect_group(check_module, source_file, ast, rules, context)

      {report, enforce} ->
        EnforcementPasses.merge(
          detect_some(check_module, source_file, ast, enforce, context),
          check_module
          |> detect_group(source_file, ast, report, context)
          |> Enum.map(&report_only/1)
        )
    end
  end

  # DND-5441: the rules in `enforcement: report` are detected apart from the
  # enforced ones, and their findings marked `:report` (printed, never
  # failing). With no report rule (the default) this is one detection call
  # over every rule, as before. A crash stays a fail-closed violation.
  defp detect_some(_check_module, _source_file, _ast, [], _context), do: []

  defp detect_some(check_module, source_file, ast, rules, context),
    do: detect_group(check_module, source_file, ast, rules, context)

  defp detect_group(check_module, source_file, ast, rules, context) do
    case guarded(check_module, fn ->
           check_module.detect_violations(source_file, ast, rules, context)
         end) do
      {:ok, violations} -> violations
      {:crashed, violation} -> [violation]
    end
  end

  defp report_only(%Violation{kind: :rule} = violation), do: %{violation | enforcement: :report}
  defp report_only(violation), do: violation

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
