defmodule Anchor.Domain.Sabotage.Verify do
  @moduledoc """
  The verdict of `mix anchor.sabotage verify --base REF` (DND-5516): does a
  committed sabotage record, or the survivors list, cover every mutant the
  changed functions' current source makes? Pure **Domain**: it runs no test,
  compiles nothing and applies no mutant; the Manager hands it the mutants
  (`Anchor.Domain.Sabotage.Mutator`), the kill-map rows and the survivors.

  ## Coverage

  A mutant id is covered by a kill-map row (`Anchor.Domain.Sabotage.KillMap`)
  of a record this branch added or appended to, with status `killed`,
  `timeout` or `invalid`, or else by a survivors entry
  (`Anchor.Domain.Sabotage.Survivors`) with the same id whose file, function
  and operator are the mutant's. Anything else is UNCOVERED. A row whose
  status is `survived`, `no_tests` or `crashed` covers nothing: a survivor
  needs its entry.

  ## Stale rows

  A record is append-only: a rerun adds a block, oldest first. For each
  changed function, the latest block (records in path order, blocks in file
  order) holding a row of it is that function's last run; a row of that block
  whose id the current source no longer generates is STALE: the function
  changed after it was sabotaged. Rows of earlier blocks are history and are
  never stale. A row for a function the diff did not change is never stale.

  ## Failures and exit codes

  `exit_code/1`: 3 when the verdict could not be measured; 1 for any
  UNCOVERED mutant, STALE row, bad survivors entry, record whose kill map does
  not parse, or landed record the branch deleted; else 0. A function no
  literal clause defines (`NOT IN SOURCE`) and the survivors the branch added
  (`REVIEW`) are printed and change nothing. Every failure line `render/2`
  prints ends with exactly one `Fix:`.
  """

  alias Anchor.Domain.GlobPattern
  alias Anchor.Domain.Sabotage.Mutant
  alias Anchor.Domain.Sabotage.Survivors
  alias Anchor.Domain.Sabotage.Survivors.Entry

  defmodule Verdict do
    @moduledoc "The verdict of one `mix anchor.sabotage verify` (DND-5516). Pure **Domain** data."
    defstruct base: nil,
              survivors_path: nil,
              functions: 0,
              mutants: 0,
              covered: [],
              uncovered: [],
              stale_rows: [],
              bad_survivors: [],
              bad_records: [],
              deleted_records: [],
              not_in_source: [],
              survivors_added: [],
              could_not_measure: nil

    @type coverage :: :killed | :timeout | :invalid | :survivor

    @type t :: %__MODULE__{
            base: String.t() | nil,
            survivors_path: String.t() | nil,
            functions: non_neg_integer(),
            mutants: non_neg_integer(),
            covered: [{String.t(), coverage()}],
            uncovered: [Mutant.t()],
            stale_rows: [{String.t(), String.t(), String.t()}],
            bad_survivors: [{pos_integer() | nil, String.t()}],
            bad_records: [{String.t(), pos_integer() | nil, String.t()}],
            deleted_records: [String.t()],
            not_in_source: [String.t()],
            survivors_added: [Entry.t()],
            could_not_measure: String.t() | nil
          }
  end

  @covering %{"killed" => :killed, "timeout" => :timeout, "invalid" => :invalid}

  @typedoc "A kill-map row with the record and block (1-based) it was read from."
  @type kill_row :: %{
          required(:record) => String.t(),
          required(:block) => pos_integer(),
          required(:id) => String.t(),
          required(:mfa) => String.t(),
          required(:status) => String.t(),
          optional(atom()) => term()
        }

  @typedoc """
  What the Manager read beside the mutants: the changed functions (`M.f/a`),
  those no literal clause defines, and the failures found while reading.
  """
  @type context :: %{
          required(:changed_mfas) => [String.t()],
          optional(:base) => String.t(),
          optional(:survivors_path) => String.t(),
          optional(:not_in_source) => [String.t()],
          optional(:deleted_records) => [String.t()],
          optional(:bad_survivors) => [{pos_integer() | nil, String.t()}],
          optional(:bad_records) => [{String.t(), pos_integer() | nil, String.t()}],
          optional(:survivors_added) => [Entry.t()]
        }

  @doc """
  Judges `mutants` (today's, of the changed functions) against the kill-map
  `rows` of the records this branch added or appended to and the survivors
  `entries`. A mutant id generated twice is a defect in the generator: the
  verdict is COULD NOT MEASURE.
  """
  @spec judge([Mutant.t()], [kill_row()], [Entry.t()], context()) :: Verdict.t()
  def judge(mutants, rows, entries, ctx) do
    verdict = %Verdict{
      base: Map.get(ctx, :base),
      survivors_path: Map.get(ctx, :survivors_path),
      functions: length(ctx.changed_mfas),
      mutants: length(mutants),
      bad_survivors: Map.get(ctx, :bad_survivors, []),
      bad_records: Map.get(ctx, :bad_records, []),
      deleted_records: Map.get(ctx, :deleted_records, []),
      not_in_source: Map.get(ctx, :not_in_source, []),
      survivors_added: Map.get(ctx, :survivors_added, [])
    }

    case duplicate_ids(mutants) do
      [] -> coverage(verdict, mutants, rows, entries, ctx.changed_mfas)
      duplicated -> %{verdict | could_not_measure: duplicated_message(duplicated)}
    end
  end

  @doc """
  The survivors entries of the list's `lines` (as `Anchor.Adapters.BaselineStore`
  reads them), and each refused entry as `{number, message}`. Unlike
  `Survivors.parse/1`, a refused entry does not hide the good ones: they still
  cover their mutants, and the refused ones fail the verdict.
  """
  @spec survivors([String.t()]) :: {[Entry.t()], [{pos_integer(), String.t()}]}
  def survivors(lines) do
    case Survivors.parse(lines) do
      {:ok, entries} ->
        {entries, []}

      {:error, refused} ->
        numbers = MapSet.new(refused, &elem(&1, 0))

        kept =
          lines
          |> Enum.with_index(1)
          |> Enum.map(fn {line, n} -> if MapSet.member?(numbers, n), do: "", else: line end)

        {good(Survivors.parse(kept)), refused}
    end
  end

  @doc "Whether `path` is a sabotage record under the records `dir_glob` (`{app}` read as `*`)."
  @spec record_path?(String.t(), String.t()) :: boolean()
  def record_path?(path, dir_glob) do
    Path.extname(path) == ".md" and Path.basename(path) != "README.md" and
      GlobPattern.matches_pattern?(Path.dirname(path), dir_glob)
  end

  @doc """
  Whether a scope with no changed function hides a failed read: changed
  source files, yet no function, no hunk outside a function and no macro was
  counted. Every changed line of a source file lands in one of those, so
  zero of all three is a scope that measured nothing.
  """
  @spec unmeasured_scope?(non_neg_integer(), non_neg_integer(), map()) :: boolean()
  def unmeasured_scope?(source_files, functions, counts),
    do: source_files > 0 and functions == 0 and counts.outside_hunks == 0 and counts.macros == 0

  @doc "The verdict as text (default) or JSON."
  @spec render(Verdict.t(), :text | :json) :: String.t()
  def render(%Verdict{} = verdict, :json), do: JSON.encode!(json(verdict))

  def render(%Verdict{could_not_measure: message}, :text) when is_binary(message), do: message

  def render(%Verdict{} = verdict, :text) do
    Enum.join(
      failure_lines(verdict) ++ info_lines(verdict) ++ [summary(verdict, exit_code(verdict))],
      "\n"
    )
  end

  @doc "0 every mutant covered; 1 a failure; 3 COULD NOT MEASURE."
  @spec exit_code(Verdict.t()) :: 0 | 1 | 3
  def exit_code(%Verdict{could_not_measure: message}) when is_binary(message), do: 3

  def exit_code(%Verdict{} = v) do
    failures = [v.uncovered, v.stale_rows, v.bad_survivors, v.bad_records, v.deleted_records]
    if Enum.all?(failures, &(&1 == [])), do: 0, else: 1
  end

  @doc "The message of a refusal the task exits 2 on."
  @spec usage_message(:no_base | {:bad_ref, String.t()}) :: String.t()
  def usage_message(:no_base),
    do:
      "mix anchor.sabotage verify needs --base: the ref the branch's records are judged " <>
        "against. Fix: pass --base <merge-base SHA>"

  def usage_message({:bad_ref, ref}),
    do:
      "--base #{ref} is not a ref git can read here. " <>
        "Fix: git fetch origin main and pass the merge-base"

  # -- judge -------------------------------------------------------------------

  defp coverage(verdict, mutants, rows, entries, changed_mfas) do
    by_id = rows |> Enum.filter(&Map.has_key?(@covering, &1.status)) |> Map.new(&{&1.id, &1})
    entries_by_id = Map.new(entries, &{&1.id, &1})

    {covered, uncovered, mismatched} =
      Enum.reduce(mutants, {[], [], []}, fn mutant, {covered, uncovered, mismatched} ->
        case cover(mutant, by_id, entries_by_id) do
          {:ok, how} -> {[{mutant.id, how} | covered], uncovered, mismatched}
          :none -> {covered, [mutant | uncovered], mismatched}
          {:mismatch, bad} -> {covered, [mutant | uncovered], [bad | mismatched]}
        end
      end)

    %{
      verdict
      | covered: Enum.reverse(covered),
        uncovered: Enum.reverse(uncovered),
        bad_survivors: verdict.bad_survivors ++ Enum.reverse(mismatched),
        stale_rows: stale(rows, mutants, changed_mfas)
    }
  end

  defp cover(mutant, by_id, entries_by_id) do
    case {Map.fetch(by_id, mutant.id), Map.fetch(entries_by_id, mutant.id)} do
      {{:ok, row}, _entry} -> {:ok, Map.fetch!(@covering, row.status)}
      {:error, {:ok, entry}} -> entry_cover(entry, mutant)
      {:error, :error} -> :none
    end
  end

  defp entry_cover(entry, mutant) do
    if {entry.file, entry.mfa, entry.operator} ==
         {mutant.file, mfa(mutant), Atom.to_string(mutant.operator)},
       do: {:ok, :survivor},
       else:
         {:mismatch,
          {entry.line_no,
           "id #{entry.id} belongs to #{mfa(mutant)} #{mutant.operator} in #{mutant.file}, " <>
             "not #{entry.mfa} #{entry.operator} in #{entry.file}"}}
  end

  # The latest block holding a row of each changed function is its last run.
  defp stale(rows, mutants, changed_mfas) do
    generated = MapSet.new(mutants, & &1.id)
    changed = MapSet.new(changed_mfas)

    latest =
      Enum.reduce(rows, %{}, fn row, acc -> Map.put(acc, row.mfa, {row.record, row.block}) end)

    for row <- rows,
        MapSet.member?(changed, row.mfa),
        Map.fetch!(latest, row.mfa) == {row.record, row.block},
        not MapSet.member?(generated, row.id),
        do: {row.record, row.id, row.mfa}
  end

  defp duplicate_ids(mutants) do
    mutants
    |> Enum.group_by(& &1.id)
    |> Enum.filter(fn {_id, list} -> length(list) > 1 end)
    |> Enum.map(fn {id, [mutant | _rest]} -> {id, mfa(mutant)} end)
    |> Enum.sort()
  end

  defp duplicated_message(duplicated) do
    named = Enum.map_join(duplicated, ", ", fn {id, mfa} -> "#{id} (#{mfa})" end)

    "COULD NOT MEASURE: the generator made one mutant id twice: #{named}, so a record row " <>
      "cannot name one mutant. Fix: this is a defect in Anchor's generator; report it with this text"
  end

  defp good({:ok, entries}), do: entries
  defp good({:error, _refused}), do: []

  # -- render ------------------------------------------------------------------

  defp failure_lines(v) do
    base = v.base || "<REF>"
    path = v.survivors_path || Survivors.default_path()

    Enum.map(v.uncovered, &uncovered_line(&1, base)) ++
      Enum.map(v.stale_rows, &stale_line(&1, base)) ++
      Enum.map(v.bad_survivors, &bad_survivor_line(&1, path)) ++
      Enum.map(v.bad_records, &bad_record_line(&1, base)) ++
      Enum.map(v.deleted_records, &removed_line/1)
  end

  defp uncovered_line(mutant, base) do
    "UNCOVERED #{mutant.id} #{mutant.file} #{mfa(mutant)} #{mutant.operator}: no record row " <>
      "and no survivors entry. Fix: mix anchor.sabotage run --base #{base} and commit the " <>
      "record it writes, or add a survivors line with the reason no test can kill it"
  end

  defp stale_line({record, id, mfa}, base) do
    "STALE RECORD #{record}: #{mfa} changed after it was sabotaged (row #{id} is no longer " <>
      "generated). Fix: mix anchor.sabotage run --base #{base} and commit the record it appends"
  end

  defp bad_survivor_line({nil, message}, path),
    do:
      "BAD SURVIVOR #{path}: #{message}. Fix: create it (it may be empty) or remove sabotage.survivors"

  defp bad_survivor_line({n, message}, path) do
    "BAD SURVIVOR #{path}, entry #{n}: #{message}. Fix: give the entry a real reason why no " <>
      "test can kill it, or kill the mutant with a test"
  end

  defp bad_record_line({record, line, message}, base) do
    "BAD RECORD #{record}#{at_line(line)}: its anchor-kills block cannot be read (#{message}), " <>
      "so it covers nothing. Fix: restore the block as mix anchor.sabotage run wrote it, or rerun " <>
      "mix anchor.sabotage run --base #{base}"
  end

  defp removed_line(record) do
    "RECORD REMOVED #{record}: a landed sabotage record was deleted. " <>
      "Fix: restore it; removing a record is a loosening (Cody's decision)"
  end

  defp at_line(nil), do: ""
  defp at_line(line), do: ":#{line}"

  defp info_lines(v) do
    Enum.map(v.not_in_source, fn mfa ->
      "NOT IN SOURCE #{mfa}: generated function, no literal clause to sabotage (not required)"
    end) ++
      Enum.map(v.survivors_added, &("REVIEW survivor added: " <> Survivors.text(&1)))
  end

  defp summary(%Verdict{functions: 0}, 0), do: "sabotage verify: no changed functions"

  defp summary(v, 0) do
    counts = Enum.frequencies_by(v.covered, &elem(&1, 1))
    killed = Map.get(counts, :killed, 0) + Map.get(counts, :timeout, 0)

    "sabotage verify: #{v.functions} functions, #{v.mutants} mutants, all covered " <>
      "(#{killed} killed, #{Map.get(counts, :survivor, 0)} survivors, " <>
      "#{Map.get(counts, :invalid, 0)} invalid)"
  end

  defp summary(v, 1) do
    "sabotage verify: #{v.functions} functions, #{v.mutants} mutants: " <>
      "#{length(v.uncovered)} uncovered, #{length(v.stale_rows)} stale rows, " <>
      "#{length(v.bad_survivors)} bad survivors, #{length(v.bad_records)} bad records, " <>
      "#{length(v.deleted_records)} records removed"
  end

  defp json(v) do
    %{
      "base" => v.base,
      "survivors_path" => v.survivors_path,
      "functions" => v.functions,
      "mutants" => v.mutants,
      "covered" => Enum.map(v.covered, fn {id, how} -> %{"id" => id, "by" => to_string(how)} end),
      "uncovered" => Enum.map(v.uncovered, &mutant_json/1),
      "stale_rows" =>
        Enum.map(v.stale_rows, fn {record, id, mfa} ->
          %{"record" => record, "id" => id, "mfa" => mfa}
        end),
      "bad_survivors" =>
        Enum.map(v.bad_survivors, fn {n, message} -> %{"entry" => n, "message" => message} end),
      "bad_records" =>
        Enum.map(v.bad_records, fn {record, line, message} ->
          %{"record" => record, "line" => line, "message" => message}
        end),
      "deleted_records" => v.deleted_records,
      "not_in_source" => v.not_in_source,
      "survivors_added" => Enum.map(v.survivors_added, &Survivors.text/1),
      "could_not_measure" => v.could_not_measure,
      "exit_code" => exit_code(v)
    }
  end

  defp mutant_json(mutant),
    do: %{
      "id" => mutant.id,
      "file" => mutant.file,
      "mfa" => mfa(mutant),
      "operator" => Atom.to_string(mutant.operator)
    }

  defp mfa(%Mutant{module: module, function: {name, arity}}),
    do: "#{inspect(module)}.#{name}/#{arity}"
end
