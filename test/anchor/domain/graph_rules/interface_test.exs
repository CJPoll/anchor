defmodule Anchor.Domain.GraphRules.InterfaceTest do
  # DND-5443: the interface graph rule. Pure Domain: first over hand-built
  # models, then over a graph built from fixtures compiled in the test, in two
  # contexts of two apps.
  #
  # Sabotage record: ../../../sabotage_records/interface-20261103-dnd_5443_graph_rules_b.md
  use ExUnit.Case, async: true

  import Anchor.Test.BeamFixtures

  alias Anchor.Adapters.BeamReader
  alias Anchor.Config
  alias Anchor.Domain.Architecture
  alias Anchor.Domain.Classification
  alias Anchor.Domain.Graph
  alias Anchor.Domain.Graph.Builder
  alias Anchor.Domain.Graph.Call
  alias Anchor.Domain.Graph.FunctionNode
  alias Anchor.Domain.Graph.ModuleNode
  alias Anchor.Domain.Graph.SourceFacts
  alias Anchor.Domain.GraphRules.Interface
  alias Anchor.Domain.Model

  # module => {bucket, context, interface?}
  @modules %{
    App.Billing.Invoice => {"managers", "App.Billing", true},
    App.Billing.Total => {"domain", "App.Billing", false},
    App.Accounts.Users => {"managers", "App.Accounts", true},
    App.Accounts.User => {"domain", "App.Accounts", false},
    App.Accounts.Api => {"domain", "App.Accounts", true},
    App.Hidden.Secret => {"domain", "App.Hidden", false},
    Top => {"framework", nil, false},
    Other => {"framework", nil, false}
  }

  @rule %{type: :interface, id: "interface", paths: ["lib/**"]}

  defp model(calls, functions \\ %{}) do
    classification =
      Map.new(@modules, fn {module, {bucket, context, interface?}} ->
        {module,
         %Classification{
           module: module,
           bucket: bucket,
           role: String.to_atom(bucket),
           context: context,
           interface?: interface?,
           source_file: "lib/#{Macro.underscore(module)}.ex"
         }}
      end)

    nodes =
      Map.new(@modules, fn {module, _class} ->
        {module,
         %ModuleNode{
           module: module,
           app: :app,
           functions:
             functions
             |> Map.get(module, [])
             |> Map.new(fn {name, arity} ->
               {{name, arity},
                %FunctionNode{module: module, name: name, arity: arity, kind: :def, line: 1}}
             end)
         }}
      end)

    %Model{
      graph: %Graph{modules: nodes, calls: calls},
      architecture: %Architecture{context_depth: 2, buckets: [], calls: %{}},
      classification: classification,
      config: %Config{path: "/repo/.anchor.yml"}
    }
  end

  defp call(from, to, line \\ 7),
    do: %Call{from: from, to: to, kind: :remote, line: line, line_source: :call}

  describe "check/2" do
    test "a cross-context call to a domain module is one violation, its Fix the route" do
      calls = [
        call({App.Billing.Invoice, :issue, 1}, {App.Accounts.User, :name, 1}),
        call({App.Accounts.Users, :get, 1}, {App.Accounts.User, :name, 1})
      ]

      assert [v] = Interface.check(model(calls), @rule)
      assert v.key == "interface|App.Billing.Invoice.issue/1|-> App.Accounts.User.name/1"
      assert v.filename == "lib/app/billing/invoice.ex"
      assert v.line == 7
      assert v.rule_id == "interface"
      assert v.trigger == "App.Billing.Invoice.issue/1"

      assert v.message ==
               "App.Billing.Invoice.issue/1 (context App.Billing) calls " <>
                 "App.Accounts.User.name/1, which is not part of context App.Accounts's " <>
                 "interface. Fix: call App.Accounts.Users instead."
    end

    test "with no single route, the Fix lists the context's interface modules" do
      calls = [call({App.Billing.Invoice, :issue, 1}, {App.Accounts.User, :name, 1})]

      assert [v] = Interface.check(model(calls), @rule)

      assert v.message =~
               "Fix: call one of App.Accounts's interface modules: App.Accounts.Api, " <>
                 "App.Accounts.Users; or, if App.Accounts.User is meant to be public, add it " <>
                 "to interfaces.exports (a reviewed change)."
    end

    test "the listed interface modules stop at five, then say how many more" do
      calls = [call({App.Billing.Invoice, :issue, 1}, {App.Accounts.User, :name, 1})]
      base = model(calls)

      extra =
        Map.new(1..5, fn n ->
          module = Module.concat([App.Accounts, "M#{n}"])

          {module,
           %Classification{
             module: module,
             bucket: "managers",
             role: :managers,
             context: "App.Accounts",
             interface?: true
           }}
        end)

      wide = %{base | classification: Map.merge(base.classification, extra)}

      assert [v] = Interface.check(wide, @rule)

      assert v.message =~
               "interface modules: App.Accounts.Api, App.Accounts.M1, App.Accounts.M2, " <>
                 "App.Accounts.M3, App.Accounts.M4 and 2 more; or,"
    end

    test "positive control: a cross-context call to a manager is none" do
      calls = [call({App.Billing.Invoice, :issue, 1}, {App.Accounts.Users, :get, 1})]

      assert Interface.check(model(calls), @rule) == []
    end

    test "a cross-context call to a module listed in exports (interface? true) is none" do
      calls = [call({App.Billing.Invoice, :issue, 1}, {App.Accounts.Api, :token, 0})]

      assert Interface.check(model(calls), @rule) == []
    end

    test "a same-context call to a domain module is never judged" do
      calls = [call({App.Billing.Invoice, :issue, 1}, {App.Billing.Total, :sum, 1})]

      assert Interface.check(model(calls), @rule) == []
    end

    test "two calls of one pair are one violation, at the first line" do
      calls = [
        call({App.Billing.Invoice, :issue, 1}, {App.Accounts.User, :name, 1}, 9),
        call({App.Billing.Invoice, :issue, 1}, {App.Accounts.User, :name, 1}, 4)
      ]

      assert [%{line: 4}] = Interface.check(model(calls), @rule)
    end

    test "a caller with no context is one violation naming it, however many calls it makes" do
      calls = [
        call({Top, :run, 0}, {App.Accounts.Users, :get, 1}, 3),
        call({Top, :run, 0}, {App.Billing.Invoice, :issue, 1}, 4),
        call({Top, :other, 0}, {App.Accounts.User, :name, 1}, 5)
      ]

      assert [v] = Interface.check(model(calls), @rule)
      assert v.key == "interface|Top|no context"
      assert v.trigger == "Top"
      assert v.line == 3

      assert v.message ==
               "Top has no context (fewer than 2 name segments), so its boundary cannot be " <>
                 "checked. Fix: rename it under a context of depth 2, or lower contexts.depth."
    end

    test "a callee with no context is a violation on the callee" do
      calls = [call({App.Billing.Invoice, :issue, 1}, {Top, :run, 0})]

      assert [v] = Interface.check(model(calls), @rule)
      assert v.key == "interface|Top|no context"
      assert v.filename == "lib/top.ex"
      assert v.line == nil
    end

    test "two modules with no context calling each other are one violation each" do
      calls = [call({Top, :run, 0}, {Other, :run, 0})]

      assert ["interface|Other|no context", "interface|Top|no context"] =
               model(calls) |> Interface.check(@rule) |> Enum.map(& &1.key)
    end

    test "a callee whose context has no interface module: the Fix: says to give it one" do
      calls = [call({App.Billing.Invoice, :issue, 1}, {App.Hidden.Secret, :read, 0})]

      assert [v] = Interface.check(model(calls), @rule)

      assert v.message =~
               "Fix: context App.Hidden has no interface module; give it one (a module of an " <>
                 "interfaces.buckets bucket) and call that, or, if App.Hidden.Secret is meant " <>
                 "to be public, add it to interfaces.exports (a reviewed change)."
    end

    test "a dynamic call reaching an interface and a non-interface candidate is one violation" do
      functions = %{App.Accounts.Users => [{:fetch, 1}], App.Accounts.User => [{:fetch, 1}]}
      calls = [call({App.Billing.Invoice, :issue, 1}, {:dynamic, :fetch, 1, :variable})]

      assert [v] = Interface.check(model(calls, functions), @rule)
      assert v.key == "interface|App.Billing.Invoice.issue/1|-> App.Accounts.User.fetch/1"
    end

    test "a call with a computed function name is one violation; a closure is not judged" do
      calls = [
        call({App.Billing.Invoice, :issue, 1}, {:dynamic, nil, 2, :call}),
        %Call{
          from: {App.Billing.Invoice, :issue, 1},
          to: {:dynamic, nil, 1, :variable},
          kind: :apply,
          line: 8,
          line_source: :call
        }
      ]

      assert [v] = Interface.check(model(calls), @rule)
      assert v.key == "interface|App.Billing.Invoice.issue/1|-> dynamic ?/2"
      assert v.message =~ "calls a function it computes (?/2)"
    end

    test "a call from a module the rule does not select is not judged" do
      calls = [call({App.Billing.Invoice, :issue, 1}, {App.Accounts.User, :name, 1})]
      rule = %{@rule | paths: ["lib/app/accounts/**"]}

      assert Interface.check(model(calls), rule) == []
    end

    test "a call to a module outside the project or unclassified is not judged" do
      calls = [
        call({App.Billing.Invoice, :issue, 1}, {Enum, :map, 2}),
        call({App.Billing.Invoice, :issue, 1}, {App.Accounts.Stray, :x, 0})
      ]

      assert Interface.check(model(calls), @rule) == []
    end

    test "max_width: 3 with an interface of 4 public functions is one violation on the config" do
      functions = %{App.Billing.Invoice => [{:a, 0}, {:b, 0}, {:c, 0}, {:d, 0}]}
      rule = Map.put(@rule, :max_width, 3)

      assert [v] = Interface.check(model([], functions), rule)
      assert v.key == "interface|App.Billing|width"
      assert v.filename == "/repo/.anchor.yml"

      assert v.message ==
               "context App.Billing exposes 4 public functions on its interface, above " <>
                 "max_width 3. Fix: move functions behind fewer interface functions; raising " <>
                 "max_width is the owner's call."
    end

    test "max_width: 3 with an interface of exactly 3 is none (the boundary)" do
      functions = %{App.Billing.Invoice => [{:a, 0}, {:b, 0}, {:c, 0}]}

      assert Interface.check(model([], functions), Map.put(@rule, :max_width, 3)) == []
    end

    test "without max_width, a wide interface is not a violation" do
      functions = %{App.Billing.Invoice => [{:a, 0}, {:b, 0}, {:c, 0}, {:d, 0}]}

      assert Interface.check(model([], functions), @rule) == []
    end

    test "max_width judges only contexts of modules the rule selects" do
      functions = %{App.Billing.Invoice => [{:a, 0}, {:b, 0}, {:c, 0}, {:d, 0}]}
      rule = @rule |> Map.put(:max_width, 3) |> Map.put(:paths, ["lib/app/accounts/**"])

      assert Interface.check(model([], functions), rule) == []
    end
  end

  describe "shape/1" do
    test "names the interface buckets and exports" do
      assert Interface.shape(@rule) ==
               "a call into another context goes to that context's interface: a module of an " <>
                 "interfaces.buckets bucket, or one listed in interfaces.exports"
    end
  end

  defp app(AnchorFixtures.InterfaceTest.Billing.Invoice), do: :billing
  defp app(_accounts), do: :accounts

  describe "check/2 over compiled fixtures (two apps)" do
    @billing """
    defmodule AnchorFixtures.InterfaceTest.Billing.Invoice do
      @moduledoc false
      alias AnchorFixtures.InterfaceTest.Accounts

      def issue(id), do: Accounts.Domain.User.name(id)
      def ok(id), do: Accounts.Users.get(id)
    end
    """

    @accounts """
    defmodule AnchorFixtures.InterfaceTest.Accounts.Users do
      @moduledoc false
      def get(id), do: AnchorFixtures.InterfaceTest.Accounts.Domain.User.name(id)
    end

    defmodule AnchorFixtures.InterfaceTest.Accounts.Domain.User do
      @moduledoc false
      def name(id), do: id
    end
    """

    test "a call from another app into a domain module is one violation, the manager none" do
      billing = "apps/billing/lib/billing/managers/invoice.ex"
      accounts = "apps/accounts/lib/accounts/managers/users.ex"

      beams =
        [{@billing, billing}, {@accounts, accounts}]
        |> compile_all_unloaded()
        |> Enum.map(fn {module, binary} ->
          BeamReader.decode(binary, app: app(module), path: "ebin/#{module}.beam")
        end)

      {:ok, arch} =
        Architecture.parse(%{
          "contexts" => %{"depth" => 3},
          "buckets" => [
            %{
              "name" => "managers",
              "role" => "managers",
              "select" => [%{"pattern" => "*.Users"}, %{"pattern" => "*.Invoice"}]
            },
            %{"name" => "domain", "role" => "domain", "select" => [%{"pattern" => "*.Domain.*"}]}
          ],
          "calls" => %{"managers" => ["managers", "domain"], "domain" => ["domain"]},
          "interfaces" => %{"buckets" => ["managers"]}
        })

      facts =
        Map.new([{@billing, billing}, {@accounts, accounts}], fn {text, file} ->
          {file, SourceFacts.from_source(file, text)}
        end)

      graph = Builder.build(beams, facts)
      {model, []} = Model.build(graph, %Config{architecture: arch, path: ".anchor.yml"}, facts)

      assert [v] = Interface.check(model, %{type: :interface, pattern: "*.Invoice"})

      assert v.key ==
               "interface|AnchorFixtures.InterfaceTest.Billing.Invoice.issue/1|-> " <>
                 "AnchorFixtures.InterfaceTest.Accounts.Domain.User.name/1"

      assert v.message =~ "Fix: call AnchorFixtures.InterfaceTest.Accounts.Users instead."
      assert v.filename == billing
    end

    # DND-5633's narrowing: a receiver the caller's @spec types as a behaviour's
    # t() reaches its implementers only, as in layering. Judged against every
    # exporter, it reported a domain module of another context that merely
    # exports the same function.
    @narrow_ns "AnchorFixtures.InterfaceTest.Narrow"

    @narrow_billing {"""
                     defmodule #{@narrow_ns}.Billing.Port do
                       @moduledoc false
                       @type t :: module()
                       @callback go(term()) :: term()
                     end

                     defmodule #{@narrow_ns}.Billing.Impl do
                       @moduledoc false
                       @behaviour #{@narrow_ns}.Billing.Port
                       def go(id), do: id
                     end

                     defmodule #{@narrow_ns}.Billing.Runner do
                       @moduledoc false
                       @spec typed(#{@narrow_ns}.Billing.Port.t(), term()) :: term()
                       def typed(port, id), do: port.go(id)

                       def untyped(port, id), do: port.go(id)
                     end
                     """, "lib/narrow/billing.ex"}

    @narrow_accounts {"""
                      defmodule #{@narrow_ns}.Accounts.Domain.Worker do
                        @moduledoc false
                        def go(id), do: id
                      end
                      """, "lib/narrow/accounts.ex"}

    test "a behaviour-typed receiver reaches its implementers; an untyped one every exporter" do
      sources = [@narrow_billing, @narrow_accounts]

      beams =
        sources
        |> compile_all_unloaded()
        |> Enum.map(fn {module, binary} ->
          BeamReader.decode(binary, app: :app, path: "ebin/#{module}.beam")
        end)

      {:ok, arch} =
        Architecture.parse(%{
          "contexts" => %{"depth" => 4},
          "buckets" => [
            %{
              "name" => "managers",
              "role" => "managers",
              "select" => [%{"pattern" => "*.Billing.*"}]
            },
            %{"name" => "domain", "role" => "domain", "select" => [%{"pattern" => "*.Domain.*"}]}
          ],
          "calls" => %{"managers" => ["managers", "domain"], "domain" => ["domain"]},
          "interfaces" => %{"buckets" => ["managers"]}
        })

      facts = Map.new(sources, fn {text, file} -> {file, SourceFacts.from_source(file, text)} end)
      graph = Builder.build(beams, facts)
      {model, []} = Model.build(graph, %Config{architecture: arch, path: ".anchor.yml"}, facts)

      keys =
        model |> Interface.check(%{type: :interface, pattern: "*.Runner"}) |> Enum.map(& &1.key)

      assert keys == [
               "interface|#{@narrow_ns}.Billing.Runner.untyped/2|-> " <>
                 "#{@narrow_ns}.Accounts.Domain.Worker.go/1"
             ]
    end
  end
end
