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
  """

  @callback read(root :: Path.t(), path :: Path.t()) :: {:ok, binary()} | {:error, term()}

  @callback create(root :: Path.t(), path :: Path.t(), contents :: binary()) ::
              :ok | {:error, :exists | term()}
end
