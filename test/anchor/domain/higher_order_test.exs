defmodule Anchor.Domain.HigherOrderTest do
  # Domain (ADR 002). QA plan, test/anchor/domain/higher_order_test.exs
  # (DND-5497, R4): which argument each library function invokes, and with
  # what arity.
  #
  # Sabotage record: ../../sabotage_records/cfa-20261103-dnd_5497_zero_cfa.md
  use ExUnit.Case, async: true

  alias Anchor.Domain.HigherOrder

  describe "invocations/1" do
    test "Enum.map/2 invokes argument 1 with arity 1" do
      assert HigherOrder.invocations({Enum, :map, 2}) == [{1, 1}]
    end

    test "Enum.reduce/3 invokes argument 2 with arity 2" do
      assert HigherOrder.invocations({Enum, :reduce, 3}) == [{2, 2}]
    end

    test "a function invoking two arguments lists both, in argument order" do
      assert HigherOrder.invocations({Enum, :group_by, 3}) == [{1, 1}, {2, 1}]
    end

    test "Erlang's :lists.map/2 invokes argument 0" do
      assert HigherOrder.invocations({:lists, :map, 2}) == [{0, 1}]
    end

    test "an unknown function, and a known name at another arity, give []" do
      assert HigherOrder.invocations({String, :upcase, 1}) == []
      assert HigherOrder.invocations({Enum, :map, 3}) == []
    end

    test "every entry names an argument the function has, once, in ascending order" do
      for {_m, _f, arity} = mfa <- HigherOrder.functions() do
        indexes = mfa |> HigherOrder.invocations() |> Enum.map(&elem(&1, 0))

        assert indexes != [], "#{inspect(mfa)} invokes nothing"
        assert indexes == Enum.sort(Enum.uniq(indexes)), "#{inspect(mfa)}: #{inspect(indexes)}"
        assert Enum.all?(indexes, &(&1 < arity)), "#{inspect(mfa)}: #{inspect(indexes)}"
      end
    end

    test "every entry names a function the runtime exports" do
      for {m, f, a} = mfa <- HigherOrder.functions() do
        assert {f, a} in m.module_info(:exports), "#{inspect(mfa)} is not exported"
      end
    end
  end
end
