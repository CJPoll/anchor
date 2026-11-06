defmodule Anchor.Adapters.SuiteRunner do
  @moduledoc """
  Runs a project's suite in this VM for the coverage map (DND-5474, DND-5691),
  the **Side Effect** adapter (ADR 001) behind `Anchor.Adapters.InProcessTests`.

  Two steps, so no compiler runs while a test does (DND-5691). Mix starts ExUnit
  before it requires the test files, and `ExUnit.Server` hands over each async
  module as soon as it is loaded, so a plain `mix test` puts compile-time calls
  inside test windows.

    1. `Mix.Task.run("test", args ++ ["--profile-require", "time", "--max-cases",
       "1"])` configures ExUnit and requires every test file without running one.
       A switch given twice takes its last value, so `--max-cases 1` comes last
       (the Manager also refuses test arguments that set it). Mix then prints
       "There are no tests to run", which means only that it ran none itself.
    2. `ExUnit.run/0`, whose counts are returned.

  That flag's branch in Mix discards what the compiler returned, so a test file
  that did not compile is found here: every file Mix would load must be in
  `Code.required_files/0`. Without this a broken file would just make the map
  smaller. A later Elixir whose flag behaves differently fails the same way, or
  the Manager's window count does: never a smaller map.
  """

  @behaviour Anchor.Adapters.InProcessTests

  @impl Anchor.Adapters.InProcessTests
  def run(args) do
    Mix.Task.run("test", args ++ ["--profile-require", "time", "--max-cases", "1"])

    case not_required() do
      [] -> result(ExUnit.run())
      missing -> {:failed, did_not_compile(missing), nil}
    end
  rescue
    error -> {:failed, Exception.message(error), nil}
  end

  defp result(%{failures: 0, total: total}), do: {:passed, total}

  defp result(%{failures: failures, total: total}),
    do: {:failed, "#{failures} of #{total} test(s) failed", total}

  # What Mix's own classification loads: test_paths, then test_load_filters.
  defp not_required do
    project = Mix.Project.config()
    filters = project[:test_load_filters] || [&String.ends_with?(&1, "_test.exs")]
    pattern = project[:test_pattern] || "*.{ex,exs}"
    required = Code.required_files()

    (project[:test_paths] || ["test"])
    |> Enum.flat_map(&Path.wildcard("#{&1}/**/#{pattern}"))
    |> Enum.filter(fn file ->
      Path.expand(file) not in required and Enum.any?(filters, &loads?(&1, file))
    end)
    |> Enum.sort()
  end

  defp loads?(filter, file) when is_function(filter, 1), do: filter.(file)
  defp loads?(filter, file) when is_binary(filter), do: filter == file

  # lib/ runs no regex outside GlobPattern, so a regex filter cannot be checked here,
  # and an unchecked one could hide a file that did not compile.
  defp loads?(filter, _file) do
    raise ArgumentError,
          "test_load_filters holds #{inspect(filter)}, which the coverage run cannot check. " <>
            "Fix: write it as a function"
  end

  defp did_not_compile(files) do
    {shown, hidden} = Enum.split(files, 5)
    more = if hidden == [], do: "", else: " and #{length(hidden)} more"
    "#{length(files)} test file(s) did not compile: #{Enum.join(shown, ", ")}#{more}"
  end
end
