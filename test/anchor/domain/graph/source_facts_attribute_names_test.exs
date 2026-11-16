defmodule Anchor.Domain.Graph.SourceFactsAttributeNamesTest do
  # A module attribute named like a directive (`@use Other.Mod`) is
  # `{:@, meta, [{:use, meta, [value]}]}`: the inner node has the shape of a
  # `use` call. It uses nothing, for every name in the special-names table.
  #
  # Sabotage record: ../../../sabotage_records/graph-20261116-athena_quote_attribute_crash.md, ../../../sabotage_records/attribute_node-20261116-athena_quote_attribute_crash.md (E)
  use ExUnit.Case, async: true

  alias Anchor.Domain.Graph.SourceFacts

  @attribute_names "test/fixtures/special_variable_names.txt"
                   |> File.read!()
                   |> String.split()

  defp source(name) do
    """
    defmodule A.B do
      @#{name} Other.Mod
      @#{name} [do: Third.Mod]

      def run, do: @#{name}
    end

    defmodule C do
    end
    """
  end

  test "the plain-named baseline" do
    assert SourceFacts.from_source("a.ex", source("value")) == %{
             defmodules: ["A.B", "C"],
             uses: %{"A.B" => [], "C" => []},
             nonliteral_defmodule?: false
           }
  end

  test "a use of an attribute's value is not a literal use" do
    text = """
    defmodule A do
      @base Some.Base
      use @base
      use GenServer
    end
    """

    assert %{uses: %{"A" => ["GenServer"]}} = SourceFacts.from_source("a.ex", text)
  end

  for name <- @attribute_names do
    test "an attribute named @#{name} reads as one named @value" do
      assert SourceFacts.from_source("a.ex", source(unquote(name))) ==
               SourceFacts.from_source("a.ex", source("value"))
    end
  end
end
