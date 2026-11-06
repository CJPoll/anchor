defmodule Anchor.Domain.InterfacesTest do
  # DND-5443: a context's interface over hand-built models. Pure Domain.
  #
  # Sabotage record: ../../sabotage_records/interface-20261103-dnd_5443_graph_rules_b.md
  use ExUnit.Case, async: true

  alias Anchor.Domain.Classification
  alias Anchor.Domain.Graph
  alias Anchor.Domain.Graph.Call
  alias Anchor.Domain.Graph.FunctionNode
  alias Anchor.Domain.Graph.ModuleNode
  alias Anchor.Domain.Interfaces
  alias Anchor.Domain.Model

  # module => {bucket, context, interface?, [{name, arity, kind}]}
  @modules %{
    App.Accounts.Users => {"managers", "App.Accounts", true, [{:get, 1, :def}, {:list, 0, :def}]},
    App.Accounts.Admin =>
      {"managers", "App.Accounts", true,
       [{:grant, 2, :def}, {:revoke, 2, :def}, {:audit, 1, :def}, {:helper, 0, :defp}]},
    App.Accounts.Api => {"domain", "App.Accounts", true, []},
    App.Accounts.User =>
      {"domain", "App.Accounts", false,
       [{:new, 1, :def}, {:__struct__, 0, :def}, {:__struct__, 1, :def}]},
    App.Accounts.Hash => {"domain", "App.Accounts", false, [{:digest, 1, :def}]},
    App.Billing.Invoices =>
      {"managers", "App.Billing", true,
       [{:pay, 1, :def}, {:module_info, 0, :def}, {:__info__, 1, :def}]},
    Top => {"framework", nil, false, [{:run, 0, :def}]}
  }

  defp model(calls \\ []) do
    classification =
      Map.new(@modules, fn {module, {bucket, context, interface?, _functions}} ->
        {module,
         %Classification{
           module: module,
           bucket: bucket,
           role: String.to_atom(bucket),
           context: context,
           interface?: interface?
         }}
      end)

    nodes =
      Map.new(@modules, fn {module, {_bucket, _context, _interface?, functions}} ->
        {module,
         %ModuleNode{
           module: module,
           app: :app,
           functions:
             Map.new(functions, fn {name, arity, kind} ->
               {{name, arity},
                %FunctionNode{module: module, name: name, arity: arity, kind: kind, line: 1}}
             end)
         }}
      end)

    %Model{
      graph: %Graph{modules: nodes, calls: Enum.map(calls, &call/1)},
      architecture: nil,
      classification: classification,
      config: nil
    }
  end

  defp call({from, to}),
    do: %Call{from: {from, :f, 0}, to: {to, :g, 0}, kind: :remote, line: 3, line_source: :call}

  describe "modules_of/2" do
    test "the context's interface modules (managers and exports), sorted; not its domain ones" do
      assert Interfaces.modules_of(model(), "App.Accounts") ==
               [App.Accounts.Admin, App.Accounts.Api, App.Accounts.Users]
    end

    test "another context's are its own" do
      assert Interfaces.modules_of(model(), "App.Billing") == [App.Billing.Invoices]
    end

    test "a context with no module has none" do
      assert Interfaces.modules_of(model(), "App.Nope") == []
    end
  end

  describe "width/1" do
    test "public functions of interface modules per context; generated and private not counted" do
      # Users 2 + Admin 3 (helper/0 is private) + Api 0; Invoices 1 (module_info/0
      # and __info__/1 are the compiler's). User and Hash are not interface.
      assert Interfaces.width(model()) == %{"App.Accounts" => 5, "App.Billing" => 1}
    end

    test "a module with no context is counted nowhere" do
      refute Map.has_key?(Interfaces.width(model()), nil)
    end
  end

  describe "route/2" do
    test "one interface module reaching the target through one same-context hop is the route" do
      calls = [{App.Accounts.Users, App.Accounts.Hash}, {App.Accounts.Hash, App.Accounts.User}]

      assert Interfaces.route(model(calls), App.Accounts.User) == {:ok, App.Accounts.Users}
    end

    test "two interface modules reaching it is :none" do
      calls = [{App.Accounts.Users, App.Accounts.User}, {App.Accounts.Admin, App.Accounts.User}]

      assert Interfaces.route(model(calls), App.Accounts.User) == :none
    end

    test "none reaching it is :none" do
      assert Interfaces.route(model([]), App.Accounts.User) == :none
    end

    test "a call from another context is no route" do
      calls = [{App.Billing.Invoices, App.Accounts.User}]

      assert Interfaces.route(model(calls), App.Accounts.User) == :none
    end

    test "a call cycle inside the context ends" do
      calls = [
        {App.Accounts.Hash, App.Accounts.User},
        {App.Accounts.User, App.Accounts.Hash},
        {App.Accounts.Users, App.Accounts.Hash}
      ]

      assert Interfaces.route(model(calls), App.Accounts.User) == {:ok, App.Accounts.Users}
    end

    test "a target with no context has no route" do
      assert Interfaces.route(model([{App.Accounts.Users, Top}]), Top) == :none
    end
  end
end
