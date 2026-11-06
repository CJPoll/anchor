defmodule Anchor.Integration.LayeringParityTest do
  # DND-5491: the engine split, held equal. The graph engine's `layering` rule
  # is the authority on layering; the AST dependency rules are its write-time
  # early warnings (`RuleSchema.early_warning_of/1`). Over the macro-free tree
  # test/fixtures/parity/, both engines must flag the same (caller, callee)
  # pairs:
  #
  #   * the AST side runs `no_direct_dependency` and `no_transitive_dependency`
  #     rules derived from the tree's `architecture:` section
  #     (`Parity.ast_rules_for/1`) through `Anchor.Managers.Lint`, on the
  #     sources read as Credo source files (the config port doubled);
  #   * the graph side compiles the same sources in the test
  #     (`Anchor.Test.BeamFixtures`), builds the model and runs `Layering`.
  #
  # Direct findings must match exactly, apart from the listed divergences.
  # The graph judges direct calls only, so each transitive AST finding must
  # pass through a call the graph flags (`Parity.uncovered/3`); the tree's
  # matrix is transitively closed, so on it that always holds.
  #
  # Sabotage record: ../../sabotage_records/parity-20261103-dnd_5648_graph_followups.md
  # Sabotage record (DND-5491, PA-A): ../../sabotage_records/dependency_analyzer-20261103-dnd_5648_graph_followups.md
  # Sabotage record (DND-5491, PA-B): ../../sabotage_records/layering-20261103-dnd_5648_graph_followups.md
  use ExUnit.Case, async: true

  import Anchor.Test.BeamFixtures
  import Hammox

  alias Anchor.Adapters.BeamReader
  alias Anchor.Adapters.ConfigFile
  alias Anchor.Check.NoDependency
  alias Anchor.Check.NoTransitiveDependency
  alias Anchor.Config
  alias Anchor.ConfigLoaderMock
  alias Anchor.Domain.DependencyAnalyzer
  alias Anchor.Domain.Graph.Builder
  alias Anchor.Domain.Graph.SourceFacts
  alias Anchor.Domain.GraphRules.Layering
  alias Anchor.Domain.Model
  alias Anchor.Domain.Parity
  alias Anchor.Managers.Lint
  alias Credo.SourceFile

  setup :verify_on_exit!

  @root Path.expand("../../fixtures/parity", __DIR__)

  @fee "AnchorFixtures.Parity.Billing.Domain.Fee"
  @store "AnchorFixtures.Parity.Orders.Adapters.Store"

  # What the engines may disagree on, each with its reason. It only shrinks:
  # a listed pair that no longer diverges fails the test, so the entry goes.
  @divergences [
    {:graph_only, {@fee, @store},
     "a dynamic call (store.save/1): the graph resolves it to every module exporting " <>
       "save/1; the AST cannot see a receiver"}
  ]

  setup_all do
    {:ok, config} = ConfigFile.load_from_path(Path.join(@root, ".anchor.yml"))

    sources =
      Path.join(@root, "lib/**/*.ex")
      |> Path.wildcard()
      |> Enum.sort()
      |> Enum.map(&{File.read!(&1), Path.relative_to(&1, @root)})

    %{config: config, sources: sources}
  end

  defp graph_pairs(%{config: config, sources: sources}) do
    beams =
      sources
      |> compile_all_unloaded()
      |> Enum.map(fn {module, binary} ->
        BeamReader.decode(binary, app: :parity, path: "ebin/#{module}.beam")
      end)

    facts = Map.new(sources, fn {text, file} -> {file, SourceFacts.from_source(file, text)} end)
    {model, []} = Model.build(Builder.build(beams, facts), config, facts)
    [layering] = config.rules

    model |> Layering.check(layering) |> Parity.pairs_from_graph()
  end

  defp ast_results(check, %{config: config, sources: sources}) do
    rules = Parity.ast_rules_for(config.architecture)
    files = Enum.map(sources, fn {text, file} -> SourceFile.parse(text, file) end)

    expect(ConfigLoaderMock, :load, fn -> {:ok, %Config{rules: rules, path: ".anchor.yml"}} end)

    {:ok, results} =
      Lint.run(check, files, [], config_loader: ConfigLoaderMock, enforce_selection_floors: false)

    for {%SourceFile{} = file, violations} <- results, do: {defined_module(file), violations}
  end

  defp defined_module(%SourceFile{} = file) do
    [module] =
      file
      |> SourceFile.source()
      |> Code.string_to_quoted!()
      |> DependencyAnalyzer.extract_module_names()

    inspect(module)
  end

  # Each module's direct dependencies, as the AST analysis reads them.
  defp deps(%{sources: sources}) do
    for {text, _file} <- sources,
        {module, %{direct_dependencies: deps}} <-
          text |> Code.string_to_quoted!() |> DependencyAnalyzer.module_dependencies(),
        into: %{},
        do: {inspect(module), Enum.map(deps, &inspect/1)}
  end

  test "both engines flag the same pairs, apart from the listed divergences", context do
    graph = graph_pairs(context)
    ast = context |> then(&ast_results(NoDependency, &1)) |> Parity.pairs_from_ast()

    transitive =
      context |> then(&ast_results(NoTransitiveDependency, &1)) |> Parity.pairs_from_ast()

    # Positive control: the inputs hold direct and transitive cases, so an
    # empty diff cannot come from empty inputs.
    assert MapSet.size(ast) >= 1
    assert transitive |> MapSet.difference(ast) |> MapSet.size() >= 1

    %{ast_only: ast_only, graph_only: graph_only} = Parity.diff(ast, graph)
    found = Enum.map(ast_only, &{:ast_only, &1}) ++ Enum.map(graph_only, &{:graph_only, &1})
    listed = Enum.map(@divergences, fn {side, pair, _reason} -> {side, pair} end)

    assert found -- listed == [],
           "the engines disagree on: " <>
             Enum.map_join(found -- listed, "; ", fn {side, {caller, callee}} ->
               "#{caller} -> #{callee} (only the #{side |> Atom.to_string() |> String.trim_trailing("_only")} engine flags it)"
             end)

    assert listed -- found == [],
           "listed divergences that no longer diverge (delete them): #{inspect(listed -- found)}"

    assert Parity.uncovered(transitive, graph, deps(context)) == [],
           "transitive AST findings with no flagged call on their chain"
  end

  test "the pairs each engine flags, named (so a change in either is read here)", context do
    expected_direct = [
      {"AnchorFixtures.Parity.Orders.Adapters.Store",
       "AnchorFixtures.Parity.Orders.Managers.Checkout"},
      {"AnchorFixtures.Parity.Orders.Domain.Calc",
       "AnchorFixtures.Parity.Orders.Managers.Checkout"},
      {"AnchorFixtures.Parity.Orders.Domain.Rules", @store},
      {"AnchorFixtures.Parity.Orders.Ui.Badge", "AnchorFixtures.Parity.Orders.Managers.Checkout"}
    ]

    assert context
           |> then(&ast_results(NoDependency, &1))
           |> Parity.pairs_from_ast()
           |> Enum.sort() ==
             expected_direct

    assert context |> graph_pairs() |> Enum.sort() ==
             Enum.sort([{@fee, @store} | expected_direct])
  end

  test "the derivation reads every bucket of the tree, and its matrix is closed", %{
    config: config
  } do
    rules = Parity.ast_rules_for(config.architecture)

    assert Enum.map(rules, & &1.id) |> Enum.sort() ==
             Enum.sort(~w(
               parity:adapters:direct parity:adapters:transitive parity:adapters:same_context
               parity:domain:direct parity:domain:transitive
               parity:managers:direct parity:managers:transitive
               parity:ui:direct parity:ui:transitive
             ))
  end
end
