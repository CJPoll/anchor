defmodule Anchor.Domain.Sabotage.Survivors do
  @moduledoc """
  The sabotage survivors list (DND-5483), a shrink-only list of the mutants
  no test can kill, each with its reason. Pure **Domain**.

  ## The file

  Default `.anchor/sabotage/survivors.txt` (config `sabotage.survivors`).
  One entry per line:

      <id> <file> <Module.fun/arity> <operator>  # <reason>

  A blank line and a line starting `#` are ignored. Every entry needs a real
  reason: an empty one, a `TODO`, `TBD` or `FIXME` (in any case, alone or as
  the reason's first word) and the placeholder `line_for/1` prints are
  refused. A bad id (not 12 lowercase hex characters), a missing field, a
  function that is not `Module.fun/arity`, an unknown operator and a
  duplicate id are refused too, each naming its line.

  `parse/1` takes the file's lines. Read through
  `Anchor.Adapters.BaselineStore` (the shared baseline reader), the blank and
  comment lines are already gone, so a number is the entry's position in the
  file's entries; every refusal also quotes the entry's own text.

  ## The judgement

  `judge/2` compares a run's outcomes with the entries through the shared
  comparator, `Anchor.Domain.Baseline.compare/2`, keyed on the mutant id:

    * **new**: an outcome `survived` or `no_tests` whose id no entry lists. It
      fails the run.
    * **held**: a listed survivor (`survived` or `no_tests`). Quiet.
    * **stale**: a listed id whose mutant is now killed, timed out or invalid
      (`now killed by ...`), or that the run did not generate though its
      function is in scope (`no longer generated`). It fails the run: delete
      the line.
    * **unjudged**: a listed id the run did not get to measure: past the cap
      or left out by `--only` (`:not_run`), a crashed run (`:crashed`), or a
      function no mutant could be made of this run (`:no_mutant_made`).
    * **malformed**: an entry whose id names a mutant of another file,
      function or operator. It fails the run, and its outcome is judged as
      unlisted.

  An entry is in scope when its function is a changed function of the run,
  or the function of a mutant the run generated (a `defimpl` target).
  Entries of every other function are not judged.

  `grew/2` is what a branch adds to the list against its base copy, keyed on
  the id (`Anchor.Domain.Baseline.grew/2`): shown for review, never a
  failure.
  """

  alias Anchor.Domain.Baseline
  alias Anchor.Domain.Sabotage.Operators
  alias Anchor.Domain.Sabotage.Run

  defmodule Entry do
    @moduledoc "One line of the survivors list (DND-5483). Pure **Domain** data."
    @enforce_keys [:id, :file, :mfa, :operator, :reason, :line_no]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            id: String.t(),
            file: String.t(),
            mfa: String.t(),
            operator: String.t(),
            reason: String.t(),
            line_no: pos_integer()
          }
  end

  defmodule Judgement do
    @moduledoc "A run's outcomes against the survivors list (DND-5483). Pure **Domain** data."
    defstruct new: [], held: [], stale: [], unjudged: [], malformed: []

    @type t :: %__MODULE__{
            new: [map()],
            held: [Anchor.Domain.Sabotage.Survivors.Entry.t()],
            stale: [{Anchor.Domain.Sabotage.Survivors.Entry.t(), String.t()}],
            unjudged: [
              {Anchor.Domain.Sabotage.Survivors.Entry.t(), :not_run | :crashed | :no_mutant_made}
            ],
            malformed: [{Anchor.Domain.Sabotage.Survivors.Entry.t(), String.t()}]
          }
  end

  @default_path ".anchor/sabotage/survivors.txt"
  @placeholder "<why no test can kill it>"
  @placeholder_words ~w(todo tbd fixme)
  @survivor_statuses [:survived, :no_tests]
  @hex ~c"0123456789abcdef"

  @type grew :: {:added | :first_landing, [Entry.t()]}

  @doc "The list's path when `sabotage.survivors` is not set."
  @spec default_path() :: String.t()
  def default_path, do: @default_path

  @doc "The reason placeholder `line_for/1` prints; refused by `parse/1`."
  @spec placeholder() :: String.t()
  def placeholder, do: @placeholder

  @doc """
  The entries of `lines`, or every refused line as `{number, message}`,
  in line order.
  """
  @spec parse([String.t()]) :: {:ok, [Entry.t()]} | {:error, [{pos_integer(), String.t()}]}
  def parse(lines) when is_list(lines) do
    parsed =
      lines
      |> Enum.with_index(1)
      |> Enum.reject(fn {line, _n} -> skipped?(String.trim(line)) end)
      |> Enum.map(fn {line, n} -> {n, entry(String.trim(line), n)} end)

    errors =
      for({n, {:error, message}} <- parsed, do: {n, message}) ++
        duplicates(for {_n, {:ok, entry}} <- parsed, do: entry)

    case Enum.sort_by(errors, &elem(&1, 0)) do
      [] -> {:ok, for({_n, {:ok, entry}} <- parsed, do: entry)}
      sorted -> {:error, sorted}
    end
  end

  @doc "The judgement of `run`'s outcomes against `entries`; see the moduledoc."
  @spec judge(Run.t(), [Entry.t()]) :: Judgement.t()
  def judge(%Run{} = run, entries) do
    unrun = run.not_run ++ run.not_selected
    mutants = Map.new(Enum.map(run.outcomes, & &1.mutant) ++ unrun, &{&1.id, &1})

    {malformed, entries} =
      Enum.reduce(entries, {[], []}, fn entry, {bad, good} ->
        case mismatch(entry, Map.get(mutants, entry.id)) do
          nil -> {bad, [entry | good]}
          message -> {[{entry, message} | bad], good}
        end
      end)

    scope = in_scope(run, unrun)

    in_scope =
      Enum.filter(Enum.reverse(entries), &(&1.mfa in scope or Map.has_key?(mutants, &1.id)))

    by_id = Map.new(in_scope, &{&1.id, &1})
    survivors = Enum.filter(run.outcomes, &(&1.status in @survivor_statuses))

    compared = Baseline.compare(Enum.map(survivors, & &1.mutant.id), Map.keys(by_id))
    new_ids = MapSet.new(compared.new)

    {stale, unjudged} =
      compared.stale
      |> Enum.map(&Map.fetch!(by_id, &1))
      |> Enum.sort_by(& &1.line_no)
      |> Enum.split_with(&(not_judged(&1, run, unrun) == nil))

    %Judgement{
      new: Enum.filter(survivors, &MapSet.member?(new_ids, &1.mutant.id)),
      held: compared.held |> Enum.map(&Map.fetch!(by_id, &1)) |> Enum.sort_by(& &1.line_no),
      stale: Enum.map(stale, &{&1, stale_reason(&1, run)}),
      unjudged: Enum.map(unjudged, &{&1, not_judged(&1, run, unrun)}),
      malformed: Enum.reverse(malformed)
    }
  end

  @doc "Whether the judgement fails the run: anything new, stale or malformed."
  @spec violation?(Judgement.t()) :: boolean()
  def violation?(%Judgement{new: [], stale: [], malformed: []}), do: false
  def violation?(%Judgement{}), do: true

  @doc """
  The entries `working` adds over `base` (the base copy's lines, or
  `:absent` for a list the base does not have: a first landing), by id.
  """
  @spec grew([Entry.t()], [String.t()] | :absent) :: grew()
  def grew(working, :absent), do: {:first_landing, working}

  def grew(working, base) when is_list(base) do
    base_ids =
      base
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&skipped?/1)
      |> Enum.map(&(&1 |> String.split() |> hd()))

    added = MapSet.new(Baseline.grew(Enum.map(working, & &1.id), base_ids))
    {:added, Enum.filter(working, &MapSet.member?(added, &1.id))}
  end

  @doc "The line to add for an unlisted survivor, with the reason left to fill in."
  @spec line_for(map()) :: String.t()
  def line_for(%{mutant: mutant}),
    do: "#{mutant.id} #{mutant.file} #{mfa(mutant)} #{mutant.operator}  # #{@placeholder}"

  @doc "An entry as its line, the text a person reads."
  @spec text(Entry.t()) :: String.t()
  def text(%Entry{} = e), do: "#{e.id} #{e.file} #{e.mfa} #{e.operator}  # #{e.reason}"

  # -- parse -----------------------------------------------------------------

  defp skipped?(""), do: true
  defp skipped?("#" <> _comment), do: true
  defp skipped?(_line), do: false

  defp entry(line, n) do
    with {:ok, head, reason} <- split_reason(line),
         {:ok, [id, file, mfa, operator]} <- fields(head),
         :ok <- check(hex_id?(id), "the id is not 12 lowercase hex characters: #{inspect(id)}"),
         :ok <- check(mfa?(mfa), "the function is not Module.fun/arity: #{inspect(mfa)}"),
         :ok <- check(operator in operators(), unknown_operator(operator)),
         :ok <- reason_ok(reason) do
      {:ok, %Entry{id: id, file: file, mfa: mfa, operator: operator, reason: reason, line_no: n}}
    end
  end

  defp split_reason(line) do
    case String.split(line, "#", parts: 2) do
      [head, reason] ->
        {:ok, head, String.trim(reason)}

      [_head] ->
        {:error, "no reason: every entry ends `  # <why no test can kill it>` with a real reason"}
    end
  end

  defp fields(head) do
    case String.split(head) do
      [_id, _file, _mfa, _operator] = fields ->
        {:ok, fields}

      fields ->
        {:error,
         "expected <id> <file> <Module.fun/arity> <operator>  # <reason>, " <>
           "got #{length(fields)} fields before the #"}
    end
  end

  defp check(true, _message), do: :ok
  defp check(false, message), do: {:error, message}

  defp hex_id?(id), do: byte_size(id) == 12 and Enum.all?(String.to_charlist(id), &(&1 in @hex))

  defp mfa?(mfa) do
    case String.split(mfa, "/") do
      [name, arity] ->
        String.contains?(name, ".") and not String.ends_with?(name, ".") and
          match?({n, ""} when n >= 0, Integer.parse(arity))

      _other ->
        false
    end
  end

  defp operators, do: Enum.map(Operators.all(), &Atom.to_string/1)

  defp unknown_operator(operator),
    do: "unknown operator #{inspect(operator)}; the operators are #{Enum.join(operators(), ", ")}"

  defp reason_ok(""), do: {:error, "the reason is empty: say why no test can kill this mutant"}

  defp reason_ok(@placeholder),
    do: {:error, "the reason is a placeholder (#{@placeholder}): write the real reason"}

  defp reason_ok(reason) do
    first =
      reason
      |> String.split()
      |> hd()
      |> String.trim_trailing(":")
      |> String.downcase()

    if first in @placeholder_words,
      do: {:error, "the reason is a placeholder (#{reason}): write the real reason"},
      else: :ok
  end

  defp duplicates(entries) do
    entries
    |> Enum.group_by(& &1.id)
    |> Enum.flat_map(fn
      {_id, [_one]} ->
        []

      {id, [first | rest]} ->
        Enum.map(
          rest,
          &{&1.line_no, "duplicate id #{id}: lines #{first.line_no} and #{&1.line_no}"}
        )
    end)
  end

  # -- judge -----------------------------------------------------------------

  defp mismatch(_entry, nil), do: nil

  defp mismatch(entry, mutant) do
    if {entry.file, entry.mfa, entry.operator} ==
         {mutant.file, mfa(mutant), Atom.to_string(mutant.operator)},
       do: nil,
       else:
         "id #{entry.id} belongs to #{mfa(mutant)} #{mutant.operator} in #{mutant.file}, " <>
           "not #{entry.mfa} #{entry.operator} in #{entry.file}"
  end

  defp in_scope(run, unrun) do
    MapSet.new(
      run.scope_functions ++
        Enum.map(run.outcomes, &mfa(&1.mutant)) ++
        Enum.map(unrun, &mfa/1) ++ Enum.map(run.errors, fn {f, _reason} -> mfa(f) end)
    )
  end

  defp not_judged(entry, run, unrun) do
    cond do
      Enum.any?(unrun, &(&1.id == entry.id)) -> :not_run
      Enum.any?(run.outcomes, &(&1.mutant.id == entry.id and &1.status == :crashed)) -> :crashed
      Enum.any?(run.errors, fn {f, _reason} -> mfa(f) == entry.mfa end) -> :no_mutant_made
      true -> nil
    end
  end

  defp stale_reason(entry, run) do
    case Enum.find(run.outcomes, &(&1.mutant.id == entry.id)) do
      nil -> "no longer generated"
      %{status: :invalid} -> "now invalid: it does not compile, so it needs no entry"
      %{killers: killers} -> "now killed by " <> Enum.map_join(killers, "; ", &killer/1)
    end
  end

  defp killer({file, line, name}), do: "#{file}:#{line} #{name}"
  defp killer(text) when is_binary(text), do: text

  defp mfa(%{module: module, function: {name, arity}}), do: "#{inspect(module)}.#{name}/#{arity}"
  defp mfa(%{module: module, name: name, arity: arity}), do: "#{inspect(module)}.#{name}/#{arity}"
end
