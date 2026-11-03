defmodule Anchor.Adapters.SourceSource do
  @moduledoc """
  Behaviour for reading a project's source files — the **Side Effect** port
  (ADR 001) the graph runner reads each module's source facts through
  (DND-5440): its literal `defmodule`s and `use`s
  (`Anchor.Domain.Graph.SourceFacts`).

  `read/2` takes the project root and repo-relative paths and returns one
  entry per path: the file's `SourceFacts`, `{:error, :unparseable}` for a
  file that does not parse, or `{:error, reason}` for one that cannot be read.
  No raw text leaves the adapter (ADR 001). A path that cannot be read is an
  error entry, never dropped. The real adapter is
  `Anchor.Adapters.SourceReader`.
  """

  alias Anchor.Domain.Graph.SourceFacts

  @callback read(root :: Path.t(), paths :: [String.t()]) ::
              %{String.t() => SourceFacts.t() | {:error, :unparseable} | {:error, term()}}
end
