defmodule Anchor.Domain.ExplainTest do
  # DND-5446: what mix anchor.explain answers, from the config and the model
  # only. Pure Domain, over hand-built models.
  #
  # Sabotage record: ../../sabotage_records/explain-20261103-dnd_5443_graph_rules_b.md
  # Sabotage record (after the merge): ../../sabotage_records/explain-20261106-dnd_5443_graph_rules_b.md
  use ExUnit.Case, async: true

  alias Anchor.Config
  alias Anchor.Domain.Aggregates.Declaration
  alias Anchor.Domain.Aggregates.Index
  alias Anchor.Domain.Classification
  alias Anchor.Domain.Explain
  alias Anchor.Domain.Graph
  alias Anchor.Domain.Graph.ModuleNode
  alias Anchor.Domain.Graph.SourceFacts
  alias Anchor.Domain.GraphReport.Finding
  alias Anchor.Domain.Model
  alias Anchor.Domain.RuleShapes

  @yaml %{
    "rules" => [
      %{"type" => "layering", "id" => "layering", "paths" => ["lib/**/*.ex"]},
      %{
        "type" => "single_control_flow",
        "paths" => ["lib/app/managers/**/*.ex"],
        "recursive" => true
      },
      %{"type" => "case_on_bare_arg", "paths" => ["lib/app/domain/**/*.ex"], "recursive" => true}
    ],
    "architecture" => %{
      "contexts" => %{"depth" => 2},
      "buckets" => [
        %{
          "name" => "managers",
          "role" => "managers",
          "select" => [%{"paths" => ["lib/**/managers/**/*.ex"]}]
        },
        %{
          "name" => "domain",
          "role" => "domain",
          "select" => [%{"paths" => ["lib/**/domain/**/*.ex"]}]
        },
        %{
          "name" => "framework",
          "role" => "framework",
          "select" => [%{"uses_module" => "GenServer"}]
        }
      ],
      "calls" => %{
        "managers" => ["managers", "domain"],
        "domain" => ["domain"],
        "framework" => ["framework", "managers"]
      },
      "interfaces" => %{"buckets" => ["managers"]}
    }
  }

  defp config, do: Config.parse_config(@yaml)

  # module => {bucket, context, interface?, file}
  @modules %{
    App.Orders.Manager => {"managers", "App.Orders", true, "lib/app/managers/orders.ex"},
    App.Orders.Helper => {"managers", "App.Orders", true, "lib/app/managers/helper.ex"},
    App.Orders.Order => {"domain", "App.Orders", false, "lib/app/domain/order.ex"},
    App.Billing.Manager => {"managers", "App.Billing", true, "lib/app/managers/billing.ex"},
    App.Billing.Invoice => {"domain", "App.Billing", false, "lib/app/domain/invoice.ex"}
  }

  defp model do
    classification =
      Map.new(@modules, fn {module, {bucket, context, interface?, file}} ->
        {module,
         %Classification{
           module: module,
           bucket: bucket,
           role: String.to_atom(bucket),
           context: context,
           interface?: interface?,
           app: :app,
           source_file: file
         }}
      end)

    nodes =
      @modules
      |> Map.new(fn {module, {_b, _c, _i, file}} ->
        {module, %ModuleNode{module: module, app: :app, source_file: file}}
      end)
      |> Map.put(App.Stray, %ModuleNode{
        module: App.Stray,
        app: :app,
        source_file: "lib/app/stray.ex"
      })

    %Model{
      graph: %Graph{modules: nodes},
      architecture: config().architecture,
      classification: classification,
      config: config(),
      facts: Map.new(nodes, fn {module, node} -> {module, Model.facts(node, %{})} end)
    }
  end

  # Explains App.Worker, a module whose source says `use GenServer`, over a model
  # built as a run builds it.
  defp explain_of_worker(config, file \\ "lib/app/domain/worker.ex") do
    source = "defmodule App.Worker do\n  use GenServer\nend\n"
    node = %ModuleNode{module: App.Worker, app: :app, source_file: file}

    {model, _issues} =
      Model.build(
        %Graph{modules: %{App.Worker => node}},
        config,
        %{file => SourceFacts.from_source(file, source)}
      )

    Explain.build(
      config,
      model,
      subject(%{module: App.Worker, path: file, argument: "App.Worker"})
    )
  end

  defp subject(overrides) do
    Map.merge(
      %{
        argument: "lib/app/managers/orders.ex",
        module: App.Orders.Manager,
        path: "lib/app/managers/orders.ex",
        exists?: true,
        source: nil,
        compiled?: true,
        findings: []
      },
      overrides
    )
  end

  describe "build/3 with the model" do
    test "a manager: classification, the modules it may call, what it must not, its rules" do
      explain = Explain.build(config(), model(), subject(%{}))

      assert explain.classification == %{
               "status" => "classified",
               "bucket" => "managers",
               "role" => "managers",
               "context" => "App.Orders",
               "app" => "app",
               "interface" => true,
               "aggregate" => "unknown (no aggregates declared)"
             }

      assert [managers, domain] = explain.may_call

      # Its own context's managers; another context's interface modules only.
      assert managers == %{
               "bucket" => "managers",
               "scope" => "any",
               "modules" => %{
                 "same_context" => ["App.Orders.Helper", "App.Orders.Manager"],
                 "other_contexts" => %{"App.Billing" => ["App.Billing.Manager"]}
               }
             }

      # Billing's domain module is not its interface, so it is not callable.
      assert domain["modules"] == %{
               "same_context" => ["App.Orders.Order"],
               "other_contexts" => %{}
             }

      assert explain.must_not_call == ["framework"]

      assert [
               %{"type" => "layering", "engine" => "graph", "id" => "layering"} = layering,
               %{"type" => "single_control_flow", "engine" => "ast"} = flow
             ] = explain.rules

      assert layering["shape"] == RuleShapes.for(%{type: :layering})
      assert flow["shape"] == RuleShapes.for(%{type: :single_control_flow})
      assert flow["enforcement"] == "enforce"
      assert explain.findings == []
      assert explain.unknown == []
    end

    # The aggregate comes from the model's aggregate index (DND-5476): a
    # declared schema's aggregate, an owner's aggregates, "none" when
    # aggregates are declared but not this module, and "unknown" only when
    # none are declared at all.
    test "the aggregate is read from the model's declarations" do
      index = %Index{
        aggregates: %{
          "orders" => %Declaration{
            name: "orders",
            schemas: [App.Orders.Order],
            owners: [App.Orders.Manager]
          }
        },
        by_schema: %{App.Orders.Order => "orders"},
        owners: %{App.Orders.Manager => ["orders"]}
      }

      model = %{model() | aggregates: index}
      aggregate = &Explain.build(config(), model, subject(&1)).classification["aggregate"]

      assert aggregate.(%{module: App.Orders.Order, path: "lib/app/domain/order.ex"}) == "orders"
      assert aggregate.(%{}) == "owner of orders"

      assert aggregate.(%{module: App.Billing.Invoice, path: "lib/app/domain/invoice.ex"}) ==
               "none (declared in no aggregate)"

      assert Explain.build(config(), model(), subject(%{})).classification["aggregate"] ==
               "unknown (no aggregates declared)"

      assert Explain.build(config(), nil, subject(%{findings: nil})).classification["aggregate"] ==
               "unknown until compiled"
    end

    test "the findings it was given are kept" do
      finding = %Finding{
        label: "layering",
        enforcement: :enforce,
        message: "x. Fix: y",
        file: "lib/app/managers/orders.ex"
      }

      assert %Explain{findings: [^finding]} =
               Explain.build(config(), model(), subject(%{findings: [finding]}))

      explain = Explain.build(config(), model(), subject(%{findings: [finding]}))

      assert Explain.render(explain, :text) =~
               "findings:\n  lib/app/managers/orders.ex:1: x. Fix: y"

      assert [%{"file" => "lib/app/managers/orders.ex", "message" => "x. Fix: y"}] =
               JSON.decode!(Explain.render(explain, :json))["findings"]
    end

    test "a module in the graph but in no bucket is unclassified, with every bucket's selectors and the Fix" do
      explain =
        Explain.build(
          config(),
          model(),
          subject(%{module: App.Stray, path: "lib/app/stray.ex", argument: "App.Stray"})
        )

      assert explain.classification["status"] == "unclassified"
      assert explain.classification["fix"] =~ "App.Stray is in no architecture bucket. Fix:"
      # It compiled: its beam facts are known, however the buckets judged it.
      assert explain.unknown == []
      assert explain.classification["app"] == "app"
      assert length(explain.classification["selectors"]) == 3
      assert explain.may_call == []
      assert explain.must_not_call == []
    end

    # Re-classifying with no source facts lost every `use`, so the answer could
    # differ from the verdict the model holds: a crash here, the wrong one below.
    test "a module in two buckets, one through its source's `use`, is ambiguous" do
      explain = explain_of_worker(config())

      assert explain.classification["status"] == "ambiguous"
      assert explain.unknown == []
      assert explain.classification["app"] == "app"

      assert explain.classification["fix"] =~
               "App.Worker is in buckets domain (by paths [\"lib/**/domain/**/*.ex\"]) and " <>
                 "framework (by uses_module GenServer). Fix:"

      assert %{"bucket" => "framework", "matched" => "uses_module GenServer"} =
               Enum.find(explain.classification["selectors"], &(&1["bucket"] == "framework"))
    end

    test "a module in two buckets, both through its source's `use`, is ambiguous" do
      second = %{
        "name" => "workers",
        "role" => "framework",
        "select" => [%{"uses_module" => "GenServer"}]
      }

      yaml =
        update_in(@yaml, ["architecture"], fn arch ->
          arch
          |> Map.update!("buckets", &(&1 ++ [second]))
          |> put_in(["calls", "workers"], ["workers"])
        end)

      explain = explain_of_worker(Config.parse_config(yaml), "lib/app/worker.ex")

      assert explain.classification["status"] == "ambiguous"

      assert explain.classification["fix"] =~
               "framework (by uses_module GenServer) and workers (by uses_module GenServer)"
    end
  end

  describe "build/3 with no model" do
    test "a path that does not exist yet under domain/: domain by path, beam facts unknown" do
      explain =
        Explain.build(
          config(),
          nil,
          subject(%{
            argument: "lib/app/domain/new_thing.ex",
            module: App.Domain.NewThing,
            path: "lib/app/domain/new_thing.ex",
            exists?: false,
            findings: nil
          })
        )

      assert explain.exists == false
      assert explain.classification["status"] == "classified by path"
      assert explain.classification["bucket"] == "domain"
      assert explain.classification["app"] == "unknown until compiled"
      assert explain.classification["possible"] == ["framework"]
      assert explain.classification["unknown_selectors"] == ["uses_module"]
      assert [%{"bucket" => "domain", "modules" => nil}] = explain.may_call
      assert explain.must_not_call == ["framework", "managers"]
      assert explain.findings == nil
      assert explain.unknown == ~w(app behaviours exports_function uses_module)
      assert Enum.map(explain.rules, & &1["type"]) == ["layering", "case_on_bare_arg"]
    end

    test "a path no selector reaches is unclassified, with the Fix" do
      explain =
        Explain.build(
          config(),
          nil,
          subject(%{module: App.Odd, path: "lib/app/odd.ex", findings: nil})
        )

      # framework is possible (a uses_module selector), so it is not unclassified.
      assert explain.classification["status"] == "possible"
    end

    test "a compile that failed is noted" do
      explain = Explain.build(config(), nil, subject(%{compiled?: false, findings: nil}))

      assert explain.notes == ["compile failed; beam facts unknown"]
    end
  end

  describe "render/2" do
    test "text: one golden case" do
      text = Explain.render(Explain.build(config(), model(), subject(%{})), :text)

      assert text ==
               """
               anchor.explain: lib/app/managers/orders.ex
                 module: App.Orders.Manager
                 path: lib/app/managers/orders.ex (exists)
               classification:
                 status: classified
                 bucket: managers (role managers)
                 context: App.Orders
                 app: app
                 interface: yes
                 aggregate: unknown (no aggregates declared)
               may call:
                 managers (any): same context: App.Orders.Helper, App.Orders.Manager; other contexts (interface only): App.Billing: App.Billing.Manager
                 domain (any): same context: App.Orders.Order; other contexts (interface only): none
               must not call: framework
               rules:
                 [enforce] layering (id: layering, graph): #{RuleShapes.for(%{type: :layering})}
                 [enforce] single_control_flow (ast): #{RuleShapes.for(%{type: :single_control_flow})}
               findings: none\
               """
    end

    test "text with no model says the findings are not computed" do
      text = Explain.render(Explain.build(config(), nil, subject(%{findings: nil})), :text)

      assert text =~ "findings: not computed (run mix anchor.graph)"
      assert text =~ "(modules not computed: run mix anchor.graph)"
    end

    test "json decodes and has the R5 keys" do
      json = config() |> Explain.build(model(), subject(%{})) |> Explain.render(:json)
      decoded = JSON.decode!(json)

      for key <- ~w(subject exists classification may_call must_not_call rules findings unknown),
          do: assert(Map.has_key?(decoded, key), key)

      assert decoded["subject"] == "lib/app/managers/orders.ex"
      assert decoded["findings"] == []

      assert JSON.decode!(
               Explain.render(Explain.build(config(), nil, subject(%{findings: nil})), :json)
             )[
               "findings"
             ] == nil
    end
  end
end
