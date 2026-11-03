defmodule AnchorFixtures.Sabotage.Canary do
  # DND-5471: the compile canary. One function per sabotage operator, a
  # nested module and a function with a default argument. Every mutant the
  # generator emits of these functions must compile with zero warnings
  # (test/anchor/domain/sabotage/mutator_compile_test.exs). Not compiled by
  # the project: test/fixtures is outside elixirc_paths.
  @moduledoc false

  require Logger

  alias URI, as: Link

  @limit 10

  def statements(x) do
    validate(x)
    y = double(x)
    Logger.info("doubled")
    y + 1
  end

  def checked(x) do
    true = is_integer(x)
    x + 1
  end

  def effects(pid, x) do
    send(pid, {:value, x})
    Logger.debug("sent")
    x
  end

  def classify(:small), do: 1
  def classify(n) when is_integer(n) and n > @limit, do: 2
  def classify(_other), do: 3

  def unwrap(result) do
    case result do
      {:ok, value} -> value
      {:error, reason} -> {:failed, reason}
    end
  end

  def pipeline(id, lookup) do
    with {:ok, user} <- lookup.(id),
         %URI{host: host} <- URI.parse(user) do
      host
    else
      _error -> nil
    end
  end

  def decide(x, flag) do
    if x > @limit do
      x * 2
    else
      {x, flag}
    end
  end

  def grade(score) do
    cond do
      score > 90 -> :a
      score > 50 -> :b
      true -> :c
    end
  end

  def pick(a, b) when is_integer(b), do: a + b
  def pick(a, _b), do: a

  def scaled(x, factor \\ 2) do
    x * factor
  end

  def bits(<<head::binary-size(1), _rest::binary>>, y), do: {head, y}

  def limited(@limit, y), do: y + 1

  def counted(x) do
    loop(x)
    x
  end

  def host(%Link{} = link) do
    _ = Link.to_string(link)
    link.host
  end

  def logged(x) do
    y = x + 1
    Logger.info(y)
    x
  end

  def remembered(x) do
    previous = Process.put(:anchor_canary, x)
    {x, previous}
  end

  defp double(x), do: x * 2

  defp loop(0), do: :done
  defp loop(n), do: loop(n - 1)

  defp validate(x) when is_integer(x), do: :ok
  defp validate(_x), do: :error

  defmodule Nested do
    @moduledoc false

    def twice(x) do
      y = x + x
      send(self(), :twice)
      y
    end
  end
end
