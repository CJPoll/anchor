# DND-5693 (throwaway, CI only): the match specs and the gate the cost and suite
# probes share. Nothing here is production code; DND-5691 builds its own from the
# findings.

defmodule Spike.Specs do
  @moduledoc false
  @label {:element, 2, {:get_seq_token}}
  @payload {{@label, {:get_tcw}}}

  def label, do: @label
  def payload, do: @payload

  # A call message that carries the label and the window word, both read by the
  # VM at the call.
  def call(suppressions \\ []) do
    suppressions ++
      [
        {:_, [{:is_seq_trace}], [{:message, @payload}]},
        {:_, [], [{:message, {{:none, {:get_tcw}}}}]}
      ]
  end

  # label_body: exact key (pid, word, label). The label is read in the BODY (a
  # guard may not read it, Q3), so a different label on the same pid in the same
  # word still sends its message.
  def suppress(:label_body, {pid, word, :none}) do
    {:_, [{:not, {:is_seq_trace}}, {:"==", {:self}, {:const, pid}}, {:"==", {:get_tcw}, word}],
     [{:message, false}]}
  end

  def suppress(:label_body, {pid, word, label}) do
    {:_, [{:is_seq_trace}, {:"==", {:self}, {:const, pid}}, {:"==", {:get_tcw}, word}],
     [{:message, {:andalso, {:"=/=", @label, {:const, label}}, @payload}}]}
  end

  # pid_word: key (pid, word), guards only: no label read, so exact only where the
  # pid's owner decides the attribution, not its label.
  def suppress(:pid_word, {pid, word, _label}) do
    {:_, [{:"==", {:self}, {:const, pid}}, {:"==", {:get_tcw}, word}], [{:message, false}]}
  end

  # word: PR #63's shape, key (word) alone. A reference for the cost table; it is
  # the shape that hides another test's leak in the same window.
  def suppress(:word, {_pid, word, _label}) do
    {:_, [{:"==", {:get_tcw}, word}], [{:message, false}]}
  end

  # The spec of a function with `held` keys suppressed, for each shape.
  def spec(:pr63, [{_pid, word, _label} | _]) do
    [{:_, [{:"=/=", {:get_tcw}, word}], [{:message, {:get_tcw}}]}]
  end

  # Guards only, and no clause matches a suppressed key: a guard failure instead
  # of a matched body. Key (pid, word), as pid_word.
  def spec(:fallthrough, held) do
    open =
      Enum.reduce(held, {:const, false}, fn {pid, word, _label}, acc ->
        {:orelse, acc, {:andalso, {:"==", {:self}, {:const, pid}}, {:"==", {:get_tcw}, word}}}
      end)

    [
      {:_, [{:is_seq_trace}, {:not, open}], [{:message, @payload}]},
      {:_, [{:not, {:is_seq_trace}}, {:not, open}], [{:message, {{:none, {:get_tcw}}}}]}
    ]
  end

  def spec(shape, held), do: call(Enum.map(held, &suppress(shape, &1)))

  def window, do: [{[:_, :"$1"], [], [{:set_tcw, {:+, {:get_tcw}, 1}}, {:message, {{:"$1", {:get_tcw}}}}]}]

  # The test process's first call into ExUnit: an odd word is an open window,
  # so this is a test; an even word is a setup_all process.
  def entry do
    [
      {:_, [{:"==", {:band, {:get_tcw}, 1}, 1}],
       [{:set_seq_token, :label, {:get_tcw}}, {:message, {{:entry_test, {:get_tcw}}}}]},
      {:_, [{:is_seq_trace}], [{:message, {{:entry_module, @label}}}]},
      {:_, [], [{:message, {{:entry_module, :none}}}]}
    ]
  end

  def setup_all do
    [
      {[:_, %{__struct__: ExUnit.TestModule, name: :"$1"}, :_, :_], [],
       [{:set_seq_token, :label, :"$1"}, {:message, {{:setup_all_label, :"$1"}}}]}
    ]
  end

  def on_exit do
    [
      {[%{__struct__: ExUnit.TestModule, name: :"$1"}, :_, :_], [],
       [{:set_seq_token, :label, :"$1"}, {:message, {{:on_exit_label, :"$1"}}}]},
      {[%{__struct__: ExUnit.Test}, :_, :_], [],
       [{:set_seq_token, :label, {:get_tcw}}, {:message, {{:on_exit_label, {:get_tcw}}}}]}
    ]
  end
