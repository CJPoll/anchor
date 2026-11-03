defmodule Anchor.Adapters.ChangeSource do
  @moduledoc """
  Behaviour for reading what a working tree changed against a base, the
  **Side Effect** port (ADR 001) `Anchor.Managers.Sabotage.scope/2` depends on
  (DND-5472). The real implementation is `Anchor.Adapters.GitChangeSource`;
  tests double it with Hammox (`Anchor.ChangeSourceMock`).

  Every callback only reads. Paths are relative to `root`.

    * `merge_base/2` returns the merge-base of `ref` and `HEAD`, or
      `:not_a_work_tree`, `{:no_merge_base, ref}` (`ref` does not resolve, or
      shares no history with `HEAD`), or `{:git_failed, argv, status, output}`.
    * `diff/2` returns the raw `--unified=0` diff text between that commit and
      the working tree (committed, staged and unstaged changes).
    * `untracked/1` returns the untracked, not ignored `.ex` files.
    * `show/3` returns a file's contents as they were at that commit.
    * `read/2` returns a file's contents, or its posix error.
  """

  @type git_error :: {:git_failed, [String.t()], non_neg_integer(), String.t()}

  @callback merge_base(root :: String.t(), ref :: String.t()) ::
              {:ok, String.t()}
              | {:error, :not_a_work_tree | {:no_merge_base, String.t()} | git_error()}

  @callback diff(root :: String.t(), sha :: String.t()) ::
              {:ok, String.t()} | {:error, git_error()}

  @callback untracked(root :: String.t()) :: {:ok, [String.t()]} | {:error, git_error()}

  @callback show(root :: String.t(), sha :: String.t(), path :: String.t()) ::
              {:ok, String.t()} | {:error, git_error()}

  @callback read(root :: String.t(), path :: String.t()) :: {:ok, String.t()} | {:error, atom()}
end
