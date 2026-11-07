defmodule Anchor.Test.DirectoryModels do
  @moduledoc """
  Hand-built models for directory placement (DND-5462): `Anchor.Test.PlacementModels`'
  model, each module given the source file `files` names (in its classification and its
  graph node) and its `defmodule` on line 3. A module is `{module, bucket, context}`
  with one function `run/0`; a call is `{from_module, to_module}`, `run/0` to `run/0`.
  """

  import Anchor.Test.PlacementModels

  alias Anchor.Domain.Model

  @doc "The model; see the moduledoc. `generated` lists the modules to mark generated."
  @spec directory_model([tuple()], [tuple()], %{module() => String.t()}, [module()]) :: Model.t()
  def directory_model(modules, calls, files, generated \\ []) do
    built =
      model(
        for(
          {module, bucket, context} <- modules,
          do: {module, bucket, [{:run, 0}], context: context}
        ),
        for({from, to} <- calls, do: {{from, :run, 0}, {to, :run, 0}})
      )

    Enum.reduce(modules, built, fn {module, _bucket, _context}, model ->
      file = Map.fetch!(files, module)
      model = put_in(model.classification[module].source_file, file)
      model = put_in(model.graph.modules[module].source_file, file)
      model = put_in(model.graph.modules[module].line, 3)
      put_in(model.graph.modules[module].generated?, module in generated)
    end)
  end
end
