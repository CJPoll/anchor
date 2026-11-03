defmodule Mix.Tasks.Anchor.Sabotage do
  @shortdoc "Generated sabotage: scope, run and restore"

  @moduledoc """
  Generated sabotage for the functions a change touched, the **Framework**
  entry point (ADR 001). It parses arguments, makes one
  `Anchor.Managers.Sabotage` call, renders the result and exits; it calls no
  adapter itself.

  ## scope (DND-5472)

      mix anchor.sabotage scope [--base REF] [--format text|json]

  Prints the functions the working tree changed (committed, staged, unstaged
  and untracked `.ex` files) relative to the merge-base of `REF` (default
  `origin/main`) and `HEAD`: one TSV line per function
  (`file, module, name/arity, kind, changed line ranges`), then a summary that
  counts everything left out (test files, non-source files, deleted files,
  hunks outside a function, macros). It reads git and source files only: no
  compile, and no project code runs.

  Exit codes: 0 measured (a clean diff prints `0 functions`); 2 usage;
  3 `COULD NOT MEASURE` with a `Fix:` line (not a git work tree, `REF`
  unresolvable or no merge-base, git failing, a changed `.ex` file that does
  not parse or cannot be read).

  ## run and restore (DND-5473)

      mix anchor.sabotage run [--base REF] [--max N|all] [--only ID]... [--dry-run]
      mix anchor.sabotage restore

  `run` applies the mutants of the changed functions one at a time, runs only
  each one's selected tests (bounded by `timeout_seconds`), restores the file
  after each, and prints a line per mutant and a summary
  (`Anchor.Domain.Sabotage.Report`). `--max` overrides the `max_mutants` cap
  (`--max all` lifts it, for CI); `--only` runs the named mutant ids;
  `--dry-run` prints the plan and writes nothing. `restore` puts back a file a
  killed run left mutated (`.anchor/sabotage/in-flight.json`).

  Exit codes (DND-5570): 0 every measured mutant was killed or timed out (an
  invalid one, which did not compile, is listed and counted and changes
  nothing), or there was no changed function (a good diff read that found none
  prints `sabotage: 0 changed functions in REF..HEAD`); 1 a mutant survived,
  crashed or had no test, beside a measured one; 2 a refusal or a usage error
  (a dirty target file, the journal not git-ignored, a journal that cannot be
  restored safely, a host with no `/proc`, bad flags); 3 `COULD NOT MEASURE` (no loadable `sabotage:`
  config, the baseline tests fail, the changed functions' files cannot be
  read, or mutants were run and none was measured: all invalid, crashed or
  without a test).
  """

  use Mix.Task

  alias Anchor.Domain.Failures
  alias Anchor.Domain.Sabotage.Report
  alias Anchor.Domain.Sabotage.Scope
  alias Anchor.Managers.Sabotage

  @default_base "origin/main"
  @usage """
  Usage: mix anchor.sabotage scope [--base REF] [--format text|json]
         mix anchor.sabotage run [--base REF] [--max N|all] [--only ID]... [--dry-run]
         mix anchor.sabotage restore
  Fix: use one of these forms; --max takes a positive integer or `all`\
  """

  @impl Mix.Task
  def run(argv), do: run(argv, [])

  @doc """
  Runs the task with `opts` passed to the Manager (tests inject
  `change_source:` here).
  """
  @spec run([String.t()], keyword()) :: :ok
  def run(["scope" | argv], opts) do
    case OptionParser.parse(argv, strict: [base: :string, format: :string]) do
      {parsed, [], []} ->
        scope(Keyword.get(parsed, :base, @default_base), format(parsed[:format]), opts)

      _invalid ->
        usage()
    end
  end

  def run(["run" | argv], opts) do
    switches = [base: :string, max: :string, only: :keep, dry_run: :boolean]

    with {parsed, [], []} <- OptionParser.parse(argv, strict: switches),
         {:ok, max} <- max(parsed[:max]) do
      facts = %{
        root: File.cwd!(),
        env: Mix.env(),
        base: Keyword.get(parsed, :base, @default_base),
        max: max,
        only: Keyword.get_values(parsed, :only),
        dry_run: Keyword.get(parsed, :dry_run, false)
      }

      report(Sabotage.run(facts, opts))
    else
      _invalid -> usage()
    end
  end

  def run(["restore"], opts), do: report(Sabotage.restore(%{root: File.cwd!()}, opts))

  def run(_argv, _opts), do: usage()

  defp max(nil), do: {:ok, nil}
  defp max("all"), do: {:ok, :all}

  defp max(text) do
    case Integer.parse(text) do
      {n, ""} when n > 0 -> {:ok, n}
      _other -> :error
    end
  end

  defp report(run) do
    Mix.shell().info(Report.render(run))

    case Report.exit_code(run) do
      0 -> :ok
      code -> exit({:shutdown, code})
    end
  end

  defp scope(_base, :invalid, _opts), do: usage()

  defp scope(base, format, opts) do
    case Sabotage.scope(%{root: File.cwd!(), base: base}, opts) do
      {:ok, result} ->
        Mix.shell().info(Scope.render(result, format))

      {:error, reason} ->
        Mix.shell().error(Failures.scope_could_not_measure(reason))
        exit({:shutdown, 3})
    end
  end

  defp format(nil), do: :text
  defp format("text"), do: :text
  defp format("json"), do: :json
  defp format(_other), do: :invalid

  defp usage do
    Mix.shell().error(@usage)
    exit({:shutdown, 2})
  end
end
