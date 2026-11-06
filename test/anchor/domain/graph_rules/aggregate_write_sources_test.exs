defmodule Anchor.Domain.GraphRules.AggregateWriteSourcesTest do
  # DND-5459: the aggregate_write_sources graph rule. Pure Domain, over
  # hand-built models whose analysis holds what it reports; V5 loads a config.
  #
  # Sabotage record: ../../../sabotage_records/aggregates-20261103-dnd_5459_write_sets.md
  # and ../../../sabotage_records/aggregates-20261106-dnd_5459_write_sets.md
  use ExUnit.Case, async: true

  alias Anchor.Config
  alias Anchor.Domain.Aggregates.Analysis
  alias Anchor.Domain.Aggregates.Scope
  alias Anchor.Domain.Aggregates.WriteSite
  alias Anchor.Domain.Classification
  alias Anchor.Domain.Graph
  alias Anchor.Domain.Graph.ModuleNode
  alias Anchor.Domain.GraphRules.AggregateWriteSources
  alias Anchor.Domain.Model

  @rule %{type: :aggregate_write_sources, id: "writes", paths: ["lib/app/**"]}

  @unresolved %WriteSite{
    mfa: {App.Store, :save, 1},
    line: 12,
    op: :insert,
    via: :repo,
    unresolved: "parameter 1 of App.Store.save/1 has no @spec and no project caller"
  }

  @resolved %WriteSite{
    mfa: {App.Store, :put, 0},
    line: 20,
    op: :insert,
    via: :repo,
    sources: [{:schema, App.S}],
    scopes: [1]
  }

  @incomplete %Scope{
    mfa: {App.Store, :run, 1},
    ordinal: 1,
    line: 30,
    kind: :fun,
    no_gap_noticed?: false,
    gaps: [{:dynamic_call, {App.Store, :run, 1}, 31}]
  }

  @complete %Scope{mfa: {App.Store, :put, 0}, ordinal: 1, line: 19, kind: :fun}

  @raw %{
    mfa: {App.Store, :purge, 0},
    line: 40,
    what: "raw SQL (App.Repo.query!/1) Anchor cannot attribute"
  }

  defp model(analysis) do
    classification = %{
      App.Store => %Classification{
        module: App.Store,
        bucket: "b",
        role: :domain,
        context: "App",
        source_file: "lib/app/store.ex"
      },
      Other.Thing => %Classification{
        module: Other.Thing,
        bucket: "b",
        role: :domain,
        context: "Other",
        source_file: "lib/other/thing.ex"
      }
    }

    %Model{
      graph: %Graph{
        modules: %{
          App.Store => %ModuleNode{module: App.Store, app: :app, source_file: "lib/app/store.ex"}
        }
      },
      architecture: nil,
      classification: classification,
      config: %Config{path: ".anchor.yml"},
      aggregate_analysis: analysis
    }
  end

  describe "check/2" do
    test "V1: one unresolved write and one incomplete scope, keyed without lines, ending in Fix:" do
      analysis = %Analysis{sites: [@unresolved, @resolved], scopes: [@incomplete, @complete]}

      assert [unresolved, incomplete] = AggregateWriteSources.check(model(analysis), @rule)

      assert unresolved.filename == "lib/app/store.ex"
      assert unresolved.line == 12

      assert unresolved.key ==
               "writes|App.Store.save/1|unresolved insert parameter 1 of App.Store.save/1 has no " <>
                 "@spec and no project caller"

      assert unresolved.message =~
               "Repo.insert in App.Store.save/1 writes a value Anchor cannot trace to a schema or table"

      assert unresolved.message =~ ". Fix: pass a struct, changeset or schema"

      assert incomplete.line == 30
      assert incomplete.key == "writes|App.Store.run/1|incomplete 1"

      assert incomplete.message =~
               "transaction 1 in App.Store.run/1 reaches 1 call(s) Anchor cannot resolve " <>
                 "(first: App.Store.run/1 line 31), so its write set is incomplete. Fix:"

      refute unresolved.key =~ "12"
      refute incomplete.key =~ "30"
    end

    test "raw SQL outside a transaction is reported, keyed without its line, with a Fix" do
      analysis = %Analysis{sites: [@resolved], unattributed: [@raw]}

      assert [finding] = AggregateWriteSources.check(model(analysis), @rule)
      assert finding.line == 40
      assert finding.filename == "lib/app/store.ex"

      assert finding.key ==
               "writes|App.Store.purge/0|unattributed raw SQL (App.Repo.query!/1) Anchor cannot " <>
                 "attribute"

      assert finding.message =~
               "App.Store.purge/0 writes, or may write, with no transaction read around it"

      assert finding.message =~ "Fix:"
    end

    test "unattributed writes outside the selector are not reported" do
      other = %{@raw | mfa: {Other.Thing, :purge, 0}}
      analysis = %Analysis{sites: [@resolved], unattributed: [other]}

      assert AggregateWriteSources.check(model(analysis), @rule) == []
    end

    test "selected modules holding only raw SQL have writes: no checks-nothing failure" do
      analysis = %Analysis{unattributed: [@raw]}

      assert [%{line: 40}] = AggregateWriteSources.check(model(analysis), @rule)
    end

    test "selected modules holding only an incomplete transaction: no checks-nothing failure" do
      analysis = %Analysis{scopes: [@incomplete]}

      assert [%{line: 30}] = AggregateWriteSources.check(model(analysis), @rule)
    end

    test "V1: a finding outside the selector is not reported" do
      outside = %{@unresolved | mfa: {Other.Thing, :save, 1}}

      analysis = %Analysis{
        sites: [outside, @resolved],
        scopes: [%{@incomplete | mfa: {Other.Thing, :run, 1}}]
      }

      assert AggregateWriteSources.check(model(analysis), @rule) == []
    end

    test "V2: no repo is one fail-closed violation on .anchor.yml" do
      assert [violation] = AggregateWriteSources.check(model(%Analysis{no_repo?: true}), @rule)
      assert violation.kind == :fail_closed
      assert violation.filename == ".anchor.yml"
      assert violation.message =~ "no Ecto repo found"
      assert violation.message =~ "Fix: list the repo under aggregates.repos."
    end

    test "V2: no analysis at all reads as no repo, never as clean" do
      assert [%{kind: :fail_closed, message: message}] =
               AggregateWriteSources.check(model(nil), @rule)

      assert message =~ "no Ecto repo found"
    end

    test "V3: a selector that matches no write checks nothing, fail-closed" do
      analysis = %Analysis{sites: [%{@resolved | mfa: {Other.Thing, :put, 0}}]}
      assert [violation] = AggregateWriteSources.check(model(analysis), @rule)
      assert violation.kind == :fail_closed

      assert violation.message =~
               ~s|checks nothing: no write found in paths ["lib/app/**"]. Fix: correct the selector|
    end

    test "V4: a clean model (positive control) has no violation" do
      analysis = %Analysis{sites: [@resolved], scopes: [@complete]}
      assert AggregateWriteSources.check(model(analysis), @rule) == []
    end
  end

  describe "V5: loading" do
    @architecture %{
      "contexts" => %{"depth" => 2},
      "buckets" => [
        %{"name" => "domain", "role" => "domain", "select" => [%{"paths" => ["lib/**"]}]}
      ],
      "calls" => %{"domain" => ["domain"]}
    }

    @rule_yaml %{"type" => "aggregate_write_sources", "id" => "writes", "paths" => ["lib/**"]}

    test "a rule with no aggregates: section is refused, the Fix naming the section" do
      assert {:error, {:invalid_rule, message}} =
               Config.parse_config(%{"rules" => [@rule_yaml], "architecture" => @architecture})

      assert message ==
               ~s|rule 1 (id: "writes"): aggregate_write_sources needs an aggregates: section in | <>
                 ".anchor.yml. Fix: add aggregates: (repos:, declare:) or remove the rule."
    end

    # Both review-floor reviewers: under `declare: none` there is no repo to
    # list, so the rule's "no repo" Fix could not be followed; the load
    # refuses the pair instead.
    test "a rule beside declare: none is refused, the Fix naming both ways out" do
      assert {:error, {:invalid_rule, message}} =
               Config.parse_config(%{
                 "rules" => [@rule_yaml],
                 "architecture" => @architecture,
                 "aggregates" => %{"declare" => "none", "reason" => "no database"}
               })

      assert message ==
               ~s|rule 1 (id: "writes"): aggregate_write_sources reads the writes of a | <>
                 "project with a repo, but .anchor.yml says aggregates: declare: none. Fix: " <>
                 "remove the rule, or declare the aggregates and the repo instead of none."
    end

    test "positive control: with the section it loads" do
      assert %Config{rules: [%{type: :aggregate_write_sources}]} =
               Config.parse_config(%{
                 "rules" => [@rule_yaml],
                 "architecture" => @architecture,
                 "aggregates" => %{"repos" => ["MyApp.Repo"]}
               })
    end
  end
end
