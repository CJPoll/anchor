defmodule Anchor.Managers.AstBaseline do
  @moduledoc """
  `mix anchor.baseline`'s use cases (DND-5632), the **Manager** (ADR 001): it
  orchestrates the config, baseline-file, git and Credo ports with the pure
  ratchet (`Anchor.Domain.Baseline`, `Anchor.Domain.BaselineBase`).

  An ast rule's findings are compared with its baseline by its Credo check
  (`Anchor.Managers.Lint`): held, NEW and STALE. Two things that comparison
  cannot do live here:

    * `write/2` creates an ast rule's baseline from its current findings. It
      only creates: an existing file is refused before Credo runs, and one
      that appears before the write is refused by the store. A rule whose
      check Credo does not run has no findings to write, so it is COULD NOT
      MEASURE, never an empty file.
    * `grew/2` fails every entry the branch added to an ast rule's baseline
      since `ref` (GREW), finding the base copy by the rule's id in the
      config at `ref`, as `mix anchor.graph --base` does for a graph rule
      (DND-5629). A first landing is a report-only note; a read that fails is
      an issue, never "no growth".

  Each returns `%{violations, baselines, exit_code}`: 0 pass, 1 a GREW entry
  or an issue, 2 a refused write, 3 COULD NOT MEASURE.

  Options (adapters, injectable for tests): `:config_loader`
  (`Anchor.Adapters.ConfigFile`), `:baseline_store`
  (`Anchor.Adapters.BaselineFile`), `:git_base` (`Anchor.Adapters.GitShow`),
  `:lint_keys` (`Anchor.Adapters.CredoKeys`).
  """

  alias Anchor.Adapters.BaselineFile
  alias Anchor.Adapters.ConfigFile
  alias Anchor.Adapters.CredoKeys
  alias Anchor.Adapters.GitShow
  alias Anchor.Config
  alias Anchor.Domain.AstBaseline
  alias Anchor.Domain.Baseline
  alias Anchor.Domain.BaselineBase
  alias Anchor.Domain.Failures
  alias Anchor.Domain.RuleSchema
  alias Anchor.Domain.Violation

  @config_file ".anchor.yml"

  @type report :: %{
          violations: [Violation.t()],
          baselines: non_neg_integer(),
          exit_code: 0..3
        }

  @doc "Creates rule `id`'s baseline from its current findings; see the moduledoc."
  @spec write(%{root: Path.t(), id: String.t()}, keyword()) :: report()
  def write(%{root: root, id: id}, opts \\ []) do
    deps = deps(opts)

    with {:ok, config} <- load_config(deps.config_loader),
         {:ok, rule} <- write_target(config, id, root),
         :ok <- absent(deps.baseline_store, root, rule),
         {:ok, keys} <- rule_keys(deps.lint_keys, rule, config_path(config, root)) do
      create(deps.baseline_store, root, rule, keys)
    end
  end

  @doc "Judges GREW for every ast rule's baseline against `ref`; see the moduledoc."
  @spec grew(%{root: Path.t(), ref: String.t()}, keyword()) :: report()
  def grew(%{root: root, ref: ref}, opts \\ []) do
    deps = deps(opts)

    case load_config(deps.config_loader) do
      {:ok, config} -> judge_grew(ast_baselined(config.rules), config, root, ref, deps)
      report -> report
    end
  end

  defp deps(opts) do
    %{
      config_loader: Keyword.get(opts, :config_loader, ConfigFile),
      baseline_store: Keyword.get(opts, :baseline_store, BaselineFile),
      git_base: Keyword.get(opts, :git_base, GitShow),
      lint_keys: Keyword.get(opts, :lint_keys, CredoKeys)
    }
  end

  defp load_config(loader) do
    case loader.load() do
      {:ok, %Config{} = config} -> {:ok, config}
      {:error, reason} -> report([Failures.config_violation(reason)], 0, 3)
    end
  end

  defp ast_baselined(rules) do
    Enum.filter(rules, fn rule ->
      is_binary(Map.get(rule, :baseline)) and RuleSchema.engine(rule.type) == :ast
    end)
  end

  defp write_target(config, id, root) do
    case Enum.find(ast_baselined(config.rules), &(&1.id == id)) do
      nil -> report([Failures.ast_write_unknown(id, config_path(config, root))], 0, 2)
      rule -> {:ok, rule}
    end
  end

  defp absent(store, root, %{baseline: path}) do
    case store.read(root, path) do
      {:ok, _entries} -> report([Failures.ast_baseline_exists(path)], 1, 2)
      {:error, _absent_or_unreadable} -> :ok
    end
  end

  # The rule's keys, once its check is known to have judged it: with its
  # baseline absent, a check that ran names the rule on the issue it raises
  # for the missing file, so a rule no check names had no findings collected.
  defp rule_keys(lint_keys, rule, config_file) do
    case lint_keys.keys() do
      {:ok, %{keys: keys, rule_ids: ids}} ->
        if rule.id in ids,
          do: {:ok, for({id, key} <- keys, id == rule.id, do: key)},
          else: report([Failures.ast_check_not_enabled(rule, config_file)], 1, 3)

      {:error, reason} ->
        report([Failures.ast_credo_halted(reason, config_file)], 1, 3)
    end
  end

  defp create(store, root, %{id: id, baseline: path}, keys) do
    case store.create(root, path, Baseline.render(id, keys)) do
      :ok -> report([note(Failures.baseline_written(path, length(keys)))], 1, 0)
      {:error, :exists} -> report([Failures.ast_baseline_exists(path)], 1, 2)
      {:error, reason} -> report([Failures.baseline_not_written(path, reason)], 1, 1)
    end
  end

  defp judge_grew([], _config, _root, _ref, _deps), do: report([], 0, nil)

  defp judge_grew(rules, config, root, ref, deps) do
    config_file = config_path(config, root)
    base = base_rules(deps.git_base, root, ref, config_file)

    {violations, unjudged} =
      Enum.reduce(rules, {[], []}, fn rule, {violations, unjudged} ->
        # Every rule of the config, graph rules too: a rule "gone" since the
        # ref is one no rule of this config has the id of.
        case rule_grew(rule, base, config.rules, root, ref, deps) do
          :unjudged -> {violations, unjudged ++ [rule.id]}
          found -> {violations ++ found, unjudged}
        end
      end)

    report(violations ++ base_config_issue(base, config_file, ref, unjudged), length(rules), nil)
  end

  defp base_rules(git, root, ref, config_file) do
    case git.rules(root, ref, config_file) do
      {:ok, rules} -> {:ok, rules}
      {:error, :absent} -> {:ok, :absent}
      {:error, reason} -> {:unreadable, reason}
    end
  end

  defp base_config_issue(_base, _config_file, _ref, []), do: []

  defp base_config_issue({:unreadable, reason}, config_file, ref, ids),
    do: [Failures.baseline_base_config_unreadable(config_file, ref, reason, ids)]

  defp rule_grew(%{baseline: path} = rule, base, config_rules, root, ref, deps) do
    case deps.baseline_store.read(root, path) do
      {:ok, entries} -> compare(rule, entries, base, config_rules, root, ref, deps)
      {:error, reason} -> [Failures.ast_baseline_unreadable(rule, path, reason)]
    end
  end

  defp compare(_rule, _entries, {:unreadable, _reason}, _config_rules, _root, _ref, _deps),
    do: :unjudged

  defp compare(
         %{id: id, baseline: path} = rule,
         entries,
         {:ok, base},
         config_rules,
         root,
         ref,
         deps
       ) do
    case BaselineBase.locate(base, id) do
      :new_rule ->
        [note(Failures.baseline_new_rule(path, ref, id, BaselineBase.gone(base, config_rules)))]

      :no_baseline ->
        grew_entries(rule, entries, [], ref)

      {:path, base_path} ->
        case deps.git_base.show(root, ref, base_path) do
          {:ok, base_entries} -> grew_entries(rule, entries, base_entries, ref)
          {:error, :absent} -> [note(Failures.baseline_first_landing(path, ref))]
          {:error, reason} -> [Failures.baseline_base_unreadable(base_path, ref, reason)]
        end
    end
  end

  defp grew_entries(%{baseline: path} = rule, entries, base_entries, ref) do
    enforcement = RuleSchema.enforcement(rule)

    entries
    |> Baseline.grew(base_entries)
    |> Enum.map(
      &(path
        |> Failures.baseline_grew(&1, ref)
        |> Violation.with_enforcement(enforcement))
    )
  end

  defp note(violation), do: Violation.with_enforcement(violation, :report)

  # The config's path relative to the project root: how git names it at a
  # ref, and how an issue on it is printed.
  defp config_path(%Config{path: nil}, _root), do: @config_file

  defp config_path(%Config{path: path}, root) do
    if Path.type(path) == :relative, do: path, else: Path.relative_to(path, root)
  end

  defp report(violations, baselines, nil),
    do: %{
      violations: violations,
      baselines: baselines,
      exit_code: AstBaseline.exit_code(violations)
    }

  defp report(violations, baselines, exit_code),
    do: %{violations: violations, baselines: baselines, exit_code: exit_code}
end
