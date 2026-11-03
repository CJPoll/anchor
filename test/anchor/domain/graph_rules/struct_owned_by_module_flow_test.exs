defmodule Anchor.Domain.GraphRules.StructOwnedByModuleFlowTest do
  # Domain (ADR 002). DND-5454: the struct_owned_by_module_flow graph rule over
  # fixtures compiled in the test (Anchor.Test.StructFlowFixtures): owners,
  # defimpl, owned_namespaces, a macro-injected write, and the split with the
  # AST rule struct_owned_by_module (DND-5453), one finding per site.
  #
  # Sabotage record: ../../../sabotage_records/struct_flow-20261103-dnd_5447_graph_rules_c.md
  use ExUnit.Case, async: true

  import Anchor.Test.BeamFixtures, only: [line_of: 2]
  import Anchor.Test.StructFlowFixtures

  alias Anchor.Domain.GraphRules.StructOwnedByModuleFlow

  @ns "AnchorFixtures.StructFlow.Rule"
  @turn AnchorFixtures.StructFlow.Rule.Runtime.Turn
  @game AnchorFixtures.StructFlow.Rule.Runtime.Game

  @types """
  defmodule AnchorFixtures.StructFlow.Rule.Runtime.Game do
    defstruct [:turn]
    @type t :: %__MODULE__{turn: AnchorFixtures.StructFlow.Rule.Runtime.Turn.t()}

    @spec make() :: t()
    def make, do: %__MODULE__{}
  end

  defmodule AnchorFixtures.StructFlow.Rule.Runtime.Turn do
    defstruct [:status, :prev]
    @type t :: %__MODULE__{status: atom(), prev: t() | nil}

    @spec new() :: t()
    def new, do: %__MODULE__{}

    def own(%AnchorFixtures.StructFlow.Rule.Runtime.Game{} = g), do: Map.put(g.turn, :status, 1)
  end

  defmodule AnchorFixtures.StructFlow.Rule.Ext.Box do
    defstruct [:a]
    @type t :: %__MODULE__{a: term()}
    @spec new() :: t()
    def new, do: %__MODULE__{}
  end

  defmodule AnchorFixtures.StructFlow.Rule.Inject do
    defmacro __using__(_opts) do
      quote do
        def injected(%AnchorFixtures.StructFlow.Rule.Runtime.Turn{} = s), do: Map.put(s, :status, 1)
      end
    end
  end
  """

  @decider """
  defmodule AnchorFixtures.StructFlow.Rule.Runtime.Decider do
    alias AnchorFixtures.StructFlow.Rule.Ext.Box
    alias AnchorFixtures.StructFlow.Rule.Runtime.{Game, Turn}

    use AnchorFixtures.StructFlow.Rule.Inject

    def field(%Game{} = g), do: Map.put(g.turn, :status, :idle)
    def spec, do: Turn.new() |> Map.put(:status, :idle)
    def matched(%Turn{} = s), do: Map.put(s, :status, :idle)
    def literal_line(%Game{} = g), do: Map.put(g.turn, :prev, %Turn{})
    def path_matched(%Game{} = g), do: put_in(g.turn.status, :x)
    def path_spec, do: put_in(Game.make().turn.status, :x)
    def box, do: Map.put(Box.new(), :a, 1)
    def uri, do: Map.put(URI.parse("http://x"), :host, "y")
  end

  # BeamFixtures turns debug_info on only in a `defmodule`; a defimpl body
  # says so itself, as `mix compile` would write its beam.
  defimpl Inspect, for: AnchorFixtures.StructFlow.Rule.Runtime.Turn do
    @compile {:debug_info, true}
    def inspect(_turn, _opts), do: Kernel.inspect(Map.put(AnchorFixtures.StructFlow.Rule.Runtime.Turn.new(), :status, 1))
  end

  defprotocol AnchorFixtures.StructFlow.Rule.Runtime.Proto do
    def touch(x)
  end

  defimpl AnchorFixtures.StructFlow.Rule.Runtime.Proto,
    for: [AnchorFixtures.StructFlow.Rule.Runtime.Turn, AnchorFixtures.StructFlow.Rule.Runtime.Game] do
    @compile {:debug_info, true}
    def touch(_x), do: Map.put(AnchorFixtures.StructFlow.Rule.Runtime.Turn.new(), :status, 1)
  end
  """

  @file_path "lib/runtime/decider.ex"

  setup_all do
    model = model(graph([{@types, "lib/runtime/types.ex"}, {@decider, @file_path}]))
    %{model: model}
  end

  defp rule(opts),
    do: Map.merge(%{type: :struct_owned_by_module_flow, id: "flow", bucket: "domain"}, opts)

  defp check(model, opts \\ %{}) do
    model
    |> StructOwnedByModuleFlow.check(rule(opts))
    |> Enum.sort_by(& &1.key)
  end

  defp keys(model, opts \\ %{}), do: model |> check(opts) |> Enum.map(& &1.key)

  describe "check/2" do
    test "a write outside the owner is one violation naming how the value is known", %{
      model: model
    } do
      [field] = Enum.filter(check(model), &(&1.trigger =~ ".field/1"))

      assert field.key == "flow|#{@ns}.Runtime.Decider.field/1|#{inspect(@turn)}|Map.put"
      assert field.filename == @file_path
      assert field.line == line_of(@decider, "def field(")

      assert field.message ==
               "#{@ns}.Runtime.Decider.field/1 changes #{inspect(@turn)} (Map.put; known as " <>
                 "#{inspect(@turn)} by the @type t of #{inspect(@game)} (field :turn)) outside " <>
                 "#{inspect(@turn)}: call a function on #{inspect(@turn)} instead " <>
                 "(e.g. #{inspect(@turn)}.put_<field>/2). Fix: " <>
                 StructOwnedByModuleFlow.shape(%{})

      [spec] = Enum.filter(check(model), &(&1.trigger =~ ".spec/0"))
      assert spec.message =~ "by the @spec of #{inspect(@turn)}.new/0"
    end

    test "inside the owner none; inside defimpl Inspect, for: Turn none", %{model: model} do
      triggers = model |> check() |> Enum.map(& &1.trigger)

      refute Enum.any?(triggers, &(&1 =~ "Turn.own/1"))
      refute Enum.any?(triggers, &(&1 =~ "Inspect"))
    end

    test "a defimpl with a list for: is owned by its protocol, as in the AST rule", %{
      model: model
    } do
      assert "flow|#{@ns}.Runtime.Proto.#{@ns}.Runtime.Turn.touch/1|#{inspect(@turn)}|Map.put" in keys(
               model
             )
    end

    test "a macro-injected write on a matched %Turn{} is one violation, at the use line", %{
      model: model
    } do
      [injected] = Enum.filter(check(model), &(&1.trigger =~ ".injected/1"))

      assert injected.line == line_of(@decider, "use AnchorFixtures")
      assert injected.message =~ "known as #{inspect(@turn)} by a match on %#{inspect(@turn)}{}"
    end

    test "the AST rule's sites are not reported again: a match in hand-written code, a line " <>
           "with literal struct syntax, and a path rooted at a matched value",
         %{model: model} do
      triggers = model |> check() |> Enum.map(& &1.trigger)

      for name <- ~w(matched/1 literal_line/1 path_matched/1),
          do: refute(Enum.any?(triggers, &String.ends_with?(&1, "Decider." <> name)), name)
    end

    test "one finding per site: put_in on a spec-known Game reports Game, not also its turn", %{
      model: model
    } do
      assert [path] = Enum.filter(check(model), &(&1.trigger =~ ".path_spec/0"))
      assert path.key =~ "|#{inspect(@game)}|Map.update!"
    end

    test "owned_namespaces: a struct outside them is not judged, and its module is reported", %{
      model: model
    } do
      all = keys(model)
      assert Enum.any?(all, &(&1 =~ ".box/0|"))

      owned = keys(model, %{owned_namespaces: [AnchorFixtures.StructFlow.Rule.Runtime]})

      refute Enum.any?(owned, &(&1 =~ ".box/0|"))
      assert "flow|#{@ns}.Ext.Box|outside owned_namespaces" in owned
      assert Enum.any?(owned, &(&1 =~ ".field/1|"))
    end

    test "a stdlib struct is not the graph's to know (URI.parse has no project spec)", %{
      model: model
    } do
      refute Enum.any?(keys(model), &(&1 =~ ".uri/0|"))
    end

    test "the whole fixture: exactly these sites", %{model: model} do
      assert keys(model) == [
               "flow|#{@ns}.Runtime.Decider.box/0|#{@ns}.Ext.Box|Map.put",
               "flow|#{@ns}.Runtime.Decider.field/1|#{inspect(@turn)}|Map.put",
               "flow|#{@ns}.Runtime.Decider.injected/1|#{inspect(@turn)}|Map.put",
               "flow|#{@ns}.Runtime.Decider.path_spec/0|#{inspect(@game)}|Map.update!",
               "flow|#{@ns}.Runtime.Decider.spec/0|#{inspect(@turn)}|Map.put",
               "flow|#{@ns}.Runtime.Proto.#{@ns}.Runtime.Game.touch/1|#{inspect(@turn)}|Map.put",
               "flow|#{@ns}.Runtime.Proto.#{@ns}.Runtime.Turn.touch/1|#{inspect(@turn)}|Map.put"
             ]
    end
  end

  describe "shape/1" do
    test "the exact conforming shape" do
      assert StructOwnedByModuleFlow.shape(%{}) ==
               "only a struct's own module builds or changes it: call a function on the " <>
                 "struct's module (e.g. S.new/1, S.put_<field>/2) instead; read fields and " <>
                 "pattern-match freely"
    end
  end

  test "rule_type/0 and needs nothing lazy" do
    assert StructOwnedByModuleFlow.rule_type() == :struct_owned_by_module_flow
    refute function_exported?(StructOwnedByModuleFlow, :needs, 0)
  end
end
