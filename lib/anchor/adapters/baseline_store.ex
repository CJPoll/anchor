defmodule Anchor.Adapters.BaselineStore do
  @moduledoc """
  Behaviour for a rule's baseline file, the **Side Effect** port (ADR 001)
  through which `mix anchor.graph` reads and creates baselines (DND-5441,
  shared contract section 8). The real adapter is
  `Anchor.Adapters.BaselineFile`; tests double it with Hammox
  (`Anchor.BaselineStoreMock`).

  Paths are relative to `root` (the config refuses an absolute path and a
  `..` segment). `create/3` only creates: on an existing file it returns
  `{:error, :exists}` and leaves the file as it was, so `--write-baseline`
  can never loosen a baseline that is already there.

  `read/2` returns the file's entries, parsed by
  `Anchor.Domain.Baseline.parse/1` (ADR 001: an adapter returns Domain values,
  never the raw bytes), or `{:error, {:line, n, :invalid_utf8}}` for a line
  that is not UTF-8, or the read's own error.
  """

  @callback read(root :: Path.t(), path :: Path.t()) ::
              {:ok, [String.t()]}
              | {:error, {:line, pos_integer(), :invalid_utf8} | :outside_root | File.posix()}

  @callback create(root :: Path.t(), path :: Path.t(), contents :: binary()) ::
              :ok | {:error, :exists | term()}
end
