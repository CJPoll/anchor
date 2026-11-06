defmodule Anchor.Integration.CoverageCompareIntegrationTest do
  # DND-5692: the tooling self-test. Canned maps in real files, the real store and the
  # real command in a VM of its own, as the Coverage map workflow runs it: the exit
  # code is the VM's own, and the fresh VM reads the maps with `[:safe]`.
  # Sabotage record: ../../sabotage_records/coverage_compare-20261106-dnd_5692_repeatability_check.md
  use ExUnit.Case, async: true

  alias Anchor.Adapters.CoverageFile
  alias Anchor.Domain.Sabotage.CoverageMap

  @moduletag :tmp_dir

  @sha String.duplicate("a", 40)
  @a %{file: "test/a_test.exs", line: 3, name: "test one", module: "ATest"}
  @map %{
    version: 2,
    commit: @sha,
    elixir: "1.19.4",
    otp: "28",
    tests: [Map.put(@a, :functions, ["A.f/0", "A.g/1"])],
    leaks: [],
    ambient: ["C.boot/0"],
    modules_traced: 3,
    suite_exit: 0,
    counters: %{call_rows: 5, credited_by_label: 0, spawns: 2}
  }

  # The real task, in a VM holding the build's code paths and nothing else. Mix.Task
  # exits {:shutdown, code}, which is how `mix` itself sets the VM's status.
  defp compare(first, second) do
    code = """
    Mix.start()
    Mix.shell(Mix.Shell.IO)
    Mix.Tasks.Anchor.Sabotage.run(["coverage-compare", #{inspect(first)}, #{inspect(second)}])
    """

    ebin = CoverageMap |> :code.which() |> to_string() |> Path.dirname()

    System.cmd("timeout", ["60", "elixir", "-pa", ebin, "-e", code], stderr_to_stdout: true)
  end

  defp write!(dir, name, map) do
    path = Path.join(dir, name)
    :ok = CoverageFile.write(path, map)
    path
  end

  test "identical maps pass", %{tmp_dir: dir} do
    assert {output, 0} = compare(write!(dir, "one.etf", @map), write!(dir, "two.etf", @map))
    assert output =~ "identical"
  end

  test "one differing function fails, naming it", %{tmp_dir: dir} do
    second = %{@map | tests: [Map.put(@a, :functions, ["A.f/0"])]}

    assert {output, 1} = compare(write!(dir, "one.etf", @map), write!(dir, "two.etf", second))
    assert output =~ "differs: test/a_test.exs:3 test one ran A.g/1: only in the first build"
    assert output =~ "Fix: "
  end

  test "a leak in one build fails, printing each build's pairs", %{tmp_dir: dir} do
    second = %{@map | leaks: [%{from: @a, function: "A.late/0"}]}

    assert {output, 1} = compare(write!(dir, "one.etf", @map), write!(dir, "two.etf", second))
    assert output =~ "one.etf): no leak"
    assert output =~ "two.etf): leak: test/a_test.exs:3 test one left a process"
    assert output =~ "a leak list is identical only at empty"
    assert output =~ "Fix: make the process end inside its test"
  end

  test "a missing second build is exit 3, COULD NOT MEASURE", %{tmp_dir: dir} do
    missing = Path.join(dir, "two.etf")

    assert {output, 3} = compare(write!(dir, "one.etf", @map), missing)
    assert output =~ "COULD NOT MEASURE"
    assert output =~ "two.etf): no file"
  end
end
