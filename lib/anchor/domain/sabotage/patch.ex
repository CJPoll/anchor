defmodule Anchor.Domain.Sabotage.Patch do
  @moduledoc """
  Source text edits for the sabotage generator (DND-5471). Pure **Domain**:
  strings in, strings out.

  A position is `{line, column}`, both 1-based, with columns counted in
  codepoints the way the Elixir tokenizer (and so Sourceror) counts them. A
  range is `{start, stop}` with `stop` exclusive. A position past the end of a
  line, or the line after the last, stands for the end of that line or the end
  of the text.
  """

  @type position :: {pos_integer(), pos_integer()}
  @type range :: {position(), position()}

  @no_newline "\\ No newline at end of file"

  @doc "`source` with the text of `range` replaced by `replacement`."
  @spec apply_range(String.t(), range(), String.t()) :: String.t()
  def apply_range(source, {start, stop}, replacement) when is_binary(replacement) do
    from = offset(source, start)
    to = offset(source, stop)

    if to < from, do: raise(ArgumentError, "Patch: range ends before it starts")

    binary_part(source, 0, from) <>
      replacement <> binary_part(source, to, byte_size(source) - to)
  end

  @doc "The text `range` covers in `source`."
  @spec slice(String.t(), range()) :: String.t()
  def slice(source, {start, stop}) do
    from = offset(source, start)
    to = offset(source, stop)
    binary_part(source, from, to - from)
  end

  @doc """
  A unified diff of `before` and `after` as one hunk with 3 lines of context,
  headed `--- a/<path>` and `+++ b/<path>`. The texts are expected to differ
  in one contiguous run of lines (one replacement); `""` when they are equal.
  """
  @spec unified_diff(String.t(), String.t(), String.t()) :: String.t()
  def unified_diff(_path, same, same), do: ""

  def unified_diff(path, before, after_text) do
    {old, old_eol?} = lines(before)
    {new, new_eol?} = lines(after_text)
    prefix = common_prefix(old, new)
    suffix = common_suffix(old, new, prefix)

    old_end = length(old) - suffix
    new_end = length(new) - suffix
    from = max(prefix - 3, 0)
    tail = min(suffix, 3)

    body =
      Enum.map(Enum.slice(old, from, prefix - from), &{" ", &1}) ++
        Enum.map(Enum.slice(old, prefix, old_end - prefix), &{"-", &1}) ++
        Enum.map(Enum.slice(new, prefix, new_end - prefix), &{"+", &1}) ++
        Enum.map(Enum.slice(old, old_end, tail), &{" ", &1})

    old_count = prefix - from + (old_end - prefix) + tail
    new_count = prefix - from + (new_end - prefix) + tail

    header =
      "@@ -#{hunk_start(from, old_count)},#{old_count} " <>
        "+#{hunk_start(from, new_count)},#{new_count} @@"

    {lines, _numbers} =
      Enum.map_reduce(body, {from, from}, fn {mark, text}, {old_no, new_no} ->
        old_no = if mark in [" ", "-"], do: old_no + 1, else: old_no
        new_no = if mark in [" ", "+"], do: new_no + 1, else: new_no

        no_eol? =
          (mark in [" ", "-"] and old_no == length(old) and not old_eol?) or
            (mark in [" ", "+"] and new_no == length(new) and not new_eol?)

        line = if no_eol?, do: mark <> text <> "\n" <> @no_newline, else: mark <> text
        {line, {old_no, new_no}}
      end)

    Enum.join(["--- a/#{path}", "+++ b/#{path}", header | lines], "\n") <> "\n"
  end

  defp common_prefix(old, new) do
    old
    |> Enum.zip(new)
    |> Enum.take_while(fn {a, b} -> a == b end)
    |> length()
  end

  defp common_suffix(old, new, prefix) do
    limit = min(length(old), length(new)) - prefix

    Enum.reverse(old)
    |> Enum.zip(Enum.reverse(new))
    |> Enum.take(limit)
    |> Enum.take_while(fn {a, b} -> a == b end)
    |> length()
  end

  defp hunk_start(from, 0), do: from
  defp hunk_start(from, _count), do: from + 1

  defp lines(text) do
    parts = String.split(text, "\n")

    case List.last(parts) do
      "" -> {Enum.drop(parts, -1), true}
      _last -> {parts, false}
    end
  end

  @doc "The byte offset of a position in `source` (clamped to the text's end)."
  @spec offset(String.t(), position()) :: non_neg_integer()
  def offset(source, {line, column}) when line >= 1 and column >= 1 do
    source
    |> String.split("\n")
    |> Enum.with_index(1)
    |> Enum.reduce_while(0, fn {text, number}, acc ->
      if number < line,
        do: {:cont, acc + byte_size(text) + 1},
        else: {:halt, acc + byte_size(String.slice(text, 0, column - 1))}
    end)
    |> min(byte_size(source))
  end
end
