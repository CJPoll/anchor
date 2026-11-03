defmodule Anchor.Domain.Graph.StructUse do
  @moduledoc """
  A struct-use edge of the causal graph — **Domain** data (DND-5438).

    * `:from` — the function the use is in, `{module, name, arity}`.
    * `:struct` — the struct's module.
    * `:op` — `:build` (`%S{...}`), `:update` (`%S{s | ...}`) or `:match`
      (`%S{}` in a pattern).
    * `:line`, `:line_source` — as in `Anchor.Domain.Graph.Call`.
  """

  @enforce_keys [:from, :struct, :op, :line, :line_source]
  defstruct [:from, :struct, :op, :line, :line_source]

  @type t :: %__MODULE__{
          from: mfa(),
          struct: module(),
          op: :build | :update | :match,
          line: non_neg_integer() | nil,
          line_source: :call | :def
        }
end
