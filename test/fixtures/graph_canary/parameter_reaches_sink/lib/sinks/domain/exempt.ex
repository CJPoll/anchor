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

defmodule AnchorFixtures.ParameterSinks.Started do
  # A literal MFA names these: the args list fixes the arity, whoever runs it.
  def child_spec(arg), do: %{id: __MODULE__, start: {__MODULE__, :start_link, [arg]}}
  def start_link(_opts), do: {:ok, self()}

  def spawned(x), do: spawn(__MODULE__, :worker, [x])
  def worker(_x), do: :ok

  # The args are not literal: every arity of the name is in reach.
  def spawned_any(args), do: spawn(__MODULE__, :any_arity, args)
  def any_arity(_x), do: :ok
  def any_arity(_x, _y), do: :ok

  # A literal term holds an MFA too.
  def literal_spec, do: {__MODULE__, :literal_target, [:fixed]}
  def literal_target(_x), do: :ok
end

defmodule AnchorFixtures.ParameterSinks.Computed do
  # A computed name: the rule cannot see its target, and counts it.
  def dispatch(action, x), do: apply(__MODULE__, action, [x])
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
