defmodule Anchor.Adapters.EctoTransactionProbeTest do
  # DND-5480: the transaction-boundary signal DND-5479 found, fed the
  # statements its recorded event sequences classify to. Each test runs in its
  # own process, so the probe's per-process state starts empty.
  #
  # Sabotage record: ../../sabotage_records/backstop-20261106-dnd_5480_test_backstop.md
  use ExUnit.Case, async: true

  alias Anchor.Adapters.EctoTransactionProbe, as: Probe
  alias Anchor.Domain.Aggregates.QueryStatement
  alias Anchor.Test.BackstopMetadata, as: Meta

  defp observe(metadata), do: metadata |> QueryStatement.classify() |> Probe.observe()

  test "P1: every write of one transaction gets the same ref, the one begin opened" do
    assert {:in_tx, ref} = observe(Meta.begin())
    assert observe(Meta.insert("orders")) == {:in_tx, ref}
    assert observe(Meta.update("invoices")) == {:in_tx, ref}
    assert observe(Meta.commit()) == :no_tx
  end

  test "P2: a write with no begin before it is outside any transaction" do
    assert observe(Meta.insert("orders")) == :no_tx
  end

  test "P2: a write after commit or rollback is outside any transaction" do
    observe(Meta.begin())
    observe(Meta.commit())
    assert observe(Meta.insert("orders")) == :no_tx

    observe(Meta.begin())
    observe(Meta.rollback())
    assert observe(Meta.delete("orders")) == :no_tx
  end

  test "P3: two sequential transactions get two different refs" do
    {:in_tx, first} = observe(Meta.begin())
    observe(Meta.commit())
    {:in_tx, second} = observe(Meta.begin())

    assert first != second
    assert observe(Meta.insert("orders")) == {:in_tx, second}
  end

  test "a savepoint inside a transaction leaves it open" do
    {:in_tx, ref} = observe(Meta.begin())
    assert Probe.observe(:savepoint) == {:in_tx, ref}
    assert observe(Meta.insert("orders")) == {:in_tx, ref}
  end

  test "the open transaction is the emitting process's own" do
    {:in_tx, _ref} = observe(Meta.begin())
    parent = self()

    task = Task.async(fn -> send(parent, {:other, observe(Meta.insert("orders"))}) end)
    Task.await(task)

    assert_received {:other, :no_tx}
  end
end
