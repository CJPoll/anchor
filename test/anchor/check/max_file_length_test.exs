defmodule Anchor.Check.MaxFileLengthTest do
  # The Framework-edge acceptance matrix for the `max_file_length` check, driven
  # through the backward-compatible `check_file/3` entry point (Base acquires the
  # AST via Source, the shell acquires the lines and delegates to the pure
  # `Anchor.Domain.Checks.MaxFileLength`, and the returned `%Violation{}`s are
  # mapped to `%Credo.Issue{}`). Rules are ATOM-keyed exactly as T3
  # (`Anchor.Config.parse_rule/1`) surfaces them — in particular the maximum is
  # `:max_lines` (BUG 2: the pre-refactor code read the string key "max_lines").
  #
  # The pure detector is exercised directly in
  # test/anchor/domain/checks/max_file_length_test.exs.
  #
  # Sabotage record:
  #   ../../sabotage_records/max_file_length-20260913-dnd_136_t6_11_max_file_length.md
  use ExUnit.Case, async: true

  alias Anchor.Check.MaxFileLength
  alias Credo.SourceFile

  @filename "lib/my_app/some_module.ex"

  # A module whose body is `n` single-line `def`s. Code-line count is therefore
  # exactly `n + 2` (the `defmodule` line, `n` def lines, the `end` line) — no
  # blanks, comments or docs, so the count is unambiguous.
  defp module_with_defs(n) do
    body = Enum.map_join(1..n, "\n", fn i -> "  def function_#{i}(), do: :ok" end)
    "defmodule MyModule do\n#{body}\nend"
  end

  defp source(text, filename), do: SourceFile.parse(text, filename)

  defp check(text, rule, filename \\ @filename) do
    MaxFileLength.check_file(source(text, filename), [rule], [])
  end

  describe "check_file/3" do
    # Row #1 — over the default 400 (no :max_lines) → one issue, message names
    # 401 code lines and the 400 default, on line 1, triggered by the filename.
    test "#1 flags a file over the default 400 (401 code lines, no max_lines)" do
      # 399 defs → 401 code lines.
      issues = check(module_with_defs(399), %{type: :max_file_length})

      assert [issue] = issues

      assert issue.message =~
               "File contains 401 lines of code (maximum allowed: 400)"

      assert issue.message =~ "Consider breaking this file into smaller"
      assert issue.line_no == 1
      assert issue.trigger == @filename
    end

    # Row #2 — exactly 400 code lines → no issue (strictly-greater triggers).
    test "#2 does not flag a file at exactly the default 400" do
      # 398 defs → 400 code lines.
      assert [] == check(module_with_defs(398), %{type: :max_file_length})
    end

    # Row #3 — honors a configured max_lines: 10 (12 code lines → one issue).
    test "#3 honors a configured max_lines of 10" do
      # 10 defs → 12 code lines.
      issues = check(module_with_defs(10), %{type: :max_file_length, max_lines: 10})

      assert [issue] = issues

      assert issue.message =~
               "File contains 12 lines of code (maximum allowed: 10)"
    end

    # Row #4 — under the configured max → no issue.
    test "#4 does not flag a file under the configured max_lines" do
      # 3 defs → 5 code lines, under the configured 10.
      assert [] == check(module_with_defs(3), %{type: :max_file_length, max_lines: 10})
    end

    # Row #5 — blank / whitespace-only lines are not counted (boundary proof).
    test "#5 excludes blank and whitespace-only lines from the count" do
      lines =
        ["defmodule MyModule do"] ++
          List.duplicate("", 25) ++
          ["  def hello(), do: :ok"] ++
          List.duplicate("   ", 25) ++
          ["end"]

      text = Enum.join(lines, "\n")

      # 3 real code lines + 50 blank lines. At the 3-line boundary the blanks are
      # excluded, so nothing triggers; were they counted (53) it would.
      assert [] == check(text, %{type: :max_file_length, max_lines: 3})

      # Positive control: detection is live for this exact source.
      assert [issue] = check(text, %{type: :max_file_length, max_lines: 2})
      assert issue.message =~ "File contains 3 lines of code (maximum allowed: 2)"
    end

    # Row #6 — full-line `#` comments are not counted (boundary proof).
    test "#6 excludes full-line comments from the count" do
      lines =
        ["defmodule MyModule do"] ++
          List.duplicate("  # a comment line", 30) ++
          ["  def hello(), do: :ok", "end"]

      text = Enum.join(lines, "\n")

      # 3 real code lines + 30 comment lines. At the boundary the comments are
      # excluded (3 not > 3); were they counted (33) it would trigger.
      assert [] == check(text, %{type: :max_file_length, max_lines: 3})

      # Positive control.
      assert [issue] = check(text, %{type: :max_file_length, max_lines: 2})
      assert issue.message =~ "File contains 3 lines of code (maximum allowed: 2)"
    end

    # Row #7 — @moduledoc / @doc heredoc bodies are not counted.
    test "#7 excludes @moduledoc and @doc heredoc bodies from the count" do
      text = """
      defmodule MyModule do
        @moduledoc \"\"\"
        Line one of the module documentation.
        Line two of the module documentation.
        Line three of the module documentation.
        Line four of the module documentation.
        Line five of the module documentation.
        \"\"\"

        @doc \"\"\"
        Doc line one.
        Doc line two.
        Doc line three.
        \"\"\"

        def hello(), do: :ok
      end
      """

      # Real code lines: defmodule, def hello, end = 3. The doc bodies (~11 lines)
      # are excluded, so with a generous max of 10 nothing triggers; were the doc
      # bodies counted the file would be well over 10.
      assert [] == check(text, %{type: :max_file_length, max_lines: 10})

      # Positive control: the same source triggers once the max drops below the
      # real code-line count.
      assert [issue] = check(text, %{type: :max_file_length, max_lines: 2})
      assert issue.message =~ "File contains 3 lines of code (maximum allowed: 2)"
    end

    # Row #8 — a `@doc false` line is not counted (boundary proof).
    test "#8 excludes a @doc false line from the count" do
      text = """
      defmodule MyModule do
        @doc false
        def internal(), do: :ok
        def other(), do: :ok
      end
      """

      # Real code lines: defmodule, def internal, def other, end = 4. At the
      # 4-line boundary the `@doc false` line is excluded (4 not > 4); were it
      # counted (5) it would trigger.
      assert [] == check(text, %{type: :max_file_length, max_lines: 4})

      # Positive control: detection is live for this exact source.
      assert [issue] = check(text, %{type: :max_file_length, max_lines: 3})
      assert issue.message =~ "File contains 4 lines of code (maximum allowed: 3)"
    end

    # Row #9 — the message reflects the code-line count only (not blanks/comments).
    test "#9 message reports code lines only, not blank or comment lines" do
      # 10 defs → 12 code lines, then 25 blank + 25 comment lines interleaved.
      filler =
        (List.duplicate("", 25) ++ List.duplicate("  # noise", 25))
        |> Enum.join("\n")

      text = "#{module_with_defs(10)}\n#{filler}"

      issues = check(text, %{type: :max_file_length, max_lines: 5})

      assert [issue] = issues

      assert issue.message =~
               "File contains 12 lines of code (maximum allowed: 5)"
    end
  end
end
