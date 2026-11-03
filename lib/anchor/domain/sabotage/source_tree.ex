defmodule Anchor.Domain.Sabotage.SourceTree do
  @moduledoc """
  The source-tree queries the sabotage generator needs (DND-5471). Pure
  **Domain**: it parses text with `Sourceror.parse_string/1` (and, for one
  node's text, `Code.string_to_quoted/2`) and walks the result. Nothing is
  evaluated, compiled or loaded.

  Sourceror's tree keeps every node's exact source range, so an edit replaces
  only the text it targets and formatting elsewhere is never re-rendered. Its
  literals are wrapped (`{:__block__, meta, [:ok]}`), so whenever a node's
  meaning matters (effect calls, normalized targets, data flow) its text is
  read again as a plain quoted expression with `quoted/2`.
  """

  alias Anchor.Domain.Sabotage.Patch

  @type clause :: %{
          def: :def | :defp,
          node: Macro.t(),
          head: Macro.t(),
          call: Macro.t(),
          args: [Macro.t()],
          guard: Macro.t() | nil,
          body: Macro.t() | nil
        }

  @doc """
  Parses a whole source file. `{:error, {:parse_error, line, message}}` when
  it does not parse.
  """
  @spec parse(String.t()) ::
          {:ok, Macro.t()} | {:error, {:parse_error, pos_integer(), String.t()}}
  def parse(source) when is_binary(source) do
    case Sourceror.parse_string(source) do
      {:ok, ast} -> {:ok, ast}
      {:error, error} -> {:error, {:parse_error, error_line(error), error_message(error)}}
    end
  end

  @doc """
  Every literal `def`/`defp` clause of `name` covering `arity` in the module
  `module` (found by `defmodule` nesting), in source order, with a body. A
  clause with default arguments (`\\\\`) covers `required..total`; a bodiless
  head with defaults (`def f(a, b \\\\ 1)`) makes every clause of its total
  arity cover its shorter arities too. `:not_in_source` when no literal
  `def`/`defp` head of `name` covers `arity` there (a macro-generated
  function, a missing module).
  """
  @spec function_clauses(Macro.t(), module(), atom(), arity()) ::
          {:ok, [clause()]} | {:error, :not_in_source}
  def function_clauses(ast, module, name, arity) do
    with {:ok, body} <- module_body(ast, module) do
      clauses =
        body |> statements() |> Enum.flat_map(&def_clause/1) |> Enum.filter(&(&1.name == name))

      header_totals = for c <- clauses, c.body == nil, covers?(c, arity), do: length(c.args)

      matching =
        Enum.filter(clauses, fn c ->
          covers?(c, arity) or (c.body != nil and length(c.args) in header_totals)
        end)

      if matching == [],
        do: {:error, :not_in_source},
        else:
          {:ok, matching |> Enum.filter(&(&1.body != nil)) |> Enum.map(&Map.delete(&1, :name))}
    end
  end

  @doc "The `defmodule` node of `module`, found by nesting, or `:error`."
  @spec module_node(Macro.t(), module()) :: {:ok, Macro.t()} | :error
  def module_node(ast, module) do
    case find_module(statements(ast), [], Module.split(module)) do
      nil -> :error
      node -> {:ok, node}
    end
  end

  @doc "A keyword key as written: Sourceror wraps it (`{:__block__, _, [:do]}`)."
  @spec key(Macro.t()) :: term()
  def key({:__block__, _meta, [key]}), do: key
  def key(key), do: key

  @doc "The value of keyword `name` in a Sourceror keyword list, or `nil`."
  @spec keyword(Macro.t(), atom()) :: Macro.t() | nil
  def keyword(list, name) when is_list(list) do
    Enum.find_value(list, fn
      {key, value} -> if key(key) == name, do: {:found, value}
      _other -> nil
    end)
    |> case do
      {:found, value} -> value
      nil -> nil
    end
  end

  def keyword(_other, _name), do: nil

  @doc """
  Every node under `ast` (itself included), outermost first, in source order.
  `quote` bodies are not entered: they build code, they do not run it.
  """
  @spec nodes(Macro.t()) :: [Macro.t()]
  def nodes(ast) do
    {_ast, acc} =
      Macro.traverse(
        ast,
        [],
        fn
          {:quote, _meta, args} = node, acc when is_list(args) -> {{:quote, [], []}, [node | acc]}
          node, acc -> {node, [node | acc]}
        end,
        fn node, acc -> {node, acc} end
      )

    Enum.reverse(acc)
  end

  @doc """
  A plain quoted expression from `text` (no Sourceror wrapping), with lines
  counted from `line`. `:error` when the text alone is not an expression.
  """
  @spec quoted(String.t(), pos_integer()) :: {:ok, Macro.t()} | :error
  def quoted(text, line \\ 1) do
    case Code.string_to_quoted(text, line: line) do
      {:ok, ast} -> {:ok, ast}
      {:error, _error} -> :error
    end
  end

  @doc "The exact range of a node, `{{line, column}, {line, column}}`, end exclusive."
  @spec range(Macro.t()) :: Patch.range() | nil
  def range(node) do
    case Sourceror.get_range(node) do
      %{start: start, end: stop} ->
        {{start[:line], start[:column]}, {stop[:line], stop[:column]}}

      nil ->
        nil
    end
  end

  @doc "The range from the start of `first` to the end of `last`."
  @spec span(Macro.t(), Macro.t()) :: Patch.range()
  def span(first, last) do
    {start, _stop} = range(first)
    {_start, stop} = range(last)
    {start, stop}
  end

  @doc "The statements of a body: a multi-statement block's members, or the node alone."
  @spec statements(Macro.t()) :: [Macro.t()]
  def statements({:__block__, meta, [_first, _second | _rest] = exprs}) when is_list(meta),
    do: exprs

  def statements({:__block__, meta, []}) when is_list(meta), do: []
  def statements(node), do: [node]

  @doc """
  Whether `node` is a real multi-statement block (Sourceror also wraps a lone
  literal or a parenthesised expression in a one-element `__block__`).
  """
  @spec block?(Macro.t()) :: boolean()
  def block?({:__block__, _meta, [_first, _second | _rest]}), do: true
  def block?(_node), do: false

  @doc "A clause as `{args, guards, body}` for `Anchor.Domain.DataFlow.analyze/1`."
  @spec dataflow_clause(String.t(), clause()) ::
          {:ok, {[Macro.t()], [Macro.t()], Macro.t()}} | :error
  def dataflow_clause(source, clause) do
    {{line, _column}, _stop} = range = range(clause.node)

    case quoted(Patch.slice(source, range), line) do
      {:ok, {def, _meta, [head | rest]}} when def in [:def, :defp] ->
        {call, guards} = split_head(head)
        body = rest |> List.first([]) |> Keyword.get(:do)
        {:ok, {call_args(call), guards, body}}

      _other ->
        :error
    end
  end

  defp call_args({_name, _meta, args}) when is_list(args), do: args
  defp call_args(_call), do: []

  defp covers?(%{args: args}, arity) do
    defaults = Enum.count(args, &match?({:\\, _meta, [_pattern, _default]}, &1))
    arity in (length(args) - defaults)..length(args)//1
  end

  defp def_clause({def, _meta, [head | rest]} = node) when def in [:def, :defp] do
    {call, guard} =
      case head do
        {:when, _wmeta, [call, guard]} -> {call, guard}
        call -> {call, nil}
      end

    case call do
      {name, _cmeta, args} when is_atom(name) and (is_list(args) or is_atom(args)) ->
        [
          %{
            def: def,
            node: node,
            head: head,
            call: call,
            name: name,
            args: if(is_list(args), do: args, else: []),
            guard: guard,
            body: rest |> List.first() |> keyword(:do)
          }
        ]

      _other ->
        []
    end
  end

  defp def_clause(_node), do: []

  # A mismatched delimiter is reported at its opener; the line that holds the
  # wrong closer is `end_line`.
  defp error_line({location, _error, _token}) when is_list(location) do
    if location[:error_type] == :mismatched_delimiter,
      do: Keyword.get(location, :end_line, Keyword.get(location, :line, 1)),
      else: Keyword.get(location, :line, 1)
  end

  defp error_line({line, _error, _token}) when is_integer(line), do: line
  defp error_line(_error), do: 1

  defp error_message({_location, {prefix, suffix}, token})
       when is_binary(prefix) and is_binary(suffix),
       do: prefix <> to_string(token) <> suffix

  defp error_message({_location, message, token}) when is_binary(message),
    do: message <> to_string(token)

  defp error_message(error), do: inspect(error)

  defp find_module(statements, prefix, wanted),
    do: Enum.find_value(statements, &module_match(&1, prefix, wanted))

  defp module_body(ast, module) do
    case module_node(ast, module) do
      {:ok, {:defmodule, _meta, [_name, kw]}} -> {:ok, keyword(kw, :do)}
      :error -> {:error, :not_in_source}
    end
  end

  defp module_match(
         {:defmodule, _meta, [{:__aliases__, _ameta, segments}, kw]} = node,
         prefix,
         wanted
       ) do
    if Enum.all?(segments, &is_atom/1) do
      path = prefix ++ Enum.map(segments, &Atom.to_string/1)

      cond do
        path == wanted ->
          node

        Enum.take(wanted, length(path)) == path ->
          find_module(statements(keyword(kw, :do)), path, wanted)

        true ->
          nil
      end
    end
  end

  defp module_match(_node, _prefix, _wanted), do: nil

  defp split_head({:when, _meta, [call, guard]}), do: {call, [guard]}
  defp split_head(call), do: {call, []}
end
