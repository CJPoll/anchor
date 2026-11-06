defmodule Anchor.Domain.GraphReport.FindingNoteTest do
  # DND-5658: `Finding.note/2`, the report-only note the landed judge's FIRST
  # LANDING lines are made with. Pure Domain.
  #
  # Sabotage record: ../../sabotage_records/landed_judge-20261103-dnd_5658_ci_base_ratchet.md
  use ExUnit.Case, async: true

  alias Anchor.Domain.GraphReport
  alias Anchor.Domain.GraphReport.Finding
  alias Anchor.Domain.Violation

  @violation %Violation{filename: nil, kind: :fail_closed, message: "NOTE: first landing"}

  test "a note is the fail-closed finding, report-only, on the default file" do
    note = Finding.note(@violation, ".anchor.yml")

    assert note.enforcement == :report
    assert note.file == ".anchor.yml"
    assert note.message == "NOTE: first landing"
    assert %{note | enforcement: :enforce} == Finding.fail_closed(@violation, ".anchor.yml")
  end

  test "a report with only a note exits 0; positive control: the fail-closed finding exits 1" do
    counts = %{modules: 1, apps: 1, rules: 0, opaque: 0}
    assert GraphReport.new([Finding.note(@violation, "f")], [], counts).exit_code == 0
    assert GraphReport.new([Finding.fail_closed(@violation, "f")], [], counts).exit_code == 1
  end
end
