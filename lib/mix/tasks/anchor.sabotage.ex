defmodule Mix.Tasks.Anchor.Sabotage do
  @shortdoc "Generated sabotage: scope, run, restore, replay and coverage"

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
                              [--coverage PATH] [--no-record] [--domain D]
                              [--ticket KEY] [--slot S] [--print-survivor-lines]
      mix anchor.sabotage restore

  `run` applies the mutants of the changed functions one at a time, runs only
  each one's selected tests (bounded by `timeout_seconds`), restores the file
  after each, and prints a line per mutant and a summary
  (`Anchor.Domain.Sabotage.Report`). `--max` overrides the `max_mutants` cap
  (`--max all` lifts it, for CI); `--only` runs the named mutant ids;
  `--dry-run` prints the plan and writes nothing. `restore` puts back a file a
  killed run left mutated (`.anchor/sabotage/in-flight.json`). `--coverage
  PATH` (or the config's `coverage_map`) selects each mutant's tests from a
  per-test coverage map (DND-5474) first, then the mirror file; each line says
  which source chose them.

  After the run it writes the sabotage record (DND-5484;
  `Anchor.Domain.Sabotage.Record`), in the repo's naming (`sabotage.records`),
  and names each file it created or appended to. `--no-record` writes none;
  `--domain` overrides the derived domain; `--ticket` and `--slot` override
  the ticket key and the slot read from the branch. The date is read here,
  in UTC, and passed on as a fact.

  The run judges the survivors list (DND-5483,
  `Anchor.Domain.Sabotage.Survivors`): a survivor (or a mutant with no test)
  that is not listed is NEW, a listed mutant now killed or no longer generated
  is STALE, and both fail the run (1); the entries this branch adds against
  `--base` are printed for review. `--print-survivor-lines` prints, at the
  end, the line to add for each NEW survivor, with a placeholder reason to
  replace; it never writes the file.

  Exit codes (DND-5570): 0 every measured mutant was killed or timed out (an
  invalid one, which did not compile, is listed and counted and changes
  nothing), or there was no changed function (a good diff read that found none
  prints `sabotage: 0 changed functions in REF..HEAD`); 1 a mutant survived or
  had no test and is not on the survivors list, a mutant crashed beside a
  measured one, a STALE or malformed survivors entry, or a survivors file
  named in the config that is absent; 2 a refusal or a usage error
  (a dirty target file, the journal not git-ignored, a journal that cannot be
  restored safely, a host with no `/proc`, bad flags, a sabotage record that cannot be
  written when every measured mutant passed: a survivor stays 1 and an
  unmeasured run 3, DND-5641); 3 `COULD NOT MEASURE` (no loadable `sabotage:`
  config, the baseline tests fail, the changed functions' files cannot be
  read, or mutants were run and none was measured: all invalid, crashed or
  without a test; the survivors file, or its copy at `--base`, cannot be
  read).

  ## replay (DND-5485)

      mix anchor.sabotage replay [--max N|all] [--records DIR_GLOB]...

  Re-applies each `killed` or `timeout` row of the landed sabotage records
  (the `anchor-kills` blocks under `sabotage.records.dir`, or each
  `--records` directory glob) on the current tree and runs the tests that
  killed it, by file and test name (`Anchor.Managers.Sabotage.Replay`). A
  row whose killers all pass is LOST POWER; a row that can no longer be
  replayed as recorded is drifted (its file, function or killer is gone, no
  mutant has its id, it no longer compiles), reported by reason. `--max`
  overrides the `max_mutants` cap (`--max all` for CI).

  Exit codes: 0 every replayed row still killed; 1 a row lost power or its
  run crashed; 2 a refusal or usage error (as `run`, and a `--records` glob
  that is absolute or has a `..` segment); 3 `COULD NOT MEASURE` (zero rows,
  every row drifted, a record that could not be read, the killers fail with
  no mutant: main is red).

  ## coverage (DND-5474)

      MIX_ENV=test mix anchor.sabotage coverage [--out PATH] [--local] [-- TEST_ARGS]

  Runs the whole suite in this VM, one test at a time (`--max-cases 1`), with
  every call of the project's own modules traced, and writes the map test ->
  functions it executed (default `_build/test/anchor/coverage.etf`;
  `Anchor.Domain.Sabotage.CoverageMap`). `TEST_ARGS` go to `mix test`.

  It is CI-only by default: without `CI=true` it refuses (exit 2) unless
  `--local` is given. Exit codes: 0 written; 1 written, but the suite failed;
  2 a refusal (not CI, MIX_ENV not test, `TEST_ARGS` that set
  `--max-cases`, another tracer on, the map not writable); 3 `COULD NOT MEASURE` (zero modules or zero tests, or a
  project module that cannot load: no map written).
  """

  use Mix.Task

  alias Anchor.Domain.Failures
  alias Anchor.Domain.Sabotage.Replay
  alias Anchor.Domain.Sabotage.Report
  alias Anchor.Domain.Sabotage.Scope
  alias Anchor.Managers.Sabotage
  alias Anchor.Sabotage.CoverageCollector

  @default_base "origin/main"
  @usage """
  Usage: mix anchor.sabotage scope [--base REF] [--format text|json]
         mix anchor.sabotage run [--base REF] [--max N|all] [--only ID]... [--dry-run]
                                 [--coverage PATH] [--no-record] [--domain D]
                                 [--ticket KEY] [--slot S] [--print-survivor-lines]
         mix anchor.sabotage restore
         mix anchor.sabotage replay [--max N|all] [--records DIR_GLOB]...
         MIX_ENV=test mix anchor.sabotage coverage [--out PATH] [--local] [-- TEST_ARGS]
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
    case run_facts(argv) do
      {:ok, facts} -> report(Sabotage.run(facts, opts))
      :usage -> usage()
    end
  end

  def run(["restore"], opts), do: report(Sabotage.restore(%{root: File.cwd!()}, opts))

  def run(["replay" | argv], opts) do
    case replay_facts(argv) do
      {:ok, facts} -> replay_report(Sabotage.replay(facts, opts))
      :usage -> usage()
    end
  end

  def run(["coverage" | argv], opts) do
    {own, test_args} = split_test_args(argv)

    case OptionParser.parse(own, strict: [out: :string, local: :boolean]) do
      {parsed, [], []} -> coverage(parsed, test_args, opts)
      _invalid -> usage()
    end
  end

  def run(_argv, _opts), do: usage()

  @doc false
  # The facts `run` passes the Manager, from its argv; exposed for its test.
  @spec run_facts([String.t()]) :: {:ok, map()} | :usage
  def run_facts(argv) do
    switches = [
      base: :string,
      max: :string,
      only: :keep,
      dry_run: :boolean,
      coverage: :string,
      record: :boolean,
      domain: :string,
      ticket: :string,
      slot: :string,
      print_survivor_lines: :boolean
    ]

    with {parsed, [], []} <- OptionParser.parse(argv, strict: switches),
         {:ok, max} <- max(parsed[:max]) do
      facts = %{
        root: File.cwd!(),
        env: Mix.env(),
        # The last run is saved under Mix's build path (DND-5635).
        build_path: Mix.Project.build_path(),
        base: Keyword.get(parsed, :base, @default_base),
        max: max,
        only: Keyword.get_values(parsed, :only),
        dry_run: Keyword.get(parsed, :dry_run, false),
        coverage: parsed[:coverage],
        no_record: Keyword.get(parsed, :record, true) == false,
        domain: parsed[:domain],
        ticket: parsed[:ticket],
        slot: parsed[:slot],
        print_survivor_lines: Keyword.get(parsed, :print_survivor_lines, false),
        now: DateTime.utc_now(),
        command: Enum.join(["mix", "anchor.sabotage", "run" | argv], " "),
        version: anchor_version()
      }

      {:ok, facts}
    else
      _invalid -> :usage
    end
  end

  @doc false
  # The facts `replay` passes the Manager, from its argv; exposed for its test.
  @spec replay_facts([String.t()]) :: {:ok, map()} | :usage
  def replay_facts(argv) do
    with {parsed, [], []} <- OptionParser.parse(argv, strict: [max: :string, records: :keep]),
         {:ok, max} <- max(parsed[:max]),
         globs = Keyword.get_values(parsed, :records),
         true <- Enum.all?(globs, &Replay.inside?/1) do
      {:ok, %{root: File.cwd!(), build_path: Mix.Project.build_path(), max: max, records: globs}}
    else
      _invalid -> :usage
    end
  end

  defp replay_report(result) do
    Mix.shell().info(Replay.render(result))

    case Replay.exit_code(result) do
      0 -> :ok
      code -> exit({:shutdown, code})
    end
  end

  defp anchor_version do
    case Application.spec(:anchor, :vsn) do
      nil -> "unknown"
      vsn -> to_string(vsn)
    end
  end

  defp split_test_args(argv) do
    case Enum.split_while(argv, &(&1 != "--")) do
      {own, ["--" | test_args]} -> {own, test_args}
      {own, []} -> {own, []}
    end
  end

  # The collector is an OTP process (Framework), so it is started here and
  # handed to the Manager, which reaches it only through the Tracing port.
  defp coverage(parsed, test_args, opts) do
    {:ok, collector} = CoverageCollector.start_link()

    facts = %{
      root: File.cwd!(),
      env: Mix.env(),
      ci: Keyword.get(opts, :ci, System.get_env("CI") == "true"),
      local: Keyword.get(parsed, :local, false),
      ebin_dirs: ebin_dirs(),
      out: Keyword.get(parsed, :out, "_build/test/anchor/coverage.etf"),
      collector: collector,
      elixir: System.version(),
      otp: to_string(:erlang.system_info(:otp_release)),
      test_args: test_args
    }

    {code, lines} = Sabotage.coverage(facts, opts)
    GenServer.stop(collector)
    emit(code, lines)
  end

  defp ebin_dirs do
    apps =
      case Mix.Project.apps_paths() do
        nil -> [Mix.Project.config()[:app]]
        paths -> Map.keys(paths)
      end

    Enum.map(apps, &Path.join([Mix.Project.build_path(), "lib", to_string(&1), "ebin"]))
  end

  defp emit(0, lines), do: Mix.shell().info(Enum.join(lines, "\n"))

  defp emit(code, lines) do
    Mix.shell().error(Enum.join(lines, "\n"))
    exit({:shutdown, code})
  end

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