end

defmodule Spike.Collector do
  @moduledoc false
  # Holds what the gate forwards. The gate has already decided; this is the
  # process DND-5691's CoverageCollector stands in for, so a forward costs a send.
  def start do
    spawn(fn ->
      Process.flag(:message_queue_data, :off_heap)
      loop(%{}, %{}, %{}, [])
    end)
  end

  def take(pid) do
    send(pid, {:take, self()})

    receive do
      {:taken, state} -> state
    end
  end

  defp loop(keys, windows, parents, roots) do
    receive do
      {:forwarded_call} ->
        loop(keys, windows, parents, roots)

      {:key, key, count} ->
        loop(Map.update(keys, key, count, &(&1 + count)), windows, parents, roots)

      {:window, word, test} ->
        loop(keys, Map.put(windows, word, test), parents, roots)

      {:spawned, child, parent, origin} ->
        loop(keys, windows, Map.put(parents, child, {parent, origin}), roots)

      {:root, pid, root} ->
        loop(keys, windows, parents, [{pid, root} | roots])

      {:take, from} ->
        send(from, {:taken, %{keys: keys, windows: windows, parents: parents, roots: Map.new(roots)}})
        loop(keys, windows, parents, roots)
    end
  end
end

defmodule Spike.Gate do
  @moduledoc false
  # The tracer. `k` is :none (every call) or a positive integer; `shape` is a
  # Spike.Specs.suppress/2 shape. The key of a call is {mfa, pid, word, label}; the
  # first k messages of a key are forwarded, then that key is suppressed by a
  # rewrite of its function's spec, and any already in flight is dropped.
  @event_manager ExUnit.EventManager
  @runner ExUnit.Runner
  @on_exit ExUnit.OnExitHandler

  def start(collector, k, shape) do
    gate =
      spawn(fn ->
        Process.flag(:message_queue_data, :off_heap)
        Process.flag(:priority, :high)

        loop(%{
          collector: collector,
          k: k,
          shape: shape,
          counts: %{},
          active: %{},
          received: 0,
          forwarded: 0,
          dropped: 0,
          silences: 0,
          silence_us: 0,
          procs: 0
        })
      end)

    gate
  end

  def finish(gate) do
    send(gate, {:finish, self()})

    receive do
      {:finished, stats} -> stats
    end
  end

  defp loop(state) do
    receive do
      {:trace, pid, :call, {m, f, a} = mfa, {label, word}}
      when is_integer(a) and m != @event_manager and m != @runner and m != @on_exit ->
        loop(call(state, mfa, pid, word, label))

      {:trace, _pid, :call, {@event_manager, _name, _arity}, {test, word}} ->
        if rem(word, 2) == 1 do
          send(state.collector, {:window, word, %{module: test.module, name: test.name, file: test.tags.file, line: test.tags.line}})
        end

        loop(%{state | received: state.received + 1})

      {:trace, pid, :call, {@on_exit, :register, _arity}, root} ->
        send(state.collector, {:root, pid, root})
        loop(%{state | received: state.received + 1})

      {:trace, _pid, :call, {@runner, _name, _arity}, _label} ->
        loop(%{state | received: state.received + 1})

      {:trace, child, :spawned, parent, spawned_mfa} ->
        send(state.collector, {:spawned, child, parent, origin(spawned_mfa)})
        loop(%{state | procs: state.procs + 1})

      {:trace, _pid, _proc_event, _a} ->
        loop(%{state | procs: state.procs + 1})

      {:trace, _pid, _proc_event, _a, _b} ->
        loop(%{state | procs: state.procs + 1})

      {:finish, from} ->
        flush_counts(state)

        send(from, {:finished, Map.take(state, [:received, :forwarded, :dropped, :silences, :silence_us, :procs])})
    end
  end

  # Every-call: count, send once at the end (the set is what DND-5691 needs; the
  # send per message is what `forward` measures in the K modes).
  defp call(%{k: :none} = state, mfa, pid, word, label) do
    key = {mfa, pid, word, label}
    send(state.collector, {:forwarded_call})

    %{
      state
      | received: state.received + 1,
        forwarded: state.forwarded + 1,
        counts: Map.update(state.counts, key, 1, &(&1 + 1))
    }
  end

  defp call(%{k: k} = state, mfa, pid, word, label) do
    key = {mfa, pid, word, label}
    state = %{state | received: state.received + 1}

    case state.counts do
      %{^key => count} when count >= k ->
        %{state | dropped: state.dropped + 1}

      %{^key => count} when count + 1 == k ->
        state = forward(state, key, count + 1)
        silence(state, mfa, pid, word, label)

      %{^key => count} ->
        forward(state, key, count + 1)

      _first when k == 1 ->
        state = forward(state, key, 1)
        silence(state, mfa, pid, word, label)

      _first ->
        forward(state, key, 1)
    end
  end

  defp forward(state, key, count) do
    send(state.collector, {:key, key, 1})
    %{state | forwarded: state.forwarded + 1, counts: Map.put(state.counts, key, count)}
  end

  # A function's clauses hold only the current word: an older word's clause can
  # never match again, so a rewrite drops it.
  defp silence(state, mfa, pid, word, label) do
    held = state.active |> Map.get(mfa, []) |> Enum.filter(fn {_pid, w, _label} -> w == word end)
    held = [{pid, word, label} | held]
    spec = Spike.Specs.spec(state.shape, held)
    {us, 1} = :timer.tc(fn -> :erlang.trace_pattern(mfa, spec, [:local]) end)

    %{
      state
      | active: Map.put(state.active, mfa, held),
        silences: state.silences + 1,
        silence_us: state.silence_us + us
    }
  end

  defp flush_counts(%{k: :none} = state) do
    Enum.each(state.counts, fn {key, count} -> send(state.collector, {:key, key, count}) end)
  end

  defp flush_counts(_state), do: :ok

  defp origin({:erlang, :apply, [fun | _]}) when is_function(fun) do
    info = Function.info(fun)
    {info[:module], info[:name]}
  end

  defp origin({m, f, _args}), do: {m, f}
  defp origin(other), do: inspect(other, limit: 4)
