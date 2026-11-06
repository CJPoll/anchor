defmodule Anchor.BackstopTest do
  # DND-5480: the backstop's Framework entry point, with the Manager's ports
  # doubled (ConfigLoader and WriteRecorder by Hammox, BeamSource by Mox) and
  # ExUnit's two hooks (`after_suite`, `on_exit`) passed in through `deps:`,
  # so the test holds each callback and runs it itself. What the entry point
  # does: the query event it builds from the repo, the session it installs,
  # the summary it prints at suite end, the pid and test name its on_exit
  # judges, and its refusals before anything starts.
  #
  # Sabotage record: ../sabotage_records/backstop-20261106-dnd_5480_test_backstop.md
  use ExUnit.Case, async: true

  import Anchor.Test.BeamFixtures
  import ExUnit.CaptureIO
  import Hammox

  alias Anchor.Adapters.BeamReader
  alias Anchor.BeamSourceMock
  alias Anchor.Config
  alias Anchor.ConfigLoaderMock
  alias Anchor.Domain.Aggregates
  alias Anchor.Domain.Aggregates.Declaration
  alias Anchor.Domain.Aggregates.Index
  alias Anchor.WriteRecorderMock

  setup :verify_on_exit!

  defmodule NoPrefixRepo do
    @moduledoc false
    def config, do: [otp_app: :anchor]
  end

  defmodule PrefixRepo do
    @moduledoc false
    def config, do: [telemetry_prefix: [:fw_app, :repo]]
  end

  @ebin "/repo/_build/test/lib/anchor/ebin"
  @recorder %{table: :fake, handler: :fake, event: [:fw_app, :repo, :query]}
  @deps [
    config_loader: ConfigLoaderMock,
    beam_source: BeamSourceMock,
    write_recorder: WriteRecorderMock
  ]

  defp session do
    %{
      index: %Index{by_table: %{"orders" => "A", "invoices" => "B"}},
      escapes: :report,
      recorder: @recorder,
      write_recorder: WriteRecorderMock
    }
  end

  describe "attach!/1" do
    setup do
      [{module, binary}] =
        compile_unloaded("defmodule AnchorFixtures.BackstopTest.M do\n  def f, do: 1\nend\n")

      %{beam: BeamReader.decode(binary, app: :anchor, path: "#{@ebin}/#{module}.beam")}
    end

    test "attaches to the repo's query event, installs the session and prints the summary at suite end",
         %{beam: beam} do
      test_pid = self()

      expect(ConfigLoaderMock, :load_in, fn "/repo" ->
        {:ok,
         %Config{
           path: "/repo/.anchor.yml",
           aggregates: %Aggregates.Config{
             declare: [%Declaration{name: "A", tables: ["orders"], sites: [:config]}]
           }
         }}
      end)

      Mox.expect(BeamSourceMock, :read_ebins, fn [{:anchor, @ebin}] -> [beam] end)

      expect(WriteRecorderMock, :attach_recorder, fn [:fw_app, :repo, :query], _probe ->
        {:ok, @recorder}
      end)

      expect(WriteRecorderMock, :install_session, fn %{recorder: @recorder, escapes: :fail} ->
        :ok
      end)

      after_suite = fn callback -> send(test_pid, {:after_suite, callback}) end

      assert Anchor.Backstop.attach!(
               repo: PrefixRepo,
               root: "/repo",
               ebins: [@ebin],
               escapes: :fail,
               deps: [{:after_suite, after_suite} | @deps]
             ) == :ok

      assert_received {:after_suite, callback}

      totals = Map.new(Aggregates.Backstop.total_keys(), &{&1, 0})
      expect(WriteRecorderMock, :read_totals, fn @recorder -> %{totals | tests: 4} end)

      assert capture_io(fn -> callback.(%{}) end) =~
               "anchor backstop: 4 tests watched, 0 crossings; escapes:"
    end

    test "F2: a repo with no telemetry prefix raises, naming the repo" do
      error =
        assert_raise ArgumentError, fn ->
          Anchor.Backstop.attach!(repo: NoPrefixRepo, deps: @deps)
        end

      assert error.message ==
               "anchor backstop: Anchor.BackstopTest.NoPrefixRepo has no telemetry prefix. Fix: " <>
                 "pass repo: an Ecto repo (use Ecto.Repo), whose config/0 holds :telemetry_prefix."
    end

    test "F2: a module that is not a repo at all raises, naming it" do
      error =
        assert_raise ArgumentError, fn -> Anchor.Backstop.attach!(repo: String, deps: @deps) end

      assert error.message =~ "anchor backstop: String has no telemetry prefix. Fix:"
    end

    test "an escapes: mode other than :report or :fail raises with Fix:" do
      error =
        assert_raise ArgumentError, fn ->
          Anchor.Backstop.attach!(repo: PrefixRepo, escapes: :warn, deps: @deps)
        end

      assert error.message =~ "escapes: must be :report or :fail, got: :warn. Fix:"
    end

    test "a missing repo: raises with Fix:" do
      error = assert_raise ArgumentError, fn -> Anchor.Backstop.attach!(escapes: :fail) end
      assert error.message =~ "anchor backstop: attach!/1 needs repo:. Fix:"
    end

    test "an unknown option raises with Fix:, never read as the default" do
      error =
        assert_raise ArgumentError, fn ->
          Anchor.Backstop.attach!(repo: PrefixRepo, escape: :fail)
        end

      assert error.message ==
               "anchor backstop: attach!/1 does not know the option(s) :escape. Fix: pass only " <>
                 "repo:, ebins:, root:, escapes:."
    end
  end

  describe "watch/2" do
    test "watches the test's pid and registers an on_exit that judges it under its name" do
      test_pid = self()
      session = session()
      expect(WriteRecorderMock, :installed_session, fn -> {:ok, session} end)
      expect(WriteRecorderMock, :watch_pid, fn @recorder, ^test_pid -> :ok end)
      on_exit = fn callback -> send(test_pid, {:on_exit, callback}) end

      assert Anchor.Backstop.watch(%{module: MyApp.OrdersTest, test: :"test pays"},
               write_recorder: WriteRecorderMock,
               on_exit: on_exit
             ) == :ok

      assert_received {:on_exit, verdict}

      r1 = make_ref()

      events =
        for table <- ["orders", "invoices"] do
          Aggregates.BackstopEvent.new(%{
            pid: test_pid,
            test_pid: test_pid,
            table: table,
            kind: :insert,
            tx: {:in_tx, r1},
            emitted_by: :test
          })
        end

      expect(WriteRecorderMock, :take_events, fn @recorder, ^test_pid -> events end)
      expect(WriteRecorderMock, :recorder_attached?, fn @recorder -> true end)
      expect(WriteRecorderMock, :add_counts, fn @recorder, _counts -> :ok end)

      error = assert_raise ExUnit.AssertionError, verdict

      assert error.message =~
               "MyApp.OrdersTest test pays: transaction wrote aggregates A (table orders)"
    end

    test "F1: watch/1 before attach!/1 raises: call attach!/1 in test_helper.exs" do
      error =
        assert_raise ArgumentError, fn ->
          Anchor.Backstop.watch(%{module: __MODULE__, test: :"test F1"})
        end

      assert error.message ==
               "anchor backstop: watch/1 was called before the backstop was attached. " <>
                 "Fix: call Anchor.Backstop.attach!/1 in test_helper.exs."
    end
  end
end
