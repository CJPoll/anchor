defmodule Anchor.Integration.DemandSelfTest do
  # Integration (ADR 002), no doubles (DND-5498 R5-R6): the demand analysis
  # over Anchor's own compiled beams, read by the real BeamReader, with the
  # 0-CFA under the open-world default seed, completes without hitting its
  # round bound and accounts for every def/defp with Core.
  #
  # Sabotage record: ../../sabotage_records/demand-20261103-dnd_5498_demand.md
  use ExUnit.Case, async: true

  # The analysis of the whole of Anchor takes about a second; mutation runs
  # pass a short global --timeout (2000 ms) that a loaded machine overruns, so
  # this module keeps ExUnit's default bound.
  @moduletag timeout: 60_000

  alias Anchor.Adapters.BeamReader
  alias Anchor.Domain.Cfa
  alias Anchor.Domain.Demand
  alias Anchor.Domain.Demand.Lattice
  alias Anchor.Domain.Graph.Builder

  test "Anchor's own code: no bound hit, every function summarised, known demands" do
    graph = Builder.build(BeamReader.read_ebins([{:anchor, Mix.Project.compile_path()}]), %{})
    assert graph.unreadable == []

    demand = Demand.analyze(graph, Cfa.analyze(graph, Cfa.default_seed(graph)), [])

    assert demand.bound_hit == []
    assert demand.counts.functions == map_size(demand.summaries)

    assert demand.counts.parameters ==
             demand.summaries |> Map.values() |> List.flatten() |> length()

    # Known summaries: Lattice.at/2 reads both of its parameters; join/2 too.
    assert Demand.param(demand, {Lattice, :at, 2}, 0) == :all
    assert Demand.param(demand, {Lattice, :join, 2}, 1) == :all

    # Positive controls: Anchor has hundreds of functions, and some parameters
    # it never uses (an absent count of zero would mean the analysis judges
    # nothing).
    assert demand.counts.functions > 500
    assert demand.counts.absent > 0
  end
end
