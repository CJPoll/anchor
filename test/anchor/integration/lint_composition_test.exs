defmodule Anchor.Integration.LintCompositionTest do
  # Integration coverage for the acquire -> derive-facts -> select composition
  # that T4 moved into `Anchor.Managers.Lint` and that `Anchor.Check.Base`
  # (Framework) drives. It exercises the WHOLE composition with the REAL
  # `Anchor.Domain.DependencyAnalyzer` (fact derivation off a real AST) and the REAL
  # `Anchor.Domain.RuleMatching` / `Anchor.Domain.GlobPattern` selection — only
  # the config SOURCE is injected.
  #
  # The selector rows re-verified here (module `pattern` = matrix row #4;
  # `uses_module` match/no-match = rows #6/#7 of `base.ex -> rule_matches_file?/2`)
  # are OWNED by T2's `Anchor.Domain.RuleMatchingTest`; this is deliberate
  # end-to-end overlap proving the pieces compose through the Manager, NOT new
  # ownership of those rows.
  #
  # Rules are injected as sparse maps (no `:paths` key) via a stub loader.
  # Through the real config pipeline `Anchor.Config.parse_rule/1` stamps every
  # rule with `paths: []`, which shadows the `pattern`/`uses_module` selectors
  # (documented latent bug, out of scope for T4), so those selectors cannot be
  # reached from a real `.anchor.yml`. Injecting sparse rules is the sanctioned
  # workaround (per the T4 brief) and keeps analyzer + selection real.
  use ExUnit.Case, async: true

  import Hammox

  alias Anchor.Check.MustUseModule
  alias Anchor.Config
  alias Anchor.ConfigLoaderMock
  alias Anchor.Domain.Violation
  alias Anchor.Managers.Lint
  alias Credo.SourceFile

  setup :verify_on_exit!

  # MustUseModule is the detection proxy: a SELECTED file that is missing the
  # required module yields exactly one violation, so "one violation" proves the
  # file was selected and "no violations" proves it was filtered out — isolating
  # the selection decision under test.
  defp run(check, source_file, rule) do
    expect(ConfigLoaderMock, :load, fn -> {:ok, %Config{rules: [rule]}} end)
    Lint.run(check, [source_file], [], config_loader: ConfigLoaderMock)
  end

  # Module `pattern` selection (matrix row #4) is the pure-predicate case OWNED
  # and proven by T2's `Anchor.Domain.RuleMatchingTest` (it matches
  # `"App.Schemas.User"` against `"*.Schemas.*"`). Post-BUG-1 (T5) it now selects
  # end-to-end through the REAL composition: `Anchor.Check.Source` unwraps the
  # `{:ok, ast}` tuple and `Anchor.Domain.DependencyAnalyzer.extract_module_names/1`
  # derives the real name `["App.Schemas.User"]`, which the `pattern` selector
  # matches. (Before T5 this PINNED the shadowed `[""]` non-selection.)
  #
  # NOTE: the rule is a SPARSE map (no `:paths` key), so the separate `paths: []`
  # selection-shadow bug (from parsed `.anchor.yml` rules, T2/T3, out of scope
  # here) does not apply — the `pattern` clause is reached and selection is
  # genuinely observable.
  describe "module `pattern` selection through the real acquire (matrix row #4)" do
    @tag row: 4
    test "selects a file whose derived module name matches the pattern (BUG 1 fixed)" do
      source = """
      defmodule App.Schemas.User do
        def x, do: 1
      end
      """

      source_file = SourceFile.parse(source, "lib/user.ex")
      rule = %{type: :must_use_module, pattern: "*.Schemas.*", required_modules: [App.Base]}

      # Selected by module `pattern`; MustUseModule then flags the missing
      # `App.Base` — one violation proves the file was selected.
      assert {:ok, [{^source_file, [%Violation{trigger: "App.Base"}]}]} =
               run(MustUseModule, source_file, rule)
    end
  end

  describe "`uses_module` selection (matrix rows #6/#7)" do
    @tag row: 6
    test "a uses_module rule selects a file that really `use`s the named module" do
      source = """
      defmodule App.Widget do
        use Ecto.Schema
      end
      """

      source_file = SourceFile.parse(source, "lib/widget.ex")
      rule = %{type: :must_use_module, uses_module: "Ecto.Schema", required_modules: [App.Base]}

      assert {:ok, [{^source_file, [%Violation{trigger: "App.Base"}]}]} =
               run(MustUseModule, source_file, rule)
    end

    @tag row: 7
    test "a uses_module rule does NOT select a file lacking that `use`" do
      source = """
      defmodule App.Widget do
        def x, do: 1
      end
      """

      source_file = SourceFile.parse(source, "lib/widget.ex")
      rule = %{type: :must_use_module, uses_module: "Ecto.Schema", required_modules: [App.Base]}

      assert {:ok, [{^source_file, []}]} = run(MustUseModule, source_file, rule)
    end
  end
end
