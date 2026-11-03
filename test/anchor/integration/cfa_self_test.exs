defmodule Anchor.Integration.CfaSelfTest do
  # Integration (ADR 002), no doubles (DND-5497 R7): the 0-CFA over Anchor's
  # own compiled beams, read by the real BeamReader, under the open-world
  # default seed, completes without hitting its bound, and accounts for
  # every apply site as resolved or any.
  #
  # Sabotage record: ../../sabotage_records/cfa-20261103-dnd_5497_zero_cfa.md
  use ExUnit.Case, async: true

  alias Anchor.Adapters.BeamReader
  alias Anchor.Domain.Cfa
  alias Anchor.Domain.Graph.Builder

  test "Anchor's own code: no bound hit, every site counted, and the sites are many" do
    graph = Builder.build(BeamReader.read_ebins([{:anchor, Mix.Project.compile_path()}]), %{})
    assert graph.unreadable == []
    assert Map.has_key?(graph.modules, Cfa)

    cfa = Cfa.analyze(graph, Cfa.default_seed(graph))

    refute cfa.bound_hit?
    assert cfa.counts.total == map_size(cfa.sites)

    # A known site: default_seed/1 hands Enum.filter and Map.new a literal fn
    # each, so each of its sites resolves to exactly one of its own lambdas.
    seed_sites = for {{{Cfa, :default_seed, 1}, _n}, result} <- cfa.sites, do: result
    assert length(seed_sites) == 2

    for {:ok, closures} <- seed_sites do
      assert [{{Cfa, :default_seed, 1}, _ordinal}] = MapSet.to_list(closures)
    end

    assert Enum.all?(seed_sites, &match?({:ok, _}, &1))
    # Positive control: Anchor passes hundreds of funs to Enum.
    assert cfa.counts.total > 100
  end
end
