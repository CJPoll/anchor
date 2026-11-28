defmodule Anchor.Domain.Checks.NoTransitiveDependencyParityTest do
  # DND-8208: the check reads each module's reachable set and every finding's
  # path from one depth-first walk, instead of one targeted search per finding.
  # It finds the same things. These rows hold that on a generated graph of
  # 5,000 modules (`Anchor.Test.TransitiveGraphFixtures`), against the
  # detection as it was before (`Anchor.Test.TransitiveDependencyOracle`), and
  # count the walks the check reports (`detect_with_trees/3`). Nothing here
  # reads a clock: the work is counted, not timed.
  #
  # Sabotage record:
  #   ../../../sabotage_records/no_transitive_dependency-20261127-athena_transitive_reachability_once.md
  use ExUnit.Case, async: true

  alias Anchor.Domain.Checks.NoTransitiveDependency
  alias Anchor.Domain.DependencyAnalyzer
  alias Anchor.Domain.DependencyTree
  alias Anchor.Test.TransitiveDependencyOracle
  alias Anchor.Test.TransitiveGraphFixtures

  setup_all do
    {modules_map, sources} = TransitiveGraphFixtures.graph()
    files = Enum.map(sources, fn {module, source} -> {module, Code.string_to_quoted!(source)} end)
    %{modules_map: modules_map, files: files, rules: TransitiveGraphFixtures.rules()}
  end

  # A walk or a path read back that stops terminating (a parent cycle followed
  # forever) fails its test at this heap bound, about 80 MB, instead of growing
  # until the host kills the run. The 5,000-module rows need a fraction of it.
  setup do
    Process.flag(:max_heap_size, %{size: 10_000_000, kill: true, error_logger: false})
    :ok
  end

  test "the fixture has 5,000 modules and 1,200 Domain files",
       %{modules_map: modules_map, files: files} do
    assert map_size(modules_map) == 5_000
    assert length(files) == 1_200
  end

  test "every file's violations are identical to the pre-change detection's, on 5,000 modules",
       %{modules_map: modules_map, files: files, rules: rules} do
    {compared, {old_searched, new_walked}} =
      Enum.map_reduce(files, {0, 0}, fn {module, ast}, {old_searched, new_walked} ->
        {new, trees} = NoTransitiveDependency.detect_with_trees(ast, rules, modules_map)
        {old, searched} = TransitiveDependencyOracle.detect_violations(ast, rules, modules_map)

        assert {module, new} == {module, old}
        {new, {old_searched + searched, new_walked + Enum.sum_by(trees, & &1.expanded)}}
      end)

    violations = List.flatten(compared)
    chained = Enum.filter(violations, &(&1.message =~ "(dependency chain: "))

    # Not vacuous: thousands of findings, most through a chain, from many files,
    # under both rules.
    assert length(violations) > 5_000
    assert length(chained) > div(length(violations), 2)
    assert Enum.count(compared, &(&1 != [])) > 300
    assert MapSet.new(violations, & &1.trigger) |> MapSet.member?("MyApp.Services.S1")

    # The pre-change half of the refactor: the old per-finding searches alone
    # expanded more modules than all the new walks together (on this fixture,
    # 460,231 against 49,165; the denser `graph(4)`, 39,445,911 against 659,076).
    assert old_searched > new_walked
  end

  test "one walk per module per detect call, whatever the number of findings, each module expanded once",
       %{modules_map: modules_map, files: files, rules: rules} do
    results =
      Enum.map(files, fn {_module, ast} ->
        NoTransitiveDependency.detect_with_trees(ast, rules, modules_map)
      end)

    findings = Enum.flat_map(results, &elem(&1, 0))

    walks =
      Enum.flat_map(results, fn {_violations, trees} ->
        Enum.map(trees, &{&1.start, &1.expanded})
      end)

    # One walk per defined module, never one per rule or per finding.
    assert Enum.map(walks, &elem(&1, 0)) == TransitiveGraphFixtures.domain_modules()
    assert length(findings) > length(walks)

    # Each walk expands each module it reaches exactly once.
    for {start, expanded} <- walks do
      reachable = DependencyAnalyzer.find_transitive_dependencies(modules_map, start)
      assert {start, expanded} == {start, MapSet.size(reachable)}
    end
  end

  # The walk count above is what the check reports about itself, so a search
  # the check made and did not report (a fresh tree, a reachability walk or a
  # targeted path search per finding: the cost DND-8208 removed) would leave it
  # green. This row reads the check's own source instead, through Anchor's call
  # facts, and its compiled function list.
  @check_source Path.expand(
                  "../../../../lib/anchor/domain/checks/no_transitive_dependency.ex",
                  __DIR__
                )

  test "the check's one graph search is the DependencyTree.build/2 call in detect_with_trees/3" do
    ast = @check_source |> File.read!() |> Code.string_to_quoted!(token_metadata: true)

    searches =
      for {{module, function, _arity} = mfa, line} <-
            DependencyAnalyzer.function_references(ast).calls,
          {module, function} in [
            {DependencyTree, :build},
            {DependencyAnalyzer, :find_transitive_dependencies}
          ] or module == TransitiveDependencyOracle,
          do: {mfa, line}

    assert [{{DependencyTree, :build, 2}, line}] = searches
    assert line in def_lines(ast, :detect_with_trees)

    # No search of its own either: the targeted search lives in the oracle.
    local = Enum.map(NoTransitiveDependency.module_info(:functions), &elem(&1, 0))
    assert local -- [:find_dependency_path, :search, :search_each] == local
  end

  defp def_lines(ast, name) do
    {_ast, range} =
      Macro.prewalk(ast, nil, fn
        {:def, meta, [{^name, _, _} | _]} = node, nil ->
          {node, meta[:line]..meta[:end][:line]//1}

        node, acc ->
          {node, acc}
      end)

    range
  end
end
