defmodule Anchor.Domain.Aggregates.Config do
  @moduledoc """
  The `aggregates:` section of `.anchor.yml` (DND-5476), parsed by
  `Anchor.Config.parse_config/1` — a **Domain** module (ADR 001). Pure.

  ```yaml
  aggregates:
    declare:
      - name: MyApp.Threads.ThreadSpace       # a module-name token; need not be a module
        schemas: [MyApp.Threads.Thread]       # exact module names
        tables: ["thread_reads"]              # tables written with no schema module
        owners: [MyApp.Threads.ThreadStore]   # exact module names (DND-5478)
    repos: [MyApp.Repo]                       # DND-5459 reads it
    write_functions: ["MyApp.Repo.soft_delete/2"]
    transaction_functions: ["GenSaas.UnitOfWork.transaction/3"]
  ```

  The whole section is parsed here, so later tickets add no keys; only
  `declare` has a meaning yet. `repos` (exact module names),
  `write_functions` and `transaction_functions` (`Anchor.Domain.FunctionRef`
  tokens) are checked for shape and stored.

  Every refusal is `{:error, {:invalid_config, message}}`, the message
  starting with the key path (`aggregates.declare[2].schemas ...`) and ending
  with a `Fix:` that gives the conforming shape. Refused: a section that is not
  a mapping; an unknown key at any level; a `declare` that is not a list; an
  entry that is not a mapping, has no `name`, or an unknown key; a `name` that
  is not a module-name token; `schemas`, `owners` or `repos` that are not lists
  of exact module names; `tables` that is not a list of non-empty strings; two
  entries with one `name`; a malformed function token.

  A bare `aggregates:` (YAML `nil`) is a section with no declarations.
  """

  alias Anchor.Domain.AllowedCallers
  alias Anchor.Domain.Aggregates.Declaration
  alias Anchor.Domain.FunctionRef

  @keys ~w(declare repos transaction_functions write_functions)
  @entry_keys ~w(name owners schemas tables)

  @shape "aggregates: declare: - name: <Aggregate>, schemas: [<Schema>...], " <>
           "tables: [\"<table>\"...], owners: [<Module>...]"

  defstruct declare: [], repos: [], write_functions: [], transaction_functions: []

  @type t :: %__MODULE__{
          declare: [Declaration.t()],
          repos: [module()],
          write_functions: [FunctionRef.t()],
          transaction_functions: [FunctionRef.t()]
        }

  @doc "The conforming shape of one `declare` entry, the `Fix:` of every refusal."
  @spec shape() :: String.t()
  def shape, do: @shape

  @doc "Parses the decoded section (`nil` for a bare `aggregates:`)."
  @spec parse(term()) :: {:ok, t()} | {:error, {:invalid_config, String.t()}}
  def parse(nil), do: parse(%{})

  def parse(section) when is_map(section) do
    with :ok <- known_keys(section, @keys, "aggregates"),
         {:ok, declare} <- declare(Map.get(section, "declare", [])),
         {:ok, repos} <- modules(Map.get(section, "repos", []), "aggregates.repos"),
         {:ok, writes} <- functions(section, "write_functions"),
         {:ok, transactions} <- functions(section, "transaction_functions") do
      {:ok,
       %__MODULE__{
         declare: declare,
         repos: repos,
         write_functions: writes,
         transaction_functions: transactions
       }}
    end
  end

  def parse(section),
    do: refuse("aggregates must be a mapping, got: #{inspect(section)}", "write #{@shape}")

  defp known_keys(map, keys, path) do
    case map |> Map.keys() |> Enum.reject(&(&1 in keys)) |> Enum.sort() do
      [] ->
        :ok

      unknown ->
        refuse(
          "#{path}: unknown key(s) #{Enum.map_join(unknown, ", ", &inspect/1)}",
          "remove or correct it; the keys are #{Enum.join(keys, ", ")}; #{@shape}"
        )
    end
  end

  defp declare(entries) when is_list(entries) do
    entries
    |> Enum.with_index(1)
    |> Enum.reduce_while({:ok, []}, fn {entry, index}, {:ok, acc} ->
      case entry(entry, "aggregates.declare[#{index}]") do
        {:ok, declaration} -> {:cont, {:ok, [declaration | acc]}}
        error -> {:halt, error}
      end
    end)
    |> unique_names()
  end

  defp declare(entries),
    do:
      refuse(
        "aggregates.declare must be a list of declarations, got: #{inspect(entries)}",
        "write #{@shape}"
      )

  defp entry(entry, path) when is_map(entry) do
    with :ok <- known_keys(entry, @entry_keys, path),
         {:ok, name} <- name(entry, path),
         {:ok, schemas} <- modules(Map.get(entry, "schemas", []), "#{path}.schemas"),
         {:ok, tables} <- tables(Map.get(entry, "tables", []), "#{path}.tables"),
         {:ok, owners} <- modules(Map.get(entry, "owners", []), "#{path}.owners") do
      {:ok,
       %Declaration{
         name: name,
         schemas: schemas,
         tables: tables,
         owners: owners,
         sites: [:config]
       }}
    end
  end

  defp entry(entry, path),
    do: refuse("#{path} must be a mapping, got: #{inspect(entry)}", "write #{@shape}")

  defp name(%{"name" => name}, path) when is_binary(name) do
    if FunctionRef.alias_name?(name),
      do: {:ok, name},
      else: bad_name(name, path)
  end

  defp name(%{"name" => name}, path), do: bad_name(name, path)

  defp name(_entry, path),
    do: refuse("#{path} has no `name`", "name the aggregate: #{@shape}")

  defp bad_name(name, path) do
    refuse(
      "#{path}.name #{inspect(name)} is not a module-name token",
      "name it like a module (MyApp.Threads.ThreadSpace); #{@shape}"
    )
  end

  defp modules(tokens, path) when is_list(tokens) do
    Enum.reduce_while(tokens, {:ok, []}, fn token, {:ok, acc} ->
      case module(token) do
        {:ok, module} -> {:cont, {:ok, acc ++ [module]}}
        {:error, why} -> {:halt, bad_modules(path, "#{inspect(token)} #{why}")}
      end
    end)
  end

  defp modules(tokens, path), do: bad_modules(path, "got: #{inspect(tokens)}")

  defp module(token) when is_binary(token), do: AllowedCallers.parse(token)
  defp module(_token), do: {:error, "is not a string"}

  defp bad_modules(path, why) do
    refuse(
      "#{path} must be a list of exact module names: #{why}",
      "name each module in full, as its defmodule spells it; #{@shape}"
    )
  end

  defp tables(tables, path) when is_list(tables) do
    if Enum.all?(tables, &(is_binary(&1) and &1 != "")),
      do: {:ok, tables},
      else: bad_tables(tables, path)
  end

  defp tables(tables, path), do: bad_tables(tables, path)

  defp bad_tables(tables, path) do
    refuse(
      "#{path} must be a list of non-empty table names, got: #{inspect(tables)}",
      "write each table as a string; #{@shape}"
    )
  end

  defp functions(section, key) do
    path = "aggregates.#{key}"

    case Map.get(section, key, []) do
      tokens when is_list(tokens) -> function_refs(tokens, path)
      other -> bad_function(path, "must be a list, got: #{inspect(other)}")
    end
  end

  defp function_refs(tokens, path) do
    Enum.reduce_while(tokens, {:ok, []}, fn token, {:ok, acc} ->
      case function_ref(token) do
        {:ok, ref} -> {:cont, {:ok, acc ++ [ref]}}
        {:error, why} -> {:halt, bad_function(path, why)}
      end
    end)
  end

  defp function_ref(token) when is_binary(token), do: FunctionRef.parse(token)
  defp function_ref(token), do: {:error, "#{inspect(token)} is not a string"}

  defp bad_function(path, why) do
    refuse(
      "#{path}: #{why}",
      "write each as \"Module.function\" or \"Module.function/arity\" (e.g. \"MyApp.Repo.insert/2\")"
    )
  end

  defp unique_names({:ok, reversed}) do
    declarations = Enum.reverse(reversed)

    duplicates =
      declarations
      |> Enum.frequencies_by(& &1.name)
      |> Enum.filter(&(elem(&1, 1) > 1))
      |> Enum.sort()

    case duplicates do
      [] ->
        {:ok, declarations}

      [{name, _count} | _rest] ->
        refuse(
          "aggregates.declare names #{inspect(name)} more than once",
          "merge them into one declaration; #{@shape}"
        )
    end
  end

  defp unique_names(error), do: error

  defp refuse(message, fix), do: {:error, {:invalid_config, message <> ". Fix: " <> fix}}
end
