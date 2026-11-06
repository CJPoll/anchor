defmodule Anchor.Domain.Aggregates.ScopesTest do
  # DND-5459: transaction scopes and their write sets over the call closure,
  # built through Analysis.build/3 on fixtures compiled in the test.
  #
  # Sabotage record: ../../../sabotage_records/aggregates-20261103-dnd_5459_write_sets.md
  # and ../../../sabotage_records/aggregates-20261106-dnd_5459_write_sets.md
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
  @custom_repo Module.concat(@ns, CustomRepo)
  @lib Module.concat(@ns, Lib)

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

    def s13(x), do: Repo.transaction(fn -> Repo.insert(%S{}); Code.ensure_loaded(x) end)

    def s14, do: Repo.transaction(fn -> Repo.insert(%S{}); Repo.query!("UPDATE t SET x = 1") end)

    def s15 do
      Multi.new()
      |> Multi.run(:sql, fn repo, _ -> repo.query("DELETE FROM t") end)
      |> Repo.transaction()
    end

    def s16, do: Repo.transaction(fn -> Ecto.Adapters.SQL.query!(Repo, "DELETE FROM t", []) end)

    def s17, do: Repo.transaction(fn -> Helper.inner_calls() end)

    def s18 do
      f = fn -> Repo.insert(%S{}) end
      Repo.transaction(fn -> f.() end)
    end

    def s19, do: Repo.transaction(fn -> f = fn -> Repo.insert(%S{}) end; f.() end)

    def s20(xs, fun), do: Repo.transaction(fn -> Repo.insert(%S{}); Enum.each(xs, fun) end)

    def s21(xs, mod), do: Repo.transaction(fn -> Enum.each(xs, &mod.write/1) end)

    def s22(xs) do
      f = fn _x -> Repo.insert(%S{}) end
      Repo.transaction(fn -> Enum.each(xs, f) end)
    end

    def s23(xs), do: Repo.transaction(fn -> Enum.each(xs, fn x -> Repo.insert(x) end) end)

    def s24(xs), do: Repo.transaction(fn -> Enum.each(xs, &Repo.insert/1) end)

    def s25, do: Repo.transaction(fn -> #{inspect(@custom_repo)}.soft(%S{}) end)

    def s26, do: Repo.transaction(fn -> #{inspect(@custom_repo)}.missing(%S{}) end)

    def s27 do
      Multi.new()
      |> Multi.run(:a, fn repo, _ -> repo.soft(%S{}) end)
      |> Repo.transaction()
    end

    def s28, do: Repo.transaction(fn -> Repo.get(S, 1); Repo.all(T); Repo.insert(%S{}) end)

    def s29(xs, acc), do: Repo.transaction(fn -> Enum.reduce(xs, acc, fn x, a -> [x | a] end) end)

    def s30(xs), do: Repo.transaction(fn -> Enum.each(xs, Helper.fun()) end)

    def s31(xs, fun), do: Repo.transaction(fn -> Enum.sort_by(xs, fun, :desc) end)

    def s32(xs), do: Repo.transaction(fn -> Repo.insert(%S{}); Enum.count(xs) end)

    def s33(xs), do: Repo.transaction(fn -> Enum.each(xs, &Helper.audit/1) end)

    def s34(mod), do: Repo.transaction(fn -> Helper.take(&mod.write/1) end)

    def s36(xs), do: Repo.transaction(fn -> Enum.sort_by(xs, fn x -> x end, :desc) end)

    def s37, do: Repo.transaction(fn -> #{inspect(@custom_repo)}.one(%S{}) end)

    def s38(xs) do
      f = &Helper.write_s/1
      Repo.transaction(fn -> Enum.each(xs, f) end)
    end

    def s39(xs) do
      f = &Repo.insert/1
      Repo.transaction(fn -> Enum.each(xs, f) end)
    end

    def s40(xs, fun), do: Repo.transaction(fn -> Enum.into(xs, %{}, fun) end)

    def s41(xs, fun) do
      m = Enum
      Repo.transaction(fn -> apply(m, :each, [xs, fun]) end)
    end

    def atomically(fun), do: fun.()
    def s42, do: atomically(fn -> Repo.insert(%S{}) end)

    def local_write(x), do: x
    def s44, do: Repo.transaction(fn -> local_write(%T{}) end)

    def s45, do: Repo.transaction(fn -> #{inspect(@lib)}.flush() end)

    def flush_here, do: Repo.insert(%U{})
    def s46, do: Repo.transaction(fn -> flush_here() end)

    def s47 do
      Multi.new()
      |> Multi.merge(fn _ -> Multi.new() end)
      |> Repo.transaction()
    end

    def s48(f), do: Repo.transaction(Builder.add_merge(Multi.new(), f))
    def s49(f), do: Repo.transaction(Builder.add_run(Multi.new(), f))
    def s50(m), do: Repo.transaction(Builder.add_t(m))
    def s51(attrs), do: Repo.transaction(Builder.add_attrs(Multi.new(), attrs))
    def s52, do: Repo.transaction(Builder.named(:a))
    def s53(mod, f), do: Repo.transaction(Builder.add_run5(Multi.new(), mod, f))

    defp local_build(attrs), do: Multi.insert(Multi.new(), {:c, attrs}, %T{})
    defp local_add(m), do: Multi.insert(m, :b, %T{})
    def s54(attrs), do: Repo.transaction(local_build(attrs))

    def s55 do
      Multi.new()
      |> Multi.insert(:a, %S{})
      |> local_add()
      |> Repo.transaction()
    end

    def s56(attrs), do: Repo.transaction(Builder.build(attrs))
    def s57(m), do: Repo.transaction(local_add(m))

    def s58(xs) do
      sorter = :desc
      Repo.transaction(fn -> Enum.sort(xs, sorter) end)
    end

    def s59(other), do: Repo.transaction(Builder.add_append(Multi.new(), other))

    def s60 do
      Multi.new()
      |> Multi.append(Multi.insert(Multi.new(), :a, %S{}))
      |> Repo.transaction()
    end

    def s61 do
      Multi.new()
      |> Multi.insert(:a, %T{})
      |> Multi.prepend(Multi.insert(Multi.new(), :b, %S{}))
      |> Repo.transaction()
    end

    def s62(other), do: Repo.transaction(Multi.append(Multi.new(), other))

    def s63, do: Repo.transaction(fn -> Task.async(fn -> Repo.insert(%S{}) end) end)
    def s64, do: Repo.transaction(fn -> spawn(fn -> Repo.insert(%S{}) end) end)
    def s65, do: Task.async(fn -> Repo.insert(%S{}) end)

    def s66(other), do: Repo.transaction(Builder.append_to_new(other))

    defp spawns_write, do: Task.async(fn -> Repo.insert(%S{}) end)
    def s67, do: Repo.transaction(fn -> spawns_write() end)
    def s68(pid), do: Repo.transaction(fn -> Agent.update(pid, fn _ -> Repo.insert(%S{}) end) end)
    def s69, do: Repo.transaction(fn -> Process.spawn(fn -> Repo.insert(%S{}) end, []) end)

    def wrap(rec), do: Repo.update(rec)
    def s70, do: wrap(%S{})

    def s71(fun), do: Repo.transaction(fn -> Helper.tx_any(fun) end)
    def s72(fun), do: Repo.transaction(fn -> Repo.transaction(fun) end)
    def s90, do: Repo.transaction(&#{inspect(@lib)}.flush/0)

    def s91 do
      Repo.transaction(&#{inspect(@lib)}.flush/0)
      Task.start(&#{inspect(@lib)}.flush/0)
    end

    def wrapper_tx(fun), do: Repo.transaction(fun)
    def s82, do: Repo.transaction(fn -> atomically(fn -> Repo.insert(%S{}) end) end)
    def s83, do: Repo.transaction(fn -> wrapper_tx(fn -> Repo.insert(%S{}) end) end)
    def s84(fun), do: Repo.transaction(fn -> Repo.checkout(fun) end)
    def s85(fun), do: Repo.transaction(Multi.run(Multi.new(), :a, fn repo, _ -> repo.transaction(fun) end))
    def s86, do: Repo.transaction(fn -> Repo.checkout(fn -> Repo.insert(%S{}) end) end)
    def s87, do: Repo.transaction(Multi.run(Multi.new(), :a, fn repo, _ -> repo.checkout(&s87_step/0) end))
    def s87_step, do: Repo.insert(%S{})
    def s88(m), do: Repo.transaction(Multi.run(Multi.new(), :a, fn repo, _ -> repo.transaction(m, []) end))
    def s89, do: Repo.transaction(fn -> Repo.checkout(&s87_step/0) end)
    def s80, do: Repo.transaction(fn -> #{inspect(@custom_repo)}.transact(fn -> :ok end) end)
    def s74(sqls), do: Repo.transaction(fn -> Enum.each(sqls, &Repo.query!/1) end)
    def s75(sqls), do: Repo.transaction(fn -> Enum.map(sqls, &Ecto.Adapters.SQL.query!(Repo, &1)) end)
    def s76(sqls), do: Repo.transaction(fn -> Enum.each(sqls, &Ecto.Adapters.SQL.query!/1) end)
    def s77(args), do: Repo.transaction(fn -> apply(Repo, :transaction, args) end)

    def s78(fun) do
      args = [fun]
      Repo.transaction(fn -> apply(Repo, :transaction, args) end)
    end

    def s79(m) do
      args = [m, :a, fn _, _ -> {:ok, 1} end]
      Repo.transaction(fn -> apply(Multi, :run, args) end)
    end

    def s73(fun), do: Repo.transaction(fn -> local_unread(fun) end)
    defp local_unread(fun), do: atomically(fun)

    def s35 do
      Multi.new()
      |> Multi.run(:a, fn repo, _ -> repo.get(S, 1); repo.insert(%S{}) end)
      |> Repo.transaction()
    end
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
              def tx_any(fun), do: Repo.transaction(fun)
              def fun, do: &write_s/1
              def audit(x), do: x
              def take(x), do: x
            end

            defmodule #{inspect(@custom_repo)} do
              def insert(x, _opts \\\\ []), do: x
              def update(x, _opts \\\\ []), do: x
              def soft(x), do: update(x)
              def transaction(fun), do: fun.()
              def with_tx, do: transaction(fn -> update(%#{inspect(@s)}{}) end)
              def reload(x), do: update(x)
              def query(x), do: update(x)
            end

            defmodule #{inspect(@builder)} do
              def add_t(m), do: Ecto.Multi.insert(m, :b, %#{inspect(@t)}{})
              def add_merge(m, f), do: Ecto.Multi.merge(m, f)
              def add_append(m, other), do: Ecto.Multi.append(m, other)
              def append_to_new(other), do: Ecto.Multi.append(Ecto.Multi.new(), other)
              def build(attrs), do: Ecto.Multi.insert(Ecto.Multi.new(), {:d, attrs}, %#{inspect(@t)}{})
              def add_run(m, f), do: Ecto.Multi.run(m, :r, f)
              def add_run5(m, mod, f), do: Ecto.Multi.run(m, :r, mod, f, [])
              def add_attrs(m, attrs), do: Ecto.Multi.insert(m, {:c, attrs}, %#{inspect(@t)}{})
              def named(name), do: Ecto.Multi.insert(Ecto.Multi.new(), name, %#{inspect(@t)}{})
            end

            defmodule #{inspect(@uow)} do
              def transaction(repo, fun), do: repo.transaction(fun)
            end
            """ <> @x_source

  setup_all do
    graph = graph!(@source)

    config = %Config{
      repos: [@repo, @custom_repo],
      write_functions: [
        elem(FunctionRef.parse("#{inspect(@helper)}.audit/1"), 1),
        elem(FunctionRef.parse("#{inspect(@x)}.local_write/1"), 1),
        elem(FunctionRef.parse("#{inspect(@x)}.wrap/1"), 1),
        elem(FunctionRef.parse("#{inspect(@lib)}.flush/0"), 1),
        elem(FunctionRef.parse("#{inspect(@x)}.flush_here/0"), 1)
      ],
      transaction_functions: [
        elem(FunctionRef.parse("#{inspect(@uow)}.transaction/2"), 1),
        elem(FunctionRef.parse("#{inspect(@x)}.atomically/1"), 1),
        elem(FunctionRef.parse("#{inspect(@x)}.wrapper_tx/1"), 1)
      ]
    }

    %{analysis: Analysis.build(graph, config)}
  end

  defp scopes(analysis, name),
    do: Enum.filter(analysis.scopes, &(&1.mfa == {@x, name, arity(name)}))

  defp arity(name) when name in [:s20, :s21, :s29, :s31, :s40, :s41, :s53], do: 2

  defp arity(name)
       when name in [
              :s6,
              :s7,
              :s10,
              :s12,
              :s13,
              :s22,
              :s23,
              :s24,
              :s30,
              :s32,
              :s33,
              :s34,
              :s36,
              :s38,
              :s39
            ],
       do: 1

  defp arity(name)
       when name in [
              :s48,
              :s49,
              :s50,
              :s51,
              :s54,
              :s56,
              :s57,
              :s58,
              :s59,
              :s62,
              :s66,
              :s68,
              :s71,
              :s72,
              :s73,
              :s84,
              :s85,
              :s88,
              :s74,
              :s75,
              :s76,
              :s77,
              :s78,
              :s79
            ],
       do: 1

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
      assert %Scope{kind: :fun, no_gap_noticed?: true, gaps: []} = scope = one(a, :s1)
      assert scope.keys == keys([@s, @t])
      assert scope.line == BeamFixtures.line_of(@source, "def s1,")
    end

    test "S2: a captured function is the scope's body", %{analysis: a} do
      assert %Scope{kind: :fun, no_gap_noticed?: true} = scope = one(a, :s2)
      assert scope.keys == keys([@u])
    end

    test "S3: a Multi traced through a helper that adds a step", %{analysis: a} do
      assert %Scope{kind: :multi, no_gap_noticed?: true} = scope = one(a, :s3)
      assert scope.keys == keys([@s, @t])
    end

    test "S4: a Multi.run callback's writes are in the Multi's scope", %{analysis: a} do
      assert %Scope{kind: :multi} = scope = one(a, :s4)
      assert MapSet.member?(scope.keys, {:schema, @u})
    end

    test "S5: a transaction_functions call is a scope", %{analysis: a} do
      assert %Scope{kind: :transaction_function, no_gap_noticed?: true} = scope = one(a, :s5)
      assert scope.keys == keys([@s])
    end

    test "S6: a call of a fun parameter makes the scope incomplete, at its line", %{analysis: a} do
      assert %Scope{no_gap_noticed?: false, gaps: [{:dynamic_call, {@x, :s6, 1}, line}]} =
               one(a, :s6)

      assert line == BeamFixtures.line_of(@source, "def s6(")
      assert one(a, :s6).keys == keys([@s])
    end

    test "S7: an unresolved write in the closure makes the scope incomplete", %{analysis: a} do
      assert %Scope{no_gap_noticed?: false, gaps: [{:unresolved_write, site}]} = one(a, :s7)
      assert site.mfa == {@x, :s7, 1}
    end

    test "S8: recursion terminates, and the keys are the union", %{analysis: a} do
      assert %Scope{no_gap_noticed?: true} = scope = one(a, :s8)
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

    test "a fn defined outside the body and called in it makes the scope incomplete", %{
      analysis: a
    } do
      assert %Scope{no_gap_noticed?: false, gaps: [{:dynamic_call, {@x, :s18, 0}, line}]} =
               one(a, :s18)

      assert line == BeamFixtures.line_of(@source, "Repo.transaction(fn -> f.() end)")
    end

    test "a fn defined and called in the body is in the scope (positive control)", %{analysis: a} do
      assert %Scope{no_gap_noticed?: true} = scope = one(a, :s19)
      assert scope.keys == keys([@s])
    end

    test "a fun parameter handed to Enum in the body makes the scope incomplete", %{analysis: a} do
      assert %Scope{no_gap_noticed?: false, gaps: [{:dynamic_call, {@x, :s20, 2}, _line}]} =
               one(a, :s20)

      assert one(a, :s20).keys == keys([@s])
    end

    test "a capture on a module held in a variable makes the scope incomplete", %{analysis: a} do
      assert %Scope{no_gap_noticed?: false, gaps: [{:dynamic_call, {@x, :s21, 2}, _line}]} =
               one(a, :s21)
    end

    test "a fn from outside the body handed to Enum in it makes the scope incomplete", %{
      analysis: a
    } do
      assert %Scope{no_gap_noticed?: false, gaps: [{:dynamic_call, {@x, :s22, 1}, _line}]} =
               one(a, :s22)
    end

    test "an inline fn handed to Enum in the body is walked, with no gap of its own", %{
      analysis: a
    } do
      assert [{:unresolved_write, %{mfa: {@x, :s23, 1}}}] = one(a, :s23).gaps
      assert %Scope{no_gap_noticed?: true} = one(a, :s29)
    end

    test "a capture of a Repo write makes the scope incomplete: its source is unseen", %{
      analysis: a
    } do
      assert %Scope{no_gap_noticed?: false, gaps: [{:dynamic_call, {@x, :s24, 1}, _line}]} =
               one(a, :s24)
    end

    test "a function written on a repo is followed: its own writes are in the scope", %{
      analysis: a
    } do
      assert %Scope{no_gap_noticed?: true} = scope = one(a, :s25)
      assert scope.keys == keys([@s])
    end

    test "only a function written on a repo is read for its calls, not what Ecto generates", %{
      analysis: a
    } do
      assert a.sites |> Enum.filter(&(elem(&1.mfa, 0) == @custom_repo)) |> Enum.map(& &1.mfa) ==
               [{@custom_repo, :soft, 1}, {@custom_repo, :with_tx, 0}]
    end

    test "a function value made by a call, handed to Enum, makes the scope incomplete", %{
      analysis: a
    } do
      assert %Scope{no_gap_noticed?: false, gaps: [{:dynamic_call, {@x, :s30, 1}, _line}]} =
               one(a, :s30)
    end

    test "the function is found before a trailing literal", %{analysis: a} do
      assert %Scope{no_gap_noticed?: false, gaps: [{:dynamic_call, {@x, :s31, 2}, _line}]} =
               one(a, :s31)
    end

    test "an inline fn before a trailing literal is walked, with no gap", %{analysis: a} do
      assert %Scope{no_gap_noticed?: true} = one(a, :s36)
    end

    test "a function Ecto generates needs no body in the beam: no gap", %{analysis: a} do
      assert %Scope{no_gap_noticed?: true} = one(a, :s37)
    end

    test "a capture from outside the body, handed to Enum in it, is followed", %{analysis: a} do
      assert %Scope{no_gap_noticed?: true} = scope = one(a, :s38)
      assert scope.keys == keys([@s])
    end

    test "a capture of a write from outside the body, handed in it, is a gap", %{analysis: a} do
      assert %Scope{no_gap_noticed?: false, gaps: [{:dynamic_call, {@x, :s39, 1}, _line}]} =
               one(a, :s39)
    end

    test "every function HigherOrder knows takes a function: Enum.into/3", %{analysis: a} do
      assert %Scope{no_gap_noticed?: false, gaps: [{:dynamic_call, {@x, :s40, 2}, _line}]} =
               one(a, :s40)
    end

    test "an apply of a function-taking call hides its arguments, so it is a gap", %{analysis: a} do
      assert %Scope{no_gap_noticed?: false, gaps: [{:dynamic_call, {@x, :s41, 2}, _line}]} =
               one(a, :s41)
    end

    test "a local call of a transaction function is a scope", %{analysis: a} do
      assert %Scope{kind: :transaction_function, no_gap_noticed?: true} = scope = one(a, :s42)
      assert scope.keys == keys([@s])
    end

    test "a local Repo.transaction, in a function written on the repo, is a scope", %{
      analysis: a
    } do
      assert [%Scope{kind: :fun} = scope] =
               Enum.filter(a.scopes, &(&1.mfa == {@custom_repo, :with_tx, 0}))

      assert scope.keys == keys([@s])
    end

    test "a local call of a write function is a write", %{analysis: a} do
      assert %Scope{no_gap_noticed?: true} = scope = one(a, :s44)
      assert scope.keys == keys([@t])
    end

    test "a zero-arity write function in a library is an unresolved write, never dropped", %{
      analysis: a
    } do
      assert %Scope{no_gap_noticed?: false, gaps: [{:unresolved_write, site}]} = one(a, :s45)
      assert site.unresolved == "a write with no source argument"
    end

    test "a zero-arity write function in the project is followed", %{analysis: a} do
      assert %Scope{no_gap_noticed?: true} = scope = one(a, :s46)
      assert scope.keys == keys([@u])
    end

    test "Multi.merge builds steps at run time: incomplete, in the function", %{analysis: a} do
      assert %Scope{kind: :multi, no_gap_noticed?: false} = one(a, :s47)
    end

    test "Multi.merge or a Multi.run of an unknown function, in a helper, is a gap too", %{
      analysis: a
    } do
      assert %Scope{no_gap_noticed?: false, gaps: [{:dynamic_call, {@builder, :add_merge, 2}, _}]} =
               one(a, :s48)

      assert %Scope{no_gap_noticed?: false, gaps: [{:dynamic_call, {@builder, :add_run, 2}, _}]} =
               one(a, :s49)

      assert %Scope{no_gap_noticed?: false, gaps: [{:dynamic_call, {@builder, :add_run5, 3}, _}]} =
               one(a, :s53)
    end

    test "a helper given only a Multi Anchor cannot trace is a gap at the transaction", %{
      analysis: a
    } do
      assert %Scope{no_gap_noticed?: false, gaps: [{:dynamic_call, {@x, :s50, 1}, _}]} =
               one(a, :s50)
    end

    test "a helper given a traced Multi and data, or only literals, stays complete", %{
      analysis: a
    } do
      assert %Scope{no_gap_noticed?: true} = one(a, :s51)
      assert %Scope{no_gap_noticed?: true} = scope = one(a, :s52)
      assert scope.keys == keys([@t])
    end

    test "a Multi built by a local helper is traced, its helper's writes in the scope", %{
      analysis: a
    } do
      assert %Scope{kind: :multi, no_gap_noticed?: true} = scope = one(a, :s54)
      assert scope.keys == keys([@t])
      assert %Scope{kind: :multi, no_gap_noticed?: true} = scope = one(a, :s55)
      assert scope.keys == keys([@s, @t])
    end

    test "a helper that makes its own Multi from data is complete; one given a Multi is not", %{
      analysis: a
    } do
      assert %Scope{no_gap_noticed?: true} = scope = one(a, :s56)
      assert scope.keys == keys([@t])

      assert %Scope{no_gap_noticed?: false, gaps: [{:dynamic_call, {@x, :s57, 1}, _}]} =
               one(a, :s57)
    end

    test "a literal reaching a function-taking call through a variable is no gap", %{analysis: a} do
      assert %Scope{no_gap_noticed?: true} = one(a, :s58)
    end

    test "Multi.append and prepend hold both sides' writes", %{analysis: a} do
      assert %Scope{kind: :multi, no_gap_noticed?: true} = scope = one(a, :s60)
      assert scope.keys == keys([@s])
      assert %Scope{kind: :multi, no_gap_noticed?: true} = scope = one(a, :s61)
      assert scope.keys == keys([@s, @t])
    end

    test "Multi.append of a Multi Anchor cannot trace is a gap, written here or in a helper", %{
      analysis: a
    } do
      assert %Scope{no_gap_noticed?: false} = one(a, :s62)

      assert %Scope{
               no_gap_noticed?: false,
               gaps: [{:dynamic_call, {@builder, :add_append, 2}, _}]
             } =
               one(a, :s59)
    end

    test "a helper appending an untraced Multi to its own new one is a gap", %{analysis: a} do
      assert %Scope{
               no_gap_noticed?: false,
               gaps: [{:dynamic_call, {@builder, :append_to_new, 1}, _}]
             } =
               one(a, :s66)
    end

    test "a function run in another process is outside the transaction: a gap", %{analysis: a} do
      assert %Scope{no_gap_noticed?: false, gaps: [{:dynamic_call, {@x, :s63, 0}, _}]} =
               one(a, :s63)

      assert %Scope{no_gap_noticed?: false, gaps: [{:dynamic_call, {@x, :s64, 0}, _}]} =
               one(a, :s64)
    end

    test "another process through a helper, Agent or Process.spawn is a gap too", %{analysis: a} do
      assert %Scope{no_gap_noticed?: false, gaps: [{:dynamic_call, {@x, :spawns_write, 0}, _}]} =
               one(a, :s67)

      assert %Scope{no_gap_noticed?: false, gaps: [{:dynamic_call, {@x, :s68, 1}, _}]} =
               one(a, :s68)

      assert %Scope{no_gap_noticed?: false, gaps: [{:dynamic_call, {@x, :s69, 0}, _}]} =
               one(a, :s69)
    end

    test "a write function's own write traces through its callers", %{analysis: a} do
      assert [%{sources: [{:schema, @s}], unresolved: nil}] =
               Enum.filter(a.sites, &(&1.mfa == {@x, :wrap, 1}))
    end

    test "a callee transaction's gap is a gap of the transaction that reaches it", %{analysis: a} do
      assert %Scope{no_gap_noticed?: false, gaps: [{:dynamic_call, {@helper, :tx_any, 1}, _}]} =
               one(a, :s71)
    end

    test "a local transaction function's gap reaches the transaction around it", %{analysis: a} do
      assert %Scope{no_gap_noticed?: false, gaps: gaps} = one(a, :s73)
      assert Enum.any?(gaps, &match?({:dynamic_call, {@x, :local_unread, 1}, _}, &1))
    end

    test "a capture of raw SQL in a body is a gap", %{analysis: a} do
      assert %Scope{no_gap_noticed?: false, gaps: [{:dynamic_call, {@x, :s74, 1}, _}]} =
               one(a, :s74)

      assert %Scope{no_gap_noticed?: false, gaps: [{:dynamic_call, {@x, :s76, 1}, _}]} =
               one(a, :s76)
    end

    test "a lambda calling raw SQL in a body is a gap (positive control)", %{analysis: a} do
      assert %Scope{no_gap_noticed?: false} = one(a, :s75)
    end

    test "an apply of a transaction or a Multi step opens nothing Anchor reads: a gap", %{
      analysis: a
    } do
      assert %Scope{no_gap_noticed?: false} = one(a, :s77)
      assert %Scope{no_gap_noticed?: false} = one(a, :s78)
      assert %Scope{no_gap_noticed?: false} = one(a, :s79)
    end

    test "Repo.transact on a repo that does not export it is a gap, not a silent no-op", %{
      analysis: a
    } do
      assert %Scope{no_gap_noticed?: false, gaps: [{:dynamic_call, {@x, :s80, 0}, _}]} =
               one(a, :s80)
    end

    test "a listed wrapper runs what it is given: no gap of its own", %{analysis: a} do
      assert scopes(a, :wrapper_tx) == []

      for name <- [:s82, :s83] do
        assert [%Scope{no_gap_noticed?: true} = inner, %Scope{no_gap_noticed?: true} = outer] =
                 scopes(a, name)

        assert inner.keys == keys([@s])
        assert outer.keys == keys([@s])
      end

      refute Enum.any?(a.unattributed, &(&1.mfa == {@uow, :transaction, 2}))
    end

    test "Repo.checkout and a callback repo's transaction read the function they are given", %{
      analysis: a
    } do
      assert %Scope{no_gap_noticed?: false, gaps: [{:dynamic_call, {@x, :s84, 1}, _}]} =
               one(a, :s84)

      assert %Scope{no_gap_noticed?: false, gaps: [{:dynamic_call, {@x, :s85, 1}, _}]} =
               one(a, :s85)

      assert %Scope{no_gap_noticed?: false, gaps: [{:dynamic_call, {@x, :s88, 1}, _}]} =
               one(a, :s88)

      assert %Scope{no_gap_noticed?: true} = scope = one(a, :s86)
      assert scope.keys == keys([@s])
      assert %Scope{no_gap_noticed?: true} = scope = one(a, :s87)
      assert scope.keys == keys([@s])
      assert %Scope{no_gap_noticed?: true} = scope = one(a, :s89)
      assert scope.keys == keys([@s])
    end

    test "a write captured as a body is a gap of its transaction, and no write outside one", %{
      analysis: a
    } do
      assert %Scope{no_gap_noticed?: false} = one(a, :s90)
      refute Enum.any?(a.unattributed, &(&1.mfa == {@x, :s90, 0}))
    end

    test "a write captured as a body and elsewhere is a gap and a write outside", %{analysis: a} do
      assert %Scope{no_gap_noticed?: false} = one(a, :s91)
      assert Enum.any?(a.unattributed, &(&1.mfa == {@x, :s91, 0}))
    end

    test "a transaction nested in a body: its gap is a gap of the outer one", %{analysis: a} do
      assert [%Scope{no_gap_noticed?: false}, %Scope{no_gap_noticed?: false}] =
               Enum.filter(a.scopes, &(&1.mfa == {@x, :s72, 1}))
    end

    test "a function-taking call's first argument is data (positive control)", %{analysis: a} do
      assert %Scope{no_gap_noticed?: true} = one(a, :s32)
    end

    test "a capture of a write_functions write makes the scope incomplete", %{analysis: a} do
      assert %Scope{no_gap_noticed?: false, gaps: [{:dynamic_call, {@x, :s33, 1}, _line}]} =
               one(a, :s33)
    end

    test "a capture on a computed module, handed to a project function, is a gap", %{analysis: a} do
      assert %Scope{no_gap_noticed?: false, gaps: [{:dynamic_call, {@x, :s34, 1}, _line}]} =
               one(a, :s34)
    end

    test "a Multi.run callback's repo reads leave the scope complete", %{analysis: a} do
      assert %Scope{no_gap_noticed?: true} = scope = one(a, :s35)
      assert scope.keys == keys([@s])
    end

    test "a repo function Anchor cannot see makes the scope incomplete", %{analysis: a} do
      assert %Scope{no_gap_noticed?: false, gaps: [{:dynamic_call, {@x, :s26, 0}, _line}]} =
               one(a, :s26)
    end

    test "an unknown function on a Multi.run callback's repo makes the scope incomplete", %{
      analysis: a
    } do
      assert %Scope{no_gap_noticed?: false, gaps: [{:dynamic_call, {@x, :s27, 0}, _line}]} =
               one(a, :s27)
    end

    test "Ecto.Repo's reads leave a scope complete (positive control)", %{analysis: a} do
      assert %Scope{no_gap_noticed?: true} = scope = one(a, :s28)
      assert scope.keys == keys([@s])
    end

    test "S10: a Multi parameter with nothing to trace is incomplete at the call", %{analysis: a} do
      assert %Scope{no_gap_noticed?: false, gaps: [{:dynamic_call, {@x, :s10, 1}, line}]} =
               one(a, :s10)

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
      assert one(a, :s12).no_gap_noticed?
    end

    test "S13: a call into a dependency is not followed: a gap naming it, the write still read",
         %{analysis: a} do
      assert %Scope{
               no_gap_noticed?: false,
               gaps: [{:unread, {@x, :s13, 1}, _line, "unread: call of Code.ensure_loaded/1"}]
             } = scope = one(a, :s13)

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
        assert %Scope{no_gap_noticed?: false, gaps: [{:dynamic_call, {@x, ^name, 0}, line}]} =
                 one(a, name)

        assert line == BeamFixtures.line_of(@source, def_text)
      end
    end
  end

  test "counts: writes found, resolved, unresolved; scopes, complete, incomplete", %{analysis: a} do
    assert a.counts.scopes == length(a.scopes)
    assert a.counts.incomplete == Enum.count(a.scopes, &(not &1.no_gap_noticed?))
    assert a.counts.writes == length(a.sites)
    assert a.counts.unresolved == length(Enum.filter(a.sites, & &1.unresolved))
    assert a.counts.unresolved == 3
    assert a.counts.resolved == a.counts.writes - 3
  end
end
