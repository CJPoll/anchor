defmodule Anchor.Adapters.RecordStore do
  @moduledoc """
  Behaviour for the sabotage record files (DND-5484), the **Side Effect**
  port (ADR 001); the implementation is `Anchor.Adapters.RecordFile`, doubled
  in tests as `Anchor.RecordStoreMock`. Paths are relative to `root`.

    * `list/2` — the `*.md` files (never a `README.md`) in every directory
      the glob names, relative to `root`, sorted;
    * `read/2` — a record's text;
    * `create/3` — writes a new record (its directory made first);
      `{:error, :eexist}` when the path exists, which is never overwritten;
    * `append/3` — adds to an existing record, after a blank line;
    * `write_report/4` — writes a scan report (DND-5490): the markdown at
      `path` (relative to `root`, or absolute) and the term's bytes beside it,
      with the extension `.etf`. A report is a build output, so both are
      overwritten; it never writes a record.
  """

  @callback list(root :: String.t(), dir_glob :: String.t()) :: [String.t()]
  @callback read(root :: String.t(), path :: String.t()) :: {:ok, String.t()} | {:error, atom()}
  @callback create(root :: String.t(), path :: String.t(), content :: String.t()) ::
              :ok | {:error, atom()}
  @callback append(root :: String.t(), path :: String.t(), content :: String.t()) ::
              :ok | {:error, atom()}

  @callback write_report(
              root :: String.t(),
              path :: String.t(),
              markdown :: String.t(),
              term :: binary()
            ) :: {:ok, [String.t()]} | {:error, atom()}
end
