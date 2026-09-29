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

  ## Failing closed (DND-1265)

  A run that could not check something reports it as a Credo issue carrying a
  `Fix:` line; it never reads as a run that found nothing. Two failures are not
  specific to any one check: a missing or invalid `.anchor.yml` (the Manager's
  `{:error, reason}`), and a source file that does not parse. Each is reported
  once per run, by the run's **shared-failure reporter**
  (`shared_failure_reporter?/2`): the first enabled Anchor check in the list
  Credo's runner iterates. Every other Anchor check stays quiet about them. These
  issues are raised to `:higher` priority, so Credo shows them without
  `--strict`.
  """

  @doc """
  Returns `true` when `check` reports the run's shared failures.

  That is the first Anchor check in the check list Credo's runner iterates
  (`Credo.Execution.checks/1`, which applies `--checks` / `--ignore-checks`),
  skipping a check disabled with `false` params. When `check` is not in that
  list at all — an execution with no check list, or a check run directly
  outside Credo's runner — it returns `true`, because no other check will make
  the report. The rule errs toward reporting twice, never toward not reporting.
  """
  @spec shared_failure_reporter?(Credo.Execution.t(), module()) :: boolean()
  def shared_failure_reporter?(exec, check) do
    {checks, _only, _ignored} = Credo.Execution.checks(exec)

    case Enum.flat_map(checks, &enabled_anchor_check/1) do
      [^check | _rest] -> true
      listed -> check not in listed
    end
  end

  # A check tuple is `{module, params}`, or `{module}` in Credo's older notation.
  defp enabled_anchor_check({_module, false}), do: []
  defp enabled_anchor_check({module, _params}), do: anchor_check(module)
  defp enabled_anchor_check({module}), do: anchor_check(module)

  defp anchor_check(module) do
    if Code.ensure_loaded?(module) and function_exported?(module, :__anchor_check__, 0),
      do: [module],
      else: []
  end

  defmacro __using__(opts) do
    quote do
      use Credo.Check, unquote(opts)

      import Credo.Check

      alias Anchor.Check.Source
      alias Anchor.Domain.DependencyAnalyzer
      alias Anchor.Domain.Failures
      alias Anchor.Domain.Violation
      alias Anchor.Managers.Lint

      @fail_closed_priority Credo.Priority.to_integer(:higher)

      @doc false
      def __anchor_check__, do: true

      @impl true
      def run_on_all_source_files(exec, source_files, params) do
        reporter? = Anchor.Check.Base.shared_failure_reporter?(exec, __MODULE__)

        issues =
          case Lint.run(__MODULE__, source_files, params, report_shared_failures: reporter?) do
            {:ok, results} ->
              Enum.flat_map(results, fn {source_file, violations} ->
                violations_to_issues(source_file, violations)
              end)

            {:error, reason} ->
              config_failure_issues(reason, reporter?)
          end

        Credo.Execution.ExecutionIssues.append(exec, issues)
        :ok
      end

      # Backward-compatible direct entry point. The per-check characterization
      # tests call `check_file/3` with a hand-built rule list and assert on the
      # returned `[%Credo.Issue{}]`. It routes through the same Domain detection
      # the Manager uses and maps the resulting violations to issues, so the
      # output is identical to the pre-refactor behavior. Config loading and rule
      # SELECTION are deliberately NOT exercised here — that path belongs to the
      # Manager; the caller passes the already-selected rules, exactly as the old
      # `check_file/3` was called. A file that does not parse is reported
      # (DND-1265), never checked as if it were empty.
      def check_file(source_file, rules, params) do
        case Source.ast(source_file) do
          {:ok, ast} ->
            context = %{modules_map: %{}, params: params}

            source_file
            |> detect_violations(ast, rules, context)
            |> then(&violations_to_issues(source_file, &1))

          {:error, {line, message}} ->
            violations_to_issues(source_file, [Failures.unparseable_violation(line, message)])
        end
      end

      defp config_failure_issues(_reason, false), do: []

      defp config_failure_issues(reason, true) do
        violation = Failures.config_violation(reason)
        violations_to_issues(%Credo.SourceFile{filename: violation.filename}, [violation])
      end

      defp violations_to_issues(source_file, violations) do
        Enum.map(violations, fn %Violation{} = violation ->
          format_issue(issue_source_file(source_file, violation), issue_opts(violation))
        end)
      end

      # A violation that names its own file (a config failure) sits on that
      # file, not on the source file the check ran on.
      defp issue_source_file(source_file, %Violation{filename: nil}), do: source_file

      defp issue_source_file(_source_file, %Violation{filename: filename}) do
        %Credo.SourceFile{filename: filename}
      end

      defp issue_opts(%Violation{kind: :fail_closed} = violation) do
        [priority: @fail_closed_priority] ++ rule_issue_opts(violation)
      end

      defp issue_opts(violation), do: rule_issue_opts(violation)

      defp rule_issue_opts(violation) do
        [message: violation.message, line_no: violation.line, trigger: violation.trigger]
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
