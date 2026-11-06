defmodule Anchor.Test.WriteFixtures do
  @moduledoc """
  Builds an `%Anchor.Domain.Graph{}` from fixture source compiled in the test
  (DND-5459): the binaries go through the real `BeamReader` decoding (`core_v1`)
  and `Graph.Builder`, and every fixture module is unloaded again
  (`Anchor.Test.BeamFixtures`), so nothing of the project is loaded.
  """

  alias Anchor.Adapters.BeamReader
  alias Anchor.Domain.Graph.Builder
  alias Anchor.Test.BeamFixtures

  @doc "The graph of the modules `source` defines (compiled as `file`)."
  @spec graph!(String.t(), String.t()) :: Anchor.Domain.Graph.t()
  def graph!(source, file \\ "lib/fixture.ex") do
    source
    |> BeamFixtures.compile_unloaded(file)
    |> Enum.map(fn {module, binary} ->
      BeamReader.decode(binary, app: :fixtures, path: "#{module}.beam")
    end)
    |> Builder.build(%{})
  end

  @doc """
  A hand-rolled schema module named `module` with table `table`: a struct and
  a literal `__schema__(:source)` clause, the shape `use Ecto.Schema` emits.
  """
  @spec schema(module(), String.t()) :: String.t()
  def schema(module, table) do
    """
    defmodule #{inspect(module)} do
      defstruct [:id]
      @type t :: %__MODULE__{}
      def __schema__(:source), do: #{inspect(table)}
      def __schema__(_), do: nil
    end
    """
  end

  @doc "A hand-rolled repo module named `module`: each write and `transaction/1,2` as a no-op."
  @spec repo(module()) :: String.t()
  def repo(module) do
    """
    defmodule #{inspect(module)} do
      def insert(x, _opts \\\\ []), do: x
      def insert!(x, _opts \\\\ []), do: x
      def update(x, _opts \\\\ []), do: x
      def update!(x, _opts \\\\ []), do: x
      def delete(x, _opts \\\\ []), do: x
      def delete!(x, _opts \\\\ []), do: x
      def insert_or_update(x, _opts \\\\ []), do: x
      def insert_or_update!(x, _opts \\\\ []), do: x
      def insert_all(x, rows, _opts \\\\ []), do: {x, rows}
      def update_all(x, set, _opts \\\\ []), do: {x, set}
      def delete_all(x, _opts \\\\ []), do: x
      def get(x, id), do: {x, id}
      def all(x), do: x
      def transaction(f, _opts \\\\ []), do: f
    end
    """
  end
end
