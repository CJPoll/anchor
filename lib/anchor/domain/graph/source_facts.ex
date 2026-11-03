defmodule Anchor.Domain.Graph.SourceFacts do
  @moduledoc """
  Facts the causal graph takes from a source file's text — **Domain** (ADR 001),
  pure (DND-5438).

  The graph reads compiled beams, where a module emitted by a macro looks the
  same as a hand-written one. The source text tells them apart: a module is
  hand-written when its file holds a literal `defmodule` naming it.
  `from_source/2` collects:

    * `defmodules` — the name of every literal `defmodule` in the file, fully
      qualified through nesting (`defmodule A do defmodule B` gives `"A"` and
      `"A.B"`), in source order. A `defmodule` inside a `quote` is macro output,
      not a literal module of this file, and is not collected.
    * `uses` — for each of those modules, the literal `use` targets in its own
      body (not in a nested module's, and not inside a `quote`).

  Names are strings as written, without the `Elixir.` prefix. A `defmodule`
  whose name is not a literal alias or atom (`defmodule unquote(name)`) names
  nothing literally and is skipped. Reading the file is the caller's job (the
  runner, DND-5440): this function takes the text.
  """

  @type t :: %{defmodules: [String.t()], uses: %{String.t() => [String.t()]}}

  @doc """
  Parses `text` (the contents of `path`) and returns its facts, or
  `{:error, :unparseable}` when the text does not parse. `path` is used only as
  the parser's file name.
  """
  @spec from_source(String.t(), String.t()) :: t() | {:error, :unparseable}
  def from_source(path, text) do
    case Code.string_to_quoted(text, file: path) do
      {:ok, ast} -> collect(ast)
      {:error, _reason} -> {:error, :unparseable}
    end
  end

  defp collect(ast) do
    modules = walk(ast, nil, [])
    names = modules |> Enum.reverse() |> Enum.map(&elem(&1, 0))
    uses = Map.new(modules, fn {name, uses} -> {name, Enum.reverse(uses)} end)
    %{defmodules: names, uses: uses}
  end

  # `acc` is a list of `{module_name, uses}` (newest first). `current` is the
  # name of the module whose body is being walked, or nil at the top level.
  defp walk({:quote, _meta, args}, _current, acc) when is_list(args), do: acc

  defp walk({:defmodule, _meta, [name_ast, body]}, current, acc) do
    case literal_name(name_ast) do
      {:ok, name} ->
        full = qualify(current, name)
        walk(body, full, [{full, []} | acc])

      :error ->
        walk(body, current, acc)
    end
  end

  defp walk({:use, _meta, [target | _opts]}, current, acc) when is_binary(current) do
    case literal_name(target) do
      {:ok, name} -> add_use(acc, current, name)
      :error -> acc
    end
  end

  defp walk({form, _meta, args}, current, acc) when is_list(args) do
    acc = walk(form, current, acc)
    Enum.reduce(args, acc, &walk(&1, current, &2))
  end

  defp walk({left, right}, current, acc), do: walk(right, current, walk(left, current, acc))

  defp walk(list, current, acc) when is_list(list),
    do: Enum.reduce(list, acc, &walk(&1, current, &2))

  defp walk(_leaf, _current, acc), do: acc

  defp add_use(acc, current, name) do
    Enum.map(acc, fn
      {^current, uses} -> {current, [name | uses]}
      other -> other
    end)
  end

  defp literal_name({:__aliases__, _meta, parts}) do
    if Enum.all?(parts, &is_atom/1),
      do: {:ok, parts |> Enum.map(&Atom.to_string/1) |> Enum.join(".")},
      else: :error
  end

  defp literal_name(atom) when is_atom(atom) and not is_nil(atom) and not is_boolean(atom),
    do: {:ok, atom |> Atom.to_string() |> String.replace_prefix("Elixir.", "")}

  defp literal_name(_other), do: :error

  defp qualify(nil, name), do: name
  defp qualify(parent, name), do: parent <> "." <> name
end
