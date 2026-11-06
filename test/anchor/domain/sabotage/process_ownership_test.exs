defmodule Anchor.Domain.Sabotage.ProcessOwnershipTest do
  # DND-5691: who owns a process, from spawn events alone, resolved once the run
  # is over. Pids are made here and never run: they are only names.
  # Sabotage record: ../../../sabotage_records/coverage_attribution-20261106-dnd_5691_causal_attribution.md
  use ExUnit.Case, async: true

  alias Anchor.Domain.Sabotage.ProcessOwnership

  defp pids(n), do: for(_i <- 1..n, do: spawn(fn -> :ok end))

  describe "edge/3" do
    setup do
      [child, parent, t] = pids(3)
      %{child: child, parent: parent, t: t}
    end

    test "1: a plain spawn has no via", %{child: child, parent: parent} do
      assert ProcessOwnership.edge(child, parent, {M, :f, []}) == {child, parent, nil}
    end

    test "2: noreply names the owner pid", %{child: child, parent: parent, t: t} do
      mfa = {Task.Supervised, :noreply, [{node(), :name, t}, [], [t], {M, :f, []}]}
      assert ProcessOwnership.edge(child, parent, mfa) == {child, parent, t}
    end

    test "3: reply names the owner pid", %{child: child, parent: parent, t: t} do
      mfa = {Task.Supervised, :reply, [{node(), :name, t}, [], :monitor]}
      assert ProcessOwnership.edge(child, parent, mfa) == {child, parent, t}
    end

    test "4: any other Task.Supervised shape is refused", %{child: child, parent: parent, t: t} do
      for mfa <- [
            {Task.Supervised, :noreply, [:x]},
            {Task.Supervised, :reply, [{node(), :name, :not_a_pid}, [], :monitor]},
            {Task.Supervised, :noreply, [{node(), :name, t}, [], [t]]},
            {Task.Supervised, :stream, [{node(), :name, t}, [], :monitor]}
          ] do
        assert ProcessOwnership.edge(child, parent, mfa) == {:error, {:task_shape, mfa}}
      end
    end
  end

  describe "owners/2" do
    @n {:test, 3}

    test "1: what the runner spawned in a window, and what that spawned, is that test's" do
      [t, a] = pids(2)
      roots = %{t => @n}
      assert ProcessOwnership.owners(roots, [{a, t, nil}]) == %{t => @n, a => @n}
    end

    test "2: the on_exit runner, spawned by the runner in the window, is a root too" do
      [t, e] = pids(2)
      assert ProcessOwnership.owners(%{t => @n, e => @n}, []) == %{t => @n, e => @n}
    end

    test "3: a grandchild stays owned after its parent has died" do
      [t, a, b] = pids(3)
      owners = ProcessOwnership.owners(%{t => @n}, [{a, t, nil}, {b, a, nil}])
      assert owners[b] == @n
    end

    test "4: a process the runner spawned outside any window belongs to the module" do
      [s, a] = pids(2)
      owners = ProcessOwnership.owners(%{s => {:module, M}}, [{a, s, nil}])
      assert owners == %{s => {:module, M}, a => {:module, M}}
    end

    test "5: a Task under a supervisor is owned through its via" do
      [t, sup, k] = pids(3)
      owners = ProcessOwnership.owners(%{t => @n}, [{k, sup, t}])
      assert owners[k] == @n
      refute is_map_key(owners, sup)
    end

    test "6: a process with no owned parent and no owned via has no owner" do
      [t, app_sup, w] = pids(3)
      refute is_map_key(ProcessOwnership.owners(%{t => @n}, [{w, app_sup, nil}]), w)
    end

    test "7: a compiler process has no owner, whichever compiler spawned it" do
      [t, compiler, c, d] = pids(4)
      owners = ProcessOwnership.owners(%{t => @n}, [{c, compiler, nil}, {d, c, nil}])
      assert owners == %{t => @n}
    end

    test "8: the result does not depend on edge order" do
      [t, a, b, sup, k] = pids(5)
      edges = [{a, t, nil}, {b, a, nil}, {k, sup, b}]
      roots = %{t => @n}

      results =
        for order <- [edges, Enum.reverse(edges), [{k, sup, b}, {a, t, nil}, {b, a, nil}]],
            do: ProcessOwnership.owners(roots, order)

      assert [first, first, first] = results
      assert first == %{t => @n, a => @n, b => @n, k => @n}
    end

    test "9: an owned via wins over an owned parent" do
      [t, sup, k] = pids(3)
      s = hd(pids(1))
      roots = %{t => @n, s => {:module, M}}
      owners = ProcessOwnership.owners(roots, [{sup, s, nil}, {k, sup, t}])
      assert owners[sup] == {:module, M}
      assert owners[k] == @n
    end

    test "10: an unowned via falls back to the parent" do
      [t, a, server, k] = pids(4)
      owners = ProcessOwnership.owners(%{t => @n}, [{a, t, nil}, {k, a, server}])
      assert owners[k] == @n
    end

    test "11: an unowned via and an unowned parent give no owner" do
      [t, server, app_sup, k] = pids(4)
      refute is_map_key(ProcessOwnership.owners(%{t => @n}, [{k, app_sup, server}]), k)
    end

    test "a root is never overridden by an edge that also names it" do
      [t, other, x] = pids(3)

      owners =
        ProcessOwnership.owners(%{t => @n, x => {:test, 5}}, [{x, t, nil}, {other, x, nil}])

      assert owners[x] == {:test, 5}
      assert owners[other] == {:test, 5}
    end

    test "a cycle (a reused pid) ends, unowned, instead of looping" do
      [a, b] = pids(2)
      assert ProcessOwnership.owners(%{}, [{a, b, nil}, {b, a, nil}]) == %{}
    end
  end
end
