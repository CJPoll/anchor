defmodule Anchor.SabotageRecordHygieneTest do
  # The committed sabotage records carry no local-only text: no scheduler
  # status line, no absolute path under a home directory
  # (Anchor.Domain.Sabotage.RecordHygiene). A record committed before
  # `mix anchor.sabotage run` redacted its records is listed, shrink only, in
  # .anchor/sabotage_record_leaks.txt; every other record must be clean, and
  # the list may not hold a clean, missing or newer record.
  # Sabotage record: ../sabotage_records/record_hygiene-20261116-sabotage_record_redaction.md
  use ExUnit.Case, async: true

  alias Anchor.Domain.Sabotage.RecordHygiene

  @records_glob "test/sabotage_records/*.md"
  @list ".anchor/sabotage_record_leaks.txt"
  # The newest record on the list when it landed. Raising it lets a newer
  # record be listed, which is loosening the check.
  @newest ~D[2026-11-08]

  defp records do
    Map.new(Path.wildcard(@records_glob), fn path -> {path, File.read!(path)} end)
  end

  defp listed do
    @list
    |> File.read!()
    |> String.split("\n", trim: true)
    |> Enum.reject(&String.starts_with?(&1, "#"))
  end

  test "every committed record is clean, or listed while it still leaks" do
    findings = RecordHygiene.judge(records(), listed(), @newest)

    assert findings == [],
           "#{inspect(findings, pretty: true, limit: :infinity)}\n" <>
             "Fix: a :leak is a record carrying a scheduler line or a home path: regenerate it " <>
             "(mix anchor.sabotage run redacts both) or edit the line out. A :stale or :missing " <>
             "entry is fixed: remove it from #{@list}. A :late entry cannot be listed."
  end

  test "the list is sorted and has no duplicate" do
    assert listed() == Enum.uniq(Enum.sort(listed()))
  end
end
