defmodule Anchor.Adapters.EctoTransactionProbe do
  @moduledoc """
  The transaction-boundary signal DND-5479 found — a **Side Effect** adapter
  (port `Anchor.Adapters.TransactionProbe`, DND-5480).

  Ecto emits a `"begin"` query event when the outermost `Repo.transaction`
  opens, and `"commit"` or `"rollback"` when it closes, in the process that
  runs it; a nested transaction emits none, and the queries between are that
  process's. So the open transaction is per process: `observe(:begin)` opens
  a new one (a fresh ref in the emitting process's dictionary),
  `observe(:commit)` and `observe(:rollback)` close it, and any other
  statement is in whatever is open. A rolled-back transaction is still
  judged: it attempted the writes.

  Not used, by design: `telemetry_options` on `Repo.transaction` (they reach
  `begin` and `commit` only, not the writes between) and
  `Repo.in_transaction?/0` (true inside the SQL sandbox's own transaction).
  """

  @behaviour Anchor.Adapters.TransactionProbe

  @key {__MODULE__, :tx}

  @doc "The transaction open in this process after `statement`; see the moduledoc."
  @impl Anchor.Adapters.TransactionProbe
  def observe(:begin) do
    ref = make_ref()
    Process.put(@key, ref)
    {:in_tx, ref}
  end

  def observe(boundary) when boundary in [:commit, :rollback] do
    Process.delete(@key)
    :no_tx
  end

  def observe(_statement) do
    case Process.get(@key) do
      nil -> :no_tx
      ref -> {:in_tx, ref}
    end
  end
end
