defmodule Anchor.Domain.Sabotage.Skipped do
  @moduledoc """
  A mutant the generator did not emit, with the reason (DND-5471). Pure
  **Domain** data. A mutant is skipped when it would not compile under
  `--warnings-as-errors` (it orphans a variable, or removes the last use of a
  private function, module attribute, alias or import), when the edit cannot
  be made by lines (the statement shares a line), or when it would change
  nothing. It is never counted as killed.

  `range` and `replacement` are the edit that was made and refused (so a
  reader can reproduce the compiler warning); both are `nil` when the edit
  could not be made at all (the statement shares a line, the pattern has
  nothing to relax, ...).
  """

  @enforce_keys [:file, :module, :function, :operator, :variant, :target, :reason]
  defstruct @enforce_keys ++ [range: nil, replacement: nil]

  @type t :: %__MODULE__{
          file: String.t(),
          module: module(),
          function: {atom(), arity()},
          operator: atom(),
          variant: nil | boolean() | non_neg_integer(),
          target: String.t(),
          reason: String.t(),
          range: Anchor.Domain.Sabotage.Patch.range() | nil,
          replacement: String.t() | nil
        }
end
