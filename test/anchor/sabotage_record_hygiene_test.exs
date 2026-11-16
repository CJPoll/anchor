defmodule Anchor.SabotageRecordHygieneTest do
  # ADR 004: the committed sabotage records carry no local-only text: no
  # scheduler status line, no path under a home or worktree directory, outside
  # the diff and kill-map blocks that quote the project's own source
  # (Anchor.Domain.Sabotage.RecordHygiene.record_leaks/1). No record is exempt.
  # Sabotage record: ../sabotage_records/record_hygiene-20261116-sabotage_record_redaction.md
  use ExUnit.Case, async: true

  alias Anchor.Domain.Sabotage.RecordHygiene

  @records_glob "test/sabotage_records/*.md"

  test "no committed record carries a scheduler line or a local path" do
    findings =
      for path <- Enum.sort(Path.wildcard(@records_glob)),
          {line, kind} <- RecordHygiene.record_leaks(File.read!(path)),
          do: {path, line, kind}

    assert findings == [],
           "#{inspect(findings, pretty: true, limit: :infinity)}\n" <>
             "Fix: regenerate the record (mix anchor.sabotage run redacts both), or rewrite each " <>
             "line as ADR 004 says: drop a scheduler line, write a path relative to the project " <>
             "root or as <worktree>/... or <home>/..."
  end

  test "positive control: the records directory is read" do
    assert Path.wildcard(@records_glob) != []
  end
end
