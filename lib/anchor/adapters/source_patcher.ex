defmodule Anchor.Adapters.SourcePatcher do
  @moduledoc """
  Writes mutants and the journal with `File`, the **Side Effect** adapter
  (ADR 001) behind `Anchor.Adapters.SourceMutation` (DND-5473).

  A file is written to `<path>.anchor-tmp` and renamed over `path`, so a kill
  mid-write never leaves half a file. The journal is created exclusively:
  `write_journal/2` is `{:error, :eexist}` while another run's journal exists.
  The journal carries its owner (this OS process's pid and start time, from
  `/proc`); `owner_alive?/1` tells a live run's journal from a dead run's.
  The run lock is linked into place from a temp file already holding its
  owner, so it is never seen empty; a lock whose holder is dead, or names
  none, is removed and taken again (once). Two runs that find the same dead
  holder's lock at the same moment can both remove it; the second link then
  fails and that run reads the first as the live holder. Where there is no
  `/proc` the owner is `nil` and the lock does not protect. `touch_ahead/1` sets the mtime to one
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
  def take_lock(root) do
    path = Path.join(root, Journal.lock_path())
    me = owner(System.pid())

    with :ok <- File.mkdir_p(Path.dirname(path)) do
      claim(path, me, 1)
    end
  end

  @impl Anchor.Adapters.SourceMutation
  def release_lock(root) do
    case File.rm(Path.join(root, Journal.lock_path())) do
      :ok -> :ok
      {:error, :enoent} -> :ok
      error -> error
    end
  end

  # The lock is a hard link to a temp file holding the owner: `File.ln/2`
  # fails `:eexist` when a lock is there, and never leaves an empty one.
  defp claim(path, me, retries) do
    tmp = "#{path}.#{System.pid()}.anchor-tmp"

    with :ok <- File.write(tmp, Journal.encode_lock(me), [:binary]) do
      linked = File.ln(tmp, path)
      _removed = File.rm(tmp)
      claimed(linked, path, me, retries)
    end
  end

  defp claimed(:ok, _path, _me, _retries), do: :ok

  defp claimed({:error, :eexist}, path, me, retries) do
    case File.read(path) do
      {:ok, bytes} -> holder(Journal.decode_lock(bytes), path, me, retries)
      {:error, :enoent} when retries > 0 -> claim(path, me, retries - 1)
      {:error, :enoent} -> {:error, {:held, nil}}
      {:error, posix} -> {:error, posix}
    end
  end

  defp claimed({:error, posix}, _path, _me, _retries), do: {:error, posix}

  defp holder(owner, path, me, retries) do
    cond do
      owner_alive?(owner) -> {:error, {:held, owner}}
      retries == 0 -> {:error, {:held, owner}}
      true -> with :ok <- stale_removed(path), do: claim(path, me, retries - 1)
    end
  end

  defp stale_removed(path) do
    case File.rm(path) do
      {:error, :enoent} -> :ok
      result -> result
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
