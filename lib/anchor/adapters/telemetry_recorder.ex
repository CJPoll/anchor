defmodule Anchor.Adapters.TelemetryRecorder do
  @moduledoc """
  Records each watched test's writes from an Ecto repo's query telemetry — a
  **Side Effect** adapter (port `Anchor.Adapters.WriteRecorder`, DND-5480).

  ## The handler

  `attach_recorder/2` attaches one `:telemetry` handler (a unique id) to the
  repo's `prefix ++ [:query]` event. `:telemetry` runs it synchronously in
  the process that ran the query, so `self()` is the emitter:

    1. it reads the statement (`Anchor.Domain.Aggregates.QueryStatement`:
       only `query` and `source`; never `params`, `cast_params` or `result`);
    2. it attributes the event to a watched test: the emitter itself
       (`emitted_by: :test`), else the first watched pid in the emitter's
       `$callers` (`:other`). Another test's events never enter, so async
       tests never see each other's writes;
    3. for an attributed event it asks the transaction probe
       (`Anchor.Adapters.TransactionProbe`) which transaction is open after
       the statement, and records a write as an
       `Anchor.Domain.Aggregates.BackstopEvent` keyed by its test;
    4. a write it cannot attribute (a process with a sandbox allowance but no
       `$callers`, an unwatched test) belongs to no test: it is counted, as
       `unattributed`, for the whole suite.

  Reads and savepoint statements are not recorded. Metadata that is not an
  Ecto query event raises; `:telemetry` then detaches the handler, and
  `recorder_attached?/1` turns false, which fails the next verdict.

  ## Storage

  One public ETS `:set` table per recorder, owned by the process that calls
  `attach_recorder/2` (`test_helper.exs`'s, which lives for the whole suite):
  `{:watched, pid}`, `{:event, test_pid, seq}` (seq is a monotonic integer,
  so `take_events/2` returns events in the order they came) and
  `{:count, key}`. `take_events/2` deletes the test's rows.
  """

  @behaviour Anchor.Adapters.WriteRecorder

  alias Anchor.Domain.Aggregates.Backstop
  alias Anchor.Domain.Aggregates.BackstopEvent
  alias Anchor.Domain.Aggregates.QueryStatement

  @session {__MODULE__, :session}

  @doc "Attaches the handler to `event` with `probe`; see the moduledoc."
  @impl Anchor.Adapters.WriteRecorder
  def attach_recorder(event, probe) when is_list(event) and is_atom(probe) do
    table = :ets.new(__MODULE__, [:set, :public, write_concurrency: true, read_concurrency: true])
    handler = {__MODULE__, make_ref()}
    config = %{table: table, probe: probe}

    # The handler id holds a fresh ref, so :telemetry's one refusal
    # (`{:error, :already_exists}`) cannot happen: a match error if it does.
    :ok = :telemetry.attach(handler, event, &__MODULE__.handle_event/4, config)
    {:ok, %{table: table, handler: handler, event: event}}
  end

  @doc """
  The `:telemetry` handler; see the moduledoc. Public so `:telemetry` calls
  it as a remote function.
  """
  @spec handle_event([atom()], map(), map(), %{table: :ets.tid(), probe: module()}) :: :ok
  def handle_event(_event, _measurements, metadata, %{table: table, probe: probe}) do
    statement = QueryStatement.classify(metadata)

    case attribution(table) do
      {:ok, test_pid, emitted_by} -> record(table, probe, statement, test_pid, emitted_by)
      :none -> unattributed(table, statement)
    end
  end

  @doc "Marks `pid` as a watched test."
  @impl Anchor.Adapters.WriteRecorder
  def watch_pid(%{table: table}, pid) when is_pid(pid) do
    :ets.insert(table, {{:watched, pid}, true})
    :ok
  end

  @doc "The test's events in the order they came; they and the pid are forgotten."
  @impl Anchor.Adapters.WriteRecorder
  def take_events(%{table: table}, pid) when is_pid(pid) do
    pattern = {{:event, pid, :"$1"}, :"$2"}
    events = :ets.select(table, [{pattern, [], [{{:"$1", :"$2"}}]}])
    :ets.select_delete(table, [{{{:event, pid, :_}, :_}, [], [true]}])
    :ets.delete(table, {:watched, pid})
    events |> Enum.sort_by(&elem(&1, 0)) |> Enum.map(&elem(&1, 1))
  end

  @doc "Whether the handler is still attached and the table still exists."
  @impl Anchor.Adapters.WriteRecorder
  def recorder_attached?(%{table: table, handler: handler, event: event}) do
    :ets.info(table, :id) != :undefined and
      Enum.any?(:telemetry.list_handlers(event), &(&1.id == handler))
  end

  @doc "Adds `counts` to the suite's totals."
  @impl Anchor.Adapters.WriteRecorder
  def add_counts(%{table: table}, counts) do
    Enum.each(counts, fn {key, n} -> count(table, key, n) end)
  end

  @doc "The suite's totals, every key of `Backstop.total_keys/0` (0 when never counted)."
  @impl Anchor.Adapters.WriteRecorder
  def read_totals(%{table: table}) do
    Map.new(Backstop.total_keys(), fn key ->
      case :ets.lookup(table, {:count, key}) do
        [{_key, n}] -> {key, n}
        [] -> {key, 0}
      end
    end)
  end

  @doc "Keeps `session` for `installed_session/0` (one per VM)."
  @impl Anchor.Adapters.WriteRecorder
  def install_session(session) when is_map(session), do: :persistent_term.put(@session, session)

  @doc "The session `install_session/1` kept, or `:error` when none was."
  @impl Anchor.Adapters.WriteRecorder
  def installed_session do
    case :persistent_term.get(@session, nil) do
      nil -> :error
      session -> {:ok, session}
    end
  end

  @doc "Detaches the handler and drops the table."
  @impl Anchor.Adapters.WriteRecorder
  def detach_recorder(%{table: table, handler: handler}) do
    :telemetry.detach(handler)
    if :ets.info(table, :id) != :undefined, do: :ets.delete(table)
    :ok
  end

  # --- the handler's steps ------------------------------------------------

  defp attribution(table) do
    me = self()

    if :ets.member(table, {:watched, me}) do
      {:ok, me, :test}
    else
      :"$callers" |> Process.get([]) |> watched_caller(table)
    end
  end

  defp watched_caller(callers, table) do
    case Enum.find(callers, &:ets.member(table, {:watched, &1})) do
      nil -> :none
      test_pid -> {:ok, test_pid, :other}
    end
  end

  defp record(table, probe, statement, test_pid, emitted_by) do
    tx = probe.observe(statement)

    case statement do
      {:write, kind, source} ->
        event =
          BackstopEvent.new(%{
            pid: self(),
            test_pid: test_pid,
            table: source,
            kind: kind,
            tx: tx,
            emitted_by: emitted_by
          })

        :ets.insert(table, {{:event, test_pid, System.unique_integer([:monotonic])}, event})
        :ok

      _not_a_write ->
        :ok
    end
  end

  defp unattributed(table, {:write, _kind, _source}), do: count(table, :unattributed, 1)
  defp unattributed(_table, _not_a_write), do: :ok

  defp count(table, key, n) do
    :ets.update_counter(table, {:count, key}, n, {{:count, key}, 0})
    :ok
  end
end
