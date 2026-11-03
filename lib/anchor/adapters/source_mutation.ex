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
    * `write_journal/2`, `delete_journal/1`;
    * `write_file/2` — writes `<path>.anchor-tmp`, then renames it over `path`;
    * `touch_ahead/1` — moves the mtime forward, so Mix recompiles the file;
    * `sha256_file/1` — the file's lowercase hex sha256;
    * `existing/1` — which of the paths are regular files;
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
  @callback save_run(path :: String.t(), bytes :: binary()) :: :ok | {:error, posix()}
end
