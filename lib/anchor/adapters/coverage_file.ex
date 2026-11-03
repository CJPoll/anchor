defmodule Anchor.Adapters.CoverageFile do
  @moduledoc """
  The coverage map file (DND-5474), the **Side Effect** adapter (ADR 001)
  behind `Anchor.Adapters.CoverageStore`: `:erlang.term_to_binary/1` on write,
  `:erlang.binary_to_term(bin, [:safe])` on read, so a file from an artifact
  can never create an atom or a function.
  """

  @behaviour Anchor.Adapters.CoverageStore

  @impl Anchor.Adapters.CoverageStore
  def write(path, map) do
    with :ok <- File.mkdir_p(Path.dirname(path)) do
      File.write(path, :erlang.term_to_binary(map))
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
