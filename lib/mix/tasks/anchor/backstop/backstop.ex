defmodule Anchor.Backstop do
  @moduledoc """
  A test-time backstop for the aggregate rules (DND-5480): it fails a test
  whose database transaction wrote tables of two declared aggregates — the
  **Framework** entry point (ADR 001; it lives under `lib/mix/tasks/` so
  `mix anchor.graph` buckets it as Framework, as it does
  `Anchor.Sabotage.CoverageCollector`).

  The static rules cannot judge a transaction whose write set they cannot
  read whole (a callback passed as a variable, a write through a variable
  repo, a `Multi.merge` function). The tests already run those paths; this
  watches the repo's query events while they do. Two calls are the whole
  integration:

      # test/test_helper.exs
      Anchor.Backstop.attach!(repo: MyApp.Repo)
      ExUnit.start()

      # test/support/data_case.ex
      setup tags do
        Anchor.Backstop.watch(tags)
        :ok
      end

  `attach!/1` options:

    * `repo:` (required) — the Ecto repo whose `telemetry_prefix` names the
      query event;
    * `ebins:` — the directories of the project's beams the aggregate
      declarations are read from (default `[Mix.Project.compile_path()]`);
    * `root:` — where `.anchor.yml` is looked up (default the working
      directory);
    * `escapes:` — `:report` (default: counted and summarised) or `:fail`
      (an escape fails its test too).

  It reads the same declarations as the static rules (`.anchor.yml`'s
  `aggregates:` and every persisted `@anchor_aggregate`), from the compiled
  beams; it never loads a project module for them. It records table names,
  statement kinds and pids, never a parameter or a row value. The verdict
  runs in the test's `on_exit`, never in the handler: no sleep, no polling,
  no clock. `Anchor.Managers.Backstop` documents the fail-closed cases and
  `Anchor.Domain.Aggregates.Backstop` the verdict and the escape kinds.
  """

  alias Anchor.Managers.Backstop

  @doc "Starts the backstop for the suite; see the moduledoc. Raises with `Fix:`."
  @spec attach!(keyword()) :: :ok
  def attach!(opts) when is_list(opts) do
    repo = Keyword.fetch!(opts, :repo)
    escapes = escapes!(Keyword.get(opts, :escapes, :report))
    app = Keyword.get(Mix.Project.config(), :app) || :project
    ebins = Keyword.get_lazy(opts, :ebins, fn -> [Mix.Project.compile_path()] end)

    session =
      Backstop.start(%{
        event: query_event!(repo),
        root: Keyword.get_lazy(opts, :root, &File.cwd!/0),
        apps: Enum.map(ebins, &{app, &1}),
        escapes: escapes
      })

    :ok = Backstop.install(session)
    ExUnit.after_suite(fn _result -> Mix.shell().info(Backstop.summary(session)) end)
    :ok
  end

  @doc """
  Watches the current test (call it in a `setup` block with the test's
  `tags`): its writes are recorded, and its `on_exit` judges them. Raises
  with `Fix:` when `attach!/1` has not run.
  """
  @spec watch(map()) :: :ok
  def watch(%{} = tags) do
    session = Backstop.installed!()
    test_pid = self()
    test = "#{inspect(Map.get(tags, :module))} #{Map.get(tags, :test)}"
    :ok = Backstop.watch(session, test_pid)
    ExUnit.Callbacks.on_exit(fn -> Backstop.verdict!(session, test_pid, test) end)
  end

  defp escapes!(mode) when mode in [:report, :fail], do: mode

  defp escapes!(other) do
    raise ArgumentError,
          "anchor backstop: escapes: must be :report or :fail, got: #{inspect(other)}. " <>
            "Fix: pass escapes: :report (count them) or escapes: :fail (fail the test)."
  end

  defp query_event!(repo) do
    prefix =
      if is_atom(repo) and Code.ensure_loaded?(repo) and function_exported?(repo, :config, 0),
        do: Keyword.get(repo.config(), :telemetry_prefix)

    if is_list(prefix) and prefix != [] and Enum.all?(prefix, &is_atom/1) do
      prefix ++ [:query]
    else
      raise ArgumentError,
            "anchor backstop: #{inspect(repo)} has no telemetry prefix. Fix: pass repo: an " <>
              "Ecto repo (use Ecto.Repo), whose config/0 holds :telemetry_prefix."
    end
  end
end
