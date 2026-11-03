defmodule Anchor.Adapters.SourceReader do
  @moduledoc """
  Reads source files off disk into their facts — the **Side Effect** adapter
  behind `Anchor.Adapters.SourceSource` (DND-5440).

  Each path is read relative to the root (an absolute path is read as it
  stands) and turned into `Anchor.Domain.Graph.SourceFacts` here, so no raw
  text leaves the adapter (ADR 001). A file that does not parse is
  `{:error, :unparseable}`; one that cannot be read is `{:error, posix}`.
  Either is keyed by the path it was asked for: never dropped, so the runner
  reports it.
  """

  @behaviour Anchor.Adapters.SourceSource

  alias Anchor.Domain.Graph.SourceFacts

  @impl Anchor.Adapters.SourceSource
  def read(root, paths) do
    Map.new(paths, fn path -> {path, facts(path, File.read(Path.expand(path, root)))} end)
  end

  defp facts(path, {:ok, text}), do: SourceFacts.from_source(path, text)
  defp facts(_path, {:error, posix}), do: {:error, posix}
end
