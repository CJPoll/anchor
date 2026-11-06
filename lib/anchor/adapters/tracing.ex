defmodule Anchor.Adapters.Tracing do
  @moduledoc """
  Behaviour for call tracing while `mix anchor.sabotage coverage` runs the
  suite (DND-5474), the **Side Effect** port (ADR 001); the implementation is
  `Anchor.Adapters.CallTracer`, doubled in tests as `Anchor.TracingMock`.

    * `start/2` — traces every local call of the given modules, and the
      ExUnit calls that bound each test, to the collector process;
      `{:error, :already_tracing}` when another tracer is on (it is never
      switched off or shared), `{:error, {:not_loadable, modules}}` when a given
      module cannot be loaded (DND-5690), `{:error, {:pattern_missing, mfa}}`
      when an ExUnit function the run reads is gone (DND-5691), each with
      nothing traced;
    * `stop/0` — clears every trace flag and pattern `start/2` set;
    * `collected/1` — asks the collector for what it attributed:
      `{:ok, state}` (an `Anchor.Domain.Sabotage.CoverageMap` state),
      or `{:error, {:collector_down, reason}}`.
  """

  alias Anchor.Domain.Sabotage.CoverageMap

  @callback start(collector :: pid(), modules :: [module()]) ::
              :ok
              | {:error, :already_tracing}
              | {:error, {:not_loadable, [module()]}}
              | {:error, {:pattern_missing, mfa()}}
  @callback stop() :: :ok
  @callback collected(collector :: pid()) ::
              {:ok, CoverageMap.state()} | {:error, {:collector_down, term()}}
end
