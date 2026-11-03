defmodule Anchor.Domain.CallMatrixTest do
  # DND-5442: the calls matrix as answers. Pure Domain.
  #
  # Sabotage record: ../../sabotage_records/layering-20261103-dnd_5441_graph_rules_a.md
  use ExUnit.Case, async: true

  alias Anchor.Domain.Architecture
  alias Anchor.Domain.CallMatrix

  defp arch(calls) do
    names = calls |> Map.keys() |> Enum.sort()

    {:ok, arch} =
      Architecture.parse(%{
        "contexts" => %{"depth" => 2},
        "buckets" =>
          Enum.map(names, fn name ->
            %{"name" => name, "role" => "domain", "select" => [%{"pattern" => "#{name}.*"}]}
          end),
        "calls" => calls
      })

    arch
  end

  defp side(bucket, context), do: %{bucket: bucket, context: context}

  describe "allowed?/3" do
    test "an unscoped entry allows the same and another context" do
      a = arch(%{"m" => ["a"], "a" => []})
      assert CallMatrix.allowed?(a, side("m", "X.A"), side("a", "X.A"))
      assert CallMatrix.allowed?(a, side("m", "X.A"), side("a", "X.B"))
      assert CallMatrix.allowed?(a, side("m", nil), side("a", nil))
    end

    test "same_context: equal contexts only; nil never matches" do
      a = arch(%{"a" => ["m:same_context"], "m" => []})
      assert CallMatrix.allowed?(a, side("a", "X.A"), side("m", "X.A"))
      refute CallMatrix.allowed?(a, side("a", "X.A"), side("m", "X.B"))
      refute CallMatrix.allowed?(a, side("a", nil), side("m", nil))
      refute CallMatrix.allowed?(a, side("a", "X.A"), side("m", nil))
    end

    test "other_context: different known contexts only" do
      a = arch(%{"a" => ["m:other_context"], "m" => []})
      assert CallMatrix.allowed?(a, side("a", "X.A"), side("m", "X.B"))
      refute CallMatrix.allowed?(a, side("a", "X.A"), side("m", "X.A"))
      refute CallMatrix.allowed?(a, side("a", nil), side("m", "X.B"))
      refute CallMatrix.allowed?(a, side("a", "X.A"), side("m", nil))
    end

    test "a bucket absent from the row is denied; present, allowed (deny by default)" do
      a = arch(%{"f" => ["m"], "m" => [], "d" => []})
      refute CallMatrix.allowed?(a, side("f", "X.A"), side("d", "X.A"))
      assert CallMatrix.allowed?(a, side("f", "X.A"), side("m", "X.A"))
    end

    test "a bucket with no row may call nothing, not even itself" do
      a = arch(%{"f" => ["m"], "m" => ["m"]})
      no_row = %{a | calls: Map.delete(a.calls, "m")}

      refute CallMatrix.allowed?(no_row, side("m", "X.A"), side("m", "X.A"))
      refute CallMatrix.allowed?(no_row, side("m", "X.A"), side("f", "X.A"))
      # Positive control: with its row, m may call itself.
      assert CallMatrix.allowed?(a, side("m", "X.A"), side("m", "X.A"))
    end
  end

  describe "route/3" do
    test "framework to adapters through managers" do
      a = arch(%{"framework" => ["managers"], "managers" => ["adapters"], "adapters" => []})
      assert CallMatrix.route(a, "framework", "adapters") == ["framework", "managers", "adapters"]
    end

    test "no path is :none" do
      a = arch(%{"framework" => ["managers"], "managers" => [], "adapters" => []})
      assert CallMatrix.route(a, "framework", "adapters") == :none
    end

    test "equal-length routes: the first by row order" do
      a = arch(%{"f" => ["y", "x"], "x" => ["t"], "y" => ["t"], "t" => []})
      assert CallMatrix.route(a, "f", "t") == ["f", "y", "t"]

      b = arch(%{"f" => ["x", "y"], "x" => ["t"], "y" => ["t"], "t" => []})
      assert CallMatrix.route(b, "f", "t") == ["f", "x", "t"]
    end

    test "a scoped entry is an edge for routing" do
      a = arch(%{"a" => ["m:other_context"], "m" => []})
      assert CallMatrix.route(a, "a", "m") == ["a", "m"]
    end

    # Regression: route(a, b, b) answered [b] whatever the row said, and
    # Layering's Fix text crashed on that one-bucket route when b's row omits
    # b (a call between two modules of b is then forbidden).
    test "a bucket to itself is searched like any other pair" do
      a = arch(%{"s" => ["d"], "d" => ["d"], "x" => ["y"], "y" => ["x"]})
      assert CallMatrix.route(a, "s", "s") == :none
      assert CallMatrix.route(a, "x", "x") == ["x", "y", "x"]
      assert CallMatrix.route(a, "d", "d") == ["d", "d"]
    end
  end

  describe "row/2" do
    test "the row as written, scopes included; an empty row calls nothing" do
      a = arch(%{"f" => ["f", "m:same_context"], "m" => []})
      assert CallMatrix.row(a, "f") == "f may call: f, m:same_context"
      assert CallMatrix.row(a, "m") == "m may call nothing"
    end
  end
end
