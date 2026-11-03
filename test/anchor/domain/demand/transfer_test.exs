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
  defmodule AnchorFixtures.TransferTest.F do
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

    def dep(p) do
      SomeDep.call(p)
      :ok
    end

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
