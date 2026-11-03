defmodule Anchor.Adapters.CoverageStore do
  @moduledoc """
  Behaviour for writing and reading a coverage map file (DND-5474), the
  **Side Effect** port (ADR 001); the implementation is
  `Anchor.Adapters.CoverageFile`, doubled in tests as `Anchor.CoverageStoreMock`.

    * `write/2` — writes the map (its directory made first);
    * `read/1` — the term the file holds, `{:error, posix}` when it cannot be
      read, `{:error, :undecodable}` when it is not a safe external term.
  """

  @callback write(path :: String.t(), map :: map()) :: :ok | {:error, atom()}
  @callback read(path :: String.t()) :: {:ok, term()} | {:error, atom()}
end
