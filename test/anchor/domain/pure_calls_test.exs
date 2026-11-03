defmodule Anchor.Domain.PureCallsTest do
  # Domain (ADR 002). DND-5498 R4: the pure-call table the demand analysis
  # reads: a pure call's arguments matter only through its result.
  #
  # Sabotage record: ../../sabotage_records/demand-20261103-dnd_5498_demand.md
  use ExUnit.Case, async: true

  alias Anchor.Domain.PureCalls

  test "stdlib value functions and erlang BIFs are pure" do
    for mfa <- [
          {String, :upcase, 1},
          {Map, :merge, 2},
          {:maps, :merge, 2},
          {:erlang, :+, 2},
          {:erlang, :element, 2},
          {:lists, :reverse, 1}
        ] do
      assert PureCalls.pure?(mfa), "#{inspect(mfa)} should be pure"
    end
  end

  test "a function that calls an argument, an effect, or the clock is not pure" do
    for mfa <- [
          {Enum, :map, 2},
          {Map, :update, 4},
          {:erlang, :send, 2},
          {DateTime, :utc_now, 0},
          {Kernel, :inspect, 2},
          {SomeDep, :call, 1}
        ] do
      refute PureCalls.pure?(mfa), "#{inspect(mfa)} should not be pure"
    end
  end

  test "modules/0 is sorted and holds Enum and :lists" do
    modules = PureCalls.modules()
    assert modules == Enum.sort(modules)
    assert Enum in modules and :lists in modules
  end
end
