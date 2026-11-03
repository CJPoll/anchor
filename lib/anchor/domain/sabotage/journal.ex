defmodule Anchor.Domain.Sabotage.Journal do
  @moduledoc """
  The in-flight journal of a sabotage run (DND-5473): written before a mutant
  touches a file, deleted once the original is back and verified. Pure
  **Domain**: the entry, its hashes and its bytes on disk
  (`.anchor/sabotage/in-flight.json`, JSON with the original base64-encoded,
  so any bytes round-trip). The file I/O is `Anchor.Adapters.SourcePatcher`'s.

  A leftover journal (the BEAM was killed between apply and restore) is read
  first on the next run: `recovery/2` says what to do with it.
  """

  @path ".anchor/sabotage/in-flight.json"

  @enforce_keys [:file, :mutant_id, :original, :original_sha, :mutated_sha]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          file: String.t(),
          mutant_id: String.t(),
          original: binary(),
          original_sha: String.t(),
          mutated_sha: String.t()
        }

  @doc "The journal's path, relative to the project root."
  @spec path() :: String.t()
  def path, do: @path

  @doc "The entry for applying `mutated` over `original` in `file`."
  @spec entry(String.t(), String.t(), binary(), binary()) :: t()
  def entry(file, mutant_id, original, mutated) do
    %__MODULE__{
      file: file,
      mutant_id: mutant_id,
      original: original,
      original_sha: sha256(original),
      mutated_sha: sha256(mutated)
    }
  end

  @doc "Lowercase hex sha256 of `bytes`."
  @spec sha256(binary()) :: String.t()
  def sha256(bytes), do: :sha256 |> :crypto.hash(bytes) |> Base.encode16(case: :lower)

  @spec encode(t()) :: binary()
  def encode(%__MODULE__{} = entry) do
    JSON.encode!(%{
      "version" => 1,
      "file" => entry.file,
      "mutant_id" => entry.mutant_id,
      "original_base64" => Base.encode64(entry.original),
      "original_sha256" => entry.original_sha,
      "mutated_sha256" => entry.mutated_sha
    })
  end

  @doc "The entry, or `{:error, :corrupt_journal}` for bytes this module did not write."
  @spec decode(binary()) :: {:ok, t()} | {:error, :corrupt_journal}
  def decode(bytes) do
    with {:ok, %{"version" => 1} = map} <- JSON.decode(bytes),
         %{"file" => file, "mutant_id" => id, "original_base64" => b64} <- map,
         %{"original_sha256" => original_sha, "mutated_sha256" => mutated_sha} <- map,
         true <- Enum.all?([file, id, b64, original_sha, mutated_sha], &is_binary/1),
         {:ok, original} <- Base.decode64(b64),
         true <- sha256(original) == original_sha do
      {:ok,
       %__MODULE__{
         file: file,
         mutant_id: id,
         original: original,
         original_sha: original_sha,
         mutated_sha: mutated_sha
       }}
    else
      _corrupt -> {:error, :corrupt_journal}
    end
  end

  @doc """
  What a leftover journal means, given the sha256 of its file now:
  `:restore` (the mutant is still there), `:discard` (the original is already
  back; only the journal is left), or `:changed` (neither: someone edited the
  file since, so nothing is written).
  """
  @spec recovery(t(), String.t()) :: :restore | :discard | :changed
  def recovery(%__MODULE__{mutated_sha: sha}, sha), do: :restore
  def recovery(%__MODULE__{original_sha: sha}, sha), do: :discard
  def recovery(%__MODULE__{}, _current), do: :changed
end
