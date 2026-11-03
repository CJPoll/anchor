defmodule Anchor.Domain.Aggregates.Scope do
  @moduledoc """
  One transaction scope and its write set (DND-5459) — **Domain** data
  (ADR 001). `Anchor.Domain.Aggregates.Scopes.build/3` builds them.

    * `mfa` — the function the transaction is started in.
    * `ordinal` — its position among the scopes of `mfa`, from 1, in Core
      order. It does not move when lines do, so baseline keys use it.
    * `line` — the transaction call's line.
    * `kind` — `:fun` (a function or capture handed to the transaction),
      `:multi` (an `Ecto.Multi`) or `:transaction_function` (an
      `aggregates.transaction_functions` call).
    * `writes` — every write the scope reaches: those in its body and those of
      every project function it calls, transitively. Sorted, unique.
    * `keys` — the write keys of the resolved writes (`{:schema, module}` or
      `{:table, name}`, `Anchor.Domain.Aggregates.WriteSource.key/2`).
    * `complete?` — `false` when `gaps` is not empty.
    * `gaps` — why the write set may be incomplete:
      `{:dynamic_call, mfa, line}` (a call Anchor cannot resolve, in the
      function `mfa`) and `{:unresolved_write, site}`.
  """

  alias Anchor.Domain.Aggregates.WriteSite

  @enforce_keys [:mfa, :ordinal, :kind]
  defstruct [
    :mfa,
    :ordinal,
    :line,
    :kind,
    writes: [],
    keys: MapSet.new(),
    complete?: true,
    gaps: []
  ]

  @type key :: WriteSite.source()
  @type gap ::
          {:dynamic_call, mfa(), non_neg_integer() | nil} | {:unresolved_write, WriteSite.t()}

  @type t :: %__MODULE__{
          mfa: mfa(),
          ordinal: pos_integer(),
          line: non_neg_integer() | nil,
          kind: :fun | :multi | :transaction_function,
          writes: [WriteSite.t()],
          keys: MapSet.t(key()),
          complete?: boolean(),
          gaps: [gap()]
        }

  @doc "The scope's id: `{mfa, ordinal}`."
  @spec id(t()) :: {mfa(), pos_integer()}
  def id(%__MODULE__{mfa: mfa, ordinal: ordinal}), do: {mfa, ordinal}
end
