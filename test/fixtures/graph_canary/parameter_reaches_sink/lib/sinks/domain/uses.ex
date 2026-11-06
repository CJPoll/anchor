defmodule AnchorFixtures.ParameterSinks.Order do
  defstruct [:id, :total]
end

defmodule AnchorFixtures.ParameterSinks.Uses do
  alias AnchorFixtures.ParameterSinks.Order

  # Positive control for price/2.
  def plain(a), do: a + 1

  # Matching a parameter is a decision, which is a use.
  def pattern(:a, x), do: x
  def pattern(:b, x), do: x

  # A guard reads y.
  def guarded(x, y) when is_atom(y), do: x

  # An unresolved apply demands what is passed to it.
  def applied(mod, fun, p), do: apply(mod, fun, [p])

  # A closure from outside: the apply site falls to any, and uses p.
  def invoked(fun, p), do: fun.(p)

  # send is an effect, and an escape.
  def sent(pid, p), do: send(pid, p)

  # A field of a struct is enough.
  def field(%Order{id: id}), do: id

  # Passed on to something that uses it: no drop.
  def forwards(x), do: plain(x)
end
