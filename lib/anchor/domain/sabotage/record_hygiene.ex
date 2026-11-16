defmodule Anchor.Domain.Sabotage.RecordHygiene do
  @moduledoc """
  What a sabotage record must never carry, and its removal. Pure **Domain**.

  A record is committed, often to a public repository, so it holds only what
  any checkout of the project would show. Two kinds of text a run's output
  picks up on one machine are not that:

    * **scheduler lines**: the status lines of the `test-slot` scheduler a
      run may be queued behind (`test-slot: ...`, and a WAITING block's
      holder and waiting lines). They name other runs, their labels and their
      checkouts;
    * **local paths**: an absolute path under a home directory
      (`/home/<user>/...`, `/Users/<user>/...`), which names the user and,
      for a checkout under `.local/worktrees/`, the branch.

  `redact/2` drops the scheduler lines and rewrites each local path: a path
  under the run's root becomes relative to it (the root itself `.`), another
  checkout under `.local/worktrees/` becomes `<worktree>/` and the path from
  its first project directory on (`_build`, `deps`, `lib`, `test`, `tmp`,
  `apps`, `priv`, `config`), or `<worktree>` alone, and any other home path
  becomes `~/...`. `leaks/1` names each line that still carries one, by number
  and kind, never by its text.
  """

  @type kind :: :scheduler_line | :local_path

  # A path token ends at whitespace, a quote, a backtick or an angle bracket;
  # it starts where no path character precedes it.
  @start ~S{(?<![\w.~/-])}
  @home @start <> ~S{(?:/home|/Users)/[^/\s"'`<>]+}
  @token_end ~S{(?=[\s"'`<>]|$)}

  # Patterns are built at run time: a compiled regex is not stored in a module
  # attribute (OTP 28).
  defp scheduler_patterns do
    [
      ~r/^\s*test-slot: /,
      ~r/^\s*units? \S+ \(\d+ of weight \d+\): /,
      ~r/^\s*unit \d+: held \(holder diagnostics/,
      ~r/^\s*\d+ waiting \(this run: /,
      ~r/^\s*this run is --exclusive \(bench only\)/
    ]
  end

  defp worktree_pattern,
    do:
      Regex.compile!("(?:" <> @home <> "|" <> @start <> ~S{~)/\.local/worktrees(?:/[^\s"'`<>]*)?})

  defp home_pattern, do: Regex.compile!(@home <> "(?=/|" <> @token_end <> ")")
  defp local_path_pattern, do: Regex.compile!(@home <> ~S{|/\.local/worktrees(?:/|$)})
  defp project_dir_pattern, do: ~r{/(?:_build|deps|lib|test|tmp|apps|priv|config)(?:/|$)}

  @doc """
  `text` without its scheduler lines, with each local path rewritten.
  `root` is the run's project root (absolute), or `nil` when unknown.
  """
  @spec redact(String.t(), String.t() | nil) :: String.t()
  def redact(text, root) when is_binary(text) do
    root = root_pattern(root)

    text
    |> String.split("\n")
    |> Enum.reject(&scheduler_line?/1)
    |> Enum.map_join("\n", &rewrite(&1, root))
  end

  @doc "Each line (1-based) that carries a scheduler line or a local path, with its kind."
  @spec leaks(String.t()) :: [{pos_integer(), kind()}]
  def leaks(text) when is_binary(text) do
    text
    |> String.split("\n")
    |> Enum.with_index(1)
    |> Enum.flat_map(fn {line, n} -> leak(line, n) end)
  end

  @typedoc "One reason a set of committed records fails `judge/3`."
  @type finding ::
          {:leak, String.t(), pos_integer(), kind()}
          | {:stale, String.t()}
          | {:missing, String.t()}
          | {:late, String.t()}

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
          {line, kind} <- leaks(content),
          do: {:leak, path, line, kind}

    unlisted ++ Enum.flat_map(Enum.sort(listed), &listed_finding(&1, records, newest))
  end

  defp listed_finding(path, records, newest),
    do: late(path, newest) ++ presence(path, Map.fetch(records, path))

  defp late(path, newest), do: if(dated_after?(path, newest), do: [{:late, path}], else: [])

  defp presence(path, :error), do: [{:missing, path}]

  defp presence(path, {:ok, content}),
    do: if(leaks(content) == [], do: [{:stale, path}], else: [])

  defp dated_after?(path, newest) do
    with [_all, digits] <- Regex.run(~r/-(\d{8})-/, Path.basename(path)),
         {:ok, date} <- Date.from_iso8601(date_text(digits)) do
      Date.after?(date, newest)
    else
      _undated -> true
    end
  end

  defp date_text(<<y::binary-size(4), m::binary-size(2), d::binary-size(2)>>),
    do: "#{y}-#{m}-#{d}"

  defp leak(line, n) do
    cond do
      scheduler_line?(line) -> [{n, :scheduler_line}]
      Regex.match?(local_path_pattern(), line) -> [{n, :local_path}]
      true -> []
    end
  end

  defp scheduler_line?(line), do: Enum.any?(scheduler_patterns(), &Regex.match?(&1, line))

  defp rewrite(line, root) do
    line
    |> strip_root(root)
    |> then(&Regex.replace(worktree_pattern(), &1, fn path -> worktree(path) end))
    |> then(&Regex.replace(home_pattern(), &1, "~"))
  end

  defp strip_root(line, nil), do: line
  defp strip_root(line, root), do: Regex.replace(root, line, fn _all, rest -> relative(rest) end)

  defp relative("/" <> rest), do: rest
  defp relative(""), do: "."

  defp worktree(path) do
    case Regex.run(project_dir_pattern(), path, return: :index) do
      [{at, _len}] -> "<worktree>" <> binary_part(path, at, byte_size(path) - at)
      nil -> "<worktree>"
    end
  end

  # The root as a pattern: itself at a path token's start, followed by a `/`
  # (stripped with it) or the token's end. A root of `/` or a relative one is
  # no root: stripping `/` would make every absolute path relative.
  defp root_pattern(root) when is_binary(root),
    do: root |> String.trim_trailing("/") |> absolute_root()

  defp root_pattern(_root), do: nil

  defp absolute_root(root) do
    if absolute?(root),
      do: Regex.compile!(@start <> Regex.escape(root) <> "(/|" <> @token_end <> ")"),
      else: nil
  end

  defp absolute?(root), do: match?("/" <> _, root) and root != "/"
end
