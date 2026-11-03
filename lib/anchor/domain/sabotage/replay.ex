defmodule Anchor.Domain.Sabotage.Replay do
  @moduledoc """
  Replaying landed sabotage records on main (DND-5485): does each recorded
  killer still kill its mutant? Pure **Domain**; the Manager
  (`Anchor.Managers.Sabotage.Replay`) reads, applies and runs.

  ## Rows

  Every `anchor-kills` row (`Anchor.Domain.Sabotage.KillMap`) with status
  `killed` or `timeout` is an item `%{record: path, row: row}`.

  ## plan/2

  Each item is replayable or drifted. Drifted (reason in parentheses):

    * the row's file is absolute or has a `..` segment (`:file_outside`), or
      has a symlink at the file or a directory above it (`:symlink`): a
      record must never steer a read or a write outside the project;
    * the file is gone (`:file_gone`);
    * its `Module.fun/arity` does not read as one (`:bad_function`), or the
      function is gone (`{:function_gone, why}`);
    * no mutant the function yields today has the row's id
      (`:no_mutant_with_id`): the function changed;
    * the row names no test (`:no_killer_test`): only `(timeout)`, and no
      other killed row of the same function in the same record names one;
    * a killer's test file is gone (`{:killer_gone, file}`), or has a
      symlink on its path (`{:killer_symlink, file}`).

  A replayable item carries the regenerated mutant and the test args: by
  name (`Anchor.Domain.Sabotage.KillerRef.to_test_args/1`), or, for a row
  killed by the bound alone, the killer files of the same function's other
  killed rows in that record, whole (`by_file: true`).

  ## judge/2

  From the mutant run's outcome (`Anchor.Domain.Sabotage.Outcome`): killed
  or timed out is `:still_killed`; survived is `{:lost_power, killers}`;
  invalid is `{:drifted, :no_longer_compiles}`; no test run is
  `{:drifted, :killer_not_found}` (the named test is gone); crashed is
  `{:crashed, reason}`.

  ## exit_code/1

  The refusal's code; 3 (COULD NOT MEASURE) with zero rows; 1 when any row
  lost power or crashed; 3 when a record's kill map could not be read (its
  kills went unchecked, so a green job would hide them) or no row was
  replayed (every one drifted); 0 otherwise. A drifted row is never a failure on its own: the code changed,
  and a newer record covers the new code.
  """

  alias Anchor.Domain.Sabotage.KillerRef
  alias Anchor.Domain.Sabotage.Mutant

  defmodule Result do
    @moduledoc "One `mix anchor.sabotage replay` (DND-5485), as data. Pure **Domain**."

    defstruct notes: [],
              refusal: nil,
              searched: [],
              records: 0,
              rows: 0,
              unreadable: [],
              drifted: [],
              not_replayed: [],
              results: []

    @type t :: %__MODULE__{
            notes: [String.t()],
            refusal: nil | {pos_integer(), String.t()},
            searched: [String.t()],
            records: non_neg_integer(),
            rows: non_neg_integer(),
            unreadable: [String.t()],
            drifted: [{map(), term()}],
            not_replayed: [map()],
            results: [{map(), term()}]
          }
  end

  @replayed ~w(killed timeout)

  @type item :: %{record: String.t(), row: map()}
  @type facts :: %{
          sources: %{String.t() => boolean()},
          generated: %{{String.t(), String.t()} => {:ok, [Mutant.t()]} | {:error, term()}},
          tests: MapSet.t(String.t()),
          symlinked: MapSet.t(String.t())
        }

  @doc "The items of `rows_by_record` (`[{path, rows}]`) a replay judges."
  @spec items([{String.t(), [map()]}]) :: [item()]
  def items(rows_by_record) do
    for {record, rows} <- rows_by_record, row <- rows, row.status in @replayed do
      %{record: record, row: row}
    end
  end

  @doc """
  `{module, name, arity}` of a kill map's `Module.fun/arity`, or `:error`.
  The module is a name read from a committed record, as the generator reads
  it from source.
  """
  @spec function(String.t()) :: {:ok, {module(), atom(), arity()}} | :error
  def function(mfa) do
    with [head, arity_text] <- String.split(mfa, "/"),
         {arity, ""} when arity >= 0 <- Integer.parse(arity_text),
         [_ | _] = parts <- String.split(head, "."),
         {modules, [name]} when modules != [] and name != "" <- Enum.split(parts, -1),
         true <- Enum.all?(modules, &(&1 != "")) do
      {:ok, {Module.concat(modules), String.to_atom(name), arity}}
    else
      _other -> :error
    end
  end

  @doc "Whether a row's file may be read and written: relative, no `..`."
  @spec inside?(String.t()) :: boolean()
  def inside?(file) do
    segments = String.split(file, "/")
    file != "" and not String.starts_with?(file, "/") and ".." not in segments
  end

  @doc "Replayable and drifted items; see the moduledoc."
  @spec plan([item()], facts()) :: %{replayable: [map()], drifted: [{item(), term()}]}
  def plan(items, facts) do
    {replayable, drifted} =
      items
      |> Enum.map(&plan_item(&1, items, facts))
      |> Enum.split_with(&match?({:ok, _replayable}, &1))

    %{
      replayable: Enum.map(replayable, fn {:ok, r} -> r end),
      drifted: Enum.map(drifted, fn {:drifted, item, reason} -> {item, reason} end)
    }
  end

  defp plan_item(%{row: row} = item, items, facts) do
    symlinked = Map.get(facts, :symlinked, MapSet.new())

    with :ok <- check(inside?(row.file), :file_outside),
         :ok <- check(not MapSet.member?(symlinked, row.file), :symlink),
         :ok <- check(Map.get(facts.sources, row.file, false), :file_gone),
         {:ok, _mfa} <- tagged(function(row.mfa), :bad_function),
         {:ok, mutants} <- generated(facts, row),
         {:ok, mutant} <- with_id(mutants, row.id),
         {:ok, args, by_file} <- test_args(item, items),
         :ok <- killers_exist(args, by_file, facts.tests, symlinked) do
      {:ok, Map.merge(item, %{mutant: mutant, test_args: args, by_file: by_file})}
    else
      {:drifted, reason} -> {:drifted, item, reason}
    end
  end

  defp check(true, _reason), do: :ok
  defp check(false, reason), do: {:drifted, reason}

  defp tagged({:ok, value}, _reason), do: {:ok, value}
  defp tagged(:error, reason), do: {:drifted, reason}

  defp generated(facts, row) do
    case Map.get(facts.generated, {row.file, row.mfa}) do
      {:ok, mutants} -> {:ok, mutants}
      {:error, why} -> {:drifted, {:function_gone, why}}
      nil -> {:drifted, {:function_gone, :not_read}}
    end
  end

  defp with_id(mutants, id) do
    case Enum.find(mutants, &(&1.id == id)) do
      nil -> {:drifted, :no_mutant_with_id}
      mutant -> {:ok, mutant}
    end
  end

  defp test_args(%{record: record, row: row}, items) do
    case named(row.killers) do
      {:error, reason} ->
        {:drifted, reason}

      {:ok, []} ->
        files =
          for %{record: ^record, row: other} <- items,
              other.mfa == row.mfa and other.status == "killed",
              {:ok, ref} <- Enum.map(other.killers, &KillerRef.parse/1),
              uniq: true,
              do: ref.file

        if files == [], do: {:drifted, :no_killer_test}, else: {:ok, files, true}

      {:ok, refs} ->
        {:ok, KillerRef.to_test_args(refs), false}
    end
  end

  # Each killer that names a test; `(timeout)` names none. A killer that
  # does not read as a test is drift, never dropped.
  defp named(killers) do
    Enum.reduce_while(killers, {:ok, []}, fn killer, {:ok, refs} ->
      case KillerRef.parse(killer) do
        {:ok, ref} -> {:cont, {:ok, refs ++ [ref]}}
        {:error, :not_a_test} -> {:cont, {:ok, refs}}
        {:error, reason} -> {:halt, {:error, {:bad_killer, killer, reason}}}
      end
    end)
  end

  defp killers_exist(args, by_file, tests, symlinked) do
    files = if by_file, do: args, else: Enum.take_while(args, &(&1 != "--only"))

    cond do
      file = Enum.find(files, &MapSet.member?(symlinked, &1)) ->
        {:drifted, {:killer_symlink, file}}

      file = Enum.find(files, &(not MapSet.member?(tests, &1))) ->
        {:drifted, {:killer_gone, file}}

      true ->
        :ok
    end
  end

  @doc "The verdict of one replayed item from its mutant run's outcome."
  @spec judge(map(), %{status: atom(), reason: String.t() | nil}) ::
          :still_killed
          | {:lost_power, [String.t()]}
          | {:drifted, :no_longer_compiles | :killer_not_found}
          | {:crashed, String.t()}
  def judge(_item, %{status: status}) when status in [:killed, :timeout], do: :still_killed
  def judge(%{row: row}, %{status: :survived}), do: {:lost_power, row.killers}
  def judge(_item, %{status: :invalid}), do: {:drifted, :no_longer_compiles}
  def judge(_item, %{status: :no_tests}), do: {:drifted, :killer_not_found}
  def judge(_item, %{status: :crashed, reason: reason}), do: {:crashed, reason || "crashed"}

  @doc "The exit code; see the moduledoc."
  @spec exit_code(Result.t()) :: non_neg_integer()
  def exit_code(%Result{refusal: {code, _message}}), do: code
  def exit_code(%Result{rows: 0}), do: 3

  def exit_code(%Result{results: results, unreadable: unreadable}) do
    verdicts = Enum.map(results, &elem(&1, 1))

    cond do
      Enum.any?(verdicts, &failed?/1) -> 1
      unreadable != [] -> 3
      not Enum.any?(verdicts, &(&1 == :still_killed)) -> 3
      true -> 0
    end
  end

  defp failed?({:lost_power, _killers}), do: true
  defp failed?({:crashed, _reason}), do: true
  defp failed?(_verdict), do: false

  @doc "The replay's text."
  @spec render(Result.t()) :: String.t()
  def render(%Result{refusal: {_code, message}} = r), do: Enum.join(r.notes ++ [message], "\n")

  def render(%Result{rows: 0} = r) do
    Enum.join(
      r.notes ++
        unreadable(r) ++
        [
          "COULD NOT MEASURE: anchor.sabotage replay found no killed or timeout row in " <>
            "#{r.records} records under #{Enum.join(r.searched, ", ")}. Fix: land a sabotage " <>
            "record written by mix anchor.sabotage run, or pass --records with the directory " <>
            "that holds them"
        ],
      "\n"
    )
  end

  def render(%Result{} = r) do
    drifted = r.drifted ++ for({item, {:drifted, why}} <- r.results, do: {item, why})

    lines =
      r.notes ++
        unreadable(r) ++
        Enum.flat_map(r.results, &result_lines/1) ++
        Enum.map(drifted, fn {item, why} ->
          "drifted (#{drift_text(why)}) #{item.row.id} #{item.row.mfa} #{item.row.operator} " <>
            "(#{item.record})"
        end) ++
        Enum.map(r.not_replayed, fn item ->
          "not replayed (cap) #{item.row.id} #{item.row.mfa} #{item.row.operator}; rerun with --max all"
        end) ++ [summary(r, drifted)] ++ conclusion(r)

    Enum.join(lines, "\n")
  end

  defp unreadable(r), do: Enum.map(r.unreadable, &("could not read " <> &1))

  defp result_lines({item, :still_killed}),
    do: ["still killed #{item.row.id} #{item.row.mfa} #{item.row.operator}#{by_file(item)}"]

  defp result_lines({item, {:lost_power, killers}}) do
    [
      "LOST POWER #{item.row.id} #{item.row.mfa} #{item.row.operator} (#{item.record})",
      "  no longer failed by: " <> Enum.join(killers, "; "),
      "  Fix: restore the assertion that caught this break, or record why the behaviour changed"
    ]
  end

  defp result_lines({item, {:crashed, reason}}) do
    [
      "CRASHED #{item.row.id} #{item.row.mfa} #{item.row.operator} (#{item.record}): #{reason}",
      "  Fix: run the killers under this mutant to see why the run crashed, then fix that"
    ]
  end

  defp result_lines({_item, {:drifted, _why}}), do: []

  defp by_file(%{by_file: true}), do: " (killer run by file: the record names no test)"
  defp by_file(_item), do: ""

  defp drift_text(:file_outside), do: "file outside the project"
  defp drift_text(:symlink), do: "a symlink on the file's path: never followed"
  defp drift_text(:file_gone), do: "file gone"
  defp drift_text(:bad_function), do: "not a Module.fun/arity"
  defp drift_text({:function_gone, why}), do: "function gone: #{inspect(why)}"
  defp drift_text(:no_mutant_with_id), do: "no mutant with id"
  defp drift_text(:no_killer_test), do: "no killer test"
  defp drift_text({:killer_gone, file}), do: "killer gone: #{file}"
  defp drift_text({:killer_symlink, file}), do: "a symlink on the killer's path: #{file}"
  defp drift_text({:bad_killer, killer, why}), do: "killer #{inspect(killer)}: #{inspect(why)}"
  defp drift_text(:no_longer_compiles), do: "no longer compiles"
  defp drift_text(:killer_not_found), do: "killer test not found: no test ran"

  defp summary(r, drifted) do
    replayed = Enum.count(r.results, fn {_item, v} -> not match?({:drifted, _why}, v) end)
    count = fn pred -> Enum.count(r.results, fn {_item, v} -> pred.(v) end) end

    "anchor.sabotage replay: #{r.rows} rows in #{r.records} records; #{replayed} replayed, " <>
      "#{count.(&(&1 == :still_killed))} still killed, " <>
      "#{count.(&match?({:lost_power, _}, &1))} LOST POWER, " <>
      "#{count.(&match?({:crashed, _}, &1))} crashed, #{length(drifted)} drifted, " <>
      "#{length(r.not_replayed)} not replayed (cap)"
  end

  defp conclusion(%Result{unreadable: [_ | _]} = r) do
    if exit_code(r) == 3,
      do: [
        "COULD NOT MEASURE: #{length(r.unreadable)} records could not be read (above), so " <>
          "their kills went unchecked. Fix: repair each kill map, or regenerate the record " <>
          "with mix anchor.sabotage run"
      ],
      else: []
  end

  defp conclusion(r) do
    if exit_code(r) == 3,
      do: [
        "COULD NOT MEASURE: no row was replayed (every one drifted). Fix: land a sabotage " <>
          "record for the current code, written by mix anchor.sabotage run"
      ],
      else: []
  end
end
