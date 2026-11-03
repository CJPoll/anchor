defmodule Anchor.Domain.Sabotage.FirstHitTest do
  # DND-5652: which of a function's call messages the coverage tracer keeps,
  # which it drops, and when it silences the function for the rest of a
  # window. Stamps are plain integers here: only their order matters.
  # Sabotage record: ../../../sabotage_records/sabotage-20261103-dnd_5652_first_hit_gate.md
  use ExUnit.Case, async: true

  alias Anchor.Domain.Sabotage.FirstHit

  @f {A, :f, 1}
  @g {B, :g, 0}

  # Boundaries at stamps 10, 20, 30 open windows 1, 2, 3.
  defp opened do
    FirstHit.new()
    |> FirstHit.boundary(1, 10)
    |> FirstHit.boundary(2, 20)
    |> FirstHit.boundary(3, 30)
  end

  # `n` messages of `mfa` from `window`, each stamped `stamp`: the decisions in
  # order and the state after them.
  defp feed(state, mfa, window, stamp, n) do
    Enum.map_reduce(1..n, state, fn _i, acc -> FirstHit.decide(acc, mfa, window, stamp) end)
  end

  defp t, do: FirstHit.threshold()

  test "F1: the threshold's message is forwarded and silences; the ones before it only forward" do
    {before, state} = feed(opened(), @f, 3, 31, t() - 1)
    assert Enum.uniq(before) == [:forward]
    assert {:silence, state} = FirstHit.decide(state, @f, 3, 31)
    assert state.silenced == %{@f => 3}
    assert state.counts == %{}
  end

  test "F2: a message from the window the function was silenced for is dropped (it was in flight)" do
    {_forwarded, state} = feed(opened(), @f, 3, 31, t())
    assert {:drop, ^state} = FirstHit.decide(state, @f, 3, 32)
  end

  test "F3: the next window forwards again, counts again, and silences again" do
    {_decisions, state} = feed(opened(), @f, 2, 21, t())
    assert {:forward, state} = FirstHit.decide(state, @f, 3, 31)
    {_decisions, state} = feed(state, @f, 3, 31, t() - 2)
    assert {:silence, state} = FirstHit.decide(state, @f, 3, 31)
    assert state.silenced == %{@f => 3}
  end

  test "F4: a late message from an earlier window is forwarded, never dropped, and never moves the silence back" do
    {_decisions, state} = feed(opened(), @f, 3, 31, t())
    assert {:forward, ^state} = FirstHit.decide(state, @f, 2, 21)
  end

  test "F5: each function is counted on its own" do
    {_decisions, state} = feed(opened(), @f, 3, 31, t() - 1)
    {_decisions, state} = feed(state, @g, 3, 31, t() - 1)
    assert state.silenced == %{}
    assert {:silence, state} = FirstHit.decide(state, @f, 3, 31)
    assert state.silenced == %{@f => 3}
  end

  test "F6: a message that read the new word but is stamped before the boundary is forwarded and never counted" do
    {decisions, state} = feed(opened(), @f, 3, 29, t() * 3)
    assert Enum.uniq(decisions) == [:forward]
    assert state.counts == %{}
    assert state.silenced == %{}
  end

  test "F7: a message from a window whose boundary has not been seen yet is forwarded and never counted" do
    {decisions, state} = feed(opened(), @f, 4, 41, t() * 3)
    assert Enum.uniq(decisions) == [:forward]
    assert state.counts == %{}
  end

  test "F8: window 0, before any boundary, has no lower edge" do
    {_decisions, state} = feed(FirstHit.new(), @f, 0, 1, t() - 1)
    assert {:silence, _state} = FirstHit.decide(state, @f, 0, 1)
  end

  test "F9: a boundary that arrives with an earlier stamp than the one before it keeps the later edge" do
    # Two runner processes' boundary messages can reach the gate swapped.
    state = FirstHit.new() |> FirstHit.boundary(1, 20) |> FirstHit.boundary(2, 10)
    assert {:forward, ^state} = FirstHit.decide(state, @f, 2, 15)
    assert state.boundaries == %{1 => 20, 2 => 20}
  end

  test "F10: messages counted in one window do not carry into the next" do
    {_decisions, state} = feed(opened(), @f, 2, 21, t() - 1)
    {decisions, _state} = feed(state, @f, 3, 31, t() - 1)
    assert Enum.uniq(decisions) == [:forward]
  end
end
