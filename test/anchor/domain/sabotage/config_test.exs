defmodule Anchor.Domain.Sabotage.ConfigTest do
  # DND-5473: the `sabotage:` section of `.anchor.yml`, parsed and refused.
  # Sabotage record: ../../../sabotage_records/sabotage-20261103-dnd_5473_sabotage_run.md
  use ExUnit.Case, async: true

  alias Anchor.Domain.Sabotage.Config
  alias Anchor.Domain.Sabotage.Operators

  describe "parse/1" do
    test "1: an empty section gives every default" do
      assert {:ok, config} = Config.parse(%{})

      assert config.test_command == ["mix", "test", "--max-cases", "2"]
      assert config.max_mutants == 30
      assert config.timeout_seconds == 300
      assert config.operators == Operators.all()
      assert config.effect_calls == []
      assert config.coverage_map == nil

      assert config.test_mirror == [
               %{from: "apps/*/lib/**/*.ex", to: "apps/{app}/test/{rest}_test.exs"},
               %{from: "lib/**/*.ex", to: "test/{rest}_test.exs"}
             ]
    end

    test "1: a YAML null section (`sabotage:` alone) gives the defaults too" do
      assert Config.parse(nil) == Config.parse(%{})
    end

    test "every key is read" do
      assert {:ok, config} =
               Config.parse(%{
                 "test_command" => ["bin/test"],
                 "max_mutants" => 5,
                 "timeout_seconds" => 60,
                 "operators" => ["return_input", "delete_statement"],
                 "effect_calls" => ["Notifier.push/1"],
                 "test_mirror" => [%{"from" => "src/**/*.ex", "to" => "spec/{rest}_test.exs"}],
                 "coverage_map" => "anchor-coverage.etf"
               })

      assert config.test_command == ["bin/test"]
      assert {config.max_mutants, config.timeout_seconds} == {5, 60}
      assert config.operators == [:delete_statement, :return_input]
      assert config.effect_calls == ["Notifier.push/1"]
      assert config.test_mirror == [%{from: "src/**/*.ex", to: "spec/{rest}_test.exs"}]
      assert config.coverage_map == "anchor-coverage.etf"
    end

    @refusals [
      {"an unknown key", %{"max_mutant" => 3}, "sabotage: unknown key(s) \"max_mutant\""},
      {"an empty coverage_map (DND-5474)", %{"coverage_map" => ""}, "sabotage.coverage_map"},
      {"a coverage_map list (DND-5474)", %{"coverage_map" => ["x"]}, "sabotage.coverage_map"},
      {"an empty test_command", %{"test_command" => []}, "sabotage.test_command"},
      {"a non-string test_command element", %{"test_command" => [1]}, "sabotage.test_command"},
      {"max_mutants 0", %{"max_mutants" => 0}, "sabotage.max_mutants"},
      {"timeout_seconds a string", %{"timeout_seconds" => "x"}, "sabotage.timeout_seconds"},
      {"an unknown operator", %{"operators" => ["bogus"]}, "sabotage.operators names \"bogus\""},
      {"an empty operator list", %{"operators" => []}, "sabotage.operators"},
      {"a misspelt effect call", %{"effect_calls" => ["Notifier"]}, "sabotage.effect_calls"},
      {"a mirror entry without `to`", %{"test_mirror" => [%{"from" => "lib/**/*.ex"}]},
       "sabotage.test_mirror[1]"},
      {"a `to` using {app} with a `from` that binds none",
       %{
         "test_mirror" => [%{"from" => "lib/**/*.ex", "to" => "apps/{app}/test/{rest}_test.exs"}]
       }, "sabotage.test_mirror[1].to uses {app}"},
      {"a `from` that does not end in a `*<suffix>` file segment",
       %{"test_mirror" => [%{"from" => "lib/**", "to" => "test/{rest}_test.exs"}]},
       "sabotage.test_mirror[1].from"},
      {"a section that is not a mapping", ["mix"], "sabotage must be a mapping"}
    ]

    test "2: each refusal names its key and ends with a Fix: line" do
      for {label, section, prefix} <- @refusals do
        assert {:error, {:invalid_config, message}} = Config.parse(section), label
        assert String.starts_with?(message, prefix), "#{label}: #{message}"
        assert message =~ ~r/Fix: [^\n]+\z/, "#{label}: #{message}"
      end
    end
  end

  describe "Anchor.Config.parse_config/1" do
    test "`sabotage:` is a top-level key, parsed into :sabotage; absent, it is nil" do
      assert %Anchor.Config{sabotage: %Config{max_mutants: 4}} =
               Anchor.Config.parse_config(%{"rules" => [], "sabotage" => %{"max_mutants" => 4}})

      assert %Anchor.Config{sabotage: nil} = Anchor.Config.parse_config(%{"rules" => []})
    end

    test "a bad section fails the whole load" do
      assert {:error, {:invalid_config, "sabotage.max_mutants" <> _rest}} =
               Anchor.Config.parse_config(%{"rules" => [], "sabotage" => %{"max_mutants" => -1}})
    end
  end
end
