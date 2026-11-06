# DND-5691: the fixture suite. Test names are what coverage_attribution_integration_test.exs
# asserts on; a pair "x a" then "x b" runs in that order, at seed 0.

defmodule AnchorFixtures.Attribution.CompileTime do
  # N4: a test file's module body runs at compile time.
  AnchorFixtures.Attribution.F.n4_compile()
end

defmodule AnchorFixtures.Attribution.LeakCases do
  use ExUnit.Case, async: false

  alias AnchorFixtures.Attribution.F

  import AnchorFixtures.Attribution.Shared

  # Parks under a registered name until the next test (or the clean process) says go.
  defp park(name, fun) do
    me = self()

    spawn(fn ->
      Process.register(self(), name)
      send(me, :registered)
      release(fun)
    end)

    receive(do: (:registered -> :ok))
  end

  defp release(fun) do
    receive do
      {:go, ack} ->
        fun.()
        send(ack, :done)
    end
  end

  defp go(name) do
    send(name, {:go, self()})
    receive(do: (:done -> :ok))
  end

  defp go_clean(name) do
    send(clean(), {:send, name, {:go, self()}})
    receive(do: (:done -> :ok))
  end

  # An owned process's label is never read, so these are released with no token.
  defp parked_task(start, name) do
    me = self()

    fun = fn ->
      Process.register(self(), name)
      send(me, {:running, name})
      release(fn -> apply(F, name, []) end)
    end

    start.(fun)
    receive(do: ({:running, ^name} -> :ok))
  end

  test "l1 spinner a" do
    me = self()

    spawn(fn ->
      F.l1_spinner()
      Process.register(self(), :attribution_l1)
      send(me, :started)
      release(&F.l1_after/0)
    end)

    receive(do: (:started -> :ok))
  end

  test "l1 spinner b" do
    go_clean(:attribution_l1)
  end

  test "l2 released a" do
    park(:attribution_l2, &F.l2_released/0)
  end

  test "l2 released b" do
    go(:attribution_l2)
  end

  test "l3 unlabelled a" do
    park(:attribution_l3, &F.l3_unlabelled/0)
  end

  test "l3 unlabelled b" do
    go_clean(:attribution_l3)
  end

  test "l4 grandchild a" do
    me = self()

    {_pid, ref} =
      spawn_monitor(fn ->
        spawn(fn ->
          Process.register(self(), :attribution_l4)
          send(me, :registered)
          release(&F.l4_grandchild/0)
        end)
      end)

    receive(do: ({:DOWN, ^ref, _, _, _} -> :ok))
    receive(do: (:registered -> :ok))
  end

  test "l4 grandchild b" do
    go(:attribution_l4)
  end

  test "l5 port a" do
    me = self()

    spawn(fn ->
      {_out, 0} = System.cmd("true", [])
      Process.register(self(), :attribution_l5)
      send(me, :registered)
      release(&F.l5_port/0)
    end)

    receive(do: (:registered -> :ok))
  end

  test "l5 port b" do
    go(:attribution_l5)
  end

  test "l6 task a" do
    parked_task(&Task.Supervisor.start_child(task_sup(), &1), :l6_task)
  end

  test "l6 task b" do
    go_clean(:l6_task)
  end

  test "l8 task reply a" do
    parked_task(
      &Task.Supervisor.start_child(task_sup(), :erlang, :apply, [&1, []], restart: :temporary),
      :l8_task_reply
    )
  end

  test "l8 task reply b" do
    go_clean(:l8_task_reply)
  end

  test "l9 task nolink a" do
    parked_task(&Task.Supervisor.async_nolink(task_sup(), &1), :l9_task_nolink)
  end

  test "l9 task nolink b" do
    go_clean(:l9_task_nolink)
  end
end

