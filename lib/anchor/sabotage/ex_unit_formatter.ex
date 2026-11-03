defmodule Anchor.Sabotage.ExUnitFormatter do
  @moduledoc """
  The ExUnit formatter a sabotage run adds to the project's test command
  (DND-5473): failed tests are read from its frames, never parsed from
  ExUnit's output. It is a **Side Effect** adapter (ADR 001) that ExUnit, an
  outside framework, calls in the project's test VM: it writes a file and
  calls no Anchor module, so it loads there alone. `Anchor.Adapters.TestRunner`
  reads what it writes.

  It appends one frame per event to the file named by
  `ANCHOR_SABOTAGE_RESULTS` (or the `:results_path` option): a 32-bit length,
  then `:erlang.term_to_binary/1` of

    * `{:suite_started}`;
    * `{:test_failed, file, line, name, first_failure_text}` — `file`
      relative to the working directory, `name` the test's name
      (`"test adds"`); a test whose `setup_all` failed counts as failed;
    * `{:suite_finished, total, failures, excluded}` — `total` counts the
      tests that ran (skipped and excluded ones are `excluded`).

  With no results path it writes nothing. It calls no other Anchor module and
  matches ExUnit's events by shape only, so it loads in the project's test VM
  by itself.
  """

  use GenServer

  @text_limit 2000

  @impl GenServer
  def init(opts) do
    path = Keyword.get(opts, :results_path) || System.get_env("ANCHOR_SABOTAGE_RESULTS")
    {:ok, %{path: path, total: 0, failures: 0, excluded: 0}}
  end

  @impl GenServer
  def handle_cast({:suite_started, _opts}, state) do
    frame(state, {:suite_started})
    {:noreply, state}
  end

  def handle_cast({:test_finished, %{state: test_state} = test}, state),
    do: {:noreply, finished(test_state, test, state)}

  def handle_cast({:suite_finished, _times}, state) do
    frame(state, {:suite_finished, state.total, state.failures, state.excluded})
    {:noreply, state}
  end

  def handle_cast(_event, state), do: {:noreply, state}

  defp finished({kind, _detail}, _test, state) when kind in [:skipped, :excluded],
    do: %{state | excluded: state.excluded + 1}

  defp finished({:failed, failures}, test, state), do: failed(test, text(failures), state)

  defp finished({:invalid, module}, test, state),
    do: failed(test, "setup_all failed: " <> text(module_failures(module)), state)

  defp finished(_passed, _test, state), do: %{state | total: state.total + 1}

  defp failed(test, text, state) do
    tags = Map.get(test, :tags, %{})
    file = tags |> Map.get(:file, "") |> Path.relative_to_cwd()
    frame(state, {:test_failed, file, Map.get(tags, :line, 0), to_string(test.name), text})
    %{state | total: state.total + 1, failures: state.failures + 1}
  end

  defp module_failures(%{state: {:failed, failures}}), do: failures
  defp module_failures(_module), do: []

  defp text([{kind, reason, stack} | _rest]),
    do: kind |> Exception.format_banner(reason, stack) |> String.slice(0, @text_limit)

  defp text(_failures), do: ""

  defp frame(%{path: nil}, _term), do: :ok

  defp frame(%{path: path}, term) do
    bin = :erlang.term_to_binary(term)
    File.write!(path, <<byte_size(bin)::32, bin::binary>>, [:append, :binary])
  end
end
