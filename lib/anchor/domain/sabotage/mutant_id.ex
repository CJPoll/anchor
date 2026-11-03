defmodule Anchor.Domain.Sabotage.MutantId do
  @moduledoc """
  The stable id of a generated mutant (DND-5471). Pure **Domain**.

  The id is the first 12 lowercase hex characters of the sha256 of
  `"<inspect(module)>.<name>/<arity>|<operator>|<variant>|<target>|<occurrence>"`,
  where `target` is the mutated node's normalized text (metadata stripped) and
  `occurrence` counts the equal operator, variant and target before it in the
  same function. No line, column or path enters the hash: moving the function,
  or editing another one, keeps its ids.
  """

  @type input :: %{
          module: module(),
          name: atom(),
          arity: arity(),
          operator: atom(),
          variant: term(),
          target: String.t(),
          occurrence: non_neg_integer()
        }

  @spec compute(input()) :: String.t()
  def compute(%{
        module: module,
        name: name,
        arity: arity,
        operator: operator,
        variant: variant,
        target: target,
        occurrence: occurrence
      })
      when is_atom(module) and is_atom(name) and is_integer(arity) and is_atom(operator) and
             is_binary(target) and is_integer(occurrence) do
    "#{inspect(module)}.#{name}/#{arity}|#{operator}|#{variant}|#{target}|#{occurrence}"
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
    |> binary_part(0, 12)
  end
end
