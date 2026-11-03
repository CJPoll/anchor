defmodule Anchor.Domain.Sabotage.Span do
  @moduledoc """
  The source lines one `def`/`defp`/`defmacro`/`defmacrop` clause occupies, a
  **Domain** value (ADR 001), from `Anchor.Domain.Sabotage.FunctionSpans`.

    * `module`, `name`, `arity` name the function. A multi-clause function has
      one span per clause, all with the same identity. `name` is `nil` when the
      source builds it (`def unquote(name)()`), and such a span is always
      `excluded_macro`.
    * `kind` is the defining macro.
    * `first..last` are the clause's lines, both inclusive.
    * `excluded_macro` is true for a macro, a guard macro, and any function
      defined inside `quote`: generated sabotage does not mutate them.
  """

  @enforce_keys [:module, :name, :arity, :kind, :first, :last, :excluded_macro]
  defstruct @enforce_keys

  @type kind :: :def | :defp | :defmacro | :defmacrop | :defguard | :defguardp

  @type t :: %__MODULE__{
          module: module() | nil,
          name: atom() | nil,
          arity: non_neg_integer(),
          kind: kind(),
          first: pos_integer(),
          last: pos_integer(),
          excluded_macro: boolean()
        }
end
