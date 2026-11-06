defmodule Anchor.Domain.Cfa.EvalTest do
  # Domain (ADR 002). DND-5674: what Eval records at a higher-order call's
  # invocation site when the argument is written as a literal. Fixtures
  # compiled in the test and unloaded, read through BeamReader's pure decode
  # and the graph builder, then analysed under the open-world seed, as the
  # runner does. Closure ids are {mfa, lambda ordinal} and {m, f, a}.
  #
  # Sabotage record (DND-5674): ../../../sabotage_records/cfa-20261106-dnd_5676_effects_cfa_batch.md
  use ExUnit.Case, async: true

  import Anchor.Test.BeamFixtures

  alias Anchor.Adapters.BeamReader
  alias Anchor.Domain.Cfa
  alias Anchor.Domain.Graph.Builder

  @literal AnchorFixtures.CfaEvalTest.Literal

  setup_all do
    graph =
      """
      defmodule AnchorFixtures.CfaEvalTest.Literal do
        def capture(xs), do: Enum.map(xs, &AnchorFixtures.CfaEvalTest.Literal.f/1)
        def lambda(xs), do: Enum.map(xs, fn x -> x end)
        def offset(xs), do: Enum.with_index(xs, 1)
        def desc(xs), do: Enum.sort(xs, :desc)
        def asc(xs), do: Enum.sort_by(xs, &AnchorFixtures.CfaEvalTest.Literal.f/1, :asc)
        def module(xs), do: Enum.sort(xs, Date)
        def tuple(xs), do: Enum.sort(xs, {:desc, Date})
        def variable(xs, fun), do: Enum.map(xs, fun)
        def f(x), do: x
      end
      """
      |> compile_unloaded("eval_test.ex")
      |> Enum.map(fn {module, binary} ->
        BeamReader.decode(binary, app: :fixtures, path: "#{module}.beam")
      end)
      |> Builder.build(%{})

    %{cfa: Cfa.analyze(graph, Cfa.default_seed(graph))}
  end

  defp site(mfa, ordinal \\ 0), do: {mfa, ordinal}
  defp set(closures), do: {:ok, MapSet.new(closures)}

  describe "a higher-order argument written as a literal (DND-5674)" do
    test "a literal capture or fn resolves to its target, under the open-world seed", %{cfa: cfa} do
      assert Cfa.closures_at(cfa, site({@literal, :capture, 1})) == set([{@literal, :f, 1}])

      assert Cfa.closures_at(cfa, site({@literal, :lambda, 1})) ==
               set([{{@literal, :lambda, 1}, 0}])
    end

    test "a literal that is no function applies nothing: the empty set, never :any", %{cfa: cfa} do
      assert Cfa.closures_at(cfa, site({@literal, :offset, 1})) == set([])
      assert Cfa.closures_at(cfa, site({@literal, :desc, 1})) == set([])
      # sort_by/3: the mapper resolves, the :asc sorter applies nothing.
      assert Cfa.closures_at(cfa, site({@literal, :asc, 1}, 0)) == set([{@literal, :f, 1}])
      assert Cfa.closures_at(cfa, site({@literal, :asc, 1}, 1)) == set([])
    end

    test "control: a module or a {dir, module} tuple may name compare/2: :any", %{cfa: cfa} do
      assert Cfa.closures_at(cfa, site({@literal, :module, 1})) == :any
      assert Cfa.closures_at(cfa, site({@literal, :tuple, 1})) == :any
    end

    test "control: a variable argument stays as the analysis finds it (a root's parameter: :any)",
         %{cfa: cfa} do
      assert Cfa.closures_at(cfa, site({@literal, :variable, 2})) == :any
    end

    test "the counts move the literal sites from any to resolved", %{cfa: cfa} do
      assert cfa.counts.by_function[{@literal, :offset, 1}] == %{total: 1, resolved: 1, any: 0}
      assert cfa.counts.by_function[{@literal, :desc, 1}] == %{total: 1, resolved: 1, any: 0}
    end
  end
end
