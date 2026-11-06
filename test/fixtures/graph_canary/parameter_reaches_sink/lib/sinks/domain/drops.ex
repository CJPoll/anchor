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

  # Violating once: the first parameter of drop_first/2. The head the default
  # generates, drop_first/1, passes its one parameter there, so it is absent
  # too, but no author wrote it to drop it.
  def drop_first(_unused, n \\ :none), do: n

  # An ordinary three-argument call on this module silences nothing here.
  def asks(msg, timeout), do: GenServer.call(__MODULE__, msg, timeout)

  # An ordinary call with a literal message and a variable third argument too: the
  # message's name is no reference. ping/2 drops its first parameter.
  def ping(_unused, timeout), do: GenServer.call(__MODULE__, :ping, timeout)

  # Violating, and a false finding this rule cannot rule out: an MFA held in
  # variables names no function. The README says to check these by hand.
  def spawned_mod(mod, x), do: spawn(mod, :via_var, [x])
  def via_var(_x), do: :ok

  # Violating: nothing here calls it, but this is how a controller action reads. A
  # caller's `apply(__MODULE__, action, [conn, params])` names no target, so an action
  # stays judged, and the README says to check those by hand.
  def index(_params), do: :ok

  # Violating: a lambda that ignores what it is applied to.
  def via_lambda(unused) do
    ignore = fn _value -> :ok end
    ignore.(unused)
  end
end
