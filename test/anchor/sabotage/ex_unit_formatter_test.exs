defmodule Anchor.Sabotage.ExUnitFormatterTest do
  # DND-5473: the formatter fed ExUnit's events directly; its frames are what
  # the runner reads.
  # Sabotage record: ../../sabotage_records/sabotage-20261103-dnd_5473_sabotage_run.md
  use ExUnit.Case, async: true

  alias Anchor.Sabotage.ExUnitFormatter

  @moduletag :tmp_dir

  defp frames(path), do: decode(File.read!(path), [])

  defp decode(<<size::32, frame::binary-size(size), rest::binary>>, acc),
    do: decode(rest, [:erlang.binary_to_term(frame, [:safe]) | acc])

  defp decode(<<>>, acc), do: Enum.reverse(acc)

  defp test_struct(name, state, line) do
    %ExUnit.Test{
      name: name,
      module: CalcTest,
      state: state,
      tags: %{file: Path.join(File.cwd!(), "test/calc_test.exs"), line: line}
    }
  end

  test "1: suite_started, one test_failed with file, line, name and text, suite_finished with totals",
       %{tmp_dir: dir} do
    path = Path.join(dir, "results.bin")
    {:ok, pid} = GenServer.start_link(ExUnitFormatter, results_path: path)

    error = %RuntimeError{message: "boom"}

    GenServer.cast(pid, {:suite_started, []})

    GenServer.cast(
      pid,
      {:test_finished, test_struct(:"test adds", {:failed, [{:error, error, []}]}, 4)}
    )

    GenServer.cast(pid, {:test_finished, test_struct(:"test subs", nil, 9)})
    GenServer.cast(pid, {:test_finished, test_struct(:"test skip", {:excluded, "x"}, 12)})
    GenServer.cast(pid, {:suite_finished, %{run: 1}})
    :ok = GenServer.stop(pid)

    assert frames(path) == [
             {:suite_started},
             {:test_failed, "test/calc_test.exs", 4, "test adds", "** (RuntimeError) boom"},
             {:suite_finished, 2, 1, 1}
           ]
  end

  test "a test whose setup_all failed counts as a failure", %{tmp_dir: dir} do
    path = Path.join(dir, "results.bin")
    {:ok, pid} = GenServer.start_link(ExUnitFormatter, results_path: path)

    module = %ExUnit.TestModule{
      name: CalcTest,
      state: {:failed, [{:error, %RuntimeError{message: "db"}, []}]}
    }

    GenServer.cast(pid, {:test_finished, test_struct(:"test adds", {:invalid, module}, 4)})
    GenServer.cast(pid, {:suite_finished, %{}})
    :ok = GenServer.stop(pid)

    assert [
             {:test_failed, "test/calc_test.exs", 4, "test adds",
              "setup_all failed: ** (RuntimeError) db"},
             {:suite_finished, 1, 1, 0}
           ] = frames(path)
  end
end
