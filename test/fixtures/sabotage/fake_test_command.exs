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
#   args           prints its arguments and ANCHOR_SABOTAGE_ROOT, then passes

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

  ["args" | rest] ->
    IO.write(Enum.join(rest, " ") <> "\n")
    IO.write("root=" <> System.get_env("ANCHOR_SABOTAGE_ROOT", "") <> "\n")
    frame.({:suite_finished, 1, 0, 0})
end
