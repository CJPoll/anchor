defmodule Anchor.Domain.GraphRule do
  @moduledoc """
  The contract every graph rule implements (DND-5440, shared contract section
  6) — a **Domain** behaviour (ADR 001).

  A graph rule reads the one `Anchor.Domain.Model` a run builds and returns
  its violations. It is pure: no IO, no project code. Each violation sets
  `filename` (repo-relative source) and `line`, and its message ends with
  `Fix: <shape>`, the rule's conforming shape (`Anchor.Domain.RuleShape`).
  `key` is the stable baseline key (DND-5441): no line numbers, no text that
  moves.

  Every graph rule module is listed in `Anchor.Domain.GraphRules.all/0`, and
  the set of their `rule_type/0`s equals RuleSchema's graph-engine types (a
  test holds them equal). The runner (`Anchor.Managers.Graph`) calls `check/2`
  under a guard: a raise, throw or exit is one issue naming the rule, and the
  other rules still run.
  """

  @doc "The rule type this module checks (a key of RuleSchema's `@engine_by_type`, engine `:graph`)."
  @callback rule_type() :: atom()

  @doc "The violations of `rule` (a parsed rule map) in `model`."
  @callback check(Anchor.Domain.Model.t(), rule :: map()) :: [Anchor.Domain.Violation.t()]
end
