defmodule Anchor.Domain.DataFlow.Scope do
  @moduledoc """
  The binding environment of one clause (DND-5439): a stack of frames mapping a
  variable name to the key of its current binding. Pure **Domain**.

  Elixir bindings are single-assignment, so every binding gets a fresh key
  `{name, context, version}`, where `version` counts the earlier bindings of
  that name anywhere in the clause. The count is clause-wide and survives
  `pop/1`, so a key is never reused, even by a sibling clause.

  A read of a name no frame binds (a variable free in the analysed clause,
  which compiled source never has outside a `quote`) gets the key
  `{name, context, :free}`: it is reported, never dropped.
  """

  defstruct frames: [%{}], versions: %{}

  @type var_key :: {atom(), atom() | nil, non_neg_integer() | :free}
  @type t :: %__MODULE__{frames: [%{{atom(), atom() | nil} => var_key()}], versions: map()}

  @spec bind(t(), atom(), atom() | nil) :: {var_key(), t()}
  def bind(%__MODULE__{frames: [top | rest], versions: versions} = scope, name, context) do
    version = Map.get(versions, {name, context}, 0)
    key = {name, context, version}

    {key,
     %{
       scope
       | frames: [Map.put(top, {name, context}, key) | rest],
         versions: Map.put(versions, {name, context}, version + 1)
     }}
  end

  @spec depth(t()) :: pos_integer()
  def depth(%__MODULE__{frames: frames}), do: length(frames)

  @spec lookup(t(), atom(), atom() | nil) :: var_key()
  def lookup(%__MODULE__{frames: frames}, name, context) do
    Enum.find_value(frames, {name, context, :free}, &Map.get(&1, {name, context}))
  end

  @spec new() :: t()
  def new, do: %__MODULE__{}

  @spec pop(t()) :: t()
  def pop(%__MODULE__{frames: [_top, next | rest]} = scope), do: %{scope | frames: [next | rest]}

  @spec push(t()) :: t()
  def push(%__MODULE__{frames: frames} = scope), do: %{scope | frames: [%{} | frames]}
end
