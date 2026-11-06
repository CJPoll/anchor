defmodule Anchor.Adapters.CoverageFile do
  @moduledoc """
  The coverage map file (DND-5474), the **Side Effect** adapter (ADR 001)
  behind `Anchor.Adapters.CoverageStore`: `:erlang.term_to_binary/2`
  (deterministic) on write,
  `:erlang.binary_to_term(bin, [:safe])` on read, so a file from an artifact
  can never create a new atom or an external function reference (it can
  still hold a local fun, which nothing here calls). The shape of what it
  holds is checked by `Anchor.Domain.Sabotage.CoverageMap.check/1`.
  """

  @behaviour Anchor.Adapters.CoverageStore

  @impl Anchor.Adapters.CoverageStore
  def write(path, map) do
    with :ok <- File.mkdir_p(Path.dirname(path)) do
      File.write(path, :erlang.term_to_binary(map, [:deterministic]))
    end
  end

  @impl Anchor.Adapters.CoverageStore
  def read(path) do
    with {:ok, bin} <- File.read(path) do
      decode(bin)
    end
  end

  defp decode(bin) do
    {:ok, :erlang.binary_to_term(bin, [:safe])}
  rescue
    ArgumentError -> {:error, :undecodable}
  end
end
