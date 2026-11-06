defmodule Anchor.Managers.BackstopTest do
  # DND-5480: the backstop's use case with every port doubled: ConfigLoader
  # and WriteRecorder with Hammox `expect/3`, BeamSource with Mox (its return
  # type holds a :cerl record Hammox cannot match). An unexpected port call
  # fails the test. The beam the doubled BeamSource returns is a fixture
  # compiled in the test.
  #
  # Sabotage record: ../../sabotage_records/backstop-20261106-dnd_5480_test_backstop.md
  use ExUnit.Case, async: true

  import Anchor.Test.BeamFixtures
  import Hammox

  alias Anchor.Adapters.BeamReader
  alias Anchor.Adapters.EctoTransactionProbe
  alias Anchor.BeamSourceMock
  alias Anchor.Config
  alias Anchor.ConfigLoaderMock
  alias Anchor.Domain.Aggregates
  alias Anchor.Domain.Aggregates.BackstopEvent
  alias Anchor.Domain.Aggregates.Declaration
  alias Anchor.Domain.Aggregates.Index
  alias Anchor.Managers.Backstop
  alias Anchor.WriteRecorderMock

  setup :verify_on_exit!

  @ebin "/repo/_build/test/lib/app/ebin"
  @event [:app, :repo, :query]
  @request %{event: @event, root: "/repo", apps: [{:app, @ebin}], escapes: :report}
  @deps [
    config_loader: ConfigLoaderMock,
    beam_source: BeamSourceMock,
    write_recorder: WriteRecorderMock
  ]
  @recorder %{table: :fake, handler: :fake, event: @event}
  @test_name "MyApp.OrdersTest test pays"

  setup_all do
    [{module, binary}] =
      compile_unloaded(
        "defmodule AnchorFixtures.Managers.BackstopTest.M do\n  def f, do: 1\nend\n"
      )

    %{beam: BeamReader.decode(binary, app: :app, path: "#{@ebin}/#{module}.beam")}
  end

  defp config(declare) do
    %Config{
      path: "/repo/.anchor.yml",
      aggregates: %Aggregates.Config{
        declare:
          Enum.map(declare, fn {name, tables} ->
            %Declaration{name: name, tables: tables, sites: [:config]}
          end)
      }
    }
  end

  defp expect_config(result), do: expect(ConfigLoaderMock, :load_in, fn "/repo" -> result end)

  defp expect_beams(beams),
    do: Mox.expect(BeamSourceMock, :read_ebins, fn [{:app, @ebin}] -> beams end)

  defp session(escapes \\ :report) do
    %{
      index: %Index{by_table: %{"orders" => "A", "invoices" => "B"}},
      escapes: escapes,
      recorder: @recorder,
      write_recorder: WriteRecorderMock
    }
  end

  defp event(table, tx, overrides \\ []) do
    BackstopEvent.new(
      Map.merge(
        %{pid: self(), test_pid: self(), table: table, kind: :insert, tx: tx, emitted_by: :test},
        Map.new(overrides)
      )
    )
  end

  defp expect_verdict(events, attached? \\ true) do
    me = self()
    expect(WriteRecorderMock, :take_events, fn @recorder, ^me -> events end)
    expect(WriteRecorderMock, :recorder_attached?, fn @recorder -> attached? end)
  end

  describe "start/2" do
    test "loads the config and beams, builds the index and attaches the recorder", %{beam: beam} do
      expect_config({:ok, config([{"A", ["orders"]}, {"B", ["invoices"]}])})
      expect_beams([beam])

      expect(WriteRecorderMock, :attach_recorder, fn @event, EctoTransactionProbe ->
        {:ok, @recorder}
      end)

      session = Backstop.start(@request, @deps)

      assert session.recorder == @recorder
      assert session.escapes == :report
      assert session.write_recorder == WriteRecorderMock
      assert Index.aggregate_of(session.index, "orders") == {:ok, "A"}
      assert Index.aggregate_of(session.index, "invoices") == {:ok, "B"}
    end

    test "M1: a config with no aggregates: section raises with Fix:, attaching nothing" do
      expect_config({:ok, %Config{path: "/repo/.anchor.yml", aggregates: nil}})

      error = assert_raise ArgumentError, fn -> Backstop.start(@request, @deps) end

      assert error.message =~
               "/repo/.anchor.yml has no aggregates: section. Fix: declare aggregates"
    end

    test "M1: a config that does not load raises with Fix:, naming the reason" do
      expect_config({:error, {:config_not_found, ["/repo/.anchor.yml"]}})

      error = assert_raise ArgumentError, fn -> Backstop.start(@request, @deps) end

      assert error.message =~
               "could not load .anchor.yml under /repo: {:config_not_found, [\"/repo/.anchor.yml\"]}. Fix:"
    end

    test "M2: zero declared aggregates raises: the backstop checks nothing", %{beam: beam} do
      expect_config({:ok, config([])})
      expect_beams([beam])

      error = assert_raise ArgumentError, fn -> Backstop.start(@request, @deps) end

      assert error.message ==
               "anchor backstop: the backstop checks nothing: no aggregate is declared. Fix: " <>
                 "declare aggregates (mix anchor.propose --level aggregate)."
    end

    test "M2: declare: none raises: the backstop checks nothing", %{beam: beam} do
      expect_config({:ok, %Config{aggregates: %Aggregates.Config{none: "no database"}}})
      expect_beams([beam])

      error = assert_raise ArgumentError, fn -> Backstop.start(@request, @deps) end
      assert error.message =~ "the backstop checks nothing"
    end

    test "M3: zero beams read raises, naming the ebins" do
      expect_config({:ok, config([{"A", ["orders"]}])})
      expect_beams([{:error, %{path: @ebin, module: nil, reason: :enoent}}])

      error = assert_raise ArgumentError, fn -> Backstop.start(@request, @deps) end
      assert error.message =~ "no beam was read from #{@ebin}. Fix:"
    end

    test "a recorder that cannot attach raises with Fix:", %{beam: beam} do
      expect_config({:ok, config([{"A", ["orders"]}])})
      expect_beams([beam])

      expect(WriteRecorderMock, :attach_recorder, fn @event, _probe ->
        {:error, :already_exists}
      end)

      error = assert_raise ArgumentError, fn -> Backstop.start(@request, @deps) end
      assert error.message =~ "could not attach to [:app, :repo, :query]: :already_exists. Fix:"
    end
  end

  describe "install/1, installed!/1, watch/2" do
    test "install keeps the session through the recorder" do
      session = session()
      expect(WriteRecorderMock, :install_session, fn ^session -> :ok end)
      assert Backstop.install(session) == :ok
    end

    test "installed! returns the kept session" do
      session = session()
      expect(WriteRecorderMock, :installed_session, fn -> {:ok, session} end)
      assert Backstop.installed!(WriteRecorderMock) == session
    end

    test "F1: installed! before any attach raises: call attach!/1 in test_helper.exs" do
      expect(WriteRecorderMock, :installed_session, fn -> :error end)

      error = assert_raise ArgumentError, fn -> Backstop.installed!(WriteRecorderMock) end
      assert error.message =~ "Fix: call Anchor.Backstop.attach!/1 in test_helper.exs."
    end

    test "watch marks the pid" do
      me = self()
      expect(WriteRecorderMock, :watch_pid, fn @recorder, ^me -> :ok end)
      assert Backstop.watch(session(), me) == :ok
    end
  end

  describe "verdict!/3" do
    test "M4: a detached handler fails the test, whatever was recorded" do
      expect_verdict([], false)

      error =
        assert_raise ExUnit.AssertionError, fn ->
          Backstop.verdict!(session(), self(), @test_name)
        end

      assert error.message =~ "#{@test_name}: the backstop handler was detached"
    end

    test "M5: a crossing fails the test, naming both aggregates, with the outbox Fix:" do
      r1 = make_ref()
      expect_verdict([event("orders", {:in_tx, r1}), event("invoices", {:in_tx, r1})])

      expect(WriteRecorderMock, :add_counts, fn @recorder, %{tests: 1, crossings: 1} -> :ok end)

      error =
        assert_raise ExUnit.AssertionError, fn ->
          Backstop.verdict!(session(), self(), @test_name)
        end

      assert error.message ==
               "MyApp.OrdersTest test pays: transaction wrote aggregates A (table orders) and B " <>
                 "(table invoices). Fix: write B's change as an outbox row in A, consumed by " <>
                 "B's owner; or declare one aggregate holding both."
    end

    test "M6: one aggregate per transaction passes, and is counted" do
      r1 = make_ref()
      expect_verdict([event("orders", {:in_tx, r1})])
      expect(WriteRecorderMock, :add_counts, fn @recorder, %{tests: 1, crossings: 0} -> :ok end)

      assert Backstop.verdict!(session(), self(), @test_name) == :ok
    end

    test "M7: an escape fails the test under escapes: :fail" do
      expect_verdict([event("orders", {:in_tx, make_ref()}, emitted_by: :other)])
      expect(WriteRecorderMock, :add_counts, fn @recorder, %{other_process: 1} -> :ok end)

      error =
        assert_raise ExUnit.AssertionError, fn ->
          Backstop.verdict!(session(:fail), self(), @test_name)
        end

      assert error.message =~ "1 writes could not be tied to a transaction (1 other-process)"
    end

    test "M7: under escapes: :report the escape passes and is kept for the summary" do
      expect_verdict([event("orders", {:in_tx, make_ref()}, emitted_by: :other)])

      expect(WriteRecorderMock, :add_counts, fn @recorder,
                                                %{tests: 1, crossings: 0, other_process: 1} ->
        :ok
      end)

      assert Backstop.verdict!(session(:report), self(), @test_name) == :ok
    end
  end

  describe "summary/1" do
    test "is the summary line of the recorder's totals" do
      totals = %{
        tests: 3,
        crossings: 0,
        other_process: 1,
        no_source: 0,
        undeclared_table: 0,
        unclassified: 0,
        outside_transaction: 2,
        unattributed: 0
      }

      expect(WriteRecorderMock, :read_totals, fn @recorder -> totals end)

      assert Backstop.summary(session()) ==
               "anchor backstop: 3 tests watched, 0 crossings; escapes: 1 other-process, " <>
                 "0 no-source, 0 undeclared, 0 unclassified; not judged: 2 outside a " <>
                 "transaction, 0 unattributed"
    end
  end
end
