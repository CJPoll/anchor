defmodule Anchor.Domain.CallNamesTest do
  # Domain (ADR 002). DND-5613: one call-site name normalization for the graph
  # and the AST engines, across the calls Elixir inlines before Core.
  #
  #   * Over-match in the graph: Process.monitor/1 and Port.monitor/1 both
  #     compile to :erlang.monitor/2, told apart only by a literal first
  #     argument (:process, :port). The walker reads that tag back into the
  #     Elixir name, so a rule naming one matches only its own function.
  #   * Engine drift: a rule may name the Elixir or the Erlang spelling
  #     (Map.put/3 or :maps.put/3), and both engines match a call site in
  #     either spelling.
  #   * An inline no tag tells apart (Bitwise.band/2 and Bitwise.&&&/2, both
  #     :erlang.band/2) stays ambiguous, and its description names every
  #     candidate source function.
  #
  # Fixtures compile in the test (Anchor.Test.BeamFixtures), under
  # AnchorFixtures.CallNamesTest.*.
  #
  # Sabotage record: ../../sabotage_records/inlines-20261103-dnd_5447_graph_rules_c.md
  use ExUnit.Case, async: true

  import Anchor.Test.BeamFixtures

  alias Anchor.Domain.Checks.NoDependency
  alias Anchor.Domain.FunctionRef
  alias Anchor.Domain.Graph
  alias Anchor.Domain.Graph.CoreWalker
  alias Anchor.Domain.Graph.Inlines
  alias AnchorFixtures.CallNamesTest.M

  @source """
  defmodule AnchorFixtures.CallNamesTest.M do
    def proc(pid), do: Process.monitor(pid) # proc
    def port(p), do: Port.monitor(p) # port
    def proc2(pid, opts), do: Process.monitor(pid, opts) # proc2
    def erl_tagged(pid), do: :erlang.monitor(:process, pid) # erl_tagged
    def untagged(type, pid), do: :erlang.monitor(type, pid) # untagged
    def short(x), do: Float.to_string(x) # short
    def band(a, b), do: Bitwise.band(a, b) # band
    def put(m, k), do: Map.put(m, k, 1) # put
    def erlput(m), do: :maps.put(:k, 1, m) # erlput
  end
  """

  setup_all do
    [{M, binary}] = compile_unloaded(@source, "lib/m.ex")
    %{binary: binary}
  end

  defp callees(binary, name_arity) do
    {calls, _uses} = CoreWalker.walk(M, name_arity, core_fun!(binary, name_arity))
    Enum.map(calls, & &1.to)
  end

  defp graph(binary) do
    calls =
      for name_arity <- [
            proc: 1,
            port: 1,
            proc2: 2,
            erl_tagged: 1,
            untagged: 2,
            band: 2,
            put: 2,
            erlput: 1
          ],
          call <- elem(CoreWalker.walk(M, name_arity, core_fun!(binary, name_arity)), 0),
          do: call

    %Graph{calls: calls}
  end

  defp callers(graph, mfa), do: graph |> Graph.calls_to(mfa) |> Enum.map(& &1.from) |> Enum.uniq()

  describe "the walker reads an inline's tag back into its Elixir name" do
    test "Process.monitor/1 and Port.monitor/1 are two edges, each its own name", %{binary: b} do
      assert {Process, :monitor, 1} in callees(b, {:proc, 1})
      assert {Port, :monitor, 1} in callees(b, {:port, 1})
      refute {:erlang, :monitor, 2} in callees(b, {:proc, 1})
      refute {:erlang, :monitor, 2} in callees(b, {:port, 1})
    end

    test "Process.monitor/2 is read from :erlang.monitor/3 with the :process tag", %{binary: b} do
      assert {Process, :monitor, 2} in callees(b, {:proc2, 2})
    end

    test "the Erlang spelling with a literal tag is the same function as its Elixir name", %{
      binary: b
    } do
      assert {Process, :monitor, 1} in callees(b, {:erl_tagged, 1})
    end

    test "a tag that is not a literal leaves the Erlang name (ambiguous)", %{binary: b} do
      assert {:erlang, :monitor, 2} in callees(b, {:untagged, 2})
    end

    test "Float.to_string/1 is read from :erlang.float_to_binary/2 with [:short]", %{binary: b} do
      assert {Float, :to_string, 1} in callees(b, {:short, 1})
    end

    test "an untagged inline keeps its Erlang name (positive control)", %{binary: b} do
      assert {:erlang, :band, 2} in callees(b, {:band, 2})
    end
  end

  describe "graph: a rule naming one tagged function matches only its own calls" do
    test "Process.monitor/1 finds proc and the ambiguous call, never Port.monitor", %{binary: b} do
      graph = graph(b)

      assert callers(graph, {Process, :monitor, 1}) ==
               [{M, :proc, 1}, {M, :erl_tagged, 1}, {M, :untagged, 2}]

      assert callers(graph, {Port, :monitor, 1}) == [{M, :port, 1}, {M, :untagged, 2}]
    end

    test "the Erlang name finds every call that compiles to it", %{binary: b} do
      assert callers(graph(b), {:erlang, :monitor, 2}) ==
               [{M, :proc, 1}, {M, :port, 1}, {M, :erl_tagged, 1}, {M, :untagged, 2}]
    end

    test "Map.put/3 and :maps.put/3 each find both spellings", %{binary: b} do
      graph = graph(b)
      both = [{M, :put, 2}, {M, :erlput, 1}]

      assert callers(graph, {Map, :put, 3}) == both
      assert callers(graph, {:maps, :put, 3}) == both
    end
  end

  describe "AST: a rule naming either spelling matches a source call in either" do
    defp ast_triggers(body, tokens) do
      refs = Enum.map(tokens, fn token -> token |> FunctionRef.parse() |> elem(1) end)

      rule = %{
        forbidden_modules: [],
        forbidden_patterns: [],
        forbidden_functions: refs,
        match: :call
      }

      source = "defmodule W do\n#{body}\nend"

      source
      |> Code.string_to_quoted!()
      |> NoDependency.detect_violations([rule])
      |> Enum.map(& &1.trigger)
    end

    test "a rule naming :maps.put/3 matches a source Map.put/3" do
      assert ast_triggers("  def a(m), do: Map.put(m, :k, 1)", [":maps.put/3"]) == ["Map.put/3"]
    end

    test "a rule naming Map.put/3 matches a source :maps.put/3" do
      assert ast_triggers("  def a(m), do: :maps.put(:k, 1, m)", ["Map.put/3"]) == [
               ":maps.put/3"
             ]
    end

    test "a rule naming Map.put (any arity) matches a source :maps.put/3" do
      assert ast_triggers("  def a(m), do: :maps.put(:k, 1, m)", ["Map.put"]) == [":maps.put/3"]
    end

    test "a rule naming Process.monitor/1 does not match a source Port.monitor/1" do
      assert ast_triggers("  def a(p), do: Port.monitor(p)", ["Process.monitor/1"]) == []
      # Positive control: the rule matches its own function.
      assert ast_triggers("  def a(p), do: Process.monitor(p)", ["Process.monitor/1"]) == [
               "Process.monitor/1"
             ]
    end

    test "a rule naming :erlang.monitor/2 matches both Elixir names" do
      body = "  def a(p), do: Process.monitor(p)\n  def b(p), do: Port.monitor(p)"

      assert body |> ast_triggers([":erlang.monitor/2"]) |> Enum.sort() == [
               "Port.monitor/1",
               "Process.monitor/1"
             ]
    end
  end

  describe "an ambiguous inline names every candidate source function" do
    test "Bitwise.band/2 and &&&/2 are both candidates of :erlang.band/2" do
      assert Inlines.candidates({:erlang, :band, 2}) ==
               [{Bitwise, :&&&, 2}, {Bitwise, :band, 2}, {:erlang, :band, 2}]

      assert Inlines.ambiguous?({:erlang, :band, 2})
      assert Inlines.describe({:erlang, :band, 2}) =~ "Bitwise.&&&/2"
      assert Inlines.describe({:erlang, :band, 2}) =~ "Bitwise.band/2"
      assert Inlines.describe({:erlang, :band, 2}) =~ ":erlang.band/2"
    end

    test "an untagged :erlang.monitor/2 names Process.monitor/1 and Port.monitor/1" do
      described = Inlines.describe({:erlang, :monitor, 2})
      assert described =~ "Process.monitor/1"
      assert described =~ "Port.monitor/1"
    end

    test "a tag-resolved or single-name call is not ambiguous (positive control)" do
      refute Inlines.ambiguous?({Process, :monitor, 1})
      refute Inlines.ambiguous?({:maps, :put, 3})
      assert Inlines.describe({Process, :monitor, 1}) == "Process.monitor/1"
      assert Inlines.describe({:maps, :put, 3}) == "Map.put/3"
      assert Inlines.describe({Enum, :map, 2}) == "Enum.map/2"
    end
  end
end
