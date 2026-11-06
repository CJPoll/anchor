defmodule Anchor.Domain.StructTypesTest do
  # Domain (ADR 002). DND-5454: what the typespecs read from beams say a field
  # or a function's return is, over fixtures compiled in the test
  # (Anchor.Test.StructFlowFixtures). Only one struct, named exactly, is known.
  #
  # Sabotage record: ../../sabotage_records/struct_flow-20261103-dnd_5447_graph_rules_c.md
  # DND-5448: ../../sabotage_records/placement-20261106-dnd_5448_placement_core.md
  use ExUnit.Case, async: true

  import Anchor.Test.StructFlowFixtures

  alias Anchor.Domain.StructTypes

  @turn AnchorFixtures.StructFlow.Types.Turn
  @game AnchorFixtures.StructFlow.Types.Game
  @wrapper AnchorFixtures.StructFlow.Types.Wrapper
  @plain AnchorFixtures.StructFlow.Types.Plain

  @source """
  defmodule AnchorFixtures.StructFlow.Types.Turn do
    defstruct [:status, :prev]

    @type t :: %__MODULE__{status: atom(), prev: t() | nil}

    @spec new() :: t()
    def new, do: %__MODULE__{}

    @spec pick(arg) :: t when arg: term()
    def pick(_arg), do: new()

    @spec either(boolean()) :: t()
    @spec either(integer()) :: map()
    def either(_x), do: %{}

    @spec same(boolean()) :: t()
    @spec same(integer()) :: nil | t()
    def same(_x), do: new()

    @spec id(t) :: t when t: var
    def id(x), do: x

    @spec wrapped() :: {:ok, t()}
    def wrapped, do: {:ok, new()}

    def unspecced, do: new()
  end

  defmodule AnchorFixtures.StructFlow.Types.Game do
    alias AnchorFixtures.StructFlow.Types.Turn

    defstruct [:turn, :last, :both, :inner, :meta, :state, :remote]

    @type state :: %Turn{}

    @opaque t :: %__MODULE__{
              turn: Turn.t(),
              last: nil | Turn.t(),
              both: Turn.t() | t(),
              inner: %Turn{},
              meta: map(),
              state: state(),
              remote: URI.t()
            }

    @spec turn(t()) :: Turn.t()
    def turn(%__MODULE__{turn: turn}), do: turn
  end

  defmodule AnchorFixtures.StructFlow.Types.Wrapper do
    @type t :: %AnchorFixtures.StructFlow.Types.Turn{}

    @spec make() :: t()
    def make, do: AnchorFixtures.StructFlow.Types.Turn.new()
  end

  defmodule AnchorFixtures.StructFlow.Types.Plain do
    defstruct [:a]
    @type t :: map()
    @spec make() :: t()
    def make, do: %{}
  end
  """

  setup_all do
    %{index: StructTypes.index(graph([{@source, "lib/types.ex"}]))}
  end

  # DND-5448: the one type question, asked of a spec type a caller holds.
  describe "struct_of/3" do
    test "a project struct, through a named type, or nil" do
      graph = graph([{@source, "lib/types.ex"}])
      type = {{:., [], [@turn, :t]}, [], []}

      assert StructTypes.struct_of(type, @game, graph) == @turn
      assert StructTypes.struct_of({:integer, [], []}, @game, graph) == nil
    end
  end

  describe "index/1 fields" do
    test "a field typed Turn.t() is Turn", %{index: index} do
      assert StructTypes.field(index, @game, :turn) == @turn
    end

    test "nil | Turn.t() is Turn, and the module's own t() names its own struct", %{
      index: index
    } do
      assert StructTypes.field(index, @game, :last) == @turn
      assert StructTypes.field(index, @turn, :prev) == @turn
    end

    test "%Turn{} and a local type naming %Turn{} are Turn", %{index: index} do
      assert StructTypes.field(index, @game, :inner) == @turn
      assert StructTypes.field(index, @game, :state) == @turn
    end

    test "a union of two structs, map(), a non-struct and a type outside the graph are unknown",
         %{index: index} do
      assert StructTypes.field(index, @game, :both) == nil
      assert StructTypes.field(index, @game, :meta) == nil
      assert StructTypes.field(index, @turn, :status) == nil
      assert StructTypes.field(index, @game, :remote) == nil
      assert StructTypes.field(index, @game, :no_such_field) == nil
    end
  end

  describe "index/1 returns" do
    test "@spec new() :: t() in Turn is Turn, a when clause included", %{index: index} do
      assert StructTypes.return(index, {@turn, :new, 0}) == @turn
      assert StructTypes.return(index, {@turn, :pick, 1}) == @turn
      assert StructTypes.return(index, {@game, :turn, 1}) == @turn
    end

    test "two specs agreeing (nil | t() is t()) are known; disagreeing ones are not", %{
      index: index
    } do
      assert StructTypes.return(index, {@turn, :same, 1}) == @turn
      assert StructTypes.return(index, {@turn, :either, 1}) == nil
    end

    test "a type variable named t, a tuple, and no spec are unknown", %{index: index} do
      assert StructTypes.return(index, {@turn, :id, 1}) == nil
      assert StructTypes.return(index, {@turn, :wrapped, 0}) == nil
      assert StructTypes.return(index, {@turn, :unspecced, 0}) == nil
    end

    test "a t that names another module's struct names that struct", %{index: index} do
      assert StructTypes.return(index, {@wrapper, :make, 0}) == @turn
    end

    test "a t that is map() is not a struct, though the module defines one", %{index: index} do
      assert StructTypes.return(index, {@plain, :make, 0}) == nil
    end
  end
end
