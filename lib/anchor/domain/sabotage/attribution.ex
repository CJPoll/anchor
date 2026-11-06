defmodule Anchor.Domain.Sabotage.Attribution do
  @moduledoc """
  What one recorded call means (DND-5691). Pure **Domain**.

  Ownership decides first: an owned process belongs to its owner whatever its
  label says, and a call past its owner's window is a leak. Only a process with
  no owner is judged by its label, and a label credits only inside its own
  window: past it the call is ambient, never a leak. Crediting the old label
  would make the map depend on which test last called that server, and test
  order differs between builds at one seed.

  A label that is neither a test's open word (windows open only at odd words, so an
  even integer never is) nor a module of this run is refused:
  it comes from something else using seq_trace, so nothing it says can be
  believed.
  """

  alias Anchor.Domain.Sabotage.ProcessOwnership

  @type context :: %{
          required(:windows) => MapSet.t(non_neg_integer()),
          required(:module_ends) => %{module() => non_neg_integer()}
        }
  @type result ::
          {:credit, ProcessOwnership.owner()}
          | {:leak, ProcessOwnership.owner()}
          | :ambient
          | {:error, {:bad_label, term()}}

  @doc "Classifies a call by its owner (or nil), its label (or `:none`) and its word."
  @spec classify(ProcessOwnership.owner() | nil, term(), non_neg_integer(), context()) :: result()
  def classify({:test, n} = owner, _label, word, _context),
    do: if(word == open_word(n), do: {:credit, owner}, else: {:leak, owner})

  def classify({:module, module} = owner, _label, word, context),
    do: if(past?(module, word, context), do: {:leak, owner}, else: {:credit, owner})

  def classify(nil, :none, _word, _context), do: :ambient

  def classify(nil, label, word, %{windows: windows}) when is_integer(label) do
    cond do
      not MapSet.member?(windows, label) -> {:error, {:bad_label, label}}
      label == word -> {:credit, {:test, test_number(label)}}
      true -> :ambient
    end
  end

  def classify(nil, label, word, %{module_ends: ends} = context)
      when is_atom(label) and is_map_key(ends, label),
      do: if(past?(label, word, context), do: :ambient, else: {:credit, {:module, label}})

  def classify(nil, label, _word, _context), do: {:error, {:bad_label, label}}

  @doc "The word at which test `n`'s window is open."
  @spec open_word(non_neg_integer()) :: pos_integer()
  def open_word(n), do: 2 * n + 1

  @doc "The test whose window opens at `word`, an odd word."
  @spec test_number(pos_integer()) :: non_neg_integer()
  def test_number(word), do: div(word - 1, 2)

  defp past?(module, word, %{module_ends: ends}), do: word >= Map.fetch!(ends, module)
end
