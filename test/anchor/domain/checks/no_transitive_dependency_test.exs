defmodule Anchor.Domain.Checks.NoTransitiveDependencyTest do
  # Pure Domain detection for the `no_transitive_dependency` check:
  # (bare AST, already-selected rules, cross-file modules_map) in,
  # `[%Violation{}]` out. No Credo types, no IO. Rule SELECTION is the Manager's
  # job (`Anchor.Managers.Lint`) and the cross-file `modules_map` is built there
  # too; here each row supplies the map in-memory, exactly as the acceptance
  # matrix specifies. The Framework mapping to `Credo.Issue` is Base's job and is
  # exercised via `Anchor.Check.NoTransitiveDependency` in
  # test/anchor/check/no_transitive_dependency_test.exs.
  #
  # Matrix: docs/five-bucket-test-matrix.md
  #   "lib/anchor/check/no_transitive_dependency.ex -> check_file/3 -> #1-9".
  # Every check's contract is nominally `check_file/3`; the pure unit that
  # implements these rows is `detect_violations/3`, which takes the modules_map
  # explicitly (check_file/3 cannot supply one — Base hands it an empty map).
  #
  # Sabotage record:
  #   ../../../sabotage_records/no_transitive_dependency-20260913-dnd_127_t6_2_no_transitive_dependency.md
  use ExUnit.Case, async: true

  alias Anchor.Domain.Checks.NoTransitiveDependency
  alias Anchor.Domain.Violation

  defp ast(source), do: Code.string_to_quoted!(source)

  defp rule(forbidden), do: %{type: :no_transitive_dependency, forbidden_modules: forbidden}

  # An AST where module `A` references `B` on line 2. Used by the chain rows; the
  # modules_map is what drives reachability, the AST only supplies the direct
  # reference line for the reported violation.
  defp a_refs_b do
    ast("""
    defmodule A do
      def f, do: B.call()
    end
    """)
  end

  describe "detect_violations/3" do
    # Row 1 — Happy Path: A -> B -> Repo through one intermediary.
    test "flags a forbidden module reached through one intermediary (A->B->Repo)" do
      modules_map = %{
        A => %{direct_dependencies: [B]},
        B => %{direct_dependencies: [MyApp.Repo]}
      }

      assert [%Violation{} = violation] =
               NoTransitiveDependency.detect_violations(
                 a_refs_b(),
                 [rule([MyApp.Repo])],
                 modules_map
               )

      assert violation.message =~ "transitive dependency on forbidden module MyApp.Repo"
      assert violation.message =~ "dependency chain: A -> B -> MyApp.Repo"
      assert violation.trigger == "MyApp.Repo"
      # line of the `B` reference
      assert violation.line == 2
    end

    # Row 2 — Happy Path: two-hop chain A -> B -> C -> Repo.
    test "flags across a two-hop chain (A->B->C->Repo)" do
      modules_map = %{
        A => %{direct_dependencies: [B]},
        B => %{direct_dependencies: [C]},
        C => %{direct_dependencies: [MyApp.Repo]}
      }

      assert [%Violation{} = violation] =
               NoTransitiveDependency.detect_violations(
                 a_refs_b(),
                 [rule([MyApp.Repo])],
                 modules_map
               )

      assert violation.message =~ "dependency chain: A -> B -> C -> MyApp.Repo"
      assert violation.trigger == "MyApp.Repo"
      assert violation.line == 2
    end

    # Row 3 — Happy Path: a direct dependency is also a transitive one, but a
    # path of length <= 2 carries NO chain suffix.
    test "direct dependency also counts as transitive, with no chain suffix" do
      source =
        ast("""
        defmodule A do
          def f, do: MyApp.Repo.all(Q)
        end
        """)

      modules_map = %{A => %{direct_dependencies: [MyApp.Repo]}}

      assert [%Violation{} = violation] =
               NoTransitiveDependency.detect_violations(
                 source,
                 [rule([MyApp.Repo])],
                 modules_map
               )

      assert violation.message ==
               "Module has transitive dependency on forbidden module MyApp.Repo"

      refute violation.message =~ "dependency chain"
      assert violation.trigger == "MyApp.Repo"
      assert violation.line == 2
    end

    # Row 4 — Positive Control: a chain that never reaches the forbidden module.
    test "chain that never reaches the forbidden module passes" do
      modules_map = %{
        A => %{direct_dependencies: [B]},
        B => %{direct_dependencies: [C]}
      }

      assert NoTransitiveDependency.detect_violations(
               a_refs_b(),
               [rule([MyApp.Repo])],
               modules_map
             ) == []

      # Positive control: `C` IS reachable (A -> B -> C), so forbidding it flags.
      assert [%Violation{trigger: "C"}] =
               NoTransitiveDependency.detect_violations(
                 a_refs_b(),
                 [rule([C])],
                 modules_map
               )
    end

    # Row 5 — Control Flow Decisioning: self-reference is removed from the deps,
    # so a module is never its own transitive dependency and never loops.
    test "self-reference does not produce a spurious hit (self removed)" do
      modules_map = %{A => %{direct_dependencies: [A]}}

      # Forbidding the forbidden module: nothing reachable, empty.
      assert NoTransitiveDependency.detect_violations(
               a_refs_b(),
               [rule([MyApp.Repo])],
               modules_map
             ) == []

      # Precise self-removal proof: even forbidding `A` itself yields nothing,
      # because self is stripped from the reachable set.
      assert NoTransitiveDependency.detect_violations(
               a_refs_b(),
               [rule([A])],
               modules_map
             ) == []

      # Positive control: a real dependency beside the self-edge still fires.
      assert [%Violation{trigger: "MyApp.Repo"}] =
               NoTransitiveDependency.detect_violations(
                 a_refs_b(),
                 [rule([MyApp.Repo])],
                 %{A => %{direct_dependencies: [A, MyApp.Repo]}}
               )
    end

    # Row 6 — Error Handling: a cycle in the graph terminates and still detects.
    test "cycle in the graph terminates and still detects" do
      modules_map = %{
        A => %{direct_dependencies: [B]},
        B => %{direct_dependencies: [A, MyApp.Repo]}
      }

      assert [%Violation{} = violation] =
               NoTransitiveDependency.detect_violations(
                 a_refs_b(),
                 [rule([MyApp.Repo])],
                 modules_map
               )

      assert violation.trigger == "MyApp.Repo"
      assert violation.message =~ "dependency chain: A -> B -> MyApp.Repo"
    end

    # Row 7 — Positive Control: a module absent from the map yields nothing.
    test "module absent from the map yields nothing" do
      source =
        ast("""
        defmodule Z do
          def f, do: B.call()
        end
        """)

      assert NoTransitiveDependency.detect_violations(
               source,
               [rule([MyApp.Repo])],
               %{}
             ) == []

      # Positive control: once `Z` IS in the map with a path to Repo, it flags.
      assert [%Violation{trigger: "MyApp.Repo"}] =
               NoTransitiveDependency.detect_violations(
                 source,
                 [rule([MyApp.Repo])],
                 %{Z => %{direct_dependencies: [B]}, B => %{direct_dependencies: [MyApp.Repo]}}
               )
    end

    # Row 8 — Validation: an empty forbidden list flags nothing.
    test "empty forbidden list flags nothing" do
      modules_map = %{
        A => %{direct_dependencies: [B]},
        B => %{direct_dependencies: [MyApp.Repo]}
      }

      assert NoTransitiveDependency.detect_violations(
               a_refs_b(),
               [rule([])],
               modules_map
             ) == []

      # Positive control: the same map with a non-empty forbidden list flags.
      assert [%Violation{trigger: "MyApp.Repo"}] =
               NoTransitiveDependency.detect_violations(
                 a_refs_b(),
                 [rule([MyApp.Repo])],
                 modules_map
               )
    end

    # Row 9 — Rule Selection: rule selection is the Manager's job, so a
    # non-selecting rule reaches this detector as an empty rule list.
    test "no matching rules (empty rule list) flags nothing" do
      modules_map = %{
        A => %{direct_dependencies: [B]},
        B => %{direct_dependencies: [MyApp.Repo]}
      }

      assert NoTransitiveDependency.detect_violations(a_refs_b(), [], modules_map) == []

      # Positive control: the selected rule present flags.
      assert [%Violation{trigger: "MyApp.Repo"}] =
               NoTransitiveDependency.detect_violations(
                 a_refs_b(),
                 [rule([MyApp.Repo])],
                 modules_map
               )
    end
  end

  describe "detect_violations/3 — forbidden_patterns (Gap A / DND-142)" do
    # See docs/phase-d-gap-test-matrix.md, no_transitive_dependency.ex ::
    # detect_violations/3 rows 1-4.
    # Sabotage record:
    #   ../../../sabotage_records/no_dependency-20260913-dnd_142_gap_a_forbidden_patterns_match.md

    defp pattern_rule(patterns) do
      %{type: :no_transitive_dependency, forbidden_modules: [], forbidden_patterns: patterns}
    end

    # Matrix row 1 — Happy Path: a pattern flags a transitively-reached adapter.
    test "forbidden_patterns flags a transitively-reached adapter" do
      modules_map = %{
        A => %{direct_dependencies: [B]},
        B => %{direct_dependencies: [X.Adapters.Y]}
      }

      assert [%Violation{} = violation] =
               NoTransitiveDependency.detect_violations(
                 a_refs_b(),
                 [pattern_rule(["*.Adapters.*"])],
                 modules_map
               )

      assert violation.message =~ "transitive dependency on forbidden module X.Adapters.Y"
      assert violation.message =~ "dependency chain: A -> B -> X.Adapters.Y"
      assert violation.trigger == "X.Adapters.Y"
      assert violation.line == 2
    end

    # Matrix row 2 — Positive Control: a reachable set with no pattern match passes.
    test "a reachable set with no pattern match passes" do
      modules_map = %{
        A => %{direct_dependencies: [B]},
        B => %{direct_dependencies: [C]}
      }

      assert NoTransitiveDependency.detect_violations(
               a_refs_b(),
               [pattern_rule(["*.Adapters.*"])],
               modules_map
             ) == []
    end

    # Matrix row 3 — Happy Path: forbidden_modules and forbidden_patterns both
    # fire transitively.
    test "forbidden_modules and forbidden_patterns both fire transitively" do
      modules_map = %{
        A => %{direct_dependencies: [B]},
        B => %{direct_dependencies: [MyApp.Repo, Z.Adapters.W]}
      }

      rule = %{
        type: :no_transitive_dependency,
        forbidden_modules: [MyApp.Repo],
        forbidden_patterns: ["*.Adapters.*"]
      }

      violations =
        NoTransitiveDependency.detect_violations(a_refs_b(), [rule], modules_map)

      assert length(violations) == 2

      triggers = violations |> Enum.map(& &1.trigger) |> MapSet.new()
      assert triggers == MapSet.new(["MyApp.Repo", "Z.Adapters.W"])
    end

    # Matrix row 4 — Validation: the pattern is dot-bounded transitively.
    test "the pattern is dot-bounded transitively — AdaptersHelper does not match" do
      modules_map = %{
        A => %{direct_dependencies: [B]},
        B => %{direct_dependencies: [Foo.AdaptersHelper]}
      }

      assert NoTransitiveDependency.detect_violations(
               a_refs_b(),
               [pattern_rule(["*.Adapters.*"])],
               modules_map
             ) == []
    end
  end
end
