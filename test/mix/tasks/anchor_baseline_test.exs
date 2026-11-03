defmodule Mix.Tasks.Anchor.BaselineTest do
  # DND-5632: `mix anchor.baseline`, the Framework entry: argument parsing,
  # rendering and exit codes. The Manager's adapters are Hammox doubles passed
  # through the task's options; the compile step is injected, so no test
  # compiles a project or runs Credo.
  # sync: capture_io(:stderr) captures the VM-wide standard_error device, which
  # another async test's output would interleave with.
  #
  # Sabotage record: ../../sabotage_records/baseline-20261103-dnd_5648_graph_followups.md
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO
  import Hammox

  alias Anchor.BaselineStoreMock
  alias Anchor.Config
  alias Anchor.ConfigLoaderMock
  alias Anchor.GitBaseMock
  alias Anchor.LintKeysMock
  alias Mix.Tasks.Anchor.Baseline

  setup :verify_on_exit!

  @path ".anchor/baselines/pure.txt"
  @rule %{
    type: :no_direct_dependency,
    id: "pure",
    index: 1,
    pattern: "MyApp.*",
    forbidden_modules: [File],
    baseline: @path
  }

  defp opts do
    [
      compile: fn -> send(self(), :compiled) end,
      config_loader: ConfigLoaderMock,
      baseline_store: BaselineStoreMock,
      git_base: GitBaseMock,
      lint_keys: LintKeysMock
    ]
  end

  defp config,
    do:
      expect(ConfigLoaderMock, :load, fn ->
        {:ok, %Config{rules: [@rule], path: ".anchor.yml"}}
      end)

  test "--write RULE_ID compiles, writes the rule's keys and exits 0" do
    config()
    expect(BaselineStoreMock, :read, fn _root, @path -> {:error, :enoent} end)

    expect(LintKeysMock, :keys, fn ->
      {:ok, %{keys: [{"pure", "pure|lib/a.ex|File"}], rule_ids: ["pure"]}}
    end)

    expect(BaselineStoreMock, :create, fn root, @path, contents ->
      assert root == File.cwd!()
      assert contents =~ "pure|lib/a.ex|File\n"
      :ok
    end)

    output = capture_io(fn -> assert Baseline.run(["--write", "pure"], opts()) == :ok end)

    assert_received :compiled
    assert output =~ "#{@path}: [report] wrote 1 entries to #{@path}."
    assert output =~ "anchor.baseline: 1 ast baselines, 0 violations (1 report-only)"
  end

  test "--write over an existing file exits 2" do
    config()
    expect(BaselineStoreMock, :read, fn _root, @path -> {:ok, []} end)

    output =
      capture_io(fn ->
        assert catch_exit(Baseline.run(["--write", "pure"], opts())) == {:shutdown, 2}
      end)

    assert output =~ "only creates"
  end

  test "--base REF prints a GREW entry and exits 1, without compiling" do
    config()
    expect(BaselineStoreMock, :read, fn _root, @path -> {:ok, ["pure|lib/b.ex|File"]} end)
    expect(GitBaseMock, :rules, fn _root, "origin/main", ".anchor.yml" -> {:ok, [@rule]} end)
    expect(GitBaseMock, :show, fn _root, "origin/main", @path -> {:ok, []} end)

    output =
      capture_io(fn ->
        assert catch_exit(Baseline.run(["--base", "origin/main"], opts())) == {:shutdown, 1}
      end)

    refute_received :compiled

    assert output =~
             "#{@path}: [enforce] pure|lib/b.ex|File was added to #{@path} since origin/main"

    assert output =~ "anchor.baseline: 1 ast baselines, 1 violation (0 report-only)"
  end

  test "--base REF with nothing grown exits 0" do
    config()
    expect(BaselineStoreMock, :read, fn _root, @path -> {:ok, []} end)
    expect(GitBaseMock, :rules, fn _root, "main", ".anchor.yml" -> {:ok, [@rule]} end)
    expect(GitBaseMock, :show, fn _root, "main", @path -> {:ok, ["pure|lib/b.ex|File"]} end)

    output = capture_io(fn -> assert Baseline.run(["--base", "main"], opts()) == :ok end)
    assert output =~ "anchor.baseline: 1 ast baselines, 0 violations (0 report-only)"
  end

  test "no mode, both modes, an unknown flag, an argument or a bad ref is usage: exit 2 with Fix:" do
    for argv <- [
          [],
          ["--write", "pure", "--base", "main"],
          ["--write", ""],
          ["--nope"],
          ["extra"],
          ["--base", "-x"],
          ["--base", "a b"]
        ] do
      stderr =
        capture_io(:stderr, fn ->
          assert catch_exit(Baseline.run(argv, opts())) == {:shutdown, 2}, inspect(argv)
        end)

      assert stderr =~ "Usage: mix anchor.baseline --write RULE_ID | --base REF", inspect(argv)
      assert stderr =~ "Fix: pass exactly one of", inspect(argv)
    end
  end
end
