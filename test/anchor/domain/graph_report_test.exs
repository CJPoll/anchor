defmodule Anchor.Domain.GraphReportTest do
  # DND-5440: the verdict of a graph run. Pure Domain: exit code, text and
  # JSON rendering from hand-built findings.
  #
  # Sabotage record: ../../sabotage_records/graph_runner-20261103-dnd_5440_graph_runner.md
  # Sabotage record: ../../sabotage_records/graph_runner-20261103-dnd_5551_graph_hardening.md
  # Sabotage record: ../../sabotage_records/graph_runner-20261103-dnd_5581_hardening_batch.md
  use ExUnit.Case, async: true

  alias Anchor.Domain.GraphReport
  alias Anchor.Domain.GraphReport.Finding

  @counts %{modules: 12, apps: 2, rules: 3, opaque: 0, no_core: 0, excluded: 0}

  defp finding(enforcement, overrides \\ %{}) do
    struct!(
      Finding,
      Map.merge(
        %{
          rule_id: "web",
          type: :layering,
          label: ~s|rule 1 (id: "web", layering)|,
          enforcement: enforcement,
          key: "MyApp.Web->MyApp.Repo",
          file: "lib/my_app/web.ex",
          line: 7,
          message: "MyApp.Web calls MyApp.Repo. Fix: call a manager instead."
        },
        overrides
      )
    )
  end

  describe "exit_code/1" do
    test "no findings is 0" do
      assert GraphReport.new([], [], @counts).exit_code == 0
    end

    test "only report findings is 0" do
      assert GraphReport.new([finding(:report)], [], @counts).exit_code == 0
    end

    test "one enforce finding is 1" do
      assert GraphReport.new([finding(:report), finding(:enforce)], [], @counts).exit_code == 1
    end

    test "a fail-closed issue is 1" do
      issue = finding(:enforce, %{rule_id: nil, type: nil, label: "anchor.graph"})
      assert GraphReport.new([issue], [], @counts).exit_code == 1
    end

    test "a could-not-check entry is 3, and 3 wins over 1" do
      could_not = finding(:enforce, %{label: "anchor.graph"})
      assert GraphReport.new([], [could_not], @counts).exit_code == 3
      assert GraphReport.new([finding(:enforce)], [could_not], @counts).exit_code == 3
    end
  end

  describe "render/2 :text" do
    test "one line per finding, then the summary with exact counts" do
      report = GraphReport.new([finding(:enforce), finding(:report, %{line: nil})], [], @counts)

      assert GraphReport.render(report, :text) ==
               ~s|lib/my_app/web.ex:7: [enforce] rule 1 (id: "web", layering) MyApp.Web calls MyApp.Repo. Fix: call a manager instead.\n| <>
                 ~s|lib/my_app/web.ex:1: [report] rule 1 (id: "web", layering) MyApp.Web calls MyApp.Repo. Fix: call a manager instead.\n| <>
                 "anchor.graph: 12 modules in 2 apps, 3 rules, 1 violations (1 report-only, 0 baselined)"
    end

    test "could-not-check entries print first and count as violations" do
      could_not =
        finding(:enforce, %{
          file: ".anchor.yml",
          line: nil,
          label: "anchor.graph",
          message: "COULD NOT MEASURE: x. Fix: y."
        })

      report = GraphReport.new([], [could_not], %{@counts | modules: 0})

      assert GraphReport.render(report, :text) ==
               ".anchor.yml:1: [enforce] anchor.graph COULD NOT MEASURE: x. Fix: y.\n" <>
                 "anchor.graph: 0 modules in 2 apps, 3 rules, 1 violations (0 report-only, 0 baselined)"
    end

    test "opaque modules are counted in the summary when there are any" do
      report = GraphReport.new([], [], %{@counts | opaque: 2})

      assert GraphReport.render(report, :text) ==
               "anchor.graph: 12 modules (2 opaque) in 2 apps, 3 rules, 0 violations (0 report-only, 0 baselined)"
    end
  end

  describe "render/2 functions with no Core body (DND-5549)" do
    test "are counted in the summary and the JSON when there are any" do
      report = GraphReport.new([], [], %{@counts | opaque: 2, no_core: 5})

      assert GraphReport.render(report, :text) ==
               "anchor.graph: 12 modules (2 opaque, 5 functions with no Core body) in 2 apps, " <>
                 "3 rules, 0 violations (0 report-only, 0 baselined)"

      assert %{"no_core" => 5} = JSON.decode!(GraphReport.render(report, :json))

      # Positive control: none, and the summary says nothing of them.
      refute GraphReport.render(GraphReport.new([], [], @counts), :text) =~ "Core"

      assert %{"no_core" => 0} =
               JSON.decode!(GraphReport.render(GraphReport.new([], [], @counts), :json))
    end
  end

  describe "render/2 dependency modules excluded (DND-5588)" do
    test "are counted in the summary and the JSON when there are any" do
      report = GraphReport.new([], [], %{@counts | excluded: 4})

      assert GraphReport.render(report, :text) ==
               "anchor.graph: 12 modules (4 dependency modules excluded) in 2 apps, " <>
                 "3 rules, 0 violations (0 report-only, 0 baselined)"

      assert %{"excluded" => 4} = JSON.decode!(GraphReport.render(report, :json))

      # Positive control: none, and the summary says nothing of them.
      refute GraphReport.render(GraphReport.new([], [], @counts), :text) =~ "excluded"
    end
  end

  describe "render/2 :json" do
    test "decodes with modules, findings and could_not_check; each finding splits message and fix" do
      could_not =
        finding(:enforce, %{
          rule_id: nil,
          type: nil,
          key: nil,
          label: "anchor.graph",
          message: "COULD NOT MEASURE: x. Fix: y."
        })

      report = GraphReport.new([finding(:report)], [could_not], @counts)

      assert %{
               "modules" => 12,
               "exit_code" => 3,
               "findings" => [finding_json],
               "could_not_check" => [
                 %{"message" => "COULD NOT MEASURE: x.", "fix" => "y.", "type" => nil}
               ]
             } = JSON.decode!(GraphReport.render(report, :json))

      assert finding_json == %{
               "rule_id" => "web",
               "type" => "layering",
               "enforcement" => "report",
               "key" => "MyApp.Web->MyApp.Repo",
               "file" => "lib/my_app/web.ex",
               "line" => 7,
               "message" => "MyApp.Web calls MyApp.Repo.",
               "fix" => "call a manager instead."
             }
    end
  end

  describe "Finding.enforcement/1" do
    test "a rule is enforced unless it says report" do
      assert Finding.enforcement(%{}) == :enforce
      assert Finding.enforcement(%{enforcement: :enforce}) == :enforce
      assert Finding.enforcement(%{enforcement: :report}) == :report
    end
  end
end
