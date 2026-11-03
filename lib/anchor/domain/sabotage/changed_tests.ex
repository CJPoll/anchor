defmodule Anchor.Domain.Sabotage.ChangedTests do
  @moduledoc """
  The tests a diff touched (DND-5484): each `test "..."` call in a test file
  whose line span meets a changed range. Pure **Domain**: it parses the text
  with `Code.string_to_quoted/2` (`token_metadata: true`, so a `do` block's
  `end` line is known) and walks it.

  A test's name is ExUnit's: `"test <describe> <name>"` inside a `describe`,
  else `"test <name>"`. A range is a diff hunk's new side `{start, count}`:
  lines `start..start + count - 1`, or, for `count == 0`, the deletion point
  between `start` and `start + 1`, which meets a test holding both lines.
  A test whose name is not a literal string is not listed (its name is only
  known at run time).
  """

  @type test :: %{file: String.t(), line: pos_integer(), name: String.t()}

  @spec in_ranges(String.t(), String.t(), [{non_neg_integer(), non_neg_integer()}]) ::
          {:ok, [test()]} | {:error, {pos_integer() | nil, String.t()}}
  def in_ranges(source, path, ranges) do
    case Code.string_to_quoted(source, columns: true, token_metadata: true, emit_warnings: false) do
      {:ok, ast} ->
        tests =
          ast
          |> walk(nil, [])
          |> Enum.reverse()
          |> Enum.filter(fn {span, _line, _name} -> Enum.any?(ranges, &meets?(span, &1)) end)
          |> Enum.map(fn {_span, line, name} -> %{file: path, line: line, name: name} end)

        {:ok, tests}

      {:error, {meta, message, token}} ->
        {:error, {Keyword.get(List.wrap(meta), :line), "#{inspect(message)}#{inspect(token)}"}}
    end
  end

  defp walk({:describe, _meta, [name, [{:do, body} | _]]}, nil, acc) when is_binary(name),
    do: walk(body, name, acc)

  defp walk({:test, meta, [name | _rest]}, describe, acc) when is_binary(name) do
    line = Keyword.fetch!(meta, :line)
    last = meta |> Keyword.get(:end, line: line) |> Keyword.fetch!(:line)
    [{line..last//1, line, full_name(describe, name)} | acc]
  end

  defp walk({_call, _meta, args}, describe, acc) when is_list(args),
    do: Enum.reduce(args, acc, &walk(&1, describe, &2))

  defp walk({left, right}, describe, acc), do: walk(right, describe, walk(left, describe, acc))

  defp walk(list, describe, acc) when is_list(list),
    do: Enum.reduce(list, acc, &walk(&1, describe, &2))

  defp walk(_other, _describe, acc), do: acc

  defp full_name(nil, name), do: "test #{name}"
  defp full_name(describe, name), do: "test #{describe} #{name}"

  defp meets?(span, {start, 0}), do: start in span and (start + 1) in span

  defp meets?(span, {start, count}),
    do: not Range.disjoint?(span, start..(start + count - 1)//1)
end
