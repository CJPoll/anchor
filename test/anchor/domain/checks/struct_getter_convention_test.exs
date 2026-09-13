defmodule Anchor.Domain.Checks.StructGetterConventionTest do
  # Pure Domain detection for the `struct_getter_convention` check: bare AST in,
  # `[%Violation{}]` out. No Credo types, no IO. The Framework mapping to
  # `Credo.Issue` (and the exhaustive #1-21 matrix) lives in
  # test/anchor/check/struct_getter_convention_test.exs. This file pins the new
  # load-bearing capability — alias resolution and the naming-vs-location split.
  #
  # Sabotage record:
  #   ../../../sabotage_records/struct_getter_convention-20260913-dnd_137_t6_12_struct_getter_convention.md
  use ExUnit.Case, async: true

  alias Anchor.Domain.Checks.StructGetterConvention
  alias Anchor.Domain.Violation

  defp ast(source), do: Code.string_to_quoted!(source)

  describe "detect_violations/2 — enclosing struct naming" do
    test "flags a %__MODULE__{} getter whose name does not match the field" do
      ast =
        ast("""
        defmodule MyApp.User do
          defstruct [:name]
          def get_name(%__MODULE__{name: name}), do: name
        end
        """)

      assert [%Violation{} = violation] = StructGetterConvention.detect_violations(ast)

      assert violation.message ==
               "Getter function `get_name` should be named `name` to match the field it extracts"

      assert violation.trigger == "get_name"
      assert violation.line == 3
    end

    test "resolves an aliased struct back to the enclosing module (naming, not location)" do
      ast =
        ast("""
        defmodule MyApp.User do
          alias MyApp.User
          defstruct [:name]
          def get_name(%User{name: name}), do: name
        end
        """)

      assert [%Violation{} = violation] = StructGetterConvention.detect_violations(ast)
      assert violation.message =~ "should be named `name`"
    end

    test "resolves an `:as` alias back to the enclosing module" do
      ast =
        ast("""
        defmodule MyApp.User do
          alias MyApp.User, as: X
          defstruct [:name]
          def name(%X{name: name}), do: name
        end
        """)

      assert [] == StructGetterConvention.detect_violations(ast)
    end
  end

  describe "detect_violations/2 — foreign struct location" do
    test "flags a getter for a foreign struct with a location message" do
      ast =
        ast("""
        defmodule A do
          def name(%Other{name: name}), do: name
        end
        """)

      assert [%Violation{} = violation] = StructGetterConvention.detect_violations(ast)

      assert violation.message ==
               "Getter for `Other.name` should be defined in `Other` (not in `A`)"

      assert violation.trigger == "name"
      assert violation.line == 2
    end

    test "an `:as` alias recovers the real foreign module in the location message" do
      ast =
        ast("""
        defmodule A do
          alias Other.Thing, as: O
          def name(%O{name: name}), do: name
        end
        """)

      assert [%Violation{} = violation] = StructGetterConvention.detect_violations(ast)

      assert violation.message ==
               "Getter for `Other.Thing.name` should be defined in `Other.Thing` (not in `A`)"
    end

    test "resolves a multi-alias `A.{B}` form to the real foreign module" do
      ast =
        ast("""
        defmodule A do
          alias Other.{Thing}
          def name(%Thing{name: name}), do: name
        end
        """)

      assert [%Violation{} = violation] = StructGetterConvention.detect_violations(ast)

      assert violation.message ==
               "Getter for `Other.Thing.name` should be defined in `Other.Thing` (not in `A`)"
    end

    test "a bare literal struct with no alias resolves to Elixir.<Name> and is foreign" do
      ast =
        ast("""
        defmodule MyApp.Service do
          def name(%Unknown{name: name}), do: name
        end
        """)

      assert [%Violation{} = violation] = StructGetterConvention.detect_violations(ast)
      assert violation.message =~ "should be defined in `Unknown`"
      refute violation.message =~ "should be named"
    end
  end

  describe "detect_violations/2 — non-getters and macros" do
    test "ignores a function that processes the extracted value" do
      ast =
        ast("""
        defmodule MyApp.User do
          defstruct [:name]
          def name(%__MODULE__{name: name}), do: String.upcase(name)
        end
        """)

      assert [] == StructGetterConvention.detect_violations(ast)
    end

    test "says nothing for an enclosing getter with no literal defstruct" do
      ast =
        ast("""
        defmodule MyApp.User do
          use SomeSchema
          def get_name(%__MODULE__{name: name}), do: name
        end
        """)

      assert [] == StructGetterConvention.detect_violations(ast)
    end
  end
end
