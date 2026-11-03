defmodule Anchor.Managers.Sabotage do
  @moduledoc """
  Orchestrates generated sabotage, the **Manager** (ADR 001) for
  `mix anchor.sabotage`. It calls the change-source adapter and Domain only
  (never a Framework module: DND-1288).

  ## scope/2 (DND-5472)

  The functions the working tree changed relative to the merge-base of `base`
  and `HEAD`:

    1. `merge_base`, then the `--unified=0` diff and the untracked `.ex` files,
       through the `Anchor.Adapters.ChangeSource` behaviour (option
       `:change_source`, default `Anchor.Adapters.GitChangeSource`);
    2. `Anchor.Domain.Sabotage.DiffHunks.parse/1`; an untracked file is wholly
       added;
    3. each changed source file that still exists (`Scope.source_files/1`) is
       read and its function spans found (`FunctionSpans.spans/2`); test,
       non-source and deleted files are never read;
    4. `Scope.build/2`.

  It fails closed: every failure is `{:error, reason}` with a reason
  `Anchor.Domain.Failures.scope_could_not_measure/1` words, never an empty
  scope. A clean diff is `{:ok, scope}` with no functions.
  """

  alias Anchor.Adapters.GitChangeSource
  alias Anchor.Domain.Sabotage.DiffHunks
  alias Anchor.Domain.Sabotage.FunctionSpans
  alias Anchor.Domain.Sabotage.Scope

  @doc """
  Scopes the diff of `root` against the merge-base of `base` and `HEAD`.
  """
  @spec scope(%{root: String.t(), base: String.t()}, keyword()) ::
          {:ok, Scope.t()} | {:error, term()}
  def scope(%{root: root, base: base}, opts \\ []) do
    source = Keyword.get(opts, :change_source, GitChangeSource)

    with {:ok, sha} <- merge_base(source, root, base),
         {:ok, text} <- source.diff(root, sha),
         {:ok, files} <- parse_diff(text),
         {:ok, untracked} <- source.untracked(root),
         files = Enum.reduce(untracked, files, &Map.put(&2, &1, %{status: :added, hunks: []})),
         {:ok, spans} <- spans(source, root, Scope.source_files(files)) do
      {:ok, Scope.build(files, spans)}
    end
  end

  defp merge_base(source, root, base) do
    case source.merge_base(root, base) do
      {:error, :not_a_work_tree} -> {:error, {:not_a_work_tree, root}}
      result -> result
    end
  end

  defp parse_diff(text) do
    case DiffHunks.parse(text) do
      {:ok, files} -> {:ok, files}
      {:error, reason} -> {:error, {:unparseable_diff, reason}}
    end
  end

  defp spans(source, root, paths) do
    Enum.reduce_while(paths, {:ok, %{}}, fn path, {:ok, acc} ->
      case file_spans(source, root, path) do
        {:ok, spans} -> {:cont, {:ok, Map.put(acc, path, spans)}}
        error -> {:halt, error}
      end
    end)
  end

  defp file_spans(source, root, path) do
    with {:read, {:ok, text}} <- {:read, source.read(root, path)},
         {:spans, {:ok, spans}} <- {:spans, FunctionSpans.spans(text, path)} do
      {:ok, spans}
    else
      {:read, {:error, posix}} -> {:error, {:unreadable, path, posix}}
      {:spans, {:error, {line, reason}}} -> {:error, {:unparseable, path, line, reason}}
    end
  end
end
