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
    * `writes` — the writes read in the scope: those in its body and those of
      the project functions it calls, transitively. Sorted, unique. A call it
      does not read adds no write here, and is in `gaps`.
    * `keys` — the write keys of the resolved writes (`{:schema, module}` or
      `{:table, name}`, `Anchor.Domain.Aggregates.WriteSource.key/2`).
    * `no_gap_noticed?` — `false` when `gaps` is not empty. `true` says only
      that Anchor noticed no gap, not that the write set is whole.
    * `gaps` — why the write set is incomplete:
      `{:dynamic_call, mfa, line}` (a call Anchor cannot resolve, in the
      function `mfa`), `{:unread, mfa, line, what}` (a call it does not read,
      `what` naming it: `unread: call of Lib.save/1`) and
      `{:unresolved_write, site}`.
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
    no_gap_noticed?: true,
    gaps: []
  ]

  @type key :: WriteSite.source()
  @type gap ::
          {:dynamic_call, mfa(), non_neg_integer() | nil}
          | {:unread, mfa(), non_neg_integer() | nil, String.t()}
          | {:unresolved_write, WriteSite.t()}

  @type t :: %__MODULE__{
          mfa: mfa(),
          ordinal: pos_integer(),
          line: non_neg_integer() | nil,
          kind: :fun | :multi | :transaction_function,
          writes: [WriteSite.t()],
          keys: MapSet.t(key()),
          no_gap_noticed?: boolean(),
          gaps: [gap()]
        }

  @doc "The scope's id: `{mfa, ordinal}`."
  @spec id(t()) :: {mfa(), pos_integer()}
  def id(%__MODULE__{mfa: mfa, ordinal: ordinal}), do: {mfa, ordinal}
end
