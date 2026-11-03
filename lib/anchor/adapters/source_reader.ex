defmodule Anchor.Adapters.SourceReader do
  @moduledoc """
  Reads source files off disk — the **Side Effect** adapter behind
  `Anchor.Adapters.SourceSource` (DND-5440).

  Each path is read relative to the root (an absolute path is read as it
  stands). A file that cannot be read is `{:error, posix}` in the result,
  keyed by the path it was asked for: never dropped, so the runner reports it.
  """

  @behaviour Anchor.Adapters.SourceSource

  @impl Anchor.Adapters.SourceSource
  def read(root, paths) do
    Map.new(paths, fn path -> {path, File.read(Path.expand(path, root))} end)
  end
end
