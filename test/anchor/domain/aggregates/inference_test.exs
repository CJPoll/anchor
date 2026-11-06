defmodule Anchor.Domain.Aggregates.InferenceTest do
  # DND-5459: inferred aggregates are the components of the co-write
  # hypergraph; the proposal parses under Aggregates.Config.parse/1.
  #
  # Sabotage record: ../../../sabotage_records/aggregates-20261103-dnd_5459_write_sets.md
  # and ../../../sabotage_records/aggregates-20261106-dnd_5459_write_sets.md
  use ExUnit.Case, async: true

  import Anchor.Test.WriteFixtures

  alias Anchor.Domain.Aggregates.Analysis
  alias Anchor.Domain.Aggregates.Config
  alias Anchor.Domain.Aggregates.Inference
  alias Anchor.Domain.Aggregates.Scope
  alias Anchor.Domain.Aggregates.WriteSite

  defp scope(ordinal, keys, no_gap_noticed? \\ true) do
    %Scope{
      mfa: {App.Tx, :run, 0},
      ordinal: ordinal,
      kind: :fun,
      keys: MapSet.new(keys),
      no_gap_noticed?: no_gap_noticed?
    }
  end

  defp analysis(scopes, nontx_keys) do
    %Analysis{
      scopes: scopes,
      nontx: %{
        {App.Plain, :write, 0} => %{
          keys: MapSet.new(nontx_keys),
          sites: [],
          no_gap_noticed?: true,
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

    assert Inference.render_yaml(reversed) == Inference.render_yaml(f1())
  end

  test "F5: render_yaml parses under Aggregates.Config.parse/1 to the proposal" do
    analysis = analysis([scope(1, schema: App.S, table: "audit_log")], [])
    proposals = Inference.proposed_declarations(analysis)

    assert {:ok, yaml} = Inference.render_yaml(analysis)

    {:ok, %{"aggregates" => section}} = YamlElixir.read_from_string(yaml)
    assert {:ok, %Config{declare: declare}} = Config.parse(section)

    assert Enum.map(declare, &{&1.name, &1.schemas, &1.tables}) ==
             Enum.map(proposals, &{&1.name, &1.schemas, &1.tables})
  end

  # Critic round 3: an analysis exists only with a repo, and a repo persists,
  # so the analysis never proposes declare: none. Built through
  # Analysis.build/2, never a hand-built state it cannot produce.
  test "F5: a repo and a schema with no write is an error naming them, never declare: none" do
    ns = AnchorFixtures.InferenceTest
    s = Module.concat(ns, S)
    repo = Module.concat(ns, Repo)

    source =
      schema(s, "s") <>
        repo(repo) <>
        "defmodule #{inspect(Module.concat(ns, Reader))} do\n" <>
        "  def all, do: #{inspect(repo)}.all(#{inspect(s)})\nend\n"

    analysis = Analysis.build(graph!(source), %Config{repos: [repo]})
    refute analysis.no_repo?

    assert {:error, why} = Inference.render_yaml(analysis)
    assert why =~ "repo(s) #{inspect(repo)}"
    assert why =~ "1 schema(s)"
    assert why =~ "a repo means the project persists, so declare: none does not fit"
    refute why =~ "aggregates:"
  end

  # Code-review finding: "nothing resolved" must never render as "nothing
  # persists".
  test "F8: writes found but none resolved is an error, never declare: none" do
    unresolved = %{analysis([], []) | counts: %{counts() | writes: 2, unresolved: 2}}

    assert {:error, why} = Inference.render_yaml(unresolved)
    assert why =~ "2 write(s) found, 2 unresolved"
    assert why =~ "Fix: "
  end

  # Critic round 2: raw SQL and a write on a module held in a variable make no
  # write site, only a gap, so "no write site" is not "nothing persists".
  test "F8: a transaction with no write site, only a gap, is an error, never declare: none" do
    gap_only = %{
      analysis([%{scope(1, [], false) | gaps: [{:dynamic_call, {App.Tx, :run, 0}, 3}]}], [])
      | counts: %{counts() | scopes: 1, incomplete: 1}
    }

    assert {:error, why} = Inference.render_yaml(gap_only)
    assert why =~ "1 transaction(s)"
  end

  test "F8: a gap with no transaction read around it is an error, never declare: none" do
    outside = %{analysis([], []) | counts: %{counts() | outside_gaps: 1}}

    assert {:error, why} = Inference.render_yaml(outside)

    assert why =~
             "1 call(s) or write(s) Anchor cannot attribute with no transaction read around them"
  end

  test "F8: no repo is an error, never declare: none" do
    assert {:error, why} = Inference.render_yaml(%Analysis{no_repo?: true})
    assert why =~ "no Ecto repo"
    assert why =~ "write declare: none by hand"
  end

  test "a resolved write in no scope and no nontx entry is still a vertex" do
    site = %WriteSite{
      line: 5,
      mfa: {App.Wrap, :run, 0},
      op: :insert,
      via: :multi,
      sources: [{:schema, App.Z}]
    }

    analysis = %{analysis([], []) | sites: [site]}

    assert Inference.components(analysis) == [MapSet.new(schema: App.Z)]
  end

  test "every proposal says on its first line what it does not read" do
    read_note =
      "# not read: the modules under aggregates.no_write_modules, the built-in no-write list " <>
        "and dependencies' own internals; a write there is not in this proposal\n"

    healthy = %{analysis([scope(1, [{:schema, App.S}])], []) | repos: [App.Repo]}
    assert {:ok, yaml} = Inference.render_yaml(healthy)
    assert String.starts_with?(yaml, read_note)

    unresolved = %{healthy | counts: %{counts() | writes: 3, unresolved: 1}}
    assert {:ok, yaml} = Inference.render_yaml(unresolved)
    assert String.starts_with?(yaml, read_note)
  end

  test "F8: a proposal beside an incomplete transaction says so in the YAML" do
    some = %{
      analysis([scope(1, schema: App.S)], [])
      | counts: %{counts() | scopes: 2, incomplete: 1}
    }

    assert {:ok, yaml} = Inference.render_yaml(some)
    assert yaml =~ "# 1 of 2 transaction(s) incomplete: this proposal may miss tables"
  end

  test "F8: a proposal with unresolved writes beside it says so in the YAML" do
    some = %{
      analysis([scope(1, schema: App.S)], [])
      | counts: %{counts() | writes: 3, unresolved: 1}
    }

    assert {:ok, yaml} = Inference.render_yaml(some)
    assert yaml =~ "# 1 of 3 write(s) unresolved: this proposal may miss tables"
    {:ok, %{"aggregates" => section}} = YamlElixir.read_from_string(yaml)
    assert {:ok, %Config{declare: [_one]}} = Config.parse(section)
  end

  defp counts, do: %Analysis{}.counts

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
