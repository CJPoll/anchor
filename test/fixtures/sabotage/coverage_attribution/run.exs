# DND-5691: the coverage run's real parts (CallTracer, CoverageCollector,
# CoverageMap) around a real ExUnit run, in its own VM, because nothing else can
# trace a whole ExUnit run from inside one. Run by coverage_attribution_test.exs:
#   elixir -pa <anchor ebin> run.exs <out.etf>
# Each case's function is its own, so the map says which call went where. Nothing
# here waits on a clock: a wait blocks on a message, or spins on a :counters word
# where a message would change the label being tested.
[out] = System.argv()

alias Anchor.Adapters.CallTracer
alias Anchor.Domain.Sabotage.CoverageMap
alias Anchor.Sabotage.CoverageCollector

defmodule AnchorFixtures.Attribution.F do
  @moduledoc false
  for name <- ~w(l1_spinner l1_after l2_released l3_unlabelled l4_grandchild l5_port l6_task
                 l7_setup_all l8_task_reply l9_task_nolink n1_task n2_supervised n4_compile
                 n5_compiled n6_timer n7_call n9_late_cast n10_stale_timer n11_handler n11_own
                 n12_apply_after n13_setup_all n14_task on_exit_test on_exit_module on_exit_test_server
                 on_exit_module_server on_exit_lost_server setup_body
                 start_supervised_init) do
    def unquote(String.to_atom(name))(), do: :ok
  end

  def ack(name, to) do
    apply(__MODULE__, name, [])
    send(to, {:acked, name})
  end
end

defmodule AnchorFixtures.Attribution.Server do
  @moduledoc false
  use GenServer
  alias AnchorFixtures.Attribution.F

  def init(state), do: {:ok, state}

  def handle_call(:n7_call, _from, state) do
    F.n7_call()
    {:reply, :ok, state}
  end

  def handle_call(:n13_setup_all, _from, state) do
    F.n13_setup_all()
    {:reply, :ok, state}
  end

  def handle_call(:n11_handler, _from, state) do
    F.n11_handler()
    {:reply, :ok, state}
  end

  def handle_call(:on_exit_test_server, _from, state) do
    F.on_exit_test_server()
    {:reply, :ok, state}
  end

  def handle_call(:on_exit_lost_server, _from, state) do
    F.on_exit_lost_server()
    {:reply, :ok, state}
  end

  def handle_call(:on_exit_module_server, _from, state) do
    F.on_exit_module_server()
    {:reply, :ok, state}
  end

  # A stale label on a server's timer. The message is armed here, under A's label,
  # and read only once B has opened; a timer message does not clear a token.
  def handle_call({:n10_stale_timer, flags}, from, state) do
    Process.send_after(self(), :n10_tick, 0)
    GenServer.reply(from, :ok)
    AnchorFixtures.Attribution.Spin.until_set(flags, 1)

    receive do
      :n10_tick -> F.n10_stale_timer()
    end

    :counters.put(flags, 2, 1)
    {:noreply, state}
  end

  # A late cast: the handler runs on past A's return, still holding A's label.
  def handle_cast({:n9_late_cast, flags}, state) do
    AnchorFixtures.Attribution.Spin.until_set(flags, 1)
    F.n9_late_cast()
    :counters.put(flags, 2, 1)
    {:noreply, state}
  end

  def handle_info({:n6_timer, ack}, state) do
    F.n6_timer()
    send(ack, :n6_acked)
    {:noreply, state}
  end
end

defmodule AnchorFixtures.Attribution.Spin do
  @moduledoc false
  def until_set(flags, index) do
    if :counters.get(flags, index) == 1 do
      :ok
    else
      :erlang.yield()
      until_set(flags, index)
    end
  end
end

defmodule AnchorFixtures.Attribution.Clean do
  @moduledoc false
  # Sends with no token: receiving a request gives it the requester's token, so it
  # clears its token before each send.
  def start, do: spawn(&loop/0)

  defp loop do
    receive do
      {:send, to, message} ->
        :seq_trace.set_token([])
        send(to, message)
        loop()
    end
  end
end

defmodule AnchorFixtures.Attribution.Shared do
  @moduledoc false
  def server, do: :persistent_term.get(:attribution_server)
  def clean, do: :persistent_term.get(:attribution_clean)
  def task_sup, do: :persistent_term.get(:attribution_task_sup)
end

defmodule AnchorFixtures.Attribution.Worker do
  @moduledoc false
  use GenServer

  def start_link(_arg), do: GenServer.start_link(__MODULE__, :ok)

  def init(:ok) do
    AnchorFixtures.Attribution.F.start_supervised_init()
    {:ok, :ok}
  end
end

# Started before tracing: nothing in a test owns them.
{:ok, server} = GenServer.start(AnchorFixtures.Attribution.Server, %{})
{:ok, task_sup} = Task.Supervisor.start_link()
:persistent_term.put(:attribution_server, server)
:persistent_term.put(:attribution_clean, AnchorFixtures.Attribution.Clean.start())
:persistent_term.put(:attribution_task_sup, task_sup)
:persistent_term.put(:attribution_flags, :counters.new(8, [:atomics]))

ExUnit.start(
  autorun: false,
  max_cases: 1,
  seed: 0,
  capture_log: false,
  formatters: [],
  exclude: [:excluded_fixture]
)

{:ok, collector} = CoverageCollector.start_link()
:ok = CallTracer.start(collector, [AnchorFixtures.Attribution.F])

# Compiled with tracing on, before any test starts: the compile-time call is
# ambient only because no window is open for it to land in.
Code.require_file("cases.exs", __DIR__)
results = ExUnit.run()
:ok = CallTracer.stop()
{:ok, state} = CallTracer.collected(collector)

meta = %{
  commit: nil,
  elixir: System.version(),
  otp: "x",
  modules_traced: 1,
  suite_exit: if(results.failures == 0, do: 0, else: 1),
  total: results.total,
  root: nil
}

File.write!(out, :erlang.term_to_binary({results, CoverageMap.finalize(state, meta)}))
System.halt(0)
