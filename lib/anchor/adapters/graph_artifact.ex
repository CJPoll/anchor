defmodule Anchor.Adapters.GraphArtifact do
  @moduledoc """
  The graph artifact on disk, `<dir>/graph.etf` — the **Side Effect** adapter
  behind `Anchor.Adapters.GraphStore` (DND-5440).

  It writes only into a directory whose last three path segments (after
  `Path.expand/1`, so `..` cannot climb out) are `_build/<env>/anchor`: any
  other `dir` is refused with `{:error, :outside_artifact_dir}`. That is a
  check of the path's shape, not of its owner: the runner passes
  `<root>/_build/<env>/anchor`, and a symlink there is followed.

  The file holds `{key, term}` in the external term format. `read/2` answers
  `{:ok, term}` only for the key asked for: a different key is
  `{:error, :stale}`, a missing file `{:error, :enoent}`, and bytes that do
  not decode (or decode to another shape) `{:error, :unreadable}`. Decoding
  uses `:safe`, so a crafted file cannot create new atoms or external fun
  references; a reader must still never apply a term it decoded.
  """

  @behaviour Anchor.Adapters.GraphStore

  @file_name "graph.etf"

  @impl Anchor.Adapters.GraphStore
  def write(dir, key, term) do
    with :ok <- artifact_dir(dir),
         :ok <- File.mkdir_p(dir) do
      File.write(Path.join(dir, @file_name), :erlang.term_to_binary({key, term}))
    end
  end

  @impl Anchor.Adapters.GraphStore
  def read(dir, key) do
    with :ok <- artifact_dir(dir),
         {:ok, bytes} <- File.read(Path.join(dir, @file_name)) do
      decode(bytes, key)
    end
  end

  defp decode(bytes, key) do
    case safe_binary_to_term(bytes) do
      {:ok, {^key, term}} -> {:ok, term}
      {:ok, {other, _term}} when is_binary(other) -> {:error, :stale}
      _unreadable -> {:error, :unreadable}
    end
  end

  defp safe_binary_to_term(bytes) do
    {:ok, :erlang.binary_to_term(bytes, [:safe])}
  rescue
    ArgumentError -> {:error, :unreadable}
  end

  defp artifact_dir(dir) do
    case dir |> Path.expand() |> Path.split() |> Enum.take(-3) do
      ["_build", _env, "anchor"] -> :ok
      _other -> {:error, :outside_artifact_dir}
    end
  end
end
