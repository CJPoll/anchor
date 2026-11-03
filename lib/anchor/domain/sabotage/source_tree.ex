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
  `module` (its node from `module_node/2`), in source order, with a body. A
  clause with default arguments (`\\\\`) covers `required..total`; a bodiless
  head with defaults (`def f(a, b \\\\ 1)`) makes every clause of its total
  arity cover its shorter arities too.

  Errors:

    * `:defimpl_target_not_literal` when `module` is `nil` (the name
      `FunctionSpans` gives an implementation it cannot name) and a `defimpl`
      whose `for:` (or protocol) is not a literal module name holds such a
      head (DND-5624);
    * `:not_in_source` otherwise when no literal `def`/`defp` head of `name`
      covers `arity` there (a macro-generated function, a missing module).
  """
  @spec function_clauses(Macro.t(), module() | nil, atom(), arity()) ::
          {:ok, [clause()]} | {:error, :not_in_source | :defimpl_target_not_literal}
  def function_clauses(ast, module, name, arity) do
    case module_node(ast, module) do
      {:ok, node} -> found(covering(node, name, arity))
      :error -> missing(unnamed_impl_covers?(ast, module, name, arity))
    end
  end

  @doc """
  The node that defines `module`, or `:error`: a `defmodule` or
  `defprotocol` (nested names joined, `Elixir.` and `__MODULE__` read), or a
  `defimpl` (DND-5624). A `defimpl P, for: T` defines `P.T`; with no `for:`
  it is `P.<the enclosing module>`; `for: [T1, T2]` defines each `P.Tn` from
  the one node. Names are read exactly as `Anchor.Domain.Sabotage.FunctionSpans`
  reads them (the literal spelling; aliases are not resolved), so every
  function it names is found here. `quote` bodies are not entered. A name the
  source does not spell literally names nothing, so `nil` is never found.
  """
  @spec module_node(Macro.t(), module() | nil) :: {:ok, Macro.t()} | :error
  def module_node(_ast, nil), do: :error

  def module_node(ast, module) do
    case Enum.find(definitions(ast), &(&1.name == module)) do
      nil -> :error
      %{node: node} -> {:ok, node}
    end
  end

  @doc """
  The `do` body of a node `module_node/2` returns (`defmodule`,
  `defprotocol` or `defimpl`, block or keyword form).
  """
  @spec definition_body(Macro.t()) :: Macro.t() | nil
  def definition_body({_kind, _meta, [_name | lists]}), do: lists |> options() |> keyword(:do)

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

  # The literal clauses and bodiless heads of `name` covering `arity` among
  # the statements of a definition's body; [] when none.
  defp covering(node, name, arity) do
    clauses =
      node
      |> definition_body()
      |> statements()
      |> Enum.flat_map(&def_clause/1)
      |> Enum.filter(&(&1.name == name))

    header_totals = for c <- clauses, c.body == nil, covers?(c, arity), do: length(c.args)

    Enum.filter(clauses, fn c ->
      covers?(c, arity) or (c.body != nil and length(c.args) in header_totals)
    end)
  end

  # Only the clauses with a body are mutated; a function whose covering heads
  # are all bodiless is in source with nothing to mutate.
  defp found([]), do: {:error, :not_in_source}

  defp found(matching),
    do: {:ok, matching |> Enum.filter(&(&1.body != nil)) |> Enum.map(&Map.delete(&1, :name))}

  defp missing(true), do: {:error, :defimpl_target_not_literal}
  defp missing(false), do: {:error, :not_in_source}

  defp unnamed_impl_covers?(ast, nil, name, arity) do
    ast
    |> definitions()
    |> Enum.any?(
      &(&1.kind == :defimpl and &1.name == nil and covering(&1.node, name, arity) != [])
    )
  end

  defp unnamed_impl_covers?(_ast, _module, _name, _arity), do: false

  # Every definition in the file, outermost first, each `%{kind, name, node}`
  # with `name` `nil` when the source does not spell it literally. Mirrors
  # `FunctionSpans`' walk on Sourceror's tree.
  defp definitions(ast), do: ast |> collect(nil, []) |> Enum.reverse()

  defp collect({:quote, _meta, args}, _parent, acc) when is_list(args), do: acc

  defp collect({kind, _meta, [name, kw]} = node, parent, acc)
       when kind in [:defmodule, :defprotocol] and is_list(kw) do
    full = nested_name(name, parent)
    collect(keyword(kw, :do), full, [%{kind: kind, name: full, node: node} | acc])
  end

  defp collect({:defimpl, _meta, [protocol | [_ | _] = lists]} = node, parent, acc) do
    if Enum.all?(lists, &is_list/1),
      do: collect_impl(protocol, options(lists), node, {parent, acc}),
      else: collect(lists, parent, collect(protocol, parent, acc))
  end

  defp collect({call, _meta, args}, parent, acc) when is_list(args),
    do: collect(args, parent, collect(call, parent, acc))

  defp collect({left, right}, parent, acc), do: collect(right, parent, collect(left, parent, acc))

  defp collect(nodes, parent, acc) when is_list(nodes),
    do: Enum.reduce(nodes, acc, &collect(&1, parent, &2))

  defp collect(_leaf, _parent, acc), do: acc

  # `for: [T1, T2]` is one definition per target, each with the same body.
  defp collect_impl(protocol, opts, node, {parent, acc}) do
    body = keyword(opts, :do)

    opts
    |> impl_targets()
    |> Enum.reduce(acc, fn target, acc ->
      name = impl_name(protocol, target, parent)
      collect(body, name, [%{kind: :defimpl, name: name, node: node} | acc])
    end)
  end

  # A definition's keyword options and do-block, as one keyword list (the
  # block form has them as two lists, the keyword form as one).
  defp options(lists), do: Enum.concat(lists)

  # `for:` absent is the enclosing module (`:enclosing`); a list (Sourceror
  # wraps it in a one-element block) is one target each.
  defp impl_targets(opts) do
    case keyword(opts, :for) do
      nil -> [:enclosing]
      {:__block__, _meta, [targets]} when is_list(targets) -> targets
      target -> [target]
    end
  end

  defp impl_name(protocol, :enclosing, parent), do: concat(literal_name(protocol, parent), parent)

  defp impl_name(protocol, target, parent),
    do: concat(literal_name(protocol, parent), literal_name(target, parent))

  defp concat(nil, _right), do: nil
  defp concat(_left, nil), do: nil
  defp concat(left, right), do: Module.concat(left, right)

  defp nested_name({:__aliases__, _meta, [:"Elixir" | parts]}, _parent), do: Module.concat(parts)

  defp nested_name({:__aliases__, _meta, [{:__MODULE__, _m, _c} | parts]}, parent),
    do: Module.concat([parent | parts])

  defp nested_name({:__aliases__, _meta, parts}, parent) do
    if Enum.all?(parts, &is_atom/1), do: Module.concat([parent | parts]), else: nil
  end

  defp nested_name({:__block__, _meta, [name]}, _parent) when is_atom(name), do: name
  defp nested_name(_built, _parent), do: nil

  defp literal_name({:__aliases__, _meta, [:"Elixir" | parts]}, _parent), do: Module.concat(parts)

  defp literal_name({:__aliases__, _meta, [{:__MODULE__, _m, _c} | parts]}, parent),
    do: Module.concat([parent | parts])

  defp literal_name({:__aliases__, _meta, parts}, _parent) do
    if Enum.all?(parts, &is_atom/1), do: Module.concat(parts), else: nil
  end

  defp literal_name({:__MODULE__, _meta, context}, parent) when is_atom(context), do: parent
  defp literal_name({:__block__, _meta, [name]}, _parent) when is_atom(name), do: name
  defp literal_name(_built, _parent), do: nil

  defp split_head({:when, _meta, [call, guard]}), do: {call, [guard]}
  defp split_head(call), do: {call, []}
end
