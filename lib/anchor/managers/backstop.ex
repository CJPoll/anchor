defmodule Anchor.Managers.Backstop do
  @moduledoc """
  The test-time aggregate backstop's use case (DND-5480) — a **Manager**.
  `Anchor.Backstop` (Framework) is its entry point.

  ## start/1

  Run once per test VM, from `test_helper.exs`:

    1. load `.anchor.yml` under `root` (`Anchor.Adapters.ConfigLoader`);
    2. read the project's beams (`Anchor.Adapters.BeamSource`) and build the
       graph (`Anchor.Domain.Graph.Builder`);
    3. build the aggregate index the static rules read
       (`Anchor.Domain.Aggregates.Index`: `aggregates: declare:` and every
       persisted `@anchor_aggregate`), one model, no second declaration;
    4. attach the recorder (`Anchor.Adapters.WriteRecorder`) to the repo's
       query event with the transaction probe
       (`Anchor.Adapters.TransactionProbe`).

  It fails closed: each of these raises `ArgumentError` with a `Fix:`, so a
  suite never starts with a backstop that checks nothing.

  | Case | Message starts |
  |---|---|
  | the config does not load | `anchor backstop: could not load .anchor.yml` |
  | no `aggregates:` section | `anchor backstop: <config path> has no aggregates: section` |
  | `aggregates: declare: none`, or zero aggregates declared | `anchor backstop: the backstop checks nothing: no aggregate is declared` |
  | no beam read from the ebins | `anchor backstop: no beam was read from` |
  | the handler could not attach | `anchor backstop: could not attach to` |

  ## Per test

  `watch/2` marks the test's pid; `verdict!/3` (from the test's `on_exit`)
  takes its writes, judges them (`Anchor.Domain.Aggregates.Backstop`), adds
  them to the suite's totals, and raises `ExUnit.AssertionError` when the
  verdict fails the test: a crossing, or under `escapes: :fail` an escape. A
  detached handler fails every verdict after it: `the backstop handler was
  detached`. `summary/1` is the line printed when the suite ends.
  """

  alias Anchor.Adapters.BeamReader
  alias Anchor.Adapters.ConfigFile
  alias Anchor.Adapters.EctoTransactionProbe
  alias Anchor.Adapters.TelemetryRecorder
  alias Anchor.Config
  alias Anchor.Domain.Aggregates.Backstop
  alias Anchor.Domain.Aggregates.Index
  alias Anchor.Domain.Graph.Beam
  alias Anchor.Domain.Graph.Builder

  @type session :: %{
          index: Index.t(),
          escapes: :report | :fail,
          recorder: map(),
          write_recorder: module()
        }

  @doc """
  Starts the backstop; see the moduledoc. `request` holds `event` (the repo's
  query event), `root` (the project root), `apps` (`[{app, ebin_dir}]`) and
  `escapes` (`:report` or `:fail`). `deps` doubles the ports:
  `:config_loader`, `:beam_source`, `:write_recorder`, `:probe`.
  """
  @spec start(
          %{
            event: [atom()],
            root: Path.t(),
            apps: [{atom(), Path.t()}],
            escapes: :report | :fail
          },
          keyword()
        ) :: session()
  def start(%{event: event, root: root, apps: apps, escapes: escapes}, deps \\ [])
      when escapes in [:report, :fail] do
    config_loader = Keyword.get(deps, :config_loader, ConfigFile)
    beam_source = Keyword.get(deps, :beam_source, BeamReader)
    write_recorder = Keyword.get(deps, :write_recorder, TelemetryRecorder)
    probe = Keyword.get(deps, :probe, EctoTransactionProbe)

    aggregates = aggregates!(config_loader.load_in(root), root)
    beams = beams!(beam_source.read_ebins(apps), apps)
    index = index!(aggregates, Builder.build(beams, %{}, root: root))

    case write_recorder.attach_recorder(event, probe) do
      {:ok, recorder} ->
        %{index: index, escapes: escapes, recorder: recorder, write_recorder: write_recorder}

      {:error, reason} ->
        raise ArgumentError,
              "anchor backstop: could not attach to #{inspect(event)}: #{inspect(reason)}. " <>
                "Fix: call Anchor.Backstop.attach!/1 once, in test_helper.exs."
    end
  end

  @doc "Keeps `session` as the test VM's one session, for `installed!/1`."
  @spec install(session()) :: :ok
  def install(%{write_recorder: write_recorder} = session),
    do: write_recorder.install_session(session)

  @doc """
  The session `install/1` kept. Raises `ArgumentError` with `Fix:` when none
  was: `watch/1` before `attach!/1` would check nothing.
  """
  @spec installed!(module()) :: session()
  def installed!(write_recorder \\ TelemetryRecorder) do
    case write_recorder.installed_session() do
      {:ok, session} ->
        session

      :error ->
        raise ArgumentError,
              "anchor backstop: watch/1 was called before the backstop was attached. " <>
                "Fix: call Anchor.Backstop.attach!/1 in test_helper.exs."
    end
  end

  @doc "Watches the test `pid`: its writes, and its callees', are recorded."
  @spec watch(session(), pid()) :: :ok
  def watch(%{write_recorder: write_recorder, recorder: recorder}, pid) when is_pid(pid),
    do: write_recorder.watch_pid(recorder, pid)

  @doc """
  Judges the test `pid`'s writes; see the moduledoc. `test` names it in the
  message. Returns `:ok` or raises `ExUnit.AssertionError`.
  """
  @spec verdict!(session(), pid(), String.t()) :: :ok
  def verdict!(%{write_recorder: write_recorder, recorder: recorder} = session, pid, test) do
    events = write_recorder.take_events(recorder, pid)

    if not write_recorder.recorder_attached?(recorder) do
      raise ExUnit.AssertionError,
        message:
          "#{test}: the backstop handler was detached, so this test's writes were not all " <>
            "recorded. Fix: read the :telemetry error logged when it was detached; the " <>
            "handler raised on an event it could not read."
    end

    result = Backstop.verdict(events, session.index)
    :ok = write_recorder.add_counts(recorder, Backstop.counts(result))

    case Backstop.failure(result, test, session.escapes) do
      :pass -> :ok
      {:fail, message} -> raise ExUnit.AssertionError, message: message
    end
  end

  @doc "The suite-end summary line (`Backstop.summary_line/1` of the totals)."
  @spec summary(session()) :: String.t()
  def summary(%{write_recorder: write_recorder, recorder: recorder}),
    do: recorder |> write_recorder.read_totals() |> Backstop.summary_line()

  # --- start's checks -----------------------------------------------------

  defp aggregates!({:ok, %Config{aggregates: nil, path: path}}, _root) do
    raise ArgumentError,
          "anchor backstop: #{path} has no aggregates: section. Fix: declare aggregates " <>
            "(mix anchor.propose --level aggregate)."
  end

  defp aggregates!({:ok, %Config{aggregates: aggregates}}, _root), do: aggregates

  defp aggregates!({:error, reason}, root) do
    raise ArgumentError,
          "anchor backstop: could not load .anchor.yml under #{root}: #{inspect(reason)}. " <>
            "Fix: run the backstop from the project root, beside a .anchor.yml that loads " <>
            "(mix credo reports why it does not)."
  end

  defp beams!(beams, apps) do
    if Enum.any?(beams, &match?(%Beam{}, &1)) do
      beams
    else
      raise ArgumentError,
            "anchor backstop: no beam was read from #{Enum.map_join(apps, ", ", &elem(&1, 1))}. " <>
              "Fix: pass ebins: the project's compile paths (the default is " <>
              "Mix.Project.compile_path/0), compiled before the suite runs."
    end
  end

  defp index!(aggregates, graph) do
    index = Index.build(aggregates, graph)

    if Index.declared(index) == 0 do
      raise ArgumentError,
            "anchor backstop: the backstop checks nothing: no aggregate is declared. Fix: " <>
              "declare aggregates (mix anchor.propose --level aggregate)."
    end

    index
  end
end
