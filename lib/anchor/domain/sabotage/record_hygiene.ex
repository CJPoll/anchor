defmodule Anchor.Domain.Sabotage.RecordHygiene do
  @moduledoc """
  What a sabotage record must never carry, and its removal (ADR 004). Pure
  **Domain**, and built on string and binary matching only: `GlobPattern` is
  the one regex compiler in `lib/`.

  A record is committed, often to a public repository, so it holds only what
  any checkout of the project would show. Two kinds of text a run's output
  picks up on one machine are not that:

    * **scheduler lines**: the status lines of the `test-slot` scheduler a
      run may be queued behind (`test-slot: ...`, and a WAITING block's
      holder, waiting and `--exclusive` lines). They name other runs, their
      labels and their checkouts. A line is one when it starts with one of
      those shapes (after its indent); a status line glued to the end of
      another line is not recognised;
    * **local paths**: a path under a home directory (`/home/<user>`,
      `/Users/<user>`, wherever it appears in a line, so `file:///home/...`,
      `-I/home/...` and `/var/home/...` count too) or under a worktree
      directory (`.local/worktrees/`). It names the user and, for a
      worktree, the branch.

  `redact/2` drops the scheduler lines and rewrites each local path. A path
  under the run's root becomes relative to it (the root itself `.`). Any other
  local path becomes `<worktree>` (under `.local/worktrees/`) or `<home>`,
  followed by the path from its first project directory on (`_build`, `deps`,
  `lib`, `test`, `tmp`, `apps`, `priv`, `config`), searched after the
  segment that names the repo (and, for a worktree, the branch's first
  segment); a branch whose later segments repeat a project directory's name
  keeps those segments. `leaks/1` names each line that still carries one, by
  number and kind, never by its text: it is the redaction's own scan, so a
  redacted text never leaks.

  A record also quotes the project's own source: each mutant's ` ```diff `
  block and the ` ```anchor-kills ` block (test names, read back by replay
  and verify). That text is in every checkout, so `redact_record/2` and
  `record_leaks/1` leave those blocks as they are and apply the rules to the
  rest. The rest includes failure output, which can quote a test's own code:
  a home path written as a literal in a failing assertion is rewritten too,
  since nothing tells it from one the run printed.
  """

  @type kind :: :scheduler_line | :local_path

  @typedoc "One reason a set of committed records fails `judge/3`."
  @type finding ::
          {:leak, String.t(), pos_integer(), kind()}
          | {:stale, String.t()}
          | {:missing, String.t()}
          | {:late, String.t()}

  @homes ["/home/", "/Users/"]
  @worktrees "/.local/worktrees"
  @markers ["/home/", "/Users/", "~/.local/worktrees"]
  # A path token ends at whitespace, a quote, a backtick, an angle bracket or
  # closing punctuation.
  @token_end [" ", "\t", "\r", "\"", "'", "`", "<", ">", ")", "]", "}", ",", ";", ":"]
  @project_dirs ~w(_build deps lib test tmp apps priv config)

  @doc """
  `text` without its scheduler lines, with each local path rewritten.
  `root` is the run's project root (absolute), or `nil` when unknown.
  """
  @spec redact(String.t(), String.t() | nil) :: String.t()
  def redact(text, root) when is_binary(text) do
    root = usable_root(root)

    text
    |> String.split("\n")
    |> Enum.reject(&scheduler_line?/1)
    |> Enum.map_join("\n", &(&1 |> strip_root(root) |> rewrite_all()))
  end

  @doc """
  A record's text, redacted as `redact/2` does outside its source blocks
  (` ```diff ` and ` ```anchor-kills `), which are kept as written.
  """
  @spec redact_record(String.t(), String.t() | nil) :: String.t()
  def redact_record(text, root) when is_binary(text) do
    root = usable_root(root)

    text
    |> String.split("\n")
    |> in_source_blocks()
    |> Enum.reject(fn {line, source?} -> not source? and scheduler_line?(line) end)
    |> Enum.map_join("\n", fn
      {line, true} -> line
      {line, false} -> line |> strip_root(root) |> rewrite_all()
    end)
  end

  @doc "`leaks/1` over a record's text outside its source blocks; line numbers are the record's."
  @spec record_leaks(String.t()) :: [{pos_integer(), kind()}]
  def record_leaks(text) when is_binary(text) do
    text
    |> String.split("\n")
    |> in_source_blocks()
    |> Enum.with_index(1)
    |> Enum.flat_map(fn
      {{_line, true}, _n} -> []
      {{line, false}, n} -> leak(line, n)
    end)
  end

  @doc "Each line (1-based) that carries a scheduler line or a local path, with its kind."
  @spec leaks(String.t()) :: [{pos_integer(), kind()}]
  def leaks(text) when is_binary(text) do
    text
    |> String.split("\n")
    |> Enum.with_index(1)
    |> Enum.flat_map(fn {line, n} -> leak(line, n) end)
  end

  @doc """
  The findings over committed `records` (`path => content`) against the
  shrink-only `listed` paths, whose files leaked before records were redacted:

    * `{:leak, path, line, kind}`: a record not listed carries a leak;
    * `{:stale, path}`: a listed record carries none any more (drop its entry);
    * `{:missing, path}`: a listed record is gone (drop its entry);
    * `{:late, path}`: a listed path's `-YYYYMMDD-` date is after `newest`, or
      it has none: only a record that existed when the list landed is listed.

  No findings is `[]`.
  """
  @spec judge(%{String.t() => String.t()}, [String.t()], Date.t()) :: [finding()]
  def judge(records, listed, %Date{} = newest) do
    listed_set = MapSet.new(listed)

    unlisted =
      for {path, content} <- Enum.sort(records),
          not MapSet.member?(listed_set, path),
          {line, kind} <- record_leaks(content),
          do: {:leak, path, line, kind}

    unlisted ++ Enum.flat_map(Enum.sort(listed), &listed_finding(&1, records, newest))
  end

  # -- judging ----------------------------------------------------------------

  defp listed_finding(path, records, newest),
    do: late(path, newest) ++ presence(path, Map.fetch(records, path))

  defp late(path, newest), do: if(dated_after?(path, newest), do: [{:late, path}], else: [])

  defp presence(path, :error), do: [{:missing, path}]

  defp presence(path, {:ok, content}),
    do: if(leaks(content) == [], do: [{:stale, path}], else: [])

  # The first `-YYYYMMDD-` of the file name, as a date after `newest`; a name
  # with none, or with no calendar date there, is late.
  defp dated_after?(path, newest) do
    case name_date(Path.basename(path)) do
      {:ok, date} -> Date.after?(date, newest)
      :error -> true
    end
  end

  defp name_date(name) do
    name
    |> String.split("-")
    |> Enum.drop(1)
    |> Enum.find(&(byte_size(&1) == 8 and digits?(&1)))
    |> date_of()
  end

  defp date_of(<<y::binary-size(4), m::binary-size(2), d::binary-size(2)>>) do
    case Date.from_iso8601("#{y}-#{m}-#{d}") do
      {:ok, date} -> {:ok, date}
      {:error, _reason} -> :error
    end
  end

  defp date_of(nil), do: :error

  defp digits?(text), do: text |> String.to_charlist() |> Enum.all?(&(&1 in ?0..?9))

  # -- source blocks ----------------------------------------------------------

  # Each line with whether it is inside a source block: from a ```diff or
  # ```anchor-kills fence to the next bare ``` (both fences count as inside).
  defp in_source_blocks(lines) do
    {tagged, _inside} = Enum.map_reduce(lines, false, &source_line/2)
    tagged
  end

  defp source_line(line, false) when line in ["```diff", "```anchor-kills"],
    do: {{line, true}, true}

  defp source_line(line, false), do: {{line, false}, false}
  defp source_line("```" = line, true), do: {{line, true}, false}
  defp source_line(line, true), do: {{line, true}, true}

  # -- scheduler lines --------------------------------------------------------

  defp leak(line, n) do
    cond do
      scheduler_line?(line) -> [{n, :scheduler_line}]
      rewrite_all(line) != line -> [{n, :local_path}]
      true -> []
    end
  end

  defp scheduler_line?(line) do
    trimmed = String.trim_leading(line)

    String.starts_with?(trimmed, ["test-slot: ", "this run is --exclusive (bench only)"]) or
      holder_line?(trimmed) or waiting_line?(trimmed)
  end

  # `units 1-4 (4 of weight 4): ...`, `unit 3: held (holder diagnostics ...`
  defp holder_line?(line) do
    (String.starts_with?(line, "units ") and String.contains?(line, " of weight ") and
       String.contains?(line, "): ")) or
      (String.starts_with?(line, "unit ") and String.contains?(line, ": held (holder diagnostics"))
  end

  # `2 waiting (this run: ...`
  defp waiting_line?(line) do
    case String.split(line, " waiting (this run: ", parts: 2) do
      [count, _rest] -> count != "" and digits?(count)
      [_none] -> false
    end
  end

  # -- the run's root ---------------------------------------------------------

  # An absolute root other than `/`, without its trailing slash: stripping `/`
  # would make every absolute path relative.
  defp usable_root(root) when is_binary(root) do
    trimmed = String.trim_trailing(root, "/")
    if String.starts_with?(trimmed, "/"), do: trimmed, else: nil
  end

  defp usable_root(_root), do: nil

  # `root/x` becomes `x`; `root` at a token's end becomes `.`; `root` followed
  # by anything else (a sibling such as `root2`) is left for rewrite_all/1.
  defp strip_root(line, nil), do: line

  defp strip_root(line, root) do
    [first | rest] = :binary.split(line, root, [:global])
    Enum.reduce(rest, first, &join_root(&2, &1, root))
  end

  defp join_root(acc, "/" <> after_root, _root), do: acc <> after_root

  defp join_root(acc, after_root, root) do
    if token_end?(after_root), do: acc <> "." <> after_root, else: acc <> root <> after_root
  end

  # -- local paths --------------------------------------------------------------

  # Rewrites until nothing is left to rewrite: a kept project tail can itself
  # hold a marker (`/home/u/x/lib/home/y`). Each pass shortens the line.
  defp rewrite_all(line) do
    case rewrite_paths(line, "") do
      ^line -> line
      rewritten -> rewrite_all(rewritten)
    end
  end

  # Each home or worktree path in `line`, rewritten; the rest kept.
  defp rewrite_paths(line, acc) do
    case :binary.match(line, @markers) do
      :nomatch ->
        acc <> line

      {at, _len} ->
        <<before::binary-size(at), from::binary>> = line
        {replacement, rest} = local_path(from)
        rewrite_paths(rest, acc <> before <> replacement)
    end
  end

  # `from` starts with a marker. Returns what replaces the path and the text
  # after it.
  defp local_path("~" <> _ = from), do: worktree_path(from, "~")

  defp local_path(from) do
    home = Enum.find(@homes, &String.starts_with?(from, &1))
    after_home = binary_part(from, byte_size(home), byte_size(from) - byte_size(home))
    {user, rest} = take_until(after_home, ["/" | @token_end])

    cond do
      user == "" -> {home, after_home}
      String.starts_with?(rest, @worktrees) -> worktree_path(rest, "")
      true -> home_path(rest)
    end
  end

  # `from` starts at `/.local/worktrees` (or `~/.local/worktrees`); `prefix`
  # is what stands before that slash.
  defp worktree_path(from, prefix) do
    skip = byte_size(prefix) + byte_size(@worktrees)
    {token, rest} = take_until(binary_part(from, skip, byte_size(from) - skip), @token_end)
    {"<worktree>" <> project_tail(token, 2), rest}
  end

  # `from` is the text after `/home/<user>`.
  defp home_path(from) do
    {token, rest} = take_until(from, @token_end)
    {"<home>" <> project_tail(token, 1), rest}
  end

  # `token` is `/seg/seg/...`. The path from its first project directory on,
  # after the first `skip` segments, or "" when it has none.
  defp project_tail(token, skip) do
    token
    |> String.split("/")
    |> Enum.drop(1 + skip)
    |> Enum.drop_while(&(&1 not in @project_dirs))
    |> joined_tail()
  end

  defp joined_tail([]), do: ""
  defp joined_tail(tail), do: "/" <> Enum.join(tail, "/")

  # Splits `text` at the first of `stops`: {before, from_the_stop_on}.
  defp take_until(text, stops) do
    case :binary.match(text, stops) do
      :nomatch -> {text, ""}
      {at, _len} -> {binary_part(text, 0, at), binary_part(text, at, byte_size(text) - at)}
    end
  end

  defp token_end?(text), do: text == "" or String.starts_with?(text, @token_end)
end
