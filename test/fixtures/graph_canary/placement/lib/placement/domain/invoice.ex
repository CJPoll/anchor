# Compliant: an owner holds its own functions, however long one of them is.
defmodule AnchorFixtures.PlacementTest.Billing.Domain.Invoice do
  alias AnchorFixtures.PlacementTest.Billing.Domain.Invoice.Line

  defstruct lines: [], ends_at: 0

  @type t :: %__MODULE__{lines: [Line.t()], ends_at: integer()}

  @spec add(t(), Line.t()) :: t()
  def add(%__MODULE__{} = invoice, %Line{} = line),
    do: %__MODULE__{invoice | lines: [line | invoice.lines]}

  @spec total(t()) :: integer()
  def total(%__MODULE__{lines: lines}), do: lines |> Enum.map(& &1.cents) |> Enum.sum()

  # Length never triggers anything: a long, well-placed function has no proposal.
  @spec summary(t()) :: String.t()
  def summary(%__MODULE__{} = invoice) do
    count = length(invoice.lines)
    total = total(invoice)
    average = if count == 0, do: 0, else: div(total, count)
    largest = invoice.lines |> Enum.map(& &1.cents) |> Enum.max(fn -> 0 end)
    smallest = invoice.lines |> Enum.map(& &1.cents) |> Enum.min(fn -> 0 end)
    spread = largest - smallest
    first = "lines: #{count}"
    second = "total: #{total}"
    third = "average: #{average}"
    fourth = "largest: #{largest}"
    fifth = "smallest: #{smallest}"
    sixth = "spread: #{spread}"
    Enum.join([first, second, third, fourth, fifth, sixth], ", ")
  end
end
