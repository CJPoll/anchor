defmodule Anchor.Domain.Sabotage.CoverageMap do
  @moduledoc """
  The per-test coverage map (DND-5474; causal attribution, DND-5691): for each
  test, the project functions that ran on its behalf. Pure **Domain**: it
  classifies recorded calls, it never traces.

  ## Attribution

  Nothing depends on when a trace message arrives. Each call is recorded with
  the process that made it and the label and window word the VM read at the call
  (`Anchor.Domain.Sabotage.LabelSpec`), as a set, and only once the run is over
  is it resolved: each process to its owner
  (`Anchor.Domain.Sabotage.ProcessOwnership`), then each call to a credit, a leak
  or ambient (`Anchor.Domain.Sabotage.Attribution`).

  The one order this reads is one tracee's own, which the VM keeps: a runner's
  `test_started`, then its spawns, then `test_finished`, say which window each of
  its spawns was in. The events (`attribute/2`) are

    * `{:test_started, runner, word, ref, module}`,
      `{:test_finished, runner, word, ran?, module}`: a window, `word` as the
      call reported it, `ran?` false for a test with no process (excluded,
      skipped, invalid);
    * `{:module_started, runner, module}`, `{:module_finished, runner, module,
      word}`: a module's span;
    * `{:entry, word}`: a test's process took its label;
    * `{:spawn, parent, child, via}`: `via` from `ProcessOwnership.edge/3`;
    * `{:call, mfa, pid, label, word}`;
    * `{:error, reason}`: a message that could not be read.

  ## The map (`finalize/2`)

      %{version: 2, commit: sha, elixir: v, otp: v,
        tests: [%{file, line, name, module, functions: ["M.f/a"]}],
        leaks: [%{from: test_ref | %{module: "M"}, function: "M.f/a"}],
        ambient: ["M.f/a"],
        modules_traced: n, suite_exit: status, counters: %{...}}

  A test with no process is not in `tests`. `canonical/1` is the part that must be
  byte-identical between two builds of one commit: no counts, no stamps, no pids.
  `finalize/2` refuses a run that cannot be believed, and `validate/1` a map with
  zero tests or zero traced modules: such a map measured nothing (`COULD NOT
  MEASURE`, exit 3), and is never written.
  """

  alias Anchor.Domain.Sabotage.Attribution
  alias Anchor.Domain.Sabotage.ProcessOwnership
  alias Anchor.Domain.Sabotage.TestPath

  @version 2

  defstruct windows: %{},
            entries: MapSet.new(),
            modules: MapSet.new(),
            module_ends: %{},
            runner_spans: %{},
            roots: %{},
            edges: [],
            calls: MapSet.new(),
            errors: []

  @type test_ref :: %{
          file: String.t(),
          line: non_neg_integer(),
          name: String.t(),
          module: String.t()
        }
  @type mfa_term :: {module(), atom(), arity()}
  @type event ::
          {:test_started, pid(), pos_integer(), test_ref(), module()}
          | {:test_finished, pid(), pos_integer(), boolean(), module()}
          | {:module_started, pid(), module()}
          | {:module_finished, pid(), module(), non_neg_integer()}
          | {:entry, pos_integer()}
          | {:spawn, pid(), pid(), pid() | nil}
          | {:call, mfa_term(), pid(), term(), non_neg_integer()}
          | {:error, term()}
  @type state :: %__MODULE__{}
  @type leak :: %{from: test_ref() | %{module: String.t()}, function: String.t()}
  @type t :: %{
          version: 2,
          commit: String.t() | nil,
          elixir: String.t(),
          otp: String.t(),
          tests: [map()],
          leaks: [leak()],
          ambient: [String.t()],
          modules_traced: non_neg_integer(),
          suite_exit: integer(),
          counters: map()
        }
  @type refusal ::
          {:bad_label, term()}
          | {:task_shape, tuple()}
          | {:unreadable, term()}
          | {:windows, non_neg_integer(), non_neg_integer() | nil}
          | {:no_entry, test_ref()}
          | {:module_unfinished, module()}

  @doc "An empty attribution state."
  @spec new() :: state()
  def new, do: %__MODULE__{}

  @doc "Records `events`, in the order they arrived."
  @spec attribute(state(), [event()]) :: state()
  def attribute(%__MODULE__{} = state, events), do: Enum.reduce(events, state, &record/2)

  @doc """
  The map from the state and `meta` (`commit`, `elixir`, `otp`, `modules_traced`,
  `suite_exit`, `total`: the tests ExUnit counted, or nil when it never ran; and
  `root`: a test file under it is made relative to it).
  """
  @spec finalize(state(), map()) :: {:ok, t()} | {:error, refusal()}
  def finalize(%__MODULE__{} = state, meta) do
    with :ok <- no_errors(state),
         :ok <- windows_match(state, Map.fetch!(meta, :total)),
         :ok <- every_test_entered(state),
         :ok <- every_module_finished(state),
         {:ok, classified} <- classified(state) do
      {:ok, map(state, classified, meta)}
    end
  end

  @doc "`:ok`, or why the map measured nothing."
  @spec validate(t()) :: :ok | {:error, :no_tests | :no_modules}
  def validate(%{tests: []}), do: {:error, :no_tests}
  def validate(%{modules_traced: 0}), do: {:error, :no_modules}
  def validate(%{tests: [_ | _], modules_traced: n}) when is_integer(n) and n > 0, do: :ok

  @doc """
  The bytes two builds of one commit must share: the tests' sets, the leaks and
  ambient, with no count, stamp, pid, commit or tool version in them. Only meaningful
  when both have no leak and no process with no owner works across a window's close
  (a cast near it, a server's timer): which call lands past a window is scheduling,
  so those lists can differ. `Anchor.Domain.Sabotage.CoverageCompare` holds the
  comparison (DND-5692): it fails on such a difference, and the fix is in the test.
  """
  @spec canonical(t()) :: binary()
  def canonical(%{version: version, tests: tests, leaks: leaks, ambient: ambient}) do
    :erlang.term_to_binary(
      %{version: version, tests: tests, leaks: leaks, ambient: ambient},
      [:deterministic]
    )
  end

  @doc "One line per leak, then a `Fix:` line; `[]` when there is none."
  @spec leak_lines(t()) :: [String.t()]
  def leak_lines(%{leaks: []}), do: []

  def leak_lines(%{leaks: leaks}) do
    Enum.map(leaks, &("anchor.sabotage coverage: " <> leak_pair(&1))) ++ [leak_fix()]
  end

  @doc "One leak in words, naming its (test or module, function) pair."
  @spec leak_pair(leak()) :: String.t()
  def leak_pair(leak) do
    "leak: #{owner_name(leak.from)} left a process that called #{leak.function} after it finished"
  end

  @doc "The `Fix:` line every report of a leak ends with."
  @spec leak_fix() :: String.t()
  def leak_fix do
    "Fix: make the process end inside its test (await it, stop it, or start it with " <>
      "start_supervised). A test that ran on is a defect in the test, never in this list."
  end

  @doc "A test as `file:line name`, or a module's `setup_all`."
  @spec owner_name(test_ref() | %{module: String.t()}) :: String.t()
  def owner_name(%{file: file, line: line, name: name}), do: "#{file}:#{line} #{name}"
  def owner_name(%{module: module}), do: "setup_all of #{module}"

  @doc """
  A map read back from a file: `{:ok, map}` when it is a version-2 map with every
  field this module reads, else `{:error, reason}`. The map comes from an
  artifact, so each field that reaches a command line is checked: `commit` (passed
  to git) is `nil` or a 40-character lowercase hex sha, else `{:error, {:commit,
  value}}`; each test `file` (passed to `mix test`) passes
  `Anchor.Domain.Sabotage.TestPath.check/1` (a project `_test.exs` path, never an
  option), else `{:error, {:test_file, file}}`.
  """
  @spec check(term()) ::
          {:ok, t()}
          | {:error, :not_a_map | {:version, term()} | {:commit, term()} | {:test_file, term()}}
  def check(
        %{version: @version, commit: commit, tests: tests, leaks: leaks, ambient: ambient} = map
      )
      when is_list(tests) and is_list(leaks) and is_list(ambient) do
    with {:commit, true} <- {:commit, sha?(commit)},
         {:shape, true} <- {:shape, Enum.all?(tests, &test_shape?/1)},
         nil <- Enum.find(tests, &(not safe_file?(&1.file))) do
      {:ok, map}
    else
      {:commit, false} -> {:error, {:commit, commit}}
      {:shape, false} -> {:error, :not_a_map}
      %{file: file} -> {:error, {:test_file, file}}
    end
  end

  def check(%{version: @version}), do: {:error, :not_a_map}
  def check(%{version: version}), do: {:error, {:version, version}}
  def check(_term), do: {:error, :not_a_map}

  @doc "The refs of the tests whose set holds `mfa` (`\"M.f/a\"`), in map order."
  @spec tests_for(t(), String.t()) :: [test_ref()]
  def tests_for(%{tests: tests}, mfa) do
    for test <- tests, mfa in test.functions, do: Map.delete(test, :functions)
  end

  @doc """
  `\"M.f/a\" => [\"file:line\", ...]` for every function the map holds: the
  test arguments `Anchor.Domain.Sabotage.TestSelection` passes a mutant of it.
  """
  @spec index(t()) :: %{String.t() => [String.t()]}
  def index(%{tests: tests}) do
    tests
    |> Enum.flat_map(fn test -> Enum.map(test.functions, &{&1, "#{test.file}:#{test.line}"}) end)
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
    |> Map.new(fn {mfa, refs} -> {mfa, refs |> Enum.uniq() |> Enum.sort()} end)
  end

  @doc "`\"Module.name/arity\"` for an mfa tuple."
  @spec mfa_string(mfa_term()) :: String.t()
  def mfa_string({module, name, arity}), do: "#{inspect(module)}.#{name}/#{arity}"

  @doc "One summary line for the map written to `path`. The counters live here, never in the canonical bytes."
  @spec summary(t(), String.t()) :: String.t()
  def summary(map, path) do
    "anchor.sabotage coverage: tests: #{length(map.tests)}, " <>
      "modules_traced: #{map.modules_traced}, leaks: #{length(map.leaks)}, " <>
      "ambient: #{length(map.ambient)}, call_rows: #{map.counters.call_rows}, " <>
      "credited_by_label: #{map.counters.credited_by_label}, suite_exit: #{map.suite_exit}; " <>
      "built at #{map.commit || "(no commit)"}; wrote #{path}"
  end

  # --- recording: one tracee's own events arrive in order, and nothing else is
  # assumed. ---

  defp record({:call, mfa, pid, label, word}, state),
    do: %{state | calls: MapSet.put(state.calls, {mfa, pid, label, word})}

  defp record({:spawn, parent, child, via}, state) do
    case state.runner_spans do
      %{^parent => span} -> %{state | roots: Map.put(state.roots, child, span)}
      _not_a_runner -> %{state | edges: [{child, parent, via} | state.edges]}
    end
  end

  defp record({:test_started, runner, word, ref, module}, state) do
    window = %{ref: ref, module: module, ran?: true}

    %{
      state
      | windows: Map.put(state.windows, word, window),
        runner_spans: Map.put(state.runner_spans, runner, {:test, Attribution.test_number(word)})
    }
  end

  # One runner calls test_started and then test_finished, and a tracee's events
  # arrive in order, so a finish with no start is a trace this run cannot read.
  defp record({:test_finished, runner, word, ran?, module}, state) do
    case Map.fetch(state.windows, word - 1) do
      {:ok, window} ->
        %{
          state
          | windows: Map.put(state.windows, word - 1, %{window | ran?: ran?}),
            runner_spans: Map.put(state.runner_spans, runner, {:module, module})
        }

      :error ->
        record({:error, {:unreadable, {:test_finished, word}}}, state)
    end
  end

  defp record({:module_started, runner, module}, state) do
    %{
      state
      | modules: MapSet.put(state.modules, module),
        runner_spans: Map.put(state.runner_spans, runner, {:module, module})
    }
  end

  # A parameterized module runs once per set of parameters, each with a runner of its
  # own, and the VM orders trace messages per tracee only: the last end by word, never
  # the last to arrive.
  defp record({:module_finished, runner, module, word}, state) do
    %{
      state
      | module_ends: Map.update(state.module_ends, module, word, &max(&1, word)),
        runner_spans: Map.delete(state.runner_spans, runner)
    }
  end

  defp record({:entry, word}, state), do: %{state | entries: MapSet.put(state.entries, word)}
  defp record({:error, reason}, state), do: %{state | errors: [reason | state.errors]}

  # --- refusals: a run that cannot be believed writes no map. ---

  defp no_errors(%{errors: []}), do: :ok
  defp no_errors(%{errors: errors}), do: {:error, errors |> Enum.sort() |> hd()}

  # `total` from ExUnit counts excluded and skipped tests too, and each of those
  # opens a window. A suite that never ran has no total and no window.
  defp windows_match(%{windows: windows}, nil) when map_size(windows) == 0, do: :ok
  defp windows_match(%{windows: windows}, total) when map_size(windows) == total, do: :ok

  defp windows_match(%{windows: windows}, total),
    do: {:error, {:windows, map_size(windows), total}}

  defp every_test_entered(%{windows: windows, entries: entries}) do
    missing =
      for {word, %{ran?: true, ref: ref}} <- windows, not MapSet.member?(entries, word), do: ref

    case Enum.sort_by(missing, &ref_order/1) do
      [] -> :ok
      [ref | _] -> {:error, {:no_entry, ref}}
    end
  end

  defp every_module_finished(%{modules: modules, module_ends: ends}) do
    case modules |> Enum.reject(&is_map_key(ends, &1)) |> Enum.sort() do
      [] -> :ok
      [module | _] -> {:error, {:module_unfinished, module}}
    end
  end

  # --- classification, once the run is over. ---

  defp classified(state) do
    owners = ProcessOwnership.owners(state.roots, state.edges)
    context = %{windows: MapSet.new(Map.keys(state.windows)), module_ends: state.module_ends}
    empty = %{credits: %{}, leaks: MapSet.new(), ambient: MapSet.new(), by_label: 0, errors: []}

    result =
      Enum.reduce(state.calls, empty, fn {mfa, pid, label, word}, acc ->
        owner = Map.get(owners, pid)
        add(Attribution.classify(owner, label, word, context), mfa, owner, acc)
      end)

    case Enum.sort(result.errors) do
      [] -> {:ok, result}
      [error | _] -> {:error, error}
    end
  end

  defp add({:credit, owner}, mfa, process_owner, acc) do
    acc = credit(acc, owner, mfa)
    if process_owner, do: acc, else: %{acc | by_label: acc.by_label + 1}
  end

  defp add({:leak, owner}, mfa, _process_owner, acc),
    do: %{credit(acc, owner, mfa) | leaks: MapSet.put(acc.leaks, {owner, mfa})}

  defp add(:ambient, mfa, _process_owner, acc), do: %{acc | ambient: MapSet.put(acc.ambient, mfa)}

  defp add({:error, reason}, _mfa, _process_owner, acc),
    do: %{acc | errors: [reason | acc.errors]}

  defp credit(acc, owner, mfa) do
    credits = Map.update(acc.credits, owner, MapSet.new([mfa]), &MapSet.put(&1, mfa))
    %{acc | credits: credits}
  end

  defp map(state, classified, meta) do
    root = Map.get(meta, :root)

    %{
      version: @version,
      commit: Map.get(meta, :commit),
      elixir: Map.fetch!(meta, :elixir),
      otp: Map.fetch!(meta, :otp),
      tests: tests(state.windows, classified.credits, root),
      leaks: leaks(classified.leaks, state.windows, root),
      ambient: classified.ambient |> Enum.map(&mfa_string/1) |> Enum.sort(),
      modules_traced: Map.fetch!(meta, :modules_traced),
      suite_exit: Map.fetch!(meta, :suite_exit),
      counters: %{
        call_rows: MapSet.size(state.calls),
        credited_by_label: classified.by_label,
        spawns: map_size(state.roots) + length(state.edges)
      }
    }
  end

  defp tests(windows, credits, root) do
    windows
    |> Enum.filter(fn {_word, window} -> window.ran? end)
    |> Enum.group_by(fn {_word, window} -> relative_ref(window.ref, root) end)
    |> Enum.map(fn {ref, group} ->
      functions =
        group
        |> Enum.flat_map(fn {word, window} -> test_functions(word, window.module, credits) end)
        |> Enum.map(&mfa_string/1)
        |> Enum.uniq()
        |> Enum.sort()

      Map.put(ref, :functions, functions)
    end)
    |> Enum.sort_by(&ref_order/1)
  end

  defp test_functions(word, module, credits) do
    own = Map.get(credits, {:test, Attribution.test_number(word)}, MapSet.new())
    of_module = Map.get(credits, {:module, module}, MapSet.new())
    Enum.concat(own, of_module)
  end

  defp leaks(leaks, windows, root) do
    leaks
    |> Enum.map(fn {owner, mfa} ->
      %{from: leak_from(owner, windows, root), function: mfa_string(mfa)}
    end)
    |> Enum.sort_by(&{owner_name(&1.from), &1.function})
  end

  defp leak_from({:test, n}, windows, root),
    do: windows |> Map.fetch!(Attribution.open_word(n)) |> Map.fetch!(:ref) |> relative_ref(root)

  defp leak_from({:module, module}, _windows, _root), do: %{module: inspect(module)}

  defp ref_order(ref), do: {ref.file, ref.line, ref.name}
  defp relative_ref(ref, root), do: %{ref | file: relative(ref.file, root)}

  defp relative(file, nil), do: file
  defp relative(file, root), do: Path.relative_to(file, root)

  defp test_shape?(%{file: f, line: l, functions: fs})
       when is_binary(f) and is_integer(l) and l > 0,
       do: is_list(fs) and Enum.all?(fs, &is_binary/1)

  defp test_shape?(_test), do: false

  defp sha?(nil), do: true

  defp sha?(commit) when is_binary(commit) and byte_size(commit) == 40,
    do: commit |> String.to_charlist() |> Enum.all?(&(&1 in ?0..?9 or &1 in ?a..?f))

  defp sha?(_commit), do: false

  # DND-5640: the one path rule, shared with the kill map and the selection.
  defp safe_file?(file), do: TestPath.check(file) == :ok
end
