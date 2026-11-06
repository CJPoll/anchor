defmodule Anchor.Domain.Sabotage.CoverageMap do
  @moduledoc """
  The per-test coverage map (DND-5474): for each test, the project functions
  that executed while it ran. Pure **Domain**: it windows call events, it never
  traces.

  ## Attribution (`attribute/2`)

  ExUnit notifies formatters asynchronously (`ExUnit.EventManager.notify/2` is
  a `:gen_event.notify` plus a `GenServer.cast` in Elixir 1.19.4), so a test's
  bounds are read from traced calls instead: the runner process calls
  `ExUnit.EventManager.test_started/2` and `test_finished/2` around each test,
  and every event carries a strict monotonic stamp. The events are

    * `{:window_open, stamp, test_ref}` and `{:window_close, stamp, test_ref}`,
      `test_ref` being `%{file, line, name, module}`;
    * `{:call, stamp, mfa}` or `{:call, stamp, mfa, pid}`, `mfa` a
      `{module, name, arity}` or a `"Module.name/arity"` string, `pid` the
      process that made the call (DND-5642).

  Trace messages from several processes can arrive out of stamp order, so
  events are buffered and released in stamp order, always keeping the `slack`
  (default #{10_000}) newest buffered: an event is attributed only once at
  least `slack` events with later stamps have arrived. An event whose stamp is older
  than one already released is counted in `late_events`, never attributed and
  never dropped silently: the map and the summary say how many there were.

  A released call inside an open window adds its function to that test's set
  (a set: a thousand calls cost one element). A call outside every window
  (`setup_all`, a process that outlived its test) counts in `outside_windows`.

  ## Window leaks (DND-5642)

  A process a test started that keeps running is credited to whichever test
  is running when it next calls project code: attribution is by time alone.
  Where a call carries its pid, the windows open when that pid was first seen
  are kept; a later call from it while none of them is open, inside another
  window, is a **leak** from those windows to the open one. What is measured
  is where a process was first SEEN, not what started it: an application
  process (a server, a cache) that sits idle until a test first calls it is
  first seen in that test, so its later calls for other tests are reported
  too. A leak line names a process to look at, not proof that the earlier
  test left it running. Leaks are counted
  per (earlier windows, credited window) pair and listed in the map as
  `window_leaks`; `leak_warnings/1` gives one line per credited test file.
  Visibility only: the call is still attributed to the open window, so the
  selection does not change. A pid first seen outside every window (a
  process that called project code at boot, `setup_all`) is never a leak.

  ## The map (`finalize/2`)

      %{version: 1, commit: sha, elixir: v, otp: v,
        tests: [%{file, line, name, module, functions: ["M.f/a"]}],
        modules_traced: n, outside_windows: n, late_events: n, suite_exit: status,
        window_leaks: [%{from: [test_ref], to: test_ref, calls: n}]}

  `validate/1` refuses a map with zero tests or zero traced modules: such a map
  measured nothing (`COULD NOT MEASURE`, exit 3), and is never written.
  """

  alias Anchor.Domain.Sabotage.TestPath

  @version 1
  @default_slack 10_000
  @leak_pairs_shown 5

  defstruct slack: @default_slack,
            pending: [],
            pending_count: 0,
            arrived: 0,
            released: nil,
            open: %{},
            finished: %{},
            outside_windows: 0,
            late_events: 0,
            first_seen: %{},
            leaks: %{}

  @type test_ref :: %{
          file: String.t(),
          line: non_neg_integer(),
          name: String.t(),
          module: String.t()
        }
  @type mfa_term :: {module(), atom(), arity()} | String.t()
  @type event ::
          {:window_open, term(), test_ref()}
          | {:window_close, term(), test_ref()}
          | {:call, term(), mfa_term()}
          | {:call, term(), mfa_term(), pid()}
  @type state :: %__MODULE__{}
  @type t :: %{
          version: 1,
          commit: String.t() | nil,
          elixir: String.t(),
          otp: String.t(),
          tests: [map()],
          modules_traced: non_neg_integer(),
          outside_windows: non_neg_integer(),
          late_events: non_neg_integer(),
          suite_exit: integer(),
          window_leaks: [leak()]
        }
  @type leak :: %{from: [test_ref()], to: test_ref(), calls: pos_integer()}

  @doc "An empty attribution state. `slack:` sets the reorder slack, in events."
  @spec new(keyword()) :: state()
  def new(opts \\ []) do
    case Keyword.get(opts, :slack, @default_slack) do
      slack when is_integer(slack) and slack >= 0 -> %__MODULE__{slack: slack}
    end
  end

  @doc "Buffers `events` and attributes every one the slack releases."
  @spec attribute(state(), [event()]) :: state()
  def attribute(%__MODULE__{} = state, events) do
    state = Enum.reduce(events, state, &arrive/2)

    # Sorting is paid once per `slack` arrivals, not once per batch.
    if state.pending_count > 2 * state.slack,
      do: release(state, state.pending_count - state.slack),
      else: state
  end

  @doc "Releases every buffered event, in stamp order."
  @spec drain(state()) :: state()
  def drain(%__MODULE__{} = state), do: release(state, state.pending_count)

  @doc """
  The map from the drained state and `meta` (`commit`, `elixir`, `otp`,
  `modules_traced`, `suite_exit`, and `root`: a test file under it is made
  relative to it). A window still open (a test the suite never finished) is
  kept as it stands.
  """
  @spec finalize(state(), map()) :: t()
  def finalize(%__MODULE__{} = state, meta) do
    state = drain(state)
    root = Map.get(meta, :root)

    windows =
      Enum.reduce(state.open, state.finished, fn {ref, set}, acc ->
        Map.update(acc, ref, set, &MapSet.union(&1, set))
      end)

    tests =
      windows
      |> Enum.map(fn {ref, set} ->
        ref
        |> Map.put(:file, relative(ref.file, root))
        |> Map.put(:functions, set |> Enum.map(&mfa_string/1) |> Enum.sort())
      end)
      |> Enum.sort_by(&{&1.file, &1.line, &1.name})

    %{
      version: @version,
      commit: Map.get(meta, :commit),
      elixir: Map.fetch!(meta, :elixir),
      otp: Map.fetch!(meta, :otp),
      tests: tests,
      modules_traced: Map.fetch!(meta, :modules_traced),
      outside_windows: state.outside_windows,
      late_events: state.late_events,
      suite_exit: Map.fetch!(meta, :suite_exit),
      window_leaks: window_leaks(state.leaks, root)
    }
  end

  @doc """
  One warning line per credited test file of the map's `window_leaks`, in
  file order; `[]` when there are none (a map written before DND-5642 has
  none). Each names the earlier test (or tests) whose process made the calls,
  the credited test and the count, at most #{@leak_pairs_shown} pairs per line.
  """
  @spec leak_warnings(map()) :: [String.t()]
  def leak_warnings(map) do
    map
    |> Map.get(:window_leaks, [])
    |> Enum.group_by(& &1.to.file)
    |> Enum.sort()
    |> Enum.map(fn {file, leaks} -> leak_line(file, leaks) end)
  end

  @doc "`:ok`, or why the map measured nothing."
  @spec validate(t()) :: :ok | {:error, :no_tests | :no_modules}
  def validate(%{tests: []}), do: {:error, :no_tests}
  def validate(%{modules_traced: 0}), do: {:error, :no_modules}
  def validate(%{tests: [_ | _], modules_traced: n}) when is_integer(n) and n > 0, do: :ok
  def validate(_map), do: {:error, :no_modules}

  @doc """
  A map read back from a file: `{:ok, map}` when it is a version-1 map with
  every field this module reads, else `{:error, reason}`. The map comes from
  an artifact, so each field that reaches a command line is checked: `commit`
  (passed to git) is `nil` or a 40-character lowercase hex sha, else
  `{:error, {:commit, value}}`; each test `file` (passed to `mix test`)
  passes `Anchor.Domain.Sabotage.TestPath.check/1` (a project `_test.exs`
  path, never an option), else `{:error, {:test_file, file}}`.
  """
  @spec check(term()) ::
          {:ok, t()}
          | {:error, :not_a_map | {:version, term()} | {:commit, term()} | {:test_file, term()}}
  def check(%{version: @version, commit: commit, tests: tests} = map) when is_list(tests) do
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

  @doc "`\"Module.name/arity\"` for an mfa tuple; a string is already one."
  @spec mfa_string(mfa_term()) :: String.t()
  def mfa_string({module, name, arity}), do: "#{inspect(module)}.#{name}/#{arity}"
  def mfa_string(mfa) when is_binary(mfa), do: mfa

  @doc "One summary line for the map written to `path`."
  @spec summary(t(), String.t()) :: String.t()
  def summary(map, path) do
    "anchor.sabotage coverage: tests: #{length(map.tests)}, " <>
      "modules_traced: #{map.modules_traced}, outside_windows: #{map.outside_windows}, " <>
      "late_events: #{map.late_events}, suite_exit: #{map.suite_exit}; " <>
      "built at #{map.commit || "(no commit)"}; wrote #{path}"
  end

  defp test_shape?(%{file: f, line: l, name: n, functions: fs})
       when is_binary(f) and is_binary(n) and is_integer(l) and l > 0,
       do: is_list(fs) and Enum.all?(fs, &is_binary/1)

  defp test_shape?(_test), do: false

  defp sha?(nil), do: true

  defp sha?(commit) when is_binary(commit) and byte_size(commit) == 40,
    do: commit |> String.to_charlist() |> Enum.all?(&(&1 in ?0..?9 or &1 in ?a..?f))

  defp sha?(_commit), do: false

  # DND-5640: the one path rule, shared with the kill map and the selection.
  defp safe_file?(file), do: TestPath.check(file) == :ok

  defp arrive(event, state) do
    stamp = elem(event, 1)
    arrived = state.arrived + 1

    if state.released != nil and stamp < state.released do
      %{state | arrived: arrived, late_events: state.late_events + 1}
    else
      %{
        state
        | arrived: arrived,
          pending: [{{stamp, arrived}, event} | state.pending],
          pending_count: state.pending_count + 1
      }
    end
  end

  defp release(state, 0), do: state

  defp release(state, count) do
    {out, keep} = state.pending |> Enum.sort_by(&elem(&1, 0)) |> Enum.split(count)
    {{last_stamp, _seq}, _event} = List.last(out)

    state = %{state | pending: keep, pending_count: length(keep), released: last_stamp}
    Enum.reduce(out, state, fn {_key, event}, acc -> apply_event(event, acc) end)
  end

  defp apply_event({:window_open, _stamp, ref}, state),
    do: %{state | open: Map.put_new(state.open, ref, MapSet.new())}

  defp apply_event({:window_close, _stamp, ref}, state) do
    {set, open} = Map.pop(state.open, ref, MapSet.new())
    %{state | open: open, finished: Map.update(state.finished, ref, set, &MapSet.union(&1, set))}
  end

  defp apply_event({:call, stamp, mfa, pid}, state),
    do: apply_event({:call, stamp, mfa}, seen(state, pid))

  defp apply_event({:call, _stamp, _mfa}, %{open: open} = state) when map_size(open) == 0,
    do: %{state | outside_windows: state.outside_windows + 1}

  defp apply_event({:call, _stamp, mfa}, state),
    do: %{state | open: Map.new(state.open, fn {ref, set} -> {ref, MapSet.put(set, mfa)} end)}

  # The windows open when `pid` was first seen; a later call from it while
  # none of them is open, inside another window, is a leak into that window.
  defp seen(state, pid) do
    open = state.open |> Map.keys() |> MapSet.new()

    case Map.fetch(state.first_seen, pid) do
      :error ->
        %{state | first_seen: Map.put(state.first_seen, pid, open)}

      {:ok, first} ->
        if leaked?(first, open),
          do: %{state | leaks: Enum.reduce(open, state.leaks, &count_leak(first, &1, &2))},
          else: state
    end
  end

  defp leaked?(first, open),
    do: MapSet.size(first) > 0 and MapSet.size(open) > 0 and MapSet.disjoint?(first, open)

  defp count_leak(first, to, leaks), do: Map.update(leaks, {first, to}, 1, &(&1 + 1))

  defp window_leaks(leaks, root) do
    leaks
    |> Enum.map(fn {{first, to}, calls} ->
      from = first |> Enum.map(&relative_ref(&1, root)) |> Enum.sort_by(&ref_order/1)
      %{from: from, to: relative_ref(to, root), calls: calls}
    end)
    |> Enum.sort_by(&{ref_order(&1.to), Enum.map(&1.from, fn ref -> ref_order(ref) end)})
  end

  defp leak_line(file, leaks) do
    total = leaks |> Enum.map(& &1.calls) |> Enum.sum()
    {shown, hidden} = Enum.split(leaks, @leak_pairs_shown)

    pairs =
      Enum.map_join(shown, "; ", fn leak ->
        "#{Enum.map_join(leak.from, " or ", &ref_text/1)} -> #{ref_text(leak.to)} " <>
          "(#{leak.calls} calls)"
      end)

    more = if hidden == [], do: "", else: "; and #{length(hidden)} more"

    "anchor.sabotage coverage: warning: #{file}: #{total} calls from a process first seen " <>
      "during an earlier test were credited to a later test (selection unchanged): " <>
      pairs <> more
  end

  defp ref_text(ref), do: "#{ref.file}:#{ref.line} #{ref.name}"
  defp ref_order(ref), do: {ref.file, ref.line, ref.name}
  defp relative_ref(ref, root), do: %{ref | file: relative(ref.file, root)}

  defp relative(file, nil), do: file
  defp relative(file, root), do: Path.relative_to(file, root)
end
