defmodule Anchor.Domain.ClassificationPlannedTest do
  # DND-5446: classifying a module before it is compiled, by path and name
  # only. Pure Domain.
  #
  # Sabotage record: ../../sabotage_records/explain-20261103-dnd_5443_graph_rules_b.md
  use ExUnit.Case, async: true

  alias Anchor.Domain.Architecture
  alias Anchor.Domain.Classification

  defp arch(buckets) do
    {:ok, arch} =
      Architecture.parse(%{
        "contexts" => %{"depth" => 2},
        "buckets" => buckets,
        "calls" => Map.new(buckets, &{&1["name"], [&1["name"]]})
      })

    arch
  end

  @domain %{
    "name" => "domain",
    "role" => "domain",
    "select" => [%{"paths" => ["lib/**/domain/**/*.ex"]}]
  }
  @framework %{
    "name" => "framework",
    "role" => "framework",
    "select" => [%{"uses_module" => "GenServer"}]
  }

  describe "classify_planned/3" do
    test "a path its bucket's paths select is definite" do
      assert Classification.classify_planned(
               "lib/app/domain/thing.ex",
               App.Domain.Thing,
               arch([@domain])
             ) == %{definite: "domain", ambiguous: [], possible: [], unknown: []}
    end

    test "a definite bucket still names a beam selector that could also match it (ambiguity)" do
      assert Classification.classify_planned(
               "lib/app/domain/thing.ex",
               App.Domain.Thing,
               arch([@domain, @framework])
             ) == %{
               definite: "domain",
               ambiguous: [],
               possible: ["framework"],
               unknown: [:uses_module]
             }
    end

    test "a pattern selector decides by the module name alone" do
      managers = %{
        "name" => "managers",
        "role" => "managers",
        "select" => [%{"pattern" => "*.Managers.*"}]
      }

      assert %{definite: "managers"} =
               Classification.classify_planned(nil, App.Managers.Orders, arch([managers]))
    end

    test "only a uses_module selector could match: no bucket, framework possible, unknown named" do
      assert Classification.classify_planned(
               "lib/app/server.ex",
               App.Server,
               arch([@domain, @framework])
             ) == %{
               definite: nil,
               ambiguous: [],
               possible: ["framework"],
               unknown: [:uses_module]
             }
    end

    test "two path selectors matching is ambiguous, never a precedence" do
      other = %{
        "name" => "other",
        "role" => "domain",
        "select" => [%{"paths" => ["lib/app/**/*.ex"]}]
      }

      assert %{definite: nil, ambiguous: ["domain", "other"]} =
               Classification.classify_planned(
                 "lib/app/domain/thing.ex",
                 App.Domain.Thing,
                 arch([@domain, other])
               )
    end

    test "no module implied (a path with no lib/ segment): a pattern selector never matches" do
      # nil read as a name is "nil", which this pattern would match.
      literal_nil = %{"name" => "any", "role" => "domain", "select" => [%{"pattern" => "nil"}]}

      assert %{definite: nil} =
               Classification.classify_planned("scripts/run.ex", nil, arch([literal_nil]))
    end

    test "a path no selector matches, with no beam selector, is unclassified" do
      assert Classification.classify_planned("lib/app/x.ex", App.X, arch([@domain])) ==
               %{definite: nil, ambiguous: [], possible: [], unknown: []}
    end
  end
end
