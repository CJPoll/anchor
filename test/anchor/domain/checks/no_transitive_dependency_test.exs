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
  alias Anchor.Test.TransitiveDependencyOracle

  # A path search that stops terminating (a cycle followed forever) fails its
  # test at this heap bound, about 16 MB, instead of growing until the host
  # kills the run. Every test here needs a small fraction of it.
  setup do
    Process.flag(:max_heap_size, %{size: 2_000_000, kill: true, error_logger: false})
    :ok
  end

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
               "Module has transitive dependency on forbidden module MyApp.Repo" <>
                 ". Fix: no chain of dependencies from the module reaches MyApp.Repo; cut the chain where it first enters a module that depends on it"

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

  # The path finder shares one visited set across every branch of its search, so
  # each module is expanded (its dependency list read) at most once. A search
  # that only remembered the modules on the current branch re-walked every
  # shared subtree once per route into it: exponential in the graph's depth on a
  # layered graph, and a credo run over a large tree never finished once a
  # violation existed. The tests count expansions, never time.
  #
  # Sabotage record:
  #   ../../../sabotage_records/no_transitive_dependency-20261116-athena_path_finder_visited_set.md
  # DND-8208: the check no longer runs this targeted search; it reads every
  # path from one search tree per module. The search moved, unchanged, to the
  # parity tests' oracle (test/support/transitive_dependency_oracle.ex), where
  # it is the reference the tree is compared with, so these rows still pin it.
  describe "find_dependency_path/3 (the reference search, now in the oracle)" do
    # `Root` depends on every module of layer 1 and then on `Bridge`; every
    # module of layer i depends on every module of layer i + 1; the last layer
    # depends on nothing; `Bridge` depends on `Forbidden`. The only route to
    # `Forbidden` is the last one tried, after the whole layered subgraph.
    defp layered_graph(width, depth) do
      layer = fn i -> Enum.map(1..width, &Module.concat([Layer, "L#{i}", "N#{&1}"])) end

      layers =
        Map.new(1..depth, fn i ->
          next = if i < depth, do: layer.(i + 1), else: []
          {i, Enum.map(layer.(i), &{&1, %{direct_dependencies: next}})}
        end)

      layers
      |> Map.values()
      |> List.flatten()
      |> Map.new()
      |> Map.put(Root, %{direct_dependencies: layer.(1) ++ [Bridge]})
      |> Map.put(Bridge, %{direct_dependencies: [Forbidden]})
    end

    test "expands each module of a dense layered graph at most once" do
      modules_map = layered_graph(3, 8)

      # Root, the 24 layer modules and Bridge: every module but the target.
      assert {[Root, Bridge, Forbidden], 26} =
               TransitiveDependencyOracle.find_dependency_path(modules_map, Root, Forbidden)
    end

    test "a dead-end subtree reached by two routes is expanded once, and the path is the first in dependency order" do
      modules_map = %{
        S => %{direct_dependencies: [A, B]},
        A => %{direct_dependencies: [C]},
        B => %{direct_dependencies: [C, D]},
        C => %{direct_dependencies: []},
        D => %{direct_dependencies: [Forbidden]}
      }

      assert {[S, B, D, Forbidden], 5} =
               TransitiveDependencyOracle.find_dependency_path(modules_map, S, Forbidden)
    end

    test "of two routes, the path is the first in dependency order, not the shortest" do
      modules_map = %{
        S => %{direct_dependencies: [A, B]},
        A => %{direct_dependencies: [C]},
        B => %{direct_dependencies: [Forbidden]},
        C => %{direct_dependencies: [Forbidden]}
      }

      assert {[S, A, C, Forbidden], 3} =
               TransitiveDependencyOracle.find_dependency_path(modules_map, S, Forbidden)
    end

    test "a module first met on the current branch (a cycle) is still left for a later route" do
      modules_map = %{
        S => %{direct_dependencies: [A]},
        A => %{direct_dependencies: [B, C]},
        B => %{direct_dependencies: [A]},
        C => %{direct_dependencies: [Forbidden]}
      }

      assert {[S, A, C, Forbidden], 4} =
               TransitiveDependencyOracle.find_dependency_path(modules_map, S, Forbidden)
    end

    test "an unreachable target yields nil after expanding each reachable module once" do
      modules_map = layered_graph(3, 8)

      # 26, and Forbidden itself: here it is not the target, so it is expanded
      # (it has no entry, so no dependencies).
      assert {nil, 27} =
               TransitiveDependencyOracle.find_dependency_path(modules_map, Root, Elsewhere)
    end

    test "detect_violations/3 reports the first path in dependency order, past a shared dead end" do
      # A and B both reach the dead end C; the first route to Forbidden is
      # through B, then D, though B -> Forbidden is shorter and comes later.
      modules_map = %{
        A => %{direct_dependencies: [C, B]},
        B => %{direct_dependencies: [C, D, Forbidden]},
        C => %{direct_dependencies: []},
        D => %{direct_dependencies: [Forbidden]}
      }

      assert [%Violation{} = violation] =
               NoTransitiveDependency.detect_violations(
                 a_refs_b(),
                 [rule([Forbidden])],
                 modules_map
               )

      assert violation.message =~ "dependency chain: A -> B -> D -> Forbidden"
      assert violation.line == 2
    end
  end
end
