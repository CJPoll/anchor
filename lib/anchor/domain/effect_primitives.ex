defmodule Anchor.Domain.EffectPrimitives do
  @moduledoc """
  The library calls whose arguments reach the world outside the program —
  **Domain**, pure data (DND-5498; shared with DND-5447, which reads the same
  table for effect inference).

  Keyed by the callee as Core names it, `{module, function, arity}`: Elixir
  inlines some calls before Core (`Kernel.send/2` is `erlang:send/2`), so a
  row names the spelling Core holds, and both spellings where both occur.

  Two kinds of row:

    * an **escape** (`escape?/1`): the value leaves the process or outlives
      the call: `send`, `spawn*`, `Task`, `Agent`, `GenServer` and
      `:gen_server` messages, ETS writes, `:persistent_term.put/2`, the
      process dictionary (`Process.put/2`, `erlang:put/2`);
    * any other **effect**: IO and `:io`, every `Logger` function (logging is
      an output: a parameter used only in a log line is used), file and
      system calls, a raise (`erlang:error/1,2,3`, `exit/1`, `throw/1`,
      `raise/3`: the exception carries its payload to the caller),
      `Phoenix.PubSub` broadcasts, `:telemetry.execute`, a `Repo` write (any
      module whose last name segment ends in `Repo`, as
      `Anchor.Domain.Sabotage.EffectCalls` reads it).

  Every argument of an effect is demanded in full. `effect?/2` also takes the
  extra tokens of `.anchor.yml`'s `architecture.effects`, in the grammar
  `Anchor.Domain.Architecture` accepts there: a module (`"Req"`,
  `":gen_tcp"`: every function of it) or a function
  (`Anchor.Domain.FunctionRef`: `"Notifier.push/1"`, `":gen_tcp.connect"`).
  `parse_extra!/1` refuses a token that is neither, so a misspelt token never
  classifies nothing.
  """

  alias Anchor.Domain.FunctionRef

  # Rows name modules as `.anchor.yml` tokens do (`"IO"`, `":ets"`), as
  # `Anchor.Domain.Sabotage.EffectCalls` keys them by name: this table compares
  # names and calls nothing.
  @escapes [
    {":erlang", :send, :*},
    {":erlang", :!, 2},
    {":erlang", :spawn, :*},
    {":erlang", :spawn_link, :*},
    {":erlang", :spawn_monitor, :*},
    {":erlang", :spawn_opt, :*},
    {":erlang", :send_after, :*},
    {":erlang", :put, 2},
    {"Process", :send, :*},
    {"Process", :send_after, :*},
    {"Process", :put, 2},
    {"Process", :spawn, :*},
    {"Kernel", :send, 2},
    {"Kernel", :spawn, :*},
    {"Kernel", :spawn_link, :*},
    {"Task", :*, :*},
    {"Task.Supervisor", :*, :*},
    {"Agent", :*, :*},
    {"GenServer", :call, :*},
    {"GenServer", :cast, :*},
    {"GenServer", :reply, 2},
    {"GenServer", :start, :*},
    {"GenServer", :start_link, :*},
    {":gen_server", :call, :*},
    {":gen_server", :cast, :*},
    {":gen_server", :reply, 2},
    {":gen_statem", :call, :*},
    {":gen_statem", :cast, :*},
    {":ets", :insert, 2},
    {":ets", :insert_new, 2},
    {":ets", :update_counter, :*},
    {":ets", :update_element, :*},
    {":ets", :delete, 2},
    {":ets", :delete_object, 2},
    {":ets", :new, 2},
    {":persistent_term", :put, 2}
  ]

  @effects [
    {":erlang", :error, :*},
    {":erlang", :exit, :*},
    {":erlang", :throw, 1},
    {":erlang", :raise, 3},
    {":erlang", :halt, :*},
    {":erlang", :open_port, 2},
    {":erlang", :port_command, :*},
    {":erlang", :erase, 1},
    {":erlang", :register, 2},
    {":erlang", :link, 1},
    {":erlang", :monitor, :*},
    {"Process", :delete, 1},
    {"Process", :exit, 2},
    {"Process", :register, 2},
    {"Process", :link, 1},
    {"Process", :monitor, :*},
    {"IO", :*, :*},
    {":io", :*, :*},
    {"Logger", :*, :*},
    {":logger", :*, :*},
    {"File", :write, :*},
    {"File", :write!, :*},
    {"File", :rm, :*},
    {"File", :rm!, :*},
    {"File", :rm_rf, :*},
    {"File", :rm_rf!, :*},
    {"File", :mkdir, :*},
    {"File", :mkdir!, :*},
    {"File", :mkdir_p, :*},
    {"File", :mkdir_p!, :*},
    {"File", :cp, :*},
    {"File", :cp!, :*},
    {"File", :cp_r, :*},
    {"File", :rename, :*},
    {"File", :rename!, :*},
    {"File", :touch, :*},
    {"File", :touch!, :*},
    {"File", :chmod, :*},
    {":file", :write_file, :*},
    {":file", :delete, :*},
    {":file", :write, 2},
    {"System", :cmd, :*},
    {"System", :halt, :*},
    {"System", :stop, :*},
    {"System", :put_env, :*},
    {":os", :cmd, :*},
    {":os", :putenv, 2},
    {"Phoenix.PubSub", :broadcast, :*},
    {"Phoenix.PubSub", :broadcast!, :*},
    {"Phoenix.PubSub", :broadcast_from, :*},
    {"Phoenix.PubSub", :broadcast_from!, :*},
    {":telemetry", :execute, :*}
  ]

  @repo_writes ~w(insert insert! update update! delete delete! insert_all update_all
                  delete_all insert_or_update insert_or_update! transaction)a

  @doc """
  The default rows, as `{kind, {module_name, function | :*, arity | :*}}`
  (`module_name/1`'s spelling), kind
  `:escape` or `:effect`; `:*` matches every function or arity. The `Repo`
  writes are a rule over module names, not rows: see the moduledoc.
  """
  @spec default() :: [{:escape | :effect, {String.t(), atom(), arity() | :*}}]
  def default,
    do: Enum.map(@escapes, &{:escape, &1}) ++ Enum.map(@effects, &{:effect, &1})

  @typedoc "A parsed extra token: every function of a module, or one function."
  @type extra :: {:module, String.t()} | FunctionRef.t()

  @doc """
  Whether a call of `mfa` is an effect: an escape, a default effect, a `Repo`
  write, or one of `extra` (parsed tokens, `parse_extra!/1`).
  """
  @spec effect?(mfa(), [extra()]) :: boolean()
  def effect?({module, function, arity} = mfa, extra) when is_list(extra) do
    escape?(mfa) or listed?(@effects, mfa) or repo_write?(module, function) or
      Enum.any?(extra, &extra_matches?(&1, module, function, arity))
  end

  @doc "Whether a call of `mfa` lets its arguments leave the process or outlive the call."
  @spec escape?(mfa()) :: boolean()
  def escape?(mfa), do: listed?(@escapes, mfa)

  @doc """
  The name a row or a module token gives `module`: `"IO"` for an Elixir
  module, `":ets"` for an Erlang one.
  """
  @spec module_name(module()) :: String.t()
  def module_name(module) do
    case Atom.to_string(module) do
      "Elixir." <> name -> name
      name -> ":" <> name
    end
  end

  @doc """
  Parses the extra effect tokens: a module (`"Req"`, `":gen_tcp"`) or a
  function (`"Notifier.push/1"`). Raises `ArgumentError` for the first token
  that is neither, with `Anchor.Domain.FunctionRef`'s message.
  """
  @spec parse_extra!([String.t()]) :: [extra()]
  def parse_extra!(tokens) when is_list(tokens), do: Enum.map(tokens, &parse_token!/1)

  defp parse_token!(token) do
    cond do
      FunctionRef.alias_name?(token) -> {:module, token}
      erlang_module_token?(token) -> {:module, token}
      true -> parse_function!(token)
    end
  end

  defp parse_function!(token) do
    case FunctionRef.parse(token) do
      {:ok, ref} -> ref
      {:error, reason} -> raise ArgumentError, reason
    end
  end

  defp erlang_module_token?(":" <> name), do: FunctionRef.erlang_module_name?(name)
  defp erlang_module_token?(_token), do: false

  defp extra_matches?({:module, name}, module, _function, _arity), do: module_name(module) == name

  defp extra_matches?(%FunctionRef{} = ref, module, function, arity),
    do: FunctionRef.matches?(ref, module, function, arity)

  defp listed?(rows, {module, function, arity}) do
    name = module_name(module)

    Enum.any?(rows, fn {m, f, a} ->
      m == name and f in [function, :*] and a in [arity, :*]
    end)
  end

  # An Erlang module (`:repo`) has no alias segments, so it is never a Repo.
  defp repo_write?(module, function) do
    name = Atom.to_string(module)

    function in @repo_writes and String.starts_with?(name, "Elixir.") and
      name |> String.split(".") |> List.last() |> String.ends_with?("Repo")
  end
end
