defmodule Anchor.Managers.Sabotage.Coverage do
  @moduledoc """
  The flow of `mix anchor.sabotage coverage` (DND-5474), part of the
  **Manager** `Anchor.Managers.Sabotage` (ADR 001). It returns
  `{exit_code, lines}` and prints nothing.

    1. `MIX_ENV` must be `test` (else exit 2).
    2. Outside CI (`CI=true`) the command refuses unless `--local` was given
       (exit 2), before anything is traced: tracing every call of a whole
       suite run one test at a time is a load that belongs in CI. Test
       arguments that set `--max-cases` are refused too (exit 2): two tests
       at once would share their calls.
    3. The project's modules (`Anchor.Adapters.ProjectModuleSource`); none is
       exit 3.
    4. Tracing starts (`Anchor.Adapters.Tracing.start/2`; another tracer
       already on is exit 2), the suite runs in this VM
       (`Anchor.Adapters.InProcessTests`), and tracing stops in an `after`
       block, so a raise never leaves the VM traced.
    5. The collector's state becomes the map
       (`Anchor.Domain.Sabotage.CoverageMap.finalize/2`); a map with zero
       tests or zero modules is exit 3 and is not written.
    6. The map is written (`Anchor.Adapters.CoverageStore`); a failed suite
       still writes it, and exits 1: the map describes a broken suite.

  The collector process is the caller's (`facts.collector`): an OTP process is
  Framework, which this Manager never calls; it reaches it only through the
  `Tracing` port.

  ## Adapters (options)

  `:tracing` (`Anchor.Adapters.CallTracer`), `:in_process_tests`
  (`Anchor.Adapters.SuiteRunner`), `:project_modules`
  (`Anchor.Adapters.ProjectModules`), `:coverage_store`
  (`Anchor.Adapters.CoverageFile`), `:git_worktree`
  (`Anchor.Adapters.GitStatus`).
  """

  alias Anchor.Adapters.CallTracer
  alias Anchor.Adapters.CoverageFile
  alias Anchor.Adapters.GitStatus
  alias Anchor.Adapters.ProjectModules
  alias Anchor.Adapters.SuiteRunner
  alias Anchor.Domain.Sabotage.CoverageMap

  @type facts :: %{
          required(:root) => String.t(),
          required(:env) => atom(),
          required(:ci) => boolean(),
          required(:local) => boolean(),
          required(:ebin_dirs) => [String.t()],
          required(:out) => String.t(),
          required(:collector) => pid(),
          required(:elixir) => String.t(),
          required(:otp) => String.t(),
          optional(:test_args) => [String.t()]
        }

  @spec run(facts(), keyword()) :: {non_neg_integer(), [String.t()]}
  def run(facts, opts) do
    ports = ports(opts)

    with :ok <- test_env(facts),
         :ok <- in_ci(facts),
         :ok <- serial(Map.get(facts, :test_args, [])),
         {:ok, modules} <- modules(facts, ports),
         {:ok, state, suite} <- traced_suite(facts, modules, ports),
         {:ok, map} <- build(state, facts, modules, suite, ports),
         :ok <- write(map, facts, ports) do
      finished(map, suite, facts)
    end
  end

  defp ports(opts) do
    %{
      tracer: Keyword.get(opts, :tracing, CallTracer),
      suite: Keyword.get(opts, :in_process_tests, SuiteRunner),
      modules: Keyword.get(opts, :project_modules, ProjectModules),
      store: Keyword.get(opts, :coverage_store, CoverageFile),
      git: Keyword.get(opts, :git_worktree, GitStatus)
    }
  end

  defp test_env(%{env: :test}), do: :ok

  defp test_env(%{env: env}),
    do:
      {2,
       [
         "per-test coverage runs the test suite, but MIX_ENV is #{env}. " <>
           "Fix: MIX_ENV=test mix anchor.sabotage coverage"
       ]}

  defp in_ci(%{ci: true}), do: :ok
  defp in_ci(%{local: true}), do: :ok

  defp in_ci(_facts),
    do:
      {2,
       [
         "per-test coverage runs the whole suite serially with call tracing; it belongs in CI. " <>
           "Fix: run it in CI, or pass --local where that load is acceptable."
       ]}

  # Windows are one test at a time only while one test runs at a time: a
  # call while two windows are open would be added to both.
  defp serial(args) do
    if Enum.any?(args, &(&1 == "--max-cases" or String.starts_with?(&1, "--max-cases="))),
      do:
        {2,
         [
           "per-test coverage runs one test at a time, so the test arguments may not set " <>
             "--max-cases (two tests at once would share their calls). Fix: drop --max-cases"
         ]},
      else: :ok
  end

  defp modules(facts, %{modules: source}) do
    case source.list(facts.ebin_dirs) do
      [] ->
        {3,
         [
           "COULD NOT MEASURE: 0 project modules in #{Enum.join(facts.ebin_dirs, ", ")}, " <>
             "0 tests. Fix: compile the project (MIX_ENV=test mix compile) first"
         ]}

      modules ->
        {:ok, modules}
    end
  end

  defp traced_suite(facts, modules, %{tracer: tracer, suite: suite}) do
    case tracer.start(facts.collector, modules) do
      :ok ->
        result =
          try do
            suite.run(Map.get(facts, :test_args, []))
          after
            :ok = tracer.stop()
          end

        collected(tracer, facts.collector, result)

      {:error, :already_tracing} ->
        {2,
         [
           "another tracer is already on in this VM, so per-test coverage cannot be traced. " <>
             "Fix: run without other tracers"
         ]}
    end
  end

  defp collected(tracer, collector, result) do
    case tracer.collected(collector) do
      {:ok, state} ->
        {:ok, state, result}

      {:error, {:collector_down, reason}} ->
        {3,
         [
           "COULD NOT MEASURE: the coverage collector stopped (#{inspect(reason)}), so no " <>
             "call could be attributed. Fix: rerun; if it stops again, report it"
         ]}
    end
  end

  defp build(state, facts, modules, suite, %{git: git}) do
    commit =
      case git.head_sha(facts.root) do
        {:ok, sha} -> sha
        {:error, _reason} -> nil
      end

    meta = %{
      commit: commit,
      elixir: facts.elixir,
      otp: facts.otp,
      modules_traced: length(modules),
      suite_exit: suite_exit(suite),
      root: facts.root
    }

    map = CoverageMap.finalize(state, meta)

    case CoverageMap.validate(map) do
      :ok ->
        {:ok, map}

      {:error, _empty} ->
        {3,
         [
           "COULD NOT MEASURE: tests: #{length(map.tests)}, modules_traced: " <>
             "#{map.modules_traced}; no map was written. Fix: check the suite runs tests " <>
             "and the ebin directories hold the project's modules"
         ]}
    end
  end

  defp suite_exit(:passed), do: 0
  defp suite_exit({:failed, _message}), do: 1

  defp write(map, facts, %{store: store}) do
    case store.write(facts.out, map) do
      :ok ->
        :ok

      {:error, posix} ->
        {2,
         [
           "could not write #{facts.out} (#{inspect(posix)}). " <>
             "Fix: pass --out a writable path"
         ]}
    end
  end

  defp finished(map, :passed, facts), do: {0, [CoverageMap.summary(map, facts.out)]}

  defp finished(map, {:failed, message}, facts) do
    {1,
     [
       CoverageMap.summary(map, facts.out),
       "the suite failed (#{message}), so the map (written, suite_exit: 1) describes a " <>
         "broken suite. Fix: make the suite green first"
     ]}
  end
end
