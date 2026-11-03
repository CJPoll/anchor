defmodule Anchor.Adapters.GitWorktree do
  @moduledoc """
  Behaviour for the two git questions a sabotage run asks before it writes
  (DND-5473), the **Side Effect** port (ADR 001); the implementation is
  `Anchor.Adapters.GitStatus`, doubled in tests as `Anchor.GitWorktreeMock`.

    * `dirty_paths/2` — which of the paths (relative to `root`) have
      uncommitted changes, untracked included;
    * `ignored?/2` — whether git ignores the path;
    * `head_sha/1` — the full sha of `HEAD` (DND-5474);
    * `ancestor?/3` — whether a commit is an ancestor of `HEAD`
      (`git merge-base --is-ancestor`; a commit git does not have is not one);
    * `changed_since/2` — the paths whose working-tree content differs from
      that commit's, untracked (not ignored) files included;
    * `branch/1` — the checked-out branch's short name, `nil` on a detached
      `HEAD` (DND-5484).
  """

  @type git_error :: {:git_failed, [String.t()], non_neg_integer(), String.t()}

  @callback dirty_paths(root :: String.t(), paths :: [String.t()]) ::
              {:ok, [String.t()]} | {:error, git_error()}
  @callback ignored?(root :: String.t(), path :: String.t()) ::
              {:ok, boolean()} | {:error, git_error()}
  @callback head_sha(root :: String.t()) :: {:ok, String.t()} | {:error, git_error()}
  @callback ancestor?(root :: String.t(), sha :: String.t()) ::
              {:ok, boolean()} | {:error, git_error()}
  @callback changed_since(root :: String.t(), sha :: String.t()) ::
              {:ok, [String.t()]} | {:error, git_error()}
  @callback branch(root :: String.t()) :: {:ok, String.t() | nil} | {:error, git_error()}
end
