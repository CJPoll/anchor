defmodule Anchor.Domain.Sabotage.DiffHunks do
  @moduledoc """
  Parses the text of `git diff --unified=0 --no-renames --src-prefix=a/
  --dst-prefix=b/` into the changed regions of each file, a **Domain** module
  (ADR 001). Pure: text in, data out.

  `parse/1` returns
  `{:ok, %{path => %{status: status, hunks: hunks, old_hunks: old_hunks}}}`:

    * `status` is `:added` (`--- /dev/null` or `new file mode`), `:deleted`
      (`+++ /dev/null` or `deleted file mode`) or `:modified`;
    * `hunks` is `[{new_start, new_count}]` in diff order, from each
      `@@ -a,b +c,d @@` header (a missing count is 1). A `new_count` of 0 is a
      pure deletion between new-side lines `new_start` and `new_start + 1`.
      A deleted file has no hunks.
    * `old_hunks` is `[{old_start, old_count}]`, the base side of each hunk,
      in the same order as `hunks` (one per hunk).

  Paths are the diff header's (with `--no-renames` both sides name the same
  file), unquoted when git C-quotes them.

  A hunk's body is consumed by its counts, never by how a line looks: under
  `--unified=0` a removed line `-- a/x` prints as `--- a/x`.

  It fails closed: a line git would not print with these flags, or a hunk whose
  body ends early, is `{:error, reason}`, never read as "no change"
  (`{:unrecognised_diff_line, line_number, text}`, `{:truncated_hunk, path}`).
  """

  @type status :: :added | :deleted | :modified
  @type range :: {non_neg_integer(), non_neg_integer()}
  @type file_change :: %{status: status(), hunks: [range()], old_hunks: [range()]}
  @type t :: %{String.t() => file_change()}

  @ignored_header_prefixes ["index ", "old mode ", "new mode ", "Binary files ", "\\ "]

  @doc """
  Parses diff text. See the module doc for the shape and the errors.
  """
  @spec parse(String.t()) :: {:ok, t()} | {:error, term()}
  def parse(text) do
    text
    |> lines()
    |> Enum.with_index(1)
    |> Enum.reduce_while(%{files: %{}, current: nil, body: nil}, &step/2)
    |> finish()
  end

  defp lines(""), do: []
  defp lines(text), do: text |> String.trim_trailing("\n") |> String.split("\n")

  defp finish({:error, _reason} = error), do: error

  defp finish(%{body: {_old, _new}, current: current}),
    do: {:error, {:truncated_hunk, current.path}}

  defp finish(state), do: {:ok, flush(state).files}

  # Inside a hunk body: consume exactly the counted removed and added lines.
  defp step({line, number}, %{body: {old_left, new_left}} = state) do
    case body_line(line, old_left, new_left) do
      {:ok, {0, 0}} -> {:cont, %{state | body: nil}}
      {:ok, counts} -> {:cont, %{state | body: counts}}
      :error -> {:halt, {:error, {:unrecognised_diff_line, number, line}}}
    end
  end

  defp step({"diff --git " <> rest, number}, state) do
    case header_path(rest) do
      {:ok, path} ->
        {:cont,
         %{flush(state) | current: %{path: path, status: :modified, hunks: [], old_hunks: []}}}

      :error ->
        {:halt, {:error, {:unrecognised_diff_line, number, "diff --git " <> rest}}}
    end
  end

  defp step({line, number}, %{current: nil}),
    do: {:halt, {:error, {:unrecognised_diff_line, number, line}}}

  defp step({line, number}, state) do
    case file_line(line, state.current) do
      {:ok, current} -> {:cont, %{state | current: current}}
      {:hunk, current, body} -> {:cont, %{state | current: current, body: body}}
      :error -> {:halt, {:error, {:unrecognised_diff_line, number, line}}}
    end
  end

  defp body_line("\\" <> _marker, old_left, new_left), do: {:ok, {old_left, new_left}}

  defp body_line("-" <> _removed, old_left, new_left) when old_left > 0,
    do: {:ok, {old_left - 1, new_left}}

  defp body_line("+" <> _added, old_left, new_left) when new_left > 0,
    do: {:ok, {old_left, new_left - 1}}

  defp body_line(_line, _old_left, _new_left), do: :error

  defp file_line("new file mode " <> _mode, current), do: {:ok, %{current | status: :added}}
  defp file_line("deleted file mode " <> _mode, current), do: {:ok, deleted(current)}
  defp file_line("--- " <> side, current), do: {:ok, old_side(side, current)}
  defp file_line("+++ " <> side, current), do: {:ok, new_side(side, current)}
  defp file_line("@@ " <> header, current), do: hunk(header, current)

  defp file_line(line, current) do
    if String.starts_with?(line, @ignored_header_prefixes), do: {:ok, current}, else: :error
  end

  defp old_side(side, current) do
    if dev_null?(side), do: %{current | status: :added}, else: current
  end

  defp new_side(side, current) do
    if dev_null?(side), do: deleted(current), else: current
  end

  defp dev_null?(side), do: String.trim_trailing(side, "\t") == "/dev/null"

  defp deleted(current), do: %{current | status: :deleted, hunks: [], old_hunks: []}

  defp hunk(header, current) do
    with [old_range, new_range, "@@" | _context] <- String.split(header, " ", parts: 4),
         {:ok, {old_start, old_count}} <- range(old_range, "-"),
         {:ok, {new_start, new_count}} <- range(new_range, "+") do
      {:hunk, record_hunk(current, {new_start, new_count}, {old_start, old_count}),
       body_counts(old_count, new_count)}
    else
      _malformed -> :error
    end
  end

  # A deleted file's hunks are dropped: nothing of it is left to scope.
  defp record_hunk(%{status: :deleted} = current, _hunk, _old), do: current

  defp record_hunk(current, hunk, old),
    do: %{current | hunks: current.hunks ++ [hunk], old_hunks: current.old_hunks ++ [old]}

  defp body_counts(old_count, new_count),
    do: if(old_count + new_count == 0, do: nil, else: {old_count, new_count})

  defp range(<<sign::binary-size(1), spec::binary>>, sign) do
    case String.split(spec, ",") do
      [start] -> counted(start, "1")
      [start, count] -> counted(start, count)
      _other -> :error
    end
  end

  defp range(_spec, _sign), do: :error

  defp counted(start, count) do
    with {start, ""} when start >= 0 <- Integer.parse(start),
         {count, ""} when count >= 0 <- Integer.parse(count) do
      {:ok, {start, count}}
    else
      _not_a_number -> :error
    end
  end

  defp flush(%{current: nil} = state), do: state

  defp flush(%{current: current} = state) do
    change = %{status: current.status, hunks: current.hunks, old_hunks: current.old_hunks}
    %{state | files: Map.put(state.files, current.path, change), current: nil}
  end

  # `a/<path> b/<path>`, each side C-quoted when git quotes the path. With
  # `--no-renames` both sides name one path, so an unquoted header splits at
  # its middle: the path may itself contain " b/".
  defp header_path("\"" <> _quoted = rest) do
    with {:ok, "a/" <> _old, " " <> new_side} <- unquote_path(rest),
         {:ok, "b/" <> path, ""} <- unquote_path(new_side) do
      {:ok, path}
    else
      _malformed -> :error
    end
  end

  defp header_path(rest) do
    size = byte_size(rest)
    path_size = div(size - 5, 2)

    with true <- size >= 7 and rem(size - 5, 2) == 0,
         "a/" <> old <- binary_part(rest, 0, path_size + 2),
         " b/" <> new <- binary_part(rest, path_size + 2, path_size + 3),
         true <- old == new do
      {:ok, new}
    else
      _malformed -> :error
    end
  end

  defp unquote_path("\"" <> rest), do: unquote_chars(rest, <<>>)
  defp unquote_path(_unquoted), do: :error

  defp unquote_chars("\"" <> rest, acc), do: {:ok, acc, rest}

  defp unquote_chars(<<?\\, a, b, c, rest::binary>>, acc)
       when a in ?0..?3 and b in ?0..?7 and c in ?0..?7,
       do: unquote_chars(rest, <<acc::binary, (a - ?0) * 64 + (b - ?0) * 8 + (c - ?0)>>)

  defp unquote_chars(<<?\\, escaped, rest::binary>>, acc),
    do: unquote_chars(rest, <<acc::binary, escape(escaped)>>)

  defp unquote_chars(<<char, rest::binary>>, acc), do: unquote_chars(rest, <<acc::binary, char>>)
  defp unquote_chars(<<>>, _acc), do: :error

  defp escape(?n), do: ?\n
  defp escape(?t), do: ?\t
  defp escape(?r), do: ?\r
  defp escape(?a), do: 7
  defp escape(?b), do: ?\b
  defp escape(?f), do: ?\f
  defp escape(?v), do: ?\v
  defp escape(other), do: other
end
