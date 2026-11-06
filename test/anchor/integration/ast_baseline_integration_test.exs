defmodule Anchor.Integration.AstBaselineIntegrationTest do
  # DND-5632: an ast rule's baseline end to end, no mocks: a real project in a
  # temp directory, real `.credo.exs` and `.anchor.yml`, `mix anchor.baseline
  # --write`'s Manager over the real adapters (Credo runs for real), then
  # `Credo.run/1` judging held, STALE and a narrowed run.
  #
  # sync: each test `File.cd!/1`s into its temp project, because Credo and
  # `.anchor.yml`'s loader both read the working directory. ExUnit runs sync
  # modules one at a time, after the async ones, so no other test sees it.
  #
  # Sabotage record: ../../sabotage_records/baseline-20261103-dnd_5648_graph_followups.md
  use ExUnit.Case, async: false

  alias Anchor.Adapters.CredoKeys
  alias Anchor.Managers.AstBaseline

  @path ".anchor/baselines/pure.txt"

  @credo """
  %{configs: [%{name: "default", files: %{included: ["lib/"], excluded: []},
    checks: %{enabled: [{Anchor.Check.NoDependency, []}]}}]}
  """

  @anchor """
  rules:
    - type: no_direct_dependency
      id: pure
      baseline: #{@path}
      paths:
        - "lib/**/*.ex"
      recursive: true
      forbidden_modules:
        - File
  """

  setup do
    tmp =
      Path.join(System.tmp_dir!(), "anchor_ast_baseline_#{:erlang.unique_integer([:positive])}")

    File.mkdir_p!(Path.join(tmp, "lib"))
    File.write!(Path.join(tmp, ".credo.exs"), @credo)
    File.write!(Path.join(tmp, ".anchor.yml"), @anchor)

    File.write!(
      Path.join(tmp, "lib/a.ex"),
      "defmodule P.A do\n  def f, do: File.read(\"a\")\nend\n"
    )

    File.write!(
      Path.join(tmp, "lib/b.ex"),
      "defmodule P.B do\n  def f, do: File.read(\"b\")\nend\n"
    )

    original = File.cwd!()
    File.cd!(tmp)

    on_exit(fn ->
      File.cd!(original)
      File.rm_rf!(tmp)
    end)

    %{root: File.cwd!()}
  end

  defp credo(argv), do: argv |> CredoKeys.run_quietly() |> Credo.Execution.get_issues()

  test "write, then held, STALE, and a narrowed run with no false STALE", %{root: root} do
    # Before a baseline exists, both findings stand.
    assert ~w(File File) == for(%{trigger: t} <- credo(["--strict"]), t == "File", do: t)

    assert %{exit_code: 0} = AstBaseline.write(%{root: root, id: "pure"}, [])

    assert File.read!(@path) ==
             "# anchor baseline for pure; shrink only\npure|lib/a.ex|File\npure|lib/b.ex|File\n"

    # Held: the run is clean.
    assert credo(["--strict"]) == []

    # A second write only creates.
    assert %{exit_code: 2} = AstBaseline.write(%{root: root, id: "pure"}, [])

    # STALE: an entry no finding consumes.
    File.write!(@path, File.read!(@path) <> "pure|lib/c.ex|File\n")
    assert [stale] = credo(["--strict"])
    assert stale.filename == @path
    assert stale.message =~ "pure|lib/c.ex|File in #{@path} matches no finding"

    # Narrowed to lib/a.ex: the entries on b.ex and c.ex are not judged, so
    # there is no STALE, and a report-only note says so.
    assert [note] = credo(["--strict", "lib/a.ex"])
    assert note.message =~ "NOTE: 2 entries of #{@path} name a file this run did not read"
    assert note.exit_status == 0
  end
end
