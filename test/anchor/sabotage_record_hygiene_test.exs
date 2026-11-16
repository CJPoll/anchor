defmodule Anchor.SabotageRecordHygieneTest do
  # ADR 004: the committed sabotage records carry no local-only text: no
  # scheduler status line, no path under a home or worktree directory
  # (Anchor.Domain.Sabotage.RecordHygiene). A record committed before
  # `mix anchor.sabotage run` redacted its records is listed, shrink only, in
  # .anchor/sabotage/record_leaks.txt; every other record must be clean, and
  # the list may not hold a clean, missing, newer or new record.
  # Sabotage record: ../sabotage_records/record_hygiene-20261116-sabotage_record_redaction.md
  use ExUnit.Case, async: true

  alias Anchor.Domain.Sabotage.RecordHygiene

  @records_glob "test/sabotage_records/*.md"
  @list ".anchor/sabotage/record_leaks.txt"
  # The newest record on the list when it landed. Raising it lets a newer
  # record be listed, which is loosening the check.
  @newest ~D[2026-11-08]
  # The list as it landed. An entry may leave the list; one this copy does not
  # hold may never join it, so growing the list means editing this test.
  @landed [
    "aggregates-20261103-dnd_5459_write_sets.md",
    "aggregates-20261106-dnd_5459_write_sets.md",
    "baseline-20261103-dnd_5648_graph_followups.md",
    "beam_reader-20261103-dnd_5438.md",
    "beam_reader-20261106-dnd_5676_effects_cfa_batch.md",
    "cfa-20261106-dnd_5676_effects_cfa_batch.md",
    "coverage_compare-20261106-dnd_5692_repeatability_check.md",
    "graph_rules-20261106-dnd_5676_effects_cfa_batch.md",
    "graph_runner-20261103-dnd_5581_hardening_batch.md",
    "graph_runner-20261103-dnd_5630_graph_hardening.md",
    "record_file-20261106-dnd_5516_sabotage_verify.md",
    "sabotage-20261103-dnd_5630_graph_hardening.md",
    "sabotage_scope-20261103-dnd_5472.md",
    "source_patcher-20261108-dnd_6070_anchor_mirror_selection.md"
  ]

  defp records do
    Map.new(Path.wildcard(@records_glob), fn path -> {path, File.read!(path)} end)
  end

  defp listed do
    @list
    |> File.read!()
    |> String.split("\n")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == "" or String.starts_with?(&1, "#")))
  end

  test "every committed record is clean, or listed while it still leaks" do
    findings = RecordHygiene.judge(records(), listed(), @newest)

    assert findings == [],
           "#{inspect(findings, pretty: true, limit: :infinity)}\n" <>
             "Fix: a :leak is a record carrying a scheduler line or a local path: regenerate it " <>
             "(mix anchor.sabotage run redacts both) or edit the line out. A :stale or :missing " <>
             "entry is fixed: remove it from #{@list}. A :late entry cannot be listed."
  end

  test "the list only shrinks: every entry is one it landed with" do
    landed = Enum.map(@landed, &"test/sabotage_records/#{&1}")
    assert listed() -- landed == [], "Fix: a record that was not on the list never joins it"
  end

  test "the list is sorted and has no duplicate" do
    assert listed() == Enum.uniq(Enum.sort(listed()))
  end
end
