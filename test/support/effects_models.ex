defmodule Anchor.Test.EffectsModels do
  @moduledoc """
  Hand-built models for the effect inference and the `effects_match_bucket`
  rule (DND-5447): no beams, no Core. A module is
  `{module, bucket, [function], opts}` with each function `{name, arity}` (a
  `def`) or `{name, arity, kind}`; `opts` may hold `:behaviours`. A call is
  `{from, to}` or `{from, to, kind}`; `to` is an mfa or a `{:dynamic, ...}`
  target. Buckets are named by their role (`domain`, `adapters`, `managers`,
  `framework`), each module in a source file under `lib/<bucket>/`.
  """

  alias Anchor.Config
  alias Anchor.Domain.Architecture
  alias Anchor.Domain.Classification
  alias Anchor.Domain.Graph
  alias Anchor.Domain.Graph.Call
  alias Anchor.Domain.Graph.FunctionNode
  alias Anchor.Domain.Graph.ModuleNode
  alias Anchor.Domain.Model

  @buckets ~w(framework managers adapters domain)

  @doc """
  The model of `modules` and `calls`. `opts`: `:effects` (extra effect
  tokens), `:roots` (root selectors, as `.anchor.yml` writes them), `:infer`
  (`%{bucket => boolean}`), `:unreadable` (graph entries).
  """
  @spec model([tuple()], [tuple()], keyword()) :: Model.t()
  def model(modules, calls, opts \\ []) do
    architecture = architecture(opts)

    nodes =
      Map.new(modules, fn {module, bucket, functions, module_opts} ->
        {module,
         %ModuleNode{
           module: module,
           app: :app,
           source_file: file(module, bucket),
           behaviours: Keyword.get(module_opts, :behaviours, []),
           functions: Map.new(functions, &function(module, &1))
         }}
      end)

    classification =
      Map.new(modules, fn {module, bucket, _functions, _opts} ->
        {module,
         %Classification{
           module: module,
           bucket: bucket,
           role: String.to_atom(bucket),
           context: nil,
           source_file: file(module, bucket)
         }}
      end)

    facts =
      Map.new(modules, fn {module, bucket, _functions, module_opts} ->
        {module,
         %{
           module: module,
           app: :app,
           source_file: file(module, bucket),
           line: 1,
           uses: [],
           behaviours: Keyword.get(module_opts, :behaviours, []),
           exports: []
         }}
      end)

    %Model{
      graph: %Graph{
        modules: nodes,
        calls: Enum.map(calls, &call/1),
        unreadable: Keyword.get(opts, :unreadable, [])
      },
      architecture: architecture,
      classification: classification,
      config: %Config{rules: [], path: ".anchor.yml", architecture: architecture},
      facts: facts
    }
  end

  @doc "The source file a module of `bucket` is in."
  @spec file(module(), String.t()) :: String.t()
  def file(module, bucket), do: "lib/#{bucket}/#{module |> Module.split() |> List.last()}.ex"

  defp architecture(opts) do
    infer = Keyword.get(opts, :infer, %{})

    section =
      %{
        "contexts" => %{"depth" => 1},
        "buckets" =>
          Enum.map(@buckets, fn name ->
            %{"name" => name, "role" => name, "select" => [%{"paths" => ["lib/#{name}/**"]}]}
            |> then(
              &if(Map.has_key?(infer, name), do: Map.put(&1, "infer", infer[name]), else: &1)
            )
          end),
        "calls" => Map.new(@buckets, &{&1, @buckets}),
        "effects" => Keyword.get(opts, :effects, []),
        "roots" => Keyword.get(opts, :roots, [])
      }

    {:ok, architecture} = Architecture.parse(section)
    architecture
  end

  defp function(module, {name, arity}), do: function(module, {name, arity, :def})

  defp function(module, {name, arity, kind}) do
    {{name, arity},
     %FunctionNode{module: module, name: name, arity: arity, kind: kind, line: 10 + arity}}
  end

  defp call({from, to}), do: call({from, to, :remote})

  defp call({from, to, kind}),
    do: %Call{from: from, to: to, kind: kind, line: 7, line_source: :call}
end
