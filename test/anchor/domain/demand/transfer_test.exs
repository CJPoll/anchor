defmodule Anchor.Domain.Demand.TransferTest do
  # Domain (ADR 002). QA plan, test/anchor/domain/demand/transfer_test.exs
  # (DND-5498, R1-R3): one backward pass over the Core of a single function
  # compiled in the test, with no callee summaries. Each row pins the exact
  # demand on every parameter.
  #
  # Sabotage record: ../../../sabotage_records/demand-20261103-dnd_5498_demand.md
  use ExUnit.Case, async: true

  import Anchor.Test.BeamFixtures

  alias Anchor.Adapters.BeamReader
  alias Anchor.Domain.Cfa
  alias Anchor.Domain.Core
  alias Anchor.Domain.Demand.Transfer
  alias Anchor.Domain.Graph
  alias Anchor.Domain.Graph.Builder
  alias AnchorFixtures.TransferTest.F

  @source """
  defmodule AnchorFixtures.TransferTest.S do
    defstruct [:name, :age]
  end

  defmodule AnchorFixtures.TransferTest.F do
    alias AnchorFixtures.TransferTest.S

    def first(a, _b), do: a
    def field(m), do: m.x
    def fields(m), do: {m.x, m.y}
    def tuple_field(t), do: elem(t, 1)
    def map_get(m), do: Map.get(m, :k)

    def discarded(a) do
      _ = a + 1
      :ok
    end

    def printed(a) do
      IO.puts(a)
      :ok
    end

    def sent(a) do
      send(self(), a)
      :ok
    end

    def branch(a, _b), do: if(a, do: 1, else: 2)
    def head(%{k: _v}), do: 1
    def guarded(x) when is_map(x), do: 1

    def unused_fn(p) do
      _f = fn -> p end
      :ok
    end

    def built(a, b), do: %{kept: a, dropped: b}.kept
    def pair(a, b), do: elem({a, b}, 0)

    def tried(a, b, _c) do
      try do
        a
      catch
        _thrown -> b
      end
    end

    def dep(p) do
      SomeDep.call(p)
      :ok
    end

    def returned(a), do: a + 1

    def dotted(m) do
      _ = m.x
      :ok
    end
    def put_read(a, b), do: Map.get(Map.put(%{x: b}, :k, a), :k)
    def update_read(m, a), do: %{m | k: a}.j
    def dyn(mod, x), do: mod.run(x)
    def ap3(mod, x), do: apply(mod, :run, [x])
    def ap2(f, x), do: apply(f, [x])

    def received_t(m) do
      receive do
        {:x, y} -> y + m
      end
    end

    def each(xs, p) do
      Enum.each(xs, fn _x -> IO.puts(p) end)
      :ok
    end

    def guarded_try(a) do
      try do
        _ = hd(a)
        :ok
      rescue
        _error -> :error
      end
    end

    def unguarded(a) do
      _ = hd(a)
      :ok
    end

    def set_fold(s, pid) do
      _ = :sets.fold(fn x, acc -> send(pid, x) && acc end, :ok, s)
      :ok
    end

    def has?(m, k), do: match?(%{^k => _}, m)

    def take(bin, n) do
      <<x::binary-size(n), _rest::binary>> = bin
      x
    end

    def name(%S{name: n}), do: n
    def bin(a, _b), do: <<a::binary>>
    def comprehension(xs, p), do: for(x <- xs, do: x + p)

    def forward(a, b), do: other(a, b)
    defp other(a, _b), do: a
  end
  """

  setup_all do
    graph =
      @source
      |> compile_unloaded("transfer_test.ex")
      |> Enum.map(fn {module, binary} ->
        BeamReader.decode(binary, app: :fixtures, path: "#{module}.beam")
      end)
      |> Builder.build(%{})

    %{graph: graph, cfa: Cfa.analyze(graph, Cfa.default_seed(graph))}
  end

  defp transfer(context, name, arity, mode \\ :sound, summaries \\ %{}) do
    mfa = {F, name, arity}
    core = context.graph |> Graph.function(mfa) |> Map.fetch!(:core) |> Core.label()

    Transfer.function(core, %{
      mfa: mfa,
      mode: mode,
      summaries: summaries,
      cfa: context.cfa,
      effects: []
    })
  end

  defp params(context, name, arity), do: transfer(context, name, arity).params

  describe "function/2" do
    test "f(a, b) -> a: [all, absent] (the function_clause catch-all is no use)", context do
      assert params(context, :first, 2) == [:all, :absent]
    end

    test "f(m) -> m.x: only field x of m", context do
      assert params(context, :field, 1) == [{:used, %{x: :all}}]
    end

    test "f(m) -> {m.x, m.y}: fields x and y", context do
      assert params(context, :fields, 1) == [{:used, %{x: :all, y: :all}}]
    end

    test "elem(t, 1) and Map.get(m, :k) read one field", context do
      assert params(context, :tuple_field, 1) == [{:used, %{1 => :all}}]
      assert params(context, :map_get, 1) == [{:used, %{k: :all}}]
    end

    test "_ = a + 1; :ok: absent (a pure expression whose result is discarded)", context do
      assert params(context, :discarded, 1) == [:absent]
    end

    test "IO.puts(a); :ok: all (an effect)", context do
      assert params(context, :printed, 1) == [:all]
    end

    test "send(self(), a); :ok: all (an escape)", context do
      assert params(context, :sent, 1) == [:all]
    end

    test "if a, do: 1, else: 2: a used, b absent", context do
      assert params(context, :branch, 2) == [:all, :absent]
    end

    test "a clause head %{k: v} uses key k of its parameter, and not k's value", context do
      assert params(context, :head, 1) == [{:used, %{k: :absent}}]
    end

    test "a guard is_map(x) uses x for its shape", context do
      assert params(context, :guarded, 1) == [{:used, %{}}]
    end

    test "a fn that is never used uses nothing it captures", context do
      assert params(context, :unused_fn, 1) == [:absent]
    end

    test "a map built and read: the field read is used, the other absent", context do
      assert params(context, :built, 2) == [:all, :absent]
    end

    test "a tuple built and read: the element read is used, the other absent", context do
      assert params(context, :pair, 2) == [:all, :absent]
    end

    test "try: the body's value and the handler's are used, nothing else", context do
      assert params(context, :tried, 3) == [:all, :all, :absent]
    end
  end

  describe "more Core shapes" do
    test "m.x with its result unused still uses field x (m may be a module: m.x() runs)",
         context do
      assert params(context, :dotted, 1) == [{:used, %{x: :all}}]
    end

    test "a + 1 returned uses a (the positive control of the discarded row)", context do
      assert params(context, :returned, 1) == [:all]
    end

    test "Map.put then Map.get of the put key: the value is used, the base's other field not",
         context do
      assert params(context, :put_read, 2) == [:all, :absent]
    end

    test "a map update read at another key: that key of the map, not the new value", context do
      assert params(context, :update_read, 2) == [{:used, %{j: :all}}, :absent]
    end

    test "a call on a variable module uses everything and names the reason", context do
      result = transfer(context, :dyn, 2)
      assert result.params == [:all, :all]
      assert MapSet.to_list(result.reasons) == [{:dynamic_call, 1}]
    end

    test "apply/3 to a variable module uses everything and names the reason", context do
      result = transfer(context, :ap3, 2)
      assert result.params == [:all, :all]
      assert MapSet.to_list(result.reasons) == [{:dynamic_apply, {:erlang, :apply, 3}}]
    end

    test "apply/2 of an :any function uses the list and names its site", context do
      result = transfer(context, :ap2, 2)
      assert result.params == [:all, :all]
      assert MapSet.to_list(result.reasons) == [{:any_apply, {{F, :ap2, 2}, 0}}]
    end

    test "a receive loop the summaries lack fails closed as an unknown closure", context do
      result = transfer(context, :received_t, 1)
      assert result.params == [:all]
      assert MapSet.to_list(result.reasons) == [{:unknown_closure, {{F, :received_t, 1}, 0}}]
    end

    test "Enum.each with a fn that prints p: both used, precisely", context do
      result = transfer(context, :each, 2)
      assert result.params == [:all, :all]
      assert MapSet.size(result.reasons) == 0
    end

    test "inside try, a pure call whose result is unused uses its argument (it can raise)",
         context do
      assert params(context, :guarded_try, 1) == [:all]
      # Positive control: the same body outside a try.
      assert params(context, :unguarded, 1) == [:absent]
    end

    test "a pure module's call with its result unused still uses a fn argument", context do
      assert params(context, :set_fold, 2) == [:all, :all]
    end

    test "a pinned map key in a pattern is used", context do
      assert params(context, :has?, 2) == [:all, :all]
    end

    test "a bitstring size in a pattern is used", context do
      assert params(context, :take, 2) == [:all, :all]
    end

    test "a struct head reads __struct__ and the named field", context do
      assert params(context, :name, 1) == [{:used, %{__struct__: :all, name: :all}}]
    end

    test "a binary built from a uses a, not b", context do
      assert params(context, :bin, 2) == [:all, :absent]
    end

    test "a comprehension (Enum.map of a fn) uses the list and what the fn captures", context do
      assert params(context, :comprehension, 2) == [:all, :all]
    end
  end

  describe "modes" do
    test "an unknown call uses its arguments and names the reason (sound)", context do
      result = transfer(context, :dep, 1)
      assert result.params == [:all]
      assert MapSet.to_list(result.reasons) == [{:unknown_call, {SomeDep, :call, 1}}]
    end

    test "an unknown call demands nothing in the optimistic mode", context do
      result = transfer(context, :dep, 1, :optimistic)
      assert result.params == [:absent]
      assert MapSet.size(result.reasons) == 0
    end
  end

  describe "callee summaries" do
    test "a local call takes the callee's summary and records the passes", context do
      summaries = %{{F, :other, 2} => [:all, :absent]}
      result = transfer(context, :forward, 2, :sound, summaries)

      assert result.params == [:all, :absent]
      assert result.passes == [[{{F, :other, 2}, 0}], [{{F, :other, 2}, 1}]]
      assert MapSet.to_list(result.callees) == [{F, :other, 2}]
    end

    test "a callee the summaries lack is an unknown call (fail closed)", context do
      result = transfer(context, :forward, 2)
      assert result.params == [:all, :all]
      assert MapSet.to_list(result.reasons) == [{:unknown_call, {F, :other, 2}}]
    end
  end
end
