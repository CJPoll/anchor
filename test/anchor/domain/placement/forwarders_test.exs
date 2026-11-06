defmodule Anchor.Domain.Placement.ForwardersTest do
  # Domain (ADR 002). DND-5461: forwarder detection on Core compiled in the test
  # (AnchorFixtures.ForwardersTest.*), and the boundary test on hand-built models.
  #
  # Sabotage record: ../../../sabotage_records/placement-20261106-dnd_5461_placement_rules.md
  use ExUnit.Case, async: true

  import Anchor.Test.BeamFixtures
  import Anchor.Test.PlacementModels

  alias Anchor.Domain.Aggregates.Index
  alias Anchor.Domain.Effects
  alias Anchor.Domain.Graph.FunctionNode
  alias Anchor.Domain.Placement.Forwarders

  @source """
  defmodule AnchorFixtures.ForwardersTest.F do
    def plain(xs), do: Math.sum(xs)
    defdelegate delegated(xs), to: Math, as: :sum
    def reordered(a, b), do: N.g(b, a)
    def literal(a), do: N.g(a, :x)
    def pattern(%{} = i), do: N.g(i)
    def guarded(a) when is_list(a), do: N.g(a)
    def two(nil), do: nil
    def two(a), do: N.g(a)
    def local(a), do: helper(a)
    def self_remote(a), do: __MODULE__.pub(a)
    def pub(a), do: a
    def shadowed(a), do: N.g(a)
    def shadowed(b), do: N.h(b)
    def piped(a), do: a |> Enum.sort() |> N.g()
    def none, do: N.g()
    def renamed(a) do
      b = a
      N.g(b)
    end

    defp helper(a), do: a
  end
  """

  setup_all do
    [{_module, binary}] = compile_unloaded(@source)
    %{binary: binary}
  end

  defp forwarder(binary, name_arity) do
    {name, arity} = name_arity
    module = AnchorFixtures.ForwardersTest.F

    Forwarders.forwarder(%FunctionNode{
      module: module,
      name: name,
      arity: arity,
      kind: :def,
      line: 1,
      core: core_fun!(binary, name_arity)
    })
  end

  describe "forwarder/1" do
    test "a plain forwarder", %{binary: binary} do
      assert forwarder(binary, {:plain, 1}) == {:forwards, {Math, :sum, 1}}
    end

    test "defdelegate reads the same", %{binary: binary} do
      assert forwarder(binary, {:delegated, 1}) == {:forwards, {Math, :sum, 1}}
    end

    test "a zero-arity forwarder", %{binary: binary} do
      assert forwarder(binary, {:none, 0}) == {:forwards, {N, :g, 0}}
    end

    test "a let that only renames a variable is peeled", %{binary: binary} do
      assert forwarder(binary, {:renamed, 1}) == {:forwards, {N, :g, 1}}
    end

    test "reordered arguments are not a forwarder", %{binary: binary} do
      assert forwarder(binary, {:reordered, 2}) == :no
    end

    test "an extra literal argument is not a forwarder", %{binary: binary} do
      assert forwarder(binary, {:literal, 1}) == :no
    end

    test "a pattern in the head is not a forwarder", %{binary: binary} do
      assert forwarder(binary, {:pattern, 1}) == :no
    end

    test "a guard is not a forwarder", %{binary: binary} do
      assert forwarder(binary, {:guarded, 1}) == :no
    end

    test "two clauses are not a forwarder", %{binary: binary} do
      assert forwarder(binary, {:two, 1}) == :no
    end

    test "a call into the same module is not this rule's (no_forwarding_function)", %{
      binary: binary
    } do
      assert forwarder(binary, {:local, 1}) == :no
    end

    test "a remote call into its own module is not this rule's either", %{binary: binary} do
      assert forwarder(binary, {:self_remote, 1}) == :no
    end

    test "a forwarding first clause with a second clause is not a forwarder", %{binary: binary} do
      assert forwarder(binary, {:shadowed, 1}) == :no
    end

    test "a transforming pipe is not a forwarder", %{binary: binary} do
      assert forwarder(binary, {:piped, 1}) == :no
    end

    test "a function with no Core is not a forwarder" do
      node = %FunctionNode{module: M, name: :f, arity: 1, kind: :def, line: 1, core: nil}
      assert Forwarders.forwarder(node) == :no
    end
  end

  describe "boundary/3" do
    @from {Totals, :sum, 1}
    @to {MathMod, :sum, 1}

    defp boundary(from_opts, to_opts, opts \\ []) do
      {from_bucket, from_opts} = Keyword.pop(from_opts, :bucket, "domain")
      {to_bucket, to_opts} = Keyword.pop(to_opts, :bucket, "domain")

      modules = [
        {Totals, from_bucket, [{:sum, 1}, {:handle_call, 3}], from_opts},
        {MathMod, to_bucket, [{:sum, 1}], to_opts}
      ]

      model = model(modules, [], opts)
      model = Keyword.get(opts, :adjust, & &1).(model)
      Forwarders.boundary(model, Keyword.get(opts, :from, @from), @to)
    end

    test "same bucket, context and app, no interface and no callback: none" do
      assert boundary([], []) == :none
    end

    test "a bucket crossing" do
      assert boundary([bucket: "framework"], bucket: "managers") == {:crosses, :bucket}
    end

    test "a context crossing" do
      assert boundary([context: "Billing"], context: "Shipping") == {:crosses, :context}
    end

    test "a target outside the project is a dependency" do
      model = model([{Totals, "adapters", [{:get, 1}], []}], [])

      assert Forwarders.boundary(model, {Totals, :get, 1}, {Req, :get, 1}) ==
               {:crosses, :dependency}
    end

    test "an unclassified target is not judged inert" do
      adjust = fn model -> update_in(model.classification, &Map.delete(&1, MathMod)) end
      assert boundary([], [], adjust: adjust) == {:crosses, :unclassified}
    end

    test "an app crossing" do
      adjust = fn model -> put_in(model.graph.modules[MathMod].app, :other) end
      assert boundary([], [], adjust: adjust) == {:crosses, :app}
    end

    test "an interface forwarding to a module that is not one" do
      assert boundary([interface: true], []) == {:crosses, :interface}
      # Positive control: interface to interface is no interface crossing.
      assert boundary([interface: true], interface: true) == :none
    end

    test "an external behaviour's callback the inference was given" do
      adjust = fn model ->
        model = put_in(model.graph.modules[Totals].behaviours, [GenServer])
        %{model | effects: %Effects{callbacks: %{GenServer => [{:handle_call, 3}]}}}
      end

      assert boundary([], [], adjust: adjust, from: {Totals, :handle_call, 3}) ==
               {:crosses, :callback}

      # Positive control: a function of the module that is no callback.
      assert boundary([], [], adjust: adjust) == :none
    end

    test "a project behaviour's callback" do
      adjust = fn model ->
        model = put_in(model.graph.modules[Totals].behaviours, [MathMod])
        put_in(model.graph.modules[MathMod].callbacks, [{:sum, 1}])
      end

      assert boundary([], [], adjust: adjust) == {:crosses, :callback}
    end

    test "different aggregates, when declared" do
      adjust = fn model ->
        %{model | aggregates: %Index{by_schema: %{Totals => "a"}, owners: %{MathMod => ["b"]}}}
      end

      assert boundary([], [], adjust: adjust) == {:crosses, :aggregate}

      same = fn model ->
        %{model | aggregates: %Index{by_schema: %{Totals => "a"}, owners: %{MathMod => ["a"]}}}
      end

      assert boundary([], [], adjust: same) == :none
    end

    test "no aggregates declared: the aggregate test is not judged" do
      assert boundary([], [], adjust: &%{&1 | aggregates: %Index{}}) == :none
    end
  end
end
