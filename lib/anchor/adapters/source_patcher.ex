defmodule Anchor.Adapters.SourcePatcher do
  @moduledoc """
  Writes mutants and the journal with `File`, the **Side Effect** adapter
  (ADR 001) behind `Anchor.Adapters.SourceMutation` (DND-5473).

  A file is written to `<path>.anchor-tmp` and renamed over `path`, so a kill
  mid-write never leaves half a file. The journal is created exclusively:
  `write_journal/2` is `{:error, :eexist}` while another run's journal exists.
  The journal carries its owner (this OS process's pid and start time, from
  `/proc`); `owner_alive?/1` tells a live run's journal from a dead run's. `touch_ahead/1` sets the mtime to one
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

    # Created exclusively: a journal already there belongs to another run
    # (`{:error, :eexist}`), and is never overwritten.
    with :ok <- File.mkdir_p(Path.dirname(path)),
         {:ok, io} <- File.open(path, [:write, :exclusive]),
         :ok <- File.close(io) do
      write_file(path, Journal.encode(%{entry | owner: owner(System.pid())}))
    end
  end

  @impl Anchor.Adapters.SourceMutation
  def owner_alive?(nil), do: false

  def owner_alive?(%{os_pid: pid, started: started}),
    do: owner(Integer.to_string(pid)) == %{os_pid: pid, started: started}

  # This OS process and its start time, field 22 of /proc/<pid>/stat (read
  # after the `)` that ends the command name, which may hold spaces). `nil`
  # where there is no /proc: a journal with no owner is never taken as live.
  defp owner(os_pid) do
    with {:ok, stat} <- File.read("/proc/#{os_pid}/stat"),
         [_head, tail] <- String.split(stat, ") ", parts: 2),
         started when is_binary(started) <- tail |> String.split(" ") |> Enum.at(19) do
      %{os_pid: String.to_integer(os_pid), started: started}
    else
      _none -> nil
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
