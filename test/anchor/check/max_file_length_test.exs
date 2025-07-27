defmodule Anchor.Check.MaxFileLengthTest do
  use ExUnit.Case

  alias Anchor.Check.MaxFileLength
  alias Credo.SourceFile

  test "no issue when file is under default limit of 400 lines" do
    lines = Enum.map(1..396, fn i -> "  def function_#{i}(), do: :ok" end)
    source_file = "defmodule MyModule do\n#{Enum.join(lines, "\n")}\nend"

    rule = %{"type" => "max_file_length"}
    source = SourceFile.parse(source_file, "lib/test.ex")
    assert [] == MaxFileLength.check_file(source, [rule], [])
  end

  test "no issue when file is exactly at default limit of 400 lines" do
    lines = Enum.map(1..398, fn i -> "  def function_#{i}(), do: :ok" end)
    source_file = "defmodule MyModule do\n#{Enum.join(lines, "\n")}\nend"

    rule = %{"type" => "max_file_length"}
    source = SourceFile.parse(source_file, "lib/test.ex")
    assert [] == MaxFileLength.check_file(source, [rule], [])
  end

  test "detects file exceeding default limit of 400 lines" do
    lines = Enum.map(1..399, fn i -> "  def function_#{i}(), do: :ok" end)
    source_file = "defmodule MyModule do\n#{Enum.join(lines, "\n")}\nend"

    rule = %{"type" => "max_file_length"}
    source = SourceFile.parse(source_file, "lib/test.ex")
    issues = MaxFileLength.check_file(source, [rule], [])
    
    assert length(issues) == 1
    issue = hd(issues)
    assert issue.message =~ "File contains 401 lines (maximum allowed: 400)"
    assert issue.message =~ "Consider breaking this file into smaller"
    assert issue.line_no == 1
  end

  test "respects custom max_lines configuration as integer" do
    lines = Enum.map(1..99, fn i -> "  def function_#{i}(), do: :ok" end)
    source_file = "defmodule MyModule do\n#{Enum.join(lines, "\n")}\nend"

    rule = %{"type" => "max_file_length", "max_lines" => 100}
    source = SourceFile.parse(source_file, "lib/test.ex")
    issues = MaxFileLength.check_file(source, [rule], [])
    
    assert length(issues) == 1
    issue = hd(issues)
    assert issue.message =~ "File contains 101 lines (maximum allowed: 100)"
  end

  test "respects custom max_lines configuration as string" do
    lines = Enum.map(1..99, fn i -> "  def function_#{i}(), do: :ok" end)
    source_file = "defmodule MyModule do\n#{Enum.join(lines, "\n")}\nend"

    rule = %{"type" => "max_file_length", "max_lines" => "100"}
    source = SourceFile.parse(source_file, "lib/test.ex")
    issues = MaxFileLength.check_file(source, [rule], [])
    
    assert length(issues) == 1
    issue = hd(issues)
    assert issue.message =~ "File contains 101 lines (maximum allowed: 100)"
  end

  test "no issue when file is under custom limit" do
    lines = Enum.map(1..47, fn i -> "  def function_#{i}(), do: :ok" end)
    source_file = "defmodule MyModule do\n#{Enum.join(lines, "\n")}\nend"

    rule = %{"type" => "max_file_length", "max_lines" => 50}
    source = SourceFile.parse(source_file, "lib/test.ex")
    assert [] == MaxFileLength.check_file(source, [rule], [])
  end

  test "handles empty files" do
    source_file = ""

    rule = %{"type" => "max_file_length"}
    source = SourceFile.parse(source_file, "lib/test.ex")
    assert [] == MaxFileLength.check_file(source, [rule], [])
  end

  test "counts blank lines and comments" do
    source_file = "defmodule MyModule do\n  # This is a comment\n  def hello, do: :world\n  \n  # Another comment\n  \n  def goodbye, do: :moon\nend"

    rule = %{"type" => "max_file_length", "max_lines" => 5}
    source = SourceFile.parse(source_file, "lib/test.ex")
    issues = MaxFileLength.check_file(source, [rule], [])
    
    assert length(issues) == 1
    issue = hd(issues)
    assert issue.message =~ "File contains 8 lines (maximum allowed: 5)"
  end

  test "trigger contains filename" do
    lines = Enum.map(1..399, fn i -> "  def function_#{i}(), do: :ok" end)
    source_file = "defmodule MyModule do\n#{Enum.join(lines, "\n")}\nend"

    rule = %{"type" => "max_file_length"}
    source = SourceFile.parse(source_file, "lib/my_app/some_module.ex")
    issues = MaxFileLength.check_file(source, [rule], [])
    
    assert length(issues) == 1
    issue = hd(issues)
    assert issue.trigger == "lib/my_app/some_module.ex"
  end
end