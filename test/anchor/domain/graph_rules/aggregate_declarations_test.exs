defmodule Anchor.Domain.GraphRules.AggregateDeclarationsTest do
  # DND-5476: the aggregate_declarations graph rule. Pure Domain, over
  # hand-built models whose index holds the issues.
  #
  # Sabotage record: ../../../sabotage_records/aggregates-20261103-dnd_5476_aggregate_decls.md
  # Sabotage record: ../../../sabotage_records/aggregates-20261103-dnd_5659_aggregates_none.md (DND-5659)
  use ExUnit.Case, async: true

  alias Anchor.Config
  alias Anchor.Domain.Aggregates.Declaration
  alias Anchor.Domain.Aggregates.DeclarationIssue
  alias Anchor.Domain.Aggregates.Index
  alias Anchor.Domain.Classification
  alias Anchor.Domain.Graph
  alias Anchor.Domain.GraphRules.AggregateDeclarations
  alias Anchor.Domain.Model

  @rule %{type: :aggregate_declarations, id: "aggregates", paths: ["lib/**"]}

  @shape "aggregates: declare: - name: <Aggregate>, schemas: [<Schema>...], " <>
           "tables: [\"<table>\"...], owners: [<Module>...], or use Anchor.Aggregate, " <>
           "name: <Aggregate>, schemas: [<Schema>...]"

  @store_site {:attribute, App.Store, "lib/app/store.ex", 3}
  @x_site {:attribute, App.X, "lib/app/x.ex", 7}

  defp model(issues, aggregates \\ %{"A" => %Declaration{name: "A", schemas: [App.S]}}) do
    classification =
      Map.new([App.Store, App.X], fn module ->
        file = "lib/app/#{module |> Module.split() |> List.last() |> String.downcase()}.ex"

        {module,
         %Classification{
           module: module,
           bucket: "b",
           role: :domain,
           context: "App",
           source_file: file
         }}
      end)

    %Model{
      graph: %Graph{},
      architecture: nil,
      classification: classification,
      config: %Config{path: ".anchor.yml"},
      aggregates: %Index{aggregates: aggregates, issues: issues}
    }
  end

  @one_of_each [
    %DeclarationIssue{
      kind: :claimed_twice,
      subject: App.S,
      aggregates: ["A", "B"],
      site: :config
    },
    %DeclarationIssue{kind: :claimed_twice, subject: "s", aggregates: ["A", "B"], site: @x_site},
    %DeclarationIssue{kind: :unknown_schema, subject: Nope, aggregates: ["A"], site: :config},
    %DeclarationIssue{
      kind: :not_a_schema,
      subject: App.Plain,
      aggregates: ["A"],
      site: @store_site
    },
    %DeclarationIssue{kind: :unknown_owner, subject: Ghost, aggregates: ["A"], site: :config},
    %DeclarationIssue{kind: :empty_aggregate, subject: "E", aggregates: ["E"], site: :config},
    %DeclarationIssue{
      kind: :malformed_attribute,
      subject: App.X,
      site: @x_site,
      detail: "it has no name"
    }
  ]

  describe "check/2" do
    test "R1: one violation per issue, at its site, keyed without lines, ending in the shape" do
      violations = AggregateDeclarations.check(model(@one_of_each), @rule)

      assert length(violations) == 7

      for v <- violations do
        assert v.rule_id == "aggregates"
        assert String.ends_with?(v.message, @shape), v.message
        assert v.message =~ ". Fix: "
        refute v.key =~ ~r/\d/, v.key
      end

      assert Enum.map(violations, &{&1.filename, &1.line}) == [
               {".anchor.yml", nil},
               {"lib/app/x.ex", 7},
               {".anchor.yml", nil},
               {"lib/app/store.ex", 3},
               {".anchor.yml", nil},
               {".anchor.yml", nil},
               {"lib/app/x.ex", 7}
             ]

      assert Enum.map(violations, & &1.key) == [
               "aggregates|.anchor.yml|claimed_twice A,B App.S",
               ~s(aggregates|App.X|claimed_twice A,B "s"),
               "aggregates|.anchor.yml|unknown_schema A Nope",
               "aggregates|App.Store|not_a_schema A App.Plain",
               "aggregates|.anchor.yml|unknown_owner A Ghost",
               "aggregates|.anchor.yml|empty_aggregate E E",
               "aggregates|App.X|malformed_attribute - App.X"
             ]

      [twice, table, unknown, not_schema, owner, empty, malformed] =
        Enum.map(violations, & &1.message)

      assert twice =~
               "schema App.S is claimed by A and B. Fix: list it in exactly one aggregate; the " <>
                 "other reaches it through an outbox row consumed by the owner: "

      assert table =~ ~s(table "s" is claimed by A and B.)
      assert unknown =~ "Nope in aggregate A names no module in this project. Fix: correct"
      assert not_schema =~ "App.Plain in aggregate A is not an Ecto schema (no __schema__/1)."
      assert owner =~ "Ghost in aggregate A names no module in this project."
      assert empty =~ "aggregate E declares no schemas and no tables. Fix: add schemas:"

      assert malformed =~
               "@anchor_aggregate on App.X is not [name: atom, schemas: [atom], tables: " <>
                 "[binary], owner: boolean]: it has no name. Fix: "
    end

    test "R2: zero aggregates declared is one fail-closed violation on .anchor.yml, unkeyed" do
      assert [v] = AggregateDeclarations.check(model([], %{}), @rule)

      assert v.filename == ".anchor.yml"
      assert v.kind == :fail_closed
      assert v.key == nil

      assert v.message ==
               ~s|rule (id: "aggregates", aggregate_declarations) checks nothing: no aggregate | <>
                 "is declared in .anchor.yml or by an @anchor_aggregate attribute. Fix: declare " <>
                 "one or remove the rule: " <> @shape
    end

    test "R2: the config's own path is where a config-site violation sits" do
      model = %{model([], %{}) | config: %Config{path: "/repo/.anchor.yml"}}
      assert [%{filename: "/repo/.anchor.yml"}] = AggregateDeclarations.check(model, @rule)
    end

    test "R3: an attribute issue outside the selector is not reported; a config one still is" do
      issues = [
        %DeclarationIssue{
          kind: :not_a_schema,
          subject: App.Plain,
          aggregates: ["A"],
          site: @x_site
        },
        %DeclarationIssue{kind: :unknown_schema, subject: Nope, aggregates: ["A"], site: :config}
      ]

      outside =
        AggregateDeclarations.check(
          model(issues),
          %{@rule | paths: nil} |> Map.put(:pattern, "Other.*")
        )

      assert [%{key: "aggregates|.anchor.yml|unknown_schema A Nope"}] = outside

      # Positive control: a selector that selects App.X reports both.
      inside = AggregateDeclarations.check(model(issues), %{@rule | paths: ["lib/app/x.ex"]})
      assert length(inside) == 2
    end

    test "R4: a clean index with an aggregate gives nothing" do
      assert AggregateDeclarations.check(model([]), @rule) == []
    end

    test "R2: zero aggregates with issues: each issue, then the checks-nothing line" do
      issue = %DeclarationIssue{
        kind: :malformed_attribute,
        subject: App.X,
        site: @x_site,
        detail: "it has no name"
      }

      assert [%{kind: :rule}, %{kind: :fail_closed}] =
               AggregateDeclarations.check(model([issue], %{}), @rule)
    end

    test "a rule with no id keys an issue by its type" do
      issue = %DeclarationIssue{
        kind: :unknown_schema,
        subject: Nope,
        aggregates: ["A"],
        site: :config
      }

      assert [v] = AggregateDeclarations.check(model([issue]), Map.delete(@rule, :id))
      assert v.key == "aggregate_declarations|.anchor.yml|unknown_schema A Nope"
    end
  end

  # DND-5659: `aggregates: declare: none`.
  describe "check/2 under declare: none" do
    @persists %DeclarationIssue{
      kind: :persists_under_none,
      subject: App.Store,
      site: {:module, App.Store, "lib/app/store.ex", 3},
      detail: "it calls MyApp.Repo.insert/2 (line 9)"
    }

    defp none_model(issues),
      do: %{model(issues, %{}) | aggregates: %Index{none: "no database", issues: issues}}

    test "Z3: none with nothing persisting is clean: no checks-nothing violation" do
      assert AggregateDeclarations.check(none_model([]), @rule) == []
    end

    test "Z4: a module that persists is one violation at its module, naming it, with the Fix" do
      assert [v] = AggregateDeclarations.check(none_model([@persists]), @rule)

      assert v.kind == :rule
      assert {v.filename, v.line} == {"lib/app/store.ex", 3}
      assert v.key == "aggregates|App.Store|persists_under_none - App.Store"

      assert v.message ==
               "App.Store persists (it calls MyApp.Repo.insert/2 (line 9)), but .anchor.yml " <>
                 "says aggregates: declare: none (no database). Fix: declare the aggregate and " <>
                 "remove declare: none: " <> @shape
    end

    test "Z4: a persisting module outside the selector is not reported" do
      rule = @rule |> Map.put(:paths, nil) |> Map.put(:pattern, "Other.*")
      assert AggregateDeclarations.check(none_model([@persists]), rule) == []
    end
  end

  describe "shape/1" do
    test "S1: the documented declaration shape" do
      assert AggregateDeclarations.shape(@rule) == @shape
      assert AggregateDeclarations.rule_type() == :aggregate_declarations
    end
  end
end
