defmodule Anchor.Adapters.ProjectModules do
  @moduledoc """
  Lists a project's modules from its ebin directories (DND-5474), the **Side
  Effect** adapter (ADR 001) behind `Anchor.Adapters.ProjectModuleSource`. A
  module is named by its `.beam` file's name; nothing is loaded here. The
  project is compiled first (`Mix.Task.run("compile")`), so the ebin
  directories hold what the suite will run.
  """

  @behaviour Anchor.Adapters.ProjectModuleSource

  @impl Anchor.Adapters.ProjectModuleSource
  def list(ebin_dirs) do
    _compiled = Mix.Task.run("compile")

    ebin_dirs
    |> Enum.flat_map(&Path.wildcard(Path.join(&1, "*.beam")))
    |> Enum.map(&(&1 |> Path.basename(".beam") |> String.to_atom()))
    |> Enum.uniq()
    |> Enum.sort()
  end
end
