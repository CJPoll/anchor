defmodule Anchor.Adapters.SourcePatcher do
  @moduledoc """
  Writes mutants and the journal with `File`, the **Side Effect** adapter
  (ADR 001) behind `Anchor.Adapters.SourceMutation` (DND-5473).

  A file is written to `<path>.anchor-tmp` and renamed over `path`, so a kill
  mid-write never leaves half a file. `touch_ahead/1` sets the mtime to one
  second past the later of now and the file's current mtime: always forward,
  so a restore in the same second as its mutant still recompiles (Mix compares
  the mtime and the size before it reads the content).
  """

  @behaviour Anchor.Adapters.SourceMutation

  alias Anchor.Domain.Sabotage.Journal

  @impl Anchor.Adapters.SourceMutation
  def read_journal(root) do
    case File.read(journal(root)) do
      {:ok, bytes} -> Journal.decode(bytes)
      {:error, :enoent} -> :none
      {:error, posix} -> {:error, posix}
    end
  end

  @impl Anchor.Adapters.SourceMutation
  def write_journal(root, %Journal{} = entry) do
    path = journal(root)

    with :ok <- File.mkdir_p(Path.dirname(path)) do
      write_file(path, Journal.encode(entry))
    end
  end

  @impl Anchor.Adapters.SourceMutation
  def delete_journal(root) do
    case File.rm(journal(root)) do
      :ok -> :ok
      {:error, :enoent} -> :ok
      error -> error
    end
  end

  @impl Anchor.Adapters.SourceMutation
  def write_file(path, bytes) do
    tmp = path <> ".anchor-tmp"

    with :ok <- File.write(tmp, bytes, [:binary]) do
      File.rename(tmp, path)
    end
  end

  @impl Anchor.Adapters.SourceMutation
  def touch_ahead(path) do
    with {:ok, %File.Stat{mtime: mtime}} <- File.stat(path, time: :posix) do
      File.touch(path, max(System.os_time(:second), mtime) + 1)
    end
  end

  @impl Anchor.Adapters.SourceMutation
  def sha256_file(path) do
    with {:ok, bytes} <- File.read(path), do: {:ok, Journal.sha256(bytes)}
  end

  @impl Anchor.Adapters.SourceMutation
  def existing(paths), do: Enum.filter(paths, &File.regular?/1)

  @impl Anchor.Adapters.SourceMutation
  def save_run(path, bytes) do
    with :ok <- File.mkdir_p(Path.dirname(path)), do: write_file(path, bytes)
  end

  defp journal(root), do: Path.join(root, Journal.path())
end
