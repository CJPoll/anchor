defmodule Anchor.Domain.Checks.StructOwnedByModuleTest do
  # DND-5453: only a struct's own module builds or changes it. Every row ports
  # a test of crew's Crew.Credo.Checks.StructOnlyChangedByOwnModule
  # (~/dev/crew/apps/tooling/test/credo_checks/struct_only_changed_by_own_module_test.exs,
  # cited as crew:<line>) with crew's verdict and `Runtime` renamed `App`.
  # crew:674 on (typespec-derived fields and returns) is DND-5454's. Pure
  # Domain: sources are parsed with columns, as `Credo.Code.ast/1` does.
  #
  # Sabotage record: ../../../sabotage_records/struct_owned_by_module-20261103-dnd_5451_ast_batch.md
  use ExUnit.Case, async: true

  alias Anchor.Domain.Checks.StructOwnedByModule, as: Check

  @shape "call a function on S's own module that builds or changes it (e.g. S.new/1, " <>
           "S.put_<field>/2); read fields and pattern-match freely."

  @owned [%{owned_namespaces: [App]}]

  defp detect(source, rules \\ [%{}]) do
    source
    |> Code.string_to_quoted!(columns: true)
    |> Check.detect_violations(rules)
  end

  defp triggers(source, rules \\ [%{}]),
    do: source |> detect(rules) |> Enum.map(& &1.trigger) |> Enum.sort()

  describe "building another module's struct (crew:49-203)" do
    test "B1 (crew:50): a struct literal of another module" do
      source = """
      defmodule App.Agents.Managers.StartAgent do
        def run, do: %App.Agents.Domain.Turn{status: :idle}
      end
      """

      assert [violation] = detect(source)
      assert violation.trigger == "%App.Agents.Domain.Turn{"
      assert violation.line == 2
      assert violation.message =~ "Only App.Agents.Domain.Turn's own module may build or change"
      assert String.ends_with?(violation.message, "Fix: " <> @shape)
    end

    test "B2 (crew:61): a struct literal through an alias names the resolved module" do
      source = """
      defmodule App.Agents.Managers.StartAgent do
        alias App.Agents.Domain.Turn

        def run, do: %Turn{status: :idle}
      end
      """

      assert [violation] = detect(source)
      assert violation.trigger == "%Turn{"
      assert violation.message =~ "App.Agents.Domain.Turn"
      assert violation.line == 4
    end

    test "B3 (crew:77): a multi-alias and a nested alias segment" do
      source = """
      defmodule App.Agents.Managers.StartAgent do
        alias App.Agents.Domain.{Effect, Turn}

        def run(call), do: [%Effect.RunTool{call: call}]
      end
      """

      assert [violation] = detect(source)
      assert violation.trigger == "%Effect.RunTool{"
      assert violation.message =~ "App.Agents.Domain.Effect.RunTool"
    end

    test "B4 (crew:92): an alias with as:" do
      source = """
      defmodule App.Agents.Managers.StartAgent do
        alias App.Agents.Domain.Turn, as: T

        def run, do: %T{}
      end
      """

      assert triggers(source) == ["%T{"]
    end

    test "B5 (crew:105): a nested module's struct built by the enclosing module" do
      source = """
      defmodule App.Outer do
        defmodule Inner do
          defstruct [:a]
        end

        def build, do: %Inner{a: 1}
      end
      """

      assert triggers(source) == ["%Inner{"]
    end

    test "B6 (crew:120): a struct literal as a default argument" do
      source = """
      defmodule App.Agents.Managers.StartAgent do
        def run(turn \\\\ %App.Turn{}), do: turn
      end
      """

      assert triggers(source) == ["%App.Turn{"]
    end

    test "B7 (crew:131): a struct literal in a module attribute" do
      source = """
      defmodule App.Agents.Managers.StartAgent do
        @default %App.Turn{}
        def run, do: @default
      end
      """

      assert triggers(source) == ["%App.Turn{"]
    end

    test "B8 (crew:143): a struct literal in a cond condition" do
      source = """
      defmodule App.Agents.Managers.StartAgent do
        def run(t) do
          cond do
            t == %App.Turn{} -> :empty
            true -> :full
          end
        end
      end
      """

      assert triggers(source) == ["%App.Turn{"]
    end

    test "B9 (crew:159): a struct literal in a case clause body" do
      source = """
      defmodule App.Agents.Managers.StartAgent do
        def run(x) do
          case x do
            :new -> %App.Turn{}
          end
        end
      end
      """

      assert triggers(source) == ["%App.Turn{"]
    end

    test "B10 (crew:174): struct/1,2 and struct!/1,2 naming another module" do
      source = """
      defmodule App.Agents.Managers.StartAgent do
        alias App.Turn

        def a, do: struct(Turn, status: :idle)
        def b, do: struct!(Turn, status: :idle)
        def c, do: Kernel.struct(Turn, [])
        def d, do: struct(Turn)
        def e, do: Kernel.struct!(Turn)
      end
      """

      assert triggers(source) == ["struct", "struct", "struct", "struct!", "struct!"]
    end

    test "B11 (crew:190): a file outside any module still may not build a struct" do
      assert triggers("%App.Turn{status: :idle}\n") == ["%App.Turn{"]
    end
  end

  describe "changing another module's struct (crew:205-329)" do
    test "C1 (crew:206): struct update syntax naming another module" do
      source = """
      defmodule App.Agents.Managers.StartAgent do
        def run(t), do: %App.Turn{t | status: :idle}
      end
      """

      assert triggers(source) == ["%App.Turn{"]
    end

    test "C2 (crew:217): map update syntax on a value matched in the head" do
      source = """
      defmodule App.Agents.Framework.AgentServer do
        alias App.Agents.Domain.ServerState

        def handle_call(%DescribeRequest{text: text}, _from, %ServerState{} = state),
          do: {:reply, :ok, %{state | description: text}}
      end
      """

      assert triggers(source) == ["%{state |"]
    end

    test "C3 (crew:231): matched in the body, in a case clause and in a with clause" do
      source = """
      defmodule App.Agents.Managers.StartAgent do
        def a(x) do
          %App.Turn{} = t = x
          %{t | status: :idle}
        end

        def b(x) do
          case x do
            %App.Turn{} = t -> %{t | status: :idle}
          end
        end

        def c(x) do
          with %App.Turn{} = t <- x, do: %{t | status: :idle}
        end
      end
      """

      assert triggers(source) == ["%{t |", "%{t |", "%{t |"]
    end

    test "C4 (crew:254): each Map writer on a matched value" do
      source = """
      defmodule App.Agents.Managers.StartAgent do
        def a(%App.Turn{} = t), do: Map.put(t, :status, :idle)
        def b(%App.Turn{} = t), do: Map.merge(t, %{status: :idle})
        def c(%App.Turn{} = t), do: Map.update!(t, :n, &(&1 + 1))
        def d(%App.Turn{} = t), do: Map.replace(t, :n, 1)
        def e(%App.Turn{} = t), do: Map.put_new(t, :n, 1)
        def f(%App.Turn{} = t), do: Map.delete(t, :n)
        def g(%App.Turn{} = t), do: Map.drop(t, [:n])
      end
      """

      assert triggers(source) == [
               "Map.delete",
               "Map.drop",
               "Map.merge",
               "Map.put",
               "Map.put_new",
               "Map.replace",
               "Map.update!"
             ]
    end

    test "C5 (crew:281): a Map writer in a pipe" do
      source = """
      defmodule App.Agents.Managers.StartAgent do
        def a(%App.Turn{} = t), do: t |> Map.put(:status, :idle)
      end
      """

      assert triggers(source) == ["Map.put"]
    end

    test "C6 (crew:292): struct/2 on a matched value" do
      source = """
      defmodule App.Agents.Managers.StartAgent do
        def a(%App.Turn{} = t), do: struct(t, status: :idle)
      end
      """

      assert triggers(source) == ["struct"]
    end

    test "C7 (crew:303): put_in, update_in and the other path functions on a matched value" do
      source = """
      defmodule App.Agents.Managers.StartAgent do
        def a(%App.Turn{} = t), do: put_in(t.status, :idle)
        def b(%App.Turn{} = t), do: put_in(t, [:status], :idle)
        def c(%App.Turn{} = t), do: update_in(t.n, &(&1 + 1))
        def d(%App.Turn{} = t), do: put_in(t[:usage].total, 1)
        def e(%App.Turn{} = t), do: pop_in(t.n)
        def f(%App.Turn{} = t), do: get_and_update_in(t.n, &{&1, &1 + 1})
        def g(%App.Turn{} = t), do: Kernel.put_in(t.n, 1)
      end
      """

      assert triggers(source) == [
               "get_and_update_in",
               "pop_in",
               "put_in",
               "put_in",
               "put_in",
               "put_in",
               "update_in"
             ]
    end
  end

  describe "the struct's own module (crew:331-385)" do
    test "O1 (crew:332): builds and changes its own struct by __MODULE__ and by full name" do
      source = """
      defmodule App.Agents.Domain.AgentState.Transcript do
        defstruct entries: [], next_id: 1

        @type t :: %__MODULE__{entries: list(), next_id: pos_integer()}

        def new, do: %__MODULE__{}
        def new_full, do: %App.Agents.Domain.AgentState.Transcript{}
        def from(kw), do: struct!(__MODULE__, kw)

        def append(%__MODULE__{} = t, entry),
          do: %{t | entries: [Entry.with_id(entry, t.next_id) | t.entries], next_id: t.next_id + 1}

        def bump(%__MODULE__{} = t), do: %__MODULE__{t | next_id: t.next_id + 1}
        def put(%__MODULE__{} = t, v), do: Map.put(t, :next_id, v)
        def path(%__MODULE__{} = t, v), do: put_in(t.next_id, v)
        def piped(%__MODULE__{} = t), do: t |> Map.merge(%{next_id: 1})
      end
      """

      assert detect(source) == []
    end

    test "O2 (crew:356): a nested module builds its own struct through the automatic alias" do
      source = """
      defmodule App.Outer do
        defmodule Inner do
          defstruct [:a]
          def new, do: %Inner{a: 1}
          def set(%Inner{} = i), do: %{i | a: 2}
        end
      end
      """

      assert detect(source) == []
    end

    test "O3 (crew:370): an alias that names the module itself" do
      source = """
      defmodule App.Agents.Domain.Turn do
        alias __MODULE__
        alias App.Agents.Domain.Turn, as: Self

        defstruct [:status]
        def new, do: %Turn{}
        def other, do: %Self{}
      end
      """

      assert detect(source) == []
    end
  end

  describe "reading and matching (crew:386-490)" do
    test "R1 (crew:387): patterns in heads, case, with, fn, receive, for, match? and =" do
      source = """
      defmodule App.Agents.Framework.AgentServer do
        alias App.Agents.Domain.{ServerState, Turn}
        alias App.Agents.Managers.HandleEvent

        def handle_call(%DescribeRequest{text: text}, _from, %ServerState{} = state),
          do: {:reply, :ok, ServerState.set_description(state, text)}

        def handle_info(msg, state) when is_struct(msg, Turn) do
          case msg do
            %Turn{status: :idle} -> {:noreply, state}
            %Turn{} = t -> {:noreply, HandleEvent.handle(state, t)}
          end
        end

        def a(x) do
          with %Turn{status: s} <- x, %ServerState{} = st <- s do
            st
          else
            %Turn{} -> :turn
          end
        end

        def b(xs), do: for(%Turn{status: s} <- xs, do: s)
        def c(x), do: match?(%Turn{status: :idle}, x)
        def d(x), do: Enum.map(x, fn %Turn{status: s} -> s end)
        def e do
          receive do
            %Turn{} = t -> t
          end
        end
        def f(x) do
          %Turn{status: s} = x
          s
        end
      end
      """

      assert detect(source) == []
    end

    test "R2 (crew:429): field reads, Map.get and Map.from_struct" do
      source = """
      defmodule App.Agents.Managers.StartAgent do
        def a(%App.Turn{} = t), do: {t.status, Map.get(t, :n), Map.from_struct(t), t[:x]}
      end
      """

      assert detect(source) == []
    end

    test "R3 (crew:439): typespecs and callbacks naming another module's struct" do
      source = """
      defmodule App.Agents.Managers.StartAgent do
        @type turn :: %App.Turn{}
        @typep p :: %App.Turn{status: atom()}
        @opaque o :: %App.Turn{}
        @callback cb(%App.Turn{}) :: %App.Turn{}
        @spec a(%App.Turn{}) :: %App.Turn{}
        def a(t), do: t
      end
      """

      assert detect(source) == []
    end

    test "R4 (crew:454): plain maps whose type is not known" do
      source = """
      defmodule App.Agents.Managers.StartAgent do
        def a(m), do: %{m | a: 1}
        def b(m), do: Map.put(m, :a, 1)
        def c(%{} = m), do: Map.merge(m, %{a: 1})
        def d(m), do: put_in(m.a, 1)
      end
      """

      assert detect(source) == []
    end

    test "R5 (crew:467): a variable matched as different structs in different clauses" do
      source = """
      defmodule App.Agents.Managers.StartAgent do
        def a(x) do
          case x do
            %App.Turn{} = v -> v
            %__MODULE__{} = v -> %{v | a: 1}
          end
        end

        def b(x) do
          case x do
            %App.Agents.Domain.Turn{} = v -> v
            %__MODULE__{} = v -> %{v | a: 1}
          end
        end
      end
      """

      assert detect(source) == []
    end
  end

  describe "a variable is known only when every binding agrees (crew:492-534)" do
    test "K1 (crew:493): rebound to a plain map" do
      source = """
      defmodule App.Agents.Adapters.Codec do
        def to_map(%App.Msg{} = msg) do
          msg = Map.from_struct(msg)
          Map.put(msg, :type, "msg")
        end
      end
      """

      assert detect(source) == []
    end

    test "K2 (crew:506): an fn argument with the same name as a head variable" do
      source = """
      defmodule App.Agents.Framework.AgentServer do
        def handle(%App.Other{} = state, items) do
          items
          |> Enum.reduce(%{}, fn item, state -> Map.put(state, item, true) end)
          |> then(fn m -> {state, m} end)
        end
      end
      """

      assert detect(source) == []
    end

    test "K3 (crew:520): bound bare in another case clause" do
      source = """
      defmodule App.Agents.Managers.StartAgent do
        def a(value) do
          case value do
            %App.Other{} = v -> App.Other.go(v)
            v -> %{v | seen: true}
          end
        end
      end
      """

      assert detect(source) == []
    end

    test "K4 (new): a variable bound to a function's return is not known here (DND-5454's)" do
      source = """
      defmodule App.Agents.Managers.StartAgent do
        def a do
          s = App.Turn.new()
          %{s | status: :idle}
        end
      end
      """

      assert detect(source) == []
    end
  end

  describe "resolving the module the way Elixir does (crew:536-603)" do
    test "M1 (crew:537): an alias resolved through an earlier alias, naming the module itself" do
      source = """
      defmodule A.B.Turn do
        alias A.B
        alias B.Turn

        defstruct [:x]
        def new, do: %Turn{}
      end
      """

      assert detect(source) == []

      # Positive control: the same alias chain from another module is flagged.
      other = """
      defmodule A.B.Other do
        alias A.B
        alias B.Turn

        def new, do: %Turn{}
      end
      """

      assert [%{message: message}] = detect(other)
      assert message =~ "Only A.B.Turn's own module"
    end

    test "M2 (crew:551): a defimpl for a struct is that struct's own code" do
      source = """
      defmodule App.Bag do
        defstruct items: []

        defimpl Collectable do
          def into(%App.Bag{} = b), do: {b, fn b, {:cont, x} -> %App.Bag{b | items: [x | b.items]} end}
        end
      end

      defimpl Inspect, for: App.Bag do
        def inspect(%App.Bag{} = b, _opts), do: inspect(%{b | items: []})
      end
      """

      assert detect(source) == []

      # Positive control: an impl for another type may not change App.Bag.
      other = """
      defimpl Inspect, for: App.Box do
        def inspect(%App.Bag{} = b, _opts), do: inspect(%{b | items: []})
      end
      """

      assert triggers(other) == ["%{b |"]
    end

    test "M3 (crew:569): a defimpl with unquoted options does not crash" do
      source = """
      defmodule App.Gen do
        defmacro impl(opts) do
          quote do
            defimpl Inspect, unquote(opts)
          end
        end
      end

      defimpl Inspect, unquote(opts)
      """

      assert detect(source) == []
    end

    test "M4 (crew:583): Kernel.match? is a pattern too" do
      source = """
      defmodule App.Agents.Managers.StartAgent do
        def a(x), do: Kernel.match?(%App.Turn{}, x)
      end
      """

      assert detect(source) == []
    end

    test "M5 (crew:593): dropping :__struct__ converts to a plain map" do
      source = """
      defmodule App.Agents.Adapters.Codec do
        def a(%App.Turn{} = t), do: Map.drop(t, [:__struct__, :secret])
        def b(%App.Turn{} = t), do: Map.delete(t, :__struct__)
      end
      """

      assert detect(source) == []
    end

    test "M6 (new): a struct literal inside quote is not reported" do
      source = """
      defmodule App.Gen do
        defmacro build do
          quote do
            %App.Turn{}
          end
        end
      end
      """

      assert detect(source) == []
    end
  end

  describe "owned_namespaces (crew:605-642)" do
    test "N1 (crew:608): stdlib and dependency structs are not the repo's to own" do
      source = """
      defmodule App.Agents.Adapters.Paths do
        def with_path(%URI{} = uri, path), do: %{uri | path: path}
        def trunc(%DateTime{} = dt), do: %{dt | microsecond: {0, 0}}
        def set, do: %MapSet{}
      end
      """

      assert detect(source, @owned) == []
      # Positive control: without owned_namespaces every struct is checked.
      assert length(detect(source)) == 3
    end

    test "N2 (crew:620): a repo struct is still flagged" do
      source = """
      defmodule App.Agents.Managers.StartAgent do
        def run, do: %App.Turn{}
      end
      """

      assert triggers(source, @owned) == ["%App.Turn{"]
    end

    test "N3 (crew:630): a module outside the owned namespaces is reported" do
      source = """
      defmodule NewApp.Thing do
        def run, do: %NewApp.Other{}
      end
      """

      assert [violation] = detect(source, @owned)
      assert violation.trigger == "NewApp.Thing"
      assert violation.line == 1
      assert violation.message =~ "owned_namespaces"
    end

    test "a namespace covers itself and its nested modules, not a name it prefixes" do
      source = """
      defmodule App.Agents.Managers.StartAgent do
        def a, do: %App{}
        def b, do: %App.Deep.Turn{}
        def c, do: %AppOther.Turn{}
      end
      """

      assert triggers(source, @owned) == ["%App.Deep.Turn{", "%App{"]
    end
  end

  describe "test code is exempt by selection (crew:644-672)" do
    # T1 (crew:651/657, a test path) is selection: Anchor.E2E.ChecksE2ETest F2.
    test "T2 (crew:663): the same code in lib is flagged twice" do
      source = """
      defmodule App.Agents.Domain.DeciderTest do
        def setup_state(%App.Turn{} = t), do: {%App.AgentState{turn: t}, %{t | status: :idle}}
      end
      """

      assert length(detect(source)) == 2
    end
  end

  test "no rules, no violations" do
    assert detect("%App.Turn{}\n", []) == []
  end

  describe "shape/1" do
    test "S1: the exact conforming shape" do
      assert Check.shape(%{}) == @shape
    end
  end
end
