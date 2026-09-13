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

  alias Anchor.Check.MustUseModule
  alias Anchor.Check.NoDependency

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
      source = """
      defmodule SomeTest do
        def go, do: MyApp.Repo.all(Q)
      end
      """

      issues =
        with_anchor_config(@yaml, fn ->
          [to_source_file(source, "test/domain/some_test.ex")]
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

  describe "no configuration present" do
    test "checks are silent when there is no .anchor.yml (graceful no-op)" do
      source = """
      defmodule MyApp.Domain.Thing do
        def go, do: MyApp.Repo.all(Q)
      end
      """

      issues =
        with_anchor_config(nil, fn ->
          [to_source_file(source, "lib/domain/thing.ex")]
          |> run_check(NoDependency)
        end)

      assert issues == []
    end
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
