defmodule Anchor.Domain.Demand.LatticeTest do
  # Domain (ADR 002). QA plan, test/anchor/domain/demand/lattice_test.exs
  # (DND-5498, R1): join, leq?, bound. StreamData is not a dependency, so the
  # algebraic properties run over a fixed table of 20 triples drawn from a
  # fixed sample of demands.
  #
  # Sabotage record: ../../../sabotage_records/demand-20261103-dnd_5498_demand.md
  use ExUnit.Case, async: true

  alias Anchor.Domain.Demand.Lattice

  @samples [
    :absent,
    :all,
    {:used, %{}},
    {:used, %{x: :all}},
    {:used, %{x: :absent}},
    {:used, %{y: :all, x: {:used, %{z: :all}}}},
    {:used, %{0 => :all}},
    {:used, %{1 => :absent, x: {:used, %{}}}}
  ]

  # 20 triples, every sample in each position at least twice.
  @triples for i <- 0..19,
               do:
                 {Enum.at(@samples, rem(i, 8)), Enum.at(@samples, rem(i * 3 + 1, 8)),
                  Enum.at(@samples, rem(i * 5 + 2, 8))}

  # `demand` three levels of fields down, raw (unbounded), so `bound/1` meets
  # it at the cut.
  defp nest(demand), do: {:used, %{a: {:used, %{b: {:used, %{c: demand}}}}}}

  describe "join/2" do
    test "absent is the identity, all absorbs" do
      for x <- @samples do
        assert Lattice.join(:absent, x) == x
        assert Lattice.join(x, :absent) == x
        assert Lattice.join(:all, x) == :all
        assert Lattice.join(x, :all) == :all
      end
    end

    test "two field demands merge their keys, joining a key both hold" do
      assert Lattice.join({:used, %{x: :absent}}, {:used, %{x: :all, y: :absent}}) ==
               {:used, %{x: :all, y: :absent}}

      assert Lattice.join(Lattice.field(:x, :all), Lattice.field(:y, :all)) ==
               {:used, %{x: :all, y: :all}}
    end

    test "commutative, associative and idempotent over 20 triples" do
      assert length(@triples) == 20

      for {a, b, c} <- @triples do
        assert Lattice.join(a, b) == Lattice.join(b, a)
        assert Lattice.join(Lattice.join(a, b), c) == Lattice.join(a, Lattice.join(b, c))
        assert Lattice.join(a, a) == a
      end
    end

    test "leq?(a, join(a, b)) over 20 triples" do
      for {a, b, _c} <- @triples do
        assert Lattice.leq?(a, Lattice.join(a, b))
        assert Lattice.leq?(b, Lattice.join(a, b))
      end
    end
  end

  describe "leq?/2" do
    test "absent < used(fields) < all, and fields compare pointwise" do
      assert Lattice.leq?(:absent, {:used, %{}})
      assert Lattice.leq?({:used, %{x: :all}}, :all)
      refute Lattice.leq?(:all, {:used, %{x: :all}})
      refute Lattice.leq?({:used, %{}}, :absent)
      assert Lattice.leq?({:used, %{x: {:used, %{}}}}, {:used, %{x: :all, y: :all}})
      refute Lattice.leq?({:used, %{x: :all}}, {:used, %{x: {:used, %{}}}})
      refute Lattice.leq?({:used, %{y: :all}}, {:used, %{x: :all}})
    end
  end

  describe "bound/1" do
    test "a 4-deep field demand collapses at depth 3 to all" do
      four = Lattice.field(:a, Lattice.field(:b, Lattice.field(:c, Lattice.field(:d, :all))))
      assert four == Lattice.field(:a, Lattice.field(:b, Lattice.field(:c, :all)))
      assert Lattice.depth() == 3
    end

    test "a 3-deep field demand is kept (positive control)" do
      three = {:used, %{a: {:used, %{b: {:used, %{c: :all}}}}}}
      assert Lattice.bound(three) == three
    end

    test "bound is monotone over 20 triples, nested to the cut" do
      for {a, b, _c} <- @triples, Lattice.leq?(a, b) do
        assert Lattice.leq?(Lattice.bound(nest(a)), Lattice.bound(nest(b)))
      end
    end
  end

  describe "a struct pattern's fields" do
    test "a field map holding :__struct__ is bounded and compared as a map, not a struct" do
      struct_fields = {:used, %{__struct__: :all, name: {:used, %{}}}}
      assert Lattice.bound(struct_fields) == struct_fields
      assert Lattice.leq?(struct_fields, Lattice.join(struct_fields, {:used, %{age: :all}}))
    end
  end

  describe "at/2" do
    test "the demand on a field: absent of absent, all of all, the key of used" do
      assert Lattice.at(:absent, :x) == :absent
      assert Lattice.at(:all, :x) == :all
      assert Lattice.at({:used, %{x: {:used, %{}}}}, :x) == {:used, %{}}
      assert Lattice.at({:used, %{x: :all}}, :y) == :absent
    end
  end
end
