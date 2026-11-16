defmodule Anchor.Domain.Sabotage.FunctionSpansAttributeNamesTest do
  # A module attribute named like a definition (`@def Other.Mod`) is
  # `{:@, meta, [{:def, meta, [value]}]}`: the inner node has the shape of a
  # `def` call. It defines no function, so it has no span, for every name in
  # the special-names table.
  #
  # Sabotage record: ../../../sabotage_records/sabotage-20261116-athena_quote_attribute_crash.md (hand run C)
  use ExUnit.Case, async: true

  alias Anchor.Domain.Sabotage.FunctionSpans

  @attribute_names "test/fixtures/special_variable_names.txt"
                   |> File.read!()
                   |> String.split()

  defp source(name) do
    """
    defmodule M do
      @#{name} Other.Mod
      @#{name} [do: Third.Mod]
      @#{name} fn x -> x end

      def run(x) do
        @#{name}
      end
    end
    """
  end

  defp summary(source) do
    {:ok, spans} = FunctionSpans.spans(source, "lib/m.ex")
    Enum.map(spans, &{&1.module, &1.name, &1.arity, &1.kind, &1.first..&1.last//1})
  end

  test "the plain-named baseline: one span, the def" do
    assert summary(source("value")) == [{M, :run, 1, :def, 6..8}]
  end

  for name <- @attribute_names do
    test "an attribute named @#{name} adds no span" do
      assert summary(source(unquote(name))) == [{M, :run, 1, :def, 6..8}]
    end
  end
end
