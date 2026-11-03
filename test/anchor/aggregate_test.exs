defmodule Anchor.AggregateTest do
  # DND-5476: `use Anchor.Aggregate` persists one attribute and nothing else.
  # Fixtures are compiled in the test and unloaded (`Anchor.Test.BeamFixtures`);
  # their attributes are read from the beam, as `mix anchor.graph` reads them.
  #
  # Sabotage record: ../sabotage_records/aggregates-20261103-dnd_5476_aggregate_decls.md
  use ExUnit.Case, async: true

  import Anchor.Test.BeamFixtures

  alias Anchor.Adapters.BeamReader

  @ns "AnchorFixtures.AggregateTest"

  defp attribute(source) do
    [{module, binary}] = compile_unloaded(source)
    {:ok, {^module, [attributes: chunk]}} = :beam_lib.chunks(binary, [:attributes])
    beam = BeamReader.decode(binary, app: :fixtures, path: "#{module}.beam")
    {Keyword.get_values(beam.elixir.attributes, :anchor_aggregate), chunk, beam}
  end

  describe "__using__/1" do
    test "M1: the macro persists exactly the attribute, owner true by default" do
      {values, chunk, _beam} =
        attribute("""
        defmodule #{@ns}.M1 do
          use Anchor.Aggregate, name: #{@ns}.Agg, schemas: [#{@ns}.S]
        end
        """)

      expected = [
        name: AnchorFixtures.AggregateTest.Agg,
        schemas: [AnchorFixtures.AggregateTest.S],
        tables: [],
        owner: true
      ]

      assert values == [expected]
      assert Keyword.fetch!(chunk, :anchor_aggregate) == expected
    end

    test "M2: the hand-written attribute reads the same as the macro's" do
      {macro, _chunk, _beam} =
        attribute("""
        defmodule #{@ns}.M2Macro do
          use Anchor.Aggregate, name: #{@ns}.Agg, schemas: [#{@ns}.S], tables: ["t"]
        end
        """)

      {hand, _chunk, _beam} =
        attribute("""
        defmodule #{@ns}.M2Hand do
          Module.register_attribute(__MODULE__, :anchor_aggregate, persist: true)
          @anchor_aggregate [name: #{@ns}.Agg, schemas: [#{@ns}.S], tables: ["t"], owner: true]
        end
        """)

      assert macro == hand
      assert [[_ | _]] = macro
    end

    test "M3: aliases in scope resolve, and so does __MODULE__" do
      {[value], _chunk, _beam} =
        attribute("""
        defmodule #{@ns}.M3 do
          alias App.Threads, as: T
          use Anchor.Aggregate, name: T.Space, schemas: [__MODULE__], owner: false
        end
        """)

      assert value == [
               name: App.Threads.Space,
               schemas: [AnchorFixtures.AggregateTest.M3],
               tables: [],
               owner: false
             ]
    end

    @refused [
      {"no name", "schemas: [S]", "the name: option is required"},
      {"an unknown key", "name: Agg, bogus: 1", "unknown option(s) :bogus"},
      {"a variable name", "name: some_var", "name: must be a literal module name, got: some_var"},
      {"an atom name", "name: :agg", "name: must be a literal module name, got: :agg"},
      {"a non-literal schema", "name: Agg, schemas: [mod()]",
       "schemas: must be a literal module name"},
      {"schemas not a list", "name: Agg, schemas: S", "schemas: must be a list of module names"},
      {"an empty table", ~s(name: Agg, tables: [""]),
       "tables: must be a list of non-empty strings"},
      {"a non-boolean owner", "name: Agg, owner: :yes", "owner: must be true or false"}
    ]

    for {label, options, expected} <- @refused do
      @tag options: options, expected: expected
      test "M4: #{label} raises ArgumentError naming the key and the shape", %{
        options: options,
        expected: expected
      } do
        name = "#{@ns}.M4#{System.unique_integer([:positive])}"

        error =
          assert_raise ArgumentError, fn ->
            compile_unloaded("""
            defmodule #{name} do
              use Anchor.Aggregate, #{options}
            end
            """)
          end

        assert error.message =~ "use Anchor.Aggregate: " <> expected
        assert error.message =~ "Write: use Anchor.Aggregate, name: MyApp.Space, schemas:"
      end
    end

    test "M4 positive control: the same options with a literal name compile" do
      assert {[[name: Agg, schemas: [], tables: [], owner: true]], _chunk, _beam} =
               attribute("""
               defmodule #{@ns}.M4Ok do
                 use Anchor.Aggregate, name: Agg
               end
               """)
    end

    test "M5: the macro adds no function to the module" do
      {_values, _chunk, beam} =
        attribute("""
        defmodule #{@ns}.M5 do
          use Anchor.Aggregate, name: #{@ns}.Agg, schemas: [#{@ns}.S]
        end
        """)

      assert beam.elixir.definitions == []
    end
  end
end
