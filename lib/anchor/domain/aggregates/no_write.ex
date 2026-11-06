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
  for a module that also runs code or sends a message (`:erlang`, `Kernel`,
  `Application`, `Process`, `System`) only the functions that do not. It holds
  nothing that hands work to another process (`GenServer`, `Task`, `Agent`):
  those are gaps. It grew from the unread count by callee over gen_saas, measured
  in CI (the JSON's `writes.unread_by_callee`); no test holds a number.

  A framework's own modules (Phoenix, Plug) are not here. Whether they can reach a
  project's repo is the project's call, under `aggregates.no_write_modules`.

  `aggregates.no_write_modules` adds a project's own assumptions, whole modules.
  """

  # Pure data transformation over values given to them; no process, no I/O. A
  # project's Enumerable, String.Chars or Inspect impl runs inside them, and a
  # write there is a write in that impl, read where it is defined.
  @pure_modules [
    Access,
    Atom,
    Base,
    Calendar,
    Collectable,
    Date,
    DateTime,
    Enum,
    Enumerable,
    Float,
    Inspect,
    Inspect.Algebra,
    Inspect.Any,
    Integer,
    JSON,
    Jason,
    Jason.Encode,
    Jason.OrderedObject,
    Keyword,
    List,
    Macro,
    Map,
    MapSet,
    Module,
    NaiveDateTime,
    Path,
    Range,
    Regex,
    String,
    String.Chars,
    Time,
    Tuple,
    URI,
    :binary,
    :crypto,
    :lists,
    :maps,
    :rand,
    :re,
    :unicode
  ]

  # Build the exception a `raise` raises: a struct, and the raise never returns.
  # A project's own exception is a project function, followed.
  @exception_modules [
    ArgumentError,
    ArithmeticError,
    CaseClauseError,
    CompileError,
    Exception,
    FunctionClauseError,
    KeyError,
    MatchError,
    RuntimeError,
    UndefinedFunctionError
  ]

  # What the compiler leaves in Core. `elixir_quote` builds a quoted expression as a
  # value, `Kernel.Utils` raises from a macro, and `elixir_erl_pass` is `value.field`
  # on what is not known to be a map: a map's field, or, deprecated since Elixir
  # 1.17 and warned about at run time, a zero-arity call on a module held in a
  # variable. That one call is the entry's assumption, as `value.field` is on nearly
  # every line of a project, and a `value.field()` with parentheses is a gap.
  @compiler_modules [Kernel.Utils, :elixir_erl_pass, :elixir_quote]

  # Log and print: a handler runs on the caller, and a handler that writes is the
  # project's own function, read where it is defined. `IO` talks to the group leader.
  @observe_modules [IO, Logger, :logger, :telemetry]

  # Build a changeset, a query or a UUID as a value. None touches a repo: writing one
  # is a `Repo` call, read as a write. A function handed to one (`prepare_changes`)
  # is a gap: WriteSites checks the arguments.
  @query_modules [
    Ecto.Changeset,
    Ecto.Query,
    Ecto.Query.API,
    Ecto.Query.Builder,
    Ecto.Query.Builder.CTE,
    Ecto.Query.Builder.Distinct,
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
    Ecto.Queryable,
    Ecto.UUID
  ]

  @modules MapSet.new(
             @pure_modules ++
               @exception_modules ++
               @compiler_modules ++
               @query_modules ++
               @observe_modules
           )

  # What a macro or an operator compiles to, plus raising and reading the clock: pure,
  # or it never returns.
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
                      :function_exported,
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
                      :monotonic_time,
                      :nif_error,
                      :node,
                      :not,
                      :or,
                      :orelse,
                      :phash2,
                      :raise,
                      :rem,
                      :round,
                      :self,
                      :setelement,
                      :size,
                      :system_time,
                      :throw,
                      :tl,
                      :trunc,
                      :tuple_size,
                      :tuple_to_list,
                      :unique_integer,
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
                      :update_in,
                      :=~
                    ])

  # This node's own state, read or set: the environment, the process dictionary, the
  # clock. Not `Application.ensure_all_started`, `Process.send` or `System.cmd`.
  @application_functions MapSet.new([:fetch_env, :fetch_env!, :get_all_env, :get_env])
  @process_functions MapSet.new([:delete, :get, :info, :put, :sleep])
  @system_functions MapSet.new([
                      :fetch_env,
                      :fetch_env!,
                      :get_env,
                      :monotonic_time,
                      :os_time,
                      :system_time,
                      :unique_integer
                    ])

  @functions %{
    :erlang => @erlang_functions,
    Application => @application_functions,
    Kernel => @kernel_functions,
    Process => @process_functions,
    System => @system_functions
  }

  # A function given as the default comes back as a value: nothing here runs it, and
  # project code that runs it is a gap of its own, at that call.
  @given_back MapSet.new([{Keyword, :get, 3}, {Map, :get, 3}])

  @doc """
  Whether a call of `{module, name, arity}` is cleared: the built-in list, or
  `module` among `listed` (`aggregates.no_write_modules`).
  """
  @spec member?(mfa(), [module()]) :: boolean()
  def member?({module, name, _arity}, listed) do
    case @functions do
      %{^module => functions} -> MapSet.member?(functions, name) or module in listed
      _whole_modules -> MapSet.member?(@modules, module) or module in listed
    end
  end

  @doc "Whether `mfa` only hands back a function it is given, and never runs it."
  @spec gives_back?(mfa()) :: boolean()
  def gives_back?(mfa), do: MapSet.member?(@given_back, mfa)
end