defmodule AnchorFixtures.Attribution.CleanCases do
  use ExUnit.Case, async: false

  alias AnchorFixtures.Attribution.F
  alias AnchorFixtures.Attribution.Hold
  alias AnchorFixtures.Attribution.Worker

  import AnchorFixtures.Attribution.Shared

  test "n1 awaited task" do
    Task.await(Task.async(&F.n1_task/0))
  end

  test "n2 start_supervised" do
    start_supervised!(Worker)
  end

  test "n3 linked idle server" do
    # Called inside the window, and still alive, idle, when the test returns.
    {:ok, pid} = Agent.start_link(fn -> :idle end)
    :ok = Agent.get(pid, fn :idle -> F.n3_linked() end)
  end

  test "n5 compiles code itself" do
    Code.compile_string("""
    defmodule AnchorFixtures.Attribution.CompiledInATest do
      AnchorFixtures.Attribution.F.n5_compiled()
    end
    """)
  end

  test "n6 server's own timer" do
    send(clean(), {:send, server(), {:n6_timer, self()}})
    receive(do: (:n6_acked -> :ok))
  end

  test "n7 server call" do
    :ok = GenServer.call(server(), :n7_call)
  end

  test "n9 late cast a" do
    GenServer.cast(server(), :n9_late_cast)
  end

  test "n9 late cast b" do
    Hold.release(:n9_release)
  end

  test "n10 stale timer a" do
    :ok = GenServer.call(server(), :n10_stale_timer)
  end

  test "n10 stale timer b" do
    Hold.release(:n10_release)
  end

  test "n11 lost its label" do
    send(clean(), {:send, self(), :ping})
    receive(do: (:ping -> :ok))
    :ok = GenServer.call(server(), :n11_handler)
    F.n11_own()
  end

  test "n12 apply_after inside its window" do
    {:ok, _ref} = :timer.apply_after(0, F, :ack, [:n12_apply_after, self()])
    receive(do: ({:acked, :n12_apply_after} -> :ok))
  end

  test "on_exit" do
    on_exit(fn ->
      F.on_exit_test()
      :ok = GenServer.call(server(), :on_exit_test_server)
    end)
  end

  # The runner took no label from this test's last message, so only exec_on_exit's
  # own label reaches the on_exit callback's server call.
  test "on_exit after the test lost its label" do
    on_exit(fn -> :ok = GenServer.call(server(), :on_exit_lost_server) end)
    send(clean(), {:send, self(), :ping})
    receive(do: (:ping -> :ok))
  end

  @tag skip: "a skipped test still opens a window, and has no process"
  test "skipped" do
    flunk("never runs")
  end

  @tag :excluded_fixture
  test "excluded" do
    flunk("never runs")
  end
end

defmodule AnchorFixtures.Attribution.SetupAllCases do
  use ExUnit.Case, async: false

  alias AnchorFixtures.Attribution.F

  import AnchorFixtures.Attribution.Shared

  setup_all do
    F.setup_body()

    on_exit(fn ->
      F.on_exit_module()
      :ok = GenServer.call(server(), :on_exit_module_server)
    end)

    :ok = GenServer.call(server(), :n13_setup_all)
    sup = start_supervised!(Task.Supervisor)

    me = self()

    spawn(fn ->
      Process.register(self(), :attribution_l7)
      send(me, :registered)

      receive do
        {:go, ack} ->
          F.l7_setup_all()
          send(ack, :done)
      end
    end)

    receive(do: (:registered -> :ok))
    %{sup: sup}
  end

  test "s1 setup_all's work reaches this test" do
    :ok
  end

  test "n14 a test's task under a setup_all supervisor", %{sup: sup} do
    Task.await(Task.Supervisor.async(sup, &F.n14_task/0))
  end
end

defmodule AnchorFixtures.Attribution.AfterSetupAllCases do
  use ExUnit.Case, async: false

  test "l7 released from the next module" do
    send(:attribution_l7, {:go, self()})
    receive(do: (:done -> :ok))
  end
end
