defmodule Anchor.Domain.Checks.MaxFileLengthTest do
  # Pure Domain detection for the `max_file_length` check: an input of lines,
  # rules and filename in, `[%Violation{}]` out. No Credo types, no IO. The
  # Framework mapping to `Credo.Issue` and the full 9-row acceptance matrix are
  # exercised in test/anchor/check/max_file_length_test.exs.
  #
  # Sabotage records:
  #   ../../../sabotage_records/max_file_length-20260913-dnd_136_t6_11_max_file_length.md
  #   ../../../sabotage_records/max_file_length-20261127-athena_DND_8101_max_file_length_doc_lines.md
  use ExUnit.Case, async: true

  alias Anchor.Domain.Checks.MaxFileLength
  alias Anchor.Domain.Detector.Input
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
    MaxFileLength.detect(%Input{
      ast: ast(text),
      rules: [rule],
      lines: lines(text),
      filename: filename
    })
  end

  # The number of code lines the detector counts in `text`, read from the
  # violation a maximum of 1 produces. Every fixture below counts at least 2.
  defp code_lines(text) do
    [%Violation{message: message}] = detect(text, %{type: :max_file_length, max_lines: 1})
    [_match, count] = Regex.run(~r/File contains (\d+) lines of code/, message)
    String.to_integer(count)
  end

  defp module_with_defs(n) do
    body = Enum.map_join(1..n, "\n", fn i -> "  def function_#{i}(), do: :ok" end)
    "defmodule MyModule do\n#{body}\nend"
  end

  describe "detect/1" do
    test "flags an over-limit file (message/line/trigger)" do
      # 10 defs → 12 code lines, over a configured max of 10.
      violations =
        detect(module_with_defs(10), %{type: :max_file_length, max_lines: 10}, "lib/big.ex")

      assert [%Violation{} = violation] = violations

      assert violation.message ==
               "File contains 12 lines of code (maximum allowed: 10). " <>
                 "Consider breaking this file into smaller, more focused modules." <>
                 " Fix: at most 10 lines of code per file; split the module into smaller modules, each with one responsibility"

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

  describe "documentation annotations are not code, whatever their value" do
    test "excludes a ~S heredoc @moduledoc and @doc" do
      text = ~S'''
      defmodule MyApp.Thing do
        @moduledoc ~S"""
        Shows `#{name}` as written.
        """

        @doc ~S"""
        A second doc.
        """
        def a, do: 1
      end
      '''

      # defmodule, def a, end
      assert code_lines(text) == 3
    end

    test "excludes a one-line ~s doc" do
      text = ~S'''
      defmodule MyApp.Thing do
        @doc ~s(Returns "a".)
        def a, do: "a"
      end
      '''

      assert code_lines(text) == 3
    end

    test "excludes an interpolated heredoc doc" do
      text = ~S'''
      defmodule MyApp.Thing do
        @limit 10

        @doc """
        At most #{@limit} items.
        """
        def a, do: @limit
      end
      '''

      # defmodule, @limit, def a, end
      assert code_lines(text) == 4
    end

    test "excludes an interpolated one-line string doc" do
      text = ~S'''
      defmodule MyApp.Thing do
        @doc "Version #{1}."
        def a, do: 1
      end
      '''

      assert code_lines(text) == 3
    end

    test "excludes every line of a doc built by a function call" do
      text = ~S'''
      defmodule MyApp.Thing do
        @moduledoc String.trim("""
                   Trimmed.
                   """)

        @doc Enum.join(
               ["a", "b"],
               " "
             )
        def a, do: 1
      end
      '''

      assert code_lines(text) == 3
    end

    test "excludes every line of a doc built by a pipeline" do
      text = ~S'''
      defmodule MyApp.Thing do
        @moduledoc "README.md"
                   |> File.read!()
                   |> String.trim()

        def a, do: 1
      end
      '''

      assert code_lines(text) == 3
    end

    test "excludes a doc read from a module attribute, and counts the attribute's definition" do
      text = ~S'''
      defmodule MyApp.Thing do
        @shared "Shared words."

        @doc @shared
        def a, do: 1
      end
      '''

      # defmodule, @shared, def a, end
      assert code_lines(text) == 4
    end

    test "excludes every line of a doc metadata annotation" do
      text = ~S'''
      defmodule MyApp.Thing do
        @doc since: "1.0.0",
             deprecated: "Use b/0."
        def a, do: 1
      end
      '''

      assert code_lines(text) == 3
    end

    test "excludes a @typedoc heredoc and @typedoc false, and counts the types" do
      text = ~S'''
      defmodule MyApp.Thing do
        @typedoc """
        A name.
        """
        @type name :: String.t()
        @typedoc false
        @type id :: integer()
      end
      '''

      # defmodule, two @type lines, end
      assert code_lines(text) == 4
    end

    test "excludes @moduledoc false" do
      text = ~S'''
      defmodule MyApp.Thing do
        @moduledoc false
        def a, do: 1
      end
      '''

      assert code_lines(text) == 3
    end
  end

  describe "the lines around a documentation annotation are code" do
    test "counts the line after a heredoc doc's closing delimiter" do
      text = ~S'''
      defmodule MyApp.Thing do
        @moduledoc """
        Words.
        """
        @behaviour MyApp.Behaviour
        @doc """
        Words.
        """
        def a, do: 1
      end
      '''

      # defmodule, @behaviour, def a, end
      assert code_lines(text) == 4
    end

    test "counts the lines after a string doc written over two lines" do
      text = ~S'''
      defmodule MyApp.Thing do
        @doc "First line,
        second line."
        def a, do: 1
        def b, do: 2
      end
      '''

      assert code_lines(text) == 4
    end

    test "counts the lines after a one-line string doc" do
      text = ~S'''
      defmodule MyApp.Thing do
        @doc "Words."
        def a, do: 1
        def b, do: 2
      end
      '''

      assert code_lines(text) == 4
    end

    test "counts the lines after a one-line doc holding an escaped newline" do
      text = ~S'''
      defmodule MyApp.Thing do
        @doc "a\nb\nc"
        def a, do: 1
        def b, do: 2
        def c, do: 3
      end
      '''

      assert code_lines(text) == 5
    end

    test "excludes the whole of a heredoc doc that joins two lines with a backslash" do
      text = ~S'''
      defmodule MyApp.Thing do
        @doc """
        One sentence \
        over two lines.
        """
        def a, do: 1
      end
      '''

      assert code_lines(text) == 3
    end

    test "counts strings that are not documentation annotations" do
      text = ~S'''
      defmodule MyApp.Thing do
        @shortdoc "Words."
        @banner """
        Words.
        """
        def a do
          """
          Words.
          """
        end
      end
      '''

      assert code_lines(text) == 11
    end

    test "counts a line that reads a doc attribute" do
      text = ~S'''
      defmodule MyApp.Thing do
        @moduledoc "Words."
        def a, do: @moduledoc
      end
      '''

      assert code_lines(text) == 3
    end

    # The parser records no end for an annotation that code follows with no
    # newline or `;` between. `mix format` never writes this.
    test "excludes only the @ line of an annotation with no recorded end" do
      text = ~S'''
      defmodule MyApp.Thing do
        @moduledoc """
        Words.
        """ end
      '''

      # defmodule, the doc's body, the closing line that also holds `end`
      assert code_lines(text) == 3
    end
  end

  describe "a heredoc doc whose closing delimiter is the file's last line" do
    @source ~s|a = 1\nb = 2\n@moduledoc """\nWords.\n"""|

    test "is excluded when the file ends at the delimiter" do
      assert code_lines(@source) == 2
    end

    test "is excluded when a newline follows the delimiter" do
      assert code_lines(@source <> "\n") == 2
    end
  end

  describe "blank lines" do
    test "are not counted, whether empty or whitespace only, in or out of a doc" do
      text =
        ~s|defmodule MyApp.Thing do\n\n   \n\t\n  @doc """\n\n  Words.\n\n  """\n\n| <>
          ~s|  def a, do: 1\n\nend\n\n|

      assert code_lines(text) == 3
    end
  end
end
