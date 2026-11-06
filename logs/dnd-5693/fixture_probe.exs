# DND-5693 fixture probe (throwaway, CI only): Q1, Q2, Q3, and the fixture half of Q6.
#   elixir logs/dnd-5693/fixture_probe.exs
# No sleep and no time-based verdict. A wait blocks on an event, except the two that
# spin on a shared counter: a message there would change the label being measured.

defmodule Spike.Fix do
  @moduledoc false
  # The traced function: its argument names the case, and the match spec adds the
  # token's label and the trace control word as read by the VM at call time.
  def mark(tag), do: :erlang.phash2(tag)
  def plain(tag), do: :erlang.phash2(tag)
end

defmodule Spike.Server do
  @moduledoc false
  use GenServer
  alias Spike.Fix

  def init(state), do: {:ok, state}

  def handle_call({:mark, tag}, _from, state) do
    Fix.mark(tag)
    {:reply, :ok, state, {:continue, {:after_reply, tag}}}
  end

  def handle_cast({:mark, tag, ack}, state) do
    Fix.mark(tag)
    send(ack, {:acked, tag})
    {:noreply, state}
  end

  def handle_cast({:mark_then_timeout, tag, ack}, state) do
    Fix.mark(tag)
    {:noreply, Map.put(state, :timeout_ack, {tag, ack}), 0}
  end

  def handle_continue({:after_reply, tag}, state) do
    Fix.mark({:after_reply, tag})
    {:noreply, state}
  end

  def handle_info(:timeout, %{timeout_ack: {tag, ack}} = state) do
    Fix.mark({:after_timeout, tag})
    send(ack, {:acked, tag})
    {:noreply, Map.delete(state, :timeout_ack)}
  end

  def handle_info({:mark, tag, ack}, state) do
    Fix.mark(tag)
    send(ack, {:acked, tag})
    {:noreply, state}
  end
end

defmodule Spike.Clean do
  @moduledoc false
  # Sends with no token: receiving the request gives it the requester's token, so
  # it clears its token before it sends.
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

defmodule Spike.Timer do
  @moduledoc false
  def mark_ack(tag, ack) do
    Spike.Fix.mark(tag)
    send(ack, {:acked, tag})
  end
end

defmodule Spike.Tracer do
  @moduledoc false
  # Keeps every message; the fixture is small.
  def start, do: spawn(fn -> loop([]) end)

  def take(pid) do
    send(pid, {:take, self()})

    receive do
      {:taken, messages} -> messages
    end
  end

  defp loop(acc) do
    receive do
      {:take, from} ->
        send(from, {:taken, Enum.reverse(acc)})
        loop(acc)

      message ->
        loop([message | acc])
    end
  end
end

ExUnit.start(autorun: false, max_cases: 1, seed: 0, capture_log: false, formatters: [])

defmodule Spike.Shared do
  @moduledoc false
  def server, do: :persistent_term.get(:spike_server)
  def clean, do: :persistent_term.get(:spike_clean)
  def task_sup, do: :persistent_term.get(:spike_task_sup)

  def await_ack(tag) do
    receive do
      {:acked, ^tag} -> :ok
    end
  end
end

