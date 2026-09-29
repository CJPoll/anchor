defmodule Anchor.Domain.ConfigFailClosedTest do
  # DND-1265 (A8/A9 and the document shape): a config that names something
  # Anchor does not know must FAIL the load, never parse into a rule that
  # silently checks nothing. Pure Domain parser, no IO.
  #
  # Sabotage record: ../../sabotage_records/config-20260929-dnd_1265_anchor_fail_closed.md
  use ExUnit.Case, async: true

  alias Anchor.Config

  describe "parse_rule/1 rule type (A8)" do
    test "an unknown type fails, naming the token and the known types" do
      assert {:error, {:invalid_rule, reason}} =
               Config.parse_rule(%{
                 "type" => "no_direct_dependancy",
                 "forbidden_modules" => ["X"]
               })

      assert reason =~ ~s("no_direct_dependancy")
      assert reason =~ "no_direct_dependency"
      assert reason =~ "struct_getter_convention"
    end

    test "a missing type fails" do
      assert {:error, {:invalid_rule, reason}} =
               Config.parse_rule(%{"forbidden_modules" => ["X"]})

      assert reason =~ "type"
    end

    test "a non-string type fails" do
      assert {:error, {:invalid_rule, reason}} = Config.parse_rule(%{"type" => 42})
      assert reason =~ "42"
    end

    # A non-string type must not crash the message of an earlier validation
    # (here, same_context); the load fails with a reason, not an exception.
    test "a mapping as the type fails with a reason, not a crash" do
      assert {:error, {:invalid_rule, reason}} =
               Config.parse_rule(%{"type" => %{"x" => 1}, "same_context" => "yes"})

      assert reason =~ ~s(%{"x" => 1})
    end

    test "every known type parses to its atom" do
      for type <- Config.rule_types() do
        assert %{type: ^type} = Config.parse_rule(%{"type" => Atom.to_string(type)})
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
               Config.parse_rule(%{"type" => "no_direct_dependency", "match" => "sideways"})

      assert reason =~ ~s("sideways")
      assert reason =~ "reference"
      assert reason =~ "call"
    end

    test "a leading-colon match token is accepted (YAML `match: :call`)" do
      assert %{match: :call} =
               Config.parse_rule(%{"type" => "no_direct_dependency", "match" => ":call"})
    end
  end

  describe "parse_rule/1 mode token (same class as A9)" do
    test "an unknown mode token fails instead of falling back to :separate" do
      assert {:error, {:invalid_rule, reason}} =
               Config.parse_rule(%{"type" => "alphabetized_functions", "mode" => "sideways"})

      assert reason =~ ~s("sideways")
      assert reason =~ "public_only"
    end

    # The README documents `mode: :all`. YAML decodes that to the string ":all",
    # which the old parser did not recognise and silently turned into :separate.
    test "the README's leading-colon mode tokens parse to their mode" do
      assert %{mode: :all} =
               Config.parse_rule(%{"type" => "alphabetized_functions", "mode" => ":all"})

      assert %{mode: :public_only} =
               Config.parse_rule(%{"type" => "alphabetized_functions", "mode" => ":public_only"})

      assert %{mode: :separate} =
               Config.parse_rule(%{"type" => "alphabetized_functions", "mode" => ":separate"})
    end
  end

  describe "parse_rule/1 non-map rule" do
    test "a rule that is not a mapping fails" do
      assert {:error, {:invalid_rule, reason}} = Config.parse_rule("no_direct_dependency")
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
          %{"type" => "no_direct_dependency"},
          %{"type" => "no_direct_dependancy"}
        ]
      }

      assert {:error, {:invalid_rule, reason}} = Config.parse_config(data)
      assert reason =~ "rule 2"
      assert reason =~ ~s("no_direct_dependancy")
    end
  end
end
