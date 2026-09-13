defmodule Anchor.Adapters.ConfigLoader do
  @moduledoc """
  Behaviour for loading Anchor configuration — the **Side Effect** port
  (ADR 001) that `Anchor.Managers.Lint` depends on.

  Extracting the load contract into a behaviour is what lets the Manager be
  tested against a mock (`Hammox`) instead of the real filesystem: the Manager
  calls `load/0` on whichever module implements this behaviour, defaulting to the
  real adapter `Anchor.Adapters.ConfigFile` and overridable in a test via the
  `:config_loader` option.

  An implementation returns `{:ok, %Anchor.Config{}}` on success (an empty config
  when no `.anchor.yml` is present, so checks run as no-ops) or
  `{:error, reason}` when loading fails — in which case the checks are skipped
  rather than crashing the Credo run.
  """

  @callback load() :: {:ok, Anchor.Config.t()} | {:error, term()}
end
