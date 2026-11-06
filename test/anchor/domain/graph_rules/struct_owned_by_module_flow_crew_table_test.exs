defmodule Anchor.Domain.GraphRules.StructOwnedByModuleFlowCrewTableTest do
  # Domain (ADR 002), parity. DND-5454: crew's StructOnlyChangedByOwnModule
  # test table (~/dev/crew/apps/tooling/test/credo_checks/
  # struct_only_changed_by_own_module_test.exs), split across the two halves
  # of struct ownership. Each row names its crew line.
  #
  #   * The flow rows (a value known by a field type or a spec return,
  #     crew:670-1010) are ported here as compiled fixtures: flagged rows are
  #     flagged, allowed rows are not, and crew's known limits stay unknown.
  #   * The rows one file's text decides (construction, update syntax, a
  #     variable matched in the same clause) belong to the AST rule
  #     struct_owned_by_module (DND-5453). They are listed with
  #     `covered_by: DND-5453` and asserted present in its table by name, so
  #     no row can be dropped from both, and the graph rule is asserted not to
  #     report them again (one finding per site).
  #   * crew:899 (two files disagree on a module's `t`) and crew:1000
  #     (typespecs in test files) have no graph form: a module has one beam,
  #     and test code is left out by selection.
  #
  # Sabotage record: ../../../sabotage_records/struct_flow-20261103-dnd_5447_graph_rules_c.md
  use ExUnit.Case, async: true

  import Anchor.Test.StructFlowFixtures

  alias Anchor.Domain.GraphRules.StructOwnedByModuleFlow

  @ns "AnchorFixtures.StructFlow.Crew"

  @ast_table "test/anchor/domain/checks/struct_owned_by_module_test.exs"

  # The rows the AST rule holds: id and crew line, as its test names say.
  @covered_by_5453 [
    {"B1", 50},
    {"B2", 61},
    {"B3", 77},
    {"B4", 92},
    {"B5", 105},
    {"B6", 120},
    {"B7", 131},
    {"B8", 143},
    {"B9", 159},
    {"B10", 174},
    {"B11", 190},
    {"C1", 206},
    {"C2", 217},
    {"C3", 231},
    {"C4", 254},
    {"C5", 281},
    {"C6", 292},
    {"C7", 303},
    {"O1", 332},
    {"O2", 356},
    {"O3", 370},
    {"R1", 387},
    {"R2", 429},
    {"R3", 439},
    {"R4", 454},
    {"R5", 467},
    {"K1", 493},
    {"K2", 506},
    {"K3", 520},
    {"M1", 537},
    {"M2", 551},
    {"M3", 569},
    {"M4", 583},
    {"M5", 593},
    {"N1", 608},
    {"N2", 620},
    {"N3", 630}
  ]

  @defs """
  defmodule AnchorFixtures.StructFlow.Crew.Turn do
    defstruct [:status, :prev]

    @type t :: %__MODULE__{status: atom(), prev: t() | nil}

    @spec new() :: t()
    def new, do: %__MODULE__{}

    @spec blank :: t()
    def blank, do: %__MODULE__{}

    @spec finish(t()) :: t()
    def finish(%__MODULE__{} = t), do: %{t | status: :idle}

    @spec rewind(t()) :: t()
    def rewind(%__MODULE__{} = t), do: %{t.prev | status: :idle}

    # crew:916: a `t` naming another module's struct names that struct.
    def touch, do: Map.put(AnchorFixtures.StructFlow.Crew.Wrapper.make(), :status, :idle)
  end

  defmodule AnchorFixtures.StructFlow.Crew.Inner do
    defstruct [:turn]
    @opaque t :: %AnchorFixtures.StructFlow.Crew.Inner{turn: AnchorFixtures.StructFlow.Crew.Turn.t()}
  end

  defmodule AnchorFixtures.StructFlow.Crew.Config do
    @type t :: map()
  end

  defmodule AnchorFixtures.StructFlow.Crew.AgentState do
    alias AnchorFixtures.StructFlow.Crew.{Config, Turn}

    defstruct [:turn, :last, :inner, :config, :meta, :count, :either]

    @type t :: %__MODULE__{
            turn: Turn.t(),
            last: nil | Turn.t(),
            inner: AnchorFixtures.StructFlow.Crew.Inner.t(),
            config: Config.t(),
            meta: map(),
            count: non_neg_integer(),
            either: Turn.t() | AnchorFixtures.StructFlow.Crew.Inner.t()
          }

    @spec turn(t()) :: Turn.t()
    def turn(%__MODULE__{turn: turn}), do: turn

    @spec fetch_turn(t()) :: {:ok, Turn.t()}
    def fetch_turn(%__MODULE__{turn: turn}), do: {:ok, turn}

    @spec bump(t()) :: t()
    def bump(%__MODULE__{} = state), do: put_in(state.count, state.count + 1)

    # crew:799: the owner of the outer struct may not write a nested one.
    def finish(%__MODULE__{} = state), do: put_in(state.turn.status, :idle)
    def inline(%__MODULE__{} = state), do: %{state | turn: %{state.turn | status: :idle}}
  end

  defmodule AnchorFixtures.StructFlow.Crew.Wrapper do
    @type t :: %AnchorFixtures.StructFlow.Crew.Turn{}

    @spec make() :: t()
    def make, do: AnchorFixtures.StructFlow.Crew.Turn.new()
  end

  defmodule AnchorFixtures.StructFlow.Crew.Ident do
    defstruct [:a]
    @type t :: %__MODULE__{a: term()}

    @spec id(t) :: t when t: var
    def id(value), do: value
  end
  """

  @deciders """
  defmodule AnchorFixtures.StructFlow.Crew.Decider do
    alias AnchorFixtures.StructFlow.Crew.{AgentState, Ident, Turn, Wrapper}

    # crew:754
    def r754(%AgentState{} = state), do: %{state.turn | status: :idle}

    # crew:770
    def r770a(%AgentState{} = state), do: %{state.last | status: :idle}
    def r770b(%AgentState{} = state), do: %{state.turn.prev | status: :idle}
    def r770c(%AgentState{} = state), do: %{state.inner.turn | status: :idle}

    # crew:784
    def r784a(%AgentState{} = state), do: Map.put(state.turn, :status, :idle)
    def r784b(%AgentState{} = state), do: struct(state.turn, status: :idle)
    def r784c(%AgentState{} = state), do: put_in(state.turn.status, :idle)
    def r784d(%AgentState{} = state), do: state.turn |> Map.merge(%{status: :idle})

    # crew:815
    def r815a, do: %{Turn.new() | status: :idle}
    def r815b, do: Turn.new() |> Map.put(:status, :idle)
    def r815c(%AgentState{} = state), do: state |> AgentState.turn() |> Map.put(:status, :idle)
    def r815d(state), do: Map.merge(AgentState.turn(state), %{status: :idle})
    def r815e, do: Map.put(Turn.blank(), :status, :idle)

    # crew:831
    @spec fresh() :: Turn.t()
    def fresh, do: Turn.new()

    @spec pick(arg) :: Turn.t() when arg: term()
    def pick(_arg), do: Turn.new()

    def r831a, do: %{fresh() | status: :idle}
    def r831c, do: %{pick(1) | status: :idle}

    def r831b do
      turn = Turn.new()
      %{turn | status: :idle}
    end

    # crew:855 (allowed: not one known struct)
    def r855a(%AgentState{} = state), do: %{state.meta | a: 1}
    def r855b(%AgentState{} = state), do: Map.put(state.config, :a, 1)
    def r855c(%AgentState{} = state), do: Map.put(state.either, :a, 1)
    def r855d(%AgentState{} = state), do: Map.put(state.count, :a, 1)
    def r855e(%AgentState{} = state), do: Map.put(AgentState.fetch_turn(state), :a, 1)
    def r855g(state), do: %{state.turn | status: :idle}
    def r855h(%AgentState{} = state), do: {state.turn.status, Turn.finish(state.turn)}

    # crew:875 (allowed: specs disagree, in either order)
    @spec either(boolean()) :: Turn.t()
    @spec either(boolean()) :: map()
    def either(true), do: Turn.new()
    def either(false), do: %{}

    @spec other(boolean()) :: map()
    @spec other(boolean()) :: Turn.t()
    def other(true), do: Turn.new()
    def other(false), do: %{}

    def r875a, do: %{either(true) | status: :idle}
    def r875b, do: %{other(true) | status: :idle}

    # crew:916 (flagged outside Turn)
    def r916, do: Map.put(Wrapper.make(), :status, :idle)

    # crew:949 (allowed: a type variable named t)
    def r949, do: Map.put(Ident.id(%{}), :a, 1)

    # crew:971 (allowed: rebound to a plain map)
    def r971 do
      turn = Turn.new()
      turn = Map.from_struct(turn)
      Map.put(turn, :status, :idle)
    end

    # crew's limits: a call on a variable module is not known.
    def limit_variable_module(mod), do: Map.put(mod.new(), :status, :idle)
  end
  """

  @alone """
  defmodule AnchorFixtures.StructFlow.Crew.Alone do
    def r987a(%{turn: turn}), do: %{turn | status: :idle}
    def r987b, do: AnchorFixtures.StructFlow.Crew.Missing.new() |> Map.put(:status, :idle)
  end
  """

  setup_all do
    model = model(graph([{@defs, "lib/crew/defs.ex"}, {@deciders, "lib/crew/decider.ex"}]))
    rule = %{type: :struct_owned_by_module_flow, id: "flow", bucket: "domain"}
    %{findings: StructOwnedByModuleFlow.check(model, rule), rule: rule}
  end

  defp flagged(findings, module) do
    prefix = "#{@ns}.#{module}."

    findings
    |> Enum.filter(&String.starts_with?(&1.trigger, prefix))
    |> Enum.map(
      &{String.replace_prefix(&1.trigger, prefix, ""), &1.key |> String.split("|") |> Enum.at(3)}
    )
    |> Enum.sort()
  end

  defp decider(findings, row),
    do: findings |> flagged("Decider") |> Enum.filter(&String.starts_with?(elem(&1, 0), row))

  describe "flow rows, flagged" do
    test "crew:754 map update syntax on a field typed as another module's struct", %{
      findings: findings
    } do
      assert decider(findings, "r754") == [{"r754/1", "map update"}]
    end

    test "crew:770 a field typed nil | Struct.t(), and a nested field", %{findings: findings} do
      assert decider(findings, "r770") ==
               [{"r770a/1", "map update"}, {"r770b/1", "map update"}, {"r770c/1", "map update"}]
    end

    test "crew:784 the Map writers, struct/2 and put_in on a field typed as another struct", %{
      findings: findings
    } do
      # r784c roots put_in at the matched state: that site is the AST rule's
      # (crew reports it once, on AgentState), so the graph does not add one.
      assert decider(findings, "r784") ==
               [{"r784a/1", "Map.put"}, {"r784b/1", "struct"}, {"r784d/1", "Map.put"}]
    end

    test "crew:799 the owner of the outer struct may not write a nested struct through it", %{
      findings: findings
    } do
      assert flagged(findings, "AgentState") ==
               [{"finish/1", "Map.update!"}, {"inline/1", "map update"}]
    end

    test "crew:815 a remote function's return, called directly and piped", %{findings: findings} do
      assert decider(findings, "r815") == [
               {"r815a/0", "map update"},
               {"r815b/0", "Map.put"},
               {"r815c/1", "Map.put"},
               {"r815d/1", "Map.put"},
               {"r815e/0", "Map.put"}
             ]
    end

    test "crew:831 a local function's return, and a variable bound to a function's return", %{
      findings: findings
    } do
      assert decider(findings, "r831") ==
               [{"r831a/0", "map update"}, {"r831b/0", "map update"}, {"r831c/0", "map update"}]
    end

    test "crew:916 a t naming another module's struct: flagged outside it, not inside it", %{
      findings: findings
    } do
      assert decider(findings, "r916") == [{"r916/0", "Map.put"}]
      assert flagged(findings, "Turn") == []
    end
  end

  describe "flow rows, allowed (never guessed)" do
    test "crew:748 the struct modules themselves are clean", %{findings: findings} do
      assert flagged(findings, "Turn") == []
      assert flagged(findings, "Wrapper") == []
      assert flagged(findings, "Ident") == []
    end

    for {row, line} <- [
          {"r855", 855},
          {"r875", 875},
          {"r949", 949},
          {"r971", 971},
          {"limit_variable_module", 0}
        ] do
      test "#{if line > 0, do: "crew:#{line}", else: "crew's limits"} #{row}: not reported", %{
        findings: findings
      } do
        assert decider(findings, unquote(row)) == []
      end
    end

    test "crew:987 without the defining modules, a field or a return is not known", %{
      rule: rule
    } do
      model = model(graph([{@alone, "lib/crew/alone.ex"}]))
      assert StructOwnedByModuleFlow.check(model, rule) == []
    end
  end

  describe "rows covered by DND-5453 (the AST rule)" do
    test "each is present in the AST rule's table by name" do
      names = File.read!(@ast_table)

      missing =
        for {id, line} <- @covered_by_5453,
            not String.contains?(names, ~s[test "#{id} (crew:#{line})]),
            do: "#{id} (crew:#{line})"

      assert missing == []
    end

    test "macro-injected writes, which crew does not see, are this rule's (rule test)" do
      assert File.read!("test/anchor/domain/graph_rules/struct_owned_by_module_flow_test.exs") =~
               "a macro-injected write on a matched %Turn{} is one violation, at the use line"
    end
  end
end
