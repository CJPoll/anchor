defmodule Anchor.Domain.Sabotage.Scope do
  @moduledoc """
  The functions a diff changed, and what it left out, a **Domain** module
  (ADR 001). Pure: it maps the changed lines of each file
  (`Anchor.Domain.Sabotage.DiffHunks`) onto the function spans of that file
  (`Anchor.Domain.Sabotage.FunctionSpans`).

  ## Which files are scoped

  A **source file** ends `.ex` and has no path segment `test`, `deps` or
  `_build`. A **test file** has a `test` segment or ends `_test.exs`. Every
  other file is **non-source** (`.exs`, docs, config, `deps/`, `_build/`).
  Only source files that still exist are read and scoped (`source_files/1`).

  ## How a hunk maps

  For `{start, count}` with `count > 0` the changed lines are
  `start..start + count - 1`. With `count == 0` it is a deletion point between
  lines `start` and `start + 1`, which belongs to a span holding both. An
  added file (or an untracked one) changes every line of every function in it.

  Each changed line goes to every function span holding it that is not
  `excluded_macro`.

  A hunk's removed lines (its `old_hunks` range) map onto the base side's
  spans: a function a removed line was in that still exists in the file is in
  scope, recorded at the new-side line where the removed text was. This is
  what keeps a multi-clause function in scope when a whole clause of it is
  deleted (first, middle or last), and such a hunk is not counted as outside
  a function. A function deleted whole no longer exists, so it is not scoped.

  ## What is counted, never dropped

    * `test_files`, `non_source_files`, `deleted_files`: per file;
    * `outside_hunks`: hunks with a changed line (or a deletion point) in no
      function span (an attribute, a `@spec`, a module doc, a deleted function);
    * `macros`: hunks with a changed line only a macro, a guard macro or a
      function defined inside `quote` holds.

  One hunk can count in both. Functions are ordered by file, then by first line.
  """

  alias Anchor.Domain.Sabotage.ChangedFunction
  alias Anchor.Domain.Sabotage.DiffHunks
  alias Anchor.Domain.Sabotage.Span

  defstruct functions: [],
            counts: %{
              test_files: 0,
              non_source_files: 0,
              deleted_files: 0,
              outside_hunks: 0,
              macros: 0
            }

  @type counts :: %{
          test_files: non_neg_integer(),
          non_source_files: non_neg_integer(),
          deleted_files: non_neg_integer(),
          outside_hunks: non_neg_integer(),
          macros: non_neg_integer()
        }

  @type t :: %__MODULE__{functions: [ChangedFunction.t()], counts: counts()}

  @excluded_segments ["test", "deps", "_build"]

  @doc """
  Builds the scope from the changed files, the spans of each source file
  `source_files/1` names, and the base-side spans of each of those files with
  removed lines (`old_source_files/1`): a removed line maps to the function it
  was in at the base, when that function still exists.
  """
  @spec build(DiffHunks.t(), %{String.t() => [Span.t()]}, %{String.t() => [Span.t()]}) :: t()
  def build(files, spans_by_file, old_spans_by_file \\ %{}) do
    files
    |> Enum.sort_by(fn {path, _change} -> path end)
    |> Enum.reduce({%{}, %__MODULE__{}.counts}, fn {path, change}, acc ->
      classify_file(path, change, {spans_by_file, old_spans_by_file}, acc)
    end)
    |> then(fn {functions, counts} ->
      %__MODULE__{functions: ordered(functions), counts: counts}
    end)
  end

  @doc """
  The paths of the changed source files that still exist: the files whose
  source must be read and given to `build/2`, sorted.
  """
  @spec source_files(DiffHunks.t()) :: [String.t()]
  def source_files(files) do
    for {path, %{status: status}} <- files, status != :deleted, kind(path) == :source, do: path
  end

  @doc """
  The changed source files with removed lines, whose base-side source must be
  read and its spans given to `build/3`, sorted.
  """
  @spec old_source_files(DiffHunks.t()) :: [String.t()]
  def old_source_files(files) do
    for {path, %{status: :modified} = change} <- files,
        kind(path) == :source,
        Enum.any?(Map.get(change, :old_hunks, []), fn {_start, count} -> count > 0 end),
        do: path
  end

  @doc """
  Renders the scope as text (a TSV line per function, then the summary line)
  or as JSON (the same fields).
  """
  @spec render(t(), :text | :json) :: String.t()
  def render(scope, :text) do
    rows =
      Enum.map(scope.functions, fn function ->
        Enum.join(
          [
            function.file,
            inspect(function.module),
            "#{function.name}/#{function.arity}",
            function.kind,
            ranges(function.changed_lines)
          ],
          "\t"
        )
      end)

    Enum.join(rows ++ [summary(scope)], "\n")
  end

  def render(scope, :json) do
    JSON.encode!(%{
      "functions" => Enum.map(scope.functions, &function_json/1),
      "function_count" => length(scope.functions),
      "file_count" => file_count(scope),
      "excluded" => Map.new(scope.counts, fn {key, count} -> {Atom.to_string(key), count} end)
    })
  end

  defp function_json(function) do
    %{
      "file" => function.file,
      "module" => inspect(function.module),
      "name" => Atom.to_string(function.name),
      "arity" => function.arity,
      "function" => "#{function.name}/#{function.arity}",
      "kind" => Atom.to_string(function.kind),
      "changed_lines" => function.changed_lines,
      "changed_line_ranges" => ranges(function.changed_lines)
    }
  end

  defp summary(scope) do
    c = scope.counts

    "anchor.sabotage scope: #{length(scope.functions)} functions in #{file_count(scope)} files; " <>
      "excluded: #{c.test_files} test files, #{c.non_source_files} non-source files, " <>
      "#{c.deleted_files} deleted files, #{c.outside_hunks} hunks outside a function, #{c.macros} macros"
  end

  defp file_count(scope), do: scope.functions |> Enum.uniq_by(& &1.file) |> length()

  defp classify_file(path, change, {spans_by_file, old_spans_by_file}, {functions, counts}) do
    case {kind(path), change.status} do
      {:test, _status} ->
        {functions, bump(counts, :test_files)}

      {:non_source, _status} ->
        {functions, bump(counts, :non_source_files)}

      {:source, :deleted} ->
        {functions, bump(counts, :deleted_files)}

      {:source, :added} ->
        scope_added(path, Map.fetch!(spans_by_file, path), {functions, counts})

      {:source, _modified} ->
        file = %{
          path: path,
          spans: Map.fetch!(spans_by_file, path),
          old_spans: Map.get(old_spans_by_file, path, [])
        }

        old_hunks = Map.get(change, :old_hunks, Enum.map(change.hunks, fn _hunk -> {0, 0} end))
        scope_hunks(file, Enum.zip(change.hunks, old_hunks), {functions, counts})
    end
  end

  defp kind(path) do
    segments = Path.split(path)

    cond do
      "test" in segments or String.ends_with?(path, "_test.exs") ->
        :test

      String.ends_with?(path, ".ex") and not Enum.any?(segments, &(&1 in @excluded_segments)) ->
        :source

      true ->
        :non_source
    end
  end

  # An added file changed every line its functions hold: one hunk over them
  # all. Its lines outside a function (the defmodule line, attributes) are not
  # a hunk the diff made outside a function, so they are not counted.
  defp scope_added(path, spans, {functions, counts}) do
    last = spans |> Enum.map(& &1.last) |> Enum.max(fn -> 1 end)
    file = %{path: path, spans: spans, old_spans: []}

    {functions, added_counts} =
      scope_hunks(file, [{{1, last}, {0, 0}}], {functions, %{counts | outside_hunks: 0}})

    {functions, %{added_counts | outside_hunks: counts.outside_hunks}}
  end

  # Each hunk maps its new-side lines (or deletion point) onto the file's
  # spans, and its removed lines onto the base side's spans. A function a
  # removed line was in, and that still exists, is in scope: a clause deleted
  # anywhere in a multi-clause function changes it although no clause left
  # holds the point. Such a hunk is about that function, not outside one.
  defp scope_hunks(file, hunks, acc) do
    Enum.reduce(hunks, acc, fn {hunk, old_hunk}, {functions, counts} ->
      {functions, flags} = map_hunk(hunk, file.path, file.spans, functions)
      {functions, survivors} = map_removed(old_hunk, hunk, file, functions)
      flags = if survivors == [], do: flags, else: Enum.reject(flags, &(&1 == :outside))

      {functions,
       counts |> bump_if(:outside_hunks, :outside in flags) |> bump_if(:macros, :macro in flags)}
    end)
  end

  # A deletion point inside one clause belongs to it.
  defp map_hunk({start, 0}, path, spans, functions) do
    holders = Enum.filter(spans, &(&1.first <= start and start + 1 <= &1.last))
    map_line(start + 1, holders, path, {functions, []})
  end

  defp map_hunk({start, count}, path, spans, functions) do
    Enum.reduce(start..(start + count - 1)//1, {functions, []}, fn line, acc ->
      holders = Enum.filter(spans, &(&1.first <= line and line <= &1.last))
      map_line(line, holders, path, acc)
    end)
  end

  # The removed lines' base-side functions that still exist in the file. Each
  # is recorded at the new-side line where the removed text was.
  defp map_removed({_old_start, 0}, _hunk, _file, functions), do: {functions, []}

  defp map_removed({old_start, old_count}, {new_start, new_count}, file, functions) do
    old_last = old_start + old_count - 1

    removed_from =
      file.old_spans
      |> Enum.reject(& &1.excluded_macro)
      |> Enum.filter(&(&1.first <= old_last and old_start <= &1.last))
      |> MapSet.new(&identity/1)

    survivors =
      file.spans
      |> Enum.reject(& &1.excluded_macro)
      |> Enum.filter(&MapSet.member?(removed_from, identity(&1)))
      |> Enum.uniq_by(&identity/1)

    line = if new_count == 0, do: new_start + 1, else: new_start
    {Enum.reduce(survivors, functions, &add_line(&2, &1, file.path, line)), survivors}
  end

  defp identity(span), do: {span.module, span.name, span.arity}

  defp map_line(line, holders, path, {functions, flags}) do
    case Enum.reject(holders, & &1.excluded_macro) do
      [] when holders == [] -> {functions, [:outside | flags]}
      [] -> {functions, [:macro | flags]}
      included -> {Enum.reduce(included, functions, &add_line(&2, &1, path, line)), flags}
    end
  end

  defp add_line(functions, span, path, line) do
    key = identity(span)

    Map.update(functions, key, {span.first, new_function(span, path, line)}, fn {first, function} ->
      {min(first, span.first), %{function | changed_lines: [line | function.changed_lines]}}
    end)
  end

  defp new_function(span, path, line) do
    %ChangedFunction{
      file: path,
      module: span.module,
      name: span.name,
      arity: span.arity,
      kind: span.kind,
      changed_lines: [line]
    }
  end

  defp ordered(functions) do
    functions
    |> Map.values()
    |> Enum.sort_by(fn {first, function} -> {function.file, first} end)
    |> Enum.map(fn {_first, function} ->
      %{function | changed_lines: function.changed_lines |> Enum.uniq() |> Enum.sort()}
    end)
  end

  defp bump(counts, key), do: Map.update!(counts, key, &(&1 + 1))
  defp bump_if(counts, key, true), do: bump(counts, key)
  defp bump_if(counts, _key, false), do: counts

  defp ranges(lines) do
    lines
    |> Enum.chunk_while(
      nil,
      fn
        line, nil -> {:cont, {line, line}}
        line, {first, last} when line == last + 1 -> {:cont, {first, line}}
        line, range -> {:cont, range, {line, line}}
      end,
      fn
        nil -> {:cont, nil}
        range -> {:cont, range, nil}
      end
    )
    |> Enum.map_join(",", fn
      {line, line} -> Integer.to_string(line)
      {first, last} -> "#{first}-#{last}"
    end)
  end
end
