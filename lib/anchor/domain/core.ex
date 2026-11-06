defmodule Anchor.Domain.Core do
  @moduledoc """
  Pure helpers over one function's Core Erlang (`:cerl`) — **Domain**
  (DND-5497). They name what the 0-CFA (`Anchor.Domain.Cfa`) tracks — the
  lambdas, the apply sites and the containers' allocation sites — with
  ordinals that are stable for identical Core.

  `label/1` walks the function's body once, in pre-order
  (`:cerl_trees.mapfold/4`), keeping three ordinal sequences, each counted
  from 0 in order of appearance, and annotates

    * every `fun` inside the body with `{:anchor_lambda, ordinal}`. The
      function's own `fun` is not one of them. A `letrec` definition (the loop
      Core makes of a `receive`, or of a comprehension over a binary) is a
      `fun` too, so it is a lambda with its own ordinal;
    * every apply site with `{:anchor_sites, [ordinal]}`. A site is
        * `apply E(...)` where `E` is not a function name (`fun.(x)`, and an
          apply of any computed value): one site;
        * `call 'erlang':'apply'(F, Args)` (`apply/2`): one site;
        * a call to a function `Anchor.Domain.HigherOrder` lists
          (`Enum.map(list, fun)`): one site per invoked argument, in the
          table's order.

      `apply 'f'/a(...)` (a local or `letrec` call) and `apply/3` are calls,
      not apply sites;
    * every node that builds a container with `{:anchor_alloc, ordinal}`: a
      tuple, a cons, a map, a `maps:put/3` or `Map.put/3` call, and a literal
      container that holds a fun (a pattern is labelled too; nothing reads
      its label).

  `lambdas/1`, `apply_sites/2`, `lambda_ordinal/1`, `site_ordinals/1` and
  `alloc_ordinal/1` read those annotations back, so the 0-CFA and its
  consumers share one numbering.

  `mfa_references/1` reads a different fact, with no label: the literal
  `{module, name, args}` triples a function holds (DND-5470).
  """

  alias Anchor.Domain.HigherOrder

  @labels [:anchor_lambda, :anchor_sites, :anchor_alloc]
  @map_puts [{:maps, :put, 3}, {Map, :put, 3}]

  # A function that takes a module, name and arguments, to where that triple starts.
  @mfa_taking %{
    {:erlang, :spawn, 3} => 0,
    {:erlang, :spawn_link, 3} => 0,
    {:erlang, :spawn_monitor, 3} => 0,
    {:erlang, :spawn, 4} => 1,
    {:erlang, :spawn_link, 4} => 1,
    {:erlang, :spawn_monitor, 4} => 1,
    {:erlang, :spawn_opt, 4} => 0,
    {:erlang, :spawn_opt, 5} => 1,
    {:erpc, :call, 4} => 1,
    {:erpc, :call, 5} => 1,
    {:erpc, :cast, 4} => 1,
    {:proc_lib, :spawn, 3} => 0,
    {:proc_lib, :spawn, 4} => 1,
    {:proc_lib, :spawn_link, 3} => 0,
    {:proc_lib, :spawn_link, 4} => 1,
    {:proc_lib, :start, 3} => 0,
    {:proc_lib, :start_link, 3} => 0,
    {:rpc, :call, 4} => 1,
    {:rpc, :cast, 4} => 1,
    {:timer, :apply_after, 4} => 1,
    {:timer, :apply_interval, 4} => 1,
    {Task, :async, 3} => 0,
    {Task, :start, 3} => 0,
    {Task, :start_link, 3} => 0,
    {Task.Supervisor, :async, 4} => 1,
    {Task.Supervisor, :async, 5} => 1,
    {Task.Supervisor, :async_nolink, 4} => 1,
    {Task.Supervisor, :async_nolink, 5} => 1,
    {Task.Supervisor, :start_child, 4} => 1,
    {Task.Supervisor, :start_child, 5} => 1
  }

  @typedoc "An apply site: the enclosing function and the site's ordinal in it."
  @type site_id :: {mfa(), non_neg_integer()}

  @doc "The allocation ordinal of a labelled container node, or `nil`."
  @spec alloc_ordinal(:cerl.cerl()) :: non_neg_integer() | nil
  def alloc_ordinal(node), do: label_value(node, :anchor_alloc, nil)

  @doc """
  The apply sites of `core_fun`, the Core `c_fun` of `mfa`, as
  `[{site_id, node}]` in ordinal order. A call that invokes two arguments
  (`Enum.group_by/3`) is two entries with the same node.
  """
  @spec apply_sites(mfa(), :cerl.cerl()) :: [{site_id(), :cerl.cerl()}]
  def apply_sites(mfa, core_fun) do
    core_fun
    |> label()
    |> collect(fn node -> node |> site_ordinals() |> Enum.map(&{{mfa, &1}, node}) end)
    |> Enum.sort_by(fn {{_mfa, ordinal}, _node} -> ordinal end)
  end

  @doc "The `{module, name, arity}` of a `call` with a literal module and name, else `nil`."
  @spec call_mfa(:cerl.cerl()) :: mfa() | nil
  def call_mfa(node) do
    module = :cerl.call_module(node)
    name = :cerl.call_name(node)

    with true <- :cerl.is_literal(module) and :cerl.is_literal(name),
         m when is_atom(m) <- :cerl.concrete(module),
         f when is_atom(f) <- :cerl.concrete(name) do
      {m, f, length(:cerl.call_args(node))}
    else
      _not_literal -> nil
    end
  end

  @doc """
  Annotates `core_fun` with lambda, apply-site and allocation ordinals (see
  the moduledoc). Labelling labelled Core again gives the same ordinals.
  """
  @spec label(:cerl.cerl()) :: :cerl.cerl()
  def label(core_fun) do
    body = :cerl.fun_body(core_fun)
    {body, _counters} = :cerl_trees.mapfold(&label_node/2, &{&1, &2}, {0, 0, 0}, body)
    :cerl.update_c_fun(core_fun, :cerl.fun_vars(core_fun), body)
  end

  @doc "The lambda ordinal of a labelled `fun` node, or `nil`."
  @spec lambda_ordinal(:cerl.cerl()) :: non_neg_integer() | nil
  def lambda_ordinal(node), do: label_value(node, :anchor_lambda, nil)

  @doc """
  What the labelled `letrec` node binds, for the function `mfa`: each
  definition's name `{name, arity}` to its lambda `{mfa, ordinal}` (DND-5575).
  The names are visible in the letrec's body and in its definitions' bodies;
  an enclosing scope's binding of the same name is shadowed there.
  """
  @spec letrec_bindings(mfa(), :cerl.cerl()) :: %{
          {atom(), arity()} => [{mfa(), non_neg_integer()}]
        }
  def letrec_bindings(mfa, letrec) do
    Map.new(:cerl.letrec_defs(letrec), fn {fname, fun} ->
      {:cerl.var_name(fname), [{mfa, lambda_ordinal(fun)}]}
    end)
  end

  @doc """
  The lambdas inside `core_fun`, as `[{ordinal, c_fun}]` in ordinal order (the
  function's own `fun` is not one).
  """
  @spec lambdas(:cerl.cerl()) :: [{non_neg_integer(), :cerl.cerl()}]
  def lambdas(core_fun) do
    core_fun
    |> label()
    |> collect(fn node ->
      case lambda_ordinal(node) do
        nil -> []
        ordinal -> [{ordinal, node}]
      end
    end)
    |> Enum.sort_by(&elem(&1, 0))
  end

  @doc """
  The source line of `node`'s Core annotation, else of the first annotated
  node inside it (pre-order), else `nil`. Line 0 (the compiler's mark for
  generated code) is no line.
  """
  @spec line(:cerl.cerl()) :: pos_integer() | nil
  def line(node) do
    case own_line(node) do
      nil -> node |> :cerl.subtrees() |> List.flatten() |> Enum.find_value(&line/1)
      line -> line
    end
  end

  @doc """
  The apply-site ordinals a labelled node carries (`[]` for a node that is no
  apply site).
  """
  @spec site_ordinals(:cerl.cerl()) :: [non_neg_integer()]
  def site_ordinals(node), do: label_value(node, :anchor_sites, [])

  @doc """
  The functions `core_fun` names in full, which call them where no call edge shows
  it: a literal module, a literal name and an args list of known length, in a tuple
  or a literal term (a child spec's `start:`) or as three arguments in a row of a
  call, remote or local (`spawn(M, :f, [a])`). Each is `{M, :f, arity}`, listed once.

  That shape is all it reads. Anything less names nothing and is not here: a
  variable for the module, the name or the args, and a list of unknown length. A
  call that merely has the shape (`foo(M, :f, [a])`) reads as one, which can only
  exempt that exact name and arity.
  """
  @spec mfa_references(:cerl.cerl()) :: [mfa()]
  def mfa_references(core_fun) do
    core_fun |> collect(&node_references/1) |> Enum.uniq()
  end

  @doc """
  Every atom a function's body holds as a value, in a literal of any depth (DND-5448):
  what could name a module to a supervisor (`children = [M, {N, arg}]`). The module and
  name a call is made on are not values, so they are not here.
  """
  @spec held_atoms(:cerl.cerl()) :: [atom()]
  def held_atoms(core_fun), do: core_fun |> held_atoms_of() |> Enum.uniq() |> Enum.sort()

  @doc """
  The calls of a function that takes a module, a function name and arguments and
  starts that function later (`spawn(mod, name, args)`, `Task.start(M, :f, args)`,
  the table `@mfa_taking`), whose triple `mfa_references/1` cannot read in full (DND-5448):
  each `%{module: atom | nil, name: atom | nil, line: line}`, `nil` for what is not a
  literal atom. A literal module, literal name and a list of known length is not here:
  it names one arity, and `mfa_references/1` has it.
  """
  @spec partial_mfa_calls(:cerl.cerl()) :: [
          %{module: atom() | nil, name: atom() | nil, line: non_neg_integer() | nil}
        ]
  def partial_mfa_calls(core_fun), do: core_fun |> collect(&partial_mfa_call/1) |> Enum.uniq()

  # --- labelling ---------------------------------------------------------------

  defp label_node(node, {lambdas, sites, allocs}) do
    node = strip_labels(node)

    {node, lambdas} =
      if :cerl.type(node) == :fun, do: add(node, :anchor_lambda, lambdas), else: {node, lambdas}

    {node, sites} = label_sites(node, site_count(node), sites)

    {node, allocs} =
      if alloc?(node), do: add(node, :anchor_alloc, allocs), else: {node, allocs}

    {node, {lambdas, sites, allocs}}
  end

  defp add(node, key, ordinal), do: {:cerl.add_ann([{key, ordinal}], node), ordinal + 1}

  defp label_sites(node, 0, sites), do: {node, sites}

  defp label_sites(node, count, sites) do
    ordinals = Enum.to_list(sites..(sites + count - 1)//1)
    {:cerl.add_ann([{:anchor_sites, ordinals}], node), sites + count}
  end

  defp strip_labels(node) do
    annotation =
      Enum.reject(:cerl.get_ann(node), fn
        {key, _value} -> key in @labels
        _other -> false
      end)

    :cerl.set_ann(node, annotation)
  end

  defp site_count(node) do
    case :cerl.type(node) do
      :apply -> if :cerl.is_c_fname(:cerl.apply_op(node)), do: 0, else: 1
      :call -> call_site_count(call_mfa(node))
      _other -> 0
    end
  end

  defp call_site_count({:erlang, :apply, 2}), do: 1
  defp call_site_count(nil), do: 0
  defp call_site_count(mfa), do: length(HigherOrder.invocations(mfa))

  defp alloc?(node) do
    case :cerl.type(node) do
      type when type in [:tuple, :cons, :map] -> true
      :call -> call_mfa(node) in @map_puts
      :literal -> container_holding_fun?(:cerl.concrete(node))
      _other -> false
    end
  end

  defp container_holding_fun?(term),
    do: (is_tuple(term) or is_list(term) or is_map(term)) and holds_fun?(term)

  defp holds_fun?(term) when is_function(term), do: true

  defp holds_fun?(term) when is_tuple(term),
    do: term |> Tuple.to_list() |> Enum.any?(&holds_fun?/1)

  defp holds_fun?(term) when is_map(term), do: term |> Map.to_list() |> Enum.any?(&holds_fun?/1)
  defp holds_fun?([head | tail]), do: holds_fun?(head) or holds_fun?(tail)
  defp holds_fun?(_term), do: false

  # --- literal MFAs ------------------------------------------------------------

  defp held_atoms_of(node) do
    case :cerl.type(node) do
      :literal -> node |> :cerl.concrete() |> term_atoms()
      :call -> node |> :cerl.call_args() |> Enum.flat_map(&held_atoms_of/1)
      _other -> node |> :cerl.subtrees() |> List.flatten() |> Enum.flat_map(&held_atoms_of/1)
    end
  end

  defp term_atoms(term) when is_atom(term), do: [term]
  defp term_atoms(term) when is_tuple(term), do: term |> Tuple.to_list() |> term_atoms()
  defp term_atoms(term) when is_map(term), do: term |> Map.to_list() |> term_atoms()
  defp term_atoms([head | tail]), do: term_atoms(head) ++ term_atoms(tail)
  defp term_atoms(_other), do: []

  defp partial_mfa_call(node) do
    with :call <- :cerl.type(node),
         at when is_integer(at) <- Map.get(@mfa_taking, call_mfa(node)),
         [module, name, args] <- node |> :cerl.call_args() |> Enum.slice(at, 3),
         [] <- triple_reference([module, name, args]) do
      [%{module: literal_atom(module), name: literal_atom(name), line: line(node)}]
    else
      _not_partial -> []
    end
  end

  defp literal_atom(node), do: if(literal_atom?(node), do: :cerl.concrete(node))

  defp node_references(node) do
    case :cerl.type(node) do
      :tuple -> node |> :cerl.tuple_es() |> triple_reference()
      :call -> node |> :cerl.call_args() |> window_references()
      :apply -> node |> :cerl.apply_args() |> window_references()
      :literal -> node |> :cerl.concrete() |> term_references()
      _other -> []
    end
  end

  defp window_references(args) do
    args |> Enum.chunk_every(3, 1, :discard) |> Enum.flat_map(&triple_reference/1)
  end

  defp triple_reference([module, name, args]) do
    if literal_atom?(module) and literal_atom?(name) and :cerl.is_c_list(args),
      do: [{:cerl.concrete(module), :cerl.concrete(name), :cerl.list_length(args)}],
      else: []
  end

  defp triple_reference(_elements), do: []

  defp literal_atom?(node), do: :cerl.is_literal(node) and is_atom(:cerl.concrete(node))

  defp term_references({module, name, args} = term)
       when is_atom(module) and is_atom(name) and is_list(args) do
    inner = term |> Tuple.to_list() |> Enum.flat_map(&term_references/1)
    if List.improper?(args), do: inner, else: [{module, name, length(args)} | inner]
  end

  defp term_references(term) when is_tuple(term),
    do: term |> Tuple.to_list() |> Enum.flat_map(&term_references/1)

  defp term_references(term) when is_map(term),
    do: term |> Map.to_list() |> Enum.flat_map(&term_references/1)

  defp term_references([head | tail]),
    do: term_references(head) ++ term_references(tail)

  defp term_references(_term), do: []

  # --- reading -----------------------------------------------------------------

  defp collect(tree, fun) do
    (&[fun.(&1) | &2])
    |> :cerl_trees.fold([], tree)
    |> Enum.reverse()
    |> List.flatten()
  end

  defp label_value(node, key, default) do
    case List.keyfind(:cerl.get_ann(node), key, 0) do
      {^key, value} -> value
      nil -> default
    end
  end

  defp own_line(node) do
    Enum.find_value(:cerl.get_ann(node), fn
      line when is_integer(line) and line > 0 -> line
      {line, column} when is_integer(line) and line > 0 and is_integer(column) -> line
      _other -> nil
    end)
  end
end
