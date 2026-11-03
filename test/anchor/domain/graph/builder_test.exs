defmodule Anchor.Domain.Graph.BuilderTest do
  # Domain (ADR 002). QA plan rows 32-37 (DND-5438, AC3, AC4). Fixtures are
  # compiled in the test and unloaded; their binaries are decoded into %Beam{}
  # records by Anchor.Adapters.BeamReader.decode/2 as setup (the reader's own
  # conversions are pinned in beam_reader_test.exs), and the builder under test
  # gets plain data.
  #
  # Sabotage record: ../../../sabotage_records/builder-20261103-dnd_5438.md
  # Sabotage record: ../../../sabotage_records/builder-20261103-dnd_5551_graph_hardening.md
  # Sabotage record: ../../../sabotage_records/inlines-20261103-dnd_5551_graph_hardening.md
  use ExUnit.Case, async: true

  import Anchor.Test.BeamFixtures

  alias Anchor.Adapters.BeamReader
  alias Anchor.Domain.Graph
  alias Anchor.Domain.Graph.Builder
  alias Anchor.Domain.Graph.Call
  alias Anchor.Domain.Graph.FunctionNode
  alias Anchor.Domain.Graph.ModuleNode
  alias Anchor.Domain.Graph.SourceFacts
  alias AnchorFixtures.BuilderTest.A
  alias AnchorFixtures.BuilderTest.B
  alias AnchorFixtures.BuilderTest.Plain
  alias AnchorFixtures.BuilderTest.User
  alias AnchorFixtures.BuilderTest.User.Generated

  @plain_file "lib/plain.ex"
  @plain_source """
  defmodule AnchorFixtures.BuilderTest.Plain do
    @behaviour AnchorFixtures.BuilderTest.Contract
    Module.register_attribute(__MODULE__, :tag, persist: true)
    @tag :hello
    defstruct [:a, b: 2]

    @type t :: %__MODULE__{}

    @spec run(integer()) :: integer()
    def run(x), do: helper(x)

    defp helper(x), do: x + 1

    defmacro m(x), do: x
  end
  """

  @mac_file "lib/mac.ex"
  @mac_source """
  defmodule AnchorFixtures.BuilderTest.Mac do
    defmacro __using__(_opts) do
      quote do
        defmodule Generated do
          def g(x), do: AnchorFixtures.BuilderTest.Other.h(x)
        end
      end
    end
  end
  """

  @user_file "lib/user.ex"
  @user_source """
  defmodule AnchorFixtures.BuilderTest.User do
    use AnchorFixtures.BuilderTest.Mac

    def run(x), do: x
  end
  """

  @pair_source """
  defmodule AnchorFixtures.BuilderTest.A do
    def f(x), do: AnchorFixtures.BuilderTest.B.g(x)
  end

  defmodule AnchorFixtures.BuilderTest.B do
    def g(x), do: AnchorFixtures.BuilderTest.A.f(x)
    def h(mod), do: mod.g(1)
  end
  """

  setup_all do
    plain = decode!(compile_unloaded(@plain_source, @plain_file))

    macro_and_user =
      decode!(compile_all_unloaded([{@mac_source, @mac_file}, {@user_source, @user_file}]))

    pair = decode!(compile_unloaded(@pair_source, "lib/pair.ex"))
    %{plain: plain, macro_and_user: macro_and_user, pair: pair}
  end

  defp decode!(modules) do
    Enum.map(modules, fn {module, binary} ->
      BeamReader.decode(binary, app: :demo, path: "ebin/#{module}.beam")
    end)
  end

  defp facts(file, source), do: %{file => SourceFacts.from_source(file, source)}

  describe "build/2 module facts" do
    # Row 32
    test "a module node carries the elixir_v1 facts and every function with its Core", %{
      plain: plain
    } do
      graph = Builder.build(plain, facts(@plain_file, @plain_source))

      assert %ModuleNode{
               module: Plain,
               app: :demo,
               source_file: @plain_file,
               behaviours: [AnchorFixtures.BuilderTest.Contract],
               struct_fields: [:a, :b],
               generated?: false
             } = node = Graph.module(graph, Plain)

      assert Keyword.get(node.attributes, :tag) == :hello
      assert [{:"::", _, [{:run, _, _}, _]}] = node.specs[{:run, 1}]
      assert {:type, _quoted} = node.types[{:t, 0}]

      assert %FunctionNode{kind: :def, line: 10, core: run_core} = node.functions[{:run, 1}]

      assert %FunctionNode{kind: :defp, line: 12, core: helper_core} =
               node.functions[{:helper, 1}]

      assert :cerl.is_c_fun(run_core) and :cerl.is_c_fun(helper_core)

      assert %Call{
               from: {Plain, :run, 1},
               to: {Plain, :helper, 1},
               kind: :local,
               line: 10,
               line_source: :call
             } in graph.calls
    end

    # Row 36
    test "a macro is mapped back from Core's MACRO-name/arity+1", %{plain: plain} do
      graph = Builder.build(plain, facts(@plain_file, @plain_source))

      assert %FunctionNode{kind: :defmacro, name: :m, arity: 1, line: 14, core: core} =
               Graph.function(graph, {Plain, :m, 1})

      assert :cerl.is_c_fun(core)
      refute Map.has_key?(Graph.module(graph, Plain).functions, {:"MACRO-m", 2})
    end
  end

  describe "build/2 generated? (AC3)" do
    # Row 33
    test "a module a macro emits is a module node, generated?: true, with its calls", %{
      macro_and_user: beams
    } do
      graph =
        Builder.build(
          beams,
          Map.merge(facts(@mac_file, @mac_source), facts(@user_file, @user_source))
        )

      assert Graph.module(graph, Generated).generated? == true
      assert Graph.module(graph, Generated).source_file == @user_file

      assert Graph.module(graph, User).generated? == false

      # Macro output carries the macro call site's line: the `use` in the
      # user's file (shared contract section 12's assumption, seen here).
      use_line = 2

      assert [
               %Call{
                 to: {AnchorFixtures.BuilderTest.Other, :h, 1},
                 kind: :remote,
                 line: ^use_line,
                 line_source: :call
               }
             ] = Graph.calls_from(graph, {Generated, :g, 1})
    end

    # Row 34
    test "with no source facts, or unparseable ones, generated? is :unknown, never false", %{
      macro_and_user: beams
    } do
      graph = Builder.build(beams, %{})
      assert Graph.module(graph, Generated).generated? == :unknown
      assert Graph.module(graph, User).generated? == :unknown

      graph = Builder.build(beams, %{@user_file => {:error, :unparseable}})
      assert Graph.module(graph, User).generated? == :unknown
    end

    test "a module missing from a file that has a non-literal defmodule is :unknown, not true", %{
      macro_and_user: beams
    } do
      facts = %{
        @user_file => %{defmodules: [inspect(User)], uses: %{}, nonliteral_defmodule?: true}
      }

      graph = Builder.build(beams, facts)

      assert Graph.module(graph, Generated).generated? == :unknown
      assert Graph.module(graph, User).generated? == false
    end
  end

  describe "build/2 unreadable beams (AC4)" do
    # Row 35
    test "decode errors are carried in path order, and every good module is kept", %{plain: plain} do
      error_b = {:error, %{path: "ebin/b.beam", module: nil, reason: {:unreadable, :eacces}}}
      error_a = {:error, %{path: "ebin/a.beam", module: Foo, reason: :no_debug_info}}

      graph = Builder.build([error_b | plain] ++ [error_a], %{})

      assert graph.unreadable == [
               %{path: "ebin/a.beam", module: Foo, reason: :no_debug_info},
               %{path: "ebin/b.beam", module: nil, reason: {:unreadable, :eacces}}
             ]

      assert %ModuleNode{} = Graph.module(graph, Plain)
    end
  end

  describe "build/2 functions with no Core body (DND-5549)" do
    test "a private macro and a private function nothing calls have no Core; each is counted" do
      module = AnchorFixtures.BuilderTest.NoCore

      graph =
        """
        defmodule AnchorFixtures.BuilderTest.NoCore do
          defmacrop twice(x), do: quote(do: unquote(x) * 2)
          def run(x), do: helper(twice(x))
          defp helper(x), do: x
          defp unused(x), do: x
        end
        """
        |> compile_unloaded("lib/no_core.ex")
        |> decode!()
        |> Builder.build(%{})

      assert Graph.functions_without_core(graph) == %{module => [{:twice, 1}, {:unused, 1}]}

      assert %FunctionNode{kind: :defmacrop, core: nil} =
               Graph.function(graph, {module, :twice, 1})

      assert %FunctionNode{kind: :defp, core: nil} = Graph.function(graph, {module, :unused, 1})
      # Positive control: the functions the beam holds have their Core.
      assert %FunctionNode{core: core} = Graph.function(graph, {module, :helper, 1})
      assert :cerl.is_c_fun(core)
      # A private function the compiler emitted no code for is expected.
      assert graph.unreadable == []
    end

    test "a public function with no Core is unreadable, naming it; the module is kept", %{
      plain: plain
    } do
      [beam] = Enum.filter(plain, &(&1.module == Plain))

      defs =
        Enum.reject(:cerl.module_defs(beam.core), fn {fname, _fun} ->
          :cerl.var_name(fname) in [{:run, 1}, {:"MACRO-m", 2}]
        end)

      core =
        :cerl.update_c_module(
          beam.core,
          :cerl.module_name(beam.core),
          :cerl.module_exports(beam.core),
          :cerl.module_attrs(beam.core),
          defs
        )

      graph = Builder.build([%{beam | core: core}], %{})

      assert graph.unreadable == [
               %{path: beam.path, module: Plain, reason: {:no_core, [{:m, 1}, {:run, 1}]}}
             ]

      assert Graph.functions_without_core(graph) == %{Plain => [{:m, 1}, {:run, 1}]}
      assert %ModuleNode{} = Graph.module(graph, Plain)
      assert Graph.calls_from(graph, {Plain, :run, 1}) == []
    end

    test "with every body present nothing is counted", %{pair: pair} do
      graph = Builder.build(pair, %{})
      assert Graph.functions_without_core(graph) == %{}
      assert graph.unreadable == []
    end
  end

  describe "build/2 duplicate modules" do
    test "a second beam of one module is reported, naming the kept one; its edges are not built",
         %{
           pair: pair
         } do
      [a | _] = Enum.filter(pair, &(&1.module == A))
      stale = %{a | path: "other_ebin/#{A}.beam"}

      graph = Builder.build([stale | pair], %{})

      assert graph.unreadable == [
               %{path: "other_ebin/#{A}.beam", module: A, reason: {:duplicate_module, a.path}}
             ]

      assert Graph.module(graph, A).app == :demo
      assert Enum.count(graph.calls, &(&1.from == {A, :f, 1})) == 1
    end
  end

  describe "build/2 lines of code a macro injects from another file" do
    # `quote location: :keep` keeps the macro file's lines; such a line is not
    # a line of the module's own file, so the def line stands in.
    test "a call annotated with another file gets the def line, flagged :def", %{pair: pair} do
      [lib, user] =
        decode!(
          compile_all_unloaded([
            {"""
             defmodule AnchorFixtures.BuilderTest.KeepLib do
               defmacro __using__(_opts) do
                 quote location: :keep do
                   def hello(x) do
                     Enum.map(x, & &1)
                   end
                 end
               end
             end
             """, "deps/keep_lib/lib/keep_lib.ex"},
            {"""
             defmodule AnchorFixtures.BuilderTest.KeepUser do
               use AnchorFixtures.BuilderTest.KeepLib
             end
             """, "lib/keep_user.ex"}
          ])
        )

      graph = Builder.build([lib, user | pair], %{})
      user_module = AnchorFixtures.BuilderTest.KeepUser
      def_line = Graph.function(graph, {user_module, :hello, 1}).line

      assert [%Call{to: {Enum, :map, 2}, line: ^def_line, line_source: :def}] =
               Enum.filter(
                 Graph.calls_from(graph, {user_module, :hello, 1}),
                 &(&1.to == {Enum, :map, 2})
               )

      # Positive control: the module's own file's lines are still used.
      assert [%Call{line: 6, line_source: :call}] =
               Enum.filter(Graph.calls_from(graph, {B, :g, 1}), &(&1.to == {A, :f, 1}))
    end
  end

  describe "build/2 lines of a module compiled from an absolute path" do
    # `mix compile` names each source by its absolute path (elixir_v1 `:file`),
    # while Core's `{:file, _}` annotations hold the cwd-relative path
    # (`:relative_file`). The module's own lines must still be used.
    test "an edge keeps its own line, flagged :call" do
      file = Path.join(File.cwd!(), "lib/anchor_fixtures/absolute.ex")

      [beam] =
        decode!(
          compile_unloaded(
            """
            defmodule AnchorFixtures.BuilderTest.Absolute do
              def f(x), do: Enum.count(x)
            end
            """,
            file
          )
        )

      assert beam.elixir.file == file
      graph = Builder.build([beam], %{})

      assert [%Call{to: {Enum, :count, 1}, line: 2, line_source: :call}] =
               Graph.calls_from(graph, {AnchorFixtures.BuilderTest.Absolute, :f, 1})
    end
  end

  describe "build/2 edges and Graph queries" do
    # Row 37
    test "calls between modules are aggregated and answered both ways", %{pair: pair} do
      graph = Builder.build(pair, %{})

      a_to_b = %Call{from: {A, :f, 1}, to: {B, :g, 1}, kind: :remote, line: 2, line_source: :call}
      b_to_a = %Call{from: {B, :g, 1}, to: {A, :f, 1}, kind: :remote, line: 6, line_source: :call}

      dynamic = %Call{
        from: {B, :h, 1},
        to: {:dynamic, :g, 1, :variable},
        kind: :remote,
        line: 7,
        line_source: :call
      }

      assert Enum.sort(graph.calls) == Enum.sort([a_to_b, b_to_a, dynamic])
      assert Graph.calls_from(graph, {A, :f, 1}) == [a_to_b]
      assert Graph.calls_from(graph, B) == [b_to_a, dynamic]
      assert Graph.calls_to(graph, {A, :f, 1}) == [b_to_a]
      # The dynamic call could reach B.g/1, but names no callee.
      assert Graph.calls_to(graph, B) == [a_to_b]
      assert Graph.calls_to(graph, {A, :nope, 0}) == []
    end

    # DND-5551: Elixir inlines Map.put and Map.merge before Core, so the edge
    # names :maps; a query by either spelling finds the call.
    test "a stdlib call Elixir inlines is found by its Elixir and its Erlang name" do
      inlined = AnchorFixtures.BuilderTest.Inlined

      graph =
        """
        defmodule AnchorFixtures.BuilderTest.Inlined do
          def put(map), do: Map.put(map, :k, 1)
          def merge(a, b), do: Map.merge(a, b)
          def erlang_put(map), do: :maps.put(:k, 1, map)
          def get(map), do: Map.get(map, :k)
        end
        """
        |> compile_unloaded("lib/inlined.ex")
        |> decode!()
        |> Builder.build(%{})

      put = %Call{
        from: {inlined, :put, 1},
        to: {:maps, :put, 3},
        kind: :remote,
        line: 2,
        line_source: :call
      }

      merge = %Call{
        from: {inlined, :merge, 2},
        to: {:maps, :merge, 2},
        kind: :remote,
        line: 3,
        line_source: :call
      }

      erlang_put = %Call{
        from: {inlined, :erlang_put, 1},
        to: {:maps, :put, 3},
        kind: :remote,
        line: 4,
        line_source: :call
      }

      # Core lowers Map.put to an is_map guard and a map update; the walker
      # reads the update as the inlined :maps.put/3.
      assert put in Graph.calls_from(graph, {inlined, :put, 1})
      assert Graph.calls_to(graph, {Map, :put, 3}) == [erlang_put, put]
      assert Graph.calls_to(graph, {:maps, :put, 3}) == [erlang_put, put]
      assert Graph.calls_to(graph, {Map, :merge, 2}) == [merge]
      assert Graph.calls_to(graph, {:maps, :merge, 2}) == [merge]

      assert Enum.sort(Graph.calls_to(graph, Map)) ==
               Enum.sort([put, merge, erlang_put] ++ Graph.calls_from(graph, {inlined, :get, 1}))

      # Positive control: Map.get/2 is not inlined, so Core names it as written.
      assert [%Call{to: {Map, :get, 2}, line: 5}] = Graph.calls_to(graph, {Map, :get, 2})
      assert Graph.calls_to(graph, {:maps, :get, 2}) == []
    end

    test "Graph.module/2 and function/2 answer nil for what is not there", %{pair: pair} do
      graph = Builder.build(pair, %{})
      assert Graph.module(graph, Nope) == nil
      assert Graph.function(graph, {Nope, :f, 1}) == nil
      assert Graph.function(graph, {A, :nope, 1}) == nil
    end
  end
end
