defmodule Anchor.Managers.LintTransitiveWalksTest do
  # DND-8208: how many times a run walks a module's graph for
  # no_transitive_dependency. The check walks each module once per detect
  # call, whatever the number of findings; Lint calls the detector once for a
  # file's rules without a `baseline:` and once more for each baselined rule
  # (DND-5632), so a module that k baselined rules select is walked 1 + k
  # times, and k times when every selecting rule is baselined. These rows
  # measure that through Lint, with a detector that reports its walks
  # (`Anchor.Test.CountingTransitiveDetector`). A sibling of lint_test.exs, so a
  # sabotage run of Lint selects it.
  #
  # Sabotage record:
  #   ../../sabotage_records/no_transitive_dependency-20261127-athena_transitive_reachability_once.md
  use ExUnit.Case, async: true

  import Hammox

  alias Anchor.BaselineStoreMock
  alias Anchor.Config
  alias Anchor.ConfigLoaderMock
  alias Anchor.Managers.Lint
  alias Anchor.Test.CountingTransitiveDetector
  alias Credo.SourceFile

  setup :verify_on_exit!

  # MyApp.A reaches MyApp.Repo and MyApp.Mailer through MyApp.B: two findings
  # for a rule that forbids both.
  @a """
  defmodule MyApp.A do
    def f, do: MyApp.B.call()
  end
  """

  @b """
  defmodule MyApp.B do
    def call, do: {MyApp.Repo.all(), MyApp.Mailer.send()}
  end
  """

  defp rule(id, baseline) do
    %{
      type: :no_transitive_dependency,
      id: id,
      paths: ["lib/my_app/a.ex"],
      recursive: false,
      forbidden_modules: [MyApp.Repo, MyApp.Mailer],
      forbidden_patterns: [],
      baseline: baseline
    }
  end

  defp run(rules) do
    expect(ConfigLoaderMock, :load, fn -> {:ok, %Config{rules: rules}} end)
    stub(BaselineStoreMock, :read, fn _root, _path -> {:ok, []} end)
    files = [SourceFile.parse(@a, "lib/my_app/a.ex"), SourceFile.parse(@b, "lib/my_app/b.ex")]

    {:ok, results} =
      Lint.run(CountingTransitiveDetector, files, [],
        check: Anchor.Check.NoTransitiveDependency,
        config_loader: ConfigLoaderMock,
        baseline_store: BaselineStoreMock,
        root: "/proj",
        enforce_selection_floors: false
      )

    {results, walks()}
  end

  defp walks(acc \\ []) do
    receive do
      {:transitive_walks, starts} -> walks(acc ++ starts)
    after
      0 -> acc
    end
  end

  defp findings(results) do
    for {%SourceFile{}, violations} <- results, %{kind: :rule} <- violations, do: :finding
  end

  test "a rule without a baseline: one walk of the module, though it has two findings" do
    {results, walks} = run([rule("plain", nil)])

    assert walks == [MyApp.A]
    assert length(findings(results)) == 2
  end

  test "one plain rule and two baselined rules: 1 + 2 walks of the module" do
    {_results, walks} =
      run([
        rule("plain", nil),
        rule("held_a", ".anchor/baselines/held_a.txt"),
        rule("held_b", ".anchor/baselines/held_b.txt")
      ])

    assert walks == [MyApp.A, MyApp.A, MyApp.A]
  end

  test "only baselined rules: one walk per baselined rule, none for the empty plain set" do
    {_results, walks} = run([rule("held", ".anchor/baselines/held.txt")])

    assert walks == [MyApp.A]
  end
end
