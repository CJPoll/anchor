defmodule Anchor.Check.Source do
  @moduledoc """
  The AST/source acquisition boundary — the **Framework** edge (ADR 001).

  This is the ONLY module in Anchor that may call `Credo.Code.ast/1`,
  `Credo.SourceFile.source/1`, or `Credo.Code.to_lines/1`. Everything inward of
  here — the Managers and the Domain — receives plain Elixir data (a bare AST, a
  source string, a list of lines) and never touches a Credo acquisition
  function again.

  `Credo.Code.ast/1` returns `{:ok, ast}` (or `{:error, _}`); this module
  converts that result **exactly once** — `{:ok, ast}` or
  `{:error, {line, message}}`, with no Credo type left in it — and the caller
  passes the bare `ast` inward. Passing the
  wrapped tuple onward was the root of BUG 1: module-name extraction ran against
  `{:ok, ast}` and derived empty names, silently killing module-`pattern`
  selection and the transitive-dependency graph.
  """

  @doc """
  Acquires the bare AST for `source_file`.

  Returns `{:ok, ast}`, or `{:error, {line, message}}` when the file does not
  parse. The error is data, not an empty AST (DND-1265): an empty AST reads as
  "a file with no dependencies", so every rule would pass over a file nothing
  checked. The caller reports it through `Anchor.Domain.Failures`.
  """
  @spec ast(Credo.SourceFile.t()) ::
          {:ok, Macro.t()} | {:error, {pos_integer() | nil, String.t()}}
  def ast(source_file) do
    case Credo.Code.ast(source_file) do
      {:ok, ast} -> {:ok, ast}
      {:error, _credo_issues} -> {:error, parse_error(source_file)}
    end
  end

  # Credo's parse-error issue keeps the parser's message but drops the token it
  # stopped at (`unexpected reserved word: ` with no `end`), so the error is
  # re-derived from the parser itself, only on this failure path.
  defp parse_error(source_file) do
    case Code.string_to_quoted(source(source_file), emit_warnings: false) do
      {:error, {meta, message, token}} -> {line(meta), error_text(message, token)}
      _unexpected -> {nil, "the parser rejected the file"}
    end
  end

  # The parser's position is a line number or a keyword list of error metadata.
  defp line(line) when is_integer(line), do: line
  defp line(meta) when is_list(meta), do: Keyword.get(meta, :line)
  defp line(_other), do: nil

  defp error_text({prefix, suffix}, token), do: "#{prefix}#{token}#{suffix}"
  defp error_text(message, token), do: "#{message}#{token}"

  @doc """
  Returns the raw source string for `source_file`.
  """
  @spec source(Credo.SourceFile.t()) :: String.t()
  def source(source_file), do: Credo.SourceFile.source(source_file)

  @doc """
  Returns `source_file` as a list of `{line_no, line_text}` tuples.
  """
  @spec to_lines(Credo.SourceFile.t()) :: [{integer(), String.t()}]
  def to_lines(source_file), do: Credo.Code.to_lines(source_file)
end
