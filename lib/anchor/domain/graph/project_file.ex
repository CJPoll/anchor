defmodule Anchor.Domain.Graph.ProjectFile do
  @moduledoc """
  A beam's source path, keyed against the project root — **Domain**, pure
  (DND-5588, DND-5630).

  The graph identifies a project module by its root-relative source path,
  which the selectors' `paths` globs, the source reader, issues and baselines
  all use. The compiler writes a beam's `elixir_v1` `:relative_file` relative
  to the directory it ran in, and leaves it absolute when the file is outside
  that directory: a file an `elixirc_paths` entry such as `../shared` names,
  a generated file, or a project compiled from another directory.

  Membership is not decided here: the runner reads only the project's own
  ebins, so every beam it reads is project code, wherever its source sits
  (DND-5630 reverses DND-5588's report-only exclusion). `place/2` only keys
  the path and says which side of the root it is on:

    * `{:inside_root, path}` — a path under `root`, relative to it (an
      absolute one is made relative, so a `paths` glob and the source reader
      see it as they see every other file);
    * `{:outside_root, path}` — a path outside `root`, relative to it through
      `..` (`/work/shared/foo.ex` against `/work/my_app` is
      `../shared/foo.ex`): stable across machines, and what an issue and a
      baseline key name. The runner counts these in its summary, so the
      layout stays visible;
    * `{:inside_root, nil}` — no path (an Erlang module, or a beam with no
      source): the model decides what that module is.

  `..` segments are resolved first, so `<root>/../x.ex` is outside the root.
  A relative path is read against `root`, never the working directory, and a
  `~` in it is a directory name, not the home directory. The answer is a fact
  about the paths' text only: no file is read, no symlink is followed, and
  `root` must be absolute (a relative one would be read against the working
  directory, which is IO).
  """

  @type side :: :inside_root | :outside_root

  @doc "Keys one source path against the absolute project root; see the moduledoc."
  @spec place(String.t() | nil, Path.t()) :: {side(), String.t() | nil}
  def place(file, root) when is_binary(root) do
    if Path.type(root) != :absolute,
      do: raise(ArgumentError, "the project root must be an absolute path, got: #{inspect(root)}")

    placed(file, Path.expand(root))
  end

  defp placed(nil, _root), do: {:inside_root, nil}

  defp placed(file, root) when is_binary(file) do
    relative =
      file
      |> absolute(root)
      |> Path.expand()
      |> Path.relative_to(root, force: true)

    {side(relative), relative}
  end

  # `Path.join/2`, never `Path.expand/2` with a base: expand would read a
  # leading `~` as the home directory.
  defp absolute(file, root) do
    if Path.type(file) == :absolute, do: file, else: Path.join(root, file)
  end

  defp side(relative) do
    if relative == ".." or String.starts_with?(relative, "../"),
      do: :outside_root,
      else: :inside_root
  end
end
