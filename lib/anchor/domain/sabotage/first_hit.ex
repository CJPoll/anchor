defmodule Anchor.Domain.Sabotage.FirstHit do
  @moduledoc """
  Which call messages the coverage tracer keeps, which it drops, and when it
  silences a function (DND-5652). Pure **Domain**.

  The coverage map records, per test, the set of project functions that ran
  (`Anchor.Domain.Sabotage.CoverageMap`). A set needs a function's calls only
  until it is known to have run, but tracing every call sent one message per
  call: a fixpoint over anchor's own graph is 72 million calls of 676
  functions, and its test overran ExUnit's 60 s bound under the tracer.

  So `Anchor.Adapters.CallTracer` numbers the windows in the VM's trace
  control word (each `test_started` and `test_finished` adds one, inside the
  traced call, so the number moves before the test runs), every call message
  carries that number, and the tracer process (`Anchor.Adapters.FirstHitGate`)
  asks this module about each one:

    * a function's first `threshold/0` messages in a window are forwarded (the
      map sees them, with their pids, exactly as before);
    * the message that reaches the threshold is forwarded and **silences** the
      function while the word is that window: a later window traces it again
      with no step of its own;
    * a message that arrives after the function was silenced for its own
      window (it was already in flight) is **dropped**: the function is in the
      map for that window already.

  Two clocks are in play: the word a call message carries, and the strict
  monotonic stamp the map attributes it by. A call on another scheduler can
  read the new word `w` just before the boundary's own message is stamped,
  so its stamp is earlier than window `w`'s opening and the map counts it
  outside `w`. Counting it, or silencing on it, would hide the test's own
  later call. So only a message provably inside its window counts: its
  window's boundary has been seen (`boundary/3`) and its stamp is at or after
  that boundary's stamp (window 0, before any boundary, has no lower edge).
  Any other message is forwarded and counts for nothing.

  `decide/4` answers `:forward`, `:drop` or `:silence` (forward, then
  silence), with the new state.
  """

  @threshold 64

  @type mfa_key :: {module(), atom(), arity()}
  @type stamp :: term()
  @type state :: %{
          silenced: %{mfa_key() => non_neg_integer()},
          counts: %{mfa_key() => {non_neg_integer(), pos_integer()}},
          boundaries: %{non_neg_integer() => stamp()}
        }

  @doc "How many messages of one function in one window are forwarded before it is silenced."
  @spec threshold() :: pos_integer()
  def threshold, do: @threshold

  @doc "No function silenced or counted, no boundary seen."
  @spec new() :: state()
  def new, do: %{silenced: %{}, counts: %{}, boundaries: %{}}

  @doc """
  The boundary that opened window `word`, stamped `stamp` (the word a
  `test_started` or `test_finished` message carries is the one it set). Two
  boundaries from different runner processes can arrive swapped, so an edge
  is never earlier than the one before it, when that one is known.
  """
  @spec boundary(state(), pos_integer(), stamp()) :: state()
  def boundary(state, word, stamp) do
    opened =
      case Map.fetch(state.boundaries, word - 1) do
        {:ok, before} -> max(stamp, before)
        :error -> stamp
      end

    %{state | boundaries: Map.put(state.boundaries, word, opened)}
  end

  @doc "What `mfa`'s call message from `window`, stamped `stamp`, does."
  @spec decide(state(), mfa_key(), non_neg_integer(), stamp()) ::
          {:forward | :drop | :silence, state()}
  def decide(state, mfa, window, stamp) when is_integer(window) do
    silenced = Map.get(state.silenced, mfa, -1)

    cond do
      silenced == window -> {:drop, state}
      silenced > window -> {:forward, state}
      not inside?(state, window, stamp) -> {:forward, state}
      true -> count(state, mfa, window)
    end
  end

  defp count(state, mfa, window) do
    seen =
      case Map.get(state.counts, mfa) do
        {^window, n} -> n + 1
        _other_window_or_none -> 1
      end

    if seen >= @threshold do
      {:silence,
       %{
         state
         | silenced: Map.put(state.silenced, mfa, window),
           counts: Map.delete(state.counts, mfa)
       }}
    else
      {:forward, %{state | counts: Map.put(state.counts, mfa, {window, seen})}}
    end
  end

  defp inside?(_state, 0, _stamp), do: true

  defp inside?(state, window, stamp) do
    case Map.fetch(state.boundaries, window) do
      {:ok, opened} -> stamp >= opened
      :error -> false
    end
  end
end
