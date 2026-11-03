defmodule Anchor.Domain.CoreTest do
  # Domain (ADR 002). QA plan, test/anchor/domain/core_test.exs (DND-5497):
  # the lambda, apply-site and allocation ordinals over Core of a fixture
  # compiled in the test (read the way BeamReader reads it).
  #
  # Sabotage record: ../../sabotage_records/cfa-20261103-dnd_5497_zero_cfa.md
  use ExUnit.Case, async: true

  import Anchor.Test.BeamFixtures

  alias Anchor.Domain.Core

  @source """
  defmodule AnchorFixtures.CoreTest.M do
    def two_fns(x) do
      f = fn a -> a end # first fn
      g = fn b -> b end # second fn
      {f, g, x}
    end

    def applies(f, x) do
      f.(x) # var apply
      apply(f, [x]) # apply2
      Enum.map(x, f) # enum map
      Enum.group_by(x, f, f) # group by
      :lists.map(f, x)
    end

    def not_sites(mod, x) do
      String.upcase(x)
      apply(mod, :f, [x])
      helper(x)
    end

    def nested(x), do: fn -> fn -> x end end

    def receives do
      receive do
        m -> m
      end
    end

    def builds(x), do: {[x], %{a: x}, Map.put(%{}, :b, x)}

    defp helper(x), do: x
  end
  """

  setup_all do
    %{binary: @source |> compile_unloaded("core_test.ex") |> binary!(AnchorFixtures.CoreTest.M)}
  end

  defp core(binary, name_arity), do: core_fun!(binary, name_arity)

  defp mfa({name, arity}), do: {AnchorFixtures.CoreTest.M, name, arity}

  describe "lambdas/1" do
    test "two fns are ordinals 0 and 1 in source order", %{binary: binary} do
      lambdas = Core.lambdas(core(binary, {:two_fns, 1}))

      assert Enum.map(lambdas, &elem(&1, 0)) == [0, 1]

      assert Enum.map(lambdas, fn {_ordinal, fun} -> Core.line(fun) end) ==
               [line_of(@source, "# first fn"), line_of(@source, "# second fn")]
    end

    test "recompiling the same source gives the same ids", %{binary: binary} do
      again = @source |> compile_unloaded("core_test.ex") |> binary!(AnchorFixtures.CoreTest.M)

      for name_arity <- [{:two_fns, 1}, {:applies, 2}, {:nested, 1}] do
        assert Enum.map(Core.lambdas(core(binary, name_arity)), &elem(&1, 0)) ==
                 Enum.map(Core.lambdas(core(again, name_arity)), &elem(&1, 0))

        assert Enum.map(Core.apply_sites(mfa(name_arity), core(binary, name_arity)), &elem(&1, 0)) ==
                 Enum.map(
                   Core.apply_sites(mfa(name_arity), core(again, name_arity)),
                   &elem(&1, 0)
                 )
      end
    end

    test "nested fns are numbered outer first; the function's own fun is not a lambda",
         %{binary: binary} do
      assert core(binary, {:nested, 1}) |> Core.lambdas() |> Enum.map(&elem(&1, 0)) == [0, 1]
    end

    test "a receive's letrec loop is a lambda with its own ordinal", %{binary: binary} do
      assert [{0, fun}] = Core.lambdas(core(binary, {:receives, 0}))
      assert :cerl.is_c_fun(fun)
    end

    test "labelling labelled Core again gives the same ordinals", %{binary: binary} do
      fun = core(binary, {:two_fns, 1})
      assert Core.lambdas(Core.label(fun)) |> Enum.map(&elem(&1, 0)) == [0, 1]
    end
  end

  describe "apply_sites/2" do
    test "f.(x), apply(f, [x]), Enum.map/2, Enum.group_by/3 (two) and :lists.map/2 are sites",
         %{binary: binary} do
      sites = Core.apply_sites(mfa({:applies, 2}), core(binary, {:applies, 2}))

      assert Enum.map(sites, &elem(&1, 0)) ==
               Enum.map(0..5, &{mfa({:applies, 2}), &1})

      assert Enum.map(sites, fn {_id, node} -> Core.line(node) end) == [
               line_of(@source, "# var apply"),
               line_of(@source, "# apply2"),
               line_of(@source, "# enum map"),
               line_of(@source, "# group by"),
               line_of(@source, "# group by"),
               line_of(@source, ":lists.map(f, x)")
             ]
    end

    test "a remote call with a literal module, apply/3 and a local call are not sites",
         %{binary: binary} do
      assert Core.apply_sites(mfa({:not_sites, 2}), core(binary, {:not_sites, 2})) == []
    end
  end

  describe "alloc_ordinal/1" do
    test "every tuple, cons and map is an allocation site, numbered in pre-order",
         %{binary: binary} do
      labelled =
        (&[{Core.alloc_ordinal(&1), :cerl.type(&1)} | &2])
        |> :cerl_trees.fold([], Core.label(core(binary, {:builds, 1})))
        |> Enum.reject(&match?({nil, _type}, &1))
        |> Enum.sort()

      # Elixir inlines Map.put(%{}, :b, x) into a map literal before Core, so
      # it is a map here; the last tuple is the head's {function_clause, X}.
      assert labelled == [{0, :map}, {1, :map}, {2, :tuple}, {3, :cons}, {4, :tuple}]
    end
  end

  describe "line/1" do
    test "the source line of the Core annotation; nil when there is none" do
      assert Core.line(:cerl.c_atom(:a)) == nil
      assert Core.line(:cerl.set_ann(:cerl.c_atom(:a), [7])) == 7
      assert Core.line(:cerl.set_ann(:cerl.c_atom(:a), [{9, 3}])) == 9
      assert Core.line(:cerl.set_ann(:cerl.c_atom(:a), [0])) == nil
    end
  end
end
