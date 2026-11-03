defmodule Anchor.Domain.PureCalls do
  @moduledoc """
  The library calls the absence analysis (`Anchor.Domain.Demand`) reads as
  pure — **Domain**, pure data (DND-5498, requirement R4).

  A pure call's arguments matter only through its result: when its result is
  used they are used in full, and when it is not they are not. Every other
  library call that is not an effect (`Anchor.Domain.EffectPrimitives`) uses
  its arguments in full and makes the calling function imprecise.

  Two kinds of row:

    * a whole module whose functions take values and return values: `Enum`,
      `List`, `Map`, `Keyword`, `String`, `Integer`, `Float`, `Tuple`,
      `Atom`, `MapSet`, `Range`, `Bitwise`, `Base`, `Regex`, `URI`,
      `Version`, `:lists`, `:maps`, `:string`, `:binary`, `:math`,
      `:unicode`, `:proplists`, `:orddict`, `:ordsets`, `:sets`, `:gb_trees`,
      `:gb_sets`, `:queue`. A function that calls one of its arguments
      (`Anchor.Domain.HigherOrder`: `Enum.map/2`, `Map.update/4`) is never
      pure here: what it calls may have effects;
    * an `:erlang` BIF from `@erlang`: arithmetic, comparison, type tests,
      tuple, list and binary building and reading, conversions.

  A function that reads the clock, the environment or the file system
  (`DateTime.utc_now/0`, `Path.expand/1`) is not here. Neither is a protocol
  call that may run project code (`Kernel.inspect/2`, `String.Chars`). `Enum`
  on a struct that implements `Enumerable` with an effect is a known gap: the
  table reads every `Enum` function as pure.
  """

  alias Anchor.Domain.HigherOrder

  @modules [
    Atom,
    Base,
    Bitwise,
    Enum,
    Float,
    Integer,
    Keyword,
    List,
    Map,
    MapSet,
    Range,
    Regex,
    String,
    Tuple,
    URI,
    Version,
    :binary,
    :gb_sets,
    :gb_trees,
    :lists,
    :maps,
    :math,
    :orddict,
    :ordsets,
    :proplists,
    :queue,
    :sets,
    :string,
    :unicode
  ]

  @erlang ~w(+ - * / div rem abs band bor bxor bnot bsl bsr not and or xor
             == /= =:= =/= < > =< >= max min
             is_atom is_binary is_bitstring is_boolean is_float is_function is_integer
             is_list is_map is_map_key is_number is_pid is_port is_record is_reference
             is_tuple
             element setelement tuple_size make_tuple append_element tuple_to_list
             list_to_tuple hd tl length ++ -- map_size map_get
             byte_size bit_size binary_part iolist_to_binary iolist_size list_to_binary
             binary_to_list bitstring_to_list list_to_bitstring
             atom_to_binary atom_to_list binary_to_atom binary_to_existing_atom
             list_to_atom list_to_existing_atom
             integer_to_binary integer_to_list binary_to_integer list_to_integer
             float_to_binary float_to_list binary_to_float list_to_float float
             trunc round ceil floor phash2 make_fun self node)a

  @doc "Whether `mfa` is a pure library call (see the moduledoc)."
  @spec pure?(mfa()) :: boolean()
  def pure?({:erlang, name, _arity}), do: name in @erlang

  def pure?({module, _name, _arity} = mfa),
    do: module in @modules and HigherOrder.invocations(mfa) == []

  @doc "The modules read as pure in full, sorted."
  @spec modules() :: [module()]
  def modules, do: Enum.sort(@modules)
end
