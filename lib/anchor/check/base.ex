defmodule Anchor.Check.Base do
  @moduledoc """
  Base functionality for Anchor checks.
  """

  defmacro __using__(opts) do
    quote do
      use Credo.Check, unquote(opts)

      import Credo.Check

      alias Anchor.Config
      alias Anchor.DependencyAnalyzer

      @impl true
      def run_on_all_source_files(exec, source_files, params) do
        case Config.load() do
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
        rules
        |> Enum.filter(&rule_matches_type?/1)
        |> Enum.filter(&rule_matches_file?(&1, source_file))
      end

      defp rule_matches_type?(rule), do: rule.type == rule_type()

      defp rule_matches_file?(%{paths: paths, recursive: recursive}, source_file)
           when is_list(paths) do
        file_path = source_file.filename

        Enum.any?(paths, fn pattern ->
          if recursive do
            matches_recursive_pattern?(file_path, pattern)
          else
            matches_pattern?(file_path, pattern)
          end
        end)
      end

      defp rule_matches_file?(%{pattern: pattern}, source_file) when is_binary(pattern) do
        module_name =
          source_file
          |> Credo.Code.ast()
          |> DependencyAnalyzer.extract_module_name()
          |> to_string()

        matches_module_pattern?(module_name, pattern)
      end

      defp rule_matches_file?(%{uses_module: uses_module}, source_file) when is_binary(uses_module) do
        ast = Credo.Code.ast(source_file)
        
        uses_module
        |> Module.concat([])
        |> then(&DependencyAnalyzer.has_use?(ast, &1))
      end

      defp rule_matches_file?(_, _), do: false

      defp matches_pattern?(path, pattern) do
        regex = pattern_to_regex(pattern)
        Regex.match?(regex, path)
      end

      defp matches_recursive_pattern?(path, pattern) do
        # Handle ** glob patterns correctly
        # ** should match zero or more directories
        regex_pattern =
          pattern
          |> String.replace(".", "\\.")
          |> String.replace("**/*", "**")  # Convert **/* to just ** for simpler handling
          |> String.replace("**/", "**")   # Convert **/ to just ** for simpler handling
          |> String.replace("**", "(.*)?")  # ** matches zero or more path segments
          |> String.replace("*", "[^/]*")  # * matches within a single path segment
          |> then(&"^#{&1}$")
          |> Regex.compile!()

        Regex.match?(regex_pattern, path)
      end

      defp matches_module_pattern?(module_name, pattern) do
        regex = module_pattern_to_regex(pattern)
        Regex.match?(regex, module_name)
      end

      defp pattern_to_regex(pattern) do
        pattern
        |> String.replace(".", "\\.")
        |> String.replace("*", "[^/]*")
        |> then(&"^#{&1}$")
        |> Regex.compile!()
      end

      defp module_pattern_to_regex(pattern) do
        pattern
        |> String.replace(".", "\\.")
        |> String.replace("*", ".*")
        |> then(&"^#{&1}$")
        |> Regex.compile!()
      end

      # To be implemented by specific checks
      def rule_type, do: raise("rule_type/0 must be implemented")
      def check_file(_source_file, _rules, _params), do: raise("check_file/3 must be implemented")

      defoverridable rule_type: 0, check_file: 3
    end
  end
end
