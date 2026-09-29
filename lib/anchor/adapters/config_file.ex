defmodule Anchor.Adapters.ConfigFile do
  @moduledoc """
  Reads `.anchor.yml` off disk and decodes it — a **Side Effect** adapter
  (ADR 001).

  This is the single module that touches the filesystem for configuration. It
  asks `Anchor.Domain.ConfigPaths` which candidate paths to try, does the actual
  `File.*` IO and YAML decoding, and hands the decoded map to the pure parser
  `Anchor.Config`. It returns an `%Anchor.Config{}` (a Domain struct) or an
  error tuple of plain data — never raw YAML, and never a YAML-library struct.

  It fails closed (DND-1265). The errors, which `Anchor.Domain.Failures` turns
  into the Credo issue the user sees:

    * `{:config_not_found, searched}` — no candidate exists. `searched` is every
      candidate path, in search order.
    * `{:config_load_failed, path, {:read, posix}}` — `path` exists but could
      not be read (for example, it is a directory).
    * `{:config_load_failed, path, {:yaml, message}}` — `path` is not valid YAML.
    * `{:config_load_failed, path, {:invalid_rule | :invalid_config, message}}`
      — `Anchor.Config` rejected the document.
  """

  @behaviour Anchor.Adapters.ConfigLoader

  alias Anchor.Config
  alias Anchor.Domain.ConfigPaths

  @doc """
  Loads configuration from the first existing candidate path under the current
  working directory. When no candidate exists, returns
  `{:error, {:config_not_found, searched}}` naming every path it searched.
  """
  @impl Anchor.Adapters.ConfigLoader
  def load do
    cwd = File.cwd!()
    apps? = File.dir?(Path.join(cwd, "apps"))
    searched = ConfigPaths.candidates(cwd, apps?)

    # `File.exists?/1`, not `File.regular?/1`: a candidate that exists but is not
    # a readable file must be reported by the read below, not skipped as absent.
    case Enum.find(searched, &File.exists?/1) do
      nil -> {:error, {:config_not_found, searched}}
      path -> load_from_path(path)
    end
  end

  @doc """
  Reads and parses the config at `path`, returning `{:ok, %Anchor.Config{}}` or
  `{:error, {:config_load_failed, path, detail}}`.
  """
  def load_from_path(path) do
    with {:ok, content} <- read(path),
         {:ok, data} <- decode(content),
         # `parse_config/1` returns `{:error, reason}` for an invalid document or
         # rule, so it fails the load instead of loading as a no-op.
         %Config{} = config <- Config.parse_config(data) do
      {:ok, config}
    else
      {:error, detail} -> {:error, {:config_load_failed, path, detail}}
    end
  end

  defp read(path) do
    case File.read(path) do
      {:ok, content} -> {:ok, content}
      {:error, posix} -> {:error, {:read, posix}}
    end
  end

  # The YAML library's error struct stops here: the Domain gets its text only.
  defp decode(content) do
    case YamlElixir.read_from_string(content) do
      {:ok, data} -> {:ok, data}
      {:error, error} -> {:error, {:yaml, yaml_message(error)}}
    end
  end

  defp yaml_message(%{__exception__: true} = error), do: Exception.message(error)
  defp yaml_message(error), do: inspect(error)
end
