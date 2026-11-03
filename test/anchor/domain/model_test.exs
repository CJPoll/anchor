defmodule Anchor.Domain.ModelTest do
  # DND-5440: the one model a graph run builds. Pure Domain over a hand-built
  # graph and source facts: each selector kind classifies through the graph
  # path (paths, pattern, uses_module from SourceFacts, behaviour,
  # exports_function over `def`s only), Erlang modules are opaque, and the
  # model's own issues (uses it cannot read, exports naming nothing).
  #
  # Sabotage record: ../../sabotage_records/graph_runner-20261103-dnd_5440_graph_runner.md
  use ExUnit.Case, async: true

  alias Anchor.Config
  alias Anchor.Domain.Architecture
  alias Anchor.Domain.Graph
  alias Anchor.Domain.Graph.FunctionNode
  alias Anchor.Domain.Graph.ModuleNode
  alias Anchor.Domain.Model

  defp function(module, name, arity, kind),
    do:
      {{name, arity},
       %FunctionNode{module: module, name: name, arity: arity, kind: kind, line: 2}}

  defp module_node(module, file, overrides \\ %{}) do
    struct!(
      %ModuleNode{module: module, app: :x, source_file: file, line: 1, generated?: false},
      overrides
    )
  end

  defp architecture(buckets, extra \\ %{}) do
    {:ok, arch} =
      Architecture.parse(
        Map.merge(
          %{
            "contexts" => %{"depth" => 2},
            "buckets" => buckets,
            "calls" => Map.new(buckets, &{&1["name"], []})
          },
          extra
        )
      )

    arch
  end

  defp bucket(name, selector), do: %{"name" => name, "role" => "domain", "select" => [selector]}

  defp buckets do
    [
      bucket("agg", %{"exports_function" => "__aggregate__/0"}),
      bucket("workers", %{"uses_module" => "GenServer"}),
      bucket("sups", %{"behaviour" => "Supervisor"}),
      bucket("domain", %{"paths" => ["lib/x/domain/**/*.ex"]}),
      bucket("erl", %{"pattern" => "my_erl"})
    ]
  end

  defp graph do
    modules = [
      module_node(X.Agg, "lib/x/agg.ex", %{
        functions: Map.new([function(X.Agg, :__aggregate__, 0, :def)])
      }),
      # A private `__aggregate__/0` is not an export: the paths selector
      # classifies it instead (a negative for exports_function).
      module_node(X.Domain.Priv, "lib/x/domain/priv.ex", %{
        functions: Map.new([function(X.Domain.Priv, :__aggregate__, 0, :defp)])
      }),
      module_node(X.Worker, "lib/x/worker.ex"),
      module_node(X.Sup, "lib/x/sup.ex", %{behaviours: [Supervisor]})
    ]

    %Graph{
      modules: Map.new(modules, &{&1.module, &1}),
      unreadable: [
        %{path: "ebin/my_erl.beam", module: :my_erl, reason: {:not_elixir, :erl_abstract_code}}
      ]
    }
  end

  @source_facts %{
    "lib/x/agg.ex" => %{
      defmodules: ["X.Agg"],
      uses: %{"X.Agg" => []},
      nonliteral_defmodule?: false
    },
    "lib/x/domain/priv.ex" => %{
      defmodules: ["X.Domain.Priv"],
      uses: %{"X.Domain.Priv" => []},
      nonliteral_defmodule?: false
    },
    "lib/x/worker.ex" => %{
      defmodules: ["X.Worker"],
      uses: %{"X.Worker" => ["GenServer"]},
      nonliteral_defmodule?: false
    },
    "lib/x/sup.ex" => %{
      defmodules: ["X.Sup"],
      uses: %{"X.Sup" => []},
      nonliteral_defmodule?: false
    }
  }

  defp config(arch), do: %Config{rules: [], architecture: arch, path: ".anchor.yml"}

  describe "build/3 classification through the graph" do
    test "each selector kind classifies its module; no issues when every module lands once" do
      {model, issues} = Model.build(graph(), config(architecture(buckets())), @source_facts)

      assert issues == []

      assert Map.new(model.classification, fn {module, c} -> {module, c.bucket} end) == %{
               X.Agg => "agg",
               X.Domain.Priv => "domain",
               X.Worker => "workers",
               X.Sup => "sups",
               :my_erl => "erl"
             }
    end

    test "a module's uses come from its file's SourceFacts; with none (or unparseable) it has none" do
      for facts <- [
            Map.delete(@source_facts, "lib/x/worker.ex"),
            Map.put(@source_facts, "lib/x/worker.ex", {:error, :unparseable})
          ] do
        {model, issues} = Model.build(graph(), config(architecture(buckets())), facts)

        refute Map.has_key?(model.classification, X.Worker)
        assert Enum.any?(issues, &(&1.message =~ "X.Worker is in no architecture bucket."))
      end
    end

    test "facts/2 exports only def functions, sorted, and strips Elixir. to find the uses" do
      node =
        module_node(X.Worker, "lib/x/worker.ex", %{
          functions:
            Map.new([
              function(X.Worker, :b, 1, :def),
              function(X.Worker, :a, 0, :def),
              function(X.Worker, :p, 0, :defp),
              function(X.Worker, :m, 1, :defmacro)
            ])
        })

      assert %{exports: [{:a, 0}, {:b, 1}], uses: [GenServer], line: 1} =
               Model.facts(node, @source_facts)
    end
  end

  describe "opaque/1" do
    test "is the Erlang modules a bucket classified" do
      {model, _issues} = Model.build(graph(), config(architecture(buckets())), @source_facts)
      assert Model.opaque(model) == [:my_erl]
    end

    test "an Erlang module no bucket classifies is an issue on its beam, not opaque" do
      buckets = Enum.reject(buckets(), &(&1["name"] == "erl"))
      {model, issues} = Model.build(graph(), config(architecture(buckets)), @source_facts)

      assert Model.opaque(model) == []

      assert [%{filename: "ebin/my_erl.beam", message: ":my_erl is Erlang source" <> _rest}] =
               issues
    end
  end

  describe "build/3 uses it cannot read" do
    @gen_facts Map.put(@source_facts, "lib/x/worker.ex", %{
                 defmodules: [],
                 uses: %{},
                 nonliteral_defmodule?: true
               })

    test "a module its file's literal defmodules do not name, with a uses_module selector, is an issue" do
      {_model, issues} = Model.build(graph(), config(architecture(buckets())), @gen_facts)

      assert Enum.any?(
               issues,
               &(&1.filename == "lib/x/worker.ex" and
                   &1.message =~ "X.Worker's literal uses cannot be read from lib/x/worker.ex")
             )
    end

    test "with no uses_module selector it is not (positive control above)" do
      buckets =
        Enum.reject(buckets(), &(&1["name"] == "workers")) ++
          [bucket("workers", %{"pattern" => "X.Worker"})]

      {_model, issues} = Model.build(graph(), config(architecture(buckets)), @gen_facts)

      assert issues == []
    end
  end

  describe "build/3 interfaces.exports" do
    test "an entry naming no module is an issue; one naming a module, or one the graph could not build, is not" do
      graph = %{
        graph()
        | unreadable: [
            %{path: "ebin/X.Crashed.beam", module: X.Crashed, reason: {:walk_crashed, "boom"}}
            | graph().unreadable
          ]
      }

      arch =
        architecture(buckets(), %{
          "interfaces" => %{"exports" => ["X.Agg", "X.Crashed", "X.Gone"]}
        })

      {_model, issues} = Model.build(graph, config(arch), @source_facts)

      assert [%{filename: ".anchor.yml", message: message}] = issues
      assert message =~ "architecture interfaces.exports names X.Gone, which is no module"
    end
  end
end
