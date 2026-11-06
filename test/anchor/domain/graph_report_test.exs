defmodule Anchor.Domain.GraphReportTest do
  # DND-5440: the verdict of a graph run. Pure Domain: exit code, text and
  # JSON rendering from hand-built findings.
  #
  # Sabotage record: ../../sabotage_records/graph_runner-20261103-dnd_5440_graph_runner.md
  # Sabotage record: ../../sabotage_records/graph_runner-20261103-dnd_5551_graph_hardening.md
  # (apply sites, DND-5574: ../../sabotage_records/graph_runner-20261103-dnd_5574_cfa_wiring.md)
  # Sabotage record: ../../sabotage_records/graph_runner-20261103-dnd_5581_hardening_batch.md
  # Sabotage record: ../../sabotage_records/graph_runner-20261103-dnd_5630_graph_hardening.md
  # DND-5441 (held, refused, verbose):
  #   ../../sabotage_records/baseline-20261103-dnd_5441_graph_rules_a.md
  # DND-5443 (interface width):
  #   ../../sabotage_records/interface-20261103-dnd_5443_graph_rules_b.md
  # Sabotage record (DND-5633): ../../sabotage_records/graph_runner-20261103-dnd_5648_graph_followups.md
  use ExUnit.Case, async: true

  alias Anchor.Domain.GraphReport
  alias Anchor.Domain.GraphReport.Finding

  @counts %{
    modules: 12,
    apps: 2,
    rules: 3,
    opaque: 0,
    no_core: 0,
    outside_root: 0,
    apply_sites: nil
  }

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

  describe "apply sites (DND-5574, R6)" do
    alias Anchor.Domain.Cfa

    @sites %{
      total: 3,
      resolved: 2,
      any: 1,
      bound_hit?: false,
      by_function: %{{MyApp.X, :run, 1} => %{total: 3, resolved: 2, any: 1}}
    }

    test "apply_sites/1 takes the counts and the bound from the analysis; nil for none" do
      cfa = %Cfa{counts: Map.delete(@sites, :bound_hit?), bound_hit?: true}

      assert GraphReport.apply_sites(cfa) == %{@sites | bound_hit?: true}
      assert GraphReport.apply_sites(nil) == nil
    end

    test "the summary ends with the resolved and any counts when the analysis ran" do
      report = GraphReport.new([], [], Map.put(@counts, :apply_sites, @sites))

      assert GraphReport.summary(report) ==
               "anchor.graph: 12 modules in 2 apps, 3 rules, 0 violations " <>
                 "(0 report-only, 0 baselined); apply sites: 2 resolved, 1 any"
    end

    test "a bound hit is said, never read as a result" do
      sites = %{@sites | resolved: 0, any: 3, bound_hit?: true}
      report = GraphReport.new([], [], Map.put(@counts, :apply_sites, sites))

      assert GraphReport.summary(report) =~
               "; apply sites: 0 resolved, 3 any (step bound hit: every site reads any)"
    end

    test "no analysis: the summary says nothing of apply sites, and the JSON is null" do
      report = GraphReport.new([], [], Map.put(@counts, :apply_sites, nil))

      refute GraphReport.summary(report) =~ "apply sites"
      assert %{"apply_sites" => nil} = JSON.decode!(GraphReport.render(report, :json))
    end

    test "the JSON carries the same counts, per function too" do
      report = GraphReport.new([], [], Map.put(@counts, :apply_sites, @sites))

      assert JSON.decode!(GraphReport.render(report, :json))["apply_sites"] == %{
               "total" => 3,
               "resolved" => 2,
               "any" => 1,
               "bound_hit" => false,
               "by_function" => %{"MyApp.X.run/1" => %{"total" => 3, "resolved" => 2, "any" => 1}}
             }
    end
  end

  describe "interface width (DND-5443, R4)" do
    test "the summary ends with each context's width, sorted; the JSON has interface_width" do
      report =
        GraphReport.new([], [], Map.put(@counts, :interface_width, %{"B" => 2, "A" => 5}))

      assert GraphReport.summary(report) ==
               "anchor.graph: 12 modules in 2 apps, 3 rules, 0 violations " <>
                 "(0 report-only, 0 baselined); interface width: A=5, B=2"

      assert JSON.decode!(GraphReport.render(report, :json))["interface_width"] ==
               %{"A" => 5, "B" => 2}
    end

    test "no interface rule ran: nothing is printed, and the JSON is null" do
      report = GraphReport.new([], [], @counts)

      refute GraphReport.summary(report) =~ "interface width"
      assert %{"interface_width" => nil} = JSON.decode!(GraphReport.render(report, :json))
    end

    test "a run with an interface rule and no context says so" do
      report = GraphReport.new([], [], Map.put(@counts, :interface_width, %{}))

      assert GraphReport.summary(report) =~ "; interface width: no context"
    end
  end

  # DND-5633: an over-approximated dynamic call is counted, never silent.
  describe "dynamic calls (DND-5633)" do
    @dynamic %{
      narrowed: [{{MyApp.M, :typed, 2}, :run, 1}],
      fanned_out: [{{MyApp.L, :go, 1}, :check, 2}, {{MyApp.L, :any, 1}, :f, nil}]
    }

    test "the summary ends with the fanned-out and narrowed counts" do
      report = GraphReport.new([], [], Map.put(@counts, :dynamic_calls, @dynamic))

      assert GraphReport.summary(report) ==
               "anchor.graph: 12 modules in 2 apps, 3 rules, 0 violations " <>
                 "(0 report-only, 0 baselined); dynamic calls: 2 fanned out to every " <>
                 "exporter, 1 narrowed by behaviour"
    end

    test "the JSON names each call" do
      report = GraphReport.new([], [], Map.put(@counts, :dynamic_calls, @dynamic))

      assert JSON.decode!(GraphReport.render(report, :json))["dynamic_calls"] == %{
               "narrowed" => ["MyApp.M.typed/2 -> ?.run/1"],
               "fanned_out" => ["MyApp.L.go/1 -> ?.check/2", "MyApp.L.any/1 -> ?.f/?"]
             }
    end

    test "none, or no tally, says nothing" do
      none =
        GraphReport.new([], [], Map.put(@counts, :dynamic_calls, %{narrowed: [], fanned_out: []}))

      refute GraphReport.summary(none) =~ "dynamic calls"
      refute GraphReport.summary(GraphReport.new([], [], @counts)) =~ "dynamic calls"

      assert %{"dynamic_calls" => nil} =
               JSON.decode!(GraphReport.render(GraphReport.new([], [], @counts), :json))
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

  describe "render/2 modules outside the root (DND-5588, DND-5630)" do
    # Judged like every other module (DND-5630), and still counted, so the
    # layout is visible.
    test "are counted in the summary and the JSON when there are any" do
      report = GraphReport.new([], [], %{@counts | outside_root: 4})

      assert GraphReport.render(report, :text) ==
               "anchor.graph: 12 modules (4 outside the root) in 2 apps, " <>
                 "3 rules, 0 violations (0 report-only, 0 baselined)"

      assert %{"outside_root" => 4} = JSON.decode!(GraphReport.render(report, :json))

      # Positive control: none, and the summary says nothing of them.
      refute GraphReport.render(GraphReport.new([], [], @counts), :text) =~ "outside the root"
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

  # The anchor.graph review (struct_owned_by_module_flow): a finding's
  # enforcement is changed by its own module.
  describe "Finding.with_enforcement/2" do
    test "sets the enforcement and keeps every other field" do
      finding = %Finding{
        file: "lib/a.ex",
        line: 2,
        label: "rule 1",
        message: "m",
        key: "k",
        enforcement: :enforce
      }

      reported = Finding.with_enforcement(finding, :report)
      assert reported.enforcement == :report
      assert %{reported | enforcement: :enforce} == finding
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
