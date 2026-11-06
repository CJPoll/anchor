defmodule Anchor.Adapters.TelemetryRecorderTest do
  # DND-5480: the recorder's handler, driven by synthetic `:telemetry.execute/3`
  # events carrying the metadata shapes DND-5479 recorded
  # (Anchor.Test.BackstopMetadata). Each test attaches its own recorder to an
  # event of its own name, so async tests never share a handler, and detaches
  # it on exit. Ordering is by message receipt only.
  #
  # sync: the session test below writes the VM's one session
  # (`:persistent_term`), and `Anchor.BackstopTest` (async) asserts none is
  # installed. Async modules all run before sync ones, so it never overlaps
  # that test, and on_exit erases it.
  #
  # Sabotage record: ../../sabotage_records/backstop-20261106-dnd_5480_test_backstop.md
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  alias Anchor.Adapters.EctoTransactionProbe
  alias Anchor.Adapters.TelemetryRecorder, as: Recorder
  alias Anchor.Domain.Aggregates.BackstopEvent
  alias Anchor.Test.BackstopMetadata, as: Meta

  setup %{test: test} do
    event = [:anchor_backstop_test, test, :query]
    {:ok, recorder} = Recorder.attach_recorder(event, EctoTransactionProbe)
    on_exit(fn -> Recorder.detach_recorder(recorder) end)
    %{recorder: recorder, event: event}
  end

  defp emit(event, metadata), do: :telemetry.execute(event, %{total_time: 1}, metadata)

  # Runs `fun` in a process whose `$callers` holds `callers`, and waits for it.
  defp in_process(callers, fun) do
    parent = self()

    pid =
      spawn_link(fn ->
        Process.put(:"$callers", callers)
        fun.()
        send(parent, {:done, self()})
      end)

    # Blocks on the event; ExUnit's test timeout is the only bound.
    receive do
      {:done, ^pid} -> pid
    end
  end

  test "R1: a watched test's write is recorded with its table and kind, and no parameter", %{
    recorder: recorder,
    event: event
  } do
    :ok = Recorder.watch_pid(recorder, self())
    emit(event, Meta.insert("orders"))

    me = self()

    assert [%BackstopEvent{} = recorded] = Recorder.take_events(recorder, me)

    assert recorded ==
             BackstopEvent.new(%{
               pid: me,
               test_pid: me,
               table: "orders",
               kind: :insert,
               tx: :no_tx,
               emitted_by: :test
             })

    # Nothing of params, cast_params or result is kept anywhere: not in the
    # event, not in the table.
    refute inspect(recorded, limit: :infinity) =~ Meta.secret()
    refute inspect(:ets.tab2list(recorder.table), limit: :infinity) =~ Meta.secret()
  end

  test "R1: a transaction's writes carry its ref; take forgets them and the pid", %{
    recorder: recorder,
    event: event
  } do
    :ok = Recorder.watch_pid(recorder, self())
    emit(event, Meta.begin())
    emit(event, Meta.insert("orders"))
    emit(event, Meta.select("invoices"))
    emit(event, Meta.update("invoices"))
    emit(event, Meta.commit())
    emit(event, Meta.delete("orders"))

    assert [
             %{table: "orders", kind: :insert, tx: {:in_tx, ref}},
             %{table: "invoices", kind: :update, tx: {:in_tx, ref}},
             %{table: "orders", kind: :delete, tx: :no_tx}
           ] = Recorder.take_events(recorder, self())

    assert Recorder.take_events(recorder, self()) == []

    # The pid is no longer watched: a later write is the suite's, not the test's.
    emit(event, Meta.insert("orders"))
    assert Recorder.take_events(recorder, self()) == []
    assert Recorder.read_totals(recorder).unattributed == 1
  end

  test "R2: a write from a process with the test in $callers is recorded as another process's", %{
    recorder: recorder,
    event: event
  } do
    me = self()
    :ok = Recorder.watch_pid(recorder, me)
    pid = in_process([me], fn -> emit(event, Meta.insert("orders")) end)

    assert [%{pid: ^pid, test_pid: ^me, emitted_by: :other, table: "orders"}] =
             Recorder.take_events(recorder, me)
  end

  test "R2: the first watched pid in $callers owns the write", %{recorder: recorder, event: event} do
    me = self()
    :ok = Recorder.watch_pid(recorder, me)
    unwatched = spawn(fn -> :ok end)
    in_process([unwatched, me], fn -> emit(event, Meta.insert("orders")) end)

    assert [%{test_pid: ^me, emitted_by: :other}] = Recorder.take_events(recorder, me)
  end

  test "R3: an unwatched process's write is not recorded, and is counted unattributed", %{
    recorder: recorder,
    event: event
  } do
    :ok = Recorder.watch_pid(recorder, self())
    other = in_process([], fn -> emit(event, Meta.insert("orders")) end)

    assert Recorder.take_events(recorder, self()) == []
    assert Recorder.take_events(recorder, other) == []
    assert Recorder.read_totals(recorder).unattributed == 1
  end

  test "R3: an unwatched process's read is not counted", %{recorder: recorder, event: event} do
    in_process([], fn -> emit(event, Meta.select("orders")) end)
    assert Recorder.read_totals(recorder).unattributed == 0
  end

  test "R4: two watched tests each see only their own writes", %{recorder: recorder, event: event} do
    a = self()
    :ok = Recorder.watch_pid(recorder, a)
    parent = self()

    b =
      spawn_link(fn ->
        receive do
          :go ->
            emit(event, Meta.insert("invoices"))
            send(parent, :b_done)
        end
      end)

    :ok = Recorder.watch_pid(recorder, b)
    emit(event, Meta.insert("orders"))
    send(b, :go)

    receive do
      :b_done -> :ok
    end

    assert [%{table: "orders", test_pid: ^a}] = Recorder.take_events(recorder, a)
    assert [%{table: "invoices", test_pid: ^b}] = Recorder.take_events(recorder, b)
  end

  test "R5: a read is not recorded", %{recorder: recorder, event: event} do
    :ok = Recorder.watch_pid(recorder, self())
    emit(event, Meta.select("orders"))
    assert Recorder.take_events(recorder, self()) == []
  end

  test "raw SQL is recorded with no table", %{recorder: recorder, event: event} do
    :ok = Recorder.watch_pid(recorder, self())
    emit(event, Meta.raw_insert("orders"))
    assert [%{table: nil, kind: :insert}] = Recorder.take_events(recorder, self())
  end

  test "R6: a handler that raises on malformed metadata is detached, and says so", %{
    recorder: recorder,
    event: event
  } do
    :ok = Recorder.watch_pid(recorder, self())
    assert Recorder.recorder_attached?(recorder)

    capture_log(fn -> emit(event, %{query: nil, source: nil}) end)

    refute Recorder.recorder_attached?(recorder)
  end

  test "a recorder whose table is gone is not attached", %{recorder: recorder} do
    :ets.delete(recorder.table)
    refute Recorder.recorder_attached?(recorder)
  end

  test "counts add up per key; a key never counted is 0", %{recorder: recorder} do
    :ok = Recorder.add_counts(recorder, %{tests: 1, crossings: 1, no_source: 2})
    :ok = Recorder.add_counts(recorder, %{tests: 1, crossings: 0, no_source: 1})

    assert Recorder.read_totals(recorder) == %{
             tests: 2,
             crossings: 1,
             other_process: 0,
             no_source: 3,
             undeclared_table: 0,
             unclassified: 0,
             outside_transaction: 0,
             unattributed: 0
           }
  end

  test "detach_recorder detaches the handler and drops the table", %{recorder: recorder} do
    assert :ets.info(recorder.table, :id) != :undefined
    assert :ok = Recorder.detach_recorder(recorder)

    assert :ets.info(recorder.table, :id) == :undefined
    refute Enum.any?(:telemetry.list_handlers(recorder.event), &(&1.id == recorder.handler))
  end

  test "a session installed is the session installed_session returns" do
    on_exit(fn -> :persistent_term.erase({Recorder, :session}) end)
    assert Recorder.installed_session() == :error

    session = %{escapes: :report, marker: make_ref()}
    assert Recorder.install_session(session) == :ok

    assert Recorder.installed_session() == {:ok, session}
  end

  test "a second session is refused, and the first kept" do
    on_exit(fn -> :persistent_term.erase({Recorder, :session}) end)
    first = %{marker: make_ref()}
    :ok = Recorder.install_session(first)

    assert Recorder.install_session(%{marker: make_ref()}) == {:error, :already_installed}
    assert Recorder.installed_session() == {:ok, first}
  end

  test "an event row no take read is counted unattributed", %{recorder: recorder, event: event} do
    :ok = Recorder.watch_pid(recorder, self())
    emit(event, Meta.insert("orders"))

    assert Recorder.read_totals(recorder).unattributed == 1
    assert [%{table: "orders"}] = Recorder.take_events(recorder, self())
    assert Recorder.read_totals(recorder).unattributed == 0
  end
end
