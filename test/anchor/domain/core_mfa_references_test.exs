defmodule Anchor.Domain.CoreMfaReferencesTest do
  # Domain (ADR 002). DND-5470: Core.mfa_references/1 over Core of a fixture
  # compiled in the test (read the way BeamReader reads it).
  #
  # Sabotage record: ../../sabotage_records/parameter_reaches_sink-20261106-dnd_5470_param_sink_locality.md
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
    def a_number, do: {M, :f, 3}
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
        {:args_var, 1, [{M, :f, nil}]},
        {:tuple_var, 1, [{M, :f, nil}]},
        {:later_args, 1, [{M, :f, 1}]},
        {:a_number, 0, []},
        {:computed, 2, []},
        {:computed_name, 2, []},
        {:strings, 1, []},
        {:none, 1, []}
      ] do
    test "#{function}/#{arity}", %{binary: binary} do
      references = binary |> core({unquote(function), unquote(arity)}) |> Core.mfa_references()

      assert Enum.sort(references) == unquote(Macro.escape(expected))
    end
  end

  test "a list of unknown length is no reference, and each reference is listed once", %{
    binary: binary
  } do
    assert binary |> core({:improper, 2}) |> Core.mfa_references() == []
  end
end
