defmodule Anchor.Domain.RuleShapesTest do
  # DND-5446: every rule type has a conforming shape, and with_fix/2 ends a
  # message with exactly one Fix: line. Pure Domain.
  #
  # Sabotage record: ../../sabotage_records/rule_shapes-20261103-dnd_5443_graph_rules_b.md
  use ExUnit.Case, async: true

  alias Anchor.Config
  alias Anchor.Domain.RuleSchema
  alias Anchor.Domain.RuleShapes
  alias Anchor.Domain.Violation

  # A parsed rule of every type, through the real loader, so a shape reads
  # the keys a real rule carries.
  defp rule(type) do
    base = %{"type" => Atom.to_string(type), "pattern" => "MyApp.*"}

    extra =
      case type do
        :must_use_module -> %{"required_modules" => ["MyApp.Base"]}
        :no_direct_dependency -> %{"forbidden_modules" => ["MyApp.Repo"]}
        :no_transitive_dependency -> %{"forbidden_modules" => ["MyApp.Repo"]}
        _other -> %{}
      end

    Config.parse_rule(Map.merge(base, extra))
  end

  describe "for/1" do
    test "every rule type in RuleSchema.rule_types/0 has a non-empty shape" do
      for type <- RuleSchema.rule_types() do
        shape = RuleShapes.for(rule(type))
        assert is_binary(shape) and String.trim(shape) != "", "#{type}: #{inspect(shape)}"
        refute shape =~ "Fix:", "#{type}: a shape is the Fix: text, not another Fix: line"
      end
    end

    test "positive control: a type with no shape raises FunctionClauseError" do
      assert_raise FunctionClauseError, fn -> RuleShapes.for(%{type: :no_such_type}) end
    end

    test "a shape reads the rule's own keys" do
      assert RuleShapes.for(%{type: :max_file_length, max_lines: 120}) =~ "at most 120 lines"

      assert RuleShapes.for(rule(:no_direct_dependency)) =~
               "do not reference MyApp.Repo from a module this rule selects"

      assert RuleShapes.for(%{type: :alphabetized_functions, mode: :all}) =~
               "every function of the module in alphabetical order"

      assert RuleShapes.for(%{type: :module_pattern_restrictions, allowed_functions: ["new"]}) ==
               "define only the allowed functions: new"
    end
  end

  describe "with_fix/2" do
    @rule %{type: :single_control_flow}

    test "appends ` Fix: <shape>` once, after a full stop" do
      assert RuleShapes.with_fix("Too many structures", @rule) ==
               "Too many structures. Fix: " <> RuleShapes.for(@rule)

      assert RuleShapes.with_fix("Too many structures.", @rule) ==
               "Too many structures. Fix: " <> RuleShapes.for(@rule)
    end

    test "a message that already carries a Fix: is not given a second" do
      assert RuleShapes.with_fix("Cannot resolve. Fix: name it literally.", @rule) ==
               "Cannot resolve. Fix: name it literally."
    end

    test "a violation's message is given its Fix" do
      assert %Violation{message: message, line: 3} =
               RuleShapes.with_fix(%Violation{message: "Bad", line: 3}, @rule)

      assert RuleShapes.fix_count(message) == 1
    end
  end

  describe "fix_count/1" do
    test "counts Fix: sentences" do
      assert RuleShapes.fix_count("none") == 0
      assert RuleShapes.fix_count("a. Fix: b") == 1
      assert RuleShapes.fix_count("a. Fix: b. Fix: c") == 2
    end
  end
end
