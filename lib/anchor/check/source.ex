defmodule Anchor.Check.Source do
  @moduledoc """
  The AST/source acquisition boundary — the **Framework** edge (ADR 001).

  This is the ONLY module in Anchor that may call `Credo.Code.ast/1`,
  `Credo.SourceFile.source/1`, or `Credo.Code.to_lines/1`. Everything inward of
  here — the Managers and the Domain — receives plain Elixir data (a bare AST, a
  source string, a list of lines) and never touches a Credo acquisition
  function again.

  `Credo.Code.ast/1` returns `{:ok, ast}` (or `{:error, _}`); this module unwraps
  that tuple **exactly once** and passes the bare `ast` inward. Passing the
  wrapped tuple onward was the root of BUG 1: module-name extraction ran against
  `{:ok, ast}` and derived empty names, silently killing module-`pattern`
  selection and the transitive-dependency graph.
  """

  @doc """
  Acquires the bare AST for `source_file`.

  On a parse error it returns an empty block so Domain analysis degrades to "no
  facts" rather than crashing the Credo run.
  """
  @spec ast(Credo.SourceFile.t()) :: Macro.t()
  def ast(source_file) do
    case Credo.Code.ast(source_file) do
      {:ok, ast} -> ast
      {:error, _errors} -> {:__block__, [], []}
    end
  end

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
