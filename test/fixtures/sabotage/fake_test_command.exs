# DND-5473, DND-5572: a stand-in test command for Anchor.Adapters.TestRunner's
# tests. Run as `elixir fake_test_command.exs <mode> ...`; it sends the events
# ExUnit would send to the REAL Anchor.Sabotage.ExUnitFormatter (compiled from
# lib/ here, so the formatter alone, as in a project's test VM) and lets that
# formatter write the frames to ANCHOR_SABOTAGE_RESULTS: the fixture holds no
# copy of the frame format, so a change to the encoder shows in the adapter
# tests. Every other argument (the test files and --formatter flags the runner
# appends) is ignored.
#
#   pass           2 tests, 0 failures, exit 0
#   fail           2 tests, 1 failure, exit 2
#   none           0 tests, exit 0
#   compile_error  no events, prints a compile error, exit 1
#   hang           suite started, then blocks until killed
#   args           prints its arguments, then 1 test passes
#   flood          prints ~200 KB (lines "line N ...") then 2 tests pass
#   killed         suite started, then kills itself with signal 9 (exit 137)
#   stubborn       suite started, ignores SIGTERM and blocks: only the
#                  `timeout` binary's KILL ends it (exit 137 after the bound)

# Before anything slow: the stubborn run must already ignore the stop signal
# when the bound is reached.
if hd(System.argv()) == "stubborn", do: :os.set_signal(:sigterm, :ignore)

Code.require_file(Path.expand("../../../lib/anchor/sabotage/ex_unit_formatter.ex", __DIR__))

test = fn name, line, state ->
  %ExUnit.Test{
    name: name,
    state: state,
    tags: %{file: Path.join(File.cwd!(), "test/calc_test.exs"), line: line}
  }
end

failed = {:failed, [{:error, %ExUnit.AssertionError{message: "Assertion with == failed"}, []}]}

# Starts the real formatter, casts the events in order and waits until it has
# handled them (a call after the casts), so the frames are on disk.
events = fn list ->
  {:ok, formatter} = GenServer.start_link(Anchor.Sabotage.ExUnitFormatter, [])
  Enum.each(list, &GenServer.cast(formatter, &1))
  :sys.get_state(formatter)
  formatter
end

finished = fn formatter ->
  GenServer.cast(formatter, {:suite_finished, %{run: 1}})
  :ok = GenServer.stop(formatter)
end

block = fn ->
  receive do
    :never_sent -> :ok
  end
end

case System.argv() do
  ["pass" | _rest] ->
    [
      {:suite_started, []},
      {:test_finished, test.(:"test adds", 4, nil)},
      {:test_finished, test.(:"test subs", 9, nil)}
    ]
    |> events.()
    |> finished.()

  ["fail" | _rest] ->
    [
      {:suite_started, []},
      {:test_finished, test.(:"test adds", 4, failed)},
      {:test_finished, test.(:"test subs", 9, nil)}
    ]
    |> events.()
    |> finished.()

    System.halt(2)

  ["none" | _rest] ->
    [{:suite_started, []}] |> events.() |> finished.()

  ["compile_error" | _rest] ->
    IO.write("== Compilation error in file lib/calc.ex ==" <> "\n")
    IO.write("** (CompileError) lib/calc.ex: cannot compile module Calc" <> "\n")
    System.halt(1)

  ["hang" | _rest] ->
    events.([{:suite_started, []}])
    block.()

  ["flood" | _rest] ->
    formatter =
      events.([
        {:suite_started, []},
        {:test_finished, test.(:"test adds", 4, nil)},
        {:test_finished, test.(:"test subs", 9, nil)}
      ])

    for n <- 1..4000, do: IO.write("line #{n} " <> String.duplicate("x", 40) <> "\n")
    finished.(formatter)

  ["killed" | _rest] ->
    events.([{:suite_started, []}])
    System.cmd("kill", ["-9", System.pid()])
    block.()

  ["stubborn" | _rest] ->
    events.([{:suite_started, []}])
    block.()

  ["args" | rest] ->
    IO.write(Enum.join(rest, " ") <> "\n")

    [{:suite_started, []}, {:test_finished, test.(:"test adds", 4, nil)}]
    |> events.()
    |> finished.()
end