end

defmodule Spike.Trace do
  @moduledoc false
  @flags [:call, :arity]

  # Sets the patterns and turns tracing on, as the design has it: the window word,
  # the label entry, the runner's private on_exit and setup_all, and every project
  # function with the label in the message.
  def on(modules, gate, collector, extra_flags \\ []) do
    :erlang.system_flag(:trace_control_word, 0)
    for module <- modules, Code.ensure_loaded?(module), do: :erlang.trace_pattern({module, :_, :_}, Spike.Specs.call(), [:local])
    :ok = suite_patterns()
    _count = :erlang.trace(:all, true, [{:tracer, gate} | @flags ++ extra_flags])
    1 = :erlang.trace(gate, false, [:all])
    1 = :erlang.trace(collector, false, [:all])
    :ok
  end

  defp suite_patterns do
    {:module, _} = Code.ensure_loaded(ExUnit.EventManager)
    {:module, _} = Code.ensure_loaded(ExUnit.OnExitHandler)
    {:module, _} = Code.ensure_loaded(ExUnit.Runner)
    1 = :erlang.trace_pattern({ExUnit.EventManager, :test_started, 2}, Spike.Specs.window(), [:global])
    1 = :erlang.trace_pattern({ExUnit.EventManager, :test_finished, 2}, Spike.Specs.window(), [:global])
    1 = :erlang.trace_pattern({ExUnit.OnExitHandler, :register, 1}, Spike.Specs.entry(), [:global])
    1 = :erlang.trace_pattern({ExUnit.Runner, :run_setup_all, 4}, Spike.Specs.setup_all(), [:local])
    1 = :erlang.trace_pattern({ExUnit.Runner, :exec_on_exit, 3}, Spike.Specs.on_exit(), [:local])
    :ok
  end

  def off do
    _flags = :erlang.trace(:all, false, [:all])
    ref = :erlang.trace_delivered(:all)

    receive do
      {:trace_delivered, :all, ^ref} -> :ok
    end

    _local = :erlang.trace_pattern({:_, :_, :_}, false, [:local])
    _global = :erlang.trace_pattern({:_, :_, :_}, false, [:global])
    :ok
  end
end
