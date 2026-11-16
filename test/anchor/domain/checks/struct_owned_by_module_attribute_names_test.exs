defmodule Anchor.Domain.Checks.StructOwnedByModuleAttributeNamesTest do
  # A module attribute named like a definition (`@def %Other{x: 1}`) is
  # `{:@, meta, [{:def, meta, [value]}]}`: the inner node has the shape of a
  # bodiless `def` whose head is the value. The value is code, not a pattern,
  # so a struct built there is reported, for every name in the special-names
  # table, exactly as for `@value`.
  #
  # Sabotage record: ../../../sabotage_records/struct_owned_by_module-20261116-athena_quote_attribute_crash.md
  use ExUnit.Case, async: true

  alias Anchor.Domain.Checks.StructOwnedByModule, as: Check

  @attribute_names "test/fixtures/special_variable_names.txt"
                   |> File.read!()
                   |> String.split()

  defp source(name) do
    """
    defmodule App.Builder do
      @#{name} %App.Turn{status: :idle}

      def run, do: @#{name}
    end
    """
  end

  defp triggers(source) do
    source
    |> Code.string_to_quoted!(columns: true)
    |> Check.detect_violations([%{}])
    |> Enum.map(&{&1.trigger, &1.line})
  end

  test "the plain-named baseline: the struct built in the attribute is reported" do
    assert triggers(source("value")) == [{"%App.Turn{", 2}]
  end

  for name <- @attribute_names do
    test "an attribute named @#{name} reports the struct built in it" do
      assert triggers(source(unquote(name))) == [{"%App.Turn{", 2}]
    end
  end
end
