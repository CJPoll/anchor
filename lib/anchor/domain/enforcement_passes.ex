defmodule Anchor.Domain.EnforcementPasses do
  @moduledoc """
  Joins the two detection passes of one file (DND-5631), **Domain** (ADR 001).

  `Anchor.Managers.Lint.detect_file/5` detects the rules in `enforcement:
  report` apart from the enforced ones (DND-5441). A violation a check reports
  once per file, whatever the rules (an `alias`/`import`/`require` it cannot
  resolve, a dynamic call), then came once from each pass: the same line
  printed twice. `merge/2` keeps one copy of each violation both passes found
  (same file, line, trigger, kind and message): the enforced one, since the
  finding fails the run through its enforced rule, with its message naming both
  modes (`Anchor.Domain.Failures.both_enforcement_modes/1`). A violation only
  one pass found is kept as it is.
  """

  alias Anchor.Domain.Failures
  alias Anchor.Domain.Violation

  @doc """
  The enforced pass's violations followed by the report pass's, each violation
  both found once, enforced, naming both modes. Order is kept.
  """
  @spec merge([Violation.t()], [Violation.t()]) :: [Violation.t()]
  def merge(enforced, reported) do
    in_both = MapSet.intersection(identities(enforced), identities(reported))

    Enum.map(enforced, &name_both(&1, in_both)) ++
      Enum.reject(reported, &MapSet.member?(in_both, identity(&1)))
  end

  defp identities(violations), do: MapSet.new(violations, &identity/1)

  defp identity(%Violation{} = v), do: {v.filename, v.line, v.trigger, v.kind, v.message}

  defp name_both(violation, in_both) do
    if MapSet.member?(in_both, identity(violation)),
      do: %{violation | message: Failures.both_enforcement_modes(violation.message)},
      else: violation
  end
end
