defmodule Anchor.Adapters.ConfigLoader do
  @moduledoc """
  Behaviour for loading Anchor configuration — the **Side Effect** port
  (ADR 001) that `Anchor.Managers.Lint` depends on.

  Extracting the load contract into a behaviour is what lets the Manager be
  tested against a mock (`Hammox`) instead of the real filesystem: the Manager
  calls `load/0` on whichever module implements this behaviour, defaulting to the
  real adapter `Anchor.Adapters.ConfigFile` and overridable in a test via the
  `:config_loader` option.

  An implementation returns `{:ok, %Anchor.Config{}}` on success, or
  `{:error, reason}` when there is no config to use — none was found, or it did
  not load. Anchor fails closed (DND-1265): the Framework reports `reason` as a
  Credo issue through `Anchor.Domain.Failures`, so no error ever reads as a run
  that found nothing. `Anchor.Adapters.ConfigFile` documents the reasons it
  returns; a reason of any other shape is still reported.
  """

  @callback load() :: {:ok, Anchor.Config.t()} | {:error, term()}

  @doc "`load/0` searching from `root` instead of the working directory (DND-5473)."
  @callback load_in(root :: String.t()) :: {:ok, Anchor.Config.t()} | {:error, term()}

  @doc """
  `load_in/1` with rule types this Anchor does not know set aside in
  `:deferred`, not refused (DND-5658: the landed judge of `mix anchor.graph
  --project`). Every other refusal stands.
  """
  @callback load_judged(root :: String.t()) :: {:ok, Anchor.Config.t()} | {:error, term()}
end
