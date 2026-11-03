defmodule Anchor.Domain.GraphReportAggregatesTest do
  # DND-5476: the declared aggregates' counts in a graph run's summary line
  # and JSON. Pure Domain, from hand-built counts.
  #
  # Sabotage record: ../../sabotage_records/aggregates-20261103-dnd_5476_aggregate_decls.md
  use ExUnit.Case, async: true

  alias Anchor.Domain.GraphReport

  @counts %{
    modules: 12,
    apps: 2,
    rules: 3,
    opaque: 0,
    no_core: 0,
    outside_root: 0,
    apply_sites: nil
  }

  test "declared aggregates and their unknown tables are in the summary and the JSON" do
    counts = Map.put(@counts, :aggregates, %{declared: 3, tables_unknown: 1})
    report = GraphReport.new([], [], counts)

    assert GraphReport.summary(report) ==
             "anchor.graph: 12 modules in 2 apps, 3 rules, 0 violations (0 report-only, 0 " <>
               "baselined); aggregates: 3 declared, 1 tables unknown"

    assert JSON.decode!(GraphReport.render(report, :json))["aggregates"] == %{
             "declared" => 3,
             "tables_unknown" => 1
           }
  end

  test "positive control: none declared, the summary says nothing and the JSON is null" do
    report = GraphReport.new([], [], @counts)

    refute GraphReport.summary(report) =~ "aggregates"
    assert %{"aggregates" => nil} = JSON.decode!(GraphReport.render(report, :json))
  end
end
