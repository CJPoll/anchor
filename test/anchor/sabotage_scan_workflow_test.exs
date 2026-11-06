defmodule Anchor.SabotageScanWorkflowTest do
  # DND-5490: what makes the Sabotage scan workflow the nightly scan is held
  # here: when it runs, the exact command (one shard a night, every mutant of
  # it, a report and never a record), that its token only reads, and that
  # nothing turns its red into a pass. The workflow itself runs on CI.
  # Sabotage record: ../sabotage_records/sabotage-20261106-dnd_5490_scan.md
  use ExUnit.Case, async: true

  @workflow ".github/workflows/sabotage-scan.yml"

  setup_all do
    workflow = YamlElixir.read_from_file!(@workflow)
    %{"scan" => job} = workflow["jobs"]
    %{workflow: workflow, job: job, steps: job["steps"]}
  end

  defp step(steps, name),
    do: Enum.find(steps, &(&1["name"] == name)) || flunk("no step #{name}")

  test "it runs nightly and by hand, never on a pull request", %{workflow: workflow} do
    # YAML 1.1 reads a bare `on` as true; yaml_elixir keeps it as the text.
    triggers = workflow["on"] || workflow[true]

    assert [%{"cron" => _cron}] = triggers["schedule"]
    assert Map.has_key?(triggers, "workflow_dispatch")
    refute Map.has_key?(triggers, "pull_request")
    refute Map.has_key?(triggers, "push")
  end

  test "its token only reads", %{workflow: workflow, job: job} do
    assert workflow["permissions"] == %{"contents" => "read", "actions" => "read"}
    refute Map.has_key?(job, "permissions")
  end

  # The exact command, so `|| true`, `| tee` or `; exit 0` cannot hide its code.
  test "the scan is the day's shard, every mutant, a report and no record", %{steps: steps} do
    run =
      steps
      |> step("Scan (mix anchor.sabotage run --scope all --shard auto)")
      |> Map.fetch!("run")

    assert String.trim(run) ==
             ~s(mix anchor.sabotage run --scope all --shard auto --max all --base HEAD ) <>
               ~s(--report "$RUNNER_TEMP/scan/sabotage-scan.md" $SCAN_COVERAGE)
  end

  test "the coverage map is optional: its absence is said, never a failure", %{steps: steps} do
    run = step(steps, "Download the latest coverage map")["run"]

    assert run =~ "--name anchor-coverage"
    assert run =~ ~s(echo "SCAN_COVERAGE=--coverage=$RUNNER_TEMP/coverage/anchor-coverage.etf")
    assert run =~ "No anchor-coverage artifact"
  end

  test "the summary and the artifact come from the report", %{steps: steps} do
    assert step(steps, "Write the totals and findings to the job summary")["run"] =~
             ~s(cat "$RUNNER_TEMP/scan/sabotage-scan.md" >> "$GITHUB_STEP_SUMMARY")

    upload = step(steps, "Upload the report")["with"]
    assert upload["name"] == "anchor-sabotage-scan"
    assert upload["path"] =~ "sabotage-scan.md"
    assert upload["path"] =~ "sabotage-scan.etf"
    assert upload["if-no-files-found"] == "error"
  end

  test "nothing turns a red step into a pass", %{job: job, steps: steps} do
    refute Map.has_key?(job, "continue-on-error")
    assert Enum.filter(steps, &Map.has_key?(&1, "continue-on-error")) == []
    assert Enum.filter(steps, &Map.has_key?(&1, "if")) == []
  end

  test "its bound is 180 minutes", %{job: job} do
    assert job["timeout-minutes"] == 180
  end
end
