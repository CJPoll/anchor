defmodule AnchorFixtures.ParameterSinks.Server do
  use GenServer

  # A behaviour fixes the signature.
  @impl GenServer
  def init(_arg), do: {:ok, %{}}

  @impl GenServer
  def handle_call(msg, _from, state), do: {:reply, msg, state}
end

defmodule AnchorFixtures.ParameterSinks.Port do
  @callback fetch(id :: term(), opts :: term()) :: term()
end

defmodule AnchorFixtures.ParameterSinks.Impl do
  @behaviour AnchorFixtures.ParameterSinks.Port

  # A project behaviour fixes it too.
  @impl AnchorFixtures.ParameterSinks.Port
  def fetch(id, _opts), do: id
end

defmodule AnchorFixtures.ParameterSinks.Captures do
  # The consumer of a capture fixes the arity.
  def run(xs), do: Enum.reduce(xs, [], &fmt/2)

  defp fmt(x, _acc), do: [x]
end

defmodule AnchorFixtures.ParameterSinks.Receiver do
  # A call on a variable module can reach this: the caller fixes the arity.
  def handle_it(x, _context), do: x
end

defmodule AnchorFixtures.ParameterSinks.Dynamic do
  def call(mod, x), do: mod.handle_it(x, :context)
end

defmodule AnchorFixtures.ParameterSinks.Macros do
  defmacro __using__(_opts) do
    quote do
      # A macro wrote this: the module's author cannot drop the parameter.
      def injected(a, _b), do: a
    end
  end
end

defmodule AnchorFixtures.ParameterSinks.UsesMacro do
  use AnchorFixtures.ParameterSinks.Macros

  def own(a), do: a
end
