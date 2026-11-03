defmodule Anchor.Domain.Graph.FunctionNode do
  @moduledoc """
  A function of the causal graph — **Domain** data (DND-5438).

    * `:module`, `:name`, `:arity`, `:kind` (`:def`, `:defp`, `:defmacro`,
      `:defmacrop`) and `:line` (the def line) come from the `elixir_v1`
      definitions; a macro carries its source name and arity, not Core's
      `MACRO-name/arity+1`.
    * `:clauses` — the expanded `elixir_v1` clauses, `{meta, args, guards, body}`.
    * `:core` — the function's Core Erlang `c_fun`, or `nil` when the Core
      module holds no definition for it.
  """

  @enforce_keys [:module, :name, :arity, :kind, :line]
  defstruct [:module, :name, :arity, :kind, :line, :core, clauses: []]

  @type t :: %__MODULE__{
          module: module(),
          name: atom(),
          arity: arity(),
          kind: :def | :defp | :defmacro | :defmacrop,
          line: non_neg_integer() | nil,
          clauses: [tuple()],
          core: :cerl.cerl() | nil
        }
end
