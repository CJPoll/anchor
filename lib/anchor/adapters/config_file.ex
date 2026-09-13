defmodule Anchor.Adapters.ConfigFile do
  @moduledoc """
  Reads `.anchor.yml` off disk and decodes it — a **Side Effect** adapter
  (ADR 001).

  This is the single module that touches the filesystem for configuration. It
  asks `Anchor.Domain.ConfigPaths` which candidate paths to try, does the actual
  `File.*` IO and YAML decoding, and hands the decoded map to the pure parser
  `Anchor.Config`. It returns an `%Anchor.Config{}` (a Domain struct) or a
  `{:error, {:config_load_failed, reason}}` tuple — never raw YAML.
  """

  @behaviour Anchor.Adapters.ConfigLoader

  alias Anchor.Config
  alias Anchor.Domain.ConfigPaths

  @doc """
  Loads configuration from the first existing candidate path under the current
  working directory. When no candidate exists, returns an empty config so the
  checks run as no-ops.
  """
  @impl Anchor.Adapters.ConfigLoader
  def load do
    cwd = File.cwd!()
    apps? = File.dir?(Path.join(cwd, "apps"))

    cwd
    |> ConfigPaths.candidates(apps?)
    |> Enum.find(&File.exists?/1)
    |> load_candidate()
  end

  @doc """
  Reads and parses the config at `path`, returning `{:ok, %Anchor.Config{}}` or
  `{:error, {:config_load_failed, reason}}`.
  """
  def load_from_path(path) do
    with {:ok, content} <- File.read(path),
         {:ok, data} <- YamlElixir.read_from_string(content),
         # Gap F (DND-149): `parse_config/1` returns `{:error, reason}` when a
         # rule fails validation, so an invalid rule fails the load instead of
         # loading as a no-op. A valid document yields a `%Config{}`.
         %Config{} = config <- Config.parse_config(data) do
      {:ok, config}
    else
      {:error, reason} -> {:error, {:config_load_failed, reason}}
    end
  end

  defp load_candidate(nil), do: {:ok, %Config{}}
  defp load_candidate(path), do: load_from_path(path)
end
