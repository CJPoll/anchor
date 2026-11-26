defmodule Anchor.Check.FrameworkTestMocksManagerTest do
  # Framework tests for `framework_test_mocks_manager`: the thin
  # `Anchor.Check.FrameworkTestMocksManager` shell's `check_file/3`, from a
  # parsed `Credo.SourceFile` to `Credo.Issue`s. Detection is the Domain
  # module's (Anchor.Domain.Checks.FrameworkTestMocksManagerTest); selection
  # by a real `.anchor.yml` is in Anchor.E2E.ChecksE2ETest.
  #
  # Sabotage record:
  #   ../../sabotage_records/framework_test_mocks_manager-20261127-athena_DND_8063_framework_tests_mock_manager.md
  use ExUnit.Case, async: true

  alias Anchor.Check.FrameworkTestMocksManager
  alias Credo.SourceFile

  test "a framework test that never expects on a manager double is one issue, with Fix" do
    source = """
    defmodule AppWeb.SearchControllerTest do
      test "searches", %{conn: conn}, do: post(conn, "/search")
    end
    """

    assert [issue] = run_check(source)
    assert issue.trigger == "expect"
    assert issue.line_no == 1
    assert issue.message =~ "Framework test sets no expectation on a manager double"
    assert issue.message =~ "Fix: expect the call on a manager double (*.Managers.*Mock)"
    assert issue.category == :design
  end

  test "one that expects on and verifies a manager double has no issue (the control)" do
    source = """
    defmodule AppWeb.SearchControllerTest do
      setup :verify_on_exit!
      test "searches", do: expect(App.Managers.SearchMock, :search, fn _ -> :ok end)
    end
    """

    assert run_check(source) == []
  end

  defp run_check(source) do
    rules = [%{type: :framework_test_mocks_manager, mock_patterns: ["*.Managers.*Mock"]}]

    FrameworkTestMocksManager.check_file(
      SourceFile.parse(source, "test/app_web/search_controller_test.exs"),
      rules,
      []
    )
  end
end
