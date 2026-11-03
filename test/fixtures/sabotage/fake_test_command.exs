# DND-5473: a stand-in test command for Anchor.Adapters.TestRunner's tests.
# Run as `elixir fake_test_command.exs <mode> ...`; it writes the frames
# Anchor.Sabotage.ExUnitFormatter would write to ANCHOR_SABOTAGE_RESULTS, by
# mode, and ignores every other argument (the test files and --formatter
# flags the runner appends).
#
#   pass           2 tests, 0 failures, exit 0
#   fail           2 tests, 1 failure, exit 2
#   none           0 tests, exit 0
#   compile_error  no frames, prints a compile error, exit 1
#   hang           suite_started, then blocks until killed
#   args           prints its arguments, then passes
#   flood          prints ~200 KB (lines "line N ...") then passes
#   killed         suite_started, then kills itself with signal 9 (exit 137)
#   stubborn       suite_started, ignores SIGTERM and blocks: only the
#                  `timeout` binary's KILL ends it (exit 137 after the bound)

path = System.fetch_env!("ANCHOR_SABOTAGE_RESULTS")

frame = fn term ->
  bin = :erlang.term_to_binary(term)
  File.write!(path, <<byte_size(bin)::32, bin::binary>>, [:append, :binary])
end

case System.argv() do
  ["pass" | _rest] ->
    frame.({:suite_started})
    frame.({:suite_finished, 2, 0, 0})

  ["fail" | _rest] ->
    frame.({:suite_started})
    frame.({:test_failed, "test/calc_test.exs", 4, "test adds", "Assertion with == failed"})
    frame.({:suite_finished, 2, 1, 0})
    System.halt(2)

  ["none" | _rest] ->
    frame.({:suite_started})
    frame.({:suite_finished, 0, 0, 0})

  ["compile_error" | _rest] ->
    IO.write("== Compilation error in file lib/calc.ex ==" <> "\n")
    IO.write("** (CompileError) lib/calc.ex: cannot compile module Calc" <> "\n")
    System.halt(1)

  ["hang" | _rest] ->
    frame.({:suite_started})

    receive do
      :never_sent -> :ok
    end

  ["flood" | _rest] ->
    frame.({:suite_started})
    for n <- 1..4000, do: IO.write("line #{n} " <> String.duplicate("x", 40) <> "\n")
    frame.({:suite_finished, 2, 0, 0})

  ["killed" | _rest] ->
    frame.({:suite_started})
    System.cmd("kill", ["-9", System.pid()])

    receive do
      :never_sent -> :ok
    end

  ["stubborn" | _rest] ->
    frame.({:suite_started})
    :os.set_signal(:sigterm, :ignore)

    receive do
      :never_sent -> :ok
    end

  ["args" | rest] ->
    IO.write(Enum.join(rest, " ") <> "\n")
    frame.({:suite_finished, 1, 0, 0})
end
