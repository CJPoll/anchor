defmodule Anchor.Managers.Sabotage.CoverageCompare do
  @moduledoc """
  The flow of `mix anchor.sabotage coverage-compare` (DND-5692), part of the
  **Manager** `Anchor.Managers.Sabotage` (ADR 001). It reads each build's map through
  `Anchor.Adapters.CoverageStore` (option `:coverage_store`, default
  `Anchor.Adapters.CoverageFile`), and `Anchor.Domain.Sabotage.CoverageCompare` gives
  the verdict. It returns `{exit_code, lines}` and prints nothing.
  """

  alias Anchor.Adapters.CoverageFile
  alias Anchor.Domain.Sabotage.CoverageCompare

  @type facts :: %{first: String.t(), second: String.t()}

  @spec run(facts(), keyword()) :: {non_neg_integer(), [String.t()]}
  def run(facts, opts) do
    verdict = verdict(facts, Keyword.get(opts, :coverage_store, CoverageFile))

    {CoverageCompare.exit_code(verdict), CoverageCompare.lines(verdict, facts)}
  end

  # A file always equals itself, so one given twice proves nothing and is never read.
  defp verdict(facts, store) do
    if Path.expand(facts.first) == Path.expand(facts.second),
      do: {:could_not_measure, [:same_file]},
      else: CoverageCompare.judge(store.read(facts.first), store.read(facts.second))
  end
end
