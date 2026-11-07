defmodule Anchor.Managers.Sabotage.Verify do
  @moduledoc """
  The flow of `mix anchor.sabotage verify --base REF` (DND-5516), part of the
  **Manager** `Anchor.Managers.Sabotage` (ADR 001): it reads through ports and
  hands the Domain (`Anchor.Domain.Sabotage.Verify`) what it judges. It runs no
  test, compiles nothing, applies no mutant and writes nothing; sources are
  only parsed, records and the survivors list only read.

    1. No `base` is `{:error, :no_base}`.
    2. The `sabotage:` config (`Runner.config/2`; none is COULD NOT MEASURE).
    3. The scope and the diff's files (`Anchor.Managers.Sabotage.changes/2`):
       a `base` that resolves to no merge-base is `{:error, {:bad_ref, base}}`;
       any other failure is COULD NOT MEASURE. Changed source files with
       nothing counted (`Verify.unmeasured_scope?/3`) is COULD NOT MEASURE,
       never "no changed functions".
    4. Today's mutants of each changed function (`Mutator.generate/4`, with the
       config's operators and effect calls, as the run makes them). A function
       no literal clause defines is NOT IN SOURCE; one whose file cannot be read
       or parsed is COULD NOT MEASURE.
    5. The records the diff added or modified under `sabotage.records.dir`
       (`Verify.record_path?/2`), each read (`RecordStore`) and parsed by block
       (`KillMap.parse_blocks/1`); one that cannot be read is COULD NOT
       MEASURE, one that does not parse is a BAD RECORD and covers nothing. A
       record the diff deleted is RECORD REMOVED.
    6. The survivors list (`sabotage.survivors`, default
       `Survivors.default_path/0`) through `BaselineStore`, and its copy at
       `base` through `GitBase`: the entries it adds are printed for review.
       The default path absent is an empty list; a named path absent is a BAD
       SURVIVOR; an unreadable list or base copy is COULD NOT MEASURE.

  Ports (options): `:config_loader`, `:change_source`, `:record_store`,
  `:baseline_store`, `:git_base`, as `Anchor.Managers.Sabotage.Runner` takes
  them.
  """

  alias Anchor.Adapters.BaselineFile
  alias Anchor.Adapters.ConfigFile
  alias Anchor.Adapters.GitChangeSource
  alias Anchor.Adapters.GitShow
  alias Anchor.Adapters.RecordFile
  alias Anchor.Domain.Failures
  alias Anchor.Domain.Sabotage.KillMap
  alias Anchor.Domain.Sabotage.Mutator
  alias Anchor.Domain.Sabotage.Record
  alias Anchor.Domain.Sabotage.Scope
  alias Anchor.Domain.Sabotage.Survivors
  alias Anchor.Domain.Sabotage.Verify
  alias Anchor.Domain.Sabotage.Verify.Verdict
  alias Anchor.Managers.Sabotage
  alias Anchor.Managers.Sabotage.Runner

  @spec run(map(), keyword()) ::
          {:ok, Verdict.t()} | {:error, :no_base | {:bad_ref, String.t()}}
  def run(facts, opts) do
    case Map.get(facts, :base) do
      base when is_binary(base) and base != "" -> verify(facts.root, base, ports(opts))
      _none -> {:error, :no_base}
    end
  end

  defp ports(opts) do
    %{
      config: Keyword.get(opts, :config_loader, ConfigFile),
      change: Keyword.get(opts, :change_source, GitChangeSource),
      records: Keyword.get(opts, :record_store, RecordFile),
      baseline_store: Keyword.get(opts, :baseline_store, BaselineFile),
      git_base: Keyword.get(opts, :git_base, GitShow),
      opts: opts
    }
  end

  defp verify(root, base, ports) do
    with {:ok, config} <- config(root, ports),
         {:ok, scope, files} <- changes(root, base, ports),
         {:ok, mutants, not_in_source} <- mutants(root, scope, config, ports),
         {:ok, rows, bad_records, deleted} <- records(root, files, config, ports),
         {:ok, survivors} <- survivors(root, base, config, ports) do
      {entries, bad_survivors, added, path} = survivors

      {:ok,
       Verify.judge(mutants, rows, entries, %{
         base: base,
         survivors_path: path,
         changed_mfas: Enum.map(scope.functions, &mfa/1),
         not_in_source: not_in_source,
         deleted_records: deleted,
         bad_survivors: bad_survivors,
         bad_records: bad_records,
         survivors_added: added
       })}
    else
      {:error, {:bad_ref, _ref}} = error -> error
      {:could_not_measure, message} -> {:ok, %Verdict{base: base, could_not_measure: message}}
    end
  end

  defp config(root, ports) do
    case Runner.config(root, ports) do
      {:ok, config} -> {:ok, config}
      {:refuse, _code, message} -> {:could_not_measure, message}
    end
  end

  defp changes(root, base, %{change: change, opts: opts}) do
    case Sabotage.changes(%{root: root, base: base}, Keyword.put(opts, :change_source, change)) do
      {:ok, scope, files} -> measured_scope(scope, files)
      {:error, {:no_merge_base, ref}} -> {:error, {:bad_ref, ref}}
      {:error, reason} -> {:could_not_measure, Failures.scope_could_not_measure(reason)}
    end
  end

  defp measured_scope(scope, files) do
    sources = length(Scope.source_files(files))

    if Verify.unmeasured_scope?(sources, length(scope.functions), scope.counts),
      do:
        {:could_not_measure,
         "COULD NOT MEASURE: the diff changes #{sources} source files, but no function, no " <>
           "hunk outside a function and no macro was found in them. Fix: run " <>
           "mix anchor.sabotage scope --base <REF> to see what was read, and report it to Anchor"},
      else: {:ok, scope, files}
  end

  defp mutants(root, scope, config, %{change: change}) do
    opts = [operators: config.operators, effect_calls: config.effect_calls]

    Enum.reduce_while(scope.functions, {:ok, [], []}, fn function, {:ok, mutants, absent} ->
      case generated(change.read(root, function.file), function, opts) do
        {:ok, more} -> {:cont, {:ok, mutants ++ more, absent}}
        :not_in_source -> {:cont, {:ok, mutants, absent ++ [mfa(function)]}}
        {:could_not_measure, _message} = refusal -> {:halt, refusal}
      end
    end)
  end

  defp generated({:ok, text}, function, opts) do
    case Mutator.generate(
           text,
           function.file,
           {function.module, function.name, function.arity},
           opts
         ) do
      {:ok, %{mutants: mutants}} ->
        {:ok, mutants}

      {:error, reason} when reason in [:not_in_source, :defimpl_target_not_literal] ->
        :not_in_source

      {:error, {:parse_error, line, message}} ->
        {:could_not_measure,
         "COULD NOT MEASURE: #{function.file}:#{line} does not parse (#{message}). " <>
           "Fix: make it compile; its mutants cannot be generated otherwise"}
    end
  end

  defp generated({:error, posix}, function, _opts),
    do:
      {:could_not_measure,
       "COULD NOT MEASURE: could not read #{function.file} (#{inspect(posix)}). " <>
         "Fix: make #{function.file} a readable file"}

  defp records(root, files, config, %{records: store}) do
    glob = Record.dir_glob(config.records)

    changed =
      for {path, %{status: status}} <- Enum.sort(files),
          Verify.record_path?(path, glob),
          do: {path, status}

    deleted = for {path, :deleted} <- changed, do: path
    present = for {path, status} <- changed, status != :deleted, do: path

    Enum.reduce_while(present, {:ok, [], [], deleted}, fn path, {:ok, rows, bad, deleted} ->
      case store.read(root, path) do
        {:ok, text} ->
          {:cont, parsed(path, KillMap.parse_blocks(text), {rows, bad, deleted})}

        {:error, posix} ->
          {:halt,
           {:could_not_measure,
            "COULD NOT MEASURE: the sabotage record #{path} cannot be read (#{inspect(posix)}). " <>
              "Fix: make #{path} a readable file"}}
      end
    end)
  end

  defp parsed(path, {:ok, blocks}, {rows, bad, deleted}) do
    more =
      for {block, n} <- Enum.with_index(blocks, 1),
          row <- block,
          do: Map.merge(row, %{record: path, block: n})

    {:ok, rows ++ more, bad, deleted}
  end

  defp parsed(path, {:error, {line, message}}, {rows, bad, deleted}),
    do: {:ok, rows, bad ++ [{path, line, message}], deleted}

  defp survivors(root, base, config, ports) do
    path = config.survivors || Survivors.default_path()

    with {:ok, entries, bad} <- read_survivors(root, path, config.survivors, ports),
         {:ok, base_lines} <- base_survivors(root, base, path, ports) do
      {_kind, added} = Survivors.grew(entries, base_lines)
      {:ok, {entries, bad, added, path}}
    end
  end

  defp read_survivors(root, path, named, %{baseline_store: store}) do
    case store.read(root, path) do
      {:ok, lines} ->
        {entries, bad} = Verify.survivors(lines)
        {:ok, entries, bad}

      {:error, :enoent} when is_nil(named) ->
        {:ok, [], []}

      {:error, :enoent} ->
        {:ok, [], [{nil, "survivors file not found, but sabotage.survivors names it"}]}

      {:error, reason} ->
        {:could_not_measure,
         "COULD NOT MEASURE: the survivors file #{path} cannot be read (#{inspect(reason)}). " <>
           "Fix: make #{path} a readable UTF-8 file inside the project, with no symlink on its path"}
    end
  end

  defp base_survivors(root, base, path, %{git_base: git_base}) do
    case git_base.show(root, base, path) do
      {:ok, lines} ->
        {:ok, lines}

      {:error, :absent} ->
        {:ok, :absent}

      {:error, reason} ->
        {:could_not_measure,
         "COULD NOT MEASURE: the survivors file #{path} cannot be read at #{base} " <>
           "(#{inspect(reason)}), so what this branch adds to it cannot be shown. " <>
           "Fix: fetch #{base}, or pass --base with a ref that resolves"}
    end
  end

  defp mfa(%{module: module, name: name, arity: arity}), do: "#{inspect(module)}.#{name}/#{arity}"
end
