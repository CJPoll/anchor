defmodule Anchor.Domain.Aggregates.WriteSite do
  @moduledoc """
  One database write found in compiled code (DND-5459) — **Domain** data
  (ADR 001). `Anchor.Domain.Aggregates.WriteSites.find/2` finds them and
  `Anchor.Domain.Aggregates.WriteSource.resolve/3` fills in what each writes.

    * `mfa` — the function the write is written in.
    * `line` — the write's source line (the function's def line when Core
      carries none).
    * `op` — the write's name: `:insert`, `:insert!`, `:update`, ...,
      `:delete_all`, or the configured write function's name.
    * `via` — how it was found: `:repo` (a call on a repo module), `:multi`
      (an `Ecto.Multi` step), `:write_function` (an `aggregates.write_functions`
      entry) or `:run_callback_repo` (a call on the repo argument of a
      `Multi.run` callback).
    * `sources` — what it writes, `{:schema, module}` or `{:table, name}`,
      sorted; more than one when branches differ. `[]` when unresolved.
    * `unresolved` — `nil` when every source resolved, else what was seen
      (`"parameter 1 of App.X.save/1 has no @spec and no project caller"`).
      It never names a line, so a baseline key built from it does not move.
    * `scopes` — the ordinals of the transaction scopes of `mfa` whose body
      holds it (`[]` outside every scope of its own function; a scope of a
      caller reaches it through the call).
  """

  @enforce_keys [:mfa, :line, :op, :via]
  defstruct [:mfa, :line, :op, :via, sources: [], unresolved: nil, scopes: []]

  @type source :: {:schema, module()} | {:table, String.t()}
  @type via :: :repo | :multi | :write_function | :run_callback_repo

  @type t :: %__MODULE__{
          mfa: mfa(),
          line: non_neg_integer() | nil,
          op: atom(),
          via: via(),
          sources: [source()],
          unresolved: String.t() | nil,
          scopes: [pos_integer()]
        }

  @doc "Whether every source of `site` resolved."
  @spec resolved?(t()) :: boolean()
  def resolved?(%__MODULE__{unresolved: nil}), do: true
  def resolved?(%__MODULE__{}), do: false
end
