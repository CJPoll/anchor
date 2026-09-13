defmodule Anchor.Check.Base do
  @moduledoc """
  Base functionality for Anchor checks.
  """

  defmacro __using__(opts) do
    quote do
      use Credo.Check, unquote(opts)

      import Credo.Check

      alias Anchor.Adapters.ConfigFile
      alias Anchor.Config
      alias Anchor.DependencyAnalyzer
      alias Anchor.Domain.RuleMatching

      @impl true
      def run_on_all_source_files(exec, source_files, params) do
        case ConfigFile.load() do
          {:ok, config} ->
            issues =
              source_files
              |> Enum.flat_map(&process_file(&1, config, params))

            exec
            |> Credo.Execution.ExecutionIssues.append(issues)

          {:error, _reason} ->
            # If config loading fails, we don't want to break the Credo run
            # Just skip our checks
            exec
        end
      end

      defp process_file(source_file, config, params) do
        matching_rules = find_matching_rules(source_file, config)

        if Enum.empty?(matching_rules) do
          []
        else
          check_file(source_file, matching_rules, params)
        end
      end

      defp find_matching_rules(source_file, %Config{rules: rules}) do
        facts = file_facts(source_file)

        rules
        |> Enum.filter(&RuleMatching.rule_matches_type?(&1, rule_type()))
        |> Enum.filter(&RuleMatching.rule_matches_file?(&1, facts))
      end

      # Derives the pure facts the Domain rule-selection predicate operates on.
      # The module-name derivation intentionally mirrors the historical behavior
      # (Credo.Code.ast/1 returns an {:ok, ast} tuple, so extract_module_name/1
      # resolves to nil -> "") so this refactor changes nothing observable; the
      # fact-derivation fix is a separate ticket.
      defp file_facts(source_file) do
        ast = Credo.Code.ast(source_file)

        %{
          filename: source_file.filename,
          module_names: [to_string(DependencyAnalyzer.extract_module_name(ast))],
          uses: DependencyAnalyzer.extract_uses(ast)
        }
      end

      # To be implemented by specific checks
      def rule_type, do: raise("rule_type/0 must be implemented")
      def check_file(_source_file, _rules, _params), do: raise("check_file/3 must be implemented")

      defoverridable rule_type: 0, check_file: 3
    end
  end
end
