defmodule Anchor.Domain.Sabotage.ChangedFunction do
  @moduledoc """
  One function a diff changed, a **Domain** value (ADR 001), from
  `Anchor.Domain.Sabotage.Scope.build/2`.

  Its identity is `{module, name, arity}`, never a line number, so it is stable
  when the file moves around it. `changed_lines` are the lines of its clauses
  the diff changed, sorted and unique, across every clause. A deletion inside
  the function (lines removed, none added) is recorded as the line that now
  follows the removed text.
  """

  @enforce_keys [:file, :module, :name, :arity, :kind, :changed_lines]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          file: String.t(),
          module: module(),
          name: atom(),
          arity: non_neg_integer(),
          kind: :def | :defp,
          changed_lines: [pos_integer()]
        }
end
