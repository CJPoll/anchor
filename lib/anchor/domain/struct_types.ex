defmodule Anchor.Domain.StructTypes do
  @moduledoc """
  What the typespecs read from beams say a struct field or a function's
  return is (DND-5454) — **Domain** (ADR 001), pure, over the graph's
  `ModuleNode.types` and `ModuleNode.specs` (never by loading a module).

    * **Fields.** A project struct `M` whose `@type t` / `@opaque t` is
      `%M{field: type, ...}` types each of its fields: `{M, field} => S` when
      the field's type names exactly one struct `S`.
    * **Returns.** A function whose every `@spec` clause returns the same
      struct `S`: `mfa => S`.

  A type names the struct `S` when it is `%S{...}`, or a named type (`t()`,
  `Mod.t()`, `state()`, ...) of a project module whose definition names `S`
  (followed through other named types); `nil | X` and `X | nil` name what
  `X` names, as an update raises on `nil` anyway. `S` must be a project
  struct (a module of the graph that defines one). Everything else names no
  struct: a union of two structs, `map()`, `term()`, a tuple, a type
  variable (`t` bound in a `when` clause), and any type the graph does not
  define (a stdlib or dependency type), so an unresolved type is unknown and
  never read as some other module's struct.
  """

  alias Anchor.Domain.Graph
  alias Anchor.Domain.Graph.ModuleNode

  @typedoc "The index: the struct each field and each function's return is."
  @type t :: %{fields: %{{module(), atom()} => module()}, returns: %{mfa() => module()}}

  @doc "The index of `graph`'s field types and spec returns."
  @spec index(Graph.t()) :: t()
  def index(%Graph{modules: modules}) do
    %{fields: fields(modules), returns: returns(modules)}
  end

  @doc "The struct the field `field` of the struct `struct` holds, or `nil`."
  @spec field(t(), module(), atom()) :: module() | nil
  def field(%{fields: fields}, struct, field), do: Map.get(fields, {struct, field})

  @doc "The struct `mfa` returns by every one of its specs, or `nil`."
  @spec return(t(), mfa()) :: module() | nil
  def return(%{returns: returns}, mfa), do: Map.get(returns, mfa)

  @doc """
  The one project struct the spec type `type`, written in `module`, names, or `nil`
  (the moduledoc's rule).
  """
  @spec struct_of(Macro.t(), module(), Graph.t()) :: module() | nil
  def struct_of(type, module, %Graph{modules: modules}), do: resolve(type, module, modules)

  defp fields(modules) do
    for {module, %ModuleNode{struct_fields: [_ | _]} = node} <- modules,
        {:ok, body} <- [own_t(node)],
        {:%, _meta, [^module, {:%{}, _mmeta, pairs}]} <- [body],
        {field, type} <- pairs,
        is_atom(field),
        struct = resolve(type, module, modules),
        into: %{},
        do: {{module, field}, struct}
  end

  defp own_t(%ModuleNode{types: types}) do
    case Map.get(types, {:t, 0}) do
      {kind, {:"::", _meta, [_head, body]}} when kind in [:type, :opaque] -> {:ok, body}
      _none -> :error
    end
  end

  defp returns(modules) do
    for {module, %ModuleNode{specs: specs}} <- modules,
        {{name, arity}, [_ | _] = clauses} <- specs,
        structs = Enum.map(clauses, &spec_return(&1, module, modules)),
        [struct] <- [Enum.uniq(structs)],
        struct != nil,
        into: %{},
        do: {{module, name, arity}, struct}
  end

  defp spec_return({:when, _meta, [spec, _bindings]}, module, modules),
    do: spec_return(spec, module, modules)

  defp spec_return({:"::", _meta, [_call, return]}, module, modules),
    do: resolve(return, module, modules)

  defp spec_return(_spec, _module, _modules), do: nil

  # The one struct `type` (written in `module`) names, or nil.
  defp resolve(type, module, modules), do: resolve(type, module, modules, MapSet.new())

  defp resolve(type, module, modules, seen) do
    case alternatives(type) |> Enum.reject(&(&1 == nil)) do
      [single] -> resolve_one(single, module, modules, seen)
      _none_or_many -> nil
    end
  end

  defp alternatives({:|, _meta, [left, right]}), do: alternatives(left) ++ alternatives(right)
  defp alternatives(type), do: [type]

  defp resolve_one({:%, _meta, [struct, _fields]}, _module, modules, _seen) when is_atom(struct),
    do: if(project_struct?(struct, modules), do: struct)

  # A local named type (`t()`, `state()`); a variable has `nil` args.
  defp resolve_one({name, _meta, []}, module, modules, seen) when is_atom(name),
    do: named(module, name, modules, seen)

  defp resolve_one({{:., _meta, [remote, name]}, _cmeta, []}, _module, modules, seen)
       when is_atom(remote) and is_atom(name),
       do: named(remote, name, modules, seen)

  defp resolve_one(_type, _module, _modules, _seen), do: nil

  defp named(module, name, modules, seen) do
    with false <- MapSet.member?(seen, {module, name}),
         %ModuleNode{types: types} <- Map.get(modules, module),
         {kind, {:"::", _meta, [_head, body]}} when kind in [:type, :typep, :opaque] <-
           Map.get(types, {name, 0}) do
      resolve(body, module, modules, MapSet.put(seen, {module, name}))
    else
      _unknown -> nil
    end
  end

  defp project_struct?(struct, modules) do
    match?(%ModuleNode{struct_fields: fields} when is_list(fields), Map.get(modules, struct))
  end
end
