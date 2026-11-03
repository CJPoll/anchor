defmodule Anchor.Domain.GraphRules.LayeringTest do
  # DND-5442: the layering graph rule. Pure Domain: first over hand-built
  # models, then over a graph built from fixtures compiled in the test (a
  # `use` macro injecting a forbidden call, which the AST rule cannot see).
  #
  # Sabotage record: ../../../sabotage_records/layering-20261103-dnd_5441_graph_rules_a.md
  use ExUnit.Case, async: true

  import Anchor.Test.BeamFixtures

  alias Anchor.Adapters.BeamReader
  alias Anchor.Config
  alias Anchor.Domain.Architecture
  alias Anchor.Domain.Classification
  alias Anchor.Domain.Graph
  alias Anchor.Domain.Graph.Builder
  alias Anchor.Domain.Graph.Call
  alias Anchor.Domain.Graph.ModuleNode
  alias Anchor.Domain.Graph.SourceFacts
  alias Anchor.Domain.GraphRules.Layering
  alias Anchor.Domain.Model

  @calls %{
    "framework" => ["framework", "managers", "domain"],
    "managers" => ["managers", "adapters", "domain"],
    "adapters" => ["adapters", "domain", "managers:other_context"],
    "domain" => ["domain"]
  }

  defp arch(calls \\ @calls) do
    {:ok, arch} =
      Architecture.parse(%{
        "contexts" => %{"depth" => 2},
        "buckets" =>
          Enum.map(~w(framework managers adapters domain), fn name ->
            %{"name" => name, "role" => name, "select" => [%{"paths" => ["lib/**/#{name}/**"]}]}
          end),
        "calls" => calls
      })

    arch
  end

  # module => {bucket, context}
  @modules %{
    App.Web.Page => {"framework", "App.Web"},
    App.Web.Other => {"framework", "App.Web"},
    App.Orders.Manager => {"managers", "App.Orders"},
    App.Orders.Store => {"adapters", "App.Orders"},
    App.Billing.Store => {"adapters", "App.Billing"},
    App.Billing.Manager => {"managers", "App.Billing"},
    App.Orders.Order => {"domain", "App.Orders"}
  }

  defp model(calls, nodes \\ [], matrix \\ @calls) do
    classification =
      Map.new(@modules, fn {module, {bucket, context}} ->
        {module,
         %Classification{
           module: module,
           bucket: bucket,
           role: String.to_atom(bucket),
           context: context,
           source_file: "lib/#{bucket}/#{module |> Module.split() |> List.last()}.ex"
         }}
      end)

    graph = %Graph{
      modules: Map.new(nodes, &{&1.module, &1}),
      calls:
        Enum.map(calls, fn {from, to, line} ->
          %Call{from: from, to: to, kind: :remote, line: line, line_source: :call}
        end)
    }

    %Model{graph: graph, architecture: arch(matrix), classification: classification, config: nil}
  end

  @rule %{type: :layering, id: "layering", paths: ["lib/**"]}

  describe "check/2 static calls" do
    test "framework -> adapters is one violation naming both buckets, with the route Fix" do
      [v] =
        Layering.check(
          model([{{App.Web.Page, :show, 1}, {App.Orders.Store, :fetch, 0}, 7}]),
          @rule
        )

      assert v.filename == "lib/framework/Page.ex"
      assert v.line == 7
      assert v.key == "layering|App.Web.Page.show/1|-> App.Orders.Store.fetch/0"
      assert v.rule_id == "layering"

      assert v.message ==
               "App.Web.Page.show/1 (framework, App.Web) calls App.Orders.Store.fetch/0 " <>
                 "(adapters, App.Orders); framework may call: framework, managers, domain. Fix: " <>
                 "route it through managers: framework -> managers -> adapters (call a managers " <>
                 "module of the right context, which calls adapters); framework may not call " <>
                 "adapters directly."
    end

    test "positive control: framework -> managers is none" do
      assert Layering.check(
               model([{{App.Web.Page, :show, 1}, {App.Orders.Manager, :get, 1}, 7}]),
               @rule
             ) == []
    end

    test "no route: domain -> managers says the matrix forbids it" do
      [v] =
        Layering.check(
          model([{{App.Orders.Order, :new, 1}, {App.Orders.Manager, :get, 1}, 3}]),
          @rule
        )

      assert v.message =~
               "Fix: no route: the calls matrix forbids domain reaching managers; move the " <>
                 "logic to a bucket domain may call."
    end

    test "a scope the call breaks: the Fix names the row's scope" do
      [v] =
        Layering.check(
          model([{{App.Orders.Store, :f, 0}, {App.Orders.Manager, :get, 1}, 3}]),
          @rule
        )

      assert v.message =~ "adapters reaches managers only within the scope that row names"

      # Positive control: other_context is allowed.
      assert Layering.check(
               model([{{App.Orders.Store, :f, 0}, {App.Billing.Manager, :get, 1}, 3}]),
               @rule
             ) == []
    end

    test "one function calling the forbidden target three times is one violation, first line" do
      calls =
        for line <- [9, 4, 6], do: {{App.Web.Page, :show, 1}, {App.Orders.Store, :f, 0}, line}

      assert [%{line: 4}] = Layering.check(model(calls), @rule)
    end

    test "a call within one module, and a call to Enum, are none" do
      calls = [
        {{App.Orders.Store, :f, 0}, {App.Orders.Store, :g, 0}, 1},
        {{App.Web.Page, :show, 1}, {Enum, :map, 2}, 2}
      ]

      assert Layering.check(model(calls), @rule) == []
    end

    test "a call within one module is allowed even when the bucket's row omits it" do
      no_self = Map.put(@calls, "adapters", ["domain"])
      within = [{{App.Orders.Store, :f, 0}, {App.Orders.Store, :g, 0}, 1}]
      assert Layering.check(model(within, [], no_self), @rule) == []

      # Positive control: another module of the same bucket is judged by the row.
      across = [{{App.Orders.Store, :f, 0}, {App.Billing.Store, :g, 0}, 1}]
      assert [_one] = Layering.check(model(across, [], no_self), @rule)
    end

    test "a caller outside the rule's selector is not judged" do
      call = [{{App.Web.Page, :show, 1}, {App.Orders.Store, :f, 0}, 7}]

      assert Layering.check(model(call), %{@rule | paths: ["lib/domain/**"]}) == []
      assert [_one] = Layering.check(model(call), @rule)
    end
  end

  describe "check/2 dynamic calls" do
    @port %ModuleNode{module: App.Port, app: :app, callbacks: [{:fetch, 1}]}
    @manager_impl %ModuleNode{module: App.Orders.Manager, app: :app, behaviours: [App.Port]}
    @adapter_impl %ModuleNode{module: App.Orders.Store, app: :app, behaviours: [App.Port]}

    test "one forbidden implementation is one violation naming it" do
      call = [{{App.Web.Page, :show, 1}, {:dynamic, :fetch, 1, :variable}, 5}]

      assert [v] = Layering.check(model(call, [@port, @manager_impl, @adapter_impl]), @rule)
      assert v.key == "layering|App.Web.Page.show/1|-> App.Orders.Store.fetch/1"
      assert v.message =~ "calls App.Orders.Store.fetch/1 (adapters, App.Orders)"
    end

    # Regression (critic, e92f4eb): a dynamic call of unknown arity
    # (`apply(mod, :fetch, args)`) that resolved to a forbidden candidate
    # printed `fetch/` in its key and message, unlike the unresolved form's `/?`.
    test "an unknown arity resolved to a forbidden implementation prints /?" do
      call = [{{App.Web.Page, :show, 1}, {:dynamic, :fetch, nil, :call}, 5}]

      assert [v] = Layering.check(model(call, [@port, @adapter_impl]), @rule)
      assert v.key == "layering|App.Web.Page.show/1|-> App.Orders.Store.fetch/?"
      assert v.message =~ "calls App.Orders.Store.fetch/? (adapters, App.Orders)"
    end

    test "only allowed implementations: none" do
      call = [{{App.Web.Page, :show, 1}, {:dynamic, :fetch, 1, :variable}, 5}]
      assert Layering.check(model(call, [@port, @manager_impl]), @rule) == []
    end

    test "no behaviour declaring the callback: one unresolved violation" do
      call = [{{App.Web.Page, :show, 1}, {:dynamic, :store, 2, :call}, 5}]

      assert [v] = Layering.check(model(call, [@port, @manager_impl]), @rule)
      assert v.key == "layering|App.Web.Page.show/1|-> dynamic store/2"

      assert v.message =~
               "no behaviour in the project declares that callback, so its target cannot be " <>
                 "checked. Fix: declare @callback store/2 in a behaviour"
    end

    test "a closure application names no function and is not judged" do
      call = [{{App.Web.Page, :show, 1}, {:dynamic, nil, 1, :variable}, 5}]
      assert Layering.check(model(call), @rule) == []
    end
  end

  describe "shape/1" do
    test "the rule's conforming shape" do
      assert Layering.shape(@rule) =~ "the architecture: calls matrix allows"
    end
  end

  describe "check/2 over compiled code: a call injected by `use`" do
    @mac_file "lib/app/framework/mac.ex"
    @mac """
    defmodule AnchorFixtures.LayeringTest.Mac do
      defmacro __using__(_opts) do
        quote do
          def save(x), do: AnchorFixtures.LayeringTest.Repo.insert(x)
        end
      end
    end
    """
    @web_file "lib/app/framework/web.ex"
    @web """
    defmodule AnchorFixtures.LayeringTest.Web do
      use AnchorFixtures.LayeringTest.Mac
      def page(x), do: x
    end
    """
    @repo_file "lib/app/adapters/repo.ex"
    @repo """
    defmodule AnchorFixtures.LayeringTest.Repo do
      def insert(x), do: x
    end
    """

    setup do
      sources = [{@mac, @mac_file}, {@web, @web_file}, {@repo, @repo_file}]

      beams =
        sources
        |> compile_all_unloaded()
        |> Enum.map(fn {module, binary} ->
          BeamReader.decode(binary, app: :app, path: "ebin/#{module}.beam")
        end)

      facts = Map.new(sources, fn {text, file} -> {file, SourceFacts.from_source(file, text)} end)
      graph = Builder.build(beams, facts)
      {:ok, arch} = compiled_arch()
      {model, []} = Model.build(graph, %Config{architecture: arch, path: ".anchor.yml"}, facts)
      %{model: model}
    end

    defp compiled_arch do
      Architecture.parse(%{
        "contexts" => %{"depth" => 2},
        "buckets" => [
          %{
            "name" => "framework",
            "role" => "framework",
            "select" => [%{"paths" => ["lib/app/framework/**"]}]
          },
          %{
            "name" => "adapters",
            "role" => "adapters",
            "select" => [%{"paths" => ["lib/app/adapters/**"]}]
          }
        ],
        "calls" => %{"framework" => ["framework"], "adapters" => ["adapters"]}
      })
    end

    test "the graph rule reports the injected call, with a line", %{model: model} do
      assert [v] = Layering.check(model, %{type: :layering, id: "l", paths: ["lib/**"]})
      assert v.filename == @web_file
      assert is_integer(v.line) and v.line > 0

      assert v.key ==
               "l|AnchorFixtures.LayeringTest.Web.save/1|-> AnchorFixtures.LayeringTest.Repo.insert/1"
    end

    test "the AST rule no_direct_dependency on the same source does not see it" do
      rule = %{
        type: :no_direct_dependency,
        paths: ["lib/**"],
        forbidden_modules: [AnchorFixtures.LayeringTest.Repo]
      }

      assert Anchor.Check.NoDependency.check_file(
               Credo.SourceFile.parse(@web, @web_file),
               [rule],
               []
             ) ==
               []

      # Positive control: the AST rule sees the call when it is written out.
      written =
        String.replace(
          @web,
          "def page(x), do: x",
          "def page(x), do: AnchorFixtures.LayeringTest.Repo.insert(x)"
        )

      assert [_issue] =
               Anchor.Check.NoDependency.check_file(
                 Credo.SourceFile.parse(written, @web_file),
                 [rule],
                 []
               )
    end
  end
end
