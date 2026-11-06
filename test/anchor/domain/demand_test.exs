defmodule Anchor.Domain.DemandTest do
  # Domain (ADR 002). QA plan, test/anchor/domain/demand_test.exs (DND-5498,
  # AC1-AC6, R3-R6): fixtures compiled in the test and unloaded, read through
  # BeamReader's pure decode and the graph builder, the 0-CFA run with the
  # fixtures' entry points as roots, then the demand analysis. Each row pins
  # the exact demand (and, where the row is about it, the passes, the
  # imprecise reasons or the counts).
  #
  # Sabotage record: ../../sabotage_records/demand-20261103-dnd_5498_demand.md
  use ExUnit.Case, async: true

  import Anchor.Test.BeamFixtures

  alias Anchor.Adapters.BeamReader
  alias Anchor.Domain.Cfa
  alias Anchor.Domain.Demand
  alias Anchor.Domain.Graph.Builder
  alias AnchorFixtures.DemandTest.A
  alias AnchorFixtures.DemandTest.B
  alias AnchorFixtures.DemandTest.C
  alias AnchorFixtures.DemandTest.D
  alias AnchorFixtures.DemandTest.Used

  @runs [:run, :run_used, :run_wrong, :run_cap, :apply_it]

  @source """
  defmodule AnchorFixtures.DemandTest.A do
    alias AnchorFixtures.DemandTest.B

    def first(a, _b), do: a
    def field(m), do: m.x

    def chain(x), do: B.g(x)

    def loop(0, _acc), do: :done
    def loop(n, acc), do: loop(n - 1, acc)

    def ping(0, _p), do: :done
    def ping(n, p), do: B.pong(n - 1, p)

    def sent(p) do
      send(self(), p)
      :ok
    end

    def started(p) do
      Task.start(fn -> p end)
      :ok
    end

    def ignored(p), do: B.run(fn _x -> :ignored end, p)
    def used_apply(p), do: B.run_used(fn x -> x end, p)
    def wrong_arity(p), do: B.run_wrong(fn _a, _b -> :two end, p)
    def captured(p), do: B.run_cap(&IO.puts/1, p)
    def listed(p), do: B.apply_it(fn x -> x end, p)
    def open(f, p), do: f.(p)

    def dep(p) do
      SomeDep.call(p)
      :ok
    end

    def via_open(f, p), do: open(f, p)

    def received(m) do
      receive do
        {:x, y} -> y + m
      end
    end

    def received_drop(_m) do
      receive do
        {:x, y} -> y
      end
    end

    def guarded_helper(a) do
      try do
        helper(a)
      rescue
        _error -> :error
      end
    end

    defp helper(a) do
      _ = hd(a)
      :ok
    end

    def guarded_lambda(a) do
      f = fn x ->
        _ = hd(x)
        :ok
      end

      try do
        f.(a)
      rescue
        _error -> :error
      end
    end

    def guarded_apply(a) do
      f = fn x ->
        _ = hd(x)
        :ok
      end

      args = [a]

      try do
        apply(f, args)
      rescue
        _error -> :error
      end
    end

    def notify(p) do
      ExtNotifier.push(p)
      :ok
    end
  end

  defmodule AnchorFixtures.DemandTest.B do
    alias AnchorFixtures.DemandTest.A
    alias AnchorFixtures.DemandTest.C

    def g(x), do: C.h(x)
    def pong(n, p), do: A.ping(n, p)
    def run(f, p), do: f.(p)
    def run_used(f, p), do: f.(p)
    def run_wrong(f, p), do: f.(p)
    def run_cap(f, p), do: f.(p)
    def apply_it(f, x), do: apply(f, [x])
  end

  defmodule AnchorFixtures.DemandTest.C do
    def h(_x), do: :ok
  end
  """

  # The positive controls: the same shapes, with the parameter used at the end.
  @used_source """
  defmodule AnchorFixtures.DemandTest.Used do
    alias AnchorFixtures.DemandTest.D

    def chain(x), do: D.g(x)
    def call_ping(p), do: ping(1, p)
    def ping(0, p), do: p
    def ping(n, p), do: D.pong(n - 1, p)
  end

  defmodule AnchorFixtures.DemandTest.D do
    alias AnchorFixtures.DemandTest.Used

    def g(x), do: h(x)
    def h(x), do: x
    def pong(n, p), do: Used.ping(n, p)
  end
  """

  # Every exported function of A is a root, but not B's run functions: their
  # apply sites get only what A passes them.
  setup_all do
    graph = graph!(@source)

    seed =
      graph
      |> Cfa.default_seed()
      |> Map.reject(fn {{m, f, _a}, _any} -> m == B and f in @runs end)

    cfa = Cfa.analyze(graph, seed)
    used_graph = graph!(@used_source)
    used_cfa = Cfa.analyze(used_graph, Cfa.default_seed(used_graph))

    %{
      graph: graph,
      cfa: cfa,
      demand: Demand.analyze(graph, cfa, []),
      used_graph: used_graph,
      used_cfa: used_cfa,
      used: Demand.analyze(used_graph, used_cfa, [])
    }
  end

  defp graph!(source) do
    source
    |> compile_unloaded("demand_test.ex")
    |> Enum.map(fn {module, binary} ->
      BeamReader.decode(binary, app: :fixtures, path: "#{module}.beam")
    end)
    |> Builder.build(%{})
  end

  defp demands(demand, mfa), do: Enum.map(demand.summaries[mfa], & &1.demand)

  describe "analyze/4" do
    test "AC1 def f(a, b), do: a gives [used(all), absent]", %{demand: demand} do
      assert demands(demand, {A, :first, 2}) == [:all, :absent]
      assert Demand.param(demand, {A, :first, 2}, 1) == :absent
    end

    test "AC2 def f(m), do: m.x gives [used(%{x: used(all)})]", %{demand: demand} do
      assert demands(demand, {A, :field, 1}) == [{:used, %{x: :all}}]
    end

    test "AC3 a parameter passed down two calls and dropped by the last is absent at all three",
         %{demand: demand} do
      assert demands(demand, {A, :chain, 1}) == [:absent]
      assert demands(demand, {B, :g, 1}) == [:absent]
      assert demands(demand, {C, :h, 1}) == [:absent]
    end

    test "AC3 positive control: the last returns it, and it is used at all three",
         %{used: demand} do
      assert demands(demand, {Used, :chain, 1}) == [:all]
      assert demands(demand, {D, :g, 1}) == [:all]
      assert demands(demand, {D, :h, 1}) == [:all]
    end

    test "passes: each level names the call it passes the parameter to", %{demand: demand} do
      assert hd(demand.summaries[{A, :chain, 1}]).passes == [{{B, :g, 1}, 0}]
      assert hd(demand.summaries[{B, :g, 1}]).passes == [{{C, :h, 1}, 0}]
      assert hd(demand.summaries[{C, :h, 1}]).passes == []
    end

    test "self recursion loop(n, acc): acc absent, n used", %{demand: demand} do
      assert demands(demand, {A, :loop, 2}) == [:all, :absent]
      assert Enum.at(demand.summaries[{A, :loop, 2}], 1).passes == [{{A, :loop, 2}, 1}]
    end

    test "AC5 mutual recursion passing p around without using it: absent", %{demand: demand} do
      assert demands(demand, {A, :ping, 2}) == [:all, :absent]
      assert demands(demand, {B, :pong, 2}) == [:all, :absent]
    end

    test "AC5 positive control: mutual recursion that returns p at the base uses it on both sides",
         %{used: demand} do
      assert demands(demand, {Used, :ping, 2}) == [:all, :all]
      assert demands(demand, {D, :pong, 2}) == [:all, :all]
    end

    test "AC4 a parameter only sent in a message is used (escape), and judged precisely",
         %{demand: demand} do
      assert demands(demand, {A, :sent, 1}) == [:all]
      refute Map.has_key?(demand.imprecise, {A, :sent, 1})
    end

    test "a closure capturing p handed to Task.start/1 uses p (escape)", %{demand: demand} do
      assert demands(demand, {A, :started, 1}) == [:all]
      refute Map.has_key?(demand.imprecise, {A, :started, 1})
    end

    test "an apply the 0-CFA resolves to a lambda that ignores its argument: absent",
         %{demand: demand} do
      assert demands(demand, {A, :ignored, 1}) == [:absent]
      assert demands(demand, {B, :run, 2}) == [:all, :absent]
      assert demand.lambdas[{{A, :ignored, 1}, 0}] == [:absent]
      refute Map.has_key?(demand.imprecise, {A, :ignored, 1})
    end

    test "receive (a letrec over recv primops): a captured parameter the clause uses is used",
         %{demand: demand} do
      assert demands(demand, {A, :received, 1}) == [:all]
      assert demands(demand, {A, :received_drop, 1}) == [:absent]
    end

    test "positive control: the same shape with a lambda that returns its argument: used",
         %{demand: demand} do
      assert demands(demand, {A, :used_apply, 1}) == [:all]
      assert demands(demand, {B, :run_used, 2}) == [:all, :all]
      refute Map.has_key?(demand.imprecise, {A, :used_apply, 1})
    end

    test "a closure of another arity reaching the site uses nothing (the call raises badarity)",
         %{demand: demand} do
      assert demands(demand, {B, :run_wrong, 2}) == [:all, :absent]
      assert demands(demand, {A, :wrong_arity, 1}) == [:absent]
    end

    test "a library capture resolved at a site: an effect uses the argument, precisely",
         %{demand: demand} do
      assert demands(demand, {B, :run_cap, 2}) == [:all, :all]
      refute Map.has_key?(demand.imprecise, {B, :run_cap, 2})
    end

    test "apply(f, [x]) with f resolved to a lambda that returns its argument: x used",
         %{demand: demand} do
      assert demands(demand, {B, :apply_it, 2}) == [:all, :all]
      assert demands(demand, {A, :listed, 1}) == [:all]
      refute Map.has_key?(demand.imprecise, {B, :apply_it, 2})
    end

    test "an extra module token makes every function of the module an effect", context do
      demand = Demand.analyze(context.graph, context.cfa, ["ExtNotifier"])
      refute Map.has_key?(demand.imprecise, {A, :notify, 1})
    end

    test "inside try, a project call or a lambda apply that can raise uses its argument",
         %{demand: demand} do
      assert demands(demand, {A, :guarded_helper, 1}) == [:all]
      assert demands(demand, {A, :guarded_lambda, 1}) == [:all]
      assert demands(demand, {A, :guarded_apply, 1}) == [:all]
      # Positive control: the helper on its own (outside any try) does not use it.
      assert demands(demand, {A, :helper, 1}) == [:absent]
    end

    test "AC6 a parameter passed to an :any apply: used, and the function is imprecise",
         %{demand: demand} do
      assert demands(demand, {A, :open, 2}) == [:all, :all]
      assert Enum.map(demand.summaries[{A, :open, 2}], & &1.imprecise?) == [false, true]
      assert demand.imprecise[{A, :open, 2}] == [{:any_apply, {{A, :open, 2}, 0}}]
    end

    test "a caller of an imprecise function is imprecise through it", %{demand: demand} do
      assert demands(demand, {A, :via_open, 2}) == [:all, :all]
      assert demand.imprecise[{A, :via_open, 2}] == [{:via, {A, :open, 2}}]
    end

    test "an unknown non-project call uses its argument and makes the function imprecise",
         %{demand: demand} do
      assert demands(demand, {A, :dep, 1}) == [:all]
      assert demand.imprecise[{A, :dep, 1}] == [{:unknown_call, {SomeDep, :call, 1}}]
    end

    test "an extra effect token makes a library call an effect: used, and precise", context do
      demand = Demand.analyze(context.graph, context.cfa, ["ExtNotifier.push/1"])
      assert demands(demand, {A, :notify, 1}) == [:all]
      refute Map.has_key?(demand.imprecise, {A, :notify, 1})

      # Positive control: without the token the call is unknown.
      assert context.demand.imprecise[{A, :notify, 1}] ==
               [{:unknown_call, {ExtNotifier, :push, 1}}]
    end

    test "an extra effect token that does not parse raises", context do
      assert_raise ArgumentError, ~r/is not a function reference/, fn ->
        Demand.analyze(context.graph, context.cfa, ["not a token"])
      end
    end

    test "param/3 raises for a negative or out-of-range index, never reading from the end",
         %{demand: demand} do
      assert_raise ArgumentError, ~r/was not analysed/, fn ->
        Demand.param(demand, {A, :first, 2}, -1)
      end

      assert_raise ArgumentError, ~r/was not analysed/, fn ->
        Demand.param(demand, {A, :first, 2}, 2)
      end
    end

    test "param/3 raises for a function the analysis did not cover", %{demand: demand} do
      assert_raise ArgumentError, ~r/was not analysed/, fn ->
        Demand.param(demand, {A, :missing, 1}, 0)
      end
    end
  end

  describe "a lattice's shape (the two summaries the whole-Anchor self test knew, DND-5715)" do
    @lattice """
    defmodule AnchorFixtures.DemandTest.LatticeShape do
      def at(:absent, _key), do: :absent
      def at(:all, _key), do: :all
      def at({:used, fields}, key), do: Map.get(fields, key, :absent)

      def join(:absent, other), do: other
      def join(other, :absent), do: other
      def join(:all, _other), do: :all
      def join(_other, :all), do: :all

      def join({:used, left}, {:used, right}),
        do: bound({:used, Map.merge(left, right, fn _key, l, r -> join(l, r) end)})

      def bound(demand), do: demand
    end
    """

    setup do
      graph = graph!(@lattice)
      %{lattice: Demand.analyze(graph, Cfa.analyze(graph, Cfa.default_seed(graph)), [])}
    end

    test "at/2 reads its first parameter in full, and its key", %{lattice: demand} do
      assert Demand.param(demand, {AnchorFixtures.DemandTest.LatticeShape, :at, 2}, 0) == :all
      assert Demand.param(demand, {AnchorFixtures.DemandTest.LatticeShape, :at, 2}, 1) == :all
    end

    test "join/2 reads both parameters in full, through its own recursion", %{lattice: demand} do
      assert Demand.param(demand, {AnchorFixtures.DemandTest.LatticeShape, :join, 2}, 0) == :all
      assert Demand.param(demand, {AnchorFixtures.DemandTest.LatticeShape, :join, 2}, 1) == :all
    end
  end

  describe "counts" do
    test "the counts agree with the summaries they count", %{demand: demand} do
      assert demand.counts.functions == map_size(demand.summaries)

      assert demand.counts.parameters ==
               demand.summaries |> Map.values() |> List.flatten() |> length()

      # Positive control: the fixture has functions and absent parameters.
      assert demand.counts.functions > 0
      assert demand.counts.absent > 0
    end

    # 30 functions (A 22, B 7, C 1), 41 parameters; absent: first/2's b,
    # chain, g, h, loop's acc, ping's and pong's p, ignored's p, run's p,
    # received_drop's m, wrong_arity's p, run_wrong's p, helper's a. 25
    # components: five cycles merge two functions each (ping/pong, and each
    # A function with the B function that applies its lambda: ignored/run,
    # used_apply/run_used, wrong_arity/run_wrong, listed/apply_it); 50 rounds,
    # each component's last unchanged.
    test "functions analysed, absent parameters and imprecise functions, exact", %{demand: demand} do
      assert %{
               functions: 30,
               parameters: 41,
               absent: 13,
               imprecise_parameters: 4,
               imprecise_functions: 4,
               components: 25,
               rounds: 50
             } == demand.counts

      assert demand.imprecise |> Map.keys() |> Enum.sort() == [
               {A, :dep, 1},
               {A, :notify, 1},
               {A, :open, 2},
               {A, :via_open, 2}
             ]

      assert demand.bound_hit == []
    end
  end

  describe "the round bound" do
    test "a component that does not settle within :max_rounds is used, imprecise and named",
         context do
      demand = Demand.analyze(context.used_graph, context.used_cfa, [], max_rounds: 2)
      component = [{D, :pong, 2}, {Used, :ping, 2}]

      assert demand.bound_hit == component

      for mfa <- component do
        assert demands(demand, mfa) == [:all, :all]
        assert demand.imprecise[mfa] == [:bound_hit]
      end

      # A caller passing a parameter into the unsettled component is imprecise through it.
      assert demands(demand, {Used, :call_ping, 1}) == [:all]
      assert demand.imprecise[{Used, :call_ping, 1}] == [{:via, {Used, :ping, 2}}]

      # Positive control: the default bound settles the same component.
      assert context.used.bound_hit == []
      refute Map.has_key?(context.used.imprecise, {Used, :ping, 2})
      refute Map.has_key?(context.used.imprecise, {Used, :call_ping, 1})
    end

    test ":max_rounds must be a positive integer", context do
      assert_raise ArgumentError, ~r/:max_rounds must be a positive integer/, fn ->
        Demand.analyze(context.graph, context.cfa, [], max_rounds: 0)
      end
    end
  end
end
