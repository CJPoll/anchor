defmodule Anchor.BehaviourLocalityWorkflowTest do
  # DND-5489: what the Behaviour locality workflow runs on is held here: a successful
  # Coverage map run that is not a pull request's, by hand, and with read-only
  # permissions. The workflow itself runs on CI.
  # Sabotage record: ../sabotage_records/sabotage-20261106-dnd_5470_param_sink_locality.md
  use ExUnit.Case, async: true

  @workflow ".github/workflows/behaviour-locality.yml"

  setup_all do
    workflow = YamlElixir.read_from_file!(@workflow)
    %{"behaviours" => job} = workflow["jobs"]
    %{workflow: workflow, job: job}
  end

  test "it follows Coverage map on main, and can be run by hand", %{workflow: workflow} do
    # YAML 1.1 reads a bare `on` as true; yaml_elixir keeps it as the text.
    triggers = workflow["on"] || workflow[true]

    assert triggers["workflow_run"]["workflows"] == ["Coverage map"]
    assert triggers["workflow_run"]["branches"] == ["main"]
    assert Map.has_key?(triggers, "workflow_dispatch")
    refute Map.has_key?(triggers, "pull_request")
  end

  test "it runs on a success that is no pull request's, or by hand", %{job: job} do
    condition = job["if"]

    assert condition =~ "github.event.workflow_run.conclusion == 'success'"
    assert condition =~ "github.event.workflow_run.event != 'pull_request'"
    assert condition =~ "github.event_name == 'workflow_dispatch'"
  end

  test "it can write nothing", %{workflow: workflow} do
    assert workflow["permissions"] == %{"contents" => "read", "actions" => "read"}
  end

  test "report mode's own command reads the downloaded map", %{job: job} do
    assert Enum.any?(
             job["steps"],
             &(&1["run"] == "mix anchor.sabotage behaviours --coverage anchor-coverage.etf")
           )

    refute Enum.any?(job["steps"], &Map.has_key?(&1, "continue-on-error"))
  end
end
