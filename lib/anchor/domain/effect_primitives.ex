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
  extra tokens of `.anchor.yml`'s `architecture.effects`, parsed with
  `Anchor.Domain.FunctionRef` (`"Notifier.push/1"`); `parse_extra!/1` refuses
  a token that does not parse, so a misspelt token never classifies nothing.
  """

  alias Anchor.Domain.FunctionRef

  @escapes [
    {:erlang, :send, :*},
    {:erlang, :!, 2},
    {:erlang, :spawn, :*},
    {:erlang, :spawn_link, :*},
    {:erlang, :spawn_monitor, :*},
    {:erlang, :spawn_opt, :*},
    {:erlang, :send_after, :*},
    {:erlang, :put, 2},
    {Process, :send, :*},
    {Process, :send_after, :*},
    {Process, :put, 2},
    {Process, :spawn, :*},
    {Kernel, :send, 2},
    {Kernel, :spawn, :*},
    {Kernel, :spawn_link, :*},
    {Task, :*, :*},
    {Task.Supervisor, :*, :*},
    {Agent, :*, :*},
    {GenServer, :call, :*},
    {GenServer, :cast, :*},
    {GenServer, :reply, 2},
    {GenServer, :start, :*},
    {GenServer, :start_link, :*},
    {:gen_server, :call, :*},
    {:gen_server, :cast, :*},
    {:gen_server, :reply, 2},
    {:gen_statem, :call, :*},
    {:gen_statem, :cast, :*},
    {:ets, :insert, 2},
    {:ets, :insert_new, 2},
    {:ets, :update_counter, :*},
    {:ets, :update_element, :*},
    {:ets, :delete, 2},
    {:ets, :delete_object, 2},
    {:ets, :new, 2},
    {:persistent_term, :put, 2}
  ]

  # `File` and `System` are written as atoms: Anchor's own `.anchor.yml` bars
  # a Domain module from naming them (this table only compares names).
  @effects [
    {:erlang, :error, :*},
    {:erlang, :exit, :*},
    {:erlang, :throw, 1},
    {:erlang, :raise, 3},
    {:erlang, :halt, :*},
    {:erlang, :open_port, 2},
    {:erlang, :port_command, :*},
    {:erlang, :erase, 1},
    {:erlang, :register, 2},
    {:erlang, :link, 1},
    {:erlang, :monitor, :*},
    {Process, :delete, 1},
    {Process, :exit, 2},
    {Process, :register, 2},
    {Process, :link, 1},
    {Process, :monitor, :*},
    {IO, :*, :*},
    {:io, :*, :*},
    {Logger, :*, :*},
    {:logger, :*, :*},
    {:"Elixir.File", :write, :*},
    {:"Elixir.File", :write!, :*},
    {:"Elixir.File", :rm, :*},
    {:"Elixir.File", :rm!, :*},
    {:"Elixir.File", :rm_rf, :*},
    {:"Elixir.File", :rm_rf!, :*},
    {:"Elixir.File", :mkdir, :*},
    {:"Elixir.File", :mkdir!, :*},
    {:"Elixir.File", :mkdir_p, :*},
    {:"Elixir.File", :mkdir_p!, :*},
    {:"Elixir.File", :cp, :*},
    {:"Elixir.File", :cp!, :*},
    {:"Elixir.File", :cp_r, :*},
    {:"Elixir.File", :rename, :*},
    {:"Elixir.File", :rename!, :*},
    {:"Elixir.File", :touch, :*},
    {:"Elixir.File", :touch!, :*},
    {:"Elixir.File", :chmod, :*},
    {:file, :write_file, :*},
    {:file, :delete, :*},
    {:file, :write, 2},
    {:"Elixir.System", :cmd, :*},
    {:"Elixir.System", :halt, :*},
    {:"Elixir.System", :stop, :*},
    {:"Elixir.System", :put_env, :*},
    {:os, :cmd, :*},
    {:os, :putenv, 2},
    {Phoenix.PubSub, :broadcast, :*},
    {Phoenix.PubSub, :broadcast!, :*},
    {Phoenix.PubSub, :broadcast_from, :*},
    {Phoenix.PubSub, :broadcast_from!, :*},
    {:telemetry, :execute, :*}
  ]

  @repo_writes ~w(insert insert! update update! delete delete! insert_all update_all
                  delete_all insert_or_update insert_or_update! transaction)a

  @doc """
  The default rows, as `{kind, {module, function | :*, arity | :*}}`, kind
  `:escape` or `:effect`; `:*` matches every function or arity. The `Repo`
  writes are a rule over module names, not rows: see the moduledoc.
  """
  @spec default() :: [{:escape | :effect, {module(), atom(), arity() | :*}}]
  def default,
    do: Enum.map(@escapes, &{:escape, &1}) ++ Enum.map(@effects, &{:effect, &1})

  @doc """
  Whether a call of `mfa` is an effect: an escape, a default effect, a `Repo`
  write, or one of `extra` (parsed tokens, `parse_extra!/1`).
  """
  @spec effect?(mfa(), [FunctionRef.t()]) :: boolean()
  def effect?({module, function, arity} = mfa, extra) when is_list(extra) do
    escape?(mfa) or listed?(@effects, mfa) or repo_write?(module, function) or
      Enum.any?(extra, &FunctionRef.matches?(&1, module, function, arity))
  end

  @doc "Whether a call of `mfa` lets its arguments leave the process or outlive the call."
  @spec escape?(mfa()) :: boolean()
  def escape?(mfa), do: listed?(@escapes, mfa)

  @doc """
  Parses the extra effect tokens, raising `ArgumentError` with
  `Anchor.Domain.FunctionRef`'s message for the first that does not parse.
  """
  @spec parse_extra!([String.t()]) :: [FunctionRef.t()]
  def parse_extra!(tokens) when is_list(tokens) do
    Enum.map(tokens, fn token ->
      case FunctionRef.parse(token) do
        {:ok, ref} -> ref
        {:error, reason} -> raise ArgumentError, reason
      end
    end)
  end

  defp listed?(rows, {module, function, arity}) do
    Enum.any?(rows, fn {m, f, a} ->
      m == module and f in [function, :*] and a in [arity, :*]
    end)
  end

  # An Erlang module (`:repo`) has no alias segments, so it is never a Repo.
  defp repo_write?(module, function) do
    name = Atom.to_string(module)

    function in @repo_writes and String.starts_with?(name, "Elixir.") and
      name |> String.split(".") |> List.last() |> String.ends_with?("Repo")
  end
end
