defmodule Anchor.Domain.Cfa.Value do
  @moduledoc """
  The abstract value of the 0-CFA (`Anchor.Domain.Cfa`) — **Domain**, pure
  (DND-5497).

  A value is `{closures, any?, constant?, allocs}`:

    * `closures` — the closure ids it may be;
    * `any?` — a value from outside the analysed world may be it;
    * `constant?` — an atom or another constant may be it (an atom is a module
      that a `s.f` dot-call could name); a field read from a constant is a
      constant;
    * `allocs` — the project containers it may be, by allocation site
      (`{:alloc, mfa, ordinal}`, `Anchor.Domain.Core.label/1`). A field read
      sees the slots of these allocation sites only, so a value that is no
      container (a dead branch's result) reads nothing.

  The order is the product order, so `join/2` is a union per component.
  `present/1` is what a site reports: `:any` when `any?` is set (any absorbs
  at the report; the closures beside it still flow), else `{:ok, closures}`.
  """

  @type alloc :: {:alloc, mfa(), non_neg_integer()}
  @type t :: {MapSet.t(), boolean(), boolean(), MapSet.t(alloc())}

  @doc "Nothing: no closure, nothing from outside."
  @spec bottom() :: t()
  def bottom, do: {MapSet.new(), false, false, MapSet.new()}

  @doc "A value from outside the analysed world."
  @spec any() :: t()
  def any, do: {MapSet.new(), true, false, MapSet.new()}

  @doc "An atom, or another constant (a literal that holds no fun, a number, a pid)."
  @spec constant() :: t()
  def constant, do: {MapSet.new(), false, true, MapSet.new()}

  @doc "The value that is one of `closures`."
  @spec closures(Enumerable.t()) :: t()
  def closures(closures), do: {MapSet.new(closures), false, false, MapSet.new()}

  @doc """
  The container built at `alloc`; `outside` is the value it was built on (a
  map update's base), whose outside part it keeps.
  """
  @spec container(alloc(), t()) :: t()
  def container(alloc, outside), do: {MapSet.new(), any?(outside), false, MapSet.new([alloc])}

  @doc "The closures `value` may be."
  @spec closure_set(t()) :: MapSet.t()
  def closure_set({closures, _any?, _constant?, _allocs}), do: closures

  @doc "The allocation sites `value` may be."
  @spec allocs(t()) :: MapSet.t(alloc())
  def allocs({_closures, _any?, _constant?, allocs}), do: allocs

  @doc "Whether a value from outside may be `value`."
  @spec any?(t()) :: boolean()
  def any?({_closures, any?, _constant?, _allocs}), do: any?

  @doc "Whether a constant (an atom: a module name, perhaps) may be `value`."
  @spec constant?(t()) :: boolean()
  def constant?({_closures, _any?, constant?, _allocs}), do: constant?

  @doc "The least value above both."
  @spec join(t(), t()) :: t()
  def join({c1, a1, t1, k1}, {c2, a2, t2, k2}),
    do: {MapSet.union(c1, c2), a1 or a2, t1 or t2, MapSet.union(k1, k2)}

  @doc "The join of every value in `values` (bottom for none)."
  @spec joins([t()]) :: t()
  def joins(values), do: Enum.reduce(values, bottom(), &join/2)

  @doc """
  What a read from `container` gives beyond its slots: `any` when it may come
  from outside, a constant when it may be a constant.
  """
  @spec outside(t()) :: t()
  def outside(container), do: {MapSet.new(), any?(container), constant?(container), MapSet.new()}

  @doc "The report of `value`: `:any`, or `{:ok, closures}`."
  @spec present(t()) :: {:ok, MapSet.t()} | :any
  def present(value), do: if(any?(value), do: :any, else: {:ok, closure_set(value)})
end
