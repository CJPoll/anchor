defmodule Anchor.Config do
  @moduledoc """
  Handles loading and parsing of Anchor configuration from YAML files.
  """

  alias YamlElixir

  @config_filename ".anchor.yml"

  defstruct rules: []

  def load do
    config_paths()
    |> Enum.find(&File.exists?/1)
    |> case do
      nil -> {:ok, %__MODULE__{}}
      path -> load_from_path(path)
    end
  end

  def load_from_path(path) do
    with {:ok, content} <- File.read(path),
         {:ok, data} <- YamlElixir.read_from_string(content) do
      {:ok, parse_config(data)}
    else
      {:error, reason} -> {:error, {:config_load_failed, reason}}
    end
  end

  defp config_paths do
    cwd = File.cwd!()

    # Check if we're in an umbrella app
    if File.exists?(Path.join(cwd, "apps")) do
      [
        # Root config
        Path.join(cwd, @config_filename),
        # Current app config (if we're in an app directory)
        Path.join([cwd, "..", "..", @config_filename])
      ]
    else
      [Path.join(cwd, @config_filename)]
    end
    |> Enum.uniq()
  end

  defp parse_config(data) when is_map(data) do
    rules = Map.get(data, "rules", [])
    %__MODULE__{rules: Enum.map(rules, &parse_rule/1)}
  end

  defp parse_rule(rule) when is_map(rule) do
    %{
      type: rule["type"] |> to_string() |> String.to_atom(),
      paths: rule["paths"] || [],
      pattern: rule["pattern"],
      forbidden_modules: parse_modules(rule["forbidden_modules"]),
      required_modules: parse_modules(rule["required_modules"]),
      allowed_functions: rule["allowed_functions"] || [],
      recursive: rule["recursive"] || false
    }
  end

  defp parse_modules(nil), do: []

  defp parse_modules(modules) when is_list(modules) do
    Enum.map(modules, &Module.concat([&1]))
  end
end
