defmodule Anchor.Adapters.GitShow do
  @moduledoc """
  Reads a file as it is on a git ref, the **Side Effect** adapter (ADR 001)
  behind `Anchor.Adapters.GitBase` (DND-5441).

  It refuses a ref `Anchor.Domain.Baseline.valid_ref?/1` rejects before git
  runs. Git runs with `System.cmd/3` (argv only, never a shell), in `root`,
  with `GIT_OPTIONAL_LOCKS=0`, and only reads:

    1. `git rev-parse --verify --quiet --end-of-options <ref>^{commit}`: a ref
       that does not resolve is an error, never an absent file;
    2. `git cat-file -e <sha>:./<path>`: a non-zero exit is an absent file
       (the commit resolved, so the path is what is missing);
    3. `git cat-file blob <sha>:./<path>`: the bytes.

  Git's stderr is kept out of the output it reads.
  """

  @behaviour Anchor.Adapters.GitBase

  alias Anchor.Domain.Baseline

  @impl Anchor.Adapters.GitBase
  def show(root, ref, path) do
    if Baseline.valid_ref?(ref), do: show_valid(root, ref, path), else: {:error, :bad_ref}
  end

  defp show_valid(root, ref, path) do
    with {:ok, sha} <- resolve(root, ref) do
      object = sha <> ":./" <> path

      case git(root, ["cat-file", "-e", object]) do
        {_out, 0} -> blob(root, object)
        {_out, _status} -> {:error, :absent}
      end
    end
  end

  defp resolve(root, ref) do
    case git(root, ["rev-parse", "--verify", "--quiet", "--end-of-options", ref <> "^{commit}"]) do
      {out, 0} -> {:ok, String.trim(out)}
      {out, status} -> {:error, {:git, status, out}}
    end
  end

  defp blob(root, object) do
    case git(root, ["cat-file", "blob", object]) do
      {out, 0} -> {:ok, out}
      {out, status} -> {:error, {:git, status, out}}
    end
  end

  defp git(root, args) do
    System.cmd("git", args, cd: root, stderr_to_stdout: false, env: [{"GIT_OPTIONAL_LOCKS", "0"}])
  end
end
