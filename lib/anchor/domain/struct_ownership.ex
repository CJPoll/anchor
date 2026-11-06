defmodule Anchor.Domain.StructOwnership do
  @moduledoc """
  Which structs a struct-ownership rule checks — **Domain** (ADR 001), pure.
  Shared by the AST rule `struct_owned_by_module` (DND-5453) and the graph
  rule `struct_owned_by_module_flow` (DND-5454), so the two never disagree on
  which structs are in scope.

  `owned_namespaces` (exact module names, parsed to atoms by the config)
  limits a rule to structs equal to or nested under an entry: `MyApp` covers
  `MyApp` and `MyApp.Turn`, never `MyAppWeb`. Absent (or `nil`), every struct
  is in scope (`:all`).
  """

  @typedoc "The structs a rule checks: every one, or those under these namespaces."
  @type owned :: :all | [module()]

  @doc "The namespaces `rule` checks: its `:owned_namespaces`, or `:all` when absent or empty."
  @spec owned_namespaces(map()) :: owned()
  def owned_namespaces(rule) do
    case Map.get(rule, :owned_namespaces) do
      namespaces when is_list(namespaces) and namespaces != [] -> namespaces
      _absent -> :all
    end
  end

  @doc "Whether `module` is equal to or nested under one of `owned` (always, for `:all`)."
  @spec in_scope?(module(), owned()) :: boolean()
  def in_scope?(_module, :all), do: true

  def in_scope?(module, namespaces) when is_list(namespaces) do
    name = Atom.to_string(module)

    Enum.any?(namespaces, fn namespace ->
      prefix = Atom.to_string(namespace)
      name == prefix or String.starts_with?(name, prefix <> ".")
    end)
  end
end