defmodule Spike.CaseA do
  use ExUnit.Case, async: false
  import Spike.Shared
  alias Spike.Fix

  setup_all do
    Fix.mark(:setup_all_body)
    on_exit(fn -> Fix.mark(:setup_all_on_exit) end)
    parent = self()
    pid = spawn(fn -> Fix.mark(:setup_all_spawned); send(parent, :spawned_done) end)
    ref = Process.monitor(pid)
    receive do
      :spawned_done -> :ok
    end
    receive do
      {:DOWN, ^ref, _, _, _} -> :ok
    end
    Fix.mark(:setup_all_after_down)
    :ok
  end

  setup do
    Fix.mark(:setup_block)
    :ok
  end

  test "direct" do
    Fix.mark(:test_body)
    on_exit(fn -> Fix.mark(:test_on_exit) end)
  end

  test "genserver call" do
    :ok = GenServer.call(server(), {:mark, :server_handle_call})
    Fix.mark(:test_after_call_reply)
  end

  test "genserver cast" do
    GenServer.cast(server(), {:mark, :server_handle_cast, self()})
    await_ack(:server_handle_cast)
  end

  test "server after an unlabelled message" do
    :ok = GenServer.call(server(), {:mark, :server_before_unlabelled})
    send(clean(), {:send, server(), {:mark, :server_on_unlabelled_message, self()}})
    await_ack(:server_on_unlabelled_message)
  end

  test "server timeout keeps its label" do
    GenServer.cast(server(), {:mark_then_timeout, :server_timeout_case, self()})
    await_ack(:server_timeout_case)
  end

  test "task async" do
    Task.await(Task.async(fn -> Fix.mark(:task_async) end))
    Fix.mark(:test_after_task_await)
  end

  test "task start" do
    me = self()
    {:ok, _pid} = Task.start(fn -> Fix.mark(:task_start); send(me, :task_done) end)
    receive do
      :task_done -> :ok
    end
  end

  test "spawn" do
    me = self()
    spawn(fn -> Fix.mark(:spawn); send(me, :done) end)
    receive do
      :done -> :ok
    end
  end

  test "spawn link" do
    me = self()
    spawn_link(fn -> Fix.mark(:spawn_link); send(me, :done) end)
    receive do
      :done -> :ok
    end
  end

  test "grandchild spawn" do
    me = self()

    spawn(fn ->
      spawn(fn -> Fix.mark(:grandchild); send(me, :done) end)
    end)

    receive do
      :done -> :ok
    end
  end

  test "task supervisor start child" do
    me = self()
    {:ok, _pid} =
      Task.Supervisor.start_child(task_sup(), fn ->
        Fix.mark(:task_supervisor_child)
        send(me, :done)
      end)

    receive do
      :done -> :ok
    end
  end

  test "start supervised server" do
    pid = start_supervised!(%{id: :spike_sup_server, start: {GenServer, :start_link, [Spike.Server, %{}]}})
    send(clean(), {:send, pid, {:mark, :supervised_server_unlabelled, self()}})
    await_ack(:supervised_server_unlabelled)
    :ok = GenServer.call(pid, {:mark, :supervised_server_call})
  end

  test "system cmd in the test process" do
    {_out, 0} = System.cmd("echo", ["x"])
    Fix.mark(:test_after_system_cmd)
  end

  test "system cmd in a task" do
    Task.await(
      Task.async(fn ->
        Fix.mark(:task_before_system_cmd)
        {_out, 0} = System.cmd("echo", ["x"])
        Fix.mark(:task_after_system_cmd)
      end)
    )

    Fix.mark(:test_after_task_with_cmd)
  end

  test "port open" do
    port = Port.open({:spawn_executable, System.find_executable("echo")}, [:binary, :exit_status, args: ["x"]])

    receive do
      {^port, {:exit_status, 0}} -> :ok
    end

    Fix.mark(:test_after_port_exit)
  end

  test "process send_after to self" do
    Process.send_after(self(), :tick, 1)

    receive do
      :tick -> :ok
    end

    Fix.mark(:test_after_send_after)
  end

  test "process send_after to the server" do
    Process.send_after(server(), {:mark, :server_on_send_after, self()}, 1)
    await_ack(:server_on_send_after)
  end

  test "timer apply_after" do
    {:ok, _ref} = :timer.apply_after(1, Spike.Timer, :mark_ack, [:timer_apply_after, self()])
    await_ack(:timer_apply_after)
  end

  test "test process after an unlabelled message" do
    Fix.mark(:test_before_unlabelled)
    send(clean(), {:send, self(), :unlabelled_ping})

    receive do
      :unlabelled_ping -> :ok
    end

    Fix.mark(:test_after_unlabelled)
  end

  test "test process after a monitor down" do
    {pid, ref} = spawn_monitor(fn -> :ok end)
    _ = pid

    receive do
      {:DOWN, ^ref, _, _, _} -> :ok
    end

    Fix.mark(:test_after_down)
  end

  test "test process after an exit signal message" do
    Process.flag(:trap_exit, true)
    pid = spawn_link(fn -> :ok end)

    receive do
      {:EXIT, ^pid, _} -> :ok
    end

    Fix.mark(:test_after_exit_message)
  end

  test "server call after the label was lost" do
    send(clean(), {:send, self(), :unlabelled_ping})

    receive do
      :unlabelled_ping -> :ok
    end

    :ok = GenServer.call(server(), {:mark, :server_call_from_unlabelled_test})
    Fix.mark(:test_after_call_from_unlabelled)
  end

  test "logger and io in the test process" do
    require Logger
    Logger.debug("spike")
    IO.write(:stderr, "")
    Fix.mark(:test_after_logger_and_io)
  end

  test "file and code server in the test process" do
    _ = File.read!(__ENV__.file)
    _ = :code.which(Spike.Fix)
    Fix.mark(:test_after_file_and_code)
  end

  # Leak 1: spinning with no receive; it keeps its label in the next test's window.
  test "leak spinner a" do
    counter = :counters.new(2, [:atomics])
    :persistent_term.put(:spike_spin_counter, counter)
    me = self()

    spawn(fn ->
      Fix.mark(:leak_spinner_start)
      send(me, :started)
      spin(counter)
    end)

    receive do
      :started -> :ok
    end
  end

  test "leak spinner b" do
    counter = :persistent_term.get(:spike_spin_counter)
    seen = :counters.get(counter, 1)
    wait_past(counter, seen)
    :counters.put(counter, 2, 1)
  end

  # Leak 2: a process of test a released in test b by test b's own message.
  test "leak released by next test a" do
    me = self()

    spawn(fn ->
      Process.register(self(), :spike_leak_released)
      send(me, :registered)

      receive do
        {:go, ack} ->
          Fix.mark(:leak_after_labelled_release)
          send(ack, :done)
      end
    end)

    receive do
      :registered -> :ok
    end
  end

  test "leak released by next test b" do
    send(:spike_leak_released, {:go, self()})

    receive do
      :done -> :ok
    end
  end

  # Leak 3: the same, released by an unlabelled message.
  test "leak released unlabelled a" do
    me = self()

    spawn(fn ->
      Process.register(self(), :spike_leak_clean)
      send(me, :registered)

      receive do
        {:go, ack} ->
          Fix.mark(:leak_after_unlabelled_release)
          send(ack, :done)
      end
    end)

    receive do
      :registered -> :ok
    end
  end

  test "leak released unlabelled b" do
    send(clean(), {:send, :spike_leak_clean, {:go, self()}})

    receive do
      :done -> :ok
    end
  end

  # Leak 4: a task that runs a port and outlives its test (the git adapter shape).
  test "leak after a port a" do
    me = self()

    spawn(fn ->
      {_out, 0} = System.cmd("echo", ["x"])
      Process.register(self(), :spike_leak_port)
      send(me, :registered)
      counter = :persistent_term.get(:spike_port_counter)
      spin_marked(counter)
    end)

    receive do
      :registered -> :ok
    end
  end

  test "leak after a port b" do
    counter = :persistent_term.get(:spike_port_counter)
    wait_past(counter, :counters.get(counter, 1))
    :counters.put(counter, 2, 1)
  end

  defp spin(counter) do
    case :counters.get(counter, 2) do
      1 ->
        :ok

      _running ->
        Fix.mark(:leak_spinner_call)
        :counters.add(counter, 1, 1)
        spin(counter)
    end
  end

  defp spin_marked(counter) do
    case :counters.get(counter, 2) do
      1 ->
        :ok

      _running ->
        Fix.mark(:leak_after_port_call)
        :counters.add(counter, 1, 1)
        spin_marked(counter)
    end
  end

  # Spins until the other process's counter moves, yielding each turn; no clock.
  defp wait_past(counter, seen) do
    if :counters.get(counter, 1) > seen do
      :ok
    else
      :erlang.yield()
      wait_past(counter, seen)
    end
  end
