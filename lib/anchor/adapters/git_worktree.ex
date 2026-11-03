defmodule Anchor.Adapters.GitWorktree do
  @moduledoc """
  Behaviour for the two git questions a sabotage run asks before it writes
  (DND-5473), the **Side Effect** port (ADR 001); the implementation is
  `Anchor.Adapters.GitStatus`, doubled in tests as `Anchor.GitWorktreeMock`.

    * `dirty_paths/2` — which of the paths (relative to `root`) have
      uncommitted changes, untracked included;
    * `ignored?/2` — whether git ignores the path.
  """

  @type git_error :: {:git_failed, [String.t()], non_neg_integer(), String.t()}

  @callback dirty_paths(root :: String.t(), paths :: [String.t()]) ::
              {:ok, [String.t()]} | {:error, git_error()}
  @callback ignored?(root :: String.t(), path :: String.t()) ::
              {:ok, boolean()} | {:error, git_error()}
end
