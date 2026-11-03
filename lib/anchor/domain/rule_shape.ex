defmodule Anchor.Domain.RuleShape do
  @moduledoc """
  The conforming shape of a rule (DND-5437): the text a violation's `Fix:` line
  ends with, and what `mix anchor.explain` (DND-5446) is to print for the rule — a **Domain**
  behaviour (ADR 001).

  Each rule type implements it once, so what a violation tells the author to
  write and what `explain` tells an agent to write in the first place are the
  same text. It ships here as the contract only, with no implementation yet:
  DND-5446 implements it for every rule type and adds the test that every type
  has one.
  """

  @doc "The conforming shape of `rule` (a parsed rule map), as one sentence."
  @callback shape(rule :: map()) :: String.t()
end
