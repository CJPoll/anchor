defmodule Anchor.Domain.DataFlow.Region do
  @moduledoc """
  A single-exit region of one block (DND-5439): a contiguous run of the
  block's expressions whose values leave the run through at most one exit.
  Pure **Domain** data, built by `Anchor.Domain.DataFlow.regions/1`.

  ## Fields

    * `:block` — the id of the block the run sits in.
    * `:nodes` — the run's node ids, in order (nested sub-block nodes are part
      of the node that holds them and are not listed).
    * `:inputs` — the variable keys the run reads that are bound outside it,
      sorted.
    * `:output` — `{:var, key}` when exactly one variable bound in the run is
      read after it; `:block_value` when the run ends its block and no
      variable escapes (the block's value is the exit); `:none` when the run
      neither ends its block nor lets a variable escape (it only computes or
      performs effects).
    * `:lines` — `first..last` over the lines the run's nodes carry, or `nil`
      when none carries one.
  """

  @enforce_keys [:block, :nodes, :inputs, :output]
  defstruct [:block, :nodes, :inputs, :output, :lines]

  @type output :: {:var, Anchor.Domain.DataFlow.Scope.var_key()} | :block_value | :none

  @type t :: %__MODULE__{
          block: Anchor.Domain.DataFlow.Node.id(),
          nodes: [Anchor.Domain.DataFlow.Node.id()],
          inputs: [Anchor.Domain.DataFlow.Scope.var_key()],
          output: output(),
          lines: Range.t() | nil
        }
end
