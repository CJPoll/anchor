defmodule Anchor.Adapters.TransactionProbe do
  @moduledoc """
  Behaviour for telling which transaction a query event belongs to — the
  **Side Effect** port (ADR 001) the backstop's recorder depends on (DND-5480).

  The recorder hands every statement an attributed process emits
  (`Anchor.Domain.Aggregates.QueryStatement.t()`) to `observe/1`, in the
  emitting process, in order. The probe answers the transaction open in that
  process after the statement: `{:in_tx, ref}` (one `ref` per transaction)
  or `:no_tx`. Which signal marks a transaction is the implementation's;
  DND-5479 found Ecto's `begin`/`commit`/`rollback` events
  (`Anchor.Adapters.EctoTransactionProbe`).
  """

  alias Anchor.Domain.Aggregates.QueryStatement

  @callback observe(QueryStatement.t()) :: {:in_tx, reference()} | :no_tx
end
