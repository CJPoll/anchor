defmodule Anchor.Domain.Sabotage.Mutant do
  @moduledoc """
  One generated mutant of one function (DND-5471). Pure **Domain** data.

    * `id` — `Anchor.Domain.Sabotage.MutantId`, stable across line moves.
    * `file`, `module`, `function` (`{name, arity}`).
    * `operator` — one of the six operators; `variant` — `nil`, `true`/`false`
      for `force_condition`, or the parameter index for `return_input`.
    * `target` — the mutated node's normalized text (the id's input).
    * `range` — `{{line, column}, {line, column}}`, end exclusive, in the
      original source; `original` — the text of that range; `replacement` —
      the text that replaces it.
    * `patch` — a unified diff of the whole file
      (`Anchor.Domain.Sabotage.Patch.unified_diff/3`).
  """

  @enforce_keys [
    :id,
    :file,
    :module,
    :function,
    :operator,
    :variant,
    :target,
    :range,
    :original,
    :replacement,
    :patch
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          id: String.t(),
          file: String.t(),
          module: module(),
          function: {atom(), arity()},
          operator: atom(),
          variant: nil | boolean() | non_neg_integer(),
          target: String.t(),
          range: Anchor.Domain.Sabotage.Patch.range(),
          original: String.t(),
          replacement: String.t(),
          patch: String.t()
        }
end
