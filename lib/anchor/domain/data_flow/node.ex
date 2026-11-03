defmodule Anchor.Domain.DataFlow.Node do
  @moduledoc """
  One expression of one block in a clause analysed by `Anchor.Domain.DataFlow`
  (DND-5439). Pure **Domain** data.

  ## Fields

    * `:id` — the node's path: `[2]` is the third expression of the clause
      body, `[2, :clause, 1, 0]` the first expression of that node's second
      clause, `[2, :after, 0]` the first expression of a `try`'s `after` block.
    * `:ast` — the expression, with every `|>` already read as the call it
      desugars to.
    * `:line` — the smallest source line anywhere in the expression (a
      multi-line pipeline starts on its first stage), or `nil` for a bare
      literal (which carries no metadata).
    * `:block` — the id of the block the node sits in (`[]` is the clause body).
    * `:parent` — the id of the enclosing `:branch`, `:fn` or `:for` node, or
      `nil` at the clause body.
    * `:binds` — the variable keys the node binds that stay visible after it,
      in the order bound. Keys bound only inside the node (a clause pattern, a
      `fn` argument) are in `DataFlow.defs` pointing at this node, not here.
    * `:uses` — every variable key the node reads, its own sub-blocks
      excluded: the operands of an expression, or a branch's scrutinee,
      conditions, clause guards, pins and `with`/`for` steps.
    * `:kind` — `:expr`, `:bind` (a top-level `=`), `:branch` (`case`, `cond`,
      `if`, `unless`, `with`, `receive`, `try`), `:fn` or `:for`.
    * `:unsliceable` — `nil`, or the reason the node's flow cannot be followed
      inside the clause: `:receive`, `:process_dictionary`, `:var_bang` or
      `:binding`.
    * `:refutable` — whether the node can raise on a value: it holds a `=`
      whose pattern can fail (`true = ok?(x)`, `{:ok, _} = f()`,
      `{a, b} = pair`), a `case` with no catch-all clause, or a `with` step
      written with a refutable `=` (DND-5471; see `DataFlow.Forms`). Such a
      node asserts a shape, so `DataFlow.sinks/2` always includes it, with
      the reason `:refutable`.
  """

  @enforce_keys [:id, :ast, :block]
  defstruct [
    :id,
    :ast,
    :line,
    :block,
    :parent,
    binds: [],
    uses: [],
    kind: :expr,
    unsliceable: nil,
    refutable: false
  ]

  @type id :: [non_neg_integer() | atom()]
  @type kind :: :expr | :bind | :branch | :fn | :for
  @type unsliceable :: nil | :receive | :process_dictionary | :var_bang | :binding

  @type t :: %__MODULE__{
          id: id(),
          ast: Macro.t(),
          line: pos_integer() | nil,
          block: id(),
          parent: id() | nil,
          binds: [Anchor.Domain.DataFlow.Scope.var_key()],
          uses: [Anchor.Domain.DataFlow.Scope.var_key()],
          kind: kind(),
          unsliceable: unsliceable(),
          refutable: boolean()
        }
end
