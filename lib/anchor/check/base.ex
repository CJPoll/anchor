defmodule Anchor.Check.Base do
  @moduledoc """
  Base functionality for Anchor checks — the thin **Framework** layer (ADR 001).

  A check `use`s this module to become a `Credo.Check`. The generated
  `run_on_all_source_files/3` does no orchestration itself: it hands the work to
  `Anchor.Managers.Lint` (the Manager, the only module allowed to call both the
  config adapter and Domain) and maps the `%Anchor.Domain.Violation{}` structs it
  gets back onto `Credo.Issue`s via `format_issue/2`. That mapping — the Credo
  category, priority, and other check metadata — is the only framework concern
  left here; loading config, building the module graph, acquiring ASTs, and
  selecting rules all live in the Manager now.

  A check provides:

    * `rule_type/0` — the `.anchor.yml` rule `type` this check consumes.
    * `detect_violations/4` — `(source_file, ast, rules, context)` returning a
      list of `%Anchor.Domain.Violation{}`; the check's Domain detection, called
      by the Manager with the already-selected rules for that file.
    * optionally `needs_module_graph?/0` — override to `true` when detection
      needs the cross-file dependency graph (delivered in `context.modules_map`).
  """

  defmacro __using__(opts) do
    quote do
      use Credo.Check, unquote(opts)

      import Credo.Check

      alias Anchor.DependencyAnalyzer
      alias Anchor.Domain.Violation
      alias Anchor.Managers.Lint

      @impl true
      def run_on_all_source_files(exec, source_files, params) do
        case Lint.run(__MODULE__, source_files, params) do
          {:ok, results} ->
            issues =
              Enum.flat_map(results, fn {source_file, violations} ->
                violations_to_issues(source_file, violations)
              end)

            Credo.Execution.ExecutionIssues.append(exec, issues)

          {:error, _reason} ->
            # If config loading fails, we don't want to break the Credo run.
            # Just skip our checks.
            exec
        end
      end

      # Backward-compatible direct entry point. The per-check characterization
      # tests call `check_file/3` with a hand-built rule list and assert on the
      # returned `[%Credo.Issue{}]`. It routes through the same Domain detection
      # the Manager uses and maps the resulting violations to issues, so the
      # output is identical to the pre-refactor behavior. Config loading and rule
      # SELECTION are deliberately NOT exercised here — that path belongs to the
      # Manager; the caller passes the already-selected rules, exactly as the old
      # `check_file/3` was called.
      def check_file(source_file, rules, params) do
        ast = Credo.Code.ast(source_file)
        context = %{modules_map: %{}, params: params}

        source_file
        |> detect_violations(ast, rules, context)
        |> then(&violations_to_issues(source_file, &1))
      end

      defp violations_to_issues(source_file, violations) do
        Enum.map(violations, fn %Violation{} = violation ->
          format_issue(
            source_file,
            message: violation.message,
            line_no: violation.line,
            trigger: violation.trigger
          )
        end)
      end

      @doc false
      def needs_module_graph?, do: false

      # To be implemented by specific checks.
      def rule_type, do: raise("rule_type/0 must be implemented")

      def detect_violations(_source_file, _ast, _rules, _context) do
        raise("detect_violations/4 must be implemented")
      end

      defoverridable rule_type: 0,
                     detect_violations: 4,
                     needs_module_graph?: 0,
                     check_file: 3
    end
  end
end
