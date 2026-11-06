defmodule Anchor.Adapters.TelemetryRecorderSessionTest do
  # DND-5480: the one session a test VM keeps (`install_session/1`,
  # `installed_session/0`).
  #
  # sync: the session is VM-global (`:persistent_term`); `Anchor.BackstopTest`
  # (async) asserts no session is installed. Async modules all run before
  # sync ones, so installing one here never overlaps it, and on_exit erases
  # it.
  #
  # Sabotage record: ../../sabotage_records/backstop-20261106-dnd_5480_test_backstop.md
  use ExUnit.Case, async: false

  alias Anchor.Adapters.TelemetryRecorder, as: Recorder

  test "a session installed is the session installed_session returns" do
    on_exit(fn -> :persistent_term.erase({Recorder, :session}) end)
    assert Recorder.installed_session() == :error

    session = %{escapes: :report, marker: make_ref()}
    :ok = Recorder.install_session(session)

    assert Recorder.installed_session() == {:ok, session}
  end
end
