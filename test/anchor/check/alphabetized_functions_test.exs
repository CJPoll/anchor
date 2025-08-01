defmodule Anchor.Check.AlphabetizedFunctionsTest do
  use ExUnit.Case

  alias Anchor.Check.AlphabetizedFunctions
  alias Credo.SourceFile

  test "no issues when functions are alphabetized in :separate mode (default)" do
    source_file = """
    defmodule MyModule do
      def apple(), do: :ok
      def banana(), do: :ok
      def cherry(), do: :ok

      defp apricot(), do: :ok
      defp blueberry(), do: :ok
      defp cranberry(), do: :ok
    end
    """

    rule = %{"type" => "alphabetized_functions"}
    source = SourceFile.parse(source_file, "lib/test.ex")
    assert [] == AlphabetizedFunctions.check_file(source, [rule], [])
  end

  test "detects out-of-order public functions in :separate mode" do
    source_file = """
    defmodule MyModule do
      def cherry(), do: :ok
      def apple(), do: :ok
      def banana(), do: :ok

      defp apricot(), do: :ok
      defp blueberry(), do: :ok
    end
    """

    rule = %{"type" => "alphabetized_functions", "mode" => :separate}
    source = SourceFile.parse(source_file, "lib/test.ex")
    issues = AlphabetizedFunctions.check_file(source, [rule], [])
    assert length(issues) == 3

    assert Enum.any?(issues, fn issue ->
      issue.message =~ "public function `apple/0` is not in alphabetical order" and
      issue.line_no == 3
    end)

    assert Enum.any?(issues, fn issue ->
      issue.message =~ "public function `banana/0` is not in alphabetical order" and
      issue.line_no == 4
    end)
  end

  test "detects out-of-order private functions in :separate mode" do
    source_file = """
    defmodule MyModule do
      def apple(), do: :ok
      def banana(), do: :ok

      defp cranberry(), do: :ok
      defp apricot(), do: :ok
      defp blueberry(), do: :ok
    end
    """

    rule = %{"type" => "alphabetized_functions", "mode" => :separate}
    source = SourceFile.parse(source_file, "lib/test.ex")
    issues = AlphabetizedFunctions.check_file(source, [rule], [])
    assert length(issues) == 3

    assert Enum.any?(issues, fn issue ->
      issue.message =~ "private function `apricot/0` is not in alphabetical order" and
      issue.line_no == 6
    end)

    assert Enum.any?(issues, fn issue ->
      issue.message =~ "private function `blueberry/0` is not in alphabetical order" and
      issue.line_no == 7
    end)
  end

  test "handles functions with same name but different arities" do
    source_file = """
    defmodule MyModule do
      def foo(a, b), do: a + b
      def foo(a), do: a
      def foo(), do: :ok
    end
    """

    rule = %{"type" => "alphabetized_functions"}
    source = SourceFile.parse(source_file, "lib/test.ex")
    issues = AlphabetizedFunctions.check_file(source, [rule], [])
    assert length(issues) == 2

    # foo/0 should come before foo/1 and foo/2
    assert Enum.any?(issues, fn issue ->
      issue.message =~ "public function `foo/2` is not in alphabetical order"
    end)

    assert Enum.any?(issues, fn issue ->
      issue.message =~ "public function `foo/0` is not in alphabetical order"
    end)
  end

  test "case-insensitive sorting" do
    source_file = """
    defmodule MyModule do
      def Apple(), do: :ok
      def BANANA(), do: :ok
      def cherry(), do: :ok
    end
    """

    rule = %{"type" => "alphabetized_functions"}
    source = SourceFile.parse(source_file, "lib/test.ex")
    issues = AlphabetizedFunctions.check_file(source, [rule], [])
    assert issues == []
  end

  test ":all mode checks all functions together" do
    source_file = """
    defmodule MyModule do
      def cherry(), do: :ok
      defp apple(), do: :ok
      def banana(), do: :ok
    end
    """

    rule = %{"type" => "alphabetized_functions", "mode" => :all}
    source = SourceFile.parse(source_file, "lib/test.ex")
    issues = AlphabetizedFunctions.check_file(source, [rule], [])
    assert length(issues) == 3

    assert Enum.any?(issues, fn issue ->
      issue.message =~ "function `apple/0` is not in alphabetical order" and
      issue.message =~ "It should appear after the beginning"
    end)
  end

  test ":public_only mode only checks public functions" do
    source_file = """
    defmodule MyModule do
      def banana(), do: :ok
      def apple(), do: :ok
      
      defp zebra(), do: :ok
      defp aardvark(), do: :ok
    end
    """

    rule = %{"type" => "alphabetized_functions", "mode" => :public_only}
    source = SourceFile.parse(source_file, "lib/test.ex")
    issues = AlphabetizedFunctions.check_file(source, [rule], [])
    assert length(issues) == 2

    assert Enum.any?(issues, fn issue ->
      issue.message =~ "public function `apple/0` is not in alphabetical order"
    end)
  end

  test "handles functions with guards" do
    source_file = """
    defmodule MyModule do
      def banana(x) when is_integer(x), do: x
      def apple(x) when is_atom(x), do: x
      def cherry(x), do: x
    end
    """

    rule = %{"type" => "alphabetized_functions"}
    source = SourceFile.parse(source_file, "lib/test.ex")
    issues = AlphabetizedFunctions.check_file(source, [rule], [])
    assert length(issues) == 2

    assert Enum.any?(issues, fn issue ->
      issue.message =~ "public function `apple/1` is not in alphabetical order"
    end)

    assert Enum.any?(issues, fn issue ->
      issue.message =~ "public function `banana/1` is not in alphabetical order"
    end)
  end

  test "handles macros" do
    source_file = """
    defmodule MyModule do
      defmacro cherry(), do: quote do: :ok
      defmacro apple(), do: quote do: :ok
      
      defmacrop zebra(), do: quote do: :ok
      defmacrop aardvark(), do: quote do: :ok
    end
    """

    rule = %{"type" => "alphabetized_functions"}
    source = SourceFile.parse(source_file, "lib/test.ex")
    issues = AlphabetizedFunctions.check_file(source, [rule], [])
    assert length(issues) == 4
  end

  test "mode can be provided as string" do
    source_file = """
    defmodule MyModule do
      def cherry(), do: :ok
      def apple(), do: :ok
    end
    """

    rule = %{"type" => "alphabetized_functions", "mode" => "all"}
    source = SourceFile.parse(source_file, "lib/test.ex")
    issues = AlphabetizedFunctions.check_file(source, [rule], [])
    assert length(issues) == 2
  end

  test "empty module has no issues" do
    source_file = """
    defmodule MyModule do
    end
    """

    rule = %{"type" => "alphabetized_functions"}
    source = SourceFile.parse(source_file, "lib/test.ex")
    assert [] == AlphabetizedFunctions.check_file(source, [rule], [])
  end

  test "module with only one function has no issues" do
    source_file = """
    defmodule MyModule do
      def alone(), do: :ok
    end
    """

    rule = %{"type" => "alphabetized_functions"}
    source = SourceFile.parse(source_file, "lib/test.ex")
    assert [] == AlphabetizedFunctions.check_file(source, [rule], [])
  end
end