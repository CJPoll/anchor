defmodule Anchor.Domain.Aggregates.ScopesTest do
  # DND-5459: transaction scopes and their write sets over the call closure,
  # built through Analysis.build/3 on fixtures compiled in the test.
  #
  # Sabotage record: ../../../sabotage_records/aggregates-20261103-dnd_5459_write_sets.md
  use ExUnit.Case, async: true

  import Anchor.Test.WriteFixtures

  alias Anchor.Domain.Aggregates.Analysis
  alias Anchor.Domain.Aggregates.Config
  alias Anchor.Domain.Aggregates.Scope
  alias Anchor.Domain.FunctionRef
  alias Anchor.Test.BeamFixtures

  @ns AnchorFixtures.ScopesTest
  @s Module.concat(@ns, S)
  @t Module.concat(@ns, T)
  @u Module.concat(@ns, U)
  @repo Module.concat(@ns, Repo)
  @helper Module.concat(@ns, Helper)
  @builder Module.concat(@ns, Builder)
  @uow Module.concat(@ns, UoW)
  @x Module.concat(@ns, X)

  @x_source """
  defmodule #{inspect(@x)} do
    alias #{inspect(@repo)}
    alias #{inspect(@s)}
    alias #{inspect(@t)}
    alias #{inspect(@u)}
    alias #{inspect(@helper)}
    alias #{inspect(@builder)}
    alias Ecto.Multi

    def s1, do: Repo.transaction(fn -> Repo.insert(%S{}); Helper.write_t() end)

    def s2, do: Repo.transaction(&__MODULE__.work/0)
    def work, do: Repo.insert(%U{})

    def s3 do
      Multi.new()
      |> Multi.insert(:a, %S{})
      |> Builder.add_t()
      |> Repo.transaction()
    end

    def s4 do
      Multi.new()
      |> Multi.run(:u, fn repo, _ -> repo.insert(%U{}) end)
      |> Repo.transaction()
    end

    def s5, do: #{inspect(@uow)}.transaction(Repo, fn -> Repo.insert(%S{}) end)

    def s6(fun), do: Repo.transaction(fn -> Repo.insert(%S{}); fun.() end)

    def s7(x), do: Repo.transaction(fn -> Repo.insert(x) end)

    def s8, do: Repo.transaction(fn -> Helper.a(3) end)

    def s9, do: Repo.transaction(fn -> Repo.insert(%S{}); Helper.inner() end)

    def s10(m), do: Repo.transaction(m)

    def s11 do
      Repo.transaction(fn -> Repo.insert(%S{}) end)
      Repo.transaction(fn -> Repo.insert(%T{}) end)
    end

    def s12(xs), do: Repo.transaction(fn -> Enum.each(xs, &Helper.write_s/1) end)

    def s13(x), do: Repo.transaction(fn -> Repo.insert(%S{}); JSON.encode!(x) end)

    def s14, do: Repo.transaction(fn -> Repo.insert(%S{}); Repo.query!("UPDATE t SET x = 1") end)

    def s15 do
      Multi.new()
      |> Multi.run(:sql, fn repo, _ -> repo.query("DELETE FROM t") end)
      |> Repo.transaction()
    end

    def s16, do: Repo.transaction(fn -> Ecto.Adapters.SQL.query!(Repo, "DELETE FROM t", []) end)

    def s17, do: Repo.transaction(fn -> Helper.inner_calls() end)
  end
  """

  @source schema(@s, "s") <>
            schema(@t, "t") <>
            schema(@u, "u") <>
            repo(@repo) <>
            """
            defmodule #{inspect(@helper)} do
              alias #{inspect(@repo)}
              def write_t, do: Repo.insert(%#{inspect(@t)}{})
              def write_s(_x), do: Repo.insert(%#{inspect(@s)}{})
              def a(0), do: Repo.insert(%#{inspect(@s)}{})
              def a(n), do: b(n - 1)
              def b(n), do: (Repo.insert(%#{inspect(@t)}{}); a(n))
              def inner, do: Repo.transaction(fn -> Repo.insert(%#{inspect(@t)}{}) end)
              def inner_calls, do: Repo.transaction(fn -> write_t() end)
            end

            defmodule #{inspect(@builder)} do
              def add_t(m), do: Ecto.Multi.insert(m, :b, %#{inspect(@t)}{})
            end

            defmodule #{inspect(@uow)} do
              def transaction(repo, fun), do: repo.transaction(fun)
            end
            """ <> @x_source

  setup_all do
    graph = graph!(@source)

    config = %Config{
      repos: [@repo],
      transaction_functions: [elem(FunctionRef.parse("#{inspect(@uow)}.transaction/2"), 1)]
    }

    %{analysis: Analysis.build(graph, config)}
  end

  defp scopes(analysis, name),
    do: Enum.filter(analysis.scopes, &(&1.mfa == {@x, name, arity(name)}))

  defp arity(name) when name in [:s6, :s7, :s10, :s12, :s13], do: 1
  defp arity(_name), do: 0

  defp one(analysis, name) do
    case scopes(analysis, name) do
      [scope] -> scope
      other -> flunk("expected one scope in #{name}, got #{inspect(other)}")
    end
  end

  defp keys(modules), do: MapSet.new(modules, &{:schema, &1})

  describe "build/3" do
    test "S1: a fun scope holds its own writes and a callee's in another module", %{analysis: a} do
      assert %Scope{kind: :fun, complete?: true, gaps: []} = scope = one(a, :s1)
      assert scope.keys == keys([@s, @t])
      assert scope.line == BeamFixtures.line_of(@source, "def s1,")
    end

    test "S2: a captured function is the scope's body", %{analysis: a} do
      assert %Scope{kind: :fun, complete?: true} = scope = one(a, :s2)
      assert scope.keys == keys([@u])
    end

    test "S3: a Multi traced through a helper that adds a step", %{analysis: a} do
      assert %Scope{kind: :multi, complete?: true} = scope = one(a, :s3)
      assert scope.keys == keys([@s, @t])
    end

    test "S4: a Multi.run callback's writes are in the Multi's scope", %{analysis: a} do
      assert %Scope{kind: :multi} = scope = one(a, :s4)
      assert MapSet.member?(scope.keys, {:schema, @u})
    end

    test "S5: a transaction_functions call is a scope", %{analysis: a} do
      assert %Scope{kind: :transaction_function, complete?: true} = scope = one(a, :s5)
      assert scope.keys == keys([@s])
    end

    test "S6: a call of a fun parameter makes the scope incomplete, at its line", %{analysis: a} do
      assert %Scope{complete?: false, gaps: [{:dynamic_call, {@x, :s6, 1}, line}]} = one(a, :s6)
      assert line == BeamFixtures.line_of(@source, "def s6(")
      assert one(a, :s6).keys == keys([@s])
    end

    test "S7: an unresolved write in the closure makes the scope incomplete", %{analysis: a} do
      assert %Scope{complete?: false, gaps: [{:unresolved_write, site}]} = one(a, :s7)
      assert site.mfa == {@x, :s7, 1}
    end

    test "S8: recursion terminates, and the keys are the union", %{analysis: a} do
      assert %Scope{complete?: true} = scope = one(a, :s8)
      assert scope.keys == keys([@s, @t])
    end

    test "S9: an outer scope holds a callee's inner transaction; the inner one is its own", %{
      analysis: a
    } do
      assert one(a, :s9).keys == keys([@s, @t])

      assert [%Scope{keys: inner}] = Enum.filter(a.scopes, &(&1.mfa == {@helper, :inner, 0}))
      assert inner == keys([@t])
    end

    test "an outer scope follows the calls inside a callee's inner transaction", %{analysis: a} do
      assert one(a, :s17).keys == keys([@t])
    end

    test "S10: a Multi parameter with nothing to trace is incomplete at the call", %{analysis: a} do
      assert %Scope{complete?: false, gaps: [{:dynamic_call, {@x, :s10, 1}, line}]} = one(a, :s10)
      assert line == BeamFixtures.line_of(@source, "def s10(")
    end

    test "S11: two scopes in one function are ordinals 1 and 2 in Core order", %{analysis: a} do
      assert [%Scope{ordinal: 1} = first, %Scope{ordinal: 2} = second] =
               a |> scopes(:s11) |> Enum.sort_by(& &1.ordinal)

      assert first.keys == keys([@s])
      assert second.keys == keys([@t])
    end

    test "S11: ordinals do not move when lines do (positive control: the lines do)", %{
      analysis: a
    } do
      moved = String.replace(@source, "  def s11 do", "\n\n\n  def s11 do")
      graph = graph!(moved)
      config = %Config{repos: [@repo]}
      shifted = Analysis.build(graph, config)

      before = a |> scopes(:s11) |> Enum.sort_by(& &1.ordinal)
      after_move = shifted |> scopes(:s11) |> Enum.sort_by(& &1.ordinal)

      assert Enum.map(after_move, &{&1.ordinal, &1.keys}) ==
               Enum.map(before, &{&1.ordinal, &1.keys})

      assert Enum.map(after_move, & &1.line) == Enum.map(before, &(&1.line + 3))
    end

    test "S12: a capture passed to Enum is followed", %{analysis: a} do
      assert one(a, :s12).keys == keys([@s])
      assert one(a, :s12).complete?
    end

    test "S13: a call into a dependency is not followed, and the scope stays complete", %{
      analysis: a
    } do
      assert %Scope{complete?: true, gaps: []} = scope = one(a, :s13)
      assert scope.keys == keys([@s])
    end
  end

  # Code-review finding: raw SQL writes what Anchor cannot attribute, so it
  # is a gap, never a complete scope missing a write.
  describe "raw SQL" do
    for {name, def_text} <- [
          s14: "def s14,",
          s15: "|> Multi.run(:sql,",
          s16: "def s16,"
        ] do
      @tag name: name, def_text: def_text
      test "S14: raw SQL in #{name} makes its scope incomplete, at the call's line", %{
        analysis: a,
        name: name,
        def_text: def_text
      } do
        assert %Scope{complete?: false, gaps: [{:dynamic_call, {@x, ^name, 0}, line}]} =
                 one(a, name)

        assert line == BeamFixtures.line_of(@source, def_text)
      end
    end
  end

  test "counts: writes found, resolved, unresolved; scopes, complete, incomplete", %{analysis: a} do
    assert a.counts.scopes == length(a.scopes)
    assert a.counts.incomplete == Enum.count(a.scopes, &(not &1.complete?))
    assert a.counts.writes == length(a.sites)
    assert a.counts.unresolved == 1
    assert a.counts.resolved == a.counts.writes - 1
  end
end
