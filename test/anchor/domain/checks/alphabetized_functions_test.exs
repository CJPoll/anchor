defmodule Anchor.Domain.Checks.AlphabetizedFunctionsTest do
  # Pure Domain detection for the `alphabetized_functions` check: (bare AST,
  # rules) in, `[%Violation{}]` out. No Credo types, no IO. The Framework mapping
  # to `Credo.Issue` (and the exhaustive #1-14 matrix) lives in
  # test/anchor/check/alphabetized_functions_test.exs.
  #
  # Sabotage record:
  #   ../../../sabotage_records/alphabetized_functions-20260913-dnd_135_t6_10_alphabetized_functions.md
  use ExUnit.Case, async: true

  alias Anchor.Domain.Checks.AlphabetizedFunctions
  alias Anchor.Domain.Violation

  defp ast(source), do: Code.string_to_quoted!(source)

  describe "detect_violations/2" do
    test "reads mode from the atom key :mode (not a string key)" do
      ast =
        ast("""
        defmodule M do
          def cherry(), do: :ok
          defp apple(), do: :ok
          def banana(), do: :ok
        end
        """)

      # :all via the atom key checks public+private together and flags.
      assert [_ | _] = AlphabetizedFunctions.detect_violations(ast, [%{mode: :all}])

      # A string "mode" key is NOT the T3 shape, so it is ignored and the rule
      # falls back to :separate (structural + per-group ordering), not :all.
      separate = AlphabetizedFunctions.detect_violations(ast, [%{"mode" => "all"}])
      assert Enum.any?(separate, &(&1.message =~ "appears before public functions"))
    end

    test "defaults to :separate when the rule has no mode" do
      ast =
        ast("""
        defmodule M do
          defp helper(), do: :ok
          def apple(), do: :ok
        end
        """)

      assert [%Violation{} = violation] =
               AlphabetizedFunctions.detect_violations(ast, [%{type: :alphabetized_functions}])

      assert violation.message =~ "appears before public functions"
      assert violation.trigger == "helper/0"
      assert violation.line == 2
    end

    test "a multi-clause function collapses to one unit anchored at the first clause" do
      ast =
        ast("""
        defmodule M do
          def banana(:x), do: 1
          def banana(:y), do: 2
          def apple(), do: :ok
        end
        """)

      violations = AlphabetizedFunctions.detect_violations(ast, [%{mode: :all}])
      banana = Enum.filter(violations, &(&1.trigger == "banana/1"))

      assert [%Violation{line: 2}] = banana
    end

    test "defguard/defguardp participate in ordering" do
      ordered =
        ast("""
        defmodule M do
          defguard is_apple(x) when x == :apple
          defguard is_banana(x) when x == :banana
        end
        """)

      assert [] == AlphabetizedFunctions.detect_violations(ordered, [%{mode: :all}])

      broken =
        ast("""
        defmodule M do
          defguard is_banana(x) when x == :banana
          defguard is_apple(x) when x == :apple
        end
        """)

      assert Enum.any?(
               AlphabetizedFunctions.detect_violations(broken, [%{mode: :all}]),
               &(&1.trigger == "is_apple/1")
             )
    end
  end
end
