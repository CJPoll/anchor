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
  alias Anchor.Check.NoDependency
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

    test "propagates {:error, reason} when the loader fails (the Framework reports it)" do
      source_file = SourceFile.parse("defmodule X do\nend\n", "lib/x.ex")

      expect(ConfigLoaderMock, :load, fn -> {:error, {:config_not_found, ["/p/.anchor.yml"]}} end)

      assert {:error, {:config_not_found, ["/p/.anchor.yml"]}} =
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
      # A is selected by `uses_module` (which composes end-to-end). Post-BUG-1
      # (T5): `Anchor.Check.Source` unwraps the `{:ok, ast}` tuple, so the
      # derived module names are real and `build_modules_map/2` registers
      # `A -> [B]` and `B -> [MyApp.Repo]`. A's transitive closure therefore
      # reaches the forbidden `MyApp.Repo` (chain `A -> B -> MyApp.Repo`) and A's
      # file is flagged; B is not selected by the `uses_module` rule, so it stays
      # clean. (Before T5 both files were `[]` because the graph was empty.)
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

      assert {:ok, [{^file_a, [violation]}, {^file_b, []}]} =
               Lint.run(NoTransitiveDependency, [file_a, file_b], [],
                 config_loader: ConfigLoaderMock
               )

      assert %Violation{trigger: "MyApp.Repo", line: 3} = violation

      assert violation.message ==
               "Module has transitive dependency on forbidden module MyApp.Repo " <>
                 "(dependency chain: A -> B -> MyApp.Repo)"
    end
  end

  # Gap F (DND-150): the Manager threads the file's own `module_names` (computed
  # once, reused for both rule selection and the check context) into the check
  # context, so `same_context` detection can derive the file's context.
  #
  # Matrix: docs/gap-f-same-context-test-matrix.md
  #   "lib/anchor/managers/lint.ex -> run/4 -> #1-3".
  #
  # Sabotage record:
  #   ../../sabotage_records/no_dependency-20260913-dnd_150_a2_same_context_detection.md
  describe "run/4 same_context context plumbing (Gap F)" do
    # Matrix row 1 — Happy Path: the file's module names reach the check context,
    # so a same-context dep is scoped and flagged. If `module_names` were NOT
    # threaded the check would derive a nil file context and report nothing, so a
    # violation here proves the plumbing.
    test "threads the file's module names into the check context so scoping runs" do
      source = """
      defmodule WaltUi.Contacts.Adapters.Foo do
        def f, do: WaltUi.Contacts.Managers.Bar.run(x)
      end
      """

      source_file = SourceFile.parse(source, "lib/foo.ex")

      rule = %{
        type: :no_direct_dependency,
        pattern: "*.Adapters.*",
        forbidden_modules: [],
        forbidden_patterns: ["*.Managers.*"],
        match: :call,
        same_context: true,
        context_depth: 2
      }

      expect(ConfigLoaderMock, :load, fn -> {:ok, %Config{rules: [rule]}} end)

      assert {:ok, [{^source_file, [%Violation{trigger: "WaltUi.Contacts.Managers.Bar"}]}]} =
               Lint.run(NoDependency, [source_file], [], config_loader: ConfigLoaderMock)
    end

    # Matrix row 2 — Control Flow: rule selection is unchanged after facts are
    # computed once. The pattern rule selects the matching file and skips the
    # other; the selected file's cross-context dep is (correctly) not flagged, and
    # the unselected file gets [] — i.e. selection still partitions the files.
    test "rule selection is unchanged (facts computed once)" do
      selected =
        SourceFile.parse(
          "defmodule WaltUi.Contacts.Adapters.Foo do\n  def f, do: WaltUi.Contacts.Managers.Bar.run(x)\nend\n",
          "lib/foo.ex"
        )

      unselected =
        SourceFile.parse("defmodule WaltUi.Plain do\n  def x, do: 1\nend\n", "lib/plain.ex")

      rule = %{
        type: :no_direct_dependency,
        pattern: "*.Adapters.*",
        forbidden_modules: [],
        forbidden_patterns: ["*.Managers.*"],
        match: :call,
        same_context: true,
        context_depth: 2
      }

      expect(ConfigLoaderMock, :load, fn -> {:ok, %Config{rules: [rule]}} end)

      assert {:ok,
              [
                {^selected, [%Violation{trigger: "WaltUi.Contacts.Managers.Bar"}]},
                {^unselected, []}
              ]} =
               Lint.run(NoDependency, [selected, unselected], [], config_loader: ConfigLoaderMock)
    end

    # Matrix row 3 — Control Flow: a non-same_context check is unaffected by the
    # threading — identical {:ok, results} to the pre-feature path.
    test "a non-same_context check is unaffected" do
      source = """
      defmodule MyApp.Thing do
        def f, do: MyApp.Repo.all(q)
      end
      """

      source_file = SourceFile.parse(source, "lib/thing.ex")

      rule = %{
        type: :no_direct_dependency,
        pattern: "*MyApp.*",
        forbidden_modules: [MyApp.Repo],
        forbidden_patterns: [],
        match: :reference
      }

      expect(ConfigLoaderMock, :load, fn -> {:ok, %Config{rules: [rule]}} end)

      assert {:ok, [{^source_file, [%Violation{trigger: "MyApp.Repo", line: 2}]}]} =
               Lint.run(NoDependency, [source_file], [], config_loader: ConfigLoaderMock)
    end
  end

  # DND-1265: a file Anchor cannot parse is reported, never silently skipped.
  # Sabotage record: ../../sabotage_records/lint-20260929-dnd_1265_anchor_fail_closed.md
  # Sabotage record (the parse error's line and text): ../../sabotage_records/source-20260929-dnd_1265_anchor_fail_closed.md
  describe "run/4 unparseable source file" do
    setup do
      broken = SourceFile.parse("defmodule Broken do\n  def go(\nend\n", "lib/broken.ex")

      rule = %{
        type: :must_use_module,
        paths: ["lib/*.ex"],
        recursive: false,
        required_modules: [MyApp.Base]
      }

      {:ok, broken: broken, rule: rule}
    end

    test "the shared-failure reporter gets a parse violation for the file", %{
      broken: broken,
      rule: rule
    } do
      expect(ConfigLoaderMock, :load, fn -> {:ok, %Config{rules: [rule]}} end)

      assert {:ok, [{^broken, [%Violation{} = violation]}]} =
               Lint.run(MustUseModule, [broken], [], config_loader: ConfigLoaderMock)

      assert violation.message =~ "could not parse"
      assert violation.message =~ "Fix:"
      assert is_integer(violation.line)
    end

    test "a non-reporter check gets no violation, and no detection runs on it", %{
      broken: broken,
      rule: rule
    } do
      expect(ConfigLoaderMock, :load, fn -> {:ok, %Config{rules: [rule]}} end)

      assert {:ok, [{^broken, []}]} =
               Lint.run(MustUseModule, [broken], [],
                 config_loader: ConfigLoaderMock,
                 report_shared_failures: false
               )
    end

    test "a graph-needing check builds its graph from the parseable files only", %{
      broken: broken
    } do
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

      assert {:ok,
              [
                {^broken, [%Violation{kind: :fail_closed}]},
                {^file_a, [%Violation{trigger: "MyApp.Repo"}]},
                {^file_b, []}
              ]} =
               Lint.run(NoTransitiveDependency, [broken, file_a, file_b], [],
                 config_loader: ConfigLoaderMock
               )
    end

    test "parseable files in the same run are still checked", %{broken: broken, rule: rule} do
      good = SourceFile.parse("defmodule Good do\nend\n", "lib/good.ex")
      expect(ConfigLoaderMock, :load, fn -> {:ok, %Config{rules: [rule]}} end)

      assert {:ok, [{^broken, [_parse_violation]}, {^good, [%Violation{trigger: "MyApp.Base"}]}]} =
               Lint.run(MustUseModule, [broken, good], [], config_loader: ConfigLoaderMock)
    end
  end

  # DND-1290 (folds in DND-1268, T5): a rule that selects fewer files than its
  # floor checked nothing, or less than it says, and used to read green. The
  # floor is `min_files` (default 1). Load time cannot decide it (it depends on
  # the file set), so the Manager reports it as a `:fail_closed` violation on the
  # config file, in a `{:config, violations}` entry after the per-file results.
  # Each check reports the floors of its own type's rules, over the files it ran
  # on, so each floor is reported once per run.
  # Sabotage record: ../../sabotage_records/lint-20260929-dnd_1290_empty_relation_list.md
  describe "run/4 selection floor (min_files)" do
    setup do
      thing =
        SourceFile.parse("defmodule MyApp.Thing do\n  use Ecto.Schema\nend\n", "lib/thing.ex")

      other = SourceFile.parse("defmodule MyApp.Other do\nend\n", "lib/other.ex")
      {:ok, thing: thing, other: other}
    end

    test "a rule that selects no file is one fail-closed violation on the config", %{
      thing: thing
    } do
      rule = %{
        type: :must_use_module,
        index: 2,
        id: "contexts",
        paths: ["lib/contexts/**/*.ex"],
        recursive: true,
        required_modules: [MyApp.Base]
      }

      expect(ConfigLoaderMock, :load, fn ->
        {:ok, %Config{rules: [rule], path: "/p/.anchor.yml"}}
      end)

      assert {:ok, [{^thing, []}, {:config, [violation]}]} =
               Lint.run(MustUseModule, [thing], [], config_loader: ConfigLoaderMock)

      assert %Violation{kind: :fail_closed, filename: "/p/.anchor.yml"} = violation
      assert violation.message =~ ~s|rule 2 (id: "contexts", must_use_module) selected 0 of|
      assert violation.message =~ "so it checked nothing"
      assert violation.message =~ ~r/Fix: [^\n]+\z/
    end

    test "min_files raises the floor", %{thing: thing, other: other} do
      rule = %{
        type: :must_use_module,
        index: 1,
        min_files: 3,
        paths: ["lib/*.ex"],
        recursive: false,
        required_modules: [Ecto.Schema]
      }

      expect(ConfigLoaderMock, :load, fn -> {:ok, %Config{rules: [rule]}} end)

      assert {:ok, [{^thing, []}, {^other, [_missing_use]}, {:config, [violation]}]} =
               Lint.run(MustUseModule, [thing, other], [], config_loader: ConfigLoaderMock)

      assert violation.message =~ "selected 2 of the 2 files"
      assert violation.message =~ "below its floor of 3 (min_files)"
      # With no config path known, the violation sits on the default name.
      assert violation.filename == ".anchor.yml"
    end

    test "a rule at its floor reports nothing", %{thing: thing, other: other} do
      rule = %{
        type: :must_use_module,
        min_files: 2,
        paths: ["lib/*.ex"],
        recursive: false,
        required_modules: [Ecto.Schema]
      }

      expect(ConfigLoaderMock, :load, fn -> {:ok, %Config{rules: [rule]}} end)

      assert {:ok, [{^thing, []}, {^other, [_missing_use]}]} =
               Lint.run(MustUseModule, [thing, other], [], config_loader: ConfigLoaderMock)
    end

    test "a module-selector rule counts the files it selects", %{thing: thing, other: other} do
      rule = %{type: :must_use_module, pattern: "MyApp.Nope.*", required_modules: [MyApp.Base]}

      expect(ConfigLoaderMock, :load, fn -> {:ok, %Config{rules: [rule]}} end)

      assert {:ok, [_, _, {:config, [violation]}]} =
               Lint.run(MustUseModule, [thing, other], [], config_loader: ConfigLoaderMock)

      assert violation.message =~ "(must_use_module) selected 0 of the 2 files"
    end

    test "another type's rule is not this check's floor", %{thing: thing} do
      rule = %{type: :no_direct_dependency, pattern: "Nope.*", forbidden_modules: [MyApp.Repo]}

      expect(ConfigLoaderMock, :load, fn -> {:ok, %Config{rules: [rule]}} end)

      assert {:ok, [{^thing, []}]} =
               Lint.run(MustUseModule, [thing], [], config_loader: ConfigLoaderMock)
    end

    test "a partial file set (enforce_selection_floors: false) reports no floor", %{
      thing: thing
    } do
      rule = %{type: :must_use_module, pattern: "Nope.*", required_modules: [MyApp.Base]}

      expect(ConfigLoaderMock, :load, fn -> {:ok, %Config{rules: [rule]}} end)

      assert {:ok, [{^thing, []}]} =
               Lint.run(MustUseModule, [thing], [],
                 config_loader: ConfigLoaderMock,
                 enforce_selection_floors: false
               )
    end

    test "an unparseable file still counts toward a paths rule's floor" do
      broken = SourceFile.parse("defmodule Broken do\n  def go(\nend\n", "lib/broken.ex")

      rule = %{
        type: :must_use_module,
        paths: ["lib/*.ex"],
        recursive: false,
        required_modules: [MyApp.Base]
      }

      expect(ConfigLoaderMock, :load, fn -> {:ok, %Config{rules: [rule]}} end)

      assert {:ok, [{^broken, [%Violation{kind: :fail_closed}]}]} =
               Lint.run(MustUseModule, [broken], [], config_loader: ConfigLoaderMock)
    end
  end

  # DND-1290: a rule whose type no enabled check reads loads and checks nothing.
  # The run's shared-failure reporter names it, when the Framework knows the
  # enabled types (`enabled_rule_types`); `:unknown` reports nothing.
  describe "run/4 a rule no enabled check reads" do
    setup do
      thing =
        SourceFile.parse("defmodule MyApp.Thing do\n  use Ecto.Schema\nend\n", "lib/thing.ex")

      rule = %{
        type: :single_control_flow,
        index: 3,
        paths: ["lib/*.ex"],
        recursive: false
      }

      {:ok, thing: thing, rule: rule}
    end

    test "the reporter names it as one fail-closed violation", %{thing: thing, rule: rule} do
      expect(ConfigLoaderMock, :load, fn -> {:ok, %Config{rules: [rule]}} end)

      assert {:ok, [{^thing, []}, {:config, [violation]}]} =
               Lint.run(MustUseModule, [thing], [],
                 config_loader: ConfigLoaderMock,
                 enabled_rule_types: [:must_use_module],
                 checks_by_type: %{single_control_flow: Anchor.Check.SingleControlFlow}
               )

      assert %Violation{kind: :fail_closed} = violation
      assert violation.message =~ "rule 3 (single_control_flow) is not checked"
      assert violation.message =~ "Anchor.Check.SingleControlFlow"
      assert violation.message =~ "Fix:"
    end

    test "a non-reporter check does not name it", %{thing: thing, rule: rule} do
      expect(ConfigLoaderMock, :load, fn -> {:ok, %Config{rules: [rule]}} end)

      assert {:ok, [{^thing, []}]} =
               Lint.run(MustUseModule, [thing], [],
                 config_loader: ConfigLoaderMock,
                 report_shared_failures: false,
                 enabled_rule_types: [:must_use_module]
               )
    end

    test "unknown enabled types report nothing", %{thing: thing, rule: rule} do
      expect(ConfigLoaderMock, :load, fn -> {:ok, %Config{rules: [rule]}} end)

      assert {:ok, [{^thing, []}]} =
               Lint.run(MustUseModule, [thing], [], config_loader: ConfigLoaderMock)
    end
  end
end
