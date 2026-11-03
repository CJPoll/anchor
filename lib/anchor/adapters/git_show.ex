defmodule Anchor.Adapters.GitShow do
  @moduledoc """
  Reads a baseline as it is on a git ref, the **Side Effect** adapter (ADR 001)
  behind `Anchor.Adapters.GitBase` (DND-5441).

  It refuses a ref `Anchor.Domain.Baseline.valid_ref?/1` rejects, and an
  absolute path or one with a `..` segment, before git runs. Git runs with
  `System.cmd/3` (argv only, never a shell), in `root`, with
  `Anchor.Adapters.GitEnv.env/0` (DND-5581: run from a git hook, it still
  reads the repository at `root`, never the one `GIT_DIR` names, and
  `GIT_OPTIONAL_LOCKS=0`), and only reads:

    1. `git rev-parse --verify --quiet --end-of-options <ref>^{commit}`: a ref
       that does not resolve is an error, never an absent file;
    2. `git ls-tree <sha> -- <path>`: an empty answer is an absent file (the
       commit resolved, so the path is what is missing), and a failure is an
       error, never absent. It prints nothing for an absent path, where
       `cat-file -e` wrote a `fatal:` line to the terminal;
    3. `git cat-file blob <sha>:./<path>`: the bytes, parsed by
       `Anchor.Domain.Baseline.parse/1` (the port returns entries).

  Git's stderr is kept out of the output it reads. No `git` to run is an
  error, `{:git, :enoent, _}`, never a crash.
  """

  @behaviour Anchor.Adapters.GitBase

  alias Anchor.Adapters.GitEnv
  alias Anchor.Domain.Baseline

  @impl Anchor.Adapters.GitBase
  def show(root, ref, path) do
    cond do
      not Baseline.valid_ref?(ref) -> {:error, :bad_ref}
      Path.type(path) != :relative or ".." in Path.split(path) -> {:error, :outside_root}
      true -> show_valid(root, ref, path)
    end
  end

  defp show_valid(root, ref, path) do
    with {:ok, sha} <- resolve(root, ref),
         {:ok, listed} <- git(root, ["ls-tree", sha, "--", path]),
         :ok <- present(listed),
         {:ok, bytes} <- git(root, ["cat-file", "blob", sha <> ":./" <> path]) do
      Baseline.parse(bytes)
    end
  end

  defp present(""), do: {:error, :absent}
  defp present(_listed), do: :ok

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
