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
    * `{:call, stamp, mfa}`, `mfa` a `{module, name, arity}` or a
      `"Module.name/arity"` string.

  Trace messages from several processes can arrive out of stamp order, so
  events are buffered and released in stamp order, always keeping the `slack`
  (default #{10_000}) newest buffered: an event is attributed only once at
  least `slack` events with later stamps have arrived. An event whose stamp is older
  than one already released is counted in `late_events`, never attributed and
  never dropped silently: the map and the summary say how many there were.

  A released call inside an open window adds its function to that test's set
  (a set: a thousand calls cost one element). A call outside every window
  (`setup_all`, a process that outlived its test) counts in `outside_windows`.

  ## The map (`finalize/2`)

      %{version: 1, commit: sha, elixir: v, otp: v,
        tests: [%{file, line, name, module, functions: ["M.f/a"]}],
        modules_traced: n, outside_windows: n, late_events: n, suite_exit: status}

  `validate/1` refuses a map with zero tests or zero traced modules: such a map
  measured nothing (`COULD NOT MEASURE`, exit 3), and is never written.
  """

  alias Anchor.Domain.Sabotage.TestPath

  @version 1
  @default_slack 10_000

  defstruct slack: @default_slack,
            pending: [],
            pending_count: 0,
            arrived: 0,
            released: nil,
            open: %{},
            finished: %{},
            outside_windows: 0,
            late_events: 0

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
          suite_exit: integer()
        }

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
      suite_exit: Map.fetch!(meta, :suite_exit)
    }
  end

  @doc "`:ok`, or why the map measured nothing."
  @spec validate(t()) :: :ok | {:error, :no_tests | :no_modules}
  def validate(%{tests: []}), do: {:error, :no_tests}
  def validate(%{modules_traced: 0}), do: {:error, :no_modules}
  def validate(%{tests: [_ | _], modules_traced: n}) when is_integer(n) and n > 0, do: :ok

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

  defp apply_event({:call, _stamp, _mfa}, %{open: open} = state) when map_size(open) == 0,
    do: %{state | outside_windows: state.outside_windows + 1}

  defp apply_event({:call, _stamp, mfa}, state),
    do: %{state | open: Map.new(state.open, fn {ref, set} -> {ref, MapSet.put(set, mfa)} end)}

  defp relative(file, nil), do: file
  defp relative(file, root), do: Path.relative_to(file, root)
end
