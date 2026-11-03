defmodule Anchor.Adapters.GitStatus do
  @moduledoc """
  Asks git whether files are dirty or ignored, the **Side Effect** adapter
  (ADR 001) behind `Anchor.Adapters.GitWorktree` (DND-5473). Argv only, never
  a shell; paths go after `--`, and optional locks are off so a status never
  rewrites the index. It only reads. The environment is
  `Anchor.Adapters.GitEnv.env/0`: inside a git hook it still asks about the
  repository at `root`, never the one `GIT_DIR` names (DND-5581).

    * `git status --porcelain=v1 -z --no-renames --untracked-files=all -- <paths>`;
    * `git check-ignore -q -- <path>` (exit 0 ignored, 1 not).
  """

  @behaviour Anchor.Adapters.GitWorktree

  alias Anchor.Adapters.GitEnv

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

  defp git(root, args),
    do:
      System.cmd("git", args,
        cd: root,
        stderr_to_stdout: false,
        env: GitEnv.env()
      )
end
