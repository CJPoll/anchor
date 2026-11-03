defmodule Anchor.Adapters.SourceSource do
  @moduledoc """
  Behaviour for reading a project's source files — the **Side Effect** port
  (ADR 001) the graph runner reads each module's source through (DND-5440):
  its literal `use`s and `defmodule`s (`Anchor.Domain.Graph.SourceFacts`).

  `read/2` takes the project root and repo-relative paths and returns one
  entry per path, `{:ok, text}` or `{:error, reason}`. A path that cannot be
  read is an error entry, never dropped. The real adapter is
  `Anchor.Adapters.SourceReader`.
  """

  @callback read(root :: Path.t(), paths :: [String.t()]) ::
              %{String.t() => {:ok, binary()} | {:error, term()}}
end
