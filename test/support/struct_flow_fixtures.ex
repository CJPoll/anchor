defmodule Anchor.Test.StructFlowFixtures do
  @moduledoc """
  Compiled fixtures for the `struct_owned_by_module_flow` rule (DND-5454):
  sources compiled in the test (`Anchor.Test.BeamFixtures`, every module
  unloaded again), decoded the way the runner decodes them, and built into
  one `%Anchor.Domain.Graph{}` and a model whose every module sits in one
  `domain` bucket. Name fixture modules `AnchorFixtures.StructFlow.<Test>.*`.
  """

  import Anchor.Test.BeamFixtures

  alias Anchor.Adapters.BeamReader
  alias Anchor.Config
  alias Anchor.Domain.Architecture
  alias Anchor.Domain.Graph
  alias Anchor.Domain.Graph.Builder
  alias Anchor.Domain.Model

  @doc "The graph of `sources` (`[{source, file}]`, compiled in order)."
  @spec graph([{String.t(), String.t()}]) :: Graph.t()
  def graph(sources) do
    sources
    |> compile_all_unloaded()
    |> Enum.map(fn {module, binary} ->
      BeamReader.decode(binary, app: :app, path: "ebin/#{module}.beam")
    end)
    |> Builder.build(%{})
  end

  @doc "The model of `graph`: every module named `*AnchorFixtures.*` (a protocol implementation for one included) in one `domain` bucket."
  @spec model(Graph.t()) :: Model.t()
  def model(%Graph{} = graph) do
    {:ok, architecture} =
      Architecture.parse(%{
        "contexts" => %{"depth" => 2},
        "buckets" => [
          %{
            "name" => "domain",
            "role" => "domain",
            "select" => [%{"pattern" => "*AnchorFixtures.*"}]
          }
        ],
        "calls" => %{"domain" => ["domain"]}
      })

    config = %Config{rules: [], architecture: architecture, path: ".anchor.yml"}
    {model, _issues} = Model.build(graph, config, %{})
    model
  end

  @doc "The `c_fun` of `{module, name, arity}` in `graph`."
  @spec core!(Graph.t(), mfa()) :: :cerl.cerl()
  def core!(%Graph{modules: modules}, {module, name, arity}) do
    case get_in(modules, [module, Access.key!(:functions), {name, arity}]) do
      %{core: core} when core != nil ->
        core

      other ->
        raise ArgumentError, "no Core for #{inspect({module, name, arity})}: #{inspect(other)}"
    end
  end
end
