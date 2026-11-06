defmodule Anchor.Domain.EnforcementPasses do
  @moduledoc """
  Joins the two detection passes of one file (DND-5631), **Domain** (ADR 001).

  `Anchor.Managers.Lint.detect_file/5` detects the rules in `enforcement:
  report` apart from the enforced ones (DND-5441). A violation a check reports
  once per file, whatever the rules (an `alias`/`import`/`require` it cannot
  resolve, a dynamic call), then came once from each pass: the same line
  printed twice. `merge/2` keeps one copy of each violation both passes found
  (same file, line, trigger, kind and message, apart from the rule's own
  `Fix:` sentence): the enforced one, since the
  finding fails the run through its enforced rule, with its message naming both
  modes (`Anchor.Domain.Failures.both_enforcement_modes/1`). A violation only
  one pass found is kept as it is.

  `unique/1` joins a file's passes once a baselined rule's own pass is among
  them (DND-5632): one copy per finding, the enforced one when any is.
  """

  alias Anchor.Domain.Failures
  alias Anchor.Domain.RuleShapes
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

  @doc """
  A file's violations once a baselined rule's own pass is among them
  (DND-5632), each finding printed once without losing what it means:

    * a keyed copy (a baselined rule's finding, carrying its key) is always
      kept: it is that rule's finding, and its key is what `mix
      anchor.baseline --write` writes, so two baselined rules making one
      finding print it once each;
    * an unkeyed copy is dropped when a kept copy of the same finding (same
      file, line, trigger, kind and message, apart from the note `merge/2`
      adds and the rule's own `Fix:`) fails at least as hard: an
      enforced copy covers any, a report copy covers only a report one. So a
      report rule's copy never hides an enforced finding, and an enforced
      rule's copy is never dropped for a report one.

  Order is first-seen.
  """
  @spec unique([Violation.t()]) :: [Violation.t()]
  def unique(violations) do
    keyed = Enum.reject(violations, &is_nil(&1.key))

    {kept, _covered} =
      Enum.flat_map_reduce(violations, coverage(keyed), fn v, covered ->
        cond do
          not is_nil(v.key) ->
            {[v], covered}

          covers?(Map.get(covered, identity(v)), v.enforcement) ->
            {[], covered}

          true ->
            {[v], Map.update(covered, identity(v), v.enforcement, &strongest(&1, v.enforcement))}
        end
      end)

    kept
  end

  # Per finding, the strongest enforcement among `violations`.
  defp coverage(violations) do
    Enum.reduce(violations, %{}, fn v, acc ->
      Map.update(acc, identity(v), v.enforcement, &strongest(&1, v.enforcement))
    end)
  end

  defp covers?(nil, _enforcement), do: false
  defp covers?(:enforce, _enforcement), do: true
  defp covers?(:report, enforcement), do: enforcement == :report

  defp strongest(:enforce, _other), do: :enforce
  defp strongest(_report, other), do: other

  defp identities(violations), do: MapSet.new(violations, &identity/1)

  # What the finding is: the note `merge/2` adds says how it was found, and the
  # `Fix:` is each rule's own shape (DND-5446), so copies differing only in those
  # are one finding.
  defp identity(%Violation{} = v) do
    {v.filename, v.line, v.trigger, v.kind,
     v.message |> Failures.without_both_enforcement_modes() |> RuleShapes.without_fix()}
  end

  defp name_both(violation, in_both) do
    if MapSet.member?(in_both, identity(violation)),
      do: %{violation | message: Failures.both_enforcement_modes(violation.message)},
      else: violation
  end
end
