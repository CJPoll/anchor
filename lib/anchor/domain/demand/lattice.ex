defmodule Anchor.Domain.Demand.Lattice do
  @moduledoc """
  The demand lattice of the absence analysis (`Anchor.Domain.Demand`) —
  **Domain**, pure (DND-5498, requirement R1).

  A demand says how much of a value can reach an observable use (the return
  value or an effect):

    * `:absent` — none of it: the value is never used;
    * `{:used, fields}` — the value is used (inspected: matched, type-tested,
      read), and of its fields only those in `fields` may be used further.
      `fields` maps a literal key — an atom map key or struct field, or a
      0-based tuple index — to the demand on that field. A key mapped to
      `:absent` was examined (a pattern required it) but its value is never
      used. `{:used, %{}}` is a value used for its shape alone;
    * `:all` — all of it may be used.

  The order is `:absent` < `{:used, fields}` < `:all`, and between two
  `{:used, _}` pointwise (a missing key is `:absent`). `join/2` is the least
  upper bound. Field demands nest at most 3 levels: `bound/1` turns a
  `{:used, _}` deeper than that into `:all`, which over-approximates use, so
  the lattice has finite height for a finite set of keys and every fixpoint
  over it terminates.
  """

  @depth 3

  @type key :: atom() | non_neg_integer()
  @type t :: :absent | :all | {:used, %{key() => t()}}

  @doc "Nothing of the value is used."
  @spec absent() :: t()
  def absent, do: :absent

  @doc "All of the value may be used."
  @spec all() :: t()
  def all, do: :all

  @doc "The demand on field `key` of a value whose demand is `demand`."
  @spec at(t(), key()) :: t()
  def at(:absent, _key), do: :absent
  def at(:all, _key), do: :all
  def at({:used, fields}, key), do: Map.get(fields, key, :absent)

  @doc """
  `demand` cut at the depth bound: a `{:used, _}` nested deeper than #{@depth}
  levels of fields becomes `:all`.
  """
  @spec bound(t()) :: t()
  def bound(demand), do: bound(demand, @depth)

  @doc "The maximum nesting of field demands `bound/1` keeps."
  @spec depth() :: pos_integer()
  def depth, do: @depth

  @doc "The value is used, and of its fields only `key`, with demand `demand`."
  @spec field(key(), t()) :: t()
  def field(key, demand), do: bound({:used, %{key => demand}})

  @doc "The least demand above both."
  @spec join(t(), t()) :: t()
  def join(:absent, other), do: other
  def join(other, :absent), do: other
  def join(:all, _other), do: :all
  def join(_other, :all), do: :all

  def join({:used, left}, {:used, right}),
    do: bound({:used, Map.merge(left, right, fn _key, l, r -> join(l, r) end)})

  @doc "The join of every demand in `demands` (`:absent` for none)."
  @spec joins([t()]) :: t()
  def joins(demands), do: Enum.reduce(demands, :absent, &join/2)

  @doc "Whether `left` is at or below `right` in the order."
  @spec leq?(t(), t()) :: boolean()
  def leq?(:absent, _right), do: true
  def leq?(_left, :all), do: true
  def leq?(_left, :absent), do: false
  def leq?(:all, _right), do: false

  def leq?({:used, left}, {:used, right}),
    do:
      left
      |> :maps.to_list()
      |> Enum.all?(fn {key, d} -> leq?(d, Map.get(right, key, :absent)) end)

  @doc "A value used for its shape alone (a type test), none of its fields."
  @spec shape() :: t()
  def shape, do: {:used, %{}}

  @doc "Whether any of the value is used."
  @spec used?(t()) :: boolean()
  def used?(demand), do: demand != :absent

  # `fields` may hold the key `:__struct__` (a struct pattern), so it is read
  # with `:maps`, never through `Enumerable`, which would take it for a struct.
  defp bound({:used, _fields}, 0), do: :all

  defp bound({:used, fields}, depth),
    do: {:used, :maps.map(fn _key, demand -> bound(demand, depth - 1) end, fields)}

  defp bound(demand, _depth), do: demand
end
