defmodule Anchor.Domain.GraphReportTest do
  # DND-5440: the verdict of a graph run. Pure Domain: exit code, text and
  # JSON rendering from hand-built findings.
  #
  # Sabotage record: ../../sabotage_records/graph_runner-20261103-dnd_5440_graph_runner.md
  # DND-5441 (held, refused, verbose):
  #   ../../sabotage_records/baseline-20261103-dnd_5441_graph_rules_a.md
  use ExUnit.Case, async: true

  alias Anchor.Domain.GraphReport
  alias Anchor.Domain.GraphReport.Finding

  @counts %{modules: 12, apps: 2, rules: 3, opaque: 0}

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

  # DND-5441: held findings and refusals.
  describe "held and refused" do
    test "a refusal is exit 2; 3 still wins over it; held findings never fail" do
      refusal = finding(:enforce, %{label: "anchor.graph"})
      assert GraphReport.new([], [], @counts, refused: [refusal]).exit_code == 2
      assert GraphReport.new([], [refusal], @counts, refused: [refusal]).exit_code == 3
      assert GraphReport.new([], [], @counts, held: [finding(:enforce)]).exit_code == 0
    end

    test "the summary counts held findings; refusals count as violations" do
      report =
        GraphReport.new([], [], @counts,
          held: [finding(:enforce), finding(:enforce)],
          refused: [finding(:enforce, %{label: "anchor.graph"})]
        )

      assert GraphReport.summary(report) =~ "1 violations (0 report-only, 2 baselined)"
    end

    test "held findings print only with verbose: true" do
      report = GraphReport.new([], [], @counts, held: [finding(:enforce)])

      refute GraphReport.render(report, :text) =~ "[held]"

      assert GraphReport.render(report, :text, verbose: true) =~
               ~s|lib/my_app/web.ex:7: [held] rule 1 (id: "web", layering) MyApp.Web calls|
    end

    test "JSON carries the refused and held findings" do
      report =
        GraphReport.new([], [], @counts,
          held: [finding(:enforce)],
          refused: [finding(:enforce, %{label: "anchor.graph"})]
        )

      assert %{"held" => [%{"key" => _}], "refused" => [_], "exit_code" => 2} =
               JSON.decode!(GraphReport.render(report, :json))
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
