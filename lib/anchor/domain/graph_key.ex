defmodule Anchor.Domain.GraphKey do
  @moduledoc """
  The key of a graph artifact (DND-5440, shared contract section 2) — a
  **Domain** module (ADR 001). Pure: a sha256 over the inputs the graph was
  built from, so an artifact built from other inputs is never mistaken for
  this build's. `:crypto.hash/2` is a pure function.

  The key covers every `{path, bytes}` entry sorted by path (so the order the
  ebins were read in does not matter), the config's bytes and Anchor's
  version. Each part is length-prefixed, so no two different inputs hash the
  same concatenation.

  The verdict never reads an artifact: `mix anchor.explain` and `place` do,
  and a key mismatch means rebuild, never use.
  """

  @doc "The lower-case hex sha256 of the entries (sorted by path), the config and the version."
  @spec key([{String.t(), binary()}], binary(), String.t()) :: String.t()
  def key(entries, config_bytes, version)
      when is_list(entries) and is_binary(config_bytes) and is_binary(version) do
    parts =
      entries
      |> Enum.sort_by(fn {path, _bytes} -> path end)
      |> Enum.flat_map(fn {path, bytes} -> [path, bytes] end)

    ([version, config_bytes] ++ parts)
    |> Enum.map(&framed/1)
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  defp framed(part), do: [<<byte_size(part)::unsigned-64>>, part]
end
