defmodule Anchor.Domain.BehaviourReceiverTest do
  # DND-5633: a dynamic call narrowed to a behaviour's implementers, only on
  # declared evidence (a parameter the caller's @spec types as B.t(), B a
  # project behaviour with `@type t :: module()` and the callback). Pure
  # Domain over a graph built from fixtures compiled in the test, then the
  # layering rule over the same graph.
  #
  # Sabotage record: ../../sabotage_records/layering-20261103-dnd_5648_graph_followups.md
  use ExUnit.Case, async: true

  import Anchor.Test.BeamFixtures

  alias Anchor.Adapters.BeamReader
  alias Anchor.Config
  alias Anchor.Domain.Architecture
  alias Anchor.Domain.BehaviourReceiver
  alias Anchor.Domain.DynamicCalls
  alias Anchor.Domain.Graph
  alias Anchor.Domain.Graph.Builder
  alias Anchor.Domain.Graph.Call
  alias Anchor.Domain.Graph.SourceFacts
  alias Anchor.Domain.GraphRules.Layering
  alias Anchor.Domain.Model

  @ns "AnchorFixtures.BehaviourReceiverTest"

  @port {"""
         defmodule #{@ns}.Port do
           @type t :: module()
           @callback run([String.t()]) :: :ok
         end
         """, "lib/app/adapters/port.ex"}

  @impl_mod {"""
             defmodule #{@ns}.Impl do
               @behaviour #{@ns}.Port
               def run(_args), do: :ok
             end
             """, "lib/app/adapters/impl.ex"}

  # A Mix task exports run/1 too, with no @behaviour of the port.
  @task {"""
         defmodule Mix.Tasks.#{String.replace(@ns, ".", "")}.Go do
           def run(_args), do: :ok
         end
         """, "lib/app/framework/go.ex"}

  # A behaviour that declares no `t :: module()`, and one without the callback.
  @untyped_port {"""
                 defmodule #{@ns}.Untyped do
                   @type t :: atom()
                   @callback run([String.t()]) :: :ok
                 end
                 """, "lib/app/adapters/untyped.ex"}

  @other_port {"""
               defmodule #{@ns}.Other do
                 @type t :: module()
                 @callback check() :: :ok
               end
               """, "lib/app/adapters/other.ex"}

  @manager {"""
            defmodule #{@ns}.Manager do
              @spec typed(#{@ns}.Port.t(), [String.t()]) :: :ok
              def typed(suite, args), do: suite.run(args)

              # Elixir compiles clauses into one case over the parameters.
              @spec two_clauses(#{@ns}.Port.t(), [String.t()]) :: :ok
              def two_clauses(suite, []), do: suite.run([])
              def two_clauses(suite, args), do: suite.run(args)

              def untyped(suite, args), do: suite.run(args)

              @spec as_module(module(), [String.t()]) :: :ok
              def as_module(suite, args), do: suite.run(args)

              @spec not_module_type(#{@ns}.Untyped.t(), [String.t()]) :: :ok
              def not_module_type(suite, args), do: suite.run(args)

              @spec no_callback(#{@ns}.Other.t(), [String.t()]) :: :ok
              def no_callback(suite, args), do: suite.run(args)

              @spec from_options(keyword()) :: :ok
              def from_options(opts), do: Keyword.get(opts, :suite, #{@ns}.Impl).run([])

              @spec rebound(#{@ns}.Port.t(), [String.t()]) :: :ok
              def rebound(suite, args) do
                suite = if args == [], do: suite, else: #{@ns}.Impl
                suite.run(args)
              end

              # A later clause binds the name inside a pattern: not the parameter.
              @spec nested(#{@ns}.Port.t(), [String.t()]) :: :ok
              def nested(suite, []), do: suite.run([])
              def nested(%{suite: suite}, args), do: suite.run(args)

              # A later clause binds the name again in its body.
              @spec inner(#{@ns}.Port.t(), [module()]) :: :ok
              def inner(suite, []), do: suite.run([])

              def inner(_port, [first | _rest]) do
                case first do
                  suite -> suite.run([])
                end
              end

              @spec mixed(#{@ns}.Port.t(), module()) :: :ok
              def mixed(suite, other) do
                suite.run([])
                other.run([])
              end
            end
            """, "lib/app/managers/manager.ex"}

  @sources [@port, @impl_mod, @task, @untyped_port, @other_port, @manager]

  setup_all do
    beams =
      @sources
      |> compile_all_unloaded()
      |> Enum.map(fn {module, binary} ->
        BeamReader.decode(binary, app: :app, path: "ebin/#{module}.beam")
      end)

    facts = Map.new(@sources, fn {text, file} -> {file, SourceFacts.from_source(file, text)} end)
    %{graph: Builder.build(beams, facts), facts: facts}
  end

  defp mod(name), do: Module.concat([@ns, name])
  defp task, do: Module.concat(["Mix.Tasks", String.replace(@ns, ".", ""), "Go"])

  defp call(graph, name, arity) do
    from = {mod(Manager), name, arity}

    Enum.find(graph.calls, fn
      %Call{from: ^from, to: {:dynamic, :run, 1, _receiver}} -> true
      _other -> false
    end) || flunk("no dynamic run/1 call from #{inspect(from)}")
  end

  describe "behaviour/2 and DynamicCalls.targets/2" do
    test "a parameter the @spec types as a behaviour's t() reaches its implementers only", %{
      graph: graph
    } do
      call = call(graph, :typed, 2)
      assert BehaviourReceiver.behaviour(graph, call) == {:ok, mod(Port)}
      assert DynamicCalls.targets(graph, call) == [mod(Impl)]
    end

    test "a function of several clauses narrows too (its parameters are a case's patterns)", %{
      graph: graph
    } do
      assert BehaviourReceiver.behaviour(graph, call(graph, :two_clauses, 2)) == {:ok, mod(Port)}
    end

    # The fail-closed control: no declared evidence, every exporter.
    test "an untyped parameter fans out to every module exporting run/1", %{graph: graph} do
      call = call(graph, :untyped, 2)
      assert BehaviourReceiver.behaviour(graph, call) == :none
      assert DynamicCalls.targets(graph, call) == Enum.sort([mod(Impl), task()])
    end

    test "module(), a t() that is not module(), and a behaviour without the callback fan out",
         %{graph: graph} do
      for name <- [:as_module, :not_module_type, :no_callback] do
        call = call(graph, name, 2)
        assert BehaviourReceiver.behaviour(graph, call) == :none, inspect(name)
        assert DynamicCalls.targets(graph, call) == Enum.sort([mod(Impl), task()])
      end
    end

    test "a receiver read from options, or rebound, is no parameter: it fans out", %{
      graph: graph
    } do
      assert BehaviourReceiver.behaviour(graph, call(graph, :from_options, 1)) == :none
      assert BehaviourReceiver.behaviour(graph, call(graph, :rebound, 2)) == :none
    end

    test "a name a later clause binds in a pattern or its body is no parameter: it fans out", %{
      graph: graph
    } do
      assert BehaviourReceiver.behaviour(graph, call(graph, :nested, 2)) == :none
      assert BehaviourReceiver.behaviour(graph, call(graph, :inner, 2)) == :none
    end

    test "one untyped receiver among the function's run/1 calls keeps them all fanned out", %{
      graph: graph
    } do
      assert BehaviourReceiver.behaviour(graph, call(graph, :mixed, 2)) == :none
    end

    test "implementers/3: the modules declaring the behaviour that export the function", %{
      graph: graph
    } do
      assert BehaviourReceiver.implementers(graph, mod(Port), {:run, 1}) == [mod(Impl)]
      assert BehaviourReceiver.implementers(graph, mod(Port), {:run, 2}) == []
    end
  end

  describe "DynamicCalls.tally/1" do
    test "counts each dynamic call as narrowed or fanned out", %{graph: graph} do
      %{narrowed: narrowed, fanned_out: fanned_out} = DynamicCalls.tally(graph)

      assert {{mod(Manager), :typed, 2}, :run, 1} in narrowed
      assert {{mod(Manager), :two_clauses, 2}, :run, 1} in narrowed
      assert {{mod(Manager), :untyped, 2}, :run, 1} in fanned_out
      assert {{mod(Manager), :from_options, 1}, :run, 1} in fanned_out
      assert MapSet.disjoint?(MapSet.new(narrowed), MapSet.new(fanned_out))
    end

    test "a graph with no dynamic call tallies none" do
      assert DynamicCalls.tally(%Graph{}) == %{narrowed: [], fanned_out: []}
    end
  end

  # The admiral's acceptance (DND-5633): a Manager's call on a behaviour-typed
  # receiver is no managers -> framework finding against a Mix task exporting
  # run/1; an untyped receiver still is.
  describe "the layering rule over the narrowed call" do
    setup %{graph: graph, facts: facts} do
      {:ok, arch} =
        Architecture.parse(%{
          "contexts" => %{"depth" => 2},
          "buckets" =>
            Enum.map(~w(framework managers adapters), fn name ->
              %{
                "name" => name,
                "role" => name,
                "select" => [%{"paths" => ["lib/app/#{name}/**"]}]
              }
            end),
          "calls" => %{
            "framework" => ["framework", "managers", "adapters"],
            "managers" => ["managers", "adapters"],
            "adapters" => ["adapters"]
          }
        })

      {model, []} = Model.build(graph, %Config{architecture: arch, path: ".anchor.yml"}, facts)
      %{model: model}
    end

    test "a typed receiver gives no finding; an untyped one reaches the Mix task", %{
      model: model
    } do
      violations =
        Layering.check(model, %{type: :layering, id: "l", paths: ["lib/app/managers/**"]})

      callers = violations |> Enum.map(& &1.trigger) |> MapSet.new()

      refute "#{@ns}.Manager.typed/2" in callers
      refute "#{@ns}.Manager.two_clauses/2" in callers

      # Positive control: the untyped receiver still over-approximates.
      assert "#{@ns}.Manager.untyped/2" in callers

      assert Enum.any?(
               violations,
               &(&1.key == "l|#{@ns}.Manager.untyped/2|-> #{inspect(task())}.run/1")
             )
    end
  end
end