end

defmodule Spike.Probe do
  @moduledoc false
  alias Spike.Fix

  @label {:element, 2, {:get_seq_token}}

  def say(text), do: IO.puts(text)

  # ---- Q3: which spec forms the VM accepts, and what each one does.
  def q3 do
    say("Q3 forms: compile, then real calls under label 7, label 8, and no token")

    forms = [
      {"guard get_seq_token (ticket's form)",
       [{:_, [{:"=/=", @label, 7}], [{:message, true}]}]},
      {"guard is_seq_trace with a no-token clause",
       [{:_, [{:is_seq_trace}], [{:message, :has_token}]}, {:_, [], [{:message, :no_token}]}]},
      {"body message of a computed boolean",
       [{:_, [{:is_seq_trace}], [{:message, {:"=/=", @label, 7}}]}, {:_, [], [{:message, :no_token}]}]},
      {"body andalso with a payload last",
       [
         {:_, [{:is_seq_trace}], [{:message, {:andalso, {:"=/=", @label, 7}, {{@label, {:get_tcw}}}}}]},
         {:_, [], [{:message, :no_token}]}
       ]},
      {"body andalso with an atom last",
       [
         {:_, [{:is_seq_trace}], [{:message, {:andalso, {:"=/=", @label, 7}, :seen}}]},
         {:_, [], [{:message, :no_token}]}
       ]},
      {"body orelse: false, or payload (inverted)",
       [
         {:_, [{:is_seq_trace}], [{:message, {:orelse, {:"==", @label, 7}, {{@label}}}}]},
         {:_, [], [{:message, :no_token}]}
       ]},
      {"body element of a selected index",
       [
         {:_, [{:is_seq_trace}],
          [{:message, {:element, {:+, 1, {:band, 1, {:bxor, @label, 7}}}, {{false, {{@label}}}}}}]},
         {:_, [], [{:message, :no_token}]}
       ]},
      {"tcw guard plus label-read andalso (the suppression clause)",
       [
         {:_, [{:is_seq_trace}, {:"==", {:get_tcw}, 0}],
          [{:message, {:andalso, {:"=/=", @label, 7}, {{@label, {:get_tcw}}}}}]},
         {:_, [{:is_seq_trace}], [{:message, {{@label, {:get_tcw}}}}]},
         {:_, [], [{:message, :no_token}]}
       ]},
      {"no-token silenced by guard",
       [{:_, [{:not, {:is_seq_trace}}], [{:message, false}]}, {:_, [], [{:message, {{@label}}}]}]},
      {"self plus tcw guard, compile only: the pid is the probe's, so the guard cannot match (fixture_k measures it)",
       [{:_, [{:"==", {:self}, {:const, self()}}, {:"==", {:get_tcw}, 0}], [{:message, false}]}, {:_, [], [{:message, :traced}]}]}
    ]

    for {name, spec} <- forms, do: q3_form(name, spec)
  end

  defp q3_form(name, spec) do
    compiled = :erlang.match_spec_test([:x], spec, :trace)
    say("Q3 FORM #{name}: match_spec_test=#{inspect(compiled, limit: 8)}")

    case compiled do
      {:ok, _, _, _} -> q3_real(spec)
      {:error, _} -> say("Q3 FORM   refused by the VM: no real run")
    end
  end

  defp q3_real(spec) do
    tracer = Spike.Tracer.start()
    :erlang.trace_pattern({Fix, :plain, 1}, spec, [:global])

    outcome =
      for {who, token} <- [{"label=7", 7}, {"label=8", 8}, {"no_token", nil}] do
        {pid, ref} =
          spawn_monitor(fn ->
            receive do
              :go -> :ok
            end

            if token, do: :seq_trace.set_token(:label, token)
            Fix.plain(who)
          end)

        :erlang.trace(pid, true, [:call, {:tracer, tracer}])
        send(pid, :go)

        receive do
          {:DOWN, ^ref, _, _, _} -> :ok
        end

        delivered = :erlang.trace_delivered(pid)

        receive do
          {:trace_delivered, ^pid, ^delivered} -> :ok
        end

        {who, seen(tracer, who)}
      end

    :erlang.trace_pattern({Fix, :plain, 1}, false, [:global])
    Process.exit(tracer, :kill)
    say("Q3 FORM   real=#{inspect(outcome, limit: :infinity)}")
  end

  defp seen(tracer, who) do
    tracer
    |> Spike.Tracer.take()
    |> Enum.filter(&match?({:trace, _, :call, {_, _, [^who]}, _}, &1) or match?({:trace, _, :call, {_, _, [^who]}}, &1))
    |> Enum.map(fn
      {:trace, _, :call, _, extra} -> {:message, extra}
      {:trace, _, :call, _} -> :plain_message
    end)
  end

  # ---- Q1 + Q2 + the Q6 fixture.
  def causal do
    server = start_unlabelled(fn -> GenServer.start(Spike.Server, %{}) end)
    clean = Spike.Clean.start()
    task_sup = start_unlabelled(fn -> Task.Supervisor.start_link() end)
    :persistent_term.put(:spike_server, server)
    :persistent_term.put(:spike_clean, clean)
    :persistent_term.put(:spike_task_sup, task_sup)
    :persistent_term.put(:spike_port_counter, :counters.new(2, [:atomics]))

    tracer = Spike.Tracer.start()
    :erlang.system_flag(:trace_control_word, 0)

    call_spec = [
      {:_, [{:is_seq_trace}], [{:message, {{@label, {:get_tcw}}}}]},
      {:_, [], [{:message, {{:none, {:get_tcw}}}}]}
    ]

    1 = :erlang.trace_pattern({Fix, :mark, 1}, call_spec, [:global])

    window = [{[:_, :"$1"], [], [{:set_tcw, {:+, {:get_tcw}, 1}}, {:message, {{:"$1", {:get_tcw}}}}]}]
    {:module, _} = Code.ensure_loaded(ExUnit.EventManager)
    1 = :erlang.trace_pattern({ExUnit.EventManager, :test_started, 2}, window, [:global])
    1 = :erlang.trace_pattern({ExUnit.EventManager, :test_finished, 2}, window, [:global])

    # Q1: the label is set in the test's own process, from the word test_started
    # set; an even word means this register/1 is a setup_all process.
    entry = [
      {:_, [{:"==", {:band, {:get_tcw}, 1}, 1}],
       [{:set_seq_token, :label, {:get_tcw}}, {:message, {{:entry_test, {:get_tcw}}}}]},
      {:_, [], [{:message, {{:entry_module, {:get_tcw}}}}]}
    ]

    {:module, _} = Code.ensure_loaded(ExUnit.OnExitHandler)
    1 = :erlang.trace_pattern({ExUnit.OnExitHandler, :register, 1}, entry, [:global])

    # setup_all and on_exit have no per-test entry: private functions of the
    # runner, reached by a local pattern, set the label in the module process.
    {:module, _} = Code.ensure_loaded(ExUnit.Runner)

    setup_all = [
      {[:_, %{__struct__: ExUnit.TestModule, name: :"$1"}, :_, :_], [],
       [{:set_seq_token, :label, :"$1"}, {:message, {{:setup_all_label, :"$1"}}}]}
    ]

    q1_local("run_setup_all/4", {ExUnit.Runner, :run_setup_all, 4}, setup_all)

    on_exit = [
      {[%{__struct__: ExUnit.TestModule, name: :"$1"}, :_, :_], [],
       [{:set_seq_token, :label, :"$1"}, {:message, {{:on_exit_label, :"$1"}}}]},
      {[%{__struct__: ExUnit.Test}, :_, :_], [],
       [{:set_seq_token, :label, {:get_tcw}}, {:message, {{:on_exit_label, {:get_tcw}}}}]}
    ]

    q1_local("exec_on_exit/3", {ExUnit.Runner, :exec_on_exit, 3}, on_exit)

    flags = [:call, :procs, {:tracer, tracer}]
    :erlang.trace(:new_processes, true, flags)
    for pid <- [server, task_sup], do: :erlang.trace(pid, true, flags)

    results = ExUnit.run()

    :erlang.trace(:all, false, [:all])
    delivered = :erlang.trace_delivered(:all)

    receive do
      {:trace_delivered, :all, ^delivered} -> :ok
    end

    say("Q1 ExUnit.run results=#{inspect(results)}")
    report(Spike.Tracer.take(tracer))
  end

  defp q1_local(name, mfa, spec) do
    count = :erlang.trace_pattern(mfa, spec, [:local])
    say("Q1 local pattern on ExUnit.Runner.#{name}: matched=#{count}")
  end

  defp start_unlabelled(fun) do
    me = self()
    # Started by a process that outlives ExUnit.run so nothing in a test owns it.
    pid =
      spawn(fn ->
        {:ok, started} = fun.()
        send(me, {:started, started})

        receive do
          :never -> :ok
        end
      end)

    _ = pid

    receive do
      {:started, started} -> started
    end
  end

  defp report(messages) do
    windows =
      for {:trace, _pid, :call, {ExUnit.EventManager, :test_started, _args}, {test, word}} <- messages, into: %{} do
        {word, test.name}
      end

    parents =
      for {:trace, child, :spawned, parent, _mfa} <- messages, into: %{} do
        {child, parent}
      end

    roots =
      for {:trace, pid, :call, {ExUnit.OnExitHandler, :register, _args}, {kind, word}} <- messages, into: %{} do
        {pid, {kind, word}}
      end

    say("Q1 windows=#{map_size(windows)} roots=#{map_size(roots)} procs_spawned=#{map_size(parents)}")

    for {:trace, pid, :call, {ExUnit.OnExitHandler, :register, _args}, {kind, word}} <- messages do
      say("Q1 ENTRY #{kind} word=#{word} test=#{inspect(windows[word])} pid=#{inspect(pid)}")
    end

    runner = for {:trace, pid, :call, {ExUnit.Runner, name, _}, extra} <- messages, do: {name, extra, pid}
    say("Q1 RUNNER calls=#{length(runner)} first=#{inspect(Enum.take(runner, 2))} last=#{inspect(List.last(runner))}")

    say("Q2 columns: tag | label read at the call | tcw at the call | test whose window was open | owner by spawn ancestry (Q6)")

    rows =
      for {:trace, pid, :call, {Spike.Fix, :mark, [tag]}, {label, word}} <- messages do
        {tag, label, word, pid}
      end

    rows
    |> Enum.uniq_by(fn {tag, label, word, _pid} -> {tag, label, word} end)
    |> Enum.each(fn {tag, label, word, pid} ->
      open = if rem(word, 2) == 1, do: inspect(windows[word]), else: "closed(after #{inspect(windows[word - 1])})"
      say("Q2 ROW #{inspect(tag)} | label=#{label_text(label, windows)} | tcw=#{word} | open=#{open} | owner=#{owner_text(pid, parents, roots, windows)}")
    end)

    say("Q2 total marks=#{length(rows)}")
  end

  defp label_text(:none, _windows), do: "NONE"
  defp label_text(word, windows) when is_integer(word), do: "#{word}:#{inspect(windows[word])}"
  defp label_text(other, _windows), do: inspect(other)

  defp owner_text(pid, parents, roots, windows) do
    case owner(pid, parents, roots, 0) do
      {:entry_test, word} -> "#{word}:#{inspect(windows[word])}"
      {:entry_module, _word} -> "setup_all"
      :unowned -> "UNOWNED"
    end
  end

  defp owner(_pid, _parents, _roots, depth) when depth > 64, do: :unowned

  defp owner(pid, parents, roots, depth) do
    case roots do
      %{^pid => root} ->
        root

      _other ->
        case parents do
          %{^pid => parent} -> owner(parent, parents, roots, depth + 1)
          _none -> :unowned
        end
    end
  end
end

IO.puts("PROBE otp=#{:erlang.system_info(:otp_release)} elixir=#{System.version()}")
Spike.Probe.q3()
Spike.Probe.causal()
IO.puts("PROBE DONE")
System.halt(0)
