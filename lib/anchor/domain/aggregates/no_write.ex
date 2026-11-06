defmodule Anchor.Domain.Aggregates.NoWrite do
  @moduledoc """
  The dependency calls the write analysis clears without reading them
  (DND-5889) — a **Domain** module (ADR 001), pure data. A call into a module
  outside the project is not followed, so `Anchor.Domain.Aggregates.WriteSites`
  makes it a gap at its line unless `member?/2` says it cannot reach a database
  connection.

  The list is the declared assumption of the default: a module on it that does
  write is missed. So a listed call is counted in the run's summary, it never
  reads as a proof, and an entry says why it cannot write. It holds modules, and
  for `:erlang` and `Kernel` the functions: both also hold what runs code or
  sends a message (`:erlang.send/2`, `Kernel.spawn/1`). It holds nothing that
  hands work to another process (`GenServer`, `Task`, `Agent`): those are gaps.

  `aggregates.no_write_modules` adds a project's own assumptions, whole modules.
  """

  # Pure data transformation over values given to them; no process, no I/O. A
  # project's Enumerable, String.Chars or Inspect impl runs inside them, and a
  # write there is a write in that impl, read where it is defined.
  @pure_modules [
    Access,
    Atom,
    Collectable,
    Enum,
    Enumerable,
    Float,
    Integer,
    Inspect,
    Keyword,
    List,
    Map,
    MapSet,
    String,
    String.Chars,
    Tuple,
    :lists,
    :maps
  ]

  # Build a changeset or a query as a value. Neither touches a repo: writing one
  # is a `Repo` call, read as a write. A function handed to one (`prepare_changes`)
  # is a gap: WriteSites checks the arguments.
  @query_modules [
    Ecto.Changeset,
    Ecto.Query,
    Ecto.Query.API,
    Ecto.Query.Builder,
    Ecto.Query.Builder.Dynamic,
    Ecto.Query.Builder.Filter,
    Ecto.Query.Builder.From,
    Ecto.Query.Builder.GroupBy,
    Ecto.Query.Builder.Join,
    Ecto.Query.Builder.LimitOffset,
    Ecto.Query.Builder.Lock,
    Ecto.Query.Builder.OrderBy,
    Ecto.Query.Builder.Preload,
    Ecto.Query.Builder.Select,
    Ecto.Query.Builder.Update,
    Ecto.Queryable
  ]

  # Log and measure: handlers run on the caller, and a handler that writes is the
  # project's own function, read where it is defined.
  @observe_modules [Logger, :logger, :telemetry]

  @modules MapSet.new(@pure_modules ++ @query_modules ++ @observe_modules)

  # What a macro or an operator compiles to, plus raising: pure, or it never returns.
  @erlang_functions MapSet.new([
                      :*,
                      :+,
                      :++,
                      :-,
                      :--,
                      :/,
                      :"/=",
                      :<,
                      :"=/=",
                      :"=:=",
                      :"=<",
                      :==,
                      :>,
                      :>=,
                      :abs,
                      :and,
                      :andalso,
                      :atom_to_binary,
                      :atom_to_list,
                      :band,
                      :binary_part,
                      :binary_to_atom,
                      :binary_to_existing_atom,
                      :binary_to_float,
                      :binary_to_integer,
                      :binary_to_list,
                      :bit_size,
                      :bnot,
                      :bor,
                      :bsl,
                      :bsr,
                      :bxor,
                      :byte_size,
                      :ceil,
                      :div,
                      :element,
                      :error,
                      :exit,
                      :float,
                      :float_to_binary,
                      :floor,
                      :get_module_info,
                      :hd,
                      :integer_to_binary,
                      :integer_to_list,
                      :iolist_size,
                      :iolist_to_binary,
                      :is_atom,
                      :is_binary,
                      :is_bitstring,
                      :is_boolean,
                      :is_float,
                      :is_function,
                      :is_integer,
                      :is_list,
                      :is_map,
                      :is_map_key,
                      :is_number,
                      :is_pid,
                      :is_port,
                      :is_record,
                      :is_reference,
                      :is_tuple,
                      :length,
                      :list_to_atom,
                      :list_to_binary,
                      :list_to_existing_atom,
                      :list_to_integer,
                      :list_to_tuple,
                      :make_tuple,
                      :map_get,
                      :map_size,
                      :max,
                      :min,
                      :nif_error,
                      :node,
                      :not,
                      :or,
                      :orelse,
                      :raise,
                      :rem,
                      :round,
                      :self,
                      :setelement,
                      :size,
                      :throw,
                      :tl,
                      :trunc,
                      :tuple_size,
                      :tuple_to_list,
                      :xor
                    ])

  # Kernel's functions that survive to Core (its macros and inlined functions are
  # gone by then): data only. `apply`, `spawn*` and `send` are not here.
  @kernel_functions MapSet.new([
                      :get_and_update_in,
                      :get_in,
                      :inspect,
                      :make_ref,
                      :pop_in,
                      :put_in,
                      :struct,
                      :struct!,
                      :update_in
                    ])

  @doc """
  Whether a call of `{module, name, arity}` is cleared: the built-in list, or
  `module` among `listed` (`aggregates.no_write_modules`).
  """
  @spec member?(mfa(), [module()]) :: boolean()
  def member?({:erlang, name, _arity}, listed),
    do: MapSet.member?(@erlang_functions, name) or :erlang in listed

  def member?({Kernel, name, _arity}, listed),
    do: MapSet.member?(@kernel_functions, name) or Kernel in listed

  def member?({module, _name, _arity}, listed),
    do: MapSet.member?(@modules, module) or module in listed
end
