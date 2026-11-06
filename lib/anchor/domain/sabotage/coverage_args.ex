defmodule Anchor.Domain.Sabotage.CoverageArgs do
  @moduledoc """
  What `mix anchor.sabotage coverage` hands to `mix test` (DND-5691). Pure
  **Domain**. The map is of the whole suite, so a test argument that chooses
  files is refused: a path, and `--failed`, `--stale` or `--partitions`. Filters
  (`--only`, `--exclude`, `--include`, `--name-pattern`) still pass through, and every test they
  filter out is still counted.

  An argument this cannot place (an unknown switch's value included) reads as a
  path: refused, never handed on to narrow the run unseen.
  """

  @takes_a_value ~w(--exclude --export-coverage --exit-status --formatter --include --max-failures
                    --max-requires --name-pattern --only --profile-require --repeat-until-failure
                    --seed --slowest --slowest-modules --timeout -n)
  @chooses_files ~w(--failed --stale --partitions)

  @doc "The first argument that chooses files, or nil when there is none."
  @spec chooses_files([String.t()]) :: String.t() | nil
  def chooses_files([]), do: nil

  def chooses_files([arg | rest]) do
    switch = arg |> String.split("=", parts: 2) |> hd()

    cond do
      switch in @chooses_files -> arg
      not String.starts_with?(arg, "-") -> arg
      arg in @takes_a_value -> rest |> Enum.drop(1) |> chooses_files()
      true -> chooses_files(rest)
    end
  end
end
