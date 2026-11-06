defmodule Anchor.Domain.Aggregates.MultiRootsTest do
  # DND-5884: which parameters a helper's returned Multi is built on, and the
  # transaction gap that follows from it.
  #
  # Sabotage record: ../../../sabotage_records/aggregates-20261106-dnd_5889_default_deny_walker.md
  use ExUnit.Case, async: true

  import Anchor.Test.WriteFixtures

  alias Anchor.Domain.Aggregates.Analysis
  alias Anchor.Domain.Aggregates.Config
  alias Anchor.Domain.Aggregates.MultiRoots
  alias Anchor.Domain.Aggregates.Scope

  @ns AnchorFixtures.MultiRootsTest
  @s Module.concat(@ns, S)
  @repo Module.concat(@ns, Repo)
  @h Module.concat(@ns, H)
  @d Module.concat(@ns, D)
  # No module of this name exists: a dependency, as Anchor sees one.
  @lib Module.concat(@ns, Lib)

  @source """
  defmodule #{inspect(@h)} do
    alias Ecto.Multi
    alias #{inspect(@lib)}
    alias #{inspect(@s)}

    def hides(m, attrs) do
      _own = Multi.new()
      Multi.insert(m, {:a, attrs}, %S{})
    end

    def own(attrs), do: Multi.insert(Multi.new(), {:a, attrs}, %S{})
    def step_on(m, attrs), do: Multi.insert(m, {:a, attrs}, %S{})
    def through(m), do: step_on(m, :x)
    def pick_second(_a, b), do: b
    def both(a, b), do: Multi.prepend(a, b)
    def local(m), do: inner(m)
    defp inner(m), do: Multi.put(m, :k, 1)
    def branch(m, f), do: if(f, do: m, else: Multi.new())
    def raises(m, f), do: if(f, do: m, else: raise("no"))
    def throws(m, f), do: if(f, do: m, else: throw(:no))

    def bound(m) do
      n = Multi.put(m, :k, 1)
      n = Multi.put(n, :j, 2)
      n
    end

    def seq(m, attrs) do
      Multi.new() |> Multi.put(:k, attrs)
      m
    end

    def tried(m) do
      try do
        m
      rescue
        _e -> Multi.new()
      end
    end

    def tried_handler(m) do
      try do
        Multi.new()
      rescue
        _e -> m
      end
    end

    def try_else(m) do
      try do
        m
      rescue
        _e -> Multi.new()
      else
        got -> got
      end
    end

    def destructured(m) do
      {a, _b} = {m, 1}
      a
    end

    def matched({:ok, m}), do: m
    def aliased(%Multi{} = m), do: m
    def computed(mod, m), do: mod.put(m, :k, 1)
    def swapped(a, b), do: pick_second(b, a)
    def tagged(m), do: {:ok, m}
    def from_lib, do: Lib.make()
    def called_fn(f), do: f.()
    def loops(m, n), do: if(n == 0, do: m, else: loops(Multi.put(m, :k, n), n - 1))
    def ping(m, n), do: if(n == 0, do: m, else: pong(m, n - 1))
    def pong(m, n), do: ping(m, n)
    def literal_multi, do: %Multi{}
  end

  defmodule #{inspect(@d)} do
    alias Ecto.Multi
    alias #{inspect(@h)}
    alias #{inspect(@repo)}

    def row12(unknown, attrs), do: Repo.transaction(H.hides(unknown, attrs))
    def row12_positive(attrs), do: Repo.transaction(H.hides(Multi.new(), attrs))
    def piped(attrs), do: Multi.new() |> H.step_on(attrs) |> Repo.transaction()
    def own(attrs), do: Repo.transaction(H.own(attrs))
    def second_unknown(unknown), do: Repo.transaction(H.pick_second(Multi.new(), unknown))
    def first_unknown(unknown), do: Repo.transaction(H.pick_second(unknown, Multi.new()))
    def literal_root, do: Repo.transaction(H.pick_second(Multi.new(), nil))
    def through(unknown), do: Repo.transaction(H.through(unknown))
    def through_traced, do: Repo.transaction(H.through(Multi.new()))
    def lib, do: Repo.transaction(H.from_lib())
    def loops(unknown), do: Repo.transaction(H.loops(unknown, 3))
    def branch(unknown, f), do: Repo.transaction(H.branch(unknown, f))
    def raises(f), do: Repo.transaction(H.raises(Multi.new(), f))
    def raises_unknown(unknown, f), do: Repo.transaction(H.raises(unknown, f))
    def local(unknown), do: Repo.transaction(H.local(unknown))
  end
  """

  setup_all do
    graph = graph!(schema(@s, "s") <> repo(@repo) <> @source)

    %{
      graph: graph,
      analysis: Analysis.build(graph, %Config{repos: [@repo]})
    }
  end

  defp roots(graph, name, arity), do: MultiRoots.of(graph, {@h, name, arity})

  defp set(positions), do: MapSet.new(positions)

  defp one(analysis, name) do
    [scope] = Enum.filter(analysis.scopes, &(elem(&1.mfa, 1) == name))
    scope
  end

  # The gaps of the transaction's own function: a helper's body has its own.
  defp own_gaps(scope), do: for({:dynamic_call, {@d, _, _}, _} = gap <- scope.gaps, do: gap)

  describe "of/2: what the helper returns" do
    test "a helper that also makes its own Multi has the root it returns", %{graph: g} do
      assert roots(g, :hides, 2) == set([1])
    end

    test "a helper that returns only its own Multi has none", %{graph: g} do
      assert roots(g, :own, 1) == set([])
      assert roots(g, :literal_multi, 0) == set([])
    end

    test "a step keeps its Multi's root; a data argument is no root", %{graph: g} do
      assert roots(g, :step_on, 2) == set([1])
      assert roots(g, :bound, 1) == set([1])
      assert roots(g, :aliased, 1) == set([1])
    end

    test "only the returned parameter is a root", %{graph: g} do
      assert roots(g, :pick_second, 2) == set([2])
      assert roots(g, :seq, 2) == set([1])
    end

    test "prepend and append root on both sides", %{graph: g} do
      assert roots(g, :both, 2) == set([1, 2])
    end

    test "a project call maps the callee's roots through its arguments", %{graph: g} do
      assert roots(g, :through, 1) == set([1])
      assert roots(g, :local, 1) == set([1])
      assert roots(g, :swapped, 2) == set([1])
    end

    test "every branch counts; what does not return does not", %{graph: g} do
      assert roots(g, :branch, 2) == set([1])
      assert roots(g, :raises, 2) == set([1])
      assert roots(g, :throws, 2) == set([1])
    end

    test "a try counts its body and its handler", %{graph: g} do
      assert roots(g, :tried, 1) == set([1])
      assert roots(g, :tried_handler, 1) == set([1])
      assert roots(g, :try_else, 1) == set([1])
    end

    test "a value it cannot follow is unknown", %{graph: g} do
      assert roots(g, :destructured, 1) == :unknown
      assert roots(g, :matched, 1) == :unknown
      assert roots(g, :computed, 2) == :unknown
      assert roots(g, :tagged, 1) == :unknown
      assert roots(g, :from_lib, 0) == :unknown
      assert roots(g, :called_fn, 1) == :unknown
    end

    test "a recursive helper is unknown, direct or through another", %{graph: g} do
      assert roots(g, :loops, 2) == :unknown
      assert roots(g, :ping, 2) == :unknown
    end

    test "a function Anchor has no code for is unknown", %{graph: g} do
      assert MultiRoots.of(g, {@lib, :make, 0}) == :unknown
      assert MultiRoots.of(g, {@h, :no_such_function, 0}) == :unknown
    end
  end

  describe "a transaction given a helper's Multi" do
    test "row 12: an untraced Multi handed to a helper that also makes one is a gap", %{
      analysis: a
    } do
      assert %Scope{no_gap_noticed?: false} = scope = one(a, :row12)
      assert [_gap] = own_gaps(scope)
    end

    test "row 12, positive: the same helper given a traced Multi is no gap", %{analysis: a} do
      assert %Scope{no_gap_noticed?: true, gaps: []} = one(a, :row12_positive)
    end

    test "a traced Multi piped in, beside untraced data, is no gap", %{analysis: a} do
      assert %Scope{no_gap_noticed?: true, gaps: []} = one(a, :piped)
    end

    test "a helper making its own Multi from data is no gap", %{analysis: a} do
      assert %Scope{no_gap_noticed?: true, gaps: []} = one(a, :own)
    end

    test "a traced argument beside an untraced root does not hide it", %{analysis: a} do
      assert [_gap] = a |> one(:second_unknown) |> own_gaps()
    end

    test "an untraced argument that is no root is no gap", %{analysis: a} do
      assert %Scope{no_gap_noticed?: true, gaps: []} = one(a, :first_unknown)
    end

    test "a literal at a root is no gap", %{analysis: a} do
      assert %Scope{no_gap_noticed?: true, gaps: []} = one(a, :literal_root)
    end

    test "through another helper the root is still a gap; traced, it is not", %{analysis: a} do
      assert [_what] = a |> one(:through) |> own_gaps()
      assert %Scope{no_gap_noticed?: true, gaps: []} = one(a, :through_traced)
    end

    test "a helper whose return Anchor cannot follow is a gap", %{analysis: a} do
      assert [_gap] = a |> one(:loops) |> own_gaps()
      assert [_gap] = a |> one(:lib) |> own_gaps()
    end

    test "a branch's untraced root is a gap; a raise beside a traced one is not", %{analysis: a} do
      assert [_what] = a |> one(:branch) |> own_gaps()
      assert [_what] = a |> one(:raises_unknown) |> own_gaps()
      assert %Scope{no_gap_noticed?: true, gaps: []} = one(a, :raises)
    end

    test "a private helper behind a public one is followed", %{analysis: a} do
      assert [_what] = a |> one(:local) |> own_gaps()
    end
  end
end
