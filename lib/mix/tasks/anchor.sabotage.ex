defmodule Mix.Tasks.Anchor.Sabotage do
  @shortdoc "Generated sabotage: scope, run, restore, verify, replay, coverage and behaviours"

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
                              [--scope diff|all] [--shard I/N|auto] [--report PATH]
      mix anchor.sabotage restore

  `run` applies the mutants of the changed functions one at a time, runs only
  each one's selected tests (bounded by `timeout_seconds`), restores the file
  after each, and prints a line per mutant and a summary
  (`Anchor.Domain.Sabotage.Report`). `--max` overrides the `max_mutants` cap
  (`--max all` lifts it, for CI); `--only` runs the named mutant ids;
  `--dry-run` prints the plan and writes nothing. `restore` puts back a file a
  killed run left mutated (`.anchor/sabotage/in-flight.json`). `--coverage
  PATH` (or the config's `coverage_map`) selects each mutant's tests from a
  per-test coverage map (DND-5474) first, then the mirror file and its
  `<stem>_<topic>_test.exs` siblings (DND-6070); each line says
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

  ## verify (DND-5516)

      mix anchor.sabotage verify --base REF [--format text|json]

  Checks, in seconds and with no load, that the mutants of the functions the
  diff since `REF` changes are covered: each mutant id the current source
  generates has a `killed`, `timeout` or `invalid` row in a sabotage record the
  branch added or appended to, or an entry in the survivors list with a real
  reason (`Anchor.Domain.Sabotage.Verify`). It compiles nothing, runs no test,
  applies no mutant and writes nothing: a gate runs it after the captain's
  `run` committed its record. A row of a changed function's latest run whose id
  is no longer generated is a STALE RECORD; a landed record the branch deleted
  is RECORD REMOVED; survivors the branch added are printed for review.

  Exit codes: 0 every mutant covered, or no changed function
  (`sabotage verify: no changed functions`); 1 UNCOVERED, STALE RECORD, BAD
  SURVIVOR, BAD RECORD (a kill map that does not parse) or RECORD REMOVED,
  each with one `Fix:`; 2 usage (no `--base`, a `REF` git cannot read or
  Anchor refuses to pass to git, an unknown flag); 3 `COULD NOT MEASURE` (no
  `sabotage:` config, the scope or a record or the survivors list could not be
  read, changed source files in which nothing was found, one mutant id
  generated twice).

  ## The nightly scan (DND-5490)

  `--scope all` scopes every function with a literal clause in the project's
  `lib` files instead of the diff (`Anchor.Domain.Sabotage.Scope.all/1`);
  `--shard I/N` keeps the mutants whose id, read as a hexadecimal number, is
  `I` modulo `N`, and `--shard auto` is the shard of the day, the days since
  1970-01-01 modulo `sabotage.scan_shards` (default 7). `--report PATH` writes the scan's
  report (`Anchor.Domain.Sabotage.ScanReport`) to `PATH` and its term beside
  it as `.etf`: the survivors the survivors list does not hold are its
  findings. `--report` and `--scope all` write no record. With `--report` the
  exit code ignores survivors: 0 measured, 2 the report not written or a
  refusal, 3 COULD NOT MEASURE (no function in scope, a failing baseline,
  nothing measured). A malformed `--shard` or `--scope` is a usage error (2).

  ## replay (DND-5485)

      mix anchor.sabotage replay [--max N|all] [--records DIR_GLOB]...

  Re-applies each `killed` or `timeout` row of the landed sabotage records
  (the `anchor-kills` blocks under `sabotage.records.dir` and
  `sabotage.records.outside_apps_dir` when set, or each `--records`
  directory glob) on the current tree and runs the tests that
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

  ## behaviours (DND-5489)

      mix anchor.sabotage behaviours [--coverage PATH] [--format text|json]
                                     [--write-baseline] [--base REF]

  Reads the coverage map (`--coverage`, or the config's `coverage_map`) and every
  record's kill map, and prints each test's confirmed causes: the functions it
  executed and killed a mutant of (`Anchor.Domain.Sabotage.BehaviourMap`), the
  behaviours spread over the most directories first, and how many tests nothing
  confirms yet (`--format json` lists them, and each behaviour's functions). It runs
  no test. The locality keys are compared with the baseline
  (`sabotage.behaviour_locality_baseline`): NEW when a behaviour spread to another
  directory, STALE when it shrank, and with `--base` GREW for entries the branch
  added. `--write-baseline` creates the file and never replaces one.

  Exit codes: 0 measured, in `report` mode whatever the verdict, or the baseline
  written; 1 in `enforce` mode (`sabotage.behaviour_locality_enforcement`) NEW,
  STALE or GREW, and in either mode a baseline named in the config that is absent,
  or a malformed one; 2 usage, or `--write-baseline` over an existing file;
  3 `COULD NOT MEASURE` (no loadable `sabotage:` config, no usable coverage map or
  one with no tests, a record that cannot be read, no `killed` row anywhere or none
  that confirms a behaviour, the baseline unreadable here or at `--base`).

  ## coverage (DND-5474)

      MIX_ENV=test mix anchor.sabotage coverage [--out PATH] [--local] [-- TEST_ARGS]

  Compiles every test file, then runs the whole suite in this VM, one test at a
  time (`--max-cases 1`), with every call of the project's own modules traced, and
  writes the map test -> functions it executed (default
  `_build/test/anchor/coverage.etf`; `Anchor.Domain.Sabotage.CoverageMap`).
  `TEST_ARGS` go to `mix test`; one that chooses files is refused.

  It is CI-only by default: without `CI=true` it refuses (exit 2) unless
  `--local` is given. Exit codes: 0 written; 1 written, but a test leaked (a
  process it owned called project code after it ended, DND-5691) or the suite
  failed; 2 a refusal (not CI, MIX_ENV not test, `TEST_ARGS` that set
  `--max-cases` or choose files, another tracer on, the map not writable); 3 `COULD
  NOT MEASURE` (zero modules or zero tests, a project module that cannot load, or a
  run that cannot be believed, such as fewer windows than tests: no map written).

  ## coverage-compare (DND-5692)

      mix anchor.sabotage coverage-compare FIRST SECOND

  Judges two maps built at one commit and one seed
  (`Anchor.Domain.Sabotage.CoverageCompare`). Exit codes: 0 the canonical bytes are
  identical and neither build leaked; 1 a leak in either build (each build's pairs
  printed, never compared: a leak list is identical only at empty), a failed suite,
  or a difference (each differing test, function and ambient function named);
  2 usage; 3 `COULD NOT MEASURE` (a map absent, unreadable or measuring nothing, or
  two maps not of one commit, Elixir and OTP: a missing second build is never a pass).
  """

  use Mix.Task

  alias Anchor.Domain.Baseline
  alias Anchor.Domain.Failures
  alias Anchor.Domain.Sabotage.Replay
  alias Anchor.Domain.Sabotage.Report
  alias Anchor.Domain.Sabotage.Scope
  alias Anchor.Domain.Sabotage.Verify
  alias Anchor.Managers.Sabotage
  alias Anchor.Sabotage.CoverageCollector

  @default_base "origin/main"
  @usage """
  Usage: mix anchor.sabotage scope [--base REF] [--format text|json]
         mix anchor.sabotage run [--base REF] [--max N|all] [--only ID]... [--dry-run]
                                 [--coverage PATH] [--no-record] [--domain D]
                                 [--ticket KEY] [--slot S] [--print-survivor-lines]
                                 [--scope diff|all] [--shard I/N|auto] [--report PATH]
         mix anchor.sabotage restore
         mix anchor.sabotage verify --base REF [--format text|json]
         mix anchor.sabotage replay [--max N|all] [--records DIR_GLOB]...
         MIX_ENV=test mix anchor.sabotage coverage [--out PATH] [--local] [-- TEST_ARGS]
         mix anchor.sabotage behaviours [--coverage PATH] [--format text|json]
                                        [--write-baseline] [--base REF]
         mix anchor.sabotage coverage-compare FIRST SECOND
  Fix: use one of these forms; --max takes a positive integer or `all`; --shard I/N needs 0 <= I < N\
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

  def run(["verify" | argv], opts) do
    case OptionParser.parse(argv, strict: [base: :string, format: :string]) do
      {parsed, [], []} -> verify(parsed, format(parsed[:format]), opts)
      _invalid -> usage()
    end
  end

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

  def run(["coverage-compare", first, second], opts) do
    {code, lines} = Sabotage.coverage_compare(%{first: first, second: second}, opts)
    emit(code, lines)
  end

  def run(["behaviours" | argv], opts) do
    case behaviours_facts(argv) do
      {:ok, facts} ->
        {code, lines} = Sabotage.behaviours(facts, opts)
        emit(code, lines)

      :usage ->
        usage()
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
      print_survivor_lines: :boolean,
      scope: :string,
      shard: :string,
      report: :string
    ]

    with {parsed, [], []} <- OptionParser.parse(argv, strict: switches),
         {:ok, max} <- max(parsed[:max]),
         {:ok, scope} <- run_scope(parsed[:scope]),
         {:ok, shard} <- shard(parsed[:shard]) do
      # DND-5490: a scan's report, or the whole tree, is never a branch's record.
      no_record =
        Keyword.get(parsed, :record, true) == false or scope == :all or
          is_binary(parsed[:report])

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
        no_record: no_record,
        scope: scope,
        shard: shard,
        report: parsed[:report],
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

  @doc false
  # The facts `behaviours` passes the Manager, from its argv; exposed for its test.
  @spec behaviours_facts([String.t()]) :: {:ok, map()} | :usage
  def behaviours_facts(argv) do
    switches = [coverage: :string, format: :string, write_baseline: :boolean, base: :string]

    with {parsed, [], []} <- OptionParser.parse(argv, strict: switches),
         format when format != :invalid <- format(parsed[:format]),
         true <- is_nil(parsed[:base]) or Baseline.valid_ref?(parsed[:base]) do
      {:ok,
       %{
         root: File.cwd!(),
         coverage: parsed[:coverage],
         format: format,
         write_baseline: Keyword.get(parsed, :write_baseline, false),
         base: parsed[:base]
       }}
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

  defp run_scope(nil), do: {:ok, :diff}
  defp run_scope("diff"), do: {:ok, :diff}
  defp run_scope("all"), do: {:ok, :all}
  defp run_scope(_other), do: :error

  # The date is read here, as `now` is: `auto` is the scan's shard of the day.
  defp shard(nil), do: {:ok, nil}
  defp shard("auto"), do: {:ok, {:auto, Date.utc_today()}}

  defp shard(text) do
    with [i, n] <- String.split(text, "/"),
         {i, ""} <- Integer.parse(i),
         {n, ""} <- Integer.parse(n),
         true <- n >= 1 and i >= 0 and i < n do
      {:ok, {i, n}}
    else
      _bad -> :error
    end
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

  defp verify(_parsed, :invalid, _opts), do: usage()

  defp verify(parsed, format, opts) do
    with base when is_binary(base) <- parsed[:base],
         true <- Baseline.valid_ref?(base),
         {:ok, verdict} <- Sabotage.verify(%{root: File.cwd!(), base: base}, opts) do
      emit(Verify.exit_code(verdict), [Verify.render(verdict, format)])
    else
      nil -> refuse(Verify.usage_message(:no_base))
      false -> refuse(Verify.usage_message({:bad_ref, parsed[:base]}))
      {:error, reason} -> refuse(Verify.usage_message(reason))
    end
  end

  defp refuse(message) do
    Mix.shell().error(message)
    exit({:shutdown, 2})
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
