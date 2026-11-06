defmodule Anchor.Adapters.SuiteRunnerTest do
  # DND-5691: compile first, then run. A real `mix` in a VM of its own, over a
  # fixture project written to a tmp dir, because Mix.Task.run("test") runs once
  # per VM and this VM is already running a suite.
  # Sabotage record: ../../sabotage_records/coverage_attribution-20261106-dnd_5691_causal_attribution.md
  use ExUnit.Case, async: true

  alias Anchor.Adapters.SuiteRunner

  @moduletag :tmp_dir

  @mix_exs """
  defmodule Fixture.MixProject do
    use Mix.Project

    def project,
      do: [app: :suite_runner_fixture, version: "0.1.0", deps: [], prune_code_paths: false]
  end
  """

  defp run_suite(dir, files, args) do
    File.mkdir_p!(Path.join(dir, "test"))
    File.write!(Path.join(dir, "mix.exs"), @mix_exs)
    File.write!(Path.join(dir, "test/test_helper.exs"), "ExUnit.start()\n")
    for {name, body} <- files, do: File.write!(Path.join(dir, "test/#{name}"), body)

    out = Path.join(dir, "result.etf")
    ebin = :code.which(SuiteRunner) |> Path.dirname()

    code = """
    result = #{inspect(SuiteRunner)}.run(#{inspect(args)})
    File.write!(#{inspect(out)}, :erlang.term_to_binary(result))
    """

    {output, exit_code} =
      System.cmd("elixir", ["-pa", ebin, "-S", "mix", "run", "-e", code],
        cd: dir,
        env: [{"MIX_ENV", "test"}, {"MIX_BUILD_PATH", nil}, {"MIX_DEPS_PATH", nil}],
        stderr_to_stdout: true
      )

    assert exit_code == 0, output
    {out |> File.read!() |> :erlang.binary_to_term(), output}
  end

  # Row 1. ExUnit.run/0 sees the tests only if Mix did not take them first, so a
  # run that did not compile first has total 0 here, whatever the timing.
  test "1: no test starts before every test file has compiled", %{tmp_dir: dir} do
    files = [
      {"a_async_test.exs",
       """
       defmodule AAsyncTest do
         use ExUnit.Case, async: true

         test "the last file compiled before this ran" do
           assert :persistent_term.get(:z_compiled, false)
         end
       end
       """},
      {"z_late_test.exs",
       """
       defmodule ZLateTest do
         :persistent_term.put(:z_compiled, true)
         use ExUnit.Case
         test "runs", do: :ok
       end
       """}
    ]

    assert {{:passed, 2}, _output} = run_suite(dir, files, [])
  end

  test "2: a failing suite is reported, not raised", %{tmp_dir: dir} do
    files = [
      {"a_test.exs",
       """
       defmodule ATest do
         use ExUnit.Case
         test "fails", do: flunk("no")
         test "passes", do: :ok
       end
       """}
    ]

    assert {{:failed, "1 of 2 test(s) failed", 2}, _output} = run_suite(dir, files, [])
  end

  test "3: filters reach ExUnit, and the counts say so", %{tmp_dir: dir} do
    files = [
      {"a_test.exs",
       """
       defmodule ATest do
         use ExUnit.Case

         @tag :tagged
         test "does not start", do: flunk("it started")

         test "starts", do: :ok
       end
       """}
    ]

    assert {{:passed, 2}, _output} = run_suite(dir, files, ["--exclude", "tagged"])
  end

  # Mix's branch for this flag discards what the compiler returned, so this was
  # otherwise a smaller map that looked whole.
  test "a test file that does not compile is a failure naming it, and no test runs", %{
    tmp_dir: dir
  } do
    files = [
      {"a_test.exs",
       """
       defmodule ATest do
         use ExUnit.Case
         test "passes", do: :ok
       end
       """},
      {"b_test.exs", "defmodule BTest do\n  this_does_not_compile()\nend\n"}
    ]

    assert {{:failed, message, nil}, _output} = run_suite(dir, files, [])
    assert message =~ "did not compile"
    assert message =~ "test/b_test.exs"
  end

  test "a suite with no test file runs nothing, counted", %{tmp_dir: dir} do
    assert {{:passed, 0}, _output} = run_suite(dir, [], [])
  end
end
