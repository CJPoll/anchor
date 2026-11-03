defmodule Anchor.Adapters.BaselineFile do
  @moduledoc """
  Reads and creates baseline files on disk, the **Side Effect** adapter
  (ADR 001) behind `Anchor.Adapters.BaselineStore` (DND-5441).

  A path is confined to the project root twice, before any file is read or
  written:

    * lexically: a path that is absolute or holds a `..` segment is
      `{:error, :outside_root}` (the config refuses it already; this is the
      adapter's own guard);
    * by what is on disk (DND-5628): each component under `root` is
      `lstat`ed, and a symlink, to a directory or at the file, dangling or
      not, is `{:error, {:symlink, prefix}}` naming the shallowest one. A
      symlink committed in the repository would otherwise carry a read, or
      `--write-baseline`, outside the root. Anchor never follows one.

  `create/3` never overwrites and never follows a symlink planted at the file:
  it makes the parent directories, checks the path again, writes the bytes to
  a fresh temp file in that directory (opened `:exclusive`), then hard-links
  it to the baseline's name and removes the temp file. `link(2)` fails with
  `:eexist` on any existing entry, a symlink included, returned as `{:error,
  :exists}`, so the file appears whole or not at all. A rename would replace
  an existing file, which `--write-baseline` must never do.

  Not covered: a directory on the path swapped for a symlink between the
  check and the write. Erlang's file API has no `openat`, so the check and the
  write are separate path lookups; the window is the length of one call.
  """

  @behaviour Anchor.Adapters.BaselineStore

  alias Anchor.Domain.Baseline

  @impl Anchor.Adapters.BaselineStore
  def read(root, path) do
    with {:ok, full} <- confined(root, path),
         {:ok, bytes} <- File.read(full) do
      Baseline.parse(bytes)
    end
  end

  @impl Anchor.Adapters.BaselineStore
  def create(root, path, contents) do
    with {:ok, full} <- confined(root, path),
         :ok <- File.mkdir_p(Path.dirname(full)),
         {:ok, full} <- confined(root, path) do
      write_new(full, contents)
    end
  end

  defp write_new(full, contents) do
    temp =
      Path.join(
        Path.dirname(full),
        ".#{Path.basename(full)}.#{System.unique_integer([:positive])}.tmp"
      )

    try do
      with :ok <- write_temp(temp, contents) do
        link(temp, full)
      end
    after
      File.rm(temp)
    end
  end

  defp write_temp(temp, contents) do
    case File.open(temp, [:write, :exclusive, :binary]) do
      {:ok, device} ->
        try do
          IO.binwrite(device, contents)
        after
          File.close(device)
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp link(temp, full) do
    case File.ln(temp, full) do
      :ok -> :ok
      {:error, :eexist} -> {:error, :exists}
      {:error, reason} -> {:error, reason}
    end
  end

  defp confined(root, path) do
    parts = Path.split(path)

    if Path.type(path) == :relative and ".." not in parts,
      do: no_symlink(root, parts -- ["."], Path.join(root, path)),
      else: {:error, :outside_root}
  end

  # Each component under `root`, shallowest first; the first one that does not
  # exist ends the walk (nothing below it can be a symlink).
  defp no_symlink(root, parts, full) do
    parts
    |> Enum.scan(&Path.join(&2, &1))
    |> Enum.reduce_while({:ok, full}, fn prefix, ok ->
      case File.lstat(Path.join(root, prefix)) do
        {:ok, %File.Stat{type: :symlink}} -> {:halt, {:error, {:symlink, prefix}}}
        {:ok, %File.Stat{}} -> {:cont, ok}
        {:error, _reason} -> {:halt, ok}
      end
    end)
  end
end
