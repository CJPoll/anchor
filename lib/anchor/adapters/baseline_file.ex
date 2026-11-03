defmodule Anchor.Adapters.BaselineFile do
  @moduledoc """
  Reads and creates baseline files on disk, the **Side Effect** adapter
  (ADR 001) behind `Anchor.Adapters.BaselineStore` (DND-5441).

  `create/3` opens the file with `[:write, :exclusive]`, so an existing file
  is never overwritten (the open fails with `:eexist`, returned as
  `{:error, :exists}`); the parent directories are created first. A path that
  is absolute or holds a `..` segment is refused with `{:error, :outside_root}`
  before any file is touched (the config refuses it already; this is the
  adapter's own guard).
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
         :ok <- File.mkdir_p(Path.dirname(full)) do
      write_new(full, contents)
    end
  end

  defp write_new(full, contents) do
    case File.open(full, [:write, :exclusive, :binary]) do
      {:ok, device} ->
        try do
          IO.binwrite(device, contents)
        after
          File.close(device)
        end

      {:error, :eexist} ->
        {:error, :exists}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp confined(root, path) do
    if Path.type(path) == :relative and ".." not in Path.split(path),
      do: {:ok, Path.join(root, path)},
      else: {:error, :outside_root}
  end
end
