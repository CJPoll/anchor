defmodule Anchor.Adapters.GitShow do
  @moduledoc """
  Reads a baseline (`show/3`), and the config's graph rules (`rules/3`,
  DND-5629), as they are on a git ref, the **Side Effect** adapter (ADR 001)
  behind `Anchor.Adapters.GitBase` (DND-5441).

  It refuses a ref `Anchor.Domain.Baseline.valid_ref?/1` rejects, and an
  absolute path or one with a `..` segment, before git runs. Git runs with
  `System.cmd/3` (argv only, never a shell), in `root`, with
  `Anchor.Adapters.GitEnv.env/0` (DND-5581: run from a git hook, it still
  reads the repository at `root`, never the one `GIT_DIR` names, and
  `GIT_OPTIONAL_LOCKS=0`), and only reads:

    1. `git rev-parse --verify --quiet --end-of-options <ref>^{commit}`: a ref
       that does not resolve is an error, never an absent file;
    2. `git ls-tree -z <sha> -- <each prefix of path>`: an entry of mode
       120000 (a symlink) at the file or any directory above it is
       `{:error, {:symlink, prefix}}`, never followed (DND-5628); no entry
       for the file is an absent file (the commit resolved, so the path is
       what is missing), and a failure is an error, never absent. It prints
       nothing for an absent path, where `cat-file -e` wrote a `fatal:` line
       to the terminal;
    3. `git cat-file blob <sha>:./<path>`: the bytes, parsed by
       `Anchor.Domain.Baseline.parse/1` (the port returns entries).

  Git's stderr is kept out of the output it reads. No `git` to run is an
  error, `{:git, :enoent, _}`, never a crash.
  """

  @behaviour Anchor.Adapters.GitBase

  alias Anchor.Adapters.GitEnv
  alias Anchor.Config
  alias Anchor.Domain.Baseline

  @impl Anchor.Adapters.GitBase
  def show(root, ref, path) do
    with {:ok, bytes} <- blob(root, ref, path), do: Baseline.parse(bytes)
  end

  @doc """
  The graph rules of the config at `path` on `ref` (DND-5629), read as
  `show/3` reads a baseline (the same refusals) and parsed by
  `Anchor.Config.parse_config/1`.
  """
  @impl Anchor.Adapters.GitBase
  def rules(root, ref, path) do
    with {:ok, bytes} <- blob(root, ref, path),
         {:ok, data} <- decode(bytes),
         %Config{rules: rules} <- Config.parse_config(data) do
      {:ok, rules}
    end
  end

  defp blob(root, ref, path) do
    cond do
      not Baseline.valid_ref?(ref) -> {:error, :bad_ref}
      Path.type(path) != :relative or ".." in Path.split(path) -> {:error, :outside_root}
      true -> blob_valid(root, ref, path)
    end
  end

  defp blob_valid(root, ref, path) do
    parts = Path.split(path) -- ["."]
    prefixes = Enum.scan(parts, &(&2 <> "/" <> &1))
    full = List.last(prefixes)

    with {:ok, sha} <- resolve(root, ref),
         {:ok, listed} <- git(root, ["ls-tree", "-z", sha, "--" | prefixes]),
         :ok <- present(entries(listed), prefixes, full) do
      git(root, ["cat-file", "blob", sha <> ":./" <> full])
    end
  end

  # The YAML library's error stops here: the Domain gets its text only.
  defp decode(bytes) do
    case YamlElixir.read_from_string(bytes) do
      {:ok, data} -> {:ok, data}
      {:error, %{__exception__: true} = error} -> {:error, {:yaml, Exception.message(error)}}
      {:error, error} -> {:error, {:yaml, inspect(error)}}
    end
  end

  # `ls-tree -z` lines: `<mode> <type> <object>\t<path>`, NUL-terminated.
  defp entries(listed) do
    for line <- String.split(listed, <<0>>, trim: true),
        [meta, entry_path] = String.split(line, "\t", parts: 2),
        into: %{},
        do: {entry_path, meta |> String.split(" ") |> hd()}
  end

  # A symlink (mode 120000) on the path, the file or a directory above it, is
  # refused and never followed (DND-5628); the shallowest one is named.
  defp present(entries, prefixes, full) do
    case Enum.find(prefixes, &(Map.get(entries, &1) == "120000")) do
      nil -> if Map.has_key?(entries, full), do: :ok, else: {:error, :absent}
      link -> {:error, {:symlink, link}}
    end
  end

  defp resolve(root, ref) do
    with {:ok, out} <-
           git(root, ["rev-parse", "--verify", "--quiet", "--end-of-options", ref <> "^{commit}"]) do
      {:ok, String.trim(out)}
    end
  end

  defp git(root, args) do
    case System.cmd("git", args,
           cd: root,
           stderr_to_stdout: false,
           env: GitEnv.env()
         ) do
      {out, 0} -> {:ok, out}
      {out, status} -> {:error, {:git, status, out}}
    end
  rescue
    error in ErlangError ->
      if error.original == :enoent,
        do: {:error, {:git, :enoent, "git was not found on the PATH"}},
        else: reraise(error, __STACKTRACE__)
  end
end
