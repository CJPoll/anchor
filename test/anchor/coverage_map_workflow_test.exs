defmodule Anchor.CoverageMapWorkflowTest do
  # DND-5692: the Coverage map workflow is the guard, so what makes it one is held
  # here: when it runs, that both builds are the same command at one seed, that a red
  # build still reaches the comparison, and that nothing can turn a red into a pass.
  # The workflow itself runs on CI.
  # Sabotage record: ../sabotage_records/coverage_compare-20261106-dnd_5692_repeatability_check.md
  use ExUnit.Case, async: true

  @workflow ".github/workflows/coverage-map.yml"

  setup_all do
    workflow = YamlElixir.read_from_file!(@workflow)
    %{"coverage-map" => job} = workflow["jobs"]
    %{workflow: workflow, job: job, steps: job["steps"]}
  end

  defp step(steps, name), do: Enum.find(steps, &(&1["name"] == name)) || flunk("no step #{name}")

  defp build(out) do
    ~s(mix anchor.sabotage coverage --out "#{out}" -- --seed "$COVERAGE_SEED" --exclude global_tracing)
  end

  defp command(steps, name), do: steps |> step(name) |> Map.fetch!("run") |> String.trim()

  test "it runs on pull_request and on push to main", %{workflow: workflow} do
    # YAML 1.1 reads a bare `on` as true; yaml_elixir keeps it as the text.
    triggers = workflow["on"] || workflow[true]

    assert Map.has_key?(triggers, "pull_request")
    assert triggers["push"]["branches"] == ["main"]
  end

  # Exact commands, so `|| true`, `| tee` or `; exit 0` cannot hide a step's own code.
  test "the two builds are one command at one seed, each to its own file", %{
    job: job,
    steps: steps
  } do
    assert job["env"]["COVERAGE_SEED"] == "${{ github.run_id }}"
    assert command(steps, "Build the coverage map") == build("$COVERAGE_FIRST")
    assert command(steps, "Build the coverage map again") == build("$COVERAGE_SECOND")
  end

  test "a red build still reaches the second build and the comparison", %{steps: steps} do
    for name <- ["Build the coverage map again", "Compare the two builds"] do
      assert step(steps, name)["if"] ==
               "${{ !cancelled() && steps.compile.outcome == 'success' }}"
    end

    assert step(steps, "Compile (warnings as errors)")["id"] == "compile"
  end

  test "the comparison judges both builds' files, and its code is the step's", %{steps: steps} do
    assert command(steps, "Compare the two builds") ==
             ~s(mix anchor.sabotage coverage-compare "$COVERAGE_FIRST" "$COVERAGE_SECOND")
  end

  test "nothing turns a red step into a pass", %{job: job, steps: steps} do
    refute Map.has_key?(job, "continue-on-error")
    assert Enum.filter(steps, &Map.has_key?(&1, "continue-on-error")) == []
  end

  test "a map is checked and uploaded only after every step before it passed", %{steps: steps} do
    refute Map.has_key?(step(steps, "Check the map"), "if")
    assert step(steps, "Check the map")["run"] =~ ~s{"COVERAGE_FIRST" |> System.fetch_env!()}
    assert step(steps, "Upload the map")["if"] == "github.event_name != 'pull_request'"
    assert step(steps, "Upload the map")["with"]["path"] == "${{ env.COVERAGE_FIRST }}"
    assert step(steps, "Upload the map")["with"]["if-no-files-found"] == "error"
  end

  test "the job's bound is the one it had", %{job: job} do
    assert job["timeout-minutes"] == 60
  end

  test "each file has its own path, outside the checkout and the cached _build", %{steps: steps} do
    run = step(steps, "Choose where each build writes")["run"]

    assert run =~ "COVERAGE_FIRST=$RUNNER_TEMP/coverage-first/"
    assert run =~ "COVERAGE_SECOND=$RUNNER_TEMP/coverage-second/"
  end
end
