defmodule Anchor.Domain.Sabotage.BehaviourMap do
  @moduledoc """
  From a test to the code that causes its behaviour (DND-5489), and how far that
  code spreads. Pure **Domain**.

  A test case is a behaviour. The functions it executed (the coverage map,
  `Anchor.Domain.Sabotage.CoverageMap`) are what could cause it; a mutant of one
  that the test killed (a `killed` row of a kill map,
  `Anchor.Domain.Sabotage.KillMap`) confirms it does. So a behaviour's **confirmed**
  causes are the functions it executed and killed a mutant of. Only those count:
  a function that was only executed may be incidental, and a function no mutant
  ran for is unknown. A test with none is **unconfirmed**, listed so the gap shows.

  A behaviour's **directories** are the parent directories of its confirmed causes'
  files. A cause's file comes from its kill row, or from `files_by_module` when the
  row names none; one with neither has no source (`(generated)`), is listed apart,
  and counts as no directory. A function whose rows name several files counts each:
  an old record can only add a directory, never hide one.

  ## The keys

  `test_key/2` is `<file>::<full test name>`, with no line, so moving a test keeps
  its key and a kill row recorded at another line still matches. It stays one
  baseline line: a line break in the name is written `\\n`, and the name is trimmed
  because `Anchor.Domain.Baseline.parse/1` trims. Two tests with one key (two modules
  in a file) are one behaviour.

  `locality_keys/1` repeats a behaviour's key once per directory: the multiset
  `Anchor.Domain.Baseline.compare/2` ratchets, so a behaviour that spreads to a new
  directory is NEW and one that shrinks is STALE.

  ## What did not line up

  `unmatched_killers` are killers that name no test of the map: a renamed test, a
  map older than the record. `not_executed` counts the pairs where a test killed a
  mutant of a function the map says it never ran. Neither confirms anything, and
  both are returned for the report to say.
  """

  alias Anchor.Domain.Sabotage.KillerRef

  defmodule Behaviour do
    @moduledoc "One test's causes (`Anchor.Domain.Sabotage.BehaviourMap`)."
    @enforce_keys [:test_key, :executed, :confirmed, :directories, :generated]
    defstruct [
      :test_key,
      :executed,
      :confirmed,
      :directories,
      :generated,
      executed_only: [],
      executed_only_directories: []
    ]

    @type t :: %__MODULE__{
            test_key: String.t(),
            executed: [String.t()],
            confirmed: [String.t()],
            directories: [String.t()],
            generated: [String.t()],
            executed_only: [String.t()],
            executed_only_directories: [String.t()]
          }
  end

  @generated "(generated)"

  @type t :: %{
          behaviours: [Behaviour.t()],
          unconfirmed: [String.t()],
          unmatched_killers: [String.t()],
          not_executed: non_neg_integer()
        }

  @doc "What a cause with no source file shows instead of a directory."
  @spec generated() :: String.t()
  def generated, do: @generated

  @doc """
  The behaviours of `coverage_map` as `kill_rows` confirm them. `files_by_module` is
  `\"Module\" => \"lib/file.ex\"`.
  """
  @spec build(map(), [map()], %{optional(String.t()) => String.t()}) :: t()
  def build(%{tests: tests}, kill_rows, files_by_module) do
    {killed_by, unparsed} = killed_by(kill_rows)
    executed = executed_by_key(tests)
    judged = Enum.map(executed, &behaviour(&1, killed_by, files_by_module))
    {confirmed, unconfirmed} = Enum.split_with(judged, &(&1.confirmed != []))

    %{
      behaviours: confirmed,
      unconfirmed: Enum.map(unconfirmed, & &1.test_key),
      unmatched_killers: unmatched(killed_by, executed) ++ unparsed,
      not_executed: not_executed(killed_by, executed)
    }
  end

  @doc """
  `:ok` when every test of the map has a string name; a key is built from it, and
  `CoverageMap.check/1` does not read the name. Else `{:error, {:test_name, file}}`.
  """
  @spec named(map()) :: :ok | {:error, {:test_name, String.t()}}
  def named(%{tests: tests}) do
    case Enum.find(tests, &(not is_binary(Map.get(&1, :name)))) do
      nil -> :ok
      test -> {:error, {:test_name, test.file}}
    end
  end

  @doc "The key of the test named `name` in `file`. It holds no line."
  @spec test_key(String.t(), String.t()) :: String.t()
  def test_key(file, name) do
    clean = name |> String.trim() |> String.replace("\r", "\\r") |> String.replace("\n", "\\n")
    "#{file}::#{clean}"
  end

  @doc "A behaviour's key once per directory: the ratchet's multiset."
  @spec locality_keys(t()) :: [String.t()]
  def locality_keys(%{behaviours: behaviours}) do
    behaviours
    |> Enum.flat_map(fn behaviour ->
      Enum.map(behaviour.directories, fn _ -> behaviour.test_key end)
    end)
  end

  @doc "The `n` behaviours spread over the most directories, widest first."
  @spec top(t(), non_neg_integer()) :: [Behaviour.t()]
  def top(%{behaviours: behaviours}, n) do
    behaviours
    |> Enum.sort_by(&{-length(&1.directories), &1.test_key})
    |> Enum.take(n)
  end

  @doc "The baseline entries that are no test key (`file::name`)."
  @spec malformed([String.t()]) :: [String.t()]
  def malformed(entries) do
    Enum.reject(entries, fn entry ->
      match?([file, name] when file != "" and name != "", String.split(entry, "::", parts: 2))
    end)
  end

  @doc "`\"Module\" => file` from source files' `defmodules`; the first file sorted wins."
  @spec files_by_module(%{optional(String.t()) => map() | {:error, term()}}) ::
          %{optional(String.t()) => String.t()}
  def files_by_module(facts_by_file) do
    for {file, %{defmodules: modules}} <- Enum.sort(facts_by_file),
        module <- modules,
        reduce: %{} do
      index -> Map.put_new(index, module, file)
    end
  end

  # -- building ----------------------------------------------------------------

  # test key => function => the files of the rows it killed a mutant in.
  defp killed_by(rows) do
    for %{status: "killed", killers: killers, mfa: mfa, file: file} <- rows,
        killer <- killers,
        reduce: {%{}, []} do
      {killed, unparsed} ->
        case KillerRef.parse(killer) do
          {:ok, ref} -> {add_kill(killed, test_key(ref.file, ref.name), mfa, file), unparsed}
          {:error, _reason} -> {killed, [killer | unparsed]}
        end
    end
    |> then(fn {killed, unparsed} -> {killed, unparsed |> Enum.uniq() |> Enum.sort()} end)
  end

  defp add_kill(killed, key, mfa, file) do
    Map.update(killed, key, %{mfa => [file]}, fn functions ->
      Map.update(functions, mfa, [file], &[file | &1])
    end)
  end

  defp executed_by_key(tests) do
    tests
    |> Enum.group_by(&test_key(&1.file, &1.name), & &1.functions)
    |> Enum.map(fn {key, sets} -> {key, sets |> List.flatten() |> Enum.uniq() |> Enum.sort()} end)
    |> Enum.sort()
  end

  defp behaviour({key, executed}, killed_by, index) do
    kills = Map.get(killed_by, key, %{})
    {confirmed, only} = Enum.split_with(executed, &Map.has_key?(kills, &1))
    files = Map.new(confirmed, &{&1, source_files(&1, kills[&1], index)})

    %Behaviour{
      test_key: key,
      executed: executed,
      confirmed: confirmed,
      directories: files |> Map.values() |> List.flatten() |> directories(),
      generated: for({mfa, []} <- files, do: mfa) |> Enum.sort(),
      executed_only: only,
      executed_only_directories:
        only |> Enum.flat_map(&displayed(&1, index)) |> Enum.uniq() |> Enum.sort()
    }
  end

  defp source_files(mfa, row_files, index) do
    case Enum.reject(row_files, &(&1 == "")) do
      [] -> indexed(mfa, index)
      named -> Enum.uniq(named)
    end
  end

  defp indexed(mfa, index) do
    case Map.fetch(index, module_of(mfa)) do
      {:ok, file} -> [file]
      :error -> []
    end
  end

  # The leading segments that read as an alias: `A.B.f/0` is `A.B`, and `:erl.f/0`
  # is none. The one regex compiler is `Anchor.Domain.GlobPattern` (DND-1292).
  defp module_of(mfa) do
    mfa
    |> String.split(".")
    |> Enum.take_while(&alias_segment?/1)
    |> Enum.join(".")
  end

  defp alias_segment?(<<first, _rest::binary>> = segment),
    do: first in ?A..?Z and not String.contains?(segment, "/")

  defp alias_segment?(""), do: false

  defp displayed(mfa, index) do
    case indexed(mfa, index) do
      [] -> [@generated]
      files -> Enum.map(files, &Path.dirname/1)
    end
  end

  defp directories(files), do: files |> Enum.map(&Path.dirname/1) |> Enum.uniq() |> Enum.sort()

  defp unmatched(killed_by, executed) do
    known = MapSet.new(executed, &elem(&1, 0))
    killed_by |> Map.keys() |> Enum.reject(&(&1 in known)) |> Enum.sort()
  end

  defp not_executed(killed_by, executed) do
    Enum.sum_by(executed, fn {key, functions} ->
      killed_by |> Map.get(key, %{}) |> Map.drop(functions) |> map_size()
    end)
  end
end
