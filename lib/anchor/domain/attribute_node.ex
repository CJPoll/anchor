defmodule Anchor.Domain.AttributeNode do
  @moduledoc """
  A module attribute's node, as an AST walker must read it — the **Domain**
  bucket (ADR 001).

  Setting an attribute is `{:@, meta, [{name, name_meta, [value]}]}` and
  reading one is `{:@, meta, [{name, name_meta, context}]}`. The inner node of
  a set has the shape of the call `name(value)`, so a walker that descends into
  it and matches a special form or directive by name reads `@use Other.Mod` as
  `use Other.Mod`, `@def Other.Mod` as a function definition and
  `@quote value` as a quote block. The attribute's name is never code; only its
  value is.

  `children/1` is the code under an attribute node: its value when it is set,
  nothing when it is read. `without_name/1` rebuilds the node over those
  children, for a `Macro.prewalk/3` callback, which walks the children of the
  node it returns.
  """

  @doc """
  The code under the attribute node `node`: `[value]` for `@name value`, `[]`
  for a read `@name`, and the node's own arguments for any other `@` node.
  """
  @spec children(Macro.t()) :: [Macro.t()]
  def children({:@, _meta, [{name, _name_meta, [value]}]}) when is_atom(name), do: [value]

  def children({:@, _meta, [{name, _name_meta, context}]})
      when is_atom(name) and is_atom(context),
      do: []

  def children({:@, _meta, args}) when is_list(args), do: args

  @doc """
  `node` with an attribute's name removed, `{:@, meta, children}`, so a
  `Macro.prewalk/3` callback that returns it walks the value and never the
  name. Any node that is not an attribute is returned unchanged.
  """
  @spec without_name(Macro.t()) :: Macro.t()
  def without_name({:@, meta, args} = node) when is_list(args), do: {:@, meta, children(node)}
  def without_name(node), do: node
end
