defmodule Anchor.E2E.ChecksE2ETest do
  # End-to-end harness for Anchor's config-driven checks (T1 / DND-121).
  #
  # Unlike the per-check characterization tests, which call `check_file/3`
  # directly with a hand-built rule map, this harness drives the REAL entry
  # point that Credo itself invokes: `run_on_all_source_files/3`. That path
  #
  #   * loads rules from a real `.anchor.yml` on disk via `Anchor.Config.load/0`
  #     (so rule PARSING and rule SELECTION by `paths`/`recursive` are exercised,
  #     not bypassed), and
  #   * feeds each check a real `Credo.SourceFile` and drives the whole check
  #     entry point, so rules come from a parsed on-disk config and dispatch runs
  #     exactly as Credo runs it. The AST arrives as
  #     `Credo.Code.ast(source_file) => {:ok, ast}` — the `{:ok, ast}`-wrapped
  #     shape production sees, and the seam where the latent BUG 1 (analysis over
  #     the wrapped tuple) hides. (The direct `check_file/3` characterization
  #     tests also route through `Credo.Code.ast/1` and see the same wrapped
  #     tuple; what is unique here is exercising `run_on_all_source_files/3` and
  #     `Config.load/0` rule selection end to end, not just `check_file/3`.)
  #     These tests PIN current behavior; they intentionally stay green even
  #     where that behavior is later adjudged wrong.
  #
  # We use `Credo.Test.Case` only for `to_source_file/2` and `run_check/2`, and
  # assert on the returned issue list with plain ExUnit assertions. Credo
  # 1.7.12's own `assert_issue/2`/`assert_issues/2` are avoided on purpose: they
  # eagerly build an error message via `to_inspected/1`, whose
  # `Inspect.Algebra.format/2` path raises under Elixir 1.19 whenever a real
  # issue is present. That is an environmental incompatibility in the helper,
  # not in the checks.
  #
  # `async: false` because each case briefly `File.cd/1`s into a temp directory
  # so `Anchor.Config.load/0` (which reads `.anchor.yml` from the cwd) picks up
  # the fixture config. No production code reads the cwd during other tests, and
  # ExUnit runs sync modules in isolation, so the cwd change is safe.
  use Credo.Test.Case, async: false

  alias Anchor.Check.ModulePatternRestrictions
  alias Anchor.Check.MustUseModule
  alias Anchor.Check.NoDependency

  # DND-1267: a function-level rule, from YAML to Credo issue, with no mocks.
  describe "forbidden_functions through the real pipeline" do
    @functions_yaml """
    rules:
      - type: no_direct_dependency
        paths:
          - "lib/**/*.ex"
        recursive: true
        forbidden_functions:
          - "Athena.Slack.user_info"
          - "Athena.Slack.rule_post/2"
    """

    test "flags aliased, imported, delegated and captured calls; not other functions" do
      source = """
      defmodule MyApp.Priorities.Thing do
        alias Athena.Slack
        import Athena.Slack, only: [rule_post: 2]

        defdelegate lookup(id), to: Athena.Slack, as: :user_info

        def a(id), do: Slack.user_info(id)
        def b(x), do: x |> rule_post(:c)
        def c, do: &Slack.rule_post/2
        def d(id), do: Slack.workspace_url(id)
        def e(x), do: Slack.rule_post(x)
      end
      """

      issues =
        with_anchor_config(@functions_yaml, fn ->
          [to_source_file(source, "lib/priorities/thing.ex")]
          |> run_check(NoDependency)
        end)

      # One issue per function reached, at its first line (as a module-level
      # rule reports each module once). The per-shape table is
      # Anchor.Domain.Checks.NoDependencyForbiddenFunctionsTest.
      assert issues |> Enum.map(&{&1.line_no, &1.trigger}) |> Enum.sort() == [
               {5, "Athena.Slack.user_info/1"},
               {8, "Athena.Slack.rule_post/2"}
             ]
    end
  end

  # DND-1269: G1 of the DND-1263 design, from YAML to Credo issue, with no mocks.
  describe "allowed_callers through the real pipeline" do
    @allowed_yaml """
    rules:
      - type: no_direct_dependency
        id: slack-name-reads-single-caller
        paths:
          - "lib/**/*.ex"
        recursive: true
        match: call
        forbidden_modules:
          - Athena.Slack.Internal
        forbidden_functions:
          - "Athena.Slack.user_info"
        allowed_callers:
          - Athena.Priorities.SlackNameAdapter
    """

    test "only the allowed caller may call; a second module in its file may not" do
      source = """
      defmodule Athena.Priorities.SlackNameAdapter do
        alias Athena.Slack
        def user(id), do: Slack.user_info(id)
        def raw(id), do: Athena.Slack.Internal.get(id)
      end

      defmodule Athena.Priorities.Sneaky do
        def user(id), do: Athena.Slack.user_info(id)
      end
      """

      issues =
        with_anchor_config(@allowed_yaml, fn ->
          all_issues(
            [to_source_file(source, "lib/priorities/slack_name_adapter.ex")],
            NoDependency
          )
        end)

      assert Enum.map(issues, &{&1.line_no, &1.trigger}) == [{8, "Athena.Slack.user_info/1"}]
    end

    test "a renamed allowed caller is one issue on the config file" do
      source = """
      defmodule Athena.Priorities.SlackNames do
        def user(id), do: Athena.Slack.user_info(id)
      end
      """

      {issues, dir} =
        with_anchor_config(@allowed_yaml, fn ->
          {all_issues([to_source_file(source, "lib/priorities/slack_names.ex")], NoDependency),
           File.cwd!()}
        end)

      assert [config_issue] = Enum.filter(issues, &(&1.filename == Path.join(dir, ".anchor.yml")))

      assert config_issue.message =~
               "lists Athena.Priorities.SlackNameAdapter in allowed_callers, but no file it selects defines it"

      assert config_issue.message =~ ~r/Fix: [^\n]+\z/
      assert Enum.any?(issues, &(&1.trigger == "Athena.Slack.user_info/1"))
    end
  end

  describe "NoDependency through the real pipeline" do
    @yaml """
    rules:
      - type: no_direct_dependency
        paths:
          - "lib/**/*.ex"
        forbidden_modules:
          - MyApp.Repo
        recursive: true
    """

    test "flags a forbidden direct dependency in a selected file" do
      source = """
      defmodule MyApp.Domain.Thing do
        def go, do: MyApp.Repo.all(Q)
      end
      """

      issues =
        with_anchor_config(@yaml, fn ->
          [to_source_file(source, "lib/domain/thing.ex")]
          |> run_check(NoDependency)
        end)

      assert [issue] = issues
      assert issue.trigger == "MyApp.Repo"
      assert issue.message == "Module has forbidden direct dependency on MyApp.Repo"
      assert issue.line_no == 2
    end

    test "a clean selected file produces no issues" do
      source = """
      defmodule MyApp.Domain.Clean do
        def go, do: :ok
      end
      """

      issues =
        with_anchor_config(@yaml, fn ->
          [to_source_file(source, "lib/domain/clean.ex")]
          |> run_check(NoDependency)
        end)

      assert issues == []
    end

    test "a file whose path the rule does not select produces no issues" do
      # `paths: ["lib/**/*.ex"]` does not select a test/ file, so rule selection
      # in Anchor.Check.Base filters it out before check_file/3 ever runs.
      # DND-1290: the run also holds a clean selected file, so the rule meets its
      # floor of one selected file; a rule that selects nothing is its own issue
      # (see "selection floor" below).
      source = """
      defmodule SomeTest do
        def go, do: MyApp.Repo.all(Q)
      end
      """

      clean = "defmodule MyApp.Domain.Clean do\n  def go, do: :ok\nend\n"

      issues =
        with_anchor_config(@yaml, fn ->
          [
            to_source_file(source, "test/domain/some_test.ex"),
            to_source_file(clean, "lib/domain/clean.ex")
          ]
          |> run_check(NoDependency)
        end)

      assert issues == []
    end

    test "reports one issue per distinct forbidden module in a selected file" do
      yaml = """
      rules:
        - type: no_direct_dependency
          paths:
            - "lib/**/*.ex"
          forbidden_modules:
            - MyApp.Repo
            - MyApp.Mailer
          recursive: true
      """

      source = """
      defmodule MyApp.Domain.Multi do
        def go do
          MyApp.Repo.all(Q)
          MyApp.Mailer.send(M)
        end
      end
      """

      issues =
        with_anchor_config(yaml, fn ->
          [to_source_file(source, "lib/domain/multi.ex")]
          |> run_check(NoDependency)
        end)

      triggers = issues |> Enum.map(& &1.trigger) |> Enum.sort()
      assert triggers == ["MyApp.Mailer", "MyApp.Repo"]
    end
  end

  describe "MustUseModule through the real pipeline" do
    @use_yaml """
    rules:
      - type: must_use_module
        paths:
          - "lib/**/*.ex"
        required_modules:
          - MyApp.Schema
        recursive: true
    """

    test "flags a selected file that is missing the required use" do
      source = """
      defmodule MyApp.Widget do
        def x, do: 1
      end
      """

      issues =
        with_anchor_config(@use_yaml, fn ->
          [to_source_file(source, "lib/widget.ex")]
          |> run_check(MustUseModule)
        end)

      assert [issue] = issues
      assert issue.trigger == "MyApp.Schema"
      assert issue.message == "Module must use MyApp.Schema"
    end

    test "a selected file that has the required use produces no issues" do
      source = """
      defmodule MyApp.Widget do
        use MyApp.Schema
        def x, do: 1
      end
      """

      issues =
        with_anchor_config(@use_yaml, fn ->
          [to_source_file(source, "lib/widget.ex")]
          |> run_check(MustUseModule)
        end)

      assert issues == []
    end
  end

  # DND-1265: Anchor fails closed. A run that could not check anything reports
  # that as a Credo issue carrying a `Fix:` line, never an empty issue list.
  # These rows read EVERY issue in the execution (`all_issues/2`), because the
  # config issues sit on the config path, not on a checked source file.
  #
  # Sabotage record: ../../sabotage_records/base-20260929-dnd_1265_anchor_fail_closed.md
  # Sabotage record (the parse error's line and text): ../../sabotage_records/source-20260929-dnd_1265_anchor_fail_closed.md
  describe "no configuration present (A6)" do
    test "reports one issue naming the searched path, with a Fix: line" do
      source = """
      defmodule MyApp.Domain.Thing do
        def go, do: MyApp.Repo.all(Q)
      end
      """

      {issues, dir} =
        with_anchor_config(nil, fn ->
          {all_issues([to_source_file(source, "lib/domain/thing.ex")], NoDependency), File.cwd!()}
        end)

      searched = Path.join(dir, ".anchor.yml")
      assert [issue] = issues
      assert issue.filename == searched
      assert issue.message =~ "Searched: #{searched}"
      assert issue.message =~ "Fix:"
      assert issue.check == NoDependency
      # Raised so Credo shows it without --strict.
      assert issue.priority == Credo.Priority.to_integer(:higher)
    end
  end

  describe "config load error (A7)" do
    test "malformed YAML is one issue on the config file, not a skip" do
      {issues, dir} =
        with_anchor_config("rules: [unterminated", fn ->
          {all_issues([to_source_file("defmodule A do\nend\n", "lib/a.ex")], NoDependency),
           File.cwd!()}
        end)

      assert [issue] = issues
      assert issue.filename == Path.join(dir, ".anchor.yml")
      assert issue.message =~ "YAML"
      assert issue.message =~ "Fix:"
    end

    test "an unknown rule type (A8) is one issue on the config file" do
      yaml = """
      rules:
        - type: no_direct_dependancy
          paths:
            - "lib/**/*.ex"
          forbidden_modules:
            - MyApp.Repo
          recursive: true
      """

      source = """
      defmodule MyApp.Domain.Thing do
        def go, do: MyApp.Repo.all(Q)
      end
      """

      {issues, dir} =
        with_anchor_config(yaml, fn ->
          {all_issues([to_source_file(source, "lib/domain/thing.ex")], NoDependency), File.cwd!()}
        end)

      assert [issue] = issues
      assert issue.filename == Path.join(dir, ".anchor.yml")
      assert issue.message =~ ~s("no_direct_dependancy")
      assert issue.message =~ "Fix:"
    end

    test "an unknown match token (A9) is one issue on the config file" do
      yaml = """
      rules:
        - type: no_direct_dependency
          paths:
            - "lib/**/*.ex"
          forbidden_modules:
            - MyApp.Repo
          match: calls
          recursive: true
      """

      issues =
        with_anchor_config(yaml, fn ->
          all_issues([to_source_file("defmodule A do\nend\n", "lib/a.ex")], NoDependency)
        end)

      assert [issue] = issues
      assert issue.message =~ ~s("calls")
      assert issue.message =~ "Fix:"
    end

    # DND-1286: a misspelt key inside a rule used to be ignored, so this rule
    # forbade nothing and the forbidden call below read green.
    # Sabotage record: ../../sabotage_records/rule_schema-20260929-dnd_1286_rule_key_allowlist.md
    test "an unknown key inside a rule is one issue on the config file" do
      yaml = """
      rules:
        - type: no_direct_dependency
          paths:
            - "lib/**/*.ex"
          forbiden_patterns:
            - "*.Repo"
          recursive: true
      """

      source = """
      defmodule MyApp.Domain.Thing do
        def go, do: MyApp.Repo.all(Q)
      end
      """

      {issues, dir} =
        with_anchor_config(yaml, fn ->
          {all_issues([to_source_file(source, "lib/domain/thing.ex")], NoDependency), File.cwd!()}
        end)

      assert [issue] = issues
      assert issue.filename == Path.join(dir, ".anchor.yml")
      assert issue.message =~ ~s(rule 1: unknown key "forbiden_patterns")
      assert issue.message =~ ~s(did you mean "forbidden_patterns"?)
      assert issue.message =~ "no Anchor rule was checked"
      assert issue.message =~ ~r/Fix: [^\n]+\z/
      # The Fix: line points at the per-type key table.
      assert issue.message =~ ~s(table "Keys each rule type accepts")
    end

    # DND-1286: a rule with no selector selected no file and read green.
    # Sabotage record: ../../sabotage_records/rule_schema-20260929-dnd_1286_rule_key_allowlist.md
    test "a rule with no selector is one issue on the config file" do
      yaml = """
      rules:
        - type: no_direct_dependency
          forbidden_modules:
            - MyApp.Repo
      """

      source = """
      defmodule MyApp.Domain.Thing do
        def go, do: MyApp.Repo.all(Q)
      end
      """

      issues =
        with_anchor_config(yaml, fn ->
          all_issues([to_source_file(source, "lib/domain/thing.ex")], NoDependency)
        end)

      assert [issue] = issues
      assert issue.message =~ "rule 1: the rule has no selector"
      assert issue.message =~ "Fix:"
    end
  end

  describe "unparseable source file (A9)" do
    test "a file anchor cannot parse is an issue on that file" do
      broken = Credo.SourceFile.parse("defmodule Broken do\n  def go(\nend\n", "lib/broken.ex")

      issues = with_anchor_config(@yaml, fn -> all_issues([broken], NoDependency) end)

      assert [issue] = issues
      assert issue.filename == "lib/broken.ex"
      assert issue.line_no == 2
      assert issue.priority >= Credo.Priority.to_integer(:higher)
      assert issue.message =~ "could not parse"
      # The parser's full text, including the token it stopped at.
      assert issue.message =~ "unexpected reserved word: end"
      assert issue.message =~ "Fix:"
    end
  end

  describe "one failure report per run" do
    test "only the first enabled Anchor check reports a config failure" do
      exec =
        exec_with_checks([
          {Credo.Check.Readability.ModuleNames, []},
          {MustUseModule, []},
          {NoDependency, []}
        ])

      files = [to_source_file("defmodule A do\nend\n", "lib/a.ex")]

      issues =
        with_anchor_config(nil, fn ->
          :ok = NoDependency.run_on_all_source_files(exec, files, [])
          :ok = MustUseModule.run_on_all_source_files(exec, files, [])
          Credo.Execution.get_issues(exec)
        end)

      assert [issue] = issues
      assert issue.check == MustUseModule
    end

    test "only the first enabled Anchor check reports an unparseable file" do
      exec = exec_with_checks([{MustUseModule, []}, {NoDependency, []}])
      broken = Credo.SourceFile.parse("defmodule Broken do\n  def go(\nend\n", "lib/broken.ex")

      issues =
        with_anchor_config(@yaml, fn ->
          :ok = NoDependency.run_on_all_source_files(exec, [broken], [])
          :ok = MustUseModule.run_on_all_source_files(exec, [broken], [])
          Credo.Execution.get_issues(exec)
        end)

      assert [issue] = issues
      assert issue.check == MustUseModule
      assert issue.filename == "lib/broken.ex"
    end
  end

  # DND-1290: a rule that loads but checks nothing. Load-time cases fail the
  # load; the zero-files case is decided at run time, over the files the check
  # ran on.
  # Sabotage record: ../../sabotage_records/lint-20260929-dnd_1290_empty_relation_list.md
  describe "a rule that checks nothing (DND-1290)" do
    @thing """
    defmodule MyApp.Domain.Thing do
      def go, do: MyApp.Repo.all(Q)
    end
    """

    test "a relation-less rule is one issue on the config file" do
      yaml = """
      rules:
        - type: must_use_module
          paths:
            - "lib/**/*.ex"
          recursive: true
      """

      {issues, dir} =
        with_anchor_config(yaml, fn ->
          {all_issues([to_source_file(@thing, "lib/domain/thing.ex")], MustUseModule),
           File.cwd!()}
        end)

      assert [issue] = issues
      assert issue.filename == Path.join(dir, ".anchor.yml")
      assert issue.message =~ "rule 1: a must_use_module rule has no relation"
      assert issue.message =~ "required_modules is missing or empty"
      assert issue.message =~ "no Anchor rule was checked"
      assert issue.message =~ ~r/Fix: [^\n]+\z/
    end

    test "a rule that selects zero files is one issue on the config file" do
      yaml = """
      rules:
        - type: no_direct_dependency
          id: web-no-repo
          paths:
            - "lib/my_app_web/**/*.ex"
          recursive: true
          forbidden_modules:
            - MyApp.Repo
      """

      {issues, dir} =
        with_anchor_config(yaml, fn ->
          {all_issues([to_source_file(@thing, "lib/domain/thing.ex")], NoDependency), File.cwd!()}
        end)

      assert [issue] = issues
      assert issue.filename == Path.join(dir, ".anchor.yml")
      assert issue.priority >= Credo.Priority.to_integer(:higher)

      assert issue.message =~
               ~s|rule 1 (id: "web-no-repo", no_direct_dependency) selected 0 of the 1 file|

      assert issue.message =~ "so it checked nothing"
      assert issue.message =~ ~r/Fix: [^\n]+\z/
    end

    test "a run over explicit files does not apply the floor" do
      yaml = """
      rules:
        - type: no_direct_dependency
          paths:
            - "lib/my_app_web/**/*.ex"
          recursive: true
          forbidden_modules:
            - MyApp.Repo
      """

      exec = %{
        Credo.Execution.build()
        | cli_options: %Credo.CLI.Options{
            path: File.cwd!(),
            switches: %{files_included: ["lib/domain/thing.ex"]}
          }
      }

      issues =
        with_anchor_config(yaml, fn ->
          :ok =
            NoDependency.run_on_all_source_files(
              exec,
              [to_source_file(@thing, "lib/domain/thing.ex")],
              []
            )

          Credo.Execution.get_issues(exec)
        end)

      assert issues == []
    end

    test "a rule whose check is not enabled is one issue on the config file" do
      yaml = """
      rules:
        - type: no_direct_dependency
          paths:
            - "lib/**/*.ex"
          recursive: true
          forbidden_modules:
            - MyApp.Nope
        - type: single_control_flow
          paths:
            - "lib/**/*.ex"
          recursive: true
      """

      exec = exec_with_checks([{NoDependency, []}])

      issues =
        with_anchor_config(yaml, fn ->
          :ok =
            NoDependency.run_on_all_source_files(
              exec,
              [to_source_file(@thing, "lib/domain/thing.ex")],
              []
            )

          Credo.Execution.get_issues(exec)
        end)

      assert [issue] = issues
      assert issue.message =~ "rule 2 (single_control_flow) is not checked"
      assert issue.message =~ "Fix:"
    end

    test "an alias-form module pattern selects and forbids (the README's own form)" do
      yaml = """
      rules:
        - type: no_direct_dependency
          pattern: "MyApp.Domain.*"
          forbidden_patterns:
            - "MyApp.Repo*"
      """

      issues =
        with_anchor_config(yaml, fn ->
          all_issues([to_source_file(@thing, "lib/domain/thing.ex")], NoDependency)
        end)

      assert [issue] = issues
      assert issue.trigger == "MyApp.Repo"
    end
  end

  # DND-1292: every glob character but `*`/`**` is a literal. `*?` used to be a
  # lazy regex match-all that allowed every function, and a `+` in a path glob
  # selected the wrong directory and not its own.
  # Sabotage record: ../../sabotage_records/glob_pattern-20260929-dnd_1292_glob_escape.md
  describe "regex metacharacters in globs are literal (DND-1292)" do
    test "allowed_functions `*?` allows the predicates and flags the rest" do
      yaml = """
      rules:
        - type: module_pattern_restrictions
          pattern: "MyApp.Domain.*"
          allowed_functions: ["*?"]
      """

      source = """
      defmodule MyApp.Domain.Thing do
        def valid?(x), do: x
        def run(x), do: x
      end
      """

      issues =
        with_anchor_config(yaml, fn ->
          all_issues([to_source_file(source, "lib/domain/thing.ex")], ModulePatternRestrictions)
        end)

      assert [issue] = issues
      assert issue.trigger == "run"
    end

    test "a `paths` glob with `+` selects its own directory" do
      yaml = """
      rules:
        - type: no_direct_dependency
          paths: ["lib/c++/**/*.ex"]
          recursive: true
          forbidden_modules: [MyApp.Repo]
      """

      issues =
        with_anchor_config(yaml, fn ->
          all_issues([to_source_file(@thing, "lib/c++/domain/thing.ex")], NoDependency)
        end)

      assert [issue] = issues
      assert issue.trigger == "MyApp.Repo"
    end
  end

  defp all_issues(source_files, check) do
    exec = Credo.Execution.build()
    :ok = check.run_on_all_source_files(exec, source_files, [])
    Credo.Execution.get_issues(exec)
  end

  defp exec_with_checks(checks) do
    %{Credo.Execution.build() | checks: %{enabled: checks, disabled: []}}
  end

  # Runs `fun` with the cwd set to a fresh temp directory. When `yaml` is a
  # string, it is written there as `.anchor.yml` so `Anchor.Config.load/0` finds
  # it; when `yaml` is nil, no config file is written (the no-config case). The
  # cwd is always restored and the temp directory removed afterwards.
  defp with_anchor_config(yaml, fun) do
    tmp = Path.join(System.tmp_dir!(), "anchor_e2e_#{:erlang.unique_integer([:positive])}")
    File.mkdir_p!(tmp)
    if is_binary(yaml), do: File.write!(Path.join(tmp, ".anchor.yml"), yaml)

    original_cwd = File.cwd!()
    # LOAD-BEARING: File.cd/1 mutates the BEAM's process-global cwd. This is
    # only safe because this module is `async: false` (see @moduledoc). Do NOT
    # flip this module to `async: true`, and do not add a second cwd-mutating
    # `async: false` module, without serializing them — concurrent cwd changes
    # race silently.
    File.cd!(tmp)

    try do
      fun.()
    after
      File.cd!(original_cwd)
      File.rm_rf!(tmp)
    end
  end
end
