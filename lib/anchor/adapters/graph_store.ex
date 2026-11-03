defmodule Anchor.Adapters.GraphStore do
  @moduledoc """
  Behaviour for the graph artifact — the **Side Effect** port (ADR 001)
  through which `mix anchor.graph` leaves the graph it built for `mix
  anchor.explain` and `place` (DND-5440, shared contract section 2).

  `write/3` stores a term under a key in a directory; `read/2` returns it
  only when the stored key is the one asked for. The verdict never reads it.
  The real adapter is `Anchor.Adapters.GraphArtifact`.
  """

  @callback write(dir :: Path.t(), key :: String.t(), term()) :: :ok | {:error, term()}
  @callback read(dir :: Path.t(), key :: String.t()) :: {:ok, term()} | {:error, term()}
end
