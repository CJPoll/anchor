defmodule Anchor.Domain.Graph.Call do
  @moduledoc """
  A call edge of the causal graph — **Domain** data (DND-5438).

    * `:from` — the calling function, `{module, name, arity}`.
    * `:to` — the callee `{module, name, arity}`, or
      `{:dynamic, name | nil, arity | nil, receiver}` when Core does not name
      it: `receiver` is `:variable` (a module or fun held in a variable) or
      `:call` (a module computed by an expression, or `apply/2,3`). A call
      through a module attribute is a plain remote call: in Core the attribute
      is already a literal.
    * `:kind` — `:remote` (a call with a literal module), `:local` (a call to a
      function of the same module), `:capture` (`&M.f/a` or `&f/a`), `:apply`
      (`apply/2,3`, `fun.(x)`).
    * `:line` — the source line; `:line_source` is `:call` when it came from the
      call's own Core annotation and `:def` when Core carried none and the
      function's def line stands in.
  """

  @enforce_keys [:from, :to, :kind, :line, :line_source]
  defstruct [:from, :to, :kind, :line, :line_source]

  @type receiver :: :variable | :call
  @type target :: mfa() | {:dynamic, atom() | nil, arity() | nil, receiver()}

  @type t :: %__MODULE__{
          from: mfa(),
          to: target(),
          kind: :remote | :local | :capture | :apply,
          line: non_neg_integer() | nil,
          line_source: :call | :def
        }
end
