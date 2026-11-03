defmodule Anchor.Domain.Sabotage.TestPathTest do
  # DND-5640: the one rule for a path handed to `mix test`'s argv.
  # Sabotage record: ../../../sabotage_records/sabotage-20261103-dnd_5640_test_path.md
  use ExUnit.Case, async: true

  alias Anchor.Domain.Sabotage.TestPath

  test "positive control: a project test file, with or without a line, is accepted" do
    assert TestPath.check("test/a_test.exs") == :ok
    assert TestPath.check("apps/core/test/x/b_test.exs") == :ok
    assert TestPath.check_arg("test/a_test.exs:12") == :ok
    assert TestPath.safe_arg?("test/a_test.exs:12")
  end

  test "an option is refused: --opt never reaches the argv" do
    assert TestPath.check("--include") == {:error, :option}
    assert TestPath.check("--only_test.exs") == {:error, :option}
    assert TestPath.check_arg("--include=slow:1") == {:error, :option}
    refute TestPath.safe_arg?("-x_test.exs")
  end

  test "../ is refused: a test file outside the project" do
    assert TestPath.check("../x_test.exs") == {:error, :parent_segment}
    assert TestPath.check("test/../../x_test.exs") == {:error, :parent_segment}
  end

  test "an absolute path is refused" do
    assert TestPath.check("/abs/x_test.exs") == {:error, :absolute}
    assert TestPath.check_arg("/etc/x_test.exs:3") == {:error, :absolute}
  end

  test "a/../b is refused, even when it stays inside the project" do
    assert TestPath.check("a/../b_test.exs") == {:error, :parent_segment}
  end

  test "an empty path, an empty segment and a file that is not a _test.exs file are refused" do
    assert TestPath.check("") == {:error, :empty}
    assert TestPath.check("test//a_test.exs") == {:error, :empty_segment}
    assert TestPath.check("test/a.exs") == {:error, :not_a_test_file}
    assert TestPath.check("mix.exs") == {:error, :not_a_test_file}
  end

  test "each reason has words for a refusal line" do
    for reason <- [:empty, :option, :absolute, :parent_segment, :empty_segment, :not_a_test_file] do
      assert TestPath.describe(reason) =~ ~r/\w/
    end
  end
end
