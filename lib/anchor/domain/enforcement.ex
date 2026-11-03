defmodule Anchor.Domain.Enforcement do
  @moduledoc """
  Applies a rule's baseline to its findings (DND-5441, shared contract section
  8) — a **Domain** module (ADR 001). Pure: the runner reads the files, this
  decides.

  `judge/4` takes a rule's findings (each with its stable `key`), the
  entries of its baseline file, and, under `--base REF`, the entries of the
  base branch's copy, and returns the findings that stand and the ones the
  baseline holds:

    * a finding an entry covers is **held**: counted, never failing;
    * a finding no entry covers (NEW) stands as it is: it fails an `enforce`
      rule;
    * an entry no finding consumes is a STALE finding on the baseline path
      (`Failures.baseline_stale/2`);
    * an entry the branch added since `REF` is a GREW finding
      (`Failures.baseline_grew/3`); a file absent at `REF` is a first landing,
      a report-only NOTE (`Failures.baseline_first_landing/2`).

  STALE and GREW take the rule's enforcement: a `report` rule reports them,
  an `enforce` rule fails on them. A finding with no key cannot be held.
  """

  alias Anchor.Domain.Baseline
  alias Anchor.Domain.Failures
  alias Anchor.Domain.GraphReport.Finding

  @typedoc """
  The base branch's copy: `nil` (no `--base`), `:absent` (no file at the
  ref) or `{:ok, entries}`.
  """
  @type base :: nil | :absent | {:ok, [String.t()]}

  @typedoc "The rule, its label, its baseline path, and the `--base` ref (or nil)."
  @type context :: %{rule: map(), label: String.t(), path: String.t(), ref: String.t() | nil}

  @doc "The findings that stand and the held ones; see the moduledoc."
  @spec judge([Finding.t()], [String.t()], base(), context()) :: {[Finding.t()], [Finding.t()]}
  def judge(findings, entries, base, %{rule: rule, label: label, path: path} = context) do
    keys = findings |> Enum.map(& &1.key) |> Enum.reject(&is_nil/1)
    %{stale: stale, held: held_keys} = Baseline.compare(keys, entries)
    {held, standing} = split_held(findings, held_keys)

    stale_findings =
      Enum.map(stale, &Finding.from_rule(Failures.baseline_stale(path, &1), rule, label, path))

    {standing ++ stale_findings ++ base_findings(entries, base, context), held}
  end

  defp base_findings(_entries, nil, _context), do: []

  defp base_findings(_entries, :absent, %{path: path, ref: ref}) do
    note = Finding.fail_closed(Failures.baseline_first_landing(path, ref), path)
    [%{note | enforcement: :report}]
  end

  defp base_findings(entries, {:ok, base_entries}, context) do
    %{rule: rule, label: label, path: path, ref: ref} = context

    entries
    |> Baseline.grew(base_entries)
    |> Enum.map(&Finding.from_rule(Failures.baseline_grew(path, &1, ref), rule, label, path))
  end

  # Each finding whose key is among `held_keys` (as a multiset) is held, in
  # finding order; the rest stand.
  defp split_held(findings, held_keys) do
    {held, standing, _left} =
      Enum.reduce(findings, {[], [], Enum.frequencies(held_keys)}, fn finding,
                                                                      {held, standing, left} ->
        case Map.get(left, finding.key, 0) do
          0 -> {held, [finding | standing], left}
          n -> {[finding | held], standing, Map.put(left, finding.key, n - 1)}
        end
      end)

    {Enum.reverse(held), Enum.reverse(standing)}
  end
end
