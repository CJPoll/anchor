defmodule Anchor.Adapters.WriteRecorder do
  @moduledoc """
  Behaviour for recording the writes each watched test makes — the **Side
  Effect** port (ADR 001) `Anchor.Managers.Backstop` depends on (DND-5480).
  The real adapter is `Anchor.Adapters.TelemetryRecorder`; the Manager's
  tests double it with Hammox.

    * `attach_recorder/2` attaches to a repo's query event (`prefix ++
      [:query]`) with a transaction probe, and returns the recorder;
    * `watch_pid/2` marks a test's pid as watched: from then on its writes,
      and those of every process with it in `$callers`, are recorded;
    * `take_events/2` returns a test's writes in the order they came and
      forgets them and the pid;
    * `recorder_attached?/1` is false once `:telemetry` has detached the
      handler (it raised) or the recorder's table is gone;
    * `add_counts/2` and `read_totals/1` keep the suite's totals
      (`Anchor.Domain.Aggregates.Backstop.total_keys/0`), `unattributed`
      included, which the recorder counts itself;
    * `install_session/1` and `installed_session/0` keep the one session a
      test VM's `Anchor.Backstop.attach!/1` started, for `watch/1` to find
      (a second is refused);
    * `detach_recorder/1` detaches the handler and drops the table.

  Nothing it keeps holds a parameter or a row value: table names, kinds and
  pids only.
  """

  alias Anchor.Domain.Aggregates.BackstopEvent

  @typedoc "A recorder `attach_recorder/2` returned; opaque to its callers."
  @type recorder :: %{required(atom()) => term()}

  @callback attach_recorder(event :: [atom()], probe :: module()) ::
              {:ok, recorder()} | {:error, term()}
  @callback watch_pid(recorder(), pid()) :: :ok
  @callback take_events(recorder(), pid()) :: [BackstopEvent.t()]
  @callback recorder_attached?(recorder()) :: boolean()
  @callback add_counts(recorder(), %{atom() => non_neg_integer()}) :: :ok
  @callback read_totals(recorder()) :: %{atom() => non_neg_integer()}
  @callback install_session(session :: map()) :: :ok | {:error, :already_installed}
  @callback installed_session() :: {:ok, map()} | :error
  @callback detach_recorder(recorder()) :: :ok
end
