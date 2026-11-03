defmodule Anchor.Sabotage.CoverageCollectorTest do
  # DND-5474: the collector turns trace messages into CoverageMap events; the
  # messages are sent to it directly (no tracing), with explicit stamps.
  # Sabotage record: ../../../../sabotage_records/sabotage-20261103-dnd_5474_coverage_map.md
  # Sabotage record (DND-5642): ../../../../sabotage_records/sabotage-20261103-dnd_5639_sabotage_followups.md
  use ExUnit.Case, async: true

  alias Anchor.Domain.Sabotage.CoverageMap
  alias Anchor.Sabotage.CoverageCollector

  @meta %{commit: "c", elixir: "1.19.4", otp: "28", modules_traced: 2, suite_exit: 0, root: "/p"}

  defp test_struct(line, name),
    do: %ExUnit.Test{
      name: name,
      module: ATest,
      tags: %{file: "/p/test/a_test.exs", line: line, test: name, module: ATest}
    }

  defp ref(line, name),
    do: %{file: "/p/test/a_test.exs", line: line, name: to_string(name), module: "ATest"}

  test "1: trace messages give the same map CoverageMap gives on the same events" do
    {:ok, pid} = CoverageCollector.start_link(slack: 2)
    t1 = test_struct(3, :"test one")
    t2 = test_struct(9, :"test two")
    em = ExUnit.EventManager

    for message <- [
          {:trace_ts, self(), :call, {em, :test_started, [:mgr, t1]}, 1},
          {:trace_ts, self(), :call, {A, :f, [1, 2]}, 2},
          {:trace_ts, self(), :call, {em, :test_finished, 2}, t1, 3},
          {:trace_ts, self(), :call, {B, :g, 0}, 5},
          {:trace_ts, self(), :call, {em, :test_started, 2}, t2, 4},
          {:trace_ts, self(), :call, {em, :test_finished, [:mgr, t2]}, 6},
          {:something, :else}
        ],
        do: send(pid, message)

    assert {:ok, state} = CoverageCollector.finish(pid)

    expected =
      [slack: 2]
      |> CoverageMap.new()
      |> CoverageMap.attribute([
        {:window_open, 1, ref(3, :"test one")},
        {:call, 2, {A, :f, 2}, self()},
        {:window_close, 3, ref(3, :"test one")},
        {:call, 5, {B, :g, 0}, self()},
        {:window_open, 4, ref(9, :"test two")},
        {:window_close, 6, ref(9, :"test two")}
      ])

    assert CoverageMap.finalize(state, @meta) == CoverageMap.finalize(expected, @meta)

    assert Map.new(CoverageMap.finalize(state, @meta).tests, &{&1.line, &1.functions}) ==
             %{3 => ["A.f/2"], 9 => ["B.g/0"]}
  end

  test "2: a call's arguments are never kept" do
    {:ok, pid} = CoverageCollector.start_link()
    big = String.duplicate("secret-value-", 1000)
    t1 = test_struct(3, :"test one")

    send(pid, {:trace_ts, self(), :call, {ExUnit.EventManager, :test_started, 2}, t1, 1})
    send(pid, {:trace_ts, self(), :call, {A, :f, [big, %{key: big}]}, 2})

    assert {:ok, state} = CoverageCollector.finish(pid)
    refute inspect(state, limit: :infinity, printable_limit: :infinity) =~ "secret-value"
    refute inspect(:sys.get_state(pid), limit: :infinity, printable_limit: :infinity) =~ "secret"
    assert [set] = Map.values(state.open)
    assert MapSet.to_list(set) == [{A, :f, 2}]
  end

  test "3: each call keeps the pid that made it, so a process from an earlier window is a leak (DND-5642)" do
    {:ok, pid} = CoverageCollector.start_link()
    t1 = test_struct(3, :"test one")
    t2 = test_struct(9, :"test two")
    em = ExUnit.EventManager
    leaker = spawn(fn -> :ok end)
    fresh = spawn(fn -> :ok end)

    for message <- [
          {:trace_ts, self(), :call, {em, :test_started, 2}, t1, 1},
          {:trace_ts, leaker, :call, {A, :f, 0}, 2},
          {:trace_ts, self(), :call, {em, :test_finished, 2}, t1, 3},
          {:trace_ts, self(), :call, {em, :test_started, 2}, t2, 4},
          {:trace_ts, fresh, :call, {B, :g, 0}, 5},
          {:trace_ts, leaker, :call, {B, :g, [1]}, 6},
          {:trace_ts, self(), :call, {em, :test_finished, 2}, t2, 7}
        ],
        do: send(pid, message)

    assert {:ok, state} = CoverageCollector.finish(pid)

    assert CoverageMap.finalize(state, @meta).window_leaks == [
             %{
               from: [ref(3, :"test one") |> Map.put(:file, "test/a_test.exs")],
               to: ref(9, :"test two") |> Map.put(:file, "test/a_test.exs"),
               calls: 1
             }
           ]
  end
end
