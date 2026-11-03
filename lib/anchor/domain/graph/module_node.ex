defmodule Anchor.Domain.Graph.ModuleNode do
  @moduledoc """
  A module of the causal graph — **Domain** data (DND-5438).

    * `:module`, `:app`, `:source_file` (the `elixir_v1` `relative_file`).
    * `:line` — the line of the module's `defmodule` (the `elixir_v1`
      `:anno`), or `nil` when the metadata has none (DND-5440: an
      unclassified module is reported there).
    * `:behaviours` — every `@behaviour`, from the persisted attributes.
    * `:attributes` — the persisted attributes, a keyword list.
    * `:specs` — `%{{name, arity} => [quoted spec]}`.
    * `:types` — `%{{name, arity} => {kind, quoted type}}`, kind `:type`,
      `:typep` or `:opaque`.
    * `:struct_fields` — the struct's field names, or `nil` for no struct.
    * `:functions` — `%{{name, arity} => %FunctionNode{}}`.
    * `:generated?` — `true` when the module's source file has no literal
      `defmodule` naming it (macro or DSL output), `false` when it has, and
      `:unknown` when the source facts for the file are missing, the file
      did not parse, or the file has a `defmodule` whose name is not literal
      (which may be this module). `:unknown` is never read as hand-written.
      A module a DSL makes (a hand-written `defprotocol`, say) has no literal
      `defmodule`, so it is `true` by this definition.
  """

  @enforce_keys [:module, :app]
  defstruct [
    :module,
    :app,
    :source_file,
    :line,
    :struct_fields,
    behaviours: [],
    attributes: [],
    specs: %{},
    types: %{},
    functions: %{},
    generated?: :unknown
  ]

  @type t :: %__MODULE__{
          module: module(),
          app: atom(),
          source_file: String.t() | nil,
          line: pos_integer() | nil,
          behaviours: [module()],
          attributes: keyword(),
          specs: %{{atom(), arity()} => [Macro.t()]},
          types: %{{atom(), arity()} => {:type | :typep | :opaque, Macro.t()}},
          struct_fields: [atom()] | nil,
          functions: %{{atom(), arity()} => Anchor.Domain.Graph.FunctionNode.t()},
          generated?: boolean() | :unknown
        }
end
