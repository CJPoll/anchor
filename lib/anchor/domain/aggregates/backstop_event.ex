defmodule Anchor.Domain.Aggregates.BackstopEvent do
  @moduledoc """
  One write a watched test made, as the backstop records it (DND-5480) —
  **Domain** data.

    * `pid` — the process that emitted the query event;
    * `test_pid` — the watched test it belongs to: `pid` itself, or the first
      watched pid in `pid`'s `$callers`;
    * `table` — the event's `source`, `nil` for raw SQL;
    * `kind` — `:insert`, `:update`, `:delete`, or `:unknown` for a statement
      `Anchor.Domain.Aggregates.QueryStatement` could not read as a read;
    * `tx` — `{:in_tx, ref}` when `pid` had a transaction open
      (`Anchor.Adapters.TransactionProbe`), else `:no_tx`;
    * `emitted_by` — `:test` when `pid` is the test, `:other` when it is a
      process the test started or called.

  Table names, kinds and pids only: never a parameter or a row value.
  """

  @enforce_keys [:pid, :test_pid, :table, :kind, :tx, :emitted_by]
  defstruct @enforce_keys

  @type tx :: {:in_tx, reference()} | :no_tx
  @type t :: %__MODULE__{
          pid: pid(),
          test_pid: pid(),
          table: String.t() | nil,
          kind: :insert | :update | :delete | :unknown,
          tx: tx(),
          emitted_by: :test | :other
        }

  @doc "An event from its fields (every field of the moduledoc, required)."
  @spec new(%{
          pid: pid(),
          test_pid: pid(),
          table: String.t() | nil,
          kind: :insert | :update | :delete | :unknown,
          tx: tx(),
          emitted_by: :test | :other
        }) :: t()
  def new(%{} = fields), do: struct!(__MODULE__, fields)
end
