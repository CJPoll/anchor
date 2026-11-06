defmodule Anchor.Domain.Placement.FunctionFacts do
  @moduledoc """
  What the placement model knows about one function (DND-5448) — **Domain** data.

    * `mfa`, `kind` — the function, and `:def` or `:defp`;
    * `role` — the role its effects give it (`Anchor.Domain.Effects`), `nil` when
      it was not analysed;
    * `output_owner`, `input_owner` — the struct whose module owns it by its
      return value or by its input (`Anchor.Domain.Placement.Ownership`), or `nil`;
    * `idom` — its immediate dominator from the roots: an mfa, the virtual root, or
      `nil` when no root reaches it;
    * `reachable?` — a root reaches it;
    * `shared?` — its immediate dominator is the virtual root and it is no root: it
      is reached from unrelated places, so rules 2 to 4 propose no move for it;
    * `generated?` — macro or DSL output (or possibly so), so rules 2 to 4 and F5 do
      not judge it;
    * `callers` — the functions with an edge to it, sorted, itself left out;
    * `named?` — something names it so it must stay public: a dynamic call can
      reach it, or a literal `{M, :f, args}` names it.
  """

  @enforce_keys [:mfa, :kind]
  defstruct [
    :mfa,
    :kind,
    :role,
    :output_owner,
    :input_owner,
    :idom,
    reachable?: false,
    shared?: false,
    generated?: false,
    callers: [],
    named?: false
  ]

  @type t :: %__MODULE__{
          mfa: mfa(),
          kind: :def | :defp,
          role: Anchor.Domain.Effects.role() | nil,
          output_owner: module() | nil,
          input_owner: module() | nil,
          idom: mfa() | atom() | nil,
          reachable?: boolean(),
          shared?: boolean(),
          generated?: boolean(),
          callers: [mfa()],
          named?: boolean()
        }
end
