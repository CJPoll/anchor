defmodule Anchor.Adapters.SourceMutation do
  @moduledoc """
  Behaviour for writing mutants into a project and putting it back, the
  **Side Effect** port (ADR 001) `Anchor.Managers.Sabotage.run/2` depends on
  (DND-5473). The real implementation is `Anchor.Adapters.SourcePatcher`;
  tests double it with Hammox (`Anchor.SourceMutationMock`).

  The journal callbacks take the project root (the journal lives at
  `Anchor.Domain.Sabotage.Journal.path/0` under it); every other path is
  absolute.

    * `read_journal/1` — the entry, `:none`, or `{:error, :corrupt_journal}`;
    * `write_journal/2` (it stamps the journal with this run as its owner),
      `delete_journal/1`;
    * `owner_alive?/1` — whether a journal's owner is a live process (never
      true for `nil`);
    * `take_lock/1` — takes the run lock (`Journal.lock_path/0`) for this run:
      `{:error, {:held, owner}}` while a live run holds it; a dead holder's
      lock is taken over, under `<lock>.takeover`; `{:error, {:stuck, path}}`
      when a run was killed mid-takeover; `{:error, :no_proc}` on a host with
      no `/proc` (the lock could name no owner, DND-5571); `release_lock/1`
      removes it while it is this run's;
    * `write_file/2` — writes `<path>.anchor-tmp`, then renames it over `path`;
    * `touch_ahead/1` — moves the mtime forward, so Mix recompiles the file;
    * `sha256_file/1` — the file's lowercase hex sha256;
    * `existing/1` — which of the paths are regular files;
    * `files_in/1` — the regular files directly in each directory, sorted
      per directory, none for one that cannot be listed (DND-6070: the
      mirror's siblings);
    * `symlinked/2` — which of the paths (relative to `root`) have a symlink
      at the file or at a directory above it under `root`, dangling or not
      (DND-5485: a replayed record must never steer a read or a write
      outside the project through one);
    * `save_run/2` — writes the run's saved result.
  """

  alias Anchor.Domain.Sabotage.Journal

  @type posix :: atom()

  @callback read_journal(root :: String.t()) ::
              {:ok, Journal.t()} | :none | {:error, :corrupt_journal | posix()}
  @callback write_journal(root :: String.t(), Journal.t()) :: :ok | {:error, posix()}
  @callback delete_journal(root :: String.t()) :: :ok | {:error, posix()}
  @callback write_file(path :: String.t(), bytes :: binary()) :: :ok | {:error, posix()}
  @callback touch_ahead(path :: String.t()) :: :ok | {:error, posix()}
  @callback sha256_file(path :: String.t()) :: {:ok, String.t()} | {:error, posix()}
  @callback existing(paths :: [String.t()]) :: [String.t()]
  @callback files_in(dirs :: [String.t()]) :: [String.t()]
  @callback symlinked(root :: String.t(), paths :: [String.t()]) :: [String.t()]
  @callback save_run(path :: String.t(), bytes :: binary()) :: :ok | {:error, posix()}
  @callback owner_alive?(Journal.owner() | nil) :: boolean()
  @callback take_lock(root :: String.t()) ::
              :ok
              | {:error,
                 :no_proc | {:held, Journal.owner() | nil} | {:stuck, String.t()} | posix()}
  @callback release_lock(root :: String.t()) :: :ok | {:error, posix()}
end
