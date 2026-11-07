defmodule Anchor.Domain.FailuresTest do
  # Domain (DND-1265): the text of every fail-closed report. Each message says
  # what was searched or what failed, that nothing was checked because of it,
  # and carries a `Fix:` line.
  #
  # Sabotage record: ../../sabotage_records/failures-20260929-dnd_1265_anchor_fail_closed.md
  # DND-5446 (one Fix: per issue; the moved refusals):
  #   ../../sabotage_records/rule_shapes-20261103-dnd_5443_graph_rules_b.md
  use ExUnit.Case, async: true

  alias Anchor.Domain.Failures
  alias Anchor.Domain.Violation

  describe "config_violation/1" do
    test "config not found names every searched path and sits on the first one" do
      searched = ["/p/apps/a/.anchor.yml", "/p/.anchor.yml"]

      assert %Violation{} = violation = Failures.config_violation({:config_not_found, searched})

      assert violation.filename == "/p/apps/a/.anchor.yml"
      assert violation.kind == :fail_closed
      assert violation.message =~ "Searched: /p/apps/a/.anchor.yml, /p/.anchor.yml."
      assert violation.message =~ "no Anchor rule was checked"
      assert violation.message =~ "Fix:"
    end

    test "an unreadable file names the path and the posix reason" do
      violation =
        Failures.config_violation({:config_load_failed, "/p/.anchor.yml", {:read, :eacces}})

      assert violation.filename == "/p/.anchor.yml"
      assert violation.message =~ "/p/.anchor.yml"
      assert violation.message =~ "eacces"
      assert violation.message =~ "Fix:"
    end

    test "invalid YAML carries the parser's message" do
      violation =
        Failures.config_violation(
          {:config_load_failed, "/p/.anchor.yml", {:yaml, "bad indent at line 3"}}
        )

      assert violation.message =~ "YAML"
      assert violation.message =~ "bad indent at line 3"
      assert violation.message =~ "Fix:"
    end

    test "an invalid rule carries the validation message" do
      violation =
        Failures.config_violation(
          {:config_load_failed, "/p/.anchor.yml",
           {:invalid_rule, ~s(rule 2: unknown rule type "x")}}
        )

      assert violation.message =~ ~s(rule 2: unknown rule type "x")
      assert violation.message =~ "Fix:"
    end

    test "an invalid document carries the validation message" do
      violation =
        Failures.config_violation(
          {:config_load_failed, "/p/.anchor.yml", {:invalid_config, "no `rules:` list"}}
        )

      assert violation.message =~ "no `rules:` list"
      assert violation.message =~ "Fix:"
    end

    # A loader is a behaviour, so a reason of a shape this module does not know
    # must still be reported, never dropped.
    test "an unrecognised reason is still reported" do
      violation = Failures.config_violation({:something_new, 1})

      assert violation.kind == :fail_closed
      assert violation.filename == ".anchor.yml"
      assert violation.message =~ "{:something_new, 1}"
      assert violation.message =~ "Fix:"
    end
  end

  describe "unparseable_violation/2" do
    test "names the parser message and line, on the checked file" do
      violation = Failures.unparseable_violation(3, "missing terminator: end")

      assert violation.line == 3
      assert violation.filename == nil
      assert violation.kind == :fail_closed
      assert violation.message =~ "could not parse"
      assert violation.message =~ "missing terminator: end"
      assert violation.message =~ "Fix:"
    end
  end

  # DND-1290: a rule that checked nothing in a run.
  # Sabotage record: ../../sabotage_records/failures-20260929-dnd_1290_empty_relation_list.md
  describe "rule_label/1" do
    test "names the position, the id when there is one, and the type" do
      assert Failures.rule_label(%{type: :must_use_module, index: 2, id: "web"}) ==
               ~s|rule 2 (id: "web", must_use_module)|

      assert Failures.rule_label(%{type: :must_use_module, index: 2, id: nil}) ==
               "rule 2 (must_use_module)"

      # A rule built in memory has no position.
      assert Failures.rule_label(%{type: :must_use_module}) == "rule (must_use_module)"
    end
  end

  describe "selection_floor_violation/4" do
    test "a rule that selected nothing checked nothing, on its config file" do
      rule = %{type: :no_direct_dependency, index: 1, id: "web-no-repo"}

      violation = Failures.selection_floor_violation(rule, 0, 1, "/p/.anchor.yml")

      assert %Violation{kind: :fail_closed, filename: "/p/.anchor.yml", line: nil} = violation
      assert violation.trigger == ~s|rule 1 (id: "web-no-repo", no_direct_dependency)|

      assert violation.message =~
               ~s|Anchor rule 1 (id: "web-no-repo", no_direct_dependency) selected 0 of the | <>
                 "1 file this check ran on, below its floor of 1 (min_files), so it " <>
                 "checked nothing."

      refute violation.message =~ "lower min_files"
      assert violation.message =~ ~r/Fix: [^\n]+\z/
    end

    test "a rule below a raised floor checked fewer files, and may lower min_files" do
      rule = %{type: :must_use_module, index: 3, min_files: 5}

      violation = Failures.selection_floor_violation(rule, 2, 40, "/p/.anchor.yml")

      assert violation.message =~ "selected 2 of the 40 files"
      assert violation.message =~ "below its floor of 5 (min_files)"
      assert violation.message =~ "checked fewer files than it requires"
      assert violation.message =~ "lower min_files"
    end

    test "with no config path, it sits on .anchor.yml" do
      violation = Failures.selection_floor_violation(%{type: :must_use_module}, 0, 3, nil)

      assert violation.filename == ".anchor.yml"
    end
  end

  describe "unchecked_rule_violation/3" do
    test "names the check to enable" do
      rule = %{type: :single_control_flow, index: 4}

      violation =
        Failures.unchecked_rule_violation(rule, Anchor.Check.SingleControlFlow, "/p/.anchor.yml")

      assert %Violation{kind: :fail_closed, filename: "/p/.anchor.yml"} = violation

      assert violation.message =~
               "Anchor rule 4 (single_control_flow) is not checked: no enabled Credo check " <>
                 "reads single_control_flow rules, so it checked nothing."

      assert violation.message =~ "Fix: enable Anchor.Check.SingleControlFlow in .credo.exs"
    end

    test "without a known check, names the rule type to look for" do
      violation = Failures.unchecked_rule_violation(%{type: :single_control_flow}, nil, nil)

      assert violation.message =~ "the Anchor check whose rule_type is single_control_flow"
      assert violation.filename == ".anchor.yml"
    end
  end

  # DND-5676. Sabotage record:
  # ../../sabotage_records/failures-20261106-dnd_5676_effects_cfa_batch.md
  describe "struct_flow_bound_hit/4" do
    test "one fail-closed issue on the config, naming the bound, the count and each function" do
      rule = %{id: "flow", type: :struct_owned_by_module_flow}
      functions = [{MyApp.X, :f, 1}, {MyApp.X, :g, 2}]

      assert %Violation{kind: :fail_closed, filename: "config/anchor.yml", line: nil} =
               violation =
               Failures.struct_flow_bound_hit(rule, functions, 6, "config/anchor.yml")

      assert violation.message ==
               ~s|rule (id: "flow", struct_owned_by_module_flow): the struct value flow | <>
                 "(Anchor.Domain.StructFlow) hit its bound of 6 passes on 2 function(s) " <>
                 "(MyApp.X.f/1, MyApp.X.g/2), so a write to a struct there may not be judged. " <>
                 "Fix: split the function's nested anonymous functions apart, or file this " <>
                 "line as a scale limit of Anchor. Raising the bound is the owner's call."
    end

    test "with no config path, the issue sits on the default config file" do
      violation =
        Failures.struct_flow_bound_hit(%{type: :struct_owned_by_module_flow}, [], 6, nil)

      assert violation.filename == ".anchor.yml"
    end
  end

  # DND-1310. Sabotage record:
  # ../../sabotage_records/failures-20260929-dnd_1310_analyzer_quote_crash.md
  describe "analysis_crash_violation/4" do
    test "sits on the file, names the check, the exception and the frame that raised" do
      # A frame in a loaded application (anchor): the text is the frame's
      # alone, with no `(app version)` prefix read from the VM.
      frame =
        {Anchor.Domain.DependencyAnalyzer, :walk_children, 3, [file: ~c"lib/a.ex", line: 7]}

      violation =
        Failures.analysis_crash_violation(
          Anchor.Check.NoDependency,
          :error,
          %FunctionClauseError{
            module: Anchor.Domain.DependencyAnalyzer,
            function: :walk_children,
            arity: 3
          },
          [frame]
        )

      assert %Violation{kind: :fail_closed, filename: nil, line: nil} = violation
      assert violation.trigger == "Anchor.Check.NoDependency"

      assert violation.message ==
               "Anchor check Anchor.Check.NoDependency crashed on this file, so it checked no " <>
                 "Anchor rule against it: FunctionClauseError: no function clause matching in " <>
                 "Anchor.Domain.DependencyAnalyzer.walk_children/3 (raised at lib/a.ex:7: " <>
                 "Anchor.Domain.DependencyAnalyzer.walk_children/3). Fix: this is a defect in " <>
                 "Anchor, not in this file; report it to Anchor with the file (or a minimal " <>
                 "snippet that reproduces it). Excluding the file from Credo silences this and " <>
                 "leaves the file unchecked."
    end

    test "a crash in the shared per-file analysis names Anchor, not a check" do
      violation =
        Failures.analysis_crash_violation(
          :file_analysis,
          :error,
          %ArgumentError{message: "x"},
          []
        )

      assert violation.trigger == "Anchor"

      assert violation.message =~
               "Anchor crashed analysing this file, so no Anchor rule was checked against it: " <>
                 "ArgumentError: x. Fix: "
    end

    test "a raw Erlang error, a throw and an exit are each named" do
      error = Failures.analysis_crash_violation(:file_analysis, :error, :badarg, [])
      thrown = Failures.analysis_crash_violation(:file_analysis, :throw, :oops, [])
      exited = Failures.analysis_crash_violation(:file_analysis, :exit, :normal, [])

      assert error.message =~ "against it: ArgumentError: argument error. Fix: "
      assert thrown.message =~ "against it: throw: :oops. Fix: "
      assert exited.message =~ "against it: exit: :normal. Fix: "
    end

    test "a long reason is capped at 300 characters" do
      reason = %MatchError{term: String.duplicate("a", 1000)}
      violation = Failures.analysis_crash_violation(:file_analysis, :error, reason, [])

      [_opening, rest] = String.split(violation.message, "against it: MatchError: ", parts: 2)
      [shown, _fix] = String.split(rest, ". Fix: ", parts: 2)

      assert String.length(shown) == 303
      assert String.ends_with?(shown, "...")
    end

    test "a frame carrying the arguments (a FunctionClauseError's) names the arity only" do
      frame =
        {Sample.Walker, :walk_children, [nil, %{secret: :state}], [file: ~c"lib/a.ex", line: 7]}

      violation =
        Failures.analysis_crash_violation(
          Anchor.Check.NoDependency,
          :error,
          %ArgumentError{message: "x"},
          [frame]
        )

      assert violation.message =~ "(raised at lib/a.ex:7: Sample.Walker.walk_children/2). Fix: "
      refute violation.message =~ "secret"
    end

    test "without a stacktrace it still reports, naming no frame" do
      violation =
        Failures.analysis_crash_violation(
          Anchor.Check.NoDependency,
          :error,
          %ArgumentError{message: "x"},
          []
        )

      assert violation.message =~ "against it: ArgumentError: x. Fix: "
    end
  end

  # DND-5446: every issue carries exactly one `Fix:`. A rejected rule whose
  # reason names its own Fix keeps that one; the generic Fix is only for a
  # reason with none.
  describe "one Fix: per rejected config" do
    defp rejected(reason),
      do:
        Failures.config_violation({:config_load_failed, ".anchor.yml", {:invalid_rule, reason}}).message

    test "a reason with no Fix gets the generic one, once" do
      message = rejected("rule 2: unknown rule type \"x\"")

      assert message =~
               ~s|rule 2: unknown rule type "x". Fix: correct .anchor.yml to match |

      assert length(String.split(message, "Fix:")) == 2
    end

    test "each moved load refusal keeps its own Fix, and only it" do
      for {reason, fix} <- [
            {Failures.owned_namespaces_empty(),
             ~s|Fix: list module names, e.g. ["MyApp"], or leave owned_namespaces out|},
            {Failures.owned_namespaces_not_a_module("App.*"),
             ~s|Fix: list module names, e.g. ["MyApp"]|},
            {Failures.pure_patterns_match_all("*"),
             ~s|Fix: name the pure namespaces, e.g. ["MyApp.*.Domain.*"]|}
          ] do
        message = rejected("rule 1: " <> reason)
        assert message =~ fix
        assert length(String.split(message, "Fix:")) == 2, message
        refute message =~ "correct .anchor.yml to match"
      end
    end
  end
end
