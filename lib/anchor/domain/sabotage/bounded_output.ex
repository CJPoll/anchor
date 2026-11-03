defmodule Anchor.Domain.Sabotage.BoundedOutput do
  @moduledoc """
  A bounded collector for a test run's output (DND-5573). Pure **Domain**: a
  `Collectable` that `System.cmd/3` fills through `into:`, so a mutant that
  prints without end cannot grow the VM's memory.

  It keeps the first `head_limit` bytes (where a compile error is) and the
  last `tail_limit` bytes (where a crash's last words are), and counts every
  byte between them. `text/1` joins the two with a line that says how many
  bytes were dropped, and `dropped/1` is the count. The bytes kept and
  dropped are the same however the output is cut into chunks.
  """

  @default_limit 32_768

  defstruct head: "", tail: "", dropped: 0, head_limit: @default_limit, tail_limit: @default_limit

  @type t :: %__MODULE__{
          head: binary(),
          tail: binary(),
          dropped: non_neg_integer(),
          head_limit: non_neg_integer(),
          tail_limit: non_neg_integer()
        }

  @doc "An empty collector keeping `head_limit` bytes from the start and `tail_limit` from the end."
  @spec new(non_neg_integer(), non_neg_integer()) :: t()
  def new(head_limit \\ @default_limit, tail_limit \\ @default_limit),
    do: %__MODULE__{head_limit: head_limit, tail_limit: tail_limit}

  @doc "Adds a chunk of output."
  @spec append(t(), binary()) :: t()
  def append(%__MODULE__{} = out, chunk) when is_binary(chunk) do
    room = max(out.head_limit - byte_size(out.head), 0)
    take = min(room, byte_size(chunk))
    <<for_head::binary-size(take), rest::binary>> = chunk

    trim_tail(%{out | head: out.head <> for_head, tail: out.tail <> rest})
  end

  @doc "The bytes between the head and the tail that were not kept."
  @spec dropped(t()) :: non_neg_integer()
  def dropped(%__MODULE__{dropped: dropped}), do: dropped

  @doc """
  The kept output as valid UTF-8, with a line stating the dropped bytes
  between the head and the tail when any were dropped.
  """
  @spec text(t()) :: String.t()
  def text(%__MODULE__{dropped: 0} = out), do: String.replace_invalid(out.head <> out.tail)

  def text(%__MODULE__{} = out) do
    marker = "\n[... #{out.dropped} bytes of test output dropped ...]\n"
    String.replace_invalid(out.head <> marker <> out.tail)
  end

  defp trim_tail(%__MODULE__{tail: tail, tail_limit: limit} = out) when byte_size(tail) > limit do
    excess = byte_size(tail) - limit
    %{out | tail: binary_part(tail, excess, limit), dropped: out.dropped + excess}
  end

  defp trim_tail(out), do: out

  defimpl Collectable do
    alias Anchor.Domain.Sabotage.BoundedOutput

    def into(out) do
      {out,
       fn
         acc, {:cont, chunk} -> BoundedOutput.append(acc, chunk)
         acc, :done -> acc
         _acc, :halt -> :ok
       end}
    end
  end
end
