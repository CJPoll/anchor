defmodule Anchor.Domain.Checks.ModulePatternRestrictionsAttributeNamesTest do
  # A module attribute named like a definition (`@def Other.Mod`) is
  # `{:@, meta, [{:def, meta, [value]}]}`: the inner node has the shape of a
  # `def` call. It defines no function, and `@use Some.Base` uses nothing, for
  # every name in the special-names table.
  use ExUnit.Case, async: true

  alias Anchor.Domain.Checks.ModulePatternRestrictions

  @attribute_names "test/fixtures/special_variable_names.txt"
                   |> File.read!()
                   |> String.split()

  defp source(name) do
    """
    defmodule S do
      @#{name} Other.Mod
      @#{name} Some.Base
      @#{name} fn x -> x end

      def custom, do: @#{name}
    end
    """
  end

  defp triggers(name, rule) do
    source(name)
    |> Code.string_to_quoted!()
    |> ModulePatternRestrictions.detect_violations([rule])
    |> Enum.map(&{&1.trigger, &1.line})
  end

  @allowed_rule %{allowed_functions: ["other"]}
  @uses_rule %{uses_module: "Some.Base", allowed_functions: ["other"]}

  test "the plain-named baseline: the one def is flagged, the uses rule selects nothing" do
    assert triggers("value", @allowed_rule) == [{"custom", 6}]
    assert triggers("value", @uses_rule) == []
  end

  for name <- @attribute_names do
    test "an attribute named @#{name} defines no function and uses no module" do
      name = unquote(name)
      assert triggers(name, @allowed_rule) == [{"custom", 6}]
      assert triggers(name, @uses_rule) == []
    end
  end
end
