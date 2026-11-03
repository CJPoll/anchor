defmodule Anchor.Domain.Aggregates.InferenceTest do
  # DND-5459: inferred aggregates are the components of the co-write
  # hypergraph; the proposal parses under Aggregates.Config.parse/1.
  #
  # Sabotage record: ../../../sabotage_records/aggregates-20261103-dnd_5459_write_sets.md
  use ExUnit.Case, async: true

  alias Anchor.Domain.Aggregates.Analysis
  alias Anchor.Domain.Aggregates.Config
  alias Anchor.Domain.Aggregates.Inference
  alias Anchor.Domain.Aggregates.Scope

  defp scope(ordinal, keys, complete? \\ true) do
    %Scope{
      mfa: {App.Tx, :run, 0},
      ordinal: ordinal,
      kind: :fun,
      keys: MapSet.new(keys),
      complete?: complete?
    }
  end

  defp analysis(scopes, nontx_keys) do
    %Analysis{
      scopes: scopes,
      nontx: %{
        {App.Plain, :write, 0} => %{
          keys: MapSet.new(nontx_keys),
          sites: [],
          complete?: true,
          gaps: []
        }
      }
    }
  end

  defp f1 do
    analysis(
      [
        scope(1, schema: App.S, schema: App.T),
        scope(2, schema: App.T, schema: App.U),
        scope(3, schema: App.V)
      ],
      schema: App.W
    )
  end

  test "F1: components of the co-write hypergraph" do
    assert Inference.components(f1()) == [
             MapSet.new(schema: App.S, schema: App.T, schema: App.U),
             MapSet.new(schema: App.V),
             MapSet.new(schema: App.W)
           ]
  end

  test "F2: an incomplete scope's resolved keys join one component" do
    analysis = analysis([scope(1, [schema: App.S, schema: App.X], false)], [])
    assert Inference.components(analysis) == [MapSet.new(schema: App.S, schema: App.X)]
  end

  test "F3: the root is the key in the most complete scopes, and names the proposal" do
    assert [%{name: "App.T", root: {:schema, App.T}}, %{name: "App.V"}, %{name: "App.W"}] =
             Inference.proposed_declarations(f1())
  end

  test "F3: the proposal names the root schema, its schemas and evidence" do
    [stu | _rest] = Inference.proposed_declarations(f1())

    assert stu.name == "App.T"
    assert stu.schemas == [App.S, App.T, App.U]
    assert stu.tables == []
    assert stu.evidence.scopes == [{{App.Tx, :run, 0}, 1}, {{App.Tx, :run, 0}, 2}]
  end

  test "F4: reversed input gives identical output" do
    reversed = %{f1() | scopes: Enum.reverse(f1().scopes)}
    assert Inference.proposed_declarations(reversed) == Inference.proposed_declarations(f1())

    assert Inference.render_yaml(Inference.proposed_declarations(reversed)) ==
             Inference.render_yaml(Inference.proposed_declarations(f1()))
  end

  test "F5: render_yaml parses under Aggregates.Config.parse/1 to the proposal" do
    proposals =
      Inference.proposed_declarations(analysis([scope(1, schema: App.S, table: "audit_log")], []))

    yaml = Inference.render_yaml(proposals)

    {:ok, %{"aggregates" => section}} = YamlElixir.read_from_string(yaml)
    assert {:ok, %Config{declare: declare}} = Config.parse(section)

    assert Enum.map(declare, &{&1.name, &1.schemas, &1.tables}) ==
             Enum.map(proposals, &{&1.name, &1.schemas, &1.tables})
  end

  test "F5: nothing written renders an empty declare, which parses" do
    yaml = Inference.render_yaml([])
    {:ok, %{"aggregates" => section}} = YamlElixir.read_from_string(yaml)
    assert {:ok, %Config{declare: []}} = Config.parse(section)
  end

  test "F7: a scope with no resolved key adds no edge and does not crash" do
    analysis = analysis([scope(1, [], false), scope(2, schema: App.S)], [])

    assert Inference.components(analysis) == [MapSet.new(schema: App.S)]
    assert [%{name: "App.S"}] = Inference.proposed_declarations(analysis)
  end

  test "F6: a table-only component is named by the camelized table" do
    assert [%{name: "AuditLog", tables: ["audit_log"], schemas: []}] =
             Inference.proposed_declarations(analysis([], table: "audit_log"))
  end
end
