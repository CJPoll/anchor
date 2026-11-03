defmodule Anchor.Adapters.ProjectModuleSource do
  @moduledoc """
  Behaviour for listing a project's own modules (DND-5474), the **Side
  Effect** port (ADR 001); the implementation is
  `Anchor.Adapters.ProjectModules`, doubled in tests as
  `Anchor.ProjectModuleSourceMock`.

  `list(ebin_dirs)` compiles the project, then returns the module of every `*.beam` file in those
  directories (never a dependency's or the standard library's), sorted.
  """

  @callback list(ebin_dirs :: [String.t()]) :: [module()]
end
