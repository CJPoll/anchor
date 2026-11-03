defmodule Anchor.Domain.Aggregates.IndexTest do
  # DND-5476: the aggregate declaration index. Pure Domain, over hand-built
  # graphs; each `__schema__/1` body is the Core of a fixture compiled in the
  # test (`Anchor.Test.BeamFixtures`), so `table_of/2` reads real Core.
  #
  # Sabotage record: ../../../sabotage_records/aggregates-20261103-dnd_5476_aggregate_decls.md
  use ExUnit.Case, async: true

  import Anchor.Test.BeamFixtures

  alias Anchor.Domain.Aggregates.Config
  alias Anchor.Domain.Aggregates.Declaration
  alias Anchor.Domain.Aggregates.DeclarationIssue
  alias Anchor.Domain.Aggregates.Index
  alias Anchor.Domain.Graph
  alias Anchor.Domain.Graph.FunctionNode
  alias Anchor.Domain.Graph.ModuleNode

  @ns AnchorFixtures.Aggregates.IndexTest
  @s1 Module.concat(@ns, S1)
  @s2 Module.concat(@ns, S2)
  @s3 Module.concat(@ns, S3)
  @s4 Module.concat(@ns, S4)
  @dyn Module.concat(@ns, Dyn)
  @plain Module.concat(@ns, Plain)
  @store Module.concat(@ns, Store)
  @x Module.concat(@ns, X)

  @source """
  defmodule #{inspect(@s1)} do
    def __schema__(:prefix), do: nil
    def __schema__(:source), do: "s1"
    def __schema__(_), do: nil
  end

  defmodule #{inspect(@s2)} do
    def __schema__(:source), do: "s2"
    def __schema__(_), do: nil
  end

  defmodule #{inspect(@s3)} do
    def __schema__(:source), do: "s3"
    def __schema__(_), do: nil
  end

  defmodule #{inspect(@s4)} do
    def __schema__(:source), do: "s4"
    def __schema__(_), do: nil
  end

  defmodule #{inspect(@dyn)} do
    def __schema__(:source), do: System.get_env("T")
    def __schema__(_), do: nil
  end

  defmodule #{inspect(@plain)} do
    def other(x), do: x
  end
  """

  setup_all do
    modules = compile_unloaded(@source)

    cores =
      for {module, binary} <- modules,
          module != @plain,
          into: %{},
          do: {module, core_fun!(binary, {:__schema__, 1})}

    %{cores: cores}
  end

  # A graph of the given schema modules (their Core from the fixtures), plain
  # modules, and attribute-bearing modules (`{module, value}`).
  defp graph(cores, opts) do
    schemas =
      for module <- Keyword.get(opts, :schemas, []) do
        node(module, %{
          {:__schema__, 1} => %FunctionNode{
            module: module,
            name: :__schema__,
            arity: 1,
            kind: :def,
            line: 2,
            core: Map.fetch!(cores, module)
          }
        })
      end

    plain = for module <- Keyword.get(opts, :plain, []), do: node(module, %{})

    attributed =
      for {module, value} <- Keyword.get(opts, :attributes, []) do
        %{node(module, %{}) | attributes: [anchor_aggregate: value]}
      end

    %Graph{modules: Map.new(schemas ++ plain ++ attributed, &{&1.module, &1})}
  end

  defp node(module, functions) do
    %ModuleNode{
      module: module,
      app: :app,
      source_file: "lib/#{module |> Module.split() |> List.last() |> String.downcase()}.ex",
      line: 1,
      functions: functions,
      generated?: false
    }
  end

  defp config(declarations) do
    %Config{
      declare:
        for {name, fields} <- declarations do
          struct!(Declaration, [name: name, sites: [:config]] ++ fields)
        end
    }
  end

  describe "build/2" do
    test "I1: a config aggregate maps its schemas and their tables", %{cores: cores} do
      index =
        Index.build(config([{"A", schemas: [@s1, @s2]}]), graph(cores, schemas: [@s1, @s2]))

      assert Index.aggregate_of(index, @s1) == {:ok, "A"}
      assert Index.aggregate_of(index, "s2") == {:ok, "A"}
      assert Index.aggregate_of(index, @s3) == :error
      assert index.issues == []
      assert Index.declared(index) == 1
    end

    test "I2: a config and an attribute declaration of one name merge", %{cores: cores} do
      graph =
        graph(cores,
          schemas: [@s1, @s3],
          attributes: [{@store, [name: A, schemas: [@s3], owner: true]}]
        )

      index = Index.build(config([{"A", schemas: [@s1]}]), graph)

      assert %Declaration{schemas: schemas, sites: sites} = index.aggregates["A"]
      assert schemas == Enum.sort([@s1, @s3])
      assert Index.owners(index, "A") == [@store]
      assert sites == [:config, {:attribute, @store, "lib/store.ex", 1}]
      assert Index.aggregate_of(index, "s3") == {:ok, "A"}
      assert index.owners == %{@store => ["A"]}
      assert index.issues == []
    end

    test "I3: an owner: false attribute adds its schema and no owner", %{cores: cores} do
      graph = graph(cores, schemas: [@s1], attributes: [{@s4, [name: B, schemas: [@s4]]}])
      # S4 declares itself, so it needs its own schema body.
      graph = put_in(graph.modules[@s4].functions, schema_functions(cores, @s4))

      index = Index.build(nil, graph)

      assert Index.aggregate_of(index, @s4) == {:ok, "B"}
      assert Index.owners(index, "B") == []
      assert index.owners == %{}
      assert index.issues == []
    end

    test "I4: a schema in two aggregates is claimed twice at each site, deterministically",
         %{cores: cores} do
      graph = graph(cores, schemas: [@s1], attributes: [{@x, [name: B, schemas: [@s1]]}])
      index = Index.build(config([{"A", schemas: [@s1]}]), graph)

      assert [
               %DeclarationIssue{
                 kind: :claimed_twice,
                 subject: @s1,
                 aggregates: ["A", "B"],
                 site: :config
               },
               %DeclarationIssue{
                 kind: :claimed_twice,
                 subject: @s1,
                 aggregates: ["A", "B"],
                 site: {:attribute, @x, "lib/x.ex", 1}
               }
             ] = index.issues

      # Its table is not reported a second time.
      refute Enum.any?(index.issues, &(&1.subject == "s1"))
      assert Index.aggregate_of(index, @s1) == {:ok, "A"}
      assert Index.aggregate_of(index, "s1") == {:ok, "A"}

      # The same claims the other way round: B by config, A by attribute.
      reversed =
        Index.build(
          config([{"B", schemas: [@s1]}]),
          graph(cores, schemas: [@s1], attributes: [{@x, [name: A, schemas: [@s1]]}])
        )

      assert Index.aggregate_of(reversed, @s1) == {:ok, "A"}
      assert Enum.map(reversed.issues, & &1.aggregates) == [["A", "B"], ["A", "B"]]

      # Declaration order inside the config does not move the result either.
      both = config([{"B", schemas: [@s1]}, {"A", schemas: [@s1]}])
      forward = config([{"A", schemas: [@s1]}, {"B", schemas: [@s1]}])
      plain = graph(cores, schemas: [@s1])
      assert Index.build(both, plain) == Index.build(forward, plain)
    end

    test "I5: an explicit table and a schema's table in two aggregates is claimed twice",
         %{cores: cores} do
      index =
        Index.build(
          config([{"A", tables: ["s1"]}, {"B", schemas: [@s1]}]),
          graph(cores, schemas: [@s1])
        )

      # Both claims sit in .anchor.yml, one site: one issue there.
      assert [
               %DeclarationIssue{
                 kind: :claimed_twice,
                 subject: "s1",
                 aggregates: ["A", "B"],
                 site: :config
               }
             ] = index.issues

      # Across two sites, one issue at each.
      across =
        Index.build(
          config([{"A", tables: ["s1"]}]),
          graph(cores, schemas: [@s1], attributes: [{@x, [name: B, schemas: [@s1]]}])
        )

      assert [
               %DeclarationIssue{kind: :claimed_twice, subject: "s1", site: :config},
               %DeclarationIssue{
                 kind: :claimed_twice,
                 subject: "s1",
                 site: {:attribute, @x, _, _}
               }
             ] = across.issues

      assert Index.aggregate_of(index, "s1") == {:ok, "A"}
      assert Index.aggregate_of(index, @s1) == {:ok, "B"}
    end

    test "I6: a schema naming no project module is unknown_schema", %{cores: cores} do
      index = Index.build(config([{"A", schemas: [Nope]}]), graph(cores, schemas: [@s1]))

      assert [%DeclarationIssue{kind: :unknown_schema, subject: Nope, aggregates: ["A"]}] =
               index.issues
    end

    test "a schema naming a module the graph could not build is not also unknown",
         %{cores: cores} do
      graph = %{
        graph(cores, schemas: [@s1])
        | unreadable: [%{path: "x", module: Nope, reason: :r}]
      }

      assert Index.build(config([{"A", schemas: [Nope], owners: [Nope]}]), graph).issues == []
    end

    test "I7: a module with no __schema__/1 is not_a_schema", %{cores: cores} do
      index = Index.build(config([{"A", schemas: [@plain]}]), graph(cores, plain: [@plain]))
      assert [%DeclarationIssue{kind: :not_a_schema, subject: @plain}] = index.issues
    end

    test "I8: an owner naming no project module is unknown_owner", %{cores: cores} do
      index =
        Index.build(
          config([{"A", schemas: [@s1], owners: [Ghost]}]),
          graph(cores, schemas: [@s1])
        )

      assert [%DeclarationIssue{kind: :unknown_owner, subject: Ghost, aggregates: ["A"]}] =
               index.issues
    end

    test "I9: an aggregate with no schemas and no tables is empty_aggregate", %{cores: cores} do
      index = Index.build(config([{"A", []}]), graph(cores, schemas: [@s1]))

      assert [%DeclarationIssue{kind: :empty_aggregate, subject: "A", site: :config}] =
               index.issues
    end

    test "I12: positive control: I6-I9 with the names corrected find nothing", %{cores: cores} do
      graph = graph(cores, schemas: [@s1, @s2], plain: [@store])

      index =
        Index.build(
          config([{"A", schemas: [@s1], owners: [@store]}, {"B", schemas: [@s2]}]),
          graph
        )

      assert index.issues == []
      assert Index.declared(index) == 2
      assert Index.owners(index, "A") == [@store]
    end

    @malformed [
      {"no name", [schemas: [@s1]], "it has no name"},
      {"an unknown key", [name: A, schemas: [@s1], extra: 1], "unknown key(s) :extra"},
      {"a string name", [name: "A", schemas: [@s1]],
       ~s(name must be a module-name atom, got: "A")},
      {"an Erlang atom name", [name: :a, schemas: [@s1]], "name must be a module-name atom"},
      {"a table that is an atom", [name: A, schemas: [@s1], tables: [:atom]],
       "tables must be a list of non-empty strings"},
      {"a schema that is a string", [name: A, schemas: ["S1"]],
       "schemas must be a list of module atoms"},
      {"owner not a boolean", [name: A, schemas: [@s1], owner: :yes],
       "owner must be true or false"},
      {"a key given twice", [name: A, name: B, schemas: [@s1]], "a key is given twice"},
      {"a map", %{name: A, schemas: [@s1]}, "it is not a keyword list"}
    ]

    for {label, value, detail} <- @malformed do
      @tag value: value, detail: detail
      test "I10: malformed attribute (#{label}) contributes nothing", %{
        cores: cores,
        value: value,
        detail: detail
      } do
        index = Index.build(nil, graph(cores, schemas: [@s1], attributes: [{@x, value}]))

        assert [%DeclarationIssue{kind: :malformed_attribute, subject: @x, detail: got}] =
                 index.issues

        assert got =~ detail
        assert Index.aggregate_of(index, @s1) == :error
        assert Index.declared(index) == 0
      end
    end

    test "I10 positive control: the same attribute well formed declares S1", %{cores: cores} do
      index =
        Index.build(
          nil,
          graph(cores, schemas: [@s1], attributes: [{@x, [name: A, schemas: [@s1]]}])
        )

      assert index.issues == []
      assert Index.aggregate_of(index, @s1) == {:ok, "A"}
    end

    test "an attribute set twice is malformed", %{cores: cores} do
      graph = graph(cores, schemas: [@s1], attributes: [{@x, [name: A, schemas: [@s1]]}])

      graph =
        update_in(
          graph.modules[@x].attributes,
          &(&1 ++ [anchor_aggregate: [name: B, schemas: []]])
        )

      assert [%DeclarationIssue{kind: :malformed_attribute, detail: detail}] =
               Index.build(nil, graph).issues

      assert detail =~ "set more than once"
    end

    test "I11: a schema whose source is not a literal has an unknown table, and no issue",
         %{cores: cores} do
      graph = graph(cores, schemas: [@dyn, @s1])
      index = Index.build(config([{"A", schemas: [@dyn, @s1]}]), graph)

      assert Index.aggregate_of(index, @dyn) == {:ok, "A"}
      assert Index.table_of(graph, @dyn) == :unknown
      assert index.tables_unknown == 1
      assert index.issues == []
      assert Map.keys(index.by_table) == ["s1"]
    end
  end

  describe "table_of/2" do
    test "T1: a literal source clause gives the table, past an earlier literal clause",
         %{cores: cores} do
      assert Index.table_of(graph(cores, schemas: [@s1]), @s1) == {:ok, "s1"}
    end

    test "T2: a module without __schema__/1, or none at all, is not a schema", %{cores: cores} do
      graph = graph(cores, plain: [@plain])
      assert Index.table_of(graph, @plain) == :not_a_schema
      assert Index.table_of(graph, Nope) == :not_a_schema
    end

    test "T3: a computed source is unknown, read without loading the module", %{cores: cores} do
      assert Index.table_of(graph(cores, schemas: [@dyn]), @dyn) == :unknown
      assert :code.is_loaded(@dyn) == false
    end

    test "a __schema__/1 with no Core body is unknown" do
      function = %FunctionNode{module: @s1, name: :__schema__, arity: 1, kind: :def, line: 1}
      graph = %Graph{modules: %{@s1 => node(@s1, %{{:__schema__, 1} => function})}}
      assert Index.table_of(graph, @s1) == :unknown
    end

    test "a catch-all clause before :source makes it unknown" do
      [{module, binary}] =
        compile_unloaded("""
        defmodule #{inspect(@ns)}.CatchAll do
          def __schema__(_), do: "t"
        end
        """)

      function = %FunctionNode{
        module: module,
        name: :__schema__,
        arity: 1,
        kind: :def,
        line: 1,
        core: core_fun!(binary, {:__schema__, 1})
      }

      graph = %Graph{modules: %{module => node(module, %{{:__schema__, 1} => function})}}
      assert Index.table_of(graph, module) == :unknown
    end
  end

  describe "aggregate_of/2 and owners/2" do
    test "an undeclared name has no owners" do
      assert Index.owners(%Index{}, "Nope") == []
      assert Index.aggregate_of(%Index{}, "t") == :error
    end
  end

  defp schema_functions(cores, module) do
    %{
      {:__schema__, 1} => %FunctionNode{
        module: module,
        name: :__schema__,
        arity: 1,
        kind: :def,
        line: 2,
        core: Map.fetch!(cores, module)
      }
    }
  end
end
