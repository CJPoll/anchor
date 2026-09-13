defmodule Anchor.Managers.LintTest do
  # Unit tests for the Manager. The config-loading port is a Hammox mock injected
  # via the `:config_loader` option, and every test uses `expect/3` (not
  # `stub/3`) so the load call self-proves on exit (ADR 002): delete the
  # `config_loader.load()` call from the Manager and these tests fail on the
  # unmet expectation, not just on a wrong return value.
  #
  # The rules are built directly as sparse maps (no `:paths` key). Rules parsed
  # from a real `.anchor.yml` are stamped with `paths: []` by
  # `Anchor.Config.parse_rule/1`, which shadows the `pattern`/`uses_module`
  # selectors (documented latent bug, out of scope for T4). Injecting sparse
  # rules is the sanctioned way to exercise those selectors — see the Manager's
  # rule-selection path — while keeping the analyzer and selection code real.
  use ExUnit.Case, async: true

  import Hammox

  alias Anchor.Check.MustUseModule
  alias Anchor.Check.NoTransitiveDependency
  alias Anchor.Config
  alias Anchor.ConfigLoaderMock
  alias Anchor.Domain.Violation
  alias Anchor.Managers.Lint
  alias Credo.SourceFile

  setup :verify_on_exit!

  describe "run/4 config loading through the behaviour" do
    test "loads config via the injected loader and returns per-file violations" do
      source = """
      defmodule MyApp.Thing do
        use Ecto.Schema
      end
      """

      source_file = SourceFile.parse(source, "lib/thing.ex")
      rule = %{type: :must_use_module, uses_module: "Ecto.Schema", required_modules: [MyApp.Base]}

      expect(ConfigLoaderMock, :load, fn -> {:ok, %Config{rules: [rule]}} end)

      assert {:ok, [{returned_file, violations}]} =
               Lint.run(MustUseModule, [source_file], [], config_loader: ConfigLoaderMock)

      assert returned_file == source_file

      assert [%Violation{trigger: "MyApp.Base", line: 1, message: "Module must use MyApp.Base"}] =
               violations
    end

    test "propagates {:error, reason} when the loader fails (checks are skipped)" do
      source_file = SourceFile.parse("defmodule X do\nend\n", "lib/x.ex")

      expect(ConfigLoaderMock, :load, fn -> {:error, {:config_load_failed, :enoent}} end)

      assert {:error, {:config_load_failed, :enoent}} =
               Lint.run(MustUseModule, [source_file], [], config_loader: ConfigLoaderMock)
    end
  end

  describe "run/4 rule selection" do
    test "a rule whose type is not the check's rule_type is not selected" do
      source = """
      defmodule MyApp.Thing do
        use Ecto.Schema
      end
      """

      source_file = SourceFile.parse(source, "lib/thing.ex")
      # Right selector, WRONG type: must be filtered out before detection.
      rule = %{
        type: :no_direct_dependency,
        uses_module: "Ecto.Schema",
        forbidden_modules: [MyApp.Repo]
      }

      expect(ConfigLoaderMock, :load, fn -> {:ok, %Config{rules: [rule]}} end)

      assert {:ok, [{_file, []}]} =
               Lint.run(MustUseModule, [source_file], [], config_loader: ConfigLoaderMock)
    end

    test "pairs every source file with its violations (unselected file gets [])" do
      selected =
        SourceFile.parse("defmodule MyApp.Thing do\n  use Ecto.Schema\nend\n", "lib/thing.ex")

      unselected =
        SourceFile.parse("defmodule MyApp.Plain do\n  def x, do: 1\nend\n", "lib/plain.ex")

      rule = %{type: :must_use_module, uses_module: "Ecto.Schema", required_modules: [MyApp.Base]}

      expect(ConfigLoaderMock, :load, fn -> {:ok, %Config{rules: [rule]}} end)

      assert {:ok, results} =
               Lint.run(MustUseModule, [selected, unselected], [],
                 config_loader: ConfigLoaderMock
               )

      assert [{^selected, [%Violation{trigger: "MyApp.Base"}]}, {^unselected, []}] = results
    end
  end

  describe "run/4 module-graph construction" do
    test "only checks that need the cross-file graph declare needs_module_graph?/0" do
      # This is the switch the Manager branches on to decide whether to build the
      # graph. No loader is involved.
      assert NoTransitiveDependency.needs_module_graph?()
      refute MustUseModule.needs_module_graph?()
    end

    test "runs a graph-needing check and hands it the module graph via context" do
      # NoTransitiveDependency declares needs_module_graph?/0 => true, so the
      # Manager builds the graph from ALL files and passes it in
      # `context.modules_map`. Detection reads `context.modules_map` directly, so
      # a missing key would raise KeyError here — reaching `{:ok, ...}` proves the
      # plumbing.
      #
      # A is selected by `uses_module` (which composes end-to-end). This PINS
      # current behavior: under BUG 1 the derived module names are nil (the
      # `{:ok, ast}` wrapping), so the built graph is effectively empty and no
      # transitive dependency is found — hence `[]` per file today. A future
      # BUG 1 fix will flip A's file to a `MyApp.Repo` violation.
      file_a =
        SourceFile.parse(
          "defmodule A do\n  use SelectMe\n  def go, do: B.call()\nend\n",
          "lib/a.ex"
        )

      file_b =
        SourceFile.parse("defmodule B do\n  def call, do: MyApp.Repo.query()\nend\n", "lib/b.ex")

      rule = %{
        type: :no_transitive_dependency,
        uses_module: "SelectMe",
        forbidden_modules: [MyApp.Repo]
      }

      expect(ConfigLoaderMock, :load, fn -> {:ok, %Config{rules: [rule]}} end)

      assert {:ok, [{^file_a, []}, {^file_b, []}]} =
               Lint.run(NoTransitiveDependency, [file_a, file_b], [],
                 config_loader: ConfigLoaderMock
               )
    end
  end
end
