defmodule Anchor.Adapters.InProcessTests do
  @moduledoc """
  Behaviour for running a project's test suite in this VM, so its calls can be
  traced (DND-5474), the **Side Effect** port (ADR 001); the implementation is
  `Anchor.Adapters.SuiteRunner`, doubled in tests as
  `Anchor.InProcessTestsMock`.

  `run(args)` compiles every test file, then runs the suite one test at a time,
  and returns `{:passed, total}` or `{:failed, message, total}`, `total` being the
  tests ExUnit counted (excluded and skipped ones too), or nil when it never ran
  (a test file that does not compile, a test helper that raised).
  """

  @typedoc """
  A module implementing this behaviour. A parameter whose `@spec` says
  `InProcessTests.t()` is what lets `mix anchor.graph` judge a call on it
  against this behaviour's implementers only (DND-5633,
  `Anchor.Domain.BehaviourReceiver`).
  """
  @type t :: module()

  @type result :: {:passed, non_neg_integer()} | {:failed, String.t(), non_neg_integer() | nil}

  @callback run(args :: [String.t()]) :: result()
end
