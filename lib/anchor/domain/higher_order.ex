defmodule Anchor.Domain.HigherOrder do
  @moduledoc """
  The library functions that invoke one of their arguments — **Domain**, pure
  data (DND-5497).

  `Enum.map(list, fun)` calls `fun` inside `Enum`; the 0-CFA
  (`Anchor.Domain.Cfa`) counts that invocation as an apply site at the call,
  whose closures are the values reaching argument 1. Each entry maps a
  function to the arguments it invokes, as `{arg_index, arity}`: the 0-based
  index of the argument and the arity it is called with.

  A function missing from the table invokes nothing that the analysis can
  see: no site is recorded for its invocation, every argument passed to it
  escapes (its parameters become any), and its return is any
  (`Anchor.Domain.Cfa`). So a missing row loses a site from the counts and
  costs precision, but a closure it calls is still treated as called with
  anything. Where an argument may be a function or something else (a sorter
  or an empty fallback), the row gives the arity the function is called with
  when it is the first kind named in the docs.
  `erlang:apply/2` (`Kernel.apply/2`) is not here: it is an apply site of its
  own. `Kernel.then/2` and `Kernel.tap/2` are macros, gone before Core.
  """

  @invokers %{
    # Ecto.Changeset, Logger and MapSet (`prepare_changes/2` is not here: it runs in a
    # transaction the changeset's write opens, later)
    {Ecto.Changeset, :traverse_errors, 2} => [{1, 1}],
    {Ecto.Changeset, :update_change, 3} => [{2, 1}],
    {Ecto.Changeset, :validate_change, 3} => [{2, 2}],
    {Ecto.Changeset, :validate_change, 4} => [{3, 2}],
    {Logger, :__do_log__, 4} => [{1, 0}],
    {MapSet, :new, 2} => [{1, 1}],
    # Enum
    {Enum, :all?, 2} => [{1, 1}],
    {Enum, :any?, 2} => [{1, 1}],
    {Enum, :chunk_by, 2} => [{1, 1}],
    {Enum, :chunk_while, 4} => [{2, 2}, {3, 1}],
    {Enum, :count, 2} => [{1, 1}],
    {Enum, :count_until, 3} => [{1, 1}],
    {Enum, :dedup_by, 2} => [{1, 1}],
    {Enum, :drop_while, 2} => [{1, 1}],
    {Enum, :each, 2} => [{1, 1}],
    {Enum, :filter, 2} => [{1, 1}],
    {Enum, :find, 2} => [{1, 1}],
    {Enum, :find, 3} => [{2, 1}],
    {Enum, :find_index, 2} => [{1, 1}],
    {Enum, :find_value, 2} => [{1, 1}],
    {Enum, :find_value, 3} => [{2, 1}],
    {Enum, :flat_map, 2} => [{1, 1}],
    {Enum, :flat_map_reduce, 3} => [{2, 2}],
    {Enum, :frequencies_by, 2} => [{1, 1}],
    {Enum, :group_by, 2} => [{1, 1}],
    {Enum, :group_by, 3} => [{1, 1}, {2, 1}],
    {Enum, :into, 3} => [{2, 1}],
    {Enum, :map, 2} => [{1, 1}],
    {Enum, :map_every, 3} => [{2, 1}],
    {Enum, :map_intersperse, 3} => [{2, 1}],
    {Enum, :map_join, 2} => [{1, 1}],
    {Enum, :map_join, 3} => [{2, 1}],
    {Enum, :map_reduce, 3} => [{2, 2}],
    {Enum, :max_by, 2} => [{1, 1}],
    {Enum, :max, 2} => [{1, 2}],
    {Enum, :max, 3} => [{1, 2}, {2, 0}],
    {Enum, :max_by, 3} => [{1, 1}, {2, 2}],
    {Enum, :max_by, 4} => [{1, 1}, {2, 2}, {3, 0}],
    {Enum, :min_by, 2} => [{1, 1}],
    {Enum, :min, 2} => [{1, 2}],
    {Enum, :min, 3} => [{1, 2}, {2, 0}],
    {Enum, :min_by, 3} => [{1, 1}, {2, 2}],
    {Enum, :min_by, 4} => [{1, 1}, {2, 2}, {3, 0}],
    {Enum, :min_max_by, 2} => [{1, 1}],
    {Enum, :min_max_by, 3} => [{1, 1}, {2, 2}],
    {Enum, :product_by, 2} => [{1, 1}],
    {Enum, :reduce, 2} => [{1, 2}],
    {Enum, :reduce, 3} => [{2, 2}],
    {Enum, :reduce_while, 3} => [{2, 2}],
    {Enum, :reject, 2} => [{1, 1}],
    {Enum, :scan, 2} => [{1, 2}],
    {Enum, :scan, 3} => [{2, 2}],
    {Enum, :sort, 2} => [{1, 2}],
    {Enum, :sort_by, 2} => [{1, 1}],
    {Enum, :sort_by, 3} => [{1, 1}, {2, 2}],
    {Enum, :split_while, 2} => [{1, 1}],
    {Enum, :split_with, 2} => [{1, 1}],
    {Enum, :sum_by, 2} => [{1, 1}],
    {Enum, :take_while, 2} => [{1, 1}],
    {Enum, :uniq_by, 2} => [{1, 1}],
    {Enum, :with_index, 2} => [{1, 2}],
    {Enum, :zip_reduce, 3} => [{2, 2}],
    {Enum, :zip_reduce, 4} => [{3, 3}],
    {Enum, :zip_with, 2} => [{1, 1}],
    {Enum, :zip_with, 3} => [{2, 2}],
    # Stream
    {Stream, :chunk_by, 2} => [{1, 1}],
    {Stream, :chunk_while, 4} => [{2, 2}, {3, 1}],
    {Stream, :dedup_by, 2} => [{1, 1}],
    {Stream, :drop_while, 2} => [{1, 1}],
    {Stream, :each, 2} => [{1, 1}],
    {Stream, :filter, 2} => [{1, 1}],
    {Stream, :flat_map, 2} => [{1, 1}],
    {Stream, :iterate, 2} => [{1, 1}],
    {Stream, :map, 2} => [{1, 1}],
    {Stream, :map_every, 3} => [{2, 1}],
    {Stream, :reject, 2} => [{1, 1}],
    {Stream, :repeatedly, 1} => [{0, 0}],
    {Stream, :resource, 3} => [{0, 0}, {1, 1}, {2, 1}],
    {Stream, :scan, 2} => [{1, 2}],
    {Stream, :scan, 3} => [{2, 2}],
    {Stream, :take_while, 2} => [{1, 1}],
    {Stream, :transform, 3} => [{2, 2}],
    {Stream, :transform, 4} => [{1, 0}, {2, 2}, {3, 1}],
    {Stream, :transform, 5} => [{1, 0}, {2, 2}, {3, 1}, {4, 1}],
    {Stream, :unfold, 2} => [{1, 1}],
    {Stream, :uniq_by, 2} => [{1, 1}],
    {Stream, :with_index, 2} => [{1, 2}],
    {Stream, :zip_with, 2} => [{1, 1}],
    {Stream, :zip_with, 3} => [{2, 2}],
    # Map and Keyword
    {Map, :filter, 2} => [{1, 1}],
    {Map, :get_and_update, 3} => [{2, 1}],
    {Map, :get_and_update!, 3} => [{2, 1}],
    {Map, :get_lazy, 3} => [{2, 0}],
    {Map, :intersect, 3} => [{2, 3}],
    {Map, :merge, 3} => [{2, 3}],
    {Map, :new, 2} => [{1, 1}],
    {Map, :put_new_lazy, 3} => [{2, 0}],
    {Map, :reject, 2} => [{1, 1}],
    {Map, :replace_lazy, 3} => [{2, 1}],
    {Map, :split_with, 2} => [{1, 1}],
    {Map, :update, 4} => [{3, 1}],
    {Map, :update!, 3} => [{2, 1}],
    {Keyword, :filter, 2} => [{1, 1}],
    {Keyword, :get_lazy, 3} => [{2, 0}],
    {Keyword, :merge, 3} => [{2, 3}],
    {Keyword, :new, 2} => [{1, 1}],
    {Keyword, :put_new_lazy, 3} => [{2, 0}],
    {Keyword, :reject, 2} => [{1, 1}],
    {Keyword, :update, 4} => [{3, 1}],
    {Keyword, :update!, 3} => [{2, 1}],
    # List
    {List, :foldl, 3} => [{2, 2}],
    {List, :foldr, 3} => [{2, 2}],
    {List, :update_at, 3} => [{2, 1}],
    # Processes
    {Agent, :get, 2} => [{1, 1}],
    {Agent, :get, 3} => [{1, 1}],
    {Agent, :get_and_update, 2} => [{1, 1}],
    {Agent, :start, 1} => [{0, 0}],
    {Agent, :start_link, 1} => [{0, 0}],
    {Agent, :update, 2} => [{1, 1}],
    {Agent, :update, 3} => [{1, 1}],
    {Task, :async, 1} => [{0, 0}],
    {Task, :async_stream, 2} => [{1, 1}],
    {Task, :async_stream, 3} => [{1, 1}],
    {Task, :start, 1} => [{0, 0}],
    {Task, :start_link, 1} => [{0, 0}],
    {Task.Supervisor, :async, 2} => [{1, 0}],
    {Task.Supervisor, :async_nolink, 2} => [{1, 0}],
    {Task.Supervisor, :start_child, 2} => [{1, 0}],
    {:erlang, :spawn, 1} => [{0, 0}],
    {:erlang, :spawn_link, 1} => [{0, 0}],
    {:erlang, :spawn_monitor, 1} => [{0, 0}],
    # Erlang lists and maps
    {:lists, :all, 2} => [{0, 1}],
    {:lists, :any, 2} => [{0, 1}],
    {:lists, :dropwhile, 2} => [{0, 1}],
    {:lists, :filter, 2} => [{0, 1}],
    {:lists, :filtermap, 2} => [{0, 1}],
    {:lists, :flatmap, 2} => [{0, 1}],
    {:lists, :foldl, 3} => [{0, 2}],
    {:lists, :foldr, 3} => [{0, 2}],
    {:lists, :foreach, 2} => [{0, 1}],
    {:lists, :map, 2} => [{0, 1}],
    {:lists, :mapfoldl, 3} => [{0, 2}],
    {:lists, :mapfoldr, 3} => [{0, 2}],
    {:lists, :partition, 2} => [{0, 1}],
    {:lists, :sort, 2} => [{0, 2}],
    {:lists, :splitwith, 2} => [{0, 1}],
    {:lists, :takewhile, 2} => [{0, 1}],
    {:lists, :usort, 2} => [{0, 2}],
    {:lists, :zipwith, 3} => [{0, 2}],
    {:maps, :filter, 2} => [{0, 2}],
    {:maps, :filtermap, 2} => [{0, 2}],
    {:maps, :fold, 3} => [{0, 3}],
    {:maps, :foreach, 2} => [{0, 2}],
    {:maps, :map, 2} => [{0, 2}],
    {:maps, :update_with, 3} => [{1, 1}],
    {:maps, :update_with, 4} => [{1, 1}]
  }

  @doc """
  The arguments `mfa` invokes, as `[{arg_index, arity}]` (0-based index, the
  arity it is called with), in argument order; `[]` for a function that
  invokes none of its arguments or is not in the table.
  """
  @spec invocations(mfa()) :: [{non_neg_integer(), arity()}]
  def invocations(mfa), do: Map.get(@invokers, mfa, [])

  @doc "Every function in the table, sorted."
  @spec functions() :: [mfa()]
  def functions, do: @invokers |> Map.keys() |> Enum.sort()
end
