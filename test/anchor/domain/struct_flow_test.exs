defmodule Anchor.Domain.StructFlowTest do
  # Domain (ADR 002). DND-5454: what one function's Core knows each value to
  # be, and which of its writes change a known struct, over fixtures compiled
  # in the test (Anchor.Test.StructFlowFixtures). Core names a source variable
  # `s` as `_s@1`; `known/1` here reads them back as `:s`.
  #
  # Sabotage record: ../../sabotage_records/struct_flow-20261103-dnd_5447_graph_rules_c.md
  # Sabotage record (DND-5676): ../../sabotage_records/struct_flow-20261106-dnd_5676_effects_cfa_batch.md
  use ExUnit.Case, async: true

  import Anchor.Test.StructFlowFixtures

  alias Anchor.Domain.StructFlow
  alias Anchor.Domain.StructTypes

  @turn AnchorFixtures.StructFlow.Flow.Turn
  @game AnchorFixtures.StructFlow.Flow.Game
  @w AnchorFixtures.StructFlow.Flow.W

  @source """
  defmodule AnchorFixtures.StructFlow.Flow.Turn do
    defstruct [:status, :n]
    @type t :: %__MODULE__{status: atom(), n: integer()}
    @spec new() :: t()
    def new, do: %__MODULE__{}
  end

  defmodule AnchorFixtures.StructFlow.Flow.Game do
    defstruct [:turn, :meta]
    @type t :: %__MODULE__{turn: AnchorFixtures.StructFlow.Flow.Turn.t(), meta: map()}
  end

  defmodule AnchorFixtures.StructFlow.Flow.Deep0 do
    defstruct [:a]
    @type t :: %__MODULE__{a: AnchorFixtures.StructFlow.Flow.Deep1.t()}
  end
  defmodule AnchorFixtures.StructFlow.Flow.Deep1 do
    defstruct [:a]
    @type t :: %__MODULE__{a: AnchorFixtures.StructFlow.Flow.Deep2.t()}
  end
  defmodule AnchorFixtures.StructFlow.Flow.Deep2 do
    defstruct [:a]
    @type t :: %__MODULE__{a: AnchorFixtures.StructFlow.Flow.Deep3.t()}
  end
  defmodule AnchorFixtures.StructFlow.Flow.Deep3 do
    defstruct [:a]
    @type t :: %__MODULE__{a: AnchorFixtures.StructFlow.Flow.Deep4.t()}
  end
  defmodule AnchorFixtures.StructFlow.Flow.Deep4 do
    defstruct [:a]
    @type t :: %__MODULE__{a: AnchorFixtures.StructFlow.Flow.Deep5.t()}
  end
  defmodule AnchorFixtures.StructFlow.Flow.Deep5 do
    defstruct [:a]
    @type t :: %__MODULE__{a: AnchorFixtures.StructFlow.Flow.Deep6.t()}
  end
  defmodule AnchorFixtures.StructFlow.Flow.Deep6 do
    defstruct [:a]
    @type t :: %__MODULE__{a: term()}
  end

  defmodule AnchorFixtures.StructFlow.Flow.W do
    alias AnchorFixtures.StructFlow.Flow.{Game, Turn}

    @spec local() :: Turn.t()
    def local, do: Turn.new()

    def matched(%Turn{} = s), do: s
    def by_spec, do: (s = Turn.new(); s)
    def by_local_spec, do: (s = local(); s)
    def by_field(%Game{} = g), do: (t = g.turn; t)
    def by_head_field(%Game{turn: t}), do: t
    def rebound(s), do: (s = Map.from_struct(s); s)
    def through_case(%Turn{} = x), do: (case x do y -> y end)
    def meta(%Game{} = g), do: (m = g.meta; m)

    def upd(%Turn{} = s), do: %{s | n: 1}
    def put(%Turn{} = s), do: Map.put(s, :n, 1)
    def merge(%Turn{} = s), do: Map.merge(s, %{n: 1})
    def replace(%Turn{} = s), do: Map.replace(s, :n, 1)
    def replace!(%Turn{} = s), do: Map.replace!(s, :n, 1)
    def update(%Turn{} = s), do: Map.update(s, :n, 0, &(&1 + 1))
    def update!(%Turn{} = s), do: Map.update!(s, :n, &(&1 + 1))
    def delete(%Turn{} = s), do: Map.delete(s, :n)
    def drop(%Turn{} = s), do: Map.drop(s, [:n])
    def put_new(%Turn{} = s), do: Map.put_new(s, :n, 1)
    def struct2(%Turn{} = s), do: struct(s, n: 1)
    def struct2!(%Turn{} = s), do: struct!(s, n: 1)
    def put_in_path(%Game{} = g), do: put_in(g.turn.status, :x)
    def put_in_keys(%Turn{} = s), do: put_in(s, [:n], 1)
    def spec_put, do: Turn.new() |> Map.put(:n, 2)
    def field_put(%Game{} = g), do: Map.put(g.turn, :n, 3)

    def reads(%Turn{} = s), do: {s.n, Map.get(s, :n), Map.from_struct(s)}
    def reads_and_put(%Turn{} = s), do: {s.n, Map.get(s, :n), Map.put(s, :n, 1)}
    def drop_struct(%Turn{} = s), do: {Map.delete(s, :__struct__), Map.drop(s, [:__struct__])}
    def unknown_put(s), do: Map.put(s, :n, 1)
    def meta_put(%Game{} = g), do: Map.put(g.meta, :a, 1)

    # DND-5676: each nested fun's parameter (the innermost `x` included) is
    # known one pass after the last: four levels settle within the bound of
    # six passes, five do not.
    def deep4(%AnchorFixtures.StructFlow.Flow.Deep0{} = g) do
      f4 = fn p -> Map.update!(p, :a, fn x -> x end) end
      f3 = fn p -> Map.update!(p, :a, f4) end
      f2 = fn p -> Map.update!(p, :a, f3) end
      f1 = fn p -> Map.update!(p, :a, f2) end
      Map.update!(g, :a, f1)
    end

    def deep5(%AnchorFixtures.StructFlow.Flow.Deep0{} = g) do
      f5 = fn p -> Map.update!(p, :a, fn x -> x end) end
      f4 = fn p -> Map.update!(p, :a, f5) end
      f3 = fn p -> Map.update!(p, :a, f4) end
      f2 = fn p -> Map.update!(p, :a, f3) end
      f1 = fn p -> Map.update!(p, :a, f2) end
      Map.update!(g, :a, f1)
    end

    def deep6(%AnchorFixtures.StructFlow.Flow.Deep0{} = g) do
      f6 = fn p -> Map.update!(p, :a, fn x -> x end) end
      f5 = fn p -> Map.update!(p, :a, f6) end
      f4 = fn p -> Map.update!(p, :a, f5) end
      f3 = fn p -> Map.update!(p, :a, f4) end
      f2 = fn p -> Map.update!(p, :a, f3) end
      f1 = fn p -> Map.update!(p, :a, f2) end
      Map.update!(g, :a, f1)
    end
  end
  """

  setup_all do
    graph = graph([{@source, "lib/flow.ex"}])
    %{graph: graph, index: StructTypes.index(graph)}
  end

  defp known(ctx, name, arity) do
    {:ok, known} = ctx.graph |> core!({@w, name, arity}) |> StructFlow.known(ctx.index, @w)

    known
    |> Enum.flat_map(fn {var, value} ->
      case Regex.run(~r/^_(\w+)@\d+$/, to_string(var)) do
        [_all, source] -> [{String.to_atom(source), value}]
        nil -> []
      end
    end)
    |> Map.new()
  end

  defp writes(ctx, name, arity) do
    core = core!(ctx.graph, {@w, name, arity})
    {:ok, writes} = StructFlow.writes(core, ctx.index, @w)
    writes
  end

  defp ops(ctx, name, arity), do: ctx |> writes(name, arity) |> Enum.map(&{&1.struct, &1.op})

  describe "known/3" do
    test "%Turn{} = s: s is Turn, matched", ctx do
      assert known(ctx, :matched, 1) == %{s: {@turn, :matched}}
    end

    test "s = Turn.new(): known by the spec, remote or local", ctx do
      assert known(ctx, :by_spec, 0) == %{s: {@turn, {:spec, {@turn, :new, 0}}}}
      assert known(ctx, :by_local_spec, 0) == %{s: {@turn, {:spec, {@w, :local, 0}}}}
    end

    test "t = g.turn with g matched %Game{}: known by the field type", ctx do
      assert %{t: {@turn, {:field, @game, :turn}}, g: {@game, :matched}} =
               known(ctx, :by_field, 1)
    end

    test "%Game{turn: t} in the head: t known by the field type", ctx do
      assert %{t: {@turn, {:field, @game, :turn}}} = known(ctx, :by_head_field, 1)
    end

    test "bound bare, then rebound to Map.from_struct(s): unknown", ctx do
      assert known(ctx, :rebound, 1) == %{}
    end

    test "passed through case x do y -> y end unchanged: known through the clause variable",
         ctx do
      assert %{x: {@turn, :matched}, y: {@turn, :matched}} = known(ctx, :through_case, 1)
    end

    test "a field typed map(): unknown", ctx do
      refute Map.has_key?(known(ctx, :meta, 1), :m)
    end
  end

  describe "writes/3: one per op" do
    for {name, op} <- [
          upd: "map update",
          put: "Map.put",
          merge: "Map.put",
          replace: "Map.replace",
          replace!: "Map.replace!",
          update: "Map.update",
          update!: "Map.update!",
          delete: "Map.delete",
          drop: "Map.drop",
          put_new: "Map.put_new",
          struct2: "struct",
          struct2!: "struct!",
          put_in_keys: "put_in"
        ] do
      test "#{name}: #{op} on a matched Turn", ctx do
        assert [%{struct: @turn, op: unquote(op), how: :matched, line: line}] =
                 writes(ctx, unquote(name), 1)

        assert is_integer(line) and line > 0
      end
    end

    test "put_in(g.turn.status, :x) judges g and g.turn, not the status leaf", ctx do
      assert ctx |> ops(:put_in_path, 1) |> Enum.sort() ==
               [{@game, "Map.update!"}, {@turn, "Map.update!"}]

      assert [%{how: :matched}, %{how: {:field, @game, :turn}}] =
               ctx |> writes(:put_in_path, 1) |> Enum.sort_by(&inspect(&1.struct))
    end

    test "a spec return and a field read, written to", ctx do
      assert [%{struct: @turn, how: {:spec, {@turn, :new, 0}}}] = writes(ctx, :spec_put, 0)
      assert [%{struct: @turn, how: {:field, @game, :turn}}] = writes(ctx, :field_put, 1)
    end
  end

  describe "writes/3: scopes" do
    # Core lets a clause rebind a name the enclosing scope bound; the outer
    # binding holds again after the clause. Built by hand with :cerl:
    #
    #   fun (A) -> let <V> = call 'Turn':'new'() in
    #     do (case A of <V> when 'true' -> V end) ~{'k'=>1|V}~
    test "a clause's rebinding of a name ends with the clause" do
      turn = @turn
      var = :cerl.c_var(:V)
      arg = :cerl.c_var(:A)
      new = :cerl.c_call(:cerl.c_atom(turn), :cerl.c_atom(:new), [])
      shadow = :cerl.c_case(arg, [:cerl.c_clause([var], :cerl.c_atom(true), var)])
      put = :cerl.ann_c_map([7], var, [:cerl.c_map_pair(:cerl.c_atom(:k), :cerl.c_int(1))])
      core = :cerl.c_fun([arg], :cerl.c_let([var], new, :cerl.c_seq(shadow, put)))
      index = %{fields: %{}, returns: %{{turn, :new, 0} => turn}}

      assert {:ok, [%{struct: ^turn, op: "Map.put", how: {:spec, {^turn, :new, 0}}, line: 7}]} =
               StructFlow.writes(core, index, @w)
    end
  end

  describe "writes/3: not writes" do
    test "reading s.field, Map.get and Map.from_struct is none; the same plus a Map.put is one",
         ctx do
      assert writes(ctx, :reads, 1) == []
      assert ops(ctx, :reads_and_put, 1) == [{@turn, "Map.put"}]
    end

    test "dropping :__struct__ makes a plain map, not a write", ctx do
      assert writes(ctx, :drop_struct, 1) == []
    end

    test "a write on an unknown value or a map()-typed field is none", ctx do
      assert writes(ctx, :unknown_put, 1) == []
      assert writes(ctx, :meta_put, 1) == []
    end
  end

  describe "the pass bound (DND-5676)" do
    @deep for k <- 0..6, do: Module.concat(AnchorFixtures.StructFlow.Flow, "Deep#{k}")

    defp structs(writes), do: writes |> Enum.map(& &1.struct) |> Enum.sort()

    test "nested funs that settle within the bound are {:ok, _}, every level written", ctx do
      core = core!(ctx.graph, {@w, :deep4, 1})

      assert {:ok, writes} = StructFlow.writes(core, ctx.index, @w)
      assert structs(writes) == Enum.take(@deep, 5)
      assert {:ok, _known} = StructFlow.known(core, ctx.index, @w)
    end

    test "one level more does not settle at the last pass: :bound_hit", ctx do
      core = core!(ctx.graph, {@w, :deep5, 1})
      passes = StructFlow.max_passes()

      assert {:bound_hit, ^passes, _writes} = StructFlow.writes(core, ctx.index, @w)
      assert {:bound_hit, ^passes, _known} = StructFlow.known(core, ctx.index, @w)
    end

    test "past the bound: the writes the last settled pass found, the deepest one missing",
         ctx do
      core = core!(ctx.graph, {@w, :deep6, 1})

      assert {:bound_hit, _passes, writes} = StructFlow.writes(core, ctx.index, @w)
      # The seventh level's write needs a seventh pass: it is the one not found.
      assert structs(writes) == Enum.take(@deep, 6)
    end
  end
end
