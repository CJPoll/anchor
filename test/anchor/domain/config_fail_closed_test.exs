defmodule Anchor.Domain.ConfigFailClosedTest do
  # DND-1265 (A8/A9 and the document shape): a config that names something
  # Anchor does not know must FAIL the load, never parse into a rule that
  # silently checks nothing. Pure Domain parser, no IO.
  #
  # Sabotage record: ../../sabotage_records/config-20260929-dnd_1265_anchor_fail_closed.md
  # Sabotage record (DND-1286 selector fixtures):
  # ../../sabotage_records/config-20260929-dnd_1286_rule_key_allowlist.md
  use ExUnit.Case, async: true

  alias Anchor.Config
  alias Anchor.Domain.RuleSchema

  describe "parse_rule/1 rule type (A8)" do
    test "an unknown type fails, naming the token and the known types" do
      assert {:error, {:invalid_rule, reason}} =
               parse_rule(%{
                 "type" => "no_direct_dependancy",
                 "forbidden_modules" => ["X"]
               })

      assert reason =~ ~s("no_direct_dependancy")
      assert reason =~ "no_direct_dependency"
      assert reason =~ "struct_getter_convention"
    end

    test "a missing type fails" do
      assert {:error, {:invalid_rule, reason}} =
               parse_rule(%{"forbidden_modules" => ["X"]})

      assert reason =~ "type"
    end

    test "a non-string type fails" do
      assert {:error, {:invalid_rule, reason}} = parse_rule(%{"type" => 42})
      assert reason =~ "42"
    end

    # A non-string type must not crash the message of an earlier validation
    # (here, same_context); the load fails with a reason, not an exception.
    test "a mapping as the type fails with a reason, not a crash" do
      assert {:error, {:invalid_rule, reason}} =
               parse_rule(%{"type" => %{"x" => 1}, "same_context" => "yes"})

      assert reason =~ ~s(%{"x" => 1})
    end

    test "a leading-colon type is accepted, as for match and mode" do
      assert %{type: :no_direct_dependency} =
               parse_rule(%{"type" => ":no_direct_dependency"})
    end

    test "every known type parses to its atom" do
      for type <- Config.rule_types() do
        assert %{type: ^type} = parse_rule(%{"type" => Atom.to_string(type)})
      end
    end

    # Drift guard: the Domain list of known types is the set of `rule_type/0`s
    # the shipped checks consume. A check added without its type here would have
    # every one of its rules rejected; a type here with no check would accept a
    # rule nothing reads.
    test "the known types are exactly the rule types of Anchor.checks/0" do
      check_types = Anchor.checks() |> Enum.map(& &1.rule_type()) |> Enum.sort()

      assert Enum.sort(Config.rule_types()) == check_types
    end
  end

  describe "parse_rule/1 match token (A9)" do
    test "an unknown match token fails instead of falling back to :reference" do
      assert {:error, {:invalid_rule, reason}} =
               parse_rule(%{"type" => "no_direct_dependency", "match" => "sideways"})

      assert reason =~ ~s("sideways")
      assert reason =~ "reference"
      assert reason =~ "call"
    end

    test "a leading-colon match token is accepted (YAML `match: :call`)" do
      assert %{match: :call} =
               parse_rule(%{"type" => "no_direct_dependency", "match" => ":call"})
    end
  end

  describe "parse_rule/1 mode token (same class as A9)" do
    test "an unknown mode token fails instead of falling back to :separate" do
      assert {:error, {:invalid_rule, reason}} =
               parse_rule(%{"type" => "alphabetized_functions", "mode" => "sideways"})

      assert reason =~ ~s("sideways")
      assert reason =~ "public_only"
    end

    # The README documents `mode: :all`. YAML decodes that to the string ":all",
    # which the old parser did not recognise and silently turned into :separate.
    test "the README's leading-colon mode tokens parse to their mode" do
      assert %{mode: :all} =
               parse_rule(%{"type" => "alphabetized_functions", "mode" => ":all"})

      assert %{mode: :public_only} =
               parse_rule(%{"type" => "alphabetized_functions", "mode" => ":public_only"})

      assert %{mode: :separate} =
               parse_rule(%{"type" => "alphabetized_functions", "mode" => ":separate"})
    end
  end

  describe "parse_rule/1 non-map rule" do
    test "a rule that is not a mapping fails" do
      assert {:error, {:invalid_rule, reason}} = parse_rule("no_direct_dependency")
      assert reason =~ "mapping"
    end
  end

  describe "parse_config/1 document shape" do
    test "an empty document (nil) fails: an empty .anchor.yml checks nothing" do
      assert {:error, {:invalid_config, reason}} = Config.parse_config(nil)
      assert reason =~ "rules"
    end

    test "a document with no `rules` key fails" do
      assert {:error, {:invalid_config, reason}} = Config.parse_config(%{})
      assert reason =~ "rules"
    end

    test "an unknown top-level key fails (a typo such as `anchors:` for `rules:`)" do
      data = %{"anchors" => [%{"type" => "no_direct_dependency"}]}

      assert {:error, {:invalid_config, reason}} = Config.parse_config(data)
      assert reason =~ ~s("anchors")
    end

    test "a `rules` value that is not a list fails" do
      assert {:error, {:invalid_config, reason}} = Config.parse_config(%{"rules" => "all"})
      assert reason =~ "list"
    end

    test "a top level that is not a mapping fails" do
      assert {:error, {:invalid_config, reason}} = Config.parse_config(["rules"])
      assert reason =~ "mapping"
    end

    test "an explicit empty rules list is a deliberate empty config" do
      assert %Config{rules: []} = Config.parse_config(%{"rules" => []})
    end

    test "an invalid rule names its 1-based position in the document" do
      data = %{
        "rules" => [
          %{"type" => "no_direct_dependency", "pattern" => "*", "forbidden_modules" => ["A"]},
          %{"type" => "no_direct_dependancy", "pattern" => "*"}
        ]
      }

      assert {:error, {:invalid_rule, reason}} = Config.parse_config(data)
      assert reason =~ "rule 2"
      assert reason =~ ~s("no_direct_dependancy")
    end
  end

  # DND-1286: a rule must carry a selector, or it fails the load. These rows are
  # about other keys, so a rule that names no selector of its own gets a
  # module-pattern one before it is parsed. The selector rows live in
  # rule_schema_test.exs.
  # These rows test the type, match and mode tokens, so a rule with no selector
  # gets a match-everything `pattern` (DND-1286) and a relation-bearing rule
  # with no relation gets a placeholder one (DND-1290).
  defp parse_rule(rule) when is_map(rule) do
    rule
    |> then(
      &if(has_any?(&1, RuleSchema.selector_keys()), do: &1, else: Map.put(&1, "pattern", "*"))
    )
    |> with_placeholder_relation()
    |> Config.parse_rule()
  end

  defp with_placeholder_relation(%{"type" => type} = rule) when is_binary(type) do
    case Enum.find(RuleSchema.rule_types(), &(":#{&1}" == type or "#{&1}" == type)) do
      nil -> rule
      known -> put_relation(rule, RuleSchema.relation_keys(known))
    end
  end

  defp with_placeholder_relation(rule), do: rule

  defp put_relation(rule, []), do: rule

  defp put_relation(rule, [key | _rest] = keys) do
    if has_any?(rule, keys), do: rule, else: Map.put(rule, key, ["Placeholder.Relation"])
  end

  defp has_any?(rule, keys), do: Enum.any?(keys, &Map.has_key?(rule, &1))

  defp parse_rule(rule), do: Config.parse_rule(rule)
end
