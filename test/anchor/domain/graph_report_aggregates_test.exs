defmodule Anchor.Domain.GraphReportAggregatesTest do
  # DND-5476: the declared aggregates' counts in a graph run's summary line
  # and JSON. Pure Domain, from hand-built counts.
  #
  # Sabotage record: ../../sabotage_records/aggregates-20261103-dnd_5476_aggregate_decls.md
  # DND-5459 (the writes counts): ../../sabotage_records/aggregates-20261103-dnd_5459_write_sets.md
  # Sabotage record: ../../sabotage_records/aggregates-20261106-dnd_5889_default_deny_walker.md
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

  test "the write analysis's counts are in the summary and the JSON" do
    writes = %{
      writes: 7,
      resolved: 5,
      unresolved: 2,
      scopes: 3,
      no_gap_noticed: 2,
      incomplete: 1,
      outside_gaps: 4,
      cleared: 9,
      unread_by_callee: %{"unread: call of Lib.save/1" => 2}
    }

    report = GraphReport.new([], [], Map.put(@counts, :writes, writes))

    assert GraphReport.summary(report) ==
             "anchor.graph: 12 modules in 2 apps, 3 rules, 0 violations (0 report-only, 0 " <>
               "baselined); writes: 7 read, 5 resolved, 2 unresolved; transactions: 3 read, 2 " <>
               "no gap noticed, 1 incomplete; 4 gaps with no transaction read around them; " <>
               "9 dependency calls cleared by the no-write list; not read: the modules under " <>
               "aggregates.no_write_modules, the built-in no-write list, an unknown value given to " <>
               "one of them and dependencies' own internals; see the README's What it does not " <>
               "read"

    assert JSON.decode!(GraphReport.render(report, :json))["writes"] == %{
             "writes" => 7,
             "resolved" => 5,
             "unresolved" => 2,
             "outside_gaps" => 4,
             "scopes" => 3,
             "no_gap_noticed" => 2,
             "incomplete" => 1,
             "cleared" => 9,
             "unread_by_callee" => %{"unread: call of Lib.save/1" => 2}
           }
  end

  test "positive control: no write analysis, the summary says nothing and the JSON is null" do
    report = GraphReport.new([], [], @counts)

    refute GraphReport.summary(report) =~ "writes"
    assert %{"writes" => nil} = JSON.decode!(GraphReport.render(report, :json))
  end
end
