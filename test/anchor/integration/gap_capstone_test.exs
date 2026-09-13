defmodule Anchor.Integration.GapCapstoneTest do
  # End-to-end capstone (DND-143) proving the four Phase-D capability gaps
  # (D rule-selection, B Erlang-atom targets, A `forbidden_patterns`,
  # A′ `match: call`) compose through the REAL lint pipeline. The pipeline is
  # driven only through its PUBLIC entry `Anchor.Managers.Lint.run/4`, never the
  # Domain functions directly, and every layer below the Manager is REAL:
  #
  #   * config is read and parsed by the REAL Side-Effect adapter
  #     `Anchor.Adapters.ConfigFile.load_from_path/1` (real `File.read` + real
  #     `YamlElixir` decode + real `Anchor.Config.parse_config/1`), off a real
  #     `.anchor.yml`-shaped fixture written to the test's `tmp_dir`;
  #   * AST acquisition goes through the REAL `Anchor.Check.Source` edge;
  #   * fact derivation is the REAL `Anchor.Domain.DependencyAnalyzer`;
  #   * rule selection is the REAL `Anchor.Domain.RuleMatching` / `GlobPattern`;
  #   * detection is the REAL `Anchor.Domain.Checks.NoDependency`.
  #
  # The ONLY injected boundary is the config loader: the Manager depends on the
  # `Anchor.Adapters.ConfigLoader` behaviour (arity-0 `load/0`) and takes the
  # implementation as an option, so the mock's `load/0` simply forwards to the
  # real adapter's `load_from_path/1` for the fixture this test wrote. This is
  # the "no mocks beyond the config loader" contract from the ticket — the parse
  # pipeline these scenarios exercise (`forbidden_patterns`, `match`, the
  # leading-colon atom token, and the paths-absent⇒`nil` Gap-D selection) is the
  # SAME code a production `.anchor.yml` runs through.
  #
  # The per-unit behavior each scenario leans on is OWNED and sabotaged by the
  # upstream unit tickets (Gap D = DND-140, Gap B = DND-141, Gap A/A′ = DND-142);
  # this file proves the COMPOSITION, not new ownership of those rows.
  #
  # Sabotage record: test/sabotage_records/lint-20260913-dnd_143_dogfood_docs_capstone.md
  #
  # Scenario 6 (`mix credo --strict` over Anchor's own tree with the tightened
  # `.anchor.yml` exits 0) is a whole-repo self-check, not a unit of the Lint
  # pipeline against fixtures, so it is covered by the project's `mix credo
  # --strict` green bar rather than duplicated as a nested-`mix` subprocess here.
  use ExUnit.Case, async: true

  import Hammox

  alias Anchor.Adapters.ConfigFile
  alias Anchor.Check.NoDependency
  alias Anchor.ConfigLoaderMock
  alias Anchor.Domain.Violation
  alias Credo.SourceFile

  setup :verify_on_exit!

  # Writes `yaml` to a real `.anchor.yml` under the test's tmp_dir and points the
  # Manager at a loader whose `load/0` forwards to the REAL adapter parse of that
  # file — the only injected boundary. Returns the `Anchor.Managers.Lint.run/4`
  # result for `check` over the single `source_file`.
  defp lint(check, source_file, yaml, tmp_dir) do
    path = Path.join(tmp_dir, ".anchor.yml")
    File.write!(path, yaml)
    expect(ConfigLoaderMock, :load, fn -> ConfigFile.load_from_path(path) end)
    Anchor.Managers.Lint.run(check, [source_file], [], config_loader: ConfigLoaderMock)
  end

  describe "Gap A — forbidden_patterns (module-name glob) through the real pipeline" do
    @tag :tmp_dir
    test "scenario 1: an adapter reference is flagged by a *.Adapters.* pattern", %{
      tmp_dir: tmp_dir
    } do
      yaml = """
      rules:
        - type: no_direct_dependency
          paths:
            - "lib/**/*.ex"
          recursive: true
          forbidden_patterns:
            - "*.Adapters.*"
      """

      source = """
      defmodule App.Contacts.Service do
        def run(x) do
          WaltUi.Contacts.Adapters.Repositories.Repository.all(x)
        end
      end
      """

      source_file = SourceFile.parse(source, "lib/app/contacts/service.ex")

      assert {:ok,
              [
                {^source_file,
                 [%Violation{trigger: "WaltUi.Contacts.Adapters.Repositories.Repository"}]}
              ]} = lint(NoDependency, source_file, yaml, tmp_dir)
    end

    @tag :tmp_dir
    test "scenario 2 (positive control): Domain-only file passes; helper substring not matched",
         %{tmp_dir: tmp_dir} do
      yaml = """
      rules:
        - type: no_direct_dependency
          paths:
            - "lib/**/*.ex"
          recursive: true
          forbidden_patterns:
            - "*.Adapters.*"
      """

      # `WaltUi.Contacts.Domain.Foo` has no `.Adapters.` segment; `Foo.AdaptersHelper`
      # has no dot AFTER `Adapters`, so the dot-bounded `*.Adapters.*` does NOT match
      # it (proves the pattern is not a bare substring match).
      source = """
      defmodule App.Contacts.Cleaner do
        def run(x) do
          WaltUi.Contacts.Domain.Foo.clean(x)
          Foo.AdaptersHelper.help(x)
        end
      end
      """

      source_file = SourceFile.parse(source, "lib/app/contacts/cleaner.ex")

      assert {:ok, [{^source_file, []}]} = lint(NoDependency, source_file, yaml, tmp_dir)
    end
  end

  describe "Gap A′ — match: call carve-out through the real pipeline" do
    @tag :tmp_dir
    test "scenario 3a: an adapter held as an inert map value passes under match: call", %{
      tmp_dir: tmp_dir
    } do
      yaml = """
      rules:
        - type: no_direct_dependency
          paths:
            - "lib/**/*.ex"
          recursive: true
          match: call
          forbidden_patterns:
            - "*.Adapters.*"
      """

      # The router HOLDS the adapter module as a map value but never CALLS it, so
      # under `match: call` it is not a call dependency and is not flagged.
      source = """
      defmodule App.Domain.Router do
        @adapters %{enrich: Foo.Adapters.Loader}
        def adapter, do: @adapters[:enrich]
      end
      """

      source_file = SourceFile.parse(source, "lib/app/domain/router.ex")

      assert {:ok, [{^source_file, []}]} = lint(NoDependency, source_file, yaml, tmp_dir)
    end

    @tag :tmp_dir
    test "scenario 3b: the same adapter in call position IS flagged under match: call", %{
      tmp_dir: tmp_dir
    } do
      yaml = """
      rules:
        - type: no_direct_dependency
          paths:
            - "lib/**/*.ex"
          recursive: true
          match: call
          forbidden_patterns:
            - "*.Adapters.*"
      """

      source = """
      defmodule App.Domain.Enricher do
        def run(x) do
          Foo.Adapters.Loader.enrich(x)
        end
      end
      """

      source_file = SourceFile.parse(source, "lib/app/domain/enricher.ex")

      assert {:ok, [{^source_file, [%Violation{trigger: "Foo.Adapters.Loader"}]}]} =
               lint(NoDependency, source_file, yaml, tmp_dir)
    end
  end

  describe "Gap B — Erlang-atom module target through the real pipeline" do
    @tag :tmp_dir
    test "scenario 4: a leading-colon :telemetry token flags a bare-atom remote call", %{
      tmp_dir: tmp_dir
    } do
      # The leading-colon token is quoted so YAML keeps it a string;
      # `Anchor.Config.parse_rule/1` turns `":telemetry"` into the raw atom
      # `:telemetry` (NOT `Module.concat`), which matches `:telemetry.execute(...)`.
      yaml = """
      rules:
        - type: no_direct_dependency
          paths:
            - "lib/**/*.ex"
          recursive: true
          forbidden_modules:
            - ":telemetry"
      """

      source = """
      defmodule App.Telemetry.Reporter do
        def report do
          :telemetry.execute([:a], %{}, %{})
        end
      end
      """

      source_file = SourceFile.parse(source, "lib/app/telemetry/reporter.ex")

      assert {:ok, [{^source_file, [%Violation{trigger: ":telemetry"}]}]} =
               lint(NoDependency, source_file, yaml, tmp_dir)
    end
  end

  describe "Gap D — pattern selection with paths absent, through the real parse" do
    @tag :tmp_dir
    test "scenario 5: a pattern-selected rule (no paths key) selects and reports", %{
      tmp_dir: tmp_dir
    } do
      # No `paths:` key. Through the REAL `Anchor.Config.parse_rule/1` this parses
      # to `paths: nil` (Gap D). Before Gap D the parser stamped `paths: []`, which
      # shadowed the `pattern` selector and this rule would NEVER select a file
      # from a real `.anchor.yml`. This scenario is the end-to-end proof that Gap D
      # unblocks pattern-based selection through the whole loader+selection compose.
      yaml = """
      rules:
        - type: no_direct_dependency
          pattern: "*.Domain.*"
          forbidden_patterns:
            - "*.Adapters.*"
      """

      source = """
      defmodule App.Domain.Thing do
        def run(x) do
          WaltUi.Billing.Adapters.Client.charge(x)
        end
      end
      """

      source_file = SourceFile.parse(source, "lib/app/domain/thing.ex")

      assert {:ok, [{^source_file, [%Violation{trigger: "WaltUi.Billing.Adapters.Client"}]}]} =
               lint(NoDependency, source_file, yaml, tmp_dir)
    end
  end
end
