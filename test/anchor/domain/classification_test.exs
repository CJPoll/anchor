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

  # DND-5440: the runner classifies every module at once and reports each
  # module no bucket, or two buckets, select, and each bucket below its floor.
  # Sabotage record: ../../sabotage_records/graph_runner-20261103-dnd_5440_graph_runner.md
  describe "classify_all/3" do
    test "classified modules are keyed by module; no issues when every module classifies" do
      arch = architecture([@domain, @managers])
      user = facts(MyApp.Accounts.User, "lib/my_app/domain/accounts/user.ex")
      manager = facts(MyApp.Accounts.Manager, "lib/my_app/managers/accounts.ex")

      assert {%{
                MyApp.Accounts.User => %Classification{bucket: "domain"},
                MyApp.Accounts.Manager => %Classification{bucket: "managers"}
              } = map, []} =
               Classification.classify_all([user, manager], arch, ".anchor.yml")

      assert map_size(map) == 2
    end

    test "an unclassified module is one issue on its file and defmodule line, with Fix: and explain" do
      arch = architecture([@domain, @managers])
      user = facts(MyApp.Accounts.User, "lib/my_app/domain/accounts/user.ex")
      manager = facts(MyApp.Accounts.Manager, "lib/my_app/managers/accounts.ex")
      stray = facts(MyApp.Stray, "lib/my_app/stray.ex", %{line: 1})

      assert {map, [issue]} =
               Classification.classify_all([user, manager, stray], arch, ".anchor.yml")

      refute Map.has_key?(map, MyApp.Stray)
      assert issue.filename == "lib/my_app/stray.ex"
      assert issue.line == 1
      assert issue.kind == :fail_closed
      assert issue.message =~ "MyApp.Stray is in no architecture bucket."
      assert issue.message =~ "Fix: add a selector that matches lib/my_app/stray.ex"
      assert issue.message =~ "mix anchor.explain lib/my_app/stray.ex"
    end

    test "an ambiguous module is one issue naming both buckets and both selectors, and is in neither" do
      arch = architecture([@domain, @framework, @managers])

      both =
        facts(MyApp.Accounts.Worker, "lib/my_app/domain/accounts/worker.ex", %{
          uses: [GenServer],
          line: 3
        })

      manager = facts(MyApp.Accounts.Manager, "lib/my_app/managers/accounts.ex")

      assert {map, [issue]} = Classification.classify_all([both, manager], arch, ".anchor.yml")
      refute Map.has_key?(map, MyApp.Accounts.Worker)
      assert issue.filename == "lib/my_app/domain/accounts/worker.ex"
      assert issue.line == 3

      assert issue.message =~
               ~s|MyApp.Accounts.Worker is in buckets domain (by paths ["lib/**/domain/**/*.ex"]) and framework (by uses_module GenServer).|

      assert issue.message =~ "Fix: narrow one selector; buckets never take precedence."
    end

    test "a bucket below min_modules is one issue on the config; at the floor, none" do
      domain = Map.put(@domain, "min_modules", 2)
      arch = architecture([domain, @managers])
      user = facts(MyApp.Accounts.User, "lib/my_app/domain/accounts/user.ex")
      order = facts(MyApp.Accounts.Order, "lib/my_app/domain/accounts/order.ex")
      manager = facts(MyApp.Accounts.Manager, "lib/my_app/managers/accounts.ex")

      assert {_map, [issue]} =
               Classification.classify_all([user, manager], arch, "conf/.anchor.yml")

      assert issue.filename == "conf/.anchor.yml"

      assert issue.message ==
               "architecture bucket domain selects 1 modules, below min_modules 2. Fix: correct " <>
                 "the selector; lowering min_modules is the owner's call."

      assert {_map, []} =
               Classification.classify_all([user, order, manager], arch, "conf/.anchor.yml")
    end
  end
end
