defmodule Anchor.Domain.GraphKey do
  @moduledoc """
  The key of a graph artifact (DND-5440, shared contract section 2) — a
  **Domain** module (ADR 001). Pure: a sha256 over the inputs the graph was
  built from, so an artifact built from other inputs is never mistaken for
  this build's. `:crypto.hash/2` is a pure function.

  The key covers every beam's `{path, bytes}` entry and every source file's
  `{path, bytes}` entry, each list sorted by path (so the order the ebins
  were read in does not matter), the config's bytes and Anchor's version. A
  source entry's bytes are the file's `SourceFacts` (DND-5586): the graph
  takes `generated?` and the literal `use`s from them, and a source edit can
  change them without changing a beam. Each part is length-prefixed and each
  list is preceded by its length, so no two different inputs hash the same
  concatenation.

  The verdict never reads an artifact: `mix anchor.explain` and `place` do,
  and a key mismatch means rebuild, never use.
  """

  @doc """
  The lower-case hex sha256 of the beam entries and the source entries (each
  sorted by path), the config and the version.
  """
  @spec key([{String.t(), binary()}], [{String.t(), binary()}], binary(), String.t()) ::
          String.t()
  def key(beam_entries, source_entries, config_bytes, version)
      when is_list(beam_entries) and is_list(source_entries) and is_binary(config_bytes) and
             is_binary(version) do
    ([framed(version), framed(config_bytes)] ++
       section(beam_entries) ++ section(source_entries))
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  # A list of entries: its length, then each path and its bytes, by path.
  defp section(entries) do
    parts =
      entries
      |> Enum.sort_by(fn {path, _bytes} -> path end)
      |> Enum.flat_map(fn {path, bytes} -> [framed(path), framed(bytes)] end)

    [<<length(entries)::unsigned-64>> | parts]
  end

  defp framed(part), do: [<<byte_size(part)::unsigned-64>>, part]
end
