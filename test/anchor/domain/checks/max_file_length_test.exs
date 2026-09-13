defmodule Anchor.Domain.Checks.MaxFileLengthTest do
  # Pure Domain detection for the `max_file_length` check: (lines, bare AST,
  # rules, filename) in, `[%Violation{}]` out. No Credo types, no IO. The
  # Framework mapping to `Credo.Issue` and the full 9-row acceptance matrix are
  # exercised in test/anchor/check/max_file_length_test.exs.
  #
  # Sabotage record:
  #   ../../../sabotage_records/max_file_length-20260913-dnd_136_t6_11_max_file_length.md
  use ExUnit.Case, async: true

  alias Anchor.Domain.Checks.MaxFileLength
  alias Anchor.Domain.Violation

  # `Source.to_lines/1` yields `{line_no, text}` pairs; mirror that shape here.
  defp lines(text) do
    text
    |> String.split("\n")
    |> Enum.with_index(1)
    |> Enum.map(fn {line, i} -> {i, line} end)
  end

  defp ast(text), do: Code.string_to_quoted!(text)

  defp detect(text, rule, filename \\ "lib/test.ex") do
    MaxFileLength.detect_violations(lines(text), ast(text), [rule], filename)
  end

  defp module_with_defs(n) do
    body = Enum.map_join(1..n, "\n", fn i -> "  def function_#{i}(), do: :ok" end)
    "defmodule MyModule do\n#{body}\nend"
  end

  describe "detect_violations/4" do
    test "flags an over-limit file (message/line/trigger)" do
      # 10 defs → 12 code lines, over a configured max of 10.
      violations =
        detect(module_with_defs(10), %{type: :max_file_length, max_lines: 10}, "lib/big.ex")

      assert [%Violation{} = violation] = violations

      assert violation.message ==
               "File contains 12 lines of code (maximum allowed: 10). " <>
                 "Consider breaking this file into smaller, more focused modules."

      assert violation.line == 1
      assert violation.trigger == "lib/big.ex"
    end

    test "defaults the maximum to 400 when :max_lines is absent" do
      # 399 defs → 401 code lines, over the 400 default.
      assert [%Violation{message: message}] =
               detect(module_with_defs(399), %{type: :max_file_length})

      assert message =~ "(maximum allowed: 400)"

      # Boundary: 398 defs → exactly 400 code lines, not strictly greater.
      assert detect(module_with_defs(398), %{type: :max_file_length}) == []
    end

    test "reads :max_lines from the atom key, never the string key" do
      # 10 defs → 12 code lines. The atom key must be honored (12 > 10 → flag);
      # a same-value STRING key must be ignored so the 400 default applies and
      # nothing triggers — this is the BUG 2 boundary.
      assert [%Violation{}] =
               detect(module_with_defs(10), %{type: :max_file_length, max_lines: 10})

      assert detect(module_with_defs(10), %{:type => :max_file_length, "max_lines" => 10}) == []
    end

    test "honors a quoted (string) :max_lines value" do
      # T3 (`Anchor.Config.parse_rule/1`) passes `rule["max_lines"]` through
      # verbatim, so a quoted YAML value (`max_lines: "10"`) surfaces as a binary
      # under the atom key. 10 defs → 12 code lines, over the coerced 10.
      assert [%Violation{message: message}] =
               detect(module_with_defs(10), %{type: :max_file_length, max_lines: "10"})

      assert message =~ "(maximum allowed: 10)"
    end

    test "counts code lines only, excluding blanks, comments and doc bodies" do
      text = """
      defmodule MyModule do
        @moduledoc \"\"\"
        Documentation line one.
        Documentation line two.
        \"\"\"

        # a comment

        def hello(), do: :ok
      end
      """

      # Real code lines: defmodule, def hello, end = 3.
      # Positive control at the boundary + below it.
      assert detect(text, %{type: :max_file_length, max_lines: 3}) == []

      assert [%Violation{message: message}] =
               detect(text, %{type: :max_file_length, max_lines: 2})

      assert message =~ "File contains 3 lines of code (maximum allowed: 2)"
    end

    test "excludes a @doc false line from the count" do
      text = """
      defmodule MyModule do
        @doc false
        def internal(), do: :ok
        def other(), do: :ok
      end
      """

      # 4 real code lines; @doc false excluded.
      assert detect(text, %{type: :max_file_length, max_lines: 4}) == []
      assert [%Violation{}] = detect(text, %{type: :max_file_length, max_lines: 3})
    end
  end
end
