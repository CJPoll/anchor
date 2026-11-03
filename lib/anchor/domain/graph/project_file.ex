defmodule Anchor.Domain.Graph.ProjectFile do
  @moduledoc """
  Whether a beam's source file is the project's — **Domain**, pure (DND-5588).

  The graph identifies a project module by its repo-relative source path
  (`elixir_v1` `:relative_file`), which the selectors' `paths` globs and the
  source reader both use. The compiler writes that path relative to the
  directory it ran in, and leaves it absolute when the file is outside that
  directory: a path dependency's source, a generated file, or a project
  compiled from another directory. `place/2` answers for one such path:

    * a relative path is the project's, as it stands;
    * an absolute path inside `root` is the project's, made relative to
      `root` (so a `paths` glob and the source reader see it as they see
      every other file);
    * an absolute path outside `root` is a dependency's: the runner leaves
      the module out of the graph and counts it, never classifies it;
    * no path (an Erlang module, or a beam with no source) is the project's,
      as `nil`: the model decides what that module is.

  `..` segments are resolved first, so `<root>/../x.ex` is outside the root.
  The answer is a fact about the path's text only: no file is read, and a
  symlink is not followed.
  """

  @doc "Places one source path against the project root (absolute); see the moduledoc."
  @spec place(String.t() | nil, Path.t()) :: {:project, String.t() | nil} | :dependency
  def place(nil, _root), do: {:project, nil}

  def place(file, root) when is_binary(file) and is_binary(root) do
    if Path.type(file) == :absolute,
      do: absolute(Path.expand(file), Path.expand(root)),
      else: {:project, file}
  end

  defp absolute(file, root) do
    relative = Path.relative_to(file, root)

    if Path.type(relative) == :relative and relative != ".",
      do: {:project, relative},
      else: :dependency
  end
end
