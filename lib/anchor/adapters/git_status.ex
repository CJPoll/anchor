defmodule Anchor.Adapters.GitStatus do
  @moduledoc """
  Asks git whether files are dirty or ignored, the **Side Effect** adapter
  (ADR 001) behind `Anchor.Adapters.GitWorktree` (DND-5473). Argv only, never
  a shell; paths go after `--`, and optional locks are off so a status never
  rewrites the index. It only reads.

    * `git status --porcelain=v1 -z --no-renames --untracked-files=all -- <paths>`;
    * `git check-ignore -q -- <path>` (exit 0 ignored, 1 not);
    * `git rev-parse --verify HEAD` (DND-5474);
    * `git merge-base --is-ancestor <sha> HEAD` (exit 0 an ancestor, 1 not,
      128 a commit git does not have: not an ancestor);
    * `git diff --name-only --relative -z <sha> --` and
      `git ls-files --others --exclude-standard -z` (both relative to `root`,
      so a project below the git root gets its own paths).
  """

  @behaviour Anchor.Adapters.GitWorktree

  @impl Anchor.Adapters.GitWorktree
  def dirty_paths(_root, []), do: {:ok, []}

  def dirty_paths(root, paths) do
    args = ~w(status --porcelain=v1 -z --no-renames --untracked-files=all --) ++ paths

    case git(root, args) do
      {out, 0} ->
        {:ok,
         out
         |> String.split(<<0>>, trim: true)
         |> Enum.map(fn <<_xy::binary-size(2), " ", path::binary>> -> path end)}

      {out, status} ->
        {:error, {:git_failed, args, status, out}}
    end
  end

  @impl Anchor.Adapters.GitWorktree
  def ignored?(root, path) do
    args = ["check-ignore", "-q", "--", path]

    case git(root, args) do
      {_out, 0} -> {:ok, true}
      {_out, 1} -> {:ok, false}
      {out, status} -> {:error, {:git_failed, args, status, out}}
    end
  end

  @impl Anchor.Adapters.GitWorktree
  def head_sha(root) do
    args = ["rev-parse", "--verify", "HEAD"]

    case git(root, args) do
      {out, 0} -> {:ok, String.trim(out)}
      {out, status} -> {:error, {:git_failed, args, status, out}}
    end
  end

  @impl Anchor.Adapters.GitWorktree
  def ancestor?(root, sha) do
    args = ["merge-base", "--is-ancestor", sha, "HEAD"]

    case git(root, args) do
      {_out, 0} -> {:ok, true}
      {_out, status} when status in [1, 128] -> {:ok, false}
      {out, status} -> {:error, {:git_failed, args, status, out}}
    end
  end

  @impl Anchor.Adapters.GitWorktree
  def changed_since(root, sha) do
    with {:ok, changed} <- names(root, ["diff", "--name-only", "--relative", "-z", sha, "--"]),
         {:ok, untracked} <- names(root, ["ls-files", "--others", "--exclude-standard", "-z"]) do
      {:ok, Enum.uniq(changed ++ untracked)}
    end
  end

  defp names(root, args) do
    case git(root, args) do
      {out, 0} -> {:ok, String.split(out, <<0>>, trim: true)}
      {out, status} -> {:error, {:git_failed, args, status, out}}
    end
  end

  defp git(root, args),
    do:
      System.cmd("git", args,
        cd: root,
        stderr_to_stdout: false,
        env: [{"GIT_OPTIONAL_LOCKS", "0"}]
      )
end
