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
  alias Anchor.Domain.RuleMatching

  @default_config_loader ConfigFile

  @type result ::
          {:ok, [{Credo.SourceFile.t(), [Anchor.Domain.Violation.t()]}]} | {:error, term()}

  @doc """
  Runs `check_module` over `source_files`, returning per-file violations.

  `params` are the Credo check params, threaded through to the check's detection.
  `opts` accepts `:config_loader` — a module implementing
  `Anchor.Adapters.ConfigLoader` — to inject a mock in tests; it defaults to the
  real `Anchor.Adapters.ConfigFile`. It also accepts `:report_shared_failures`
  (default `true`): whether an unparseable file yields its violation for this
  check.
  """
  @spec run(module(), [Credo.SourceFile.t()], keyword(), keyword()) :: result()
  def run(check_module, source_files, params, opts \\ []) do
    config_loader = Keyword.get(opts, :config_loader, @default_config_loader)
    report_shared_failures? = Keyword.get(opts, :report_shared_failures, true)

    case config_loader.load() do
      {:ok, %Config{rules: rules}} ->
        # Each file is parsed once, here, and the result reused for the module
        # graph and for detection.
        parsed = Enum.map(source_files, &{&1, Source.ast(&1)})
        modules_map = build_modules_map(check_module, parsed)

        results =
          Enum.map(
            parsed,
            &result_for_file(
              &1,
              check_module,
              rules,
              modules_map,
              params,
              report_shared_failures?
            )
          )

        {:ok, results}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # DND-1265: a file Anchor cannot parse is reported, never checked as if it
  # were empty. The report is not specific to this check, so only the run's
  # shared-failure reporter makes it (see `Anchor.Check.Base`); every other
  # check skips the file.
  defp result_for_file(
         {source_file, {:error, {line, message}}},
         _check,
         _rules,
         _map,
         _params,
         true
       ) do
    {source_file, [Failures.unparseable_violation(line, message)]}
  end

  defp result_for_file(
         {source_file, {:error, _parse_error}},
         _check,
         _rules,
         _map,
         _params,
         false
       ) do
    {source_file, []}
  end

  defp result_for_file(
         {source_file, {:ok, ast}},
         check_module,
         rules,
         modules_map,
         params,
         _report?
       ) do
    detect_for_file(check_module, source_file, ast, rules, modules_map, params)
  end

  defp detect_for_file(check_module, source_file, ast, rules, modules_map, params) do
    # Gap F (DND-150): the file's facts (its own module names among them) are
    # computed ONCE here and reused for BOTH rule selection and the check
    # context — no second AST walk. The file's `module_names` are threaded into
    # the check context so `same_context` detection can derive the file's context.
    facts = file_facts(source_file, ast)
    matching_rules = matching_rules(check_module, facts, rules)

    violations =
      detect(check_module, source_file, ast, matching_rules, modules_map, facts, params)

    {source_file, violations}
  end

  defp detect(_check_module, _source_file, _ast, [], _modules_map, _facts, _params), do: []

  defp detect(check_module, source_file, ast, matching_rules, modules_map, facts, params) do
    context = %{modules_map: modules_map, params: params, module_names: facts.module_names}
    check_module.detect_violations(source_file, ast, matching_rules, context)
  end

  defp matching_rules(check_module, facts, rules) do
    rule_type = check_module.rule_type()

    rules
    |> Enum.filter(&RuleMatching.rule_matches_type?(&1, rule_type))
    |> Enum.filter(&RuleMatching.rule_matches_file?(&1, facts))
  end

  defp file_facts(source_file, ast) do
    %{
      filename: source_file.filename,
      module_names: Enum.map(DependencyAnalyzer.extract_module_names(ast), &to_string/1),
      uses: DependencyAnalyzer.extract_uses(ast)
    }
  end

  defp build_modules_map(check_module, parsed) do
    if check_module.needs_module_graph?() do
      Enum.reduce(parsed, %{}, &put_module_analyses/2)
    else
      %{}
    end
  end

  # An unparseable file contributes no modules to the graph; it is reported on
  # its own (see `result_for_file/6`).
  defp put_module_analyses({_source_file, {:error, _parse_error}}, acc), do: acc

  defp put_module_analyses({_source_file, {:ok, ast}}, acc) do
    ast
    |> DependencyAnalyzer.module_dependencies()
    |> Enum.reduce(acc, fn {module, analysis}, acc -> Map.put(acc, module, analysis) end)
  end
end
