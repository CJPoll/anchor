defmodule Anchor.Domain.Sabotage.FunctionSpans do
  @moduledoc """
  Finds the line span of every function clause in a source file, a **Domain**
  module (ADR 001). Pure: it parses the source text it is given and runs none of
  it.

  `spans/2` returns `{:ok, [%Anchor.Domain.Sabotage.Span{}]}` ordered by first
  line, or `{:error, {line, reason}}` when the source does not parse.

  How a span is read from the source AST
  (`Code.string_to_quoted/2` with `token_metadata: true`):

    * **Module.** A stack of `defmodule`s: a nested `defmodule B` inside `A` is
      `A.B`, `defmodule Elixir.C` is `C`, and `defprotocol` names a module the
      same way. `defimpl P, for: T` is `P.T`, `for: [T, U]` gives a span per
      type, and without `for:` it is `P.<the enclosing module>`. Names are the literal spelling (aliases are not
      resolved: DND-1282).
    * **First line** is the `def` call's line.
    * **Last line** is the `end` of a do-block, else the `end_of_expression`
      line (a keyword `do:` body, a heredoc included), else the highest line in
      the clause.
    * **Arity** is the head's argument count; a default argument counts once.
    * **Excluded.** `defmacro`, `defmacrop`, `defguard`, `defguardp`, every
      def inside `quote`, and a def whose name the source builds with
      `unquote` are marked `excluded_macro`.
  """

  alias Anchor.Domain.Sabotage.Span

  @defs [:def, :defp, :defmacro, :defmacrop, :defguard, :defguardp]
  @macros [:defmacro, :defmacrop, :defguard, :defguardp]

  @doc """
  The spans of every function clause in `source`; `path` only names the file
  in parser messages.
  """
  @spec spans(String.t(), String.t()) ::
          {:ok, [Span.t()]} | {:error, {pos_integer() | nil, String.t()}}
  def spans(source, path) do
    case Code.string_to_quoted(source,
           columns: true,
           token_metadata: true,
           file: path,
           emit_warnings: false
         ) do
      {:ok, ast} ->
        {:ok,
         ast
         |> walk(%{module: nil, quoted: false}, [])
         |> Enum.reverse()
         |> Enum.sort_by(& &1.first)}

      {:error, {meta, message, token}} ->
        {:error, {error_line(meta), error_text(message, token)}}
    end
  end

  defp walk({:defmodule, _meta, [name, [do: body]]}, ctx, acc),
    do: walk(body, %{ctx | module: nested_name(name, ctx.module)}, acc)

  defp walk({:defprotocol, _meta, [name, [do: body]]}, ctx, acc),
    do: walk(body, %{ctx | module: nested_name(name, ctx.module)}, acc)

  defp walk({:defimpl, _meta, [protocol, [{:do, _body} | _rest] = opts]}, ctx, acc),
    do: walk_impl(protocol, opts, ctx, acc)

  defp walk({:defimpl, _meta, [protocol, opts]}, ctx, acc) when is_list(opts),
    do: walk_impl(protocol, opts, ctx, acc)

  defp walk({:defimpl, _meta, [protocol, opts, do_block]}, ctx, acc)
       when is_list(opts) and is_list(do_block),
       do: walk_impl(protocol, opts ++ do_block, ctx, acc)

  defp walk({kind, meta, [head | body]} = node, ctx, acc) when kind in @defs,
    do: walk(body, ctx, [span(kind, meta, head, node, ctx) | acc])

  defp walk({:quote, _meta, args}, ctx, acc) when is_list(args),
    do: walk(args, %{ctx | quoted: true}, acc)

  defp walk({call, _meta, args}, ctx, acc) when is_list(args),
    do: walk(args, ctx, walk(call, ctx, acc))

  defp walk({left, right}, ctx, acc), do: walk(right, ctx, walk(left, ctx, acc))
  defp walk(nodes, ctx, acc) when is_list(nodes), do: Enum.reduce(nodes, acc, &walk(&1, ctx, &2))
  defp walk(_leaf, _ctx, acc), do: acc

  # `for: [A, B]` defines one implementation module per type, each with the
  # same body.
  defp walk_impl(protocol, opts, ctx, acc) do
    body = Keyword.get(opts, :do)

    opts
    |> Keyword.get(:for)
    |> List.wrap()
    |> then(fn
      [] -> [nil]
      targets -> targets
    end)
    |> Enum.reduce(acc, &walk(body, %{ctx | module: impl_name(protocol, &1, ctx.module)}, &2))
  end

  defp span(kind, meta, head, node, ctx) do
    {name, arity} = name_and_arity(head)

    %Span{
      module: ctx.module,
      name: name,
      arity: arity,
      kind: kind,
      first: Keyword.fetch!(meta, :line),
      last: last_line(meta, node),
      excluded_macro: ctx.quoted or kind in @macros or is_nil(name)
    }
  end

  defp name_and_arity({:when, _meta, [call, _guard]}), do: name_and_arity(call)

  defp name_and_arity({name, _meta, args}) when is_atom(name) and is_list(args),
    do: {name, length(args)}

  defp name_and_arity({name, _meta, context}) when is_atom(name) and is_atom(context),
    do: {name, 0}

  defp name_and_arity({_built, _meta, args}) when is_list(args), do: {nil, length(args)}
  defp name_and_arity(_unknown), do: {nil, 0}

  defp last_line(meta, node) do
    end_line(meta[:end]) || end_line(meta[:end_of_expression]) ||
      max_line(node, Keyword.fetch!(meta, :line))
  end

  defp end_line(nil), do: nil
  defp end_line(position), do: Keyword.get(position, :line)

  defp max_line({_call, meta, args} = node, max) when is_list(meta) do
    line = if is_integer(meta[:line]), do: max(max, meta[:line]), else: max
    node |> elem(0) |> max_line(line) |> then(&max_line(args, &1))
  end

  defp max_line({left, right}, max), do: max_line(right, max_line(left, max))
  defp max_line(nodes, max) when is_list(nodes), do: Enum.reduce(nodes, max, &max_line/2)
  defp max_line(_leaf, max), do: max

  defp nested_name({:__aliases__, _meta, [:"Elixir" | parts]}, _parent), do: Module.concat(parts)

  defp nested_name({:__aliases__, _meta, [{:__MODULE__, _m, _c} | parts]}, parent),
    do: Module.concat([parent | parts])

  defp nested_name({:__aliases__, _meta, parts}, parent) do
    if Enum.all?(parts, &is_atom/1), do: Module.concat([parent | parts]), else: nil
  end

  defp nested_name(name, _parent) when is_atom(name), do: name
  defp nested_name(_built, _parent), do: nil

  defp impl_name(protocol, nil, parent), do: concat(literal_name(protocol, parent), parent)

  defp impl_name(protocol, target, parent),
    do: concat(literal_name(protocol, parent), literal_name(target, parent))

  defp concat(nil, _right), do: nil
  defp concat(_left, nil), do: nil
  defp concat(left, right), do: Module.concat(left, right)

  defp literal_name({:__aliases__, _meta, [:"Elixir" | parts]}, _parent), do: Module.concat(parts)

  defp literal_name({:__aliases__, _meta, [{:__MODULE__, _m, _c} | parts]}, parent),
    do: Module.concat([parent | parts])

  defp literal_name({:__aliases__, _meta, parts}, _parent) do
    if Enum.all?(parts, &is_atom/1), do: Module.concat(parts), else: nil
  end

  defp literal_name({:__MODULE__, _meta, context}, parent) when is_atom(context), do: parent
  defp literal_name(name, _parent) when is_atom(name), do: name
  defp literal_name(_built, _parent), do: nil

  defp error_line(meta) when is_list(meta), do: Keyword.get(meta, :line)
  defp error_line(line) when is_integer(line), do: line
  defp error_line(_unknown), do: nil

  defp error_text({prefix, suffix}, token), do: "#{prefix}#{suffix}#{token}"
  defp error_text(message, token), do: "#{message}#{token}"
end
