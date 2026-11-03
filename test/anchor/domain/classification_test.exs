defmodule Anchor.Domain.ClassificationTest do
  # DND-5437: a module classifies into exactly one bucket, with no precedence
  # between buckets, ever. Pure Domain: facts are plain maps, the architecture
  # is parsed from a decoded section.
  #
  # Sabotage record: ../../sabotage_records/classification-20261103-dnd_5437.md
  use ExUnit.Case, async: true

  alias Anchor.Domain.Architecture
  alias Anchor.Domain.Classification

  @domain %{
    "name" => "domain",
    "role" => "domain",
    "select" => [%{"paths" => ["lib/**/domain/**/*.ex"]}]
  }
  @managers %{
    "name" => "managers",
    "role" => "managers",
    "select" => [%{"paths" => ["lib/**/managers/**/*.ex"]}]
  }
  @framework %{
    "name" => "framework",
    "role" => "framework",
    "select" => [%{"uses_module" => "GenServer"}, %{"pattern" => "Mix.Tasks.*"}]
  }

  defp architecture(buckets, extra \\ %{}) do
    names = Enum.map(buckets, & &1["name"])

    {:ok, architecture} =
      %{
        "contexts" => %{"depth" => 2},
        "buckets" => buckets,
        "calls" => Map.new(names, &{&1, []})
      }
      |> Map.merge(extra)
      |> Architecture.parse()

    architecture
  end

  defp facts(module, source_file, overrides \\ %{}) do
    Map.merge(
      %{
        module: module,
        app: :my_app,
        source_file: source_file,
        uses: [],
        behaviours: [],
        exports: []
      },
      overrides
    )
  end

  describe "classify/2" do
    test "a module one bucket selects is in that bucket" do
      arch = architecture([@domain, @managers])
      facts = facts(MyApp.Accounts.User, "lib/my_app/domain/accounts/user.ex")

      assert {:ok, %Classification{bucket: "domain", role: :domain, module: MyApp.Accounts.User}} =
               Classification.classify(facts, arch)
    end

    test "a module no bucket selects is unclassified" do
      arch = architecture([@domain, @managers])
      facts = facts(MyApp.Web.Page, "lib/my_app/web/page.ex")

      assert Classification.classify(facts, arch) == {:error, {:unclassified, MyApp.Web.Page}}
    end

    test "a module two buckets select is ambiguous, names sorted, whatever the config order" do
      facts = facts(MyApp.Domain.Worker, "lib/my_app/domain/worker.ex", %{uses: [GenServer]})
      expected = {:error, {:ambiguous, MyApp.Domain.Worker, ["domain", "framework"]}}

      assert Classification.classify(facts, architecture([@domain, @framework])) == expected
      assert Classification.classify(facts, architecture([@framework, @domain])) == expected
    end

    test "each selector kind classifies on its own" do
      by_kind = [
        {%{"paths" => ["lib/x/**/*.ex"]}, %{source_file: "lib/x/a/b.ex"}},
        {%{"pattern" => "MyApp.Thing"}, %{}},
        {%{"uses_module" => "GenServer"}, %{uses: [GenServer]}},
        {%{"behaviour" => "Supervisor"}, %{behaviours: [Supervisor]}},
        {%{"exports_function" => "__aggregate__/0"}, %{exports: [{:__aggregate__, 0}]}}
      ]

      for {selector, overrides} <- by_kind do
        bucket = %{"name" => "only", "role" => "domain", "select" => [selector]}
        arch = architecture([bucket])

        assert {:ok, %Classification{bucket: "only"}} =
                 Classification.classify(facts(MyApp.Thing, "lib/y.ex", overrides), arch),
               "#{inspect(selector)} did not select"

        assert {:error, {:unclassified, MyApp.Other}} =
                 Classification.classify(facts(MyApp.Other, "lib/y.ex"), arch),
               "#{inspect(selector)} selected a module it does not describe"
      end
    end

    test "a module of an interface bucket is an interface module" do
      arch = architecture([@domain, @managers], %{"interfaces" => %{"buckets" => ["managers"]}})

      assert {:ok, %Classification{interface?: true}} =
               Classification.classify(facts(MyApp.Accounts, "lib/a/managers/accounts.ex"), arch)

      assert {:ok, %Classification{interface?: false}} =
               Classification.classify(facts(MyApp.Accounts.User, "lib/a/domain/user.ex"), arch)
    end

    test "a module listed in interfaces.exports is an interface module" do
      arch =
        architecture([@domain], %{"interfaces" => %{"exports" => ["MyApp.Accounts.Api"]}})

      assert {:ok, %Classification{bucket: "domain", interface?: true}} =
               Classification.classify(facts(MyApp.Accounts.Api, "lib/a/domain/api.ex"), arch)

      assert {:ok, %Classification{interface?: false}} =
               Classification.classify(facts(MyApp.Accounts.User, "lib/a/domain/user.ex"), arch)
    end

    test "the struct carries the module's app, source file and context" do
      arch = architecture([@domain])
      facts = facts(MyApp.Accounts.User, "lib/a/domain/user.ex", %{app: :accounts})

      assert {:ok,
              %Classification{
                app: :accounts,
                source_file: "lib/a/domain/user.ex",
                context: "MyApp.Accounts"
              }} = Classification.classify(facts, arch)
    end
  end

  describe "context_of/2" do
    test "is the first depth segments" do
      assert Classification.context_of(MyApp.Accounts.Users, 2) == "MyApp.Accounts"
      assert Classification.context_of(MyApp.Accounts.Users, 1) == "MyApp"
      assert Classification.context_of(MyApp.Accounts.Users, 3) == "MyApp.Accounts.Users"
    end

    test "a module with fewer segments has no context" do
      assert Classification.context_of(MyApp, 2) == nil
    end

    test "an Erlang module has no context" do
      assert Classification.context_of(:ets, 1) == nil
    end
  end

  describe "bucket_counts/2" do
    test "counts each bucket's modules, in config order" do
      arch = architecture([@domain, @managers])

      facts =
        for(n <- 1..3, do: facts(Module.concat(MyApp, "D#{n}"), "lib/a/domain/d#{n}.ex")) ++
          [facts(MyApp.M, "lib/a/managers/m.ex")]

      assert arch |> then(&Classification.bucket_counts(facts, &1)) |> names_and_counts() ==
               [{"domain", 3}, {"managers", 1}]
    end

    test "a bucket matching nothing is kept, with 0" do
      arch = architecture([@domain, @managers])

      assert names_and_counts(
               Classification.bucket_counts([facts(MyApp.D, "lib/a/domain/d.ex")], arch)
             ) == [{"domain", 1}, {"managers", 0}]
    end

    test "a module two buckets select counts in both" do
      arch = architecture([@domain, @framework])
      facts = [facts(MyApp.Domain.W, "lib/a/domain/w.ex", %{uses: [GenServer]})]

      assert names_and_counts(Classification.bucket_counts(facts, arch)) ==
               [{"domain", 1}, {"framework", 1}]
    end
  end

  defp names_and_counts(counts), do: Enum.map(counts, fn {bucket, n} -> {bucket.name, n} end)
end
