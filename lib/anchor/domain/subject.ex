defmodule Anchor.Domain.Subject do
  @moduledoc """
  What `mix anchor.explain` is asked about (DND-5446): a module or a source
  path — a **Domain** module (ADR 001). Pure: it reads the argument and the
  project root as text and does no IO (whether a path exists is the
  Manager's to read).

  `parse/2` answers:

    * `{:module, module}` for an exact Elixir module name (`Anchor.Domain.Graph`),
      read through `Anchor.Domain.AllowedCallers`' grammar, so only a valid
      name becomes an atom;
    * `{:path, path, implied}` for a path to an `.ex` file under the root,
      `path` relative to the root and `implied` the module Elixir's file
      naming convention gives it: the segments after `lib/`, each camelized
      (`lib/anchor/domain/new_thing.ex` is `Anchor.Domain.NewThing`; an
      umbrella's `apps/foo/lib/foo/bar.ex` is `Foo.Bar`); `nil` when the
      path has no `lib/` segment;
    * `{:error, :outside_root}` for a path that leaves the root (`..`, or an
      absolute path elsewhere), and `{:error, :not_a_subject}` for anything
      else (an empty argument, a glob, a file that is not `.ex`).
  """

  alias Anchor.Domain.AllowedCallers

  @type t :: {:module, module()} | {:path, String.t(), module() | nil}

  @doc "Parses `argument` against the project `root`; see the moduledoc."
  @spec parse(String.t(), String.t()) :: t() | {:error, :outside_root | :not_a_subject}
  def parse(argument, root) when is_binary(argument) and is_binary(root) do
    cond do
      String.ends_with?(argument, ".ex") -> path(argument, root)
      module_name?(argument) -> module(argument)
      true -> {:error, :not_a_subject}
    end
  end

  @doc """
  The repo-relative path Elixir's naming convention gives `module`
  (`lib/anchor/domain/graph.ex` for `Anchor.Domain.Graph`), for a module the
  graph has not placed.
  """
  @spec implied_path(module()) :: String.t()
  def implied_path(module), do: "lib/#{Macro.underscore(module)}.ex"

  @doc """
  The module the convention gives the `lib/`-relative path `path`, or `nil`
  when it has no `lib/` segment.
  """
  @spec implied_module(String.t()) :: module() | nil
  def implied_module(path) do
    case Enum.drop_while(Path.split(path), &(&1 != "lib")) do
      ["lib" | [_ | _] = rest] ->
        rest
        |> List.update_at(-1, &Path.rootname/1)
        |> Enum.map(&Macro.camelize/1)
        |> Module.concat()

      _no_lib ->
        nil
    end
  end

  defp module_name?(argument),
    do: argument != "" and not String.contains?(argument, ["/", "\\"])

  defp module(argument) do
    case AllowedCallers.parse(argument) do
      {:ok, module} -> {:module, module}
      {:error, _reason} -> {:error, :not_a_subject}
    end
  end

  defp path(argument, root) do
    expanded = Path.expand(argument, root)
    relative = Path.relative_to(expanded, Path.expand(root))

    if Path.type(relative) == :absolute or relative == expanded or
         hd(Path.split(relative)) == "..",
       do: {:error, :outside_root},
       else: {:path, relative, implied_module(relative)}
  end
end
