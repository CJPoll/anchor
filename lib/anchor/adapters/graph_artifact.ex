defmodule Anchor.Adapters.GraphArtifact do
  @moduledoc """
  The graph artifact on disk, `<dir>/graph.etf` — the **Side Effect** adapter
  behind `Anchor.Adapters.GraphStore` (DND-5440).

  It reads and writes only `<build_path>/anchor`: a directory named `anchor`
  (after `Path.expand/1`, so `..` cannot climb out) whose parent is a Mix
  build path, which holds `lib/<app>/ebin` for each app it built. A project
  root holds `lib/` too, but no `lib/<app>/ebin`. Any other `dir` is refused
  with `{:error, :outside_artifact_dir}`. The runner passes
  `Mix.Project.build_path/0` joined with `anchor`: `_build/<env>/anchor`, or
  under the directory `MIX_BUILD_PATH` names (DND-5585). That is a check of
  the path's shape, not of its owner, and a symlink there is followed.

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
    expanded = Path.expand(dir)

    if Path.basename(expanded) == "anchor" and build_path?(Path.dirname(expanded)),
      do: :ok,
      else: {:error, :outside_artifact_dir}
  end

  # A Mix build path: some `lib/<app>/ebin` under it.
  defp build_path?(dir) do
    lib = Path.join(dir, "lib")

    case File.ls(lib) do
      {:ok, apps} -> Enum.any?(apps, &File.dir?(Path.join([lib, &1, "ebin"])))
      {:error, _posix} -> false
    end
  end
end
