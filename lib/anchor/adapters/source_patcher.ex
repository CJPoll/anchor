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
  owner, so it is never seen empty. A lock whose holder is dead, or names
  none, is taken over under a second lock (`<lock>.takeover`), so two runs
  can never both remove it (see `take_over/2`); `release_lock/1` removes only
  this run's own lock. Where there is no `/proc` the lock is refused
  (`{:error, :no_proc}`), because it could name no owner and would protect
  nothing (DND-5571). `touch_ahead/1` sets the mtime to one
  second past the later of now and the file's current mtime: always forward,
  so a restore in the same second as its mutant still recompiles (Mix compares
  the mtime and the size before it reads the content).
  """

  @behaviour Anchor.Adapters.SourceMutation

  alias Anchor.Domain.Sabotage.Journal

  @proc "/proc"

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
  def take_lock(root), do: take_lock(root, @proc)

  @doc """
  `take_lock/1` reading this process's identity from `proc_dir` (`/proc`):
  the seam the adapter test uses for a host without one. With none the lock
  could name no owner, so no run could tell a live holder from a dead one:
  `{:error, :no_proc}`, and nothing is written (DND-5571).
  """
  @spec take_lock(String.t(), String.t()) ::
          :ok | {:error, :no_proc | {:held, map() | nil} | {:stuck, String.t()} | atom()}
  def take_lock(root, proc_dir) do
    path = Path.join(root, Journal.lock_path())

    with {:ok, me} <- own_owner(proc_dir),
         :ok <- File.mkdir_p(Path.dirname(path)) do
      case link_owned(path, me) do
        {:error, :eexist} -> take_over(path, me)
        result -> result
      end
    end
  end

  # Removes the lock only while it is this run's: a lock another run holds
  # is never touched.
  @impl Anchor.Adapters.SourceMutation
  def release_lock(root) do
    path = Path.join(root, Journal.lock_path())

    case read_holder(path) do
      {:ok, holder} -> if holder == owner(System.pid()), do: removed(path), else: :ok
      {:error, :enoent} -> :ok
      {:error, posix} -> {:error, posix}
    end
  end

  # A hard link to a temp file already holding the owner: `File.ln/2` fails
  # `:eexist` when the path is taken, and the path is never seen empty.
  defp link_owned(path, me) do
    tmp = "#{path}.#{System.pid()}.anchor-tmp"

    with :ok <- File.write(tmp, Journal.encode_lock(me), [:binary]) do
      linked = File.ln(tmp, path)
      _removed = File.rm(tmp)
      linked
    end
  end

  # A lock is there. Whether its holder is alive is decided only under the
  # takeover lock, which one run holds at a time: the holder is read, a dead
  # one's lock removed and this run's linked, with no other run able to
  # remove or replace the lock in between (a plain link cannot land while a
  # lock is there, and only the takeover lock's holder removes one). A run
  # that finds the takeover lock held refuses; one whose holder is dead (a
  # run killed in those few lines) is `{:stuck, path}`, left for a person.
  defp take_over(path, me) do
    mutex = path <> ".takeover"

    case link_owned(mutex, me) do
      :ok ->
        result = under_takeover(path, me)
        _released = File.rm(mutex)
        result

      {:error, :eexist} ->
        takeover_held(mutex)

      error ->
        error
    end
  end

  defp under_takeover(path, me) do
    case read_holder(path) do
      {:ok, holder} ->
        if owner_alive?(holder),
          do: {:error, {:held, holder}},
          else: with(:ok <- removed(path), do: link_or_held(path, me))

      {:error, :enoent} ->
        link_or_held(path, me)

      {:error, posix} ->
        {:error, posix}
    end
  end

  # A run that linked by the plain path after the dead lock went is live.
  defp link_or_held(path, me) do
    case link_owned(path, me) do
      {:error, :eexist} -> held_now(path)
      result -> result
    end
  end

  defp held_now(path) do
    case read_holder(path) do
      {:ok, holder} -> {:error, {:held, holder}}
      {:error, _posix} -> {:error, {:held, nil}}
    end
  end

  defp takeover_held(mutex) do
    case read_holder(mutex) do
      {:ok, holder} ->
        if owner_alive?(holder),
          do: {:error, {:held, holder}},
          else: {:error, {:stuck, Path.join("_build", Path.basename(mutex))}}

      {:error, _gone} ->
        {:error, {:held, nil}}
    end
  end

  defp read_holder(path) do
    with {:ok, bytes} <- File.read(path), do: {:ok, Journal.decode_lock(bytes)}
  end

  defp removed(path) do
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
  defp owner(os_pid, proc_dir \\ @proc) do
    with {:ok, stat} <- File.read(Path.join([proc_dir, os_pid, "stat"])),
         [_head, tail] <- String.split(stat, ") ", parts: 2),
         started when is_binary(started) <- tail |> String.split(" ") |> Enum.at(19) do
      %{os_pid: String.to_integer(os_pid), started: started}
    else
      _none -> nil
    end
  end

  defp own_owner(proc_dir) do
    case owner(System.pid(), proc_dir) do
      nil -> {:error, :no_proc}
      me -> {:ok, me}
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

  # DND-5485: each component under `root` is `lstat`ed, shallowest first,
  # as `Anchor.Adapters.BaselineFile` does; a component that does not exist
  # ends the walk (nothing below it can be a symlink).
  @impl Anchor.Adapters.SourceMutation
  def symlinked(root, paths), do: Enum.filter(paths, &symlink_on_path?(root, &1))

  defp symlink_on_path?(root, path) do
    path
    |> Path.split()
    |> Enum.scan(&Path.join(&2, &1))
    |> Enum.reduce_while(false, fn prefix, false ->
      case File.lstat(Path.join(root, prefix)) do
        {:ok, %File.Stat{type: :symlink}} -> {:halt, true}
        {:ok, %File.Stat{}} -> {:cont, false}
        {:error, _posix} -> {:halt, false}
      end
    end)
  end

  @impl Anchor.Adapters.SourceMutation
  def save_run(path, bytes) do
    with :ok <- File.mkdir_p(Path.dirname(path)), do: write_file(path, bytes)
  end

  defp journal(root), do: Path.join(root, Journal.path())
end
