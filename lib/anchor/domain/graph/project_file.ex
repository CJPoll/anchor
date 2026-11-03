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
      `../shared/foo.ex`): stable across checkouts with the same relative
      layout, and what an issue and a baseline key name. The runner counts these in its summary, so the
      layout stays visible;
    * `{:inside_root, nil}` — no path (an Erlang module, or a beam with no
      source): the model decides what that module is.

  A relative path is relative to the directory the compiler ran in, which
  `place/3` takes relative to `root` (default `"."`, the root itself). In an
  umbrella Mix compiles each app from its own directory, so an app's beams
  carry app-relative paths (`lib/alpha.ex` for `apps/alpha/lib/alpha.ex`,
  recorded on a real two-app umbrella, DND-5637): read against
  `apps/alpha`, they are keyed `apps/alpha/lib/alpha.ex`, relative to the
  umbrella root like every other path. An absolute path does not depend on
  the directory.

  `..` segments are resolved first, so `<root>/../x.ex` is outside the root.
  A relative path is read against that directory, never the working directory, and a
  `~` in it is a directory name, not the home directory. The answer is a fact
  about the paths' text only: no file is read, no symlink is followed, and
  `root` must be absolute (a relative one would be read against the working
  directory, which is IO).
  """

  @type side :: :inside_root | :outside_root

  @doc """
  An umbrella's app directories (`Mix.Project.apps_paths/0`) relative to
  the absolute `root` (DND-5655): Mix gives them relative by default, but
  `apps_path` may be absolute. One under the root (after `..` is resolved,
  by text: no symlink is followed) is made relative to it; one outside it
  is `{:error, [{app, dir}]}`, every such app sorted, for the runner to
  refuse with a `Fix:` line, never a raise.
  """
  @spec source_dirs(%{optional(atom()) => Path.t()}, Path.t()) ::
          {:ok, %{optional(atom()) => Path.t()}} | {:error, [{atom(), Path.t()}]}
  def source_dirs(dirs, root) when is_map(dirs) and is_binary(root) do
    root = Path.expand(root)

    {outside, keyed} =
      dirs
      |> Enum.map(fn {app, dir} -> {app, dir, relative_dir(dir, root)} end)
      |> Enum.split_with(fn {_app, _dir, relative} -> relative == :outside end)

    case outside do
      [] -> {:ok, Map.new(keyed, fn {app, _dir, relative} -> {app, relative} end)}
      _ -> {:error, outside |> Enum.map(fn {app, dir, _} -> {app, dir} end) |> Enum.sort()}
    end
  end

  defp relative_dir(dir, root) do
    cond do
      Path.type(dir) != :absolute ->
        dir

      Path.expand(dir) == root ->
        "."

      String.starts_with?(Path.expand(dir), root <> "/") ->
        Path.relative_to(Path.expand(dir), root)

      true ->
        :outside
    end
  end

  @doc """
  Keys one source path against the absolute project root, a relative path
  read against `dir` (relative to `root`, the directory the compiler ran in);
  see the moduledoc.
  """
  @spec place(String.t() | nil, Path.t(), Path.t()) :: {side(), String.t() | nil}
  def place(file, root, dir \\ ".") when is_binary(root) and is_binary(dir) do
    if Path.type(root) != :absolute,
      do: raise(ArgumentError, "the project root must be an absolute path, got: #{inspect(root)}")

    if Path.type(dir) != :relative,
      do: raise(ArgumentError, "the directory must be relative to the root, got: #{inspect(dir)}")

    root = Path.expand(root)
    placed(file, root, Path.join(root, dir))
  end

  defp placed(nil, _root, _base), do: {:inside_root, nil}

  defp placed(file, root, base) when is_binary(file) do
    relative =
      file
      |> absolute(base)
      |> Path.expand()
      |> Path.relative_to(root, force: true)

    {side(relative), relative}
  end

  # `Path.join/2`, never `Path.expand/2` with a base: expand would read a
  # leading `~` as the home directory.
  defp absolute(file, base) do
    if Path.type(file) == :absolute, do: file, else: Path.join(base, file)
  end

  defp side(relative) do
    if relative == ".." or String.starts_with?(relative, "../"),
      do: :outside_root,
      else: :inside_root
  end
end
