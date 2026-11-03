defmodule Anchor.Domain.Graph.ProjectFile do
  @moduledoc """
  Where a beam's source file sits against the project root — **Domain**,
  pure (DND-5588).

  The graph identifies a project module by its repo-relative source path
  (`elixir_v1` `:relative_file`), which the selectors' `paths` globs and the
  source reader both use. The compiler writes that path relative to the
  directory it ran in, and leaves it absolute when the file is outside that
  directory: a file an `elixirc_paths` entry such as `../shared` names, a
  generated file, or a project compiled from another directory. `place/2`
  answers for one path:

    * a relative path is the project's, as it stands;
    * an absolute path inside `root` is the project's, made relative to
      `root` (so a `paths` glob and the source reader see it as they see
      every other file);
    * an absolute path outside `root` is `:outside_root`: the runner leaves
      the module out of the graph, counts it, and names it in a report-only
      note, never silently;
    * no path (an Erlang module, or a beam with no source) is the project's,
      as `nil`: the model decides what that module is.

  `..` segments are resolved first, so `<root>/../x.ex` is outside the root.
  The answer is a fact about the paths' text only: no file is read, no
  symlink is followed, and `root` must be absolute (a relative one would be
  read against the working directory, which is IO).
  """

  @doc "Places one source path against the absolute project root; see the moduledoc."
  @spec place(String.t() | nil, Path.t()) :: {:project, String.t() | nil} | :outside_root
  def place(file, root) when is_binary(root) do
    if Path.type(root) != :absolute,
      do: raise(ArgumentError, "the project root must be an absolute path, got: #{inspect(root)}")

    placed(file, Path.expand(root))
  end

  defp placed(nil, _root), do: {:project, nil}

  defp placed(file, root) when is_binary(file) do
    if Path.type(file) == :absolute,
      do: absolute(Path.expand(file), root),
      else: {:project, file}
  end

  defp absolute(file, root) do
    relative = Path.relative_to(file, root)

    if Path.type(relative) == :relative and relative != ".",
      do: {:project, relative},
      else: :outside_root
  end
end
