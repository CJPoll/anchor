defmodule Anchor.Domain.Cfa.RenameTest do
  # Domain (ADR 002). DND-8063: the 0-CFA keyed a variable by function and
  # name, so the compiler's reused names (`_X_@1` bound in one clause to a
  # parameter's map value and in another to a `with ... else` fun) joined
  # `any` into a local closure's apply site, and every caller of the function
  # read as a Manager under effects_match_bucket. Rename gives each binding a
  # name of its own; these rows hold that it removes only that sharing.
  # Fixtures are compiled in the test and unloaded, read through BeamReader's
  # pure decode and the graph builder, and analysed under the open-world seed,
  # as the runner does.
  #
  # Sabotage record: ../../../sabotage_records/cfa-20261127-athena_DND_8063_framework_tests_mock_manager.md
  use ExUnit.Case, async: true

  import Anchor.Test.BeamFixtures

  alias Anchor.Adapters.BeamReader
  alias Anchor.Domain.Cfa
  alias Anchor.Domain.Cfa.Rename
  alias Anchor.Domain.Core
  alias Anchor.Domain.Effects
  alias Anchor.Domain.Graph
  alias Anchor.Domain.Graph.Builder
  alias Anchor.Test.StructFlowFixtures

  @w AnchorFixtures.CfaRenameTest.W

  @source """
  defmodule AnchorFixtures.CfaRenameTest.W do
    # The collision: clause 1 binds a compiler name to a parameter's map
    # value (any); clause 2's `with ... else` is a let-bound fun the
    # compiler names the same way.
    def scope(name, env), do: do_scope(name, env)

    defp do_scope({:nest, _}, %{owner: {:module, _}} = env), do: env.owner

    defp do_scope(name, env) do
      with {:ok, m} <- found(name),
           true <- is_atom(m) do
        {:module, m, env}
      else
        _unknown -> :unknown
      end
    end

    defp found(x), do: {:ok, x}

    # A real outside closure under a reused name: `g` is first a local fun,
    # then rebound by a pattern to the parameter `f`, which is applied.
    def reused(f) do
      g = fn -> :local end
      g.()

      case f do
        g when is_function(g, 0) -> g.()
      end
    end

    # A real outside closure applied through a pattern of the parameter.
    def tagged({:cb, h}), do: h.()

    # Shadowing in nested funs: the inner `x` is the inner fun's argument.
    def shadow(x) do
      inner = fn x -> x.() end
      inner.(fn -> :ok end)
      x.()
    end
  end
  """

  setup_all do
    graph =
      @source
      |> compile_unloaded("cfa_rename_test.ex")
      |> Enum.map(fn {module, binary} ->
        BeamReader.decode(binary, app: :fixtures, path: "#{module}.beam")
      end)
      |> Builder.build(%{})

    cfa = Cfa.analyze(graph, Cfa.default_seed(graph))
    model = %{StructFlowFixtures.model(graph) | cfa: cfa}
    %{graph: graph, cfa: cfa, effects: Effects.infer(model, callbacks: %{})}
  end

  defp sites(cfa, mfa, graph) do
    %Graph.FunctionNode{core: core} =
      graph
      |> Graph.module(elem(mfa, 0))
      |> Map.fetch!(:functions)
      |> Map.fetch!({elem(mfa, 1), elem(mfa, 2)})

    for {site, _node} <- Core.apply_sites(mfa, core), do: Cfa.closures_at(cfa, site)
  end

  describe "the CFA over renamed Core" do
    test "R1: a with-else fun shares no abstract value with a same-named binding of another clause",
         %{cfa: cfa, graph: graph} do
      results = sites(cfa, {@w, :do_scope, 2}, graph)
      assert results != []
      assert Enum.all?(results, &match?({:ok, _closures}, &1)), inspect(results)
    end

    test "R2: a parameter applied under a reused name is still any; the local fun is still resolved",
         %{cfa: cfa, graph: graph} do
      assert [{:ok, local}, :any] = sites(cfa, {@w, :reused, 1}, graph)
      assert MapSet.size(local) == 1
    end

    test "R3: a closure taken from a parameter's pattern is still any", %{cfa: cfa, graph: graph} do
      assert [:any] = sites(cfa, {@w, :tagged, 1}, graph)
    end

    test "R4: in nested funs, the inner argument and the outer parameter stay apart",
         %{cfa: cfa, graph: graph} do
      # inner.(fn ...) is resolved to `inner`; x.() inside inner reaches only the
      # fun handed to it; the outer x.() is the parameter: any.
      results = sites(cfa, {@w, :shadow, 1}, graph)
      assert length(results) == 3
      assert Enum.count(results, &(&1 == :any)) == 1
      assert Enum.count(results, &match?({:ok, _}, &1)) == 2
    end
  end

  describe "effects_match_bucket's roles over the renamed CFA" do
    test "R5: a function whose only apply is its own with-else fun reaches no effect", %{
      effects: effects
    } do
      assert Effects.role(effects, {@w, :scope, 2}) == :domain
    end

    test "R6: applying an outside closure under a reused name or a pattern is still managers",
         %{effects: effects} do
      assert Effects.role(effects, {@w, :reused, 1}) == :managers
      assert Effects.role(effects, {@w, :tagged, 1}) == :managers
      assert Effects.role(effects, {@w, :shadow, 1}) == :managers
    end
  end

  describe "rename/1" do
    defp core_fun(source, name, arity) do
      [{module, binary}] = compile_unloaded(source, "rename_unit.ex")
      beam = BeamReader.decode(binary, app: :fixtures, path: "#{module}.beam")
      graph = Builder.build([beam], %{})

      %Graph.FunctionNode{core: core} =
        graph |> Graph.module(module) |> Map.fetch!(:functions) |> Map.fetch!({name, arity})

      core
    end

    defp binder_names(core) do
      :cerl_trees.fold(
        fn node, acc ->
          case :cerl.type(node) do
            :fun ->
              Enum.map(:cerl.fun_vars(node), &:cerl.var_name/1) ++ acc

            :let ->
              Enum.map(:cerl.let_vars(node), &:cerl.var_name/1) ++ acc

            :clause ->
              Enum.map(:cerl.clause_vars(node), &:cerl.var_name/1) ++ acc

            :try ->
              Enum.map(:cerl.try_vars(node) ++ :cerl.try_evars(node), &:cerl.var_name/1) ++ acc

            _other ->
              acc
          end
        end,
        [],
        core
      )
    end

    test "R7: every binding gets a name no other binding has; uses follow their binder" do
      # do_scope/2 is the collision fixture: the compiler binds one name twice.
      core =
        core_fun(String.replace(@source, "CfaRenameTest.W", "CfaRenameTest.U1"), :do_scope, 2)

      before = binder_names(core)
      renamed = Rename.rename(core)
      names = binder_names(renamed)

      assert length(before) != length(Enum.uniq(before)), "control: the fixture reuses a name"
      assert length(names) == length(Enum.uniq(names))

      free =
        :cerl_trees.free_variables(renamed)
        |> Enum.reject(&match?({_name, _arity}, &1))

      assert free == []
    end

    test "R8: function names (letrec and local calls) are never renamed" do
      core =
        core_fun(
          """
          defmodule AnchorFixtures.CfaRenameTest.U2 do
            def f(xs), do: for(<<x <- xs>>, do: g(x))
            defp g(x), do: x
          end
          """,
          :f,
          1
        )

      fnames = fn tree ->
        :cerl_trees.fold(
          fn node, acc ->
            if :cerl.type(node) == :var and match?({_n, _a}, :cerl.var_name(node)),
              do: [:cerl.var_name(node) | acc],
              else: acc
          end,
          [],
          tree
        )
        |> Enum.sort()
      end

      assert fnames.(core) != []
      assert fnames.(Rename.rename(core)) == fnames.(core)
    end

    test "R9: lambda and apply-site ordinals are unchanged" do
      core =
        core_fun(@source |> String.replace("CfaRenameTest.W", "CfaRenameTest.U3"), :shadow, 1)

      mfa = {AnchorFixtures.CfaRenameTest.U3, :shadow, 1}

      ordinals = fn tree ->
        {Enum.map(Core.lambdas(tree), &elem(&1, 0)),
         Enum.map(Core.apply_sites(mfa, tree), &elem(&1, 0))}
      end

      assert ordinals.(Rename.rename(core)) == ordinals.(core)
    end

    test "R11: a map pattern stays a pattern, and an expression map an expression" do
      core =
        core_fun(
          """
          defmodule AnchorFixtures.CfaRenameTest.U5 do
            def f(m), do: {m.x, %{m | y: 1}}
          end
          """,
          :f,
          1
        )

      kinds = fn tree ->
        :cerl_trees.fold(
          fn node, acc ->
            if :cerl.type(node) == :map, do: [:cerl.is_c_map_pattern(node) | acc], else: acc
          end,
          [],
          tree
        )
      end

      assert true in kinds.(core), "control: the fixture holds a map pattern"
      assert false in kinds.(core), "control: the fixture holds a map expression"
      assert kinds.(Rename.rename(core)) == kinds.(core)

      # A map update keeps the map it updates.
      args = fn tree ->
        :cerl_trees.fold(
          fn node, acc ->
            if :cerl.type(node) == :map and not :cerl.is_c_map_pattern(node),
              do: [:cerl.type(:cerl.map_arg(node)) | acc],
              else: acc
          end,
          [],
          tree
        )
      end

      assert :var in args.(core), "control: the fixture updates a map held in a variable"
      assert args.(Rename.rename(core)) == args.(core)
    end

    test "R12: every binding form is renamed: fun, let, clause, alias, map, binary, try, letrec" do
      core =
        core_fun(
          """
          defmodule AnchorFixtures.CfaRenameTest.U6 do
            def f(%{k: v} = whole, bin) do
              <<n::8, rest::binary-size(n)>> = bin
              chars = for <<c <- rest>>, do: c

              got =
                try do
                  v.()
                rescue
                  e in ArgumentError -> e
                catch
                  kind, reason -> {kind, reason}
                end

              receive do
                {:msg, x} -> {x, got, whole, chars}
              after
                0 -> :none
              end
            end
          end
          """,
          :f,
          2
        )

      kinds = fn tree ->
        :cerl_trees.fold(
          fn node, acc -> MapSet.put(acc, :cerl.type(node)) end,
          MapSet.new(),
          tree
        )
      end

      for kind <- [:let, :letrec, :alias, :map, :binary, :try, :case] do
        assert kind in kinds.(core), "control: the fixture holds a #{kind}"
      end

      renamed = Rename.rename(core)
      names = binder_names(renamed)
      assert names != []

      assert Enum.all?(names, &String.contains?(to_string(&1), "~")),
             "unrenamed binders: #{inspect(Enum.reject(names, &String.contains?(to_string(&1), "~")))}"

      assert renamed |> :cerl_trees.free_variables() |> Enum.reject(&match?({_n, _a}, &1)) == []
    end

    test "R13: a binary size reads the earlier segment's variable; a pinned map key reads the outer one" do
      core =
        core_fun(
          """
          defmodule AnchorFixtures.CfaRenameTest.U7 do
            def f(bin, k, m) do
              <<n::8, rest::binary-size(n)>> = bin

              case m do
                %{^k => v} -> {rest, v}
              end
            end
          end
          """,
          :f,
          3
        )

      renamed = Rename.rename(core)

      sizes =
        :cerl_trees.fold(
          fn node, acc ->
            if :cerl.type(node) == :bitstr and :cerl.is_c_var(:cerl.bitstr_size(node)),
              do: [:cerl.var_name(:cerl.bitstr_size(node)) | acc],
              else: acc
          end,
          [],
          renamed
        )

      keys =
        :cerl_trees.fold(
          fn node, acc ->
            if :cerl.type(node) == :map_pair and :cerl.is_c_var(:cerl.map_pair_key(node)),
              do: [:cerl.var_name(:cerl.map_pair_key(node)) | acc],
              else: acc
          end,
          [],
          renamed
        )

      binders = binder_names(renamed)
      assert sizes != [] and keys != [], "control: a sized segment and a pinned key"
      # Each use names an existing binder, and the pinned key is the parameter's.
      for name <- sizes ++ keys, do: assert(name in binders, inspect(name))
      # `k` is bound once (by the clause on the parameters), and the pinned key
      # is that binding, not a binding of its own.
      assert [k] = Enum.filter(Enum.uniq(binders), &String.starts_with?(to_string(&1), "_k@"))
      assert Enum.all?(keys, &(&1 == k))
      assert renamed |> :cerl_trees.free_variables() |> Enum.reject(&match?({_n, _a}, &1)) == []
    end

    test "R10: identical Core renames identically" do
      core =
        core_fun(@source |> String.replace("CfaRenameTest.W", "CfaRenameTest.U4"), :reused, 1)

      assert Rename.rename(core) == Rename.rename(core)
    end
  end
end
