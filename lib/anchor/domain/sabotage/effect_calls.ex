defmodule Anchor.Domain.Sabotage.EffectCalls do
  @moduledoc """
  Whether a statement's call is an effect (DND-5471): a write, a send, a
  process call, a log, a file or system call. Pure **Domain**: it reads a
  quoted call, nothing else.

  The sabotage generator gives every non-final statement exactly one of two
  operators: `drop_effect_call` when its call (or the right side of its `=`)
  is an effect, `delete_statement` otherwise. Only the outermost call counts:
  `foo(Repo.insert(x))` is not an effect call, `x |> Repo.insert()` is (pipes
  are read as the call they desugar to).

  ## Defaults

    * `insert`, `insert!`, `update`, `update!`, `delete`, `delete!`,
      `insert_all`, `update_all`, `delete_all`, `insert_or_update`,
      `insert_or_update!` and `transaction` on any module whose last alias
      segment ends in `Repo` (`MyApp.Repo`, `Repo`; not `MyApp.Repository`);
    * `send/2` (bare or `Kernel.send/2`), `spawn` and `spawn_link` (bare or
      on `Kernel`), `GenServer.call/cast`, `Process.send/send_after/put/delete`;
    * `:ets.insert/insert_new/delete/delete_object/update_counter`;
    * `File.write/write!/rm/rm!/rm_rf/mkdir_p/mkdir_p!/cp/rename/touch`,
      `System.cmd`, every `Logger` call, `IO.puts/write`;
    * `Task.start/start_link/async`, `Phoenix.PubSub.broadcast/broadcast!`.

  Extra tokens (`Mutator.generate/4`'s `effect_calls:` option; the runner,
  DND-5473, brings the `.anchor.yml` key) use the
  `Anchor.Domain.FunctionRef` grammar (`"Notifier.push"`,
  `"Notifier.push/1"`, `":gen_tcp.send/2"`). A token that does not parse
  raises `ArgumentError` with the grammar's message: a misspelt token must not
  silently classify nothing.
  """

  alias Anchor.Domain.DataFlow.Forms
  alias Anchor.Domain.FunctionRef

  @repo_functions ~w(insert insert! update update! delete delete! insert_all update_all
                     delete_all insert_or_update insert_or_update! transaction)a

  # Keyed by the module as written (alias segments, or the Erlang atom), so
  # this Domain module names no module it may not depend on.
  @remote %{
    [:GenServer] => [:call, :cast],
    [:Process] => [:send, :send_after, :put, :delete],
    [:File] => [:write, :write!, :rm, :rm!, :rm_rf, :mkdir_p, :mkdir_p!, :cp, :rename, :touch],
    [:System] => [:cmd],
    [:IO] => [:puts, :write],
    [:Task] => [:start, :start_link, :async],
    [:Phoenix, :PubSub] => [:broadcast, :broadcast!],
    [:Kernel] => [:spawn, :spawn_link],
    [:ets] => [:insert, :insert_new, :delete, :delete_object, :update_counter]
  }

  @spec effect?(Macro.t(), [String.t()]) :: boolean()
  def effect?(call_ast, extra_tokens) when is_list(extra_tokens) do
    refs = Enum.map(extra_tokens, &parse_token!/1)

    case call_ast |> Forms.desugar_pipes() |> call_parts() do
      {:remote, module, segments, fun, arity} ->
        default_remote?(segments, fun, arity) or
          Enum.any?(refs, &FunctionRef.matches?(&1, module, fun, arity))

      {:local, fun, arity} ->
        default_local?(fun, arity)

      :none ->
        false
    end
  end

  defp call_parts({{:., _dmeta, [{:__aliases__, _ameta, segments}, fun]}, _meta, args})
       when is_atom(fun) and is_list(args) and is_list(segments) do
    if Enum.all?(segments, &is_atom/1),
      do: {:remote, Module.concat(segments), segments, fun, length(args)},
      else: :none
  end

  defp call_parts({{:., _dmeta, [module, fun]}, _meta, args})
       when is_atom(module) and is_atom(fun) and is_list(args),
       do: {:remote, module, [module], fun, length(args)}

  defp call_parts({fun, _meta, args}) when is_atom(fun) and is_list(args),
    do: {:local, fun, length(args)}

  defp call_parts(_other), do: :none

  defp default_local?(:send, 2), do: true
  defp default_local?(fun, _arity) when fun in [:spawn, :spawn_link], do: true
  defp default_local?(_fun, _arity), do: false

  defp default_remote?([:Logger], _fun, _arity), do: true
  defp default_remote?([:Kernel], :send, arity), do: arity == 2

  defp default_remote?(segments, fun, _arity) do
    (repo?(segments) and fun in @repo_functions) or fun in Map.get(@remote, segments, [])
  end

  defp parse_token!(token) do
    case FunctionRef.parse(token) do
      {:ok, ref} -> ref
      {:error, message} -> raise ArgumentError, "sabotage effect_calls: " <> message
    end
  end

  defp repo?(segments) do
    case List.last(segments) do
      last when is_atom(last) -> last |> Atom.to_string() |> String.ends_with?("Repo")
      _other -> false
    end
  end
end
