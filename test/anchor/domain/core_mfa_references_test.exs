defmodule Anchor.Domain.CoreMfaReferencesTest do
  # Domain (ADR 002). DND-5470: Core.mfa_references/1 over Core of a fixture
  # compiled in the test (read the way BeamReader reads it).
  #
  # Sabotage record: ../../sabotage_records/parameter_reaches_sink-20261106-dnd_5470_param_sink_locality.md
  # partial_mfa_calls/1 (DND-5448): ../../sabotage_records/placement-20261106-dnd_5448_placement_core.md
  use ExUnit.Case, async: true

  import Anchor.Test.BeamFixtures

  alias Anchor.Domain.Core

  defp core(binary, name_arity), do: core_fun!(binary, name_arity)

  @mfas """
  defmodule AnchorFixtures.CoreTest.Mfas do
    def tuple(x), do: {M, :f, [x]}
    def tuple_two(x, y), do: {M, :f, [x, y]}
    def in_map(x), do: %{id: x, start: {M, :f, [x]}}
    def literal, do: {M, :f, [:a, :b]}
    def nested_literal, do: {:wrap, {M, :f, [:a]}}
    def literal_map, do: %{start: {M, :f, [:a]}}
    def tuple_in_map, do: %{start: {:wrap, {M, :f, [:a]}}}
    def list_in_map, do: %{starts: [:x, {M, :f, [:a]}]}
    def literal_list, do: [:x, {M, :g, []}, {M, :f, [:a]}]
    def spawned(x), do: spawn(M, :f, [x])
    def args_var(args), do: spawn(M, :f, args)
    def tuple_var(args), do: {M, :f, args}
    def later_args(x), do: Task.start_link(M, :f, [x])
    def improper(x, y), do: {M, :f, [x | y]}
    def literal_improper, do: {M, :f, [:a | :b]}
    def spawn_improper(x, y), do: spawn(M, :f, [x | y])
    def local(x), do: run(M, :f, [x])
    def both_computed(mod, name, x), do: {mod, name, [x]}
    def applied_literal_name(args), do: apply(M, :f, args)
    def message_call(timeout), do: GenServer.call(M, :f, timeout)
    def timeout_arg, do: GenServer.call(M, :f, 5000)
    def applied_name(name, x), do: apply(M, name, [x])
    def applied_any(name, args), do: apply(M, name, args)
    def applied_computed(mod, name, x), do: apply(mod, name, [x])
    def generic_call(msg, timeout), do: GenServer.call(M, msg, timeout)
    def local_vars(a, b), do: run(M, a, b)
    def tuple_vars(a, b), do: {M, a, b}
    def atom_key(acc, x), do: Map.put(acc, :f, [x])
    def spawn_var_module(mod, x), do: spawn(mod, :f, [x])
    defp run(m, f, a), do: apply(m, f, a)
    def a_number, do: {M, :f, 3}
    def number_beside(mod), do: {mod, :f, 3}
    def computed(mod, x), do: {mod, :f, [x]}
    def computed_name(name, x), do: {M, name, [x]}
    def strings(x), do: {"M", "f", [x]}
    def none(x), do: {:ok, x}
  end
  """

  setup_all do
    [{_module, binary}] = compile_unloaded(@mfas)
    %{binary: binary}
  end

  for {function, arity, expected} <- [
        {:tuple, 1, [{M, :f, 1}]},
        {:tuple_two, 2, [{M, :f, 2}]},
        {:in_map, 1, [{M, :f, 1}]},
        {:literal, 0, [{M, :f, 2}]},
        {:nested_literal, 0, [{M, :f, 1}]},
        {:literal_map, 0, [{M, :f, 1}]},
        {:tuple_in_map, 0, [{M, :f, 1}]},
        {:list_in_map, 0, [{M, :f, 1}]},
        {:literal_list, 0, [{M, :f, 1}, {M, :g, 0}]},
        {:spawned, 1, [{M, :f, 1}]},
        {:args_var, 1, []},
        {:tuple_var, 1, []},
        {:later_args, 1, [{M, :f, 1}]},
        {:a_number, 0, []},
        {:number_beside, 1, []},
        {:computed, 2, []},
        {:computed_name, 2, []},
        {:applied_literal_name, 1, []},
        {:timeout_arg, 0, []},
        {:message_call, 1, []},
        {:applied_name, 2, []},
        {:applied_any, 2, []},
        {:applied_computed, 3, []},
        {:generic_call, 2, []},
        {:local_vars, 2, []},
        {:tuple_vars, 2, []},
        {:atom_key, 2, []},
        {:spawn_var_module, 2, []},
        {:both_computed, 3, []},
        {:improper, 2, []},
        {:literal_improper, 0, []},
        {:spawn_improper, 2, []},
        {:local, 1, [{M, :f, 1}]},
        {:strings, 1, []},
        {:none, 1, []}
      ] do
    test "#{function}/#{arity}", %{binary: binary} do
      references =
        binary
        |> core({unquote(function), unquote(arity)})
        |> Core.mfa_references()
        # The compiler's own `{:function_clause, x, y}` has the shape, and no module.
        |> Enum.reject(&(elem(&1, 0) == :function_clause))

      assert Enum.sort(references) == unquote(Macro.escape(expected))
    end
  end

  # DND-5448.
  @partial """
  defmodule AnchorFixtures.CoreTest.Partial do
    def computed(mod, name, args), do: spawn(mod, name, args)
    def known_name(mod, args), do: Task.start(mod, :f, args)
    def literal_args_var(args), do: spawn_link(M, :f, args)
    def supervised(sup, name, args), do: Task.Supervisor.start_child(sup, M, name, args)
    def later(name, args), do: :timer.apply_after(10, M, name, args)
    def row_spawn(n, a), do: :erlang.spawn(M, n, a)
    def row_spawn_monitor(n, a), do: :erlang.spawn_monitor(M, n, a)
    def row_spawn4(n, a), do: :erlang.spawn(:node, M, n, a)
    def row_spawn_link4(n, a), do: :erlang.spawn_link(:node, M, n, a)
    def row_spawn_monitor4(n, a), do: :erlang.spawn_monitor(:node, M, n, a)
    def row_spawn_opt4(n, a), do: :erlang.spawn_opt(M, n, a, [])
    def row_spawn_opt5(n, a), do: :erlang.spawn_opt(:node, M, n, a, [])
    def row_erpc_call4(n, a), do: :erpc.call(:node, M, n, a)
    def row_erpc_call5(n, a), do: :erpc.call(:node, M, n, a, 10)
    def row_erpc_cast(n, a), do: :erpc.cast(:node, M, n, a)
    def row_proc_spawn(n, a), do: :proc_lib.spawn(M, n, a)
    def row_proc_spawn4(n, a), do: :proc_lib.spawn(:node, M, n, a)
    def row_proc_link(n, a), do: :proc_lib.spawn_link(M, n, a)
    def row_proc_link4(n, a), do: :proc_lib.spawn_link(:node, M, n, a)
    def row_proc_start(n, a), do: :proc_lib.start(M, n, a)
    def row_proc_start_link(n, a), do: :proc_lib.start_link(M, n, a)
    def row_rpc_call(n, a), do: :rpc.call(:node, M, n, a)
    def row_rpc_cast(n, a), do: :rpc.cast(:node, M, n, a)
    def row_interval(n, a), do: :timer.apply_interval(10, M, n, a)
    def row_task_async(n, a), do: Task.async(M, n, a)
    def row_task_link(n, a), do: Task.start_link(M, n, a)
    def row_sup_async(n, a), do: Task.Supervisor.async(:s, M, n, a)
    def row_sup_async5(n, a), do: Task.Supervisor.async(:s, M, n, a, [])
    def row_sup_nolink(n, a), do: Task.Supervisor.async_nolink(:s, M, n, a)
    def row_sup_nolink5(n, a), do: Task.Supervisor.async_nolink(:s, M, n, a, [])
    def row_sup_start5(n, a), do: Task.Supervisor.start_child(:s, M, n, a, [])
    def children, do: [Bare, {Tupled, [:x]}, %{key: Mapped}]
    def children_var(x), do: [Bare, {Tupled, x}]
    def called(x), do: Called.f(x)
    def whole(x), do: spawn(M, :f, [x])
    def other(a, b, c), do: {a, b, c}
  end
  """

  setup_all do
    [{_module, binary}] = compile_all_unloaded([{@partial, "lib/partial.ex"}])
    %{partial: binary}
  end

  describe "partial_mfa_calls/1" do
    for {name, arity, expected} <- [
          {:computed, 3, {nil, nil}},
          {:known_name, 2, {nil, :f}},
          {:literal_args_var, 1, {M, :f}},
          {:supervised, 3, {M, nil}},
          {:later, 2, {M, nil}}
        ] do
      test "#{name}/#{arity} reads as #{inspect(expected)}", %{partial: binary} do
        {module, name} = unquote(Macro.escape(expected))

        assert [%{module: ^module, name: ^name, line: line}] =
                 binary |> core({unquote(name), unquote(arity)}) |> Core.partial_mfa_calls()

        assert is_integer(line)
      end
    end

    for row <- ~w(row_spawn row_spawn_monitor row_spawn4 row_spawn_link4 row_spawn_monitor4
                  row_spawn_opt4 row_spawn_opt5 row_erpc_call4 row_erpc_call5 row_erpc_cast
                  row_proc_spawn row_proc_spawn4 row_proc_link row_proc_link4 row_proc_start
                  row_proc_start_link row_rpc_call row_rpc_cast row_interval row_task_async
                  row_task_link row_sup_async row_sup_async5 row_sup_nolink row_sup_nolink5
                  row_sup_start5)a do
      test "the table's row #{row} reads its module, and a computed name", %{partial: binary} do
        assert [%{module: M, name: nil}] =
                 binary |> core({unquote(row), 2}) |> Core.partial_mfa_calls()
      end
    end

    test "a whole triple is mfa_references/1's, and nothing else is read", %{partial: binary} do
      assert binary |> core({:whole, 1}) |> Core.partial_mfa_calls() == []
      assert binary |> core({:other, 3}) |> Core.partial_mfa_calls() == []
    end
  end

  # DND-5448.
  describe "held_atoms/1" do
    test "reads a literal of any depth", %{partial: binary} do
      held = binary |> core({:children, 0}) |> Core.held_atoms()

      for atom <- [Bare, Tupled, Mapped, :x, :key], do: assert(atom in held, inspect(atom))
    end

    test "reads a literal beside a variable", %{partial: binary} do
      held = binary |> core({:children_var, 1}) |> Core.held_atoms()

      assert Bare in held
      assert Tupled in held
    end

    test "the module a call is made on is not held", %{partial: binary} do
      refute Called in (binary |> core({:called, 1}) |> Core.held_atoms())
    end
  end
end
