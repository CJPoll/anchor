defmodule Anchor.Domain.CfaTest do
  # Domain (ADR 002). QA plan, test/anchor/domain/cfa_test.exs (DND-5497,
  # AC1-AC6, R5-R7): fixtures compiled in the test and unloaded, read through
  # BeamReader's pure decode and the graph builder, then analysed. Each row
  # pins the exact closure set (or :any) at one apply site; closure ids are
  # {mfa, lambda ordinal} for lambdas and {m, f, a} for captures.
  #
  # Sabotage record: ../../sabotage_records/cfa-20261103-dnd_5497_zero_cfa.md
  use ExUnit.Case, async: true

  import Anchor.Test.BeamFixtures

  alias Anchor.Adapters.BeamReader
  alias Anchor.Domain.Cfa
  alias Anchor.Domain.Graph
  alias Anchor.Domain.Graph.Builder
  alias AnchorFixtures.CfaTest.A
  alias AnchorFixtures.CfaTest.B
  alias AnchorFixtures.CfaTest.Open
  alias AnchorFixtures.CfaTest.S
  alias AnchorFixtures.CfaTest.Wild

  @source """
  defmodule AnchorFixtures.CfaTest.S do
    defstruct [:handler]
  end

  defmodule AnchorFixtures.CfaTest.A do
    alias AnchorFixtures.CfaTest.B
    alias AnchorFixtures.CfaTest.S

    def direct do
      f = fn x -> x end
      f.(1)
    end

    def go, do: B.run_once(fn -> :from_go end)
    def first, do: B.run(fn -> :first end)
    def second, do: B.run(fn -> :second end)

    def make, do: fn -> :made end
    def use_make, do: make().()

    def stored do
      s = %S{handler: fn -> :stored end}
      s.handler.()
    end

    def mapped(list), do: Enum.map(list, &B.f/1)

    def local_capture(x), do: B.run1(&helper/1, x)
    defp helper(x), do: x

    def loop_start, do: loop(fn -> :looped end, 3)
    def loop(f, 0), do: f.()
    def loop(f, n), do: loop(f, n - 1)

    def received do
      receive do
        {:fun, f} -> f.()
      end
    end

    def from_ets(table) do
      [{:k, f}] = :ets.lookup(table, :k)
      f.()
    end

    def open(f), do: f.()

    def escapes, do: :erlang.put(:k, fn g -> g.() end)

    def boxed, do: {:box, fn h -> h.() end}

    def via_module do
      case {:ok, AnchorFixtures.CfaTest.B} do
        {:ok, mod} -> mod.maker.()
      end
    end

    def lit_cross, do: lit_use({:ok, B})
    defp lit_use({:ok, mod}), do: mod.maker.()

    def via_apply3, do: apply(B, :run_apply, [fn -> :applied end])
    def via_spawn, do: spawn(B, :run_spawn, [fn -> :spawned end])

    def caught do
      try do
        throw(fn -> :thrown end)
      catch
        f -> f.()
      end
    end

    def var_mod_start, do: var_mod(B)
    # With an argument: a zero-arity mod.f() is a case that also tries a
    # map field, whose library call is :any on its own.
    defp var_mod(mod), do: mod.maker_with(1).()

    def spread, do: apply(fn x -> x.() end, [fn -> :spread end])

    def via_element, do: elem({:ok, fn -> :elem end}, 1).()

    def sorter(list), do: Enum.sort(list, B)

    def put_get, do: put_get_on(%{})

    defp put_get_on(base) do
      m = Map.put(base, :cb, fn -> :put end)
      Map.get(m, :cb).()
    end

    def tagged do
      case wrap() do
        {:ok, f} -> f.()
      end
    end

    defp wrap, do: {:ok, fn -> :wrapped end}

    def updated do
      s = %{cb: fn -> :kept end, n: 0}
      s = %{s | n: 1}
      s.cb.()
    end
  end

  defmodule AnchorFixtures.CfaTest.B do
    def run_once(g), do: g.()
    def run(g), do: g.()
    def run1(g, x), do: g.(x)
    def f(x), do: x
    def maker, do: fn -> :made_in_b end
    def maker_with(_x), do: fn -> :made_with end
    def run_apply(g), do: g.()
    def run_spawn(g), do: g.()
  end
  """

  @open_source """
  defmodule AnchorFixtures.CfaTest.Open do
    def dyn_apply(mod), do: apply(mod, :whatever, [fn -> :dyn end])
    def run_open(g), do: g.()
  end
  """

  @wild_source """
  defmodule AnchorFixtures.CfaTest.Wild do
    def keyed(key) do
      m = %{key => fn -> :wild end}
      m.handler.()
    end

    def none, do: :ok
  end
  """

  # The roots of the closed-world runs: what the tests call from outside.
  @roots [
    {A, :direct, 0},
    {A, :go, 0},
    {A, :first, 0},
    {A, :second, 0},
    {A, :use_make, 0},
    {A, :stored, 0},
    {A, :mapped, 1},
    {A, :local_capture, 1},
    {A, :loop_start, 0},
    {A, :received, 0},
    {A, :from_ets, 1},
    {A, :open, 1},
    {A, :escapes, 0},
    {A, :boxed, 0},
    {A, :via_module, 0},
    {A, :lit_cross, 0},
    {A, :via_apply3, 0},
    {A, :via_spawn, 0},
    {A, :caught, 0},
    {A, :var_mod_start, 0},
    {A, :spread, 0},
    {A, :via_element, 0},
    {A, :sorter, 1},
    {A, :put_get, 0},
    {A, :tagged, 0},
    {A, :updated, 0}
  ]

  setup_all do
    graph = graph!(@source)
    closed = Cfa.analyze(graph, Map.new(@roots, &{&1, :any}))
    %{graph: graph, closed: closed}
  end

  defp graph!(source) do
    source
    |> compile_unloaded("cfa_test.ex")
    |> Enum.map(fn {module, binary} ->
      BeamReader.decode(binary, app: :fixtures, path: "#{module}.beam")
    end)
    |> Builder.build(%{})
  end

  defp lambda(mfa, ordinal), do: {mfa, ordinal}
  defp site(mfa, ordinal \\ 0), do: {mfa, ordinal}
  defp set(closures), do: {:ok, MapSet.new(closures)}

  describe "analyze/2" do
    test "AC1 direct: a lambda bound and applied resolves to that lambda", %{closed: cfa} do
      assert Cfa.closures_at(cfa, site({A, :direct, 0})) ==
               set([lambda({A, :direct, 0}, 0)])
    end

    test "AC2 passed down across modules: the site in B.run_once/1 resolves to A's lambda",
         %{closed: cfa} do
      assert Cfa.closures_at(cfa, site({B, :run_once, 1})) == set([lambda({A, :go, 0}, 0)])
    end

    test "monovariance: two callers pass different lambdas, the one site resolves to both",
         %{closed: cfa} do
      assert Cfa.closures_at(cfa, site({B, :run, 1})) ==
               set([lambda({A, :first, 0}, 0), lambda({A, :second, 0}, 0)])
    end

    test "AC3 returned: make().() resolves to the lambda make/0 returns", %{closed: cfa} do
      assert Cfa.closures_at(cfa, site({A, :use_make, 0})) == set([lambda({A, :make, 0}, 0)])
      assert cfa.returns[{A, :make, 0}] == set([lambda({A, :make, 0}, 0)])
    end

    test "AC4 stored in a struct field and read back resolves (literal key)", %{closed: cfa} do
      assert Cfa.closures_at(cfa, site({A, :stored, 0})) == set([lambda({A, :stored, 0}, 0)])
    end

    test "stored under a non-literal key: a literal-key read sees the wildcard slot" do
      cfa = @wild_source |> graph!() |> Cfa.analyze(%{{Wild, :keyed, 1} => :any})

      assert Cfa.closures_at(cfa, site({Wild, :keyed, 1})) ==
               set([lambda({Wild, :keyed, 1}, 0)])
    end

    test "Map.put then Map.get on the same map resolves", %{closed: cfa} do
      assert Cfa.closures_at(cfa, site({A, :put_get_on, 1})) ==
               set([lambda({A, :put_get_on, 1}, 0)])
    end

    test "a lambda returned in an {:ok, f} tuple resolves at the caller's apply", %{closed: cfa} do
      assert Cfa.closures_at(cfa, site({A, :tagged, 0})) == set([lambda({A, :wrap, 0}, 0)])
    end

    test "a field kept through a map update is read from the map it was built on", %{closed: cfa} do
      assert Cfa.closures_at(cfa, site({A, :updated, 0})) == set([lambda({A, :updated, 0}, 0)])
    end

    test "AC5 Enum.map(list, &M.f/1): the invocation inside Enum.map resolves to the capture",
         %{closed: cfa} do
      assert Cfa.closures_at(cfa, site({A, :mapped, 1})) == set([{B, :f, 1}])
    end

    test "a captured local &helper/1 passed and applied resolves to the capture", %{closed: cfa} do
      assert Cfa.closures_at(cfa, site({B, :run1, 2})) == set([{A, :helper, 1}])
    end

    test "recursion: a function passing its own lambda parameter to itself terminates and resolves",
         %{closed: cfa} do
      refute cfa.bound_hit?
      assert Cfa.closures_at(cfa, site({A, :loop, 2})) == set([lambda({A, :loop_start, 0}, 0)])
    end

    test "AC6 a fun received in a message is :any", %{closed: cfa} do
      assert Cfa.closures_at(cfa, site({A, :received, 0})) == :any
    end

    test "a fun read from :ets.lookup is :any", %{closed: cfa} do
      assert Cfa.closures_at(cfa, site({A, :from_ets, 1})) == :any
    end

    test "a lambda handed to outside code is called with anything: its parameter's site is :any",
         %{closed: cfa} do
      assert Cfa.closures_at(cfa, site({A, :escapes, 0})) == :any
    end

    test "a lambda stored in a container escapes: its parameter's site is :any", %{closed: cfa} do
      assert Cfa.closures_at(cfa, site({A, :boxed, 0})) == :any
    end

    test "a dot-call on a module read from a literal is :any, never the empty set",
         %{closed: cfa} do
      assert Cfa.closures_at(cfa, site({A, :via_module, 0})) == :any
    end

    test "a module in a literal tuple, passed to another function, dot-called: :any",
         %{closed: cfa} do
      assert Cfa.closures_at(cfa, site({A, :lit_use, 1})) == :any
    end

    test "apply/3 and spawn/3 with a literal project M:F feed its parameters", %{closed: cfa} do
      assert Cfa.closures_at(cfa, site({B, :run_apply, 1})) ==
               set([lambda({A, :via_apply3, 0}, 0)])

      assert Cfa.closures_at(cfa, site({B, :run_spawn, 1})) ==
               set([lambda({A, :via_spawn, 0}, 0)])
    end

    test "apply/3 with a variable module may call any exported function of that arity with anything" do
      graph = graph!(@open_source)
      cfa = Cfa.analyze(graph, %{{Open, :dyn_apply, 1} => :any})
      assert Cfa.closures_at(cfa, site({Open, :run_open, 1})) == :any

      # Control: with nothing calling apply/3, run_open's parameter holds nothing.
      quiet = Cfa.analyze(graph, %{})
      assert Cfa.closures_at(quiet, site({Open, :run_open, 1})) == set([])
    end

    test "a fun caught from a throw is :any", %{closed: cfa} do
      assert Cfa.closures_at(cfa, site({A, :caught, 0})) == :any
    end

    test "a call on a variable module returns :any", %{closed: cfa} do
      assert Cfa.closures_at(cfa, site({A, :var_mod, 1})) == :any
    end

    test "apply/2 spreads its argument list over the applied lambda's parameters",
         %{closed: cfa} do
      results = for ordinal <- 0..1, do: Cfa.closures_at(cfa, site({A, :spread, 0}, ordinal))

      assert Enum.sort(results) ==
               Enum.sort([set([lambda({A, :spread, 0}, 0)]), set([lambda({A, :spread, 0}, 1)])])
    end

    test "elem/2 on a tuple reads the field at that position", %{closed: cfa} do
      assert Cfa.closures_at(cfa, site({A, :via_element, 0})) ==
               set([lambda({A, :via_element, 0}, 0)])
    end

    test "a module passed where Enum invokes an argument (a sorter) is :any, never empty",
         %{closed: cfa} do
      assert Cfa.closures_at(cfa, site({A, :sorter, 1})) == :any
    end

    test "an exported parameter under the default seed is :any; a seed naming its closures resolves",
         %{graph: graph} do
      open = {A, :open, 1}
      default = Cfa.analyze(graph, Cfa.default_seed(graph))

      assert Cfa.closures_at(default, site(open)) == :any
      assert Cfa.closures_at(default, site({B, :run, 1})) == :any

      seeded = Cfa.analyze(graph, %{open => [MapSet.new([lambda({A, :direct, 0}, 0)])]})
      assert Cfa.closures_at(seeded, site(open)) == set([lambda({A, :direct, 0}, 0)])
    end

    test "a seed naming the wrong number of parameter values raises, naming the function",
         %{graph: graph} do
      assert_raise ArgumentError,
                   ~r/AnchorFixtures.CfaTest.A, :open, 1.*names 2 parameter values/,
                   fn ->
                     Cfa.analyze(graph, %{{A, :open, 1} => [:any, :any]})
                   end
    end

    test "default_seed/1 makes every exported function a root, never a private one",
         %{graph: graph} do
      seed = Cfa.default_seed(graph)

      assert seed[{A, :open, 1}] == :any
      assert seed[{B, :run, 1}] == :any
      refute Map.has_key?(seed, {A, :helper, 1})
    end

    test "a seed naming a function the graph does not hold raises, with a Fix", %{graph: graph} do
      assert_raise ArgumentError, ~r/:nope, 0.*Fix: /, fn ->
        Cfa.analyze(graph, %{{A, :nope, 0} => :any})
      end
    end

    test "an unknown site id is an error, never an empty set", %{closed: cfa} do
      assert Cfa.closures_at(cfa, site({A, :direct, 0}, 99)) == {:error, :unknown_site}
    end
  end

  describe "counts" do
    # S.__struct__/1 is the struct's generated builder: its Enum.reduce
    # invokes its own lambda, so it is a site too.
    test "the fixture's exact resolved and any counts, total and per function", %{closed: cfa} do
      assert Map.delete(cfa.counts, :by_function) == %{total: 27, resolved: 17, any: 10}

      assert cfa.counts.by_function == %{
               {A, :boxed, 0} => %{total: 1, resolved: 0, any: 1},
               {A, :caught, 0} => %{total: 1, resolved: 0, any: 1},
               {A, :direct, 0} => %{total: 1, resolved: 1, any: 0},
               {A, :escapes, 0} => %{total: 1, resolved: 0, any: 1},
               {A, :from_ets, 1} => %{total: 1, resolved: 0, any: 1},
               {A, :lit_use, 1} => %{total: 1, resolved: 0, any: 1},
               {A, :loop, 2} => %{total: 1, resolved: 1, any: 0},
               {A, :mapped, 1} => %{total: 1, resolved: 1, any: 0},
               {A, :open, 1} => %{total: 1, resolved: 0, any: 1},
               {A, :put_get_on, 1} => %{total: 1, resolved: 1, any: 0},
               {A, :received, 0} => %{total: 1, resolved: 0, any: 1},
               {A, :sorter, 1} => %{total: 1, resolved: 0, any: 1},
               {A, :spread, 0} => %{total: 2, resolved: 2, any: 0},
               {A, :stored, 0} => %{total: 1, resolved: 1, any: 0},
               {A, :tagged, 0} => %{total: 1, resolved: 1, any: 0},
               {A, :updated, 0} => %{total: 1, resolved: 1, any: 0},
               {A, :use_make, 0} => %{total: 1, resolved: 1, any: 0},
               {A, :var_mod, 1} => %{total: 1, resolved: 0, any: 1},
               {A, :via_element, 0} => %{total: 1, resolved: 1, any: 0},
               {A, :via_module, 0} => %{total: 1, resolved: 0, any: 1},
               {B, :run, 1} => %{total: 1, resolved: 1, any: 0},
               {B, :run1, 2} => %{total: 1, resolved: 1, any: 0},
               {B, :run_apply, 1} => %{total: 1, resolved: 1, any: 0},
               {B, :run_once, 1} => %{total: 1, resolved: 1, any: 0},
               {B, :run_spawn, 1} => %{total: 1, resolved: 1, any: 0},
               {S, :__struct__, 1} => %{total: 1, resolved: 1, any: 0}
             }
    end

    test "an empty graph and a graph with no apply sites count zero sites" do
      empty = Cfa.analyze(%Graph{}, %{})
      assert empty.counts == %{total: 0, resolved: 0, any: 0, by_function: %{}}
      assert empty.sites == %{}

      plain =
        "defmodule AnchorFixtures.CfaTest.Plain do\n  def ok, do: :ok\nend\n"
        |> graph!()
        |> then(&Cfa.analyze(&1, Cfa.default_seed(&1)))

      assert plain.counts == %{total: 0, resolved: 0, any: 0, by_function: %{}}
    end
  end

  describe "the bound" do
    test "a run that hits :max_steps reports every site :any and says so", %{graph: graph} do
      cfa = Cfa.analyze(graph, Map.new(@roots, &{&1, :any}), max_steps: 1)

      assert cfa.bound_hit?
      assert cfa.steps == 1
      assert Cfa.closures_at(cfa, site({A, :direct, 0})) == :any
      assert cfa.counts.resolved == 0
      assert cfa.counts.any == cfa.counts.total
    end

    test "the default bound is not hit on the fixture", %{closed: cfa} do
      refute cfa.bound_hit?
      assert cfa.steps > 1
    end
  end
end
