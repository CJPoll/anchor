defmodule Anchor.Domain.FailuresTest do
  # Domain (DND-1265): the text of every fail-closed report. Each message says
  # what was searched or what failed, that nothing was checked because of it,
  # and carries a `Fix:` line.
  #
  # Sabotage record: ../../sabotage_records/failures-20260929-dnd_1265_anchor_fail_closed.md
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
end
