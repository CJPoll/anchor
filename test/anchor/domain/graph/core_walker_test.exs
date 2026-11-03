defmodule Anchor.Domain.Graph.CoreWalkerTest do
  # Domain (ADR 002). QA plan rows 17-31 (DND-5438, AC1, AC2, AC6): one fixture
  # module compiled in the test and unloaded; each row walks one function's
  # Core Erlang and pins the exact %Call{} / %StructUse{} edges, lines included
  # (each line is found in the fixture source by its snippet).
  #
  # Sabotage record: ../../../sabotage_records/core_walker-20261103-dnd_5438.md
  use ExUnit.Case, async: true

  import Anchor.Test.BeamFixtures

  alias Anchor.Domain.Graph.Call
  alias Anchor.Domain.Graph.CoreWalker
  alias Anchor.Domain.Graph.StructUse
  alias AnchorFixtures.CoreWalkerTest.M
  alias AnchorFixtures.CoreWalkerTest.Other
  alias AnchorFixtures.CoreWalkerTest.S

  @source """
  defmodule AnchorFixtures.CoreWalkerTest.S do
    defstruct [:a, :b]
  end

  defmodule AnchorFixtures.CoreWalkerTest.M do
    alias AnchorFixtures.CoreWalkerTest.Other
    alias AnchorFixtures.CoreWalkerTest.S

    @mod Other

    def remote(x), do: Other.f(x) # remote
    def attr(x), do: @mod.f(x) # attr
    def local(x), do: helper(x) # local
    def rcap(xs), do: Enum.map(xs, &Other.f/1) # rcap
    def lcap(xs), do: Enum.map(xs, &helper/1) # lcap
    def funapp(fun, x), do: fun.(x) # funapp
    def app3(mod, x), do: apply(mod, :f, [x]) # app3
    def app2(fun, x), do: apply(fun, [x]) # app2
    def varmod(mod, x), do: mod.f(x) # varmod
    def computed(x), do: Module.concat([A, B]).f(x) # computed
    def dyncap(mod), do: &mod.f/1 # dyncap

    def lowered(x, y) when is_map(x) do # lowered head
      with {:ok, a} <- Other.c1(x),
           {:ok, b} <- Other.c2(a) do
        if Other.c3(b) do
          Other.c4(b)
        else
          cond do
            Other.c5(b) -> Other.c6(b)
            true -> Other.c7(b)
          end
        end
      end

      case Other.c8(y) do
        :a -> Other.c9(y)
        _ -> fn z -> Other.c10(z) end
      end

      try do
        Other.c11(y)
      rescue
        _ -> Other.c12(y)
      end

      receive do
        {:m, v} -> Other.c13(v)
      after
        0 -> Other.c14(y)
      end

      for z <- y, do: Other.c16(z)
    end

    def lowered(_x, y), do: Other.c15(y)

    def build, do: %S{a: 1} # build literal
    def build_var(x), do: %S{a: x} # build var

    def update(%S{} = s, 1), do: %S{s | a: 1} # update clause 1
    def update(s, 2), do: %S{s | a: 2} # update clause 2

    def update_with(x) do
      with {:ok, s} <- x do
        %S{s | a: 3} # update with
      end
    end

    def match(%S{} = s), do: s # match

    def plain(m), do: [%{a: :x}, %{m | a: :y}, Other.f(m)] # plain

    defp helper(x), do: x
  end
  """

  setup_all do
    %{binary: @source |> compile_unloaded() |> binary!(M)}
  end

  defp walk(binary, name_arity), do: CoreWalker.walk(M, name_arity, core_fun!(binary, name_arity))

  defp calls(binary, name_arity), do: binary |> walk(name_arity) |> elem(0)

  defp uses(binary, name_arity), do: binary |> walk(name_arity) |> elem(1)

  defp line(snippet), do: line_of(@source, snippet)

  defp call(from, to, kind, snippet),
    do: %Call{from: from, to: to, kind: kind, line: line(snippet), line_source: :call}

  describe "walk/3 call edges (AC1)" do
    # Row 17
    test "a remote call with a literal module", %{binary: binary} do
      assert calls(binary, {:remote, 1}) ==
               [call({M, :remote, 1}, {Other, :f, 1}, :remote, "# remote")]
    end

    # Row 18
    test "a call through a module attribute is a plain remote call", %{binary: binary} do
      assert calls(binary, {:attr, 1}) == [call({M, :attr, 1}, {Other, :f, 1}, :remote, "# attr")]
    end

    # Row 19
    test "a local call", %{binary: binary} do
      assert calls(binary, {:local, 1}) ==
               [call({M, :local, 1}, {M, :helper, 1}, :local, "# local")]
    end

    # Row 20
    test "a remote capture, beside the remote call it is passed to", %{binary: binary} do
      assert calls(binary, {:rcap, 1}) == [
               call({M, :rcap, 1}, {Other, :f, 1}, :capture, "# rcap"),
               call({M, :rcap, 1}, {Enum, :map, 2}, :remote, "# rcap")
             ]
    end

    # Row 21
    test "a local capture", %{binary: binary} do
      assert calls(binary, {:lcap, 1}) == [
               call({M, :lcap, 1}, {M, :helper, 1}, :capture, "# lcap"),
               call({M, :lcap, 1}, {Enum, :map, 2}, :remote, "# lcap")
             ]
    end

    # Row 22
    test "fun application is :apply through a variable", %{binary: binary} do
      assert calls(binary, {:funapp, 2}) ==
               [call({M, :funapp, 2}, {:dynamic, nil, 1, :variable}, :apply, "# funapp")]
    end

    # Row 23
    test "apply/3 is :apply, naming the function and arity it can see", %{binary: binary} do
      assert calls(binary, {:app3, 2}) ==
               [call({M, :app3, 2}, {:dynamic, :f, 1, :call}, :apply, "# app3")]
    end

    test "apply/2 is :apply with no name", %{binary: binary} do
      assert calls(binary, {:app2, 2}) ==
               [call({M, :app2, 2}, {:dynamic, nil, 1, :call}, :apply, "# app2")]
    end

    # Row 24
    test "a call on a variable module is a dynamic receiver", %{binary: binary} do
      assert calls(binary, {:varmod, 2}) ==
               [call({M, :varmod, 2}, {:dynamic, :f, 1, :variable}, :remote, "# varmod")]
    end

    # Row 25
    test "a call on a computed module is a dynamic :call receiver", %{binary: binary} do
      assert calls(binary, {:computed, 1}) == [
               call({M, :computed, 1}, {Module, :concat, 1}, :remote, "# computed"),
               call({M, :computed, 1}, {:dynamic, :f, 1, :call}, :remote, "# computed")
             ]
    end
  end

  describe "walk/3 dynamic captures and shapes Core builds by hand" do
    test "a capture through a variable module is a dynamic :capture", %{binary: binary} do
      assert calls(binary, {:dyncap, 1}) ==
               [call({M, :dyncap, 1}, {:dynamic, :f, 1, :variable}, :capture, "# dyncap")]
    end

    # Hand-built Core, because Elixir 1.19 (with :no_copt) emits these shapes
    # only after Core optimisation; the walker must read them all the same.
    test "a variable let-bound to a literal module resolves to a :remote call" do
      var = :cerl.c_var(:mod)
      body = :cerl.c_let([var], :cerl.c_atom(Other), :cerl.c_call(var, :cerl.c_atom(:f), []))

      assert {[%Call{to: {Other, :f, 0}, kind: :remote}], []} =
               CoreWalker.walk(M, {:g, 0}, :cerl.c_fun([], body), 1)
    end

    test "a literal external fun is a :capture" do
      body = :cerl.abstract(&Enum.count/1)

      assert {[%Call{to: {Enum, :count, 1}, kind: :capture}], []} =
               CoreWalker.walk(M, {:g, 0}, :cerl.c_fun([], body), 1)
    end

    test "a struct inside a literal term is a :build of that struct" do
      body = :cerl.abstract([{:ok, %{__struct__: S, a: 1}}])

      assert {[], [%StructUse{struct: S, op: :build, line: 1, line_source: :def}]} =
               CoreWalker.walk(M, {:g, 0}, :cerl.c_fun([], body), 1)
    end

    test "a struct map built on a variable (not on %{}) is an :update" do
      s = :cerl.c_var(:s)
      pair = :cerl.c_map_pair(:cerl.c_atom(:__struct__), :cerl.c_atom(S))
      body = :cerl.ann_c_map([{3, 1}], s, [pair])

      assert {[], [%StructUse{struct: S, op: :update, line: 3, line_source: :call}]} =
               CoreWalker.walk(M, {:g, 1}, :cerl.c_fun([s], body), 1)
    end

    test "structs inside one literal come out in term order" do
      body = :cerl.abstract([%{__struct__: S}, %{__struct__: Other}])

      assert {[], [%StructUse{struct: S}, %StructUse{struct: Other}]} =
               CoreWalker.walk(M, {:g, 0}, :cerl.c_fun([], body), 1)
    end

    test "applying an expression that is not a variable is :apply through :call" do
      x = :cerl.c_var(:x)
      body = :cerl.c_apply(:cerl.c_fun([x], x), [:cerl.c_int(1)])

      assert {[%Call{to: {:dynamic, nil, 1, :call}, kind: :apply}], []} =
               CoreWalker.walk(M, {:g, 0}, :cerl.c_fun([], body), 1)
    end
  end

  describe "walk/3 through every form Core lowers (AC6)" do
    # Row 26: each source call site is one edge with its own line.
    test "no call is lost in heads, guards, with, if, cond, case, fn, try, receive, for", %{
      binary: binary
    } do
      calls = calls(binary, {:lowered, 2})

      # One {name, line} per source call site, Other.c1 .. Other.c16.
      expected = for n <- 1..16, do: {:"c#{n}", line("Other.c#{n}(")}

      found =
        for %Call{to: {Other, name, 1}, kind: :remote, line: line, line_source: :call} <- calls,
            do: {name, line}

      assert Enum.sort(found) == Enum.sort(expected)

      guard_line = line("# lowered head")

      assert %Call{kind: :remote, line: ^guard_line, line_source: :call} =
               Enum.find(calls, &(&1.to == {:erlang, :is_map, 1}))

      refute Enum.any?(calls, &(&1.kind == :local)),
             "the letrec loop Core makes of a receive is part of the function, not a local call"
    end
  end

  describe "walk/3 struct uses (AC2)" do
    # Row 27
    test "a struct literal and a struct built from values are :build", %{binary: binary} do
      assert uses(binary, {:build, 0}) == [
               %StructUse{
                 from: {M, :build, 0},
                 struct: S,
                 op: :build,
                 line: line("# build literal"),
                 line_source: :call
               }
             ]

      assert uses(binary, {:build_var, 1}) == [
               %StructUse{
                 from: {M, :build_var, 1},
                 struct: S,
                 op: :build,
                 line: line("# build var"),
                 line_source: :call
               }
             ]
    end

    # Row 28: in a multi-clause function (one clause also matches %S{} in its
    # head) and inside with.
    test "a struct update is :update, in each clause and inside with", %{binary: binary} do
      assert uses(binary, {:update, 2}) == [
               %StructUse{
                 from: {M, :update, 2},
                 struct: S,
                 op: :match,
                 line: line("# update clause 1"),
                 line_source: :call
               },
               %StructUse{
                 from: {M, :update, 2},
                 struct: S,
                 op: :update,
                 line: line("# update clause 1"),
                 line_source: :call
               },
               %StructUse{
                 from: {M, :update, 2},
                 struct: S,
                 op: :update,
                 line: line("# update clause 2"),
                 line_source: :call
               }
             ]

      assert uses(binary, {:update_with, 1}) == [
               %StructUse{
                 from: {M, :update_with, 1},
                 struct: S,
                 op: :update,
                 line: line("# update with"),
                 line_source: :call
               }
             ]
    end

    # Row 29
    test "a struct in a pattern is :match", %{binary: binary} do
      assert uses(binary, {:match, 1}) == [
               %StructUse{
                 from: {M, :match, 1},
                 struct: S,
                 op: :match,
                 line: line("# match"),
                 line_source: :call
               }
             ]
    end

    # Row 30 (its positive control is every row above that finds a struct use)
    test "a plain map and a plain map update are no struct use", %{binary: binary} do
      assert uses(binary, {:plain, 1}) == []
      assert Enum.any?(calls(binary, {:plain, 1}), &(&1.to == {Other, :f, 1}))
    end
  end

  describe "walk/4 line fallback" do
    # Row 31: a hand-built Core fun carries no annotation at all.
    test "a node with no line gets the def line, flagged :def" do
      fun = :cerl.c_fun([], :cerl.c_call(:cerl.c_atom(Other), :cerl.c_atom(:f), []))

      assert CoreWalker.walk(M, {:f, 0}, fun, 7) ==
               {[
                  %Call{
                    from: {M, :f, 0},
                    to: {Other, :f, 0},
                    kind: :remote,
                    line: 7,
                    line_source: :def
                  }
                ], []}
    end

    test "line 0 is no line: the edge gets the def line, flagged :def" do
      call = :cerl.ann_c_call([0], :cerl.c_atom(Other), :cerl.c_atom(:f), [])
      fun = :cerl.c_fun([], call)

      assert {[%Call{line: 7, line_source: :def}], []} = CoreWalker.walk(M, {:f, 0}, fun, 7)
    end

    test "with no def line given, the c_fun's own line is the def line" do
      call = :cerl.c_call(:cerl.c_atom(Other), :cerl.c_atom(:f), [])
      fun = :cerl.ann_c_fun([{12, 3}], [], call)

      assert {[%Call{line: 12, line_source: :def}], []} = CoreWalker.walk(M, {:f, 0}, fun)
    end
  end
end
