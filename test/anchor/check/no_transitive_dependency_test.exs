defmodule Anchor.Check.NoTransitiveDependencyTest do
  # Framework-shell contract for Anchor.Check.NoTransitiveDependency (T6.2 /
  # DND-127). Detection now lives in the pure Domain module
  # Anchor.Domain.Checks.NoTransitiveDependency (exercised exhaustively — the 9
  # acceptance-matrix rows — in test/anchor/domain/checks/no_transitive_dependency_test.exs).
  #
  # This suite pins the thin shell: it declares the right rule type, declares it
  # needs the module graph, delegates `detect_violations/4` to the Domain
  # detector (threading `context.modules_map`), and its `check_file/3` — which
  # Base hands an EMPTY modules_map — is therefore silent (no cross-file graph,
  # no transitive reachability).
  use ExUnit.Case, async: true

  alias Anchor.Check.NoTransitiveDependency
  alias Anchor.Domain.Violation
  alias Credo.SourceFile

  describe "rule_type/0" do
    test "is :no_transitive_dependency" do
      assert NoTransitiveDependency.rule_type() == :no_transitive_dependency
    end
  end

  describe "needs_module_graph?/0" do
    test "is true (the Manager must build the cross-file graph for this check)" do
      assert NoTransitiveDependency.needs_module_graph?() == true
    end
  end

  describe "detect_violations/4" do
    test "delegates to the Domain detector, threading context.modules_map" do
      ast =
        Code.string_to_quoted!("""
        defmodule A do
          def f, do: B.call()
        end
        """)

      rules = [%{type: :no_transitive_dependency, forbidden_modules: [MyApp.Repo]}]

      context = %{
        modules_map: %{
          A => %{direct_dependencies: [B]},
          B => %{direct_dependencies: [MyApp.Repo]}
        },
        params: []
      }

      assert [%Violation{trigger: "MyApp.Repo", line: 2} = violation] =
               NoTransitiveDependency.detect_violations(nil, ast, rules, context)

      assert violation.message =~ "dependency chain: A -> B -> MyApp.Repo"
    end

    test "an empty modules_map (Base's check_file default) yields no violations" do
      ast =
        Code.string_to_quoted!("""
        defmodule A do
          def f, do: B.call()
        end
        """)

      rules = [%{type: :no_transitive_dependency, forbidden_modules: [MyApp.Repo]}]
      context = %{modules_map: %{}, params: []}

      assert NoTransitiveDependency.detect_violations(nil, ast, rules, context) == []
    end
  end

  describe "check_file/3" do
    # Base builds `check_file/3`'s context with an empty modules_map, so this
    # check — which needs the cross-file graph — cannot detect a transitive
    # dependency through that entry point and is silent.
    test "returns no issues (check_file has no cross-file module graph)" do
      source_code = """
      defmodule A do
        def f, do: B.call()
      end
      """

      rule = %{type: :no_transitive_dependency, forbidden_modules: [MyApp.Repo]}
      source_file = SourceFile.parse(source_code, "lib/a.ex")

      assert NoTransitiveDependency.check_file(source_file, [rule], []) == []
    end
  end
end
