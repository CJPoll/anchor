defmodule Anchor.Domain.Checks.FrameworkTestMocksManagerAttributeNamesTest do
  # A module attribute named like a form the check reads (`@setup
  # :verify_on_exit!`, `@expect ...`, `@def expect(...)`) is
  # `{:@, meta, [{name, meta, [value]}]}`: the inner node has the shape of the
  # call. Its name is never code, so it neither verifies, nor expects, nor
  # defines `expect`, for every name in the special-names table and the
  # check's own names.
  #
  # Sabotage record:
  #   ../../../sabotage_records/framework_test_mocks_manager-20261127-athena_DND_8063_framework_tests_mock_manager.md
  use ExUnit.Case, async: true

  alias Anchor.Domain.Checks.FrameworkTestMocksManager, as: Check

  @attribute_names "test/fixtures/special_variable_names.txt"
                   |> File.read!()
                   |> String.split()
                   |> Kernel.++(~w(setup expect verify_on_exit! verify!))

  @rules [%{mock_patterns: ["*Mock"]}]

  defp detect(source) do
    source
    |> Code.string_to_quoted!(columns: true)
    |> Check.detect_violations(@rules)
    |> Enum.map(& &1.trigger)
  end

  test "the plain-named baseline: an expectation with no verification is reported" do
    source = """
    defmodule AppTest do
      @value :verify_on_exit!
      test "t", do: expect(App.SearchMock, :search, fn _ -> :ok end)
    end
    """

    assert detect(source) == ["verify_on_exit!"]
  end

  for name <- @attribute_names do
    test "an attribute named @#{name} verifies nothing" do
      source = """
      defmodule AppTest do
        @#{unquote(name)} :verify_on_exit!
        test "t", do: expect(App.SearchMock, :search, fn _ -> :ok end)
      end
      """

      assert detect(source) == ["verify_on_exit!"]
    end
  end

  test "an attribute named @def holding an expect head does not define expect" do
    source = """
    defmodule AppTest do
      @def expect(a, b, c)
      setup :verify_on_exit!
      test "t", do: expect(App.SearchMock, :search, fn _ -> :ok end)
    end
    """

    assert detect(source) == []
  end
end
