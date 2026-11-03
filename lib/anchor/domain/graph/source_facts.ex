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

    * `nonliteral_defmodule?` — whether the file has a `defmodule` whose name
      is not literal (`defmodule unquote(name)`, `defmodule Module.concat(...)`).
      Such a module, and every module nested in it, has a name the text does
      not show, so it is not collected and its `use`s are filed nowhere. A
      module of this file missing from `defmodules` may then be hand-written,
      and the builder answers `:unknown` for it, never `true`.

  Names are strings as written, without the `Elixir.` prefix; `__MODULE__` at
  the head of a nested module's name resolves to the enclosing module.
  Reading the file is the caller's job (the runner, DND-5440): this function
  takes the text.
  """

  @type t :: %{
          defmodules: [String.t()],
          uses: %{String.t() => [String.t()]},
          nonliteral_defmodule?: boolean()
        }

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
    entries = ast |> walk(nil, []) |> Enum.reverse()
    modules = Enum.reject(entries, &(&1 == :nonliteral))
    uses = Map.new(modules, fn {name, uses} -> {name, Enum.reverse(uses)} end)

    %{
      defmodules: Enum.map(modules, &elem(&1, 0)),
      uses: uses,
      nonliteral_defmodule?: :nonliteral in entries
    }
  end

  # `acc` is a list of `{module_name, uses}` and `:nonliteral` entries, newest
  # first. `current` is the name of the module whose body is being walked, nil
  # at the top level, or `:nonliteral` inside a module whose name is not literal.
  defp walk({:quote, _meta, args}, _current, acc) when is_list(args), do: acc

  defp walk({:defmodule, _meta, [name_ast, body]}, current, acc) do
    case module_name(name_ast, current) do
      {:ok, full} -> walk(body, full, [{full, []} | acc])
      :error -> walk(body, :nonliteral, [:nonliteral | acc])
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
      :nonliteral -> :nonliteral
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

  # The full name of a `defmodule`: its literal name qualified by the enclosing
  # module, `__MODULE__.Child` resolved against it. Inside a module whose name is
  # not literal, no name is.
  defp module_name(_name_ast, :nonliteral), do: :error

  defp module_name({:__aliases__, meta, [{:__MODULE__, _, context} | rest]}, current)
       when is_binary(current) and is_atom(context) and rest != [] do
    case literal_name({:__aliases__, meta, rest}) do
      {:ok, name} -> {:ok, current <> "." <> name}
      :error -> :error
    end
  end

  defp module_name(name_ast, current) do
    case literal_name(name_ast) do
      {:ok, name} -> {:ok, qualify(current, name)}
      :error -> :error
    end
  end

  defp qualify(nil, name), do: name
  defp qualify(parent, name), do: parent <> "." <> name
end
