defmodule Anchor.Domain.Sabotage.NewerTests do
  @moduledoc """
  The note a new survivor carries when a test was added after a sabotage
  record (DND-7453). Pure **Domain**: plain data in, plain data out.

  A whole-branch run selects tests from the kill maps of the records already
  committed (`Anchor.Domain.Sabotage.TestSelection`, source `:kill_map`) and
  the mirror file. A test the branch added or changed after a record, in a
  file neither names, is not run, so a mutant it would kill shows as a NEW
  survivor. The run does not learn that test's kills (that would be a test
  run per record); it says the test exists.

  `find/3` names, per new survivor, each committed record that lists the
  survivor's function and has a branch test changed since the record's
  commit that the survivor's selection did not run. The facts are the
  Manager's reads, given as data: a record's `path`, the `commit` that last
  touched it, the `mfas` its `anchor-kills` rows list, and the paths `changed`
  since that commit. `branch_tests` are the test files the branch changed
  (`Scope.test_changes/1`): a test changed on main since a record is not the
  branch's news, and not named. Every path named passes
  `Anchor.Domain.Sabotage.TestPath.check/1`.

  `note/2` words a survivor's findings for the report. It only adds
  information: the survivor stays NEW, and the exit code is the survivors
  list's.

  Its limits: a record's "since" is its file's last commit, so a test added
  after the record's block was written but before a later commit touched the
  same file (another run appended to it) is not newer, and the note is silent;
  and a test file no diff names (untracked) is not the branch's change, so it
  is not named. Silence is not a claim that no newer test exists.
  """

  alias Anchor.Domain.Sabotage.TestPath
  alias Anchor.Domain.Sabotage.TestSelection

  @shown 5

  @type record :: %{
          path: String.t(),
          commit: String.t(),
          mfas: [String.t()],
          changed: [String.t()]
        }
  @type finding :: %{record: String.t(), commit: String.t(), tests: [String.t()]}

  @doc "`mutant id => findings`, in the records' order; a survivor with none is left out."
  @spec find([map()], [record()], [String.t()]) :: %{String.t() => [finding()]}
  def find(survivors, records, branch_tests) do
    branch = MapSet.new(branch_tests)

    for %{mutant: mutant} = survivor <- survivors,
        findings = findings(survivor, records, branch),
        findings != [],
        into: %{},
        do: {mutant.id, findings}
  end

  @doc """
  The report lines of one survivor's findings: a `Note:` per record, then one
  `Fix:`. `survivor` names the selection the run made.
  """
  @spec note([finding()], map()) :: [String.t()]
  def note([], _survivor), do: []

  def note(findings, %{selection: {_source, args}}) do
    selected = args |> Enum.map(&ref_file/1) |> Enum.uniq()

    Enum.map(findings, &note_line/1) ++
      [
        "  Fix: fold that test into #{selects(selected)}, then re-run: a run selects only " <>
          "the files a record's kill map and the function's mirror name"
      ]
  end

  defp note_line(%{record: record, commit: commit, tests: tests}),
    do:
      "  Note: a test added after record #{record} (#{String.slice(commit, 0, 12)}) may " <>
        "kill this mutant, and this run did not select it: #{listed(tests)}"

  defp selects([]), do: "a test file the function's mirror names (this run selected none)"
  defp selects(files), do: "a test file this run selects (#{Enum.join(files, ", ")})"

  defp findings(%{mutant: mutant, selection: {_source, args}}, records, branch) do
    mfa = TestSelection.mfa(mutant)
    selected = MapSet.new(args, &ref_file/1)

    for record <- records,
        mfa in record.mfas,
        tests = newer(record.changed, branch, selected),
        tests != [] do
      %{record: record.path, commit: record.commit, tests: tests}
    end
  end

  defp newer(changed, branch, selected) do
    changed
    |> Enum.filter(&(TestPath.check(&1) == :ok and &1 in branch and &1 not in selected))
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp listed(tests) when length(tests) <= @shown, do: Enum.join(tests, ", ")

  defp listed(tests),
    do: Enum.join(Enum.take(tests, @shown), ", ") <> " and #{length(tests) - @shown} more"

  defp ref_file(ref), do: ref |> String.split(":", parts: 2) |> hd()
end
