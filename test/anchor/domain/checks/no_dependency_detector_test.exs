defmodule Anchor.Domain.Checks.NoDependencyDetectorTest do
  # DND-8063: NoDependency as an `Anchor.Domain.Detector`. detect/1 derives the
  # file's own context from `Input.module_names` (Gap F, DND-150; moved here
  # from the Credo check), so a `same_context` rule scopes its patterns to it.
  # A sibling of the detector's own test file, so a sabotage run of the module
  # selects it.
  #
  # Sabotage record:
  #   ../../../sabotage_records/no_dependency-20261127-athena_DND_8063_framework_tests_mock_manager.md
  use ExUnit.Case, async: true

  alias Anchor.Domain.Checks.NoDependency
  alias Anchor.Domain.Detector.Input

  @rule %{
    type: :no_direct_dependency,
    forbidden_modules: [],
    forbidden_patterns: ["*.Managers.*"],
    match: :call,
    same_context: true,
    context_depth: 2
  }

  @source """
  defmodule MyApp.Contacts.Adapters.Foo do
    def f(x), do: MyApp.Contacts.Managers.Bar.run(x)
  end
  """

  defp detect(module_names) do
    ast = Code.string_to_quoted!(@source, columns: true)
    NoDependency.detect(%Input{ast: ast, rules: [@rule], module_names: module_names})
  end

  test "its rule type is :no_direct_dependency" do
    assert NoDependency.rule_type() == :no_direct_dependency
  end

  test "the file's context is its first module's leading segments, with or without Elixir." do
    for names <- [
          ["Elixir.MyApp.Contacts.Adapters.Foo"],
          ["MyApp.Contacts.Adapters.Foo"],
          ["Elixir.MyApp.Contacts.Adapters.Foo", "Elixir.Other.Ctx.Mod"]
        ] do
      assert [%{trigger: "MyApp.Contacts.Managers.Bar"}] = detect(names), inspect(names)
    end
  end

  test "another context, or no module name, scopes the same-context pattern away" do
    assert detect(["Elixir.Other.Ctx.Mod"]) == []
    assert detect([]) == []
  end
end
