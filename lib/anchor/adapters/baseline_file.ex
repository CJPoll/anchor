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

  A directory on the path swapped for a symlink between the check and the
  write (DND-5647) cannot be prevented: Erlang's file API has no `openat`, so
  the check and the write are separate path lookups. It is detected: after
  the link, the real path of the written file (every symlink on it resolved)
  must be under the real path of `root`. One that is not is removed, at its
  real path, and is `{:error, {:escaped_root, real_path}}`, which the run
  reports with a `Fix:` line. Winning that race needs a process that already
  writes the repository's directories, so it gains nothing that access did
  not give; the committed symlink of DND-5628 needs no such process, and the
  lstat walk refuses it before any write. The detection has limits, named
  here so it is not read as more: a second swap, putting the directory back
  before the check, hides the escape; one that moves the link again between
  the check and the removal points the removal elsewhere; and a real path
  that cannot be resolved (more than 40 links) is that error, with the file
  left where it landed.

  `create/4` takes `before_write:`, a zero-arity function run between the
  checks and the write: the seam a test swaps a directory in, at a fixed
  point (no timing). `create/3` runs none.
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
  def create(root, path, contents), do: create(root, path, contents, [])

  @doc "`create/3`, with `before_write:` run between the checks and the write (DND-5647)."
  @spec create(String.t(), String.t(), iodata(), keyword()) :: :ok | {:error, term()}
  def create(root, path, contents, opts) do
    before_write = Keyword.get(opts, :before_write, fn -> :ok end)

    with {:ok, full} <- confined(root, path),
         :ok <- File.mkdir_p(Path.dirname(full)),
         {:ok, full} <- confined(root, path),
         _ran = before_write.(),
         :ok <- write_new(full, contents) do
      within_root(root, full)
    end
  end

  # DND-5647: the file just linked must really be under the root. One that
  # is not is removed where it really is.
  defp within_root(root, full) do
    with {:ok, real_root} <- real_path(root),
         {:ok, real} <- real_path(full) do
      if String.starts_with?(real, real_root <> "/"),
        do: :ok,
        else: escaped(real)
    end
  end

  defp escaped(real) do
    _ = File.rm(real)
    {:error, {:escaped_root, real}}
  end

  # The absolute path with every symlink on it resolved, `{:error, :eloop}`
  # past 40 links (the kernel's own bound).
  defp real_path(path), do: resolve(Path.split(Path.expand(path)), [], 40)

  defp resolve([], acc, _hops), do: {:ok, acc |> Enum.reverse() |> Path.join()}
  defp resolve(_parts, _acc, 0), do: {:error, :eloop}
  defp resolve(["/" | rest], [], hops), do: resolve(rest, ["/"], hops)
  defp resolve(["." | rest], acc, hops), do: resolve(rest, acc, hops)
  defp resolve([".." | rest], ["/"], hops), do: resolve(rest, ["/"], hops)
  defp resolve([".." | rest], [_last | acc], hops), do: resolve(rest, acc, hops)

  defp resolve([part | rest], acc, hops) do
    current = [part | acc] |> Enum.reverse() |> Path.join()

    case File.read_link(current) do
      {:ok, target} ->
        base = if Path.type(target) == :absolute, do: [], else: acc
        resolve(Path.split(target) ++ rest, base, hops - 1)

      {:error, _not_a_link} ->
        resolve(rest, [part | acc], hops)
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
