defmodule Anchor.Domain.Checks.StructGetterConventionAliasTest do
  # DND-8063: `alias A.B, as: X` resolution in StructGetterConvention, held at
  # the Domain level (rows #10 and #11 of the check's own test) after its
  # `with ... else` became an `if` and a helper. A sibling of the detector's
  # test file, so a sabotage run of the module selects it.
  #
  # Sabotage record:
  #   ../../../sabotage_records/struct_getter_convention-20261127-athena_DND_8063_framework_tests_mock_manager.md
  use ExUnit.Case, async: true

  alias Anchor.Domain.Checks.StructGetterConvention

  defp detect(source),
    do:
      source
      |> Code.string_to_quoted!(columns: true)
      |> StructGetterConvention.detect_violations()

  test "a misnamed getter written with an :as alias of the module is a naming finding" do
    assert [violation] =
             detect("""
             defmodule MyApp.User do
               alias MyApp.User, as: X
               defstruct [:name]
               def get_name(%X{name: name}), do: name
             end
             """)

    assert violation.message =~ "Getter function `get_name` should be named `name`"
  end

  test "an :as alias whose name is not a plain alias, or whose target is not literal, is skipped" do
    assert [] ==
             detect("""
             defmodule MyApp.User do
               alias __MODULE__.Inner, as: I
               alias MyApp.Other, as: :not_an_alias
               defstruct [:name]
               def name(%__MODULE__{name: name}), do: name
             end
             """)
  end
end
