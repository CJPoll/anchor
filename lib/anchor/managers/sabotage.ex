defmodule Anchor.Managers.Sabotage do
  @moduledoc """
  Orchestrates generated sabotage, the **Manager** (ADR 001) for
  `mix anchor.sabotage`. It calls adapters and Domain only (never a Framework
  module: DND-1288).

  ## run/2 and restore/2 (DND-5473)

  Delegated to `Anchor.Managers.Sabotage.Runner`, the same Manager bucket.

  ## coverage/2 (DND-5474)

  Delegated to `Anchor.Managers.Sabotage.Coverage`: the per-test coverage
  map, built by running the suite in this VM with call tracing.

  ## coverage_compare/2 (DND-5692)

  Delegated to `Anchor.Managers.Sabotage.CoverageCompare`: the verdict on two
  builds of the map at one commit and one seed.

  ## replay/2 (DND-5485)

  Delegated to `Anchor.Managers.Sabotage.Replay`: re-applies each landed
  record's mutants and runs their killers.

  ## behaviours/2 (DND-5489)

  Delegated to `Anchor.Managers.Sabotage.Behaviours`: each test's confirmed causes
  and the directories they spread over, ratcheted by a baseline.

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
    4. each of those files with removed lines (`Scope.old_source_files/1`) is
       read as it was at the merge-base (`show`), and its spans found, so a
       removed line maps to the function it was in;
    5. `Scope.build/3`.

  It fails closed: every failure is `{:error, reason}` with a reason
  `Anchor.Domain.Failures.scope_could_not_measure/1` words, never an empty
  scope. A clean diff is `{:ok, scope}` with no functions.
  """

  alias Anchor.Adapters.GitChangeSource
  alias Anchor.Domain.Sabotage.DiffHunks
  alias Anchor.Domain.Sabotage.FunctionSpans
  alias Anchor.Domain.Sabotage.Run
  alias Anchor.Domain.Sabotage.Scope
  alias Anchor.Domain.Sabotage.Replay.Result
  alias Anchor.Managers.Sabotage.Behaviours
  alias Anchor.Managers.Sabotage.Coverage
  alias Anchor.Managers.Sabotage.CoverageCompare
  alias Anchor.Managers.Sabotage.Replay
  alias Anchor.Managers.Sabotage.Runner

  @doc """
  Applies the mutants of the functions `root` changed against `base`, one at
  a time, and says what killed each (DND-5473). See
  `Anchor.Managers.Sabotage.Runner`, which holds the flow.
  """
  @spec run(map(), keyword()) :: Run.t()
  def run(facts, opts \\ []), do: Runner.run(facts, opts)

  @doc """
  Builds the per-test coverage map (DND-5474) and returns `{exit_code, lines}`.
  See `Anchor.Managers.Sabotage.Coverage`.
  """
  @spec coverage(Coverage.facts(), keyword()) :: {non_neg_integer(), [String.t()]}
  def coverage(facts, opts \\ []), do: Coverage.run(facts, opts)

  @doc """
  Judges two builds of the coverage map (DND-5692) and returns `{exit_code, lines}`.
  See `Anchor.Managers.Sabotage.CoverageCompare`.
  """
  @spec coverage_compare(CoverageCompare.facts(), keyword()) :: {non_neg_integer(), [String.t()]}
  def coverage_compare(facts, opts \\ []), do: CoverageCompare.run(facts, opts)

  @doc """
  Replays the landed sabotage records (DND-5485). See
  `Anchor.Managers.Sabotage.Replay`.
  """
  @spec replay(map(), keyword()) :: Result.t()
  def replay(facts, opts \\ []), do: Replay.run(facts, opts)

  @doc """
  Reports each test's confirmed causes and judges their locality (DND-5489), and
  returns `{exit_code, lines}`. See `Anchor.Managers.Sabotage.Behaviours`.
  """
  @spec behaviours(Behaviours.facts(), keyword()) :: {non_neg_integer(), [String.t()]}
  def behaviours(facts, opts \\ []), do: Behaviours.run(facts, opts)

  @doc "Restores a leftover journal's file, if any (`mix anchor.sabotage restore`)."
  @spec restore(%{root: String.t()}, keyword()) :: Run.t()
  def restore(facts, opts \\ []), do: Runner.restore(facts, opts)

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
         files = Enum.reduce(untracked, files, &Map.put(&2, &1, untracked_change())),
         {:ok, spans} <- spans(Scope.source_files(files), &read_spans(source, root, &1)),
         {:ok, old_spans} <-
           spans(Scope.old_source_files(files), &base_spans(source, root, sha, &1)) do
      {:ok, %{Scope.build(files, spans, old_spans) | base_sha: sha}}
    end
  end

  defp untracked_change, do: %{status: :added, hunks: [], old_hunks: []}

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

  defp spans(paths, file_spans) do
    Enum.reduce_while(paths, {:ok, %{}}, fn path, {:ok, acc} ->
      case file_spans.(path) do
        {:ok, spans} -> {:cont, {:ok, Map.put(acc, path, spans)}}
        error -> {:halt, error}
      end
    end)
  end

  defp read_spans(source, root, path) do
    with {:read, {:ok, text}} <- {:read, source.read(root, path)},
         {:spans, {:ok, spans}} <- {:spans, FunctionSpans.spans(text, path)} do
      {:ok, spans}
    else
      {:read, {:error, posix}} -> {:error, {:unreadable, path, posix}}
      {:spans, {:error, {line, reason}}} -> {:error, {:unparseable, path, line, reason}}
    end
  end

  defp base_spans(source, root, sha, path) do
    with {:show, {:ok, text}} <- {:show, source.show(root, sha, path)},
         {:spans, {:ok, spans}} <- {:spans, FunctionSpans.spans(text, path)} do
      {:ok, spans}
    else
      {:show, {:error, reason}} -> {:error, reason}
      {:spans, {:error, {line, reason}}} -> {:error, {:unparseable_base, path, sha, line, reason}}
    end
  end
end
