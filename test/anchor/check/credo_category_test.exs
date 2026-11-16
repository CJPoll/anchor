defmodule Anchor.Check.CredoCategoryTest do
  # Framework: every Anchor check declares a category Credo knows, so an issue
  # it raises carries a non-zero exit status and a wired check can fail a run.
  # Credo maps an unknown category to exit status 0 (the issue prints, the run
  # still exits 0), so a typo in a `category:` option silently disables the
  # check's enforcement.
  #
  use ExUnit.Case, async: true

  alias Anchor.Check.NoDiscardingArrowInWith
  alias Credo.Execution
  alias Credo.Execution.ExecutionIssues
  alias Credo.Execution.Task.AssignExitStatusForIssues
  alias Credo.SourceFile

  # Every module under lib/anchor/check/ that is a Credo check, found from the
  # compiled application rather than a hand-kept list, so a new check is
  # covered the moment it exists.
  defp check_modules do
    {:ok, modules} = :application.get_key(:anchor, :modules)

    modules
    |> Enum.filter(&String.starts_with?(Atom.to_string(&1), "Elixir.Anchor.Check."))
    |> Enum.filter(&function_exported?(&1, :__anchor_check__, 0))
  end

  describe "declared category" do
    test "the check set is not empty" do
      assert length(check_modules()) >= 15
    end

    test "every check declares a category for which Credo assigns a non-zero exit status" do
      bad =
        for check <- check_modules(),
            Credo.Check.to_exit_status(check.category()) == 0,
            do: {check, check.category()}

      assert bad == [], "checks declaring a category Credo does not know: #{inspect(bad)}"
    end

    test "every check's own exit_status/0 is non-zero" do
      bad = for check <- check_modules(), check.exit_status() == 0, do: check
      assert bad == []
    end
  end

  describe "issue through Credo's exit-status task" do
    test "an issue from a violating source makes the run exit non-zero" do
      source = """
      defmodule MyApp.Example do
        def f do
          with _ <- some_function() do
            :ok
          end
        end
      end
      """

      source_file = SourceFile.parse(source, "lib/some_module.ex")
      rule = %{type: :no_discarding_arrow_in_with}
      issues = NoDiscardingArrowInWith.check_file(source_file, [rule], [])
      assert [_] = issues

      exec = Execution.build()
      ExecutionIssues.append(exec, issues)
      exec = AssignExitStatusForIssues.call(exec, [])

      assert Execution.get_exit_status(exec) != 0
    end
  end
end
