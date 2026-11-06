defmodule Anchor.Domain.Sabotage.ConfigTest do
  # DND-5473: the `sabotage:` section of `.anchor.yml`, parsed and refused.
  # Sabotage record: ../../../sabotage_records/sabotage-20261103-dnd_5473_sabotage_run.md
  # Sabotage record (DND-5489): ../../../sabotage_records/sabotage-20261106-dnd_5470_param_sink_locality.md
  # Sabotage record (DND-5490): ../../../sabotage_records/sabotage-20261106-dnd_5490_scan.md
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
      assert config.survivors == nil
      assert config.behaviour_locality_baseline == nil
      assert config.behaviour_locality_enforcement == :report
      assert config.scan_shards == 7

      assert config.records == %{
               dir: "test/sabotage_records",
               naming: :domain_date_slot,
               domain_from: :module,
               domain_strip_prefixes: [],
               adr: "the repo's sabotage-record ADR"
             }

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
                 "coverage_map" => "anchor-coverage.etf",
                 "survivors" => "sabotage/survivors.txt",
                 "behaviour_locality_baseline" => "b/locality.txt",
                 "behaviour_locality_enforcement" => "enforce",
                 "scan_shards" => 30,
                 "records" => %{
                   "dir" => "apps/{app}/test/sabotage_records",
                   "naming" => "ticket_nn_what",
                   "domain_from" => "context_dir",
                   "domain_strip_prefixes" => ["App."],
                   "adr" => "ADR 26"
                 }
               })

      assert config.test_command == ["bin/test"]
      assert {config.max_mutants, config.timeout_seconds} == {5, 60}
      assert config.operators == [:delete_statement, :return_input]
      assert config.effect_calls == ["Notifier.push/1"]
      assert config.test_mirror == [%{from: "src/**/*.ex", to: "spec/{rest}_test.exs"}]
      assert config.coverage_map == "anchor-coverage.etf"
      assert config.survivors == "sabotage/survivors.txt"
      assert config.behaviour_locality_baseline == "b/locality.txt"
      assert config.behaviour_locality_enforcement == :enforce
      assert config.scan_shards == 30

      assert config.records == %{
               dir: "apps/{app}/test/sabotage_records",
               naming: :ticket_nn_what,
               domain_from: :context_dir,
               domain_strip_prefixes: ["App."],
               adr: "ADR 26"
             }
    end

    @refusals [
      {"an unknown key", %{"max_mutant" => 3}, "sabotage: unknown key(s) \"max_mutant\""},
      {"an empty coverage_map (DND-5474)", %{"coverage_map" => ""}, "sabotage.coverage_map"},
      {"a coverage_map list (DND-5474)", %{"coverage_map" => ["x"]}, "sabotage.coverage_map"},
      {"an absolute locality baseline (DND-5489)",
       %{"behaviour_locality_baseline" => "/tmp/b.txt"},
       "sabotage.behaviour_locality_baseline must be a path inside the project"},
      {"a locality baseline outside the project (DND-5489)",
       %{"behaviour_locality_baseline" => "../b.txt"},
       "sabotage.behaviour_locality_baseline must be a path inside the project"},
      {"an empty locality baseline (DND-5489)", %{"behaviour_locality_baseline" => ""},
       "sabotage.behaviour_locality_baseline must be a path inside the project"},
      {"an unknown locality mode (DND-5489)", %{"behaviour_locality_enforcement" => "warn"},
       "sabotage.behaviour_locality_enforcement must be report or enforce"},
      {"an empty survivors path (DND-5483)", %{"survivors" => ""},
       "sabotage.survivors must be a path inside the project"},
      {"an absolute survivors path (DND-5483)", %{"survivors" => "/tmp/s.txt"},
       "sabotage.survivors must be a path inside the project"},
      {"a survivors path with a .. segment (DND-5483)", %{"survivors" => "a/../../s.txt"},
       "sabotage.survivors must be a path inside the project"},
      {"an unknown records key (DND-5484)", %{"records" => %{"dirr" => "x"}},
       "sabotage.records: unknown key(s) \"dirr\""},
      {"an unknown naming (DND-5484)", %{"records" => %{"naming" => "by_date"}},
       "sabotage.records.naming \"by_date\" is not one of domain_date_slot, ticket_nn_what"},
      {"an unknown domain_from (DND-5484)", %{"records" => %{"domain_from" => "file"}},
       "sabotage.records.domain_from \"file\" is not one of context_dir, module"},
      {"records not a mapping (DND-5484)", %{"records" => "x"},
       "sabotage.records must be a mapping"},
      {"a prefix list with a number (DND-5484)",
       %{"records" => %{"domain_strip_prefixes" => [1]}},
       "sabotage.records.domain_strip_prefixes"},
      {"an empty records dir (DND-5484)", %{"records" => %{"dir" => ""}}, "sabotage.records.dir"},
      {"an absolute records dir (DND-5484)", %{"records" => %{"dir" => "/tmp/r"}},
       "sabotage.records.dir must be a directory inside the project"},
      {"a records dir with a .. segment (DND-5484)", %{"records" => %{"dir" => "test/../../r"}},
       "sabotage.records.dir must be a directory inside the project"},
      {"a records dir of only ./ (DND-5484)", %{"records" => %{"dir" => "./"}},
       "sabotage.records.dir must be a directory inside the project"},
      {"an empty test_command", %{"test_command" => []}, "sabotage.test_command"},
      {"a non-string test_command element", %{"test_command" => [1]}, "sabotage.test_command"},
      {"max_mutants 0", %{"max_mutants" => 0}, "sabotage.max_mutants"},
      {"scan_shards 0 (DND-5490)", %{"scan_shards" => 0},
       "sabotage.scan_shards must be a positive integer"},
      {"scan_shards a string (DND-5490)", %{"scan_shards" => "7"},
       "sabotage.scan_shards must be a positive integer"},
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

    test "DND-5484: records.dir is read without a leading ./ or a trailing /" do
      # Sabotage record: ../../../sabotage_records/sabotage-20261103-dnd_5484_records.md
      # Existing records are keyed by Path.dirname/1, which never ends in /.
      for dir <- ["test/sabotage_records/", "./test/sabotage_records", "test//sabotage_records"] do
        assert {:ok, %Config{records: %{dir: "test/sabotage_records"}}} =
                 Config.parse(%{"records" => %{"dir" => dir}}),
               dir
      end
    end

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
