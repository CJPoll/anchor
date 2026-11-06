defmodule AnchorFixtures.ParameterSinks.Drops do
  # Violating: an underscore name is no exemption.
  def price(order, _opts), do: order

  # Violating: b is passed to g/1, which drops it. One issue per level.
  def f(a, b) do
    g(b)
    a
  end

  def g(_x), do: :ok

  # Violating: recursion that only passes x to itself reaches nothing.
  def count(_x, 0), do: 0
  def count(x, n), do: count(x, n - 1)

  # Violating: only count/2's first parameter is dropped here; the default's
  # generated head count_from/1 is not a second issue.
  def count_from(n, _unused \\ :none), do: n

  # Violating: a lambda that ignores what it is applied to.
  def via_lambda(unused) do
    ignore = fn _value -> :ok end
    ignore.(unused)
  end
end
