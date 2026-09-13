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

  On a config-load failure it returns `{:error, reason}` so the Framework can
  skip the check without breaking the Credo run.

  ## AST acquisition (interim)

  Acquisition currently calls `Credo.Code.ast/1` directly here at the framework
  edge, mirroring what `Anchor.Check.Base` did before this refactor. The pure
  Domain selection call (`RuleMatching`, and `GlobPattern` beneath it) receives
  only a plain facts map — no Credo types. Turning acquisition into a proper port
  (`Anchor.Domain.DependencyAnalyzer` + an AST-acquisition boundary) is T5's job,
  built on top of this Manager.
  """

  alias Anchor.Adapters.ConfigFile
  alias Anchor.Config
  alias Anchor.DependencyAnalyzer
  alias Anchor.Domain.RuleMatching

  @default_config_loader ConfigFile

  @type result ::
          {:ok, [{Credo.SourceFile.t(), [Anchor.Domain.Violation.t()]}]} | {:error, term()}

  @doc """
  Runs `check_module` over `source_files`, returning per-file violations.

  `params` are the Credo check params, threaded through to the check's detection.
  `opts` accepts `:config_loader` — a module implementing
  `Anchor.Adapters.ConfigLoader` — to inject a mock in tests; it defaults to the
  real `Anchor.Adapters.ConfigFile`.
  """
  @spec run(module(), [Credo.SourceFile.t()], keyword(), keyword()) :: result()
  def run(check_module, source_files, params, opts \\ []) do
    config_loader = Keyword.get(opts, :config_loader, @default_config_loader)

    case config_loader.load() do
      {:ok, %Config{rules: rules}} ->
        modules_map = build_modules_map(check_module, source_files)

        results =
          Enum.map(source_files, &detect_for_file(check_module, &1, rules, modules_map, params))

        {:ok, results}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp detect_for_file(check_module, source_file, rules, modules_map, params) do
    ast = Credo.Code.ast(source_file)
    matching_rules = matching_rules(check_module, source_file, ast, rules)
    violations = detect(check_module, source_file, ast, matching_rules, modules_map, params)
    {source_file, violations}
  end

  defp detect(_check_module, _source_file, _ast, [], _modules_map, _params), do: []

  defp detect(check_module, source_file, ast, matching_rules, modules_map, params) do
    context = %{modules_map: modules_map, params: params}
    check_module.detect_violations(source_file, ast, matching_rules, context)
  end

  defp matching_rules(check_module, source_file, ast, rules) do
    facts = file_facts(source_file, ast)
    rule_type = check_module.rule_type()

    rules
    |> Enum.filter(&RuleMatching.rule_matches_type?(&1, rule_type))
    |> Enum.filter(&RuleMatching.rule_matches_file?(&1, facts))
  end

  defp file_facts(source_file, ast) do
    %{
      filename: source_file.filename,
      module_names: [to_string(DependencyAnalyzer.extract_module_name(ast))],
      uses: DependencyAnalyzer.extract_uses(ast)
    }
  end

  defp build_modules_map(check_module, source_files) do
    if check_module.needs_module_graph?() do
      Enum.reduce(source_files, %{}, &put_module_analysis/2)
    else
      %{}
    end
  end

  defp put_module_analysis(source_file, acc) do
    analysis = DependencyAnalyzer.analyze_file(source_file)

    if analysis.module do
      Map.put(acc, analysis.module, analysis)
    else
      acc
    end
  end
end
