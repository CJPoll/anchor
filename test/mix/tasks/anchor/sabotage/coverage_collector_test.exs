defmodule Anchor.Sabotage.CoverageCollectorTest do
  # DND-5474, DND-5691: the collector turns trace messages into CoverageMap events;
  # the messages are sent to it directly (no tracing).
  # Sabotage record: ../../../../sabotage_records/sabotage-20261103-dnd_5474_coverage_map.md
  # Sabotage record: ../../../../sabotage_records/coverage_attribution-20261106-dnd_5691_causal_attribution.md
  use ExUnit.Case, async: true

  alias Anchor.Domain.Sabotage.CoverageMap
  alias Anchor.Sabotage.CoverageCollector

  @meta %{
    commit: "c",
    elixir: "1.19.4",
    otp: "28",
    modules_traced: 2,
    suite_exit: 0,
    total: 2,
    root: "/p"
  }
  @em ExUnit.EventManager

  defp test_struct(line, name, state \\ nil),
    do: %ExUnit.Test{
      name: name,
      module: ATest,
      state: state,
      tags: %{file: "/p/test/a_test.exs", line: line, test: name, module: ATest}
    }

  defp finalized(pid, meta \\ @meta) do
    assert {:ok, state} = CoverageCollector.finish(pid)
    CoverageMap.finalize(state, meta)
  end

  defp started do
    {:ok, pid} = CoverageCollector.start_link()
    pid
  end

  defp window(runner, word, line, name, state) do
    [
      {:trace, runner, :call, {@em, :test_started, 2}, {test_struct(line, name), word}},
      {:trace, runner, :call, {@em, :test_finished, 2},
       {test_struct(line, name, state), word + 1}}
    ]
  end

  test "1: trace messages give the map: a test's process calling, and its window" do
    pid = started()
    runner = spawn(fn -> :ok end)
    t = spawn(fn -> :ok end)
    [open, close] = window(runner, 1, 3, :"test one", nil)
    [open2, close2] = window(runner, 3, 9, :"test two", {:excluded, "x"})

    for message <- [
          open,
          {:trace, runner, :spawn, t, {:erlang, :apply, [fn -> :ok end, []]}},
          {:trace, t, :spawned, runner, {:erlang, :apply, [fn -> :ok end, []]}},
          {:trace, t, :call, {ExUnit.OnExitHandler, :register, 1}, {:entry, 1}},
          {:trace, t, :call, {A, :f, 2}, {1, 1}},
          {:trace, t, :exit, :shutdown},
          close,
          open2,
          close2,
          {:something, :else}
        ],
        do: send(pid, message)

    assert {:ok, map} = finalized(pid)
    assert Map.new(map.tests, &{&1.line, &1.functions}) == %{3 => ["A.f/2"]}
    assert map.leaks == []
    assert map.ambient == []
  end

  test "2: a failed test ran; a skipped or invalid one did not" do
    pid = started()
    runner = spawn(fn -> :ok end)
    t = spawn(fn -> :ok end)
    [open, close] = window(runner, 1, 3, :"test one", {:failed, []})
    [open2, close2] = window(runner, 3, 9, :"test two", {:skipped, "x"})
    [open3, close3] = window(runner, 5, 12, :"test three", {:invalid, ATest})

    for message <- [
          open,
          {:trace, runner, :spawn, t, {M, :f, []}},
          {:trace, t, :call, {ExUnit.OnExitHandler, :register, 1}, {:entry, 1}},
          close,
          open2,
          close2,
          open3,
          close3
        ],
        do: send(pid, message)

    assert {:ok, map} = finalized(pid, %{@meta | total: 3})
    assert Enum.map(map.tests, & &1.line) == [3]
  end

  test "3: a call's arguments are never kept, and a spawn's are reduced to one pid" do
    pid = started()
    big = String.duplicate("secret-value-", 1000)
    child = spawn(fn -> :ok end)

    send(pid, {:trace, self(), :call, {A, :f, 2}, {:none, 0}})
    send(pid, {:trace, self(), :spawn, child, {M, :f, [big, %{key: big}]}})

    assert {:ok, state} = CoverageCollector.finish(pid)
    refute inspect(state, limit: :infinity, printable_limit: :infinity) =~ "secret-value"
    refute inspect(:sys.get_state(pid), limit: :infinity, printable_limit: :infinity) =~ "secret"
  end

  test "4: a module's start and end, and setup_all's process, come through" do
    pid = started()
    runner = spawn(fn -> :ok end)
    s = spawn(fn -> :ok end)
    t = spawn(fn -> :ok end)
    [open, close] = window(runner, 1, 3, :"test one", nil)

    for message <- [
          {:trace, runner, :call, {ExUnit.Runner, :run_setup_all, 4}, {:module, ATest}},
          {:trace, runner, :spawn, s, {M, :f, []}},
          {:trace, s, :call, {A, :setup, 0}, {ATest, 0}},
          open,
          {:trace, runner, :spawn, t, {M, :f, []}},
          {:trace, t, :call, {ExUnit.OnExitHandler, :register, 1}, {:entry, 1}},
          close,
          {:trace, runner, :call, {@em, :module_finished, 2}, {ATest, 4}},
          {:trace, s, :call, {A, :late, 0}, {ATest, 4}}
        ],
        do: send(pid, message)

    assert {:ok, map} = finalized(pid, %{@meta | total: 1})
    assert [%{functions: ["A.late/0", "A.setup/0"]}] = map.tests
    assert map.leaks == [%{from: %{module: "ATest"}, function: "A.late/0"}]
  end

  test "5: a task spawned for a test by a supervisor is the test's, through the owner pid" do
    pid = started()
    runner = spawn(fn -> :ok end)
    t = spawn(fn -> :ok end)
    sup = spawn(fn -> :ok end)
    k = spawn(fn -> :ok end)
    [open, close] = window(runner, 1, 3, :"test one", nil)
    task = {Task.Supervised, :noreply, [{node(), t, t}, [], [t], {M, :f, []}]}

    for message <- [
          open,
          {:trace, runner, :spawn, t, {M, :f, []}},
          {:trace, t, :call, {ExUnit.OnExitHandler, :register, 1}, {:entry, 1}},
          {:trace, sup, :spawn, k, task},
          {:trace, k, :call, {A, :f, 0}, {:none, 1}},
          close
        ],
        do: send(pid, message)

    assert {:ok, map} = finalized(pid, %{@meta | total: 1})
    assert [%{functions: ["A.f/0"]}] = map.tests
  end

  test "6: a Task spawn in an unknown shape, or an unreadable call, is refused by name" do
    pid = started()
    send(pid, {:trace, self(), :spawn, self(), {Task.Supervised, :noreply, [:x]}})
    assert finalized(pid) == {:error, {:task_shape, {Task.Supervised, :noreply, [:x]}}}

    pid = started()
    send(pid, {:trace, self(), :call, {A, :f, 0}, :not_a_pair})
    assert finalized(pid) == {:error, {:unreadable, {{A, :f, 0}, :not_a_pair}}}

    pid = started()
    send(pid, {:trace, self(), :call, {@em, :test_started, 2}, :not_a_pair})
    assert finalized(pid) == {:error, {:unreadable, {{@em, :test_started, 2}, :not_a_pair}}}
  end
end
