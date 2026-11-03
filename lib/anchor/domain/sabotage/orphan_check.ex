defmodule Anchor.Domain.Sabotage.OrphanCheck do
  @moduledoc """
  Whether a mutant would still compile under `--warnings-as-errors`
  (DND-5471). Pure **Domain**: it parses the original and the mutated text and
  compares what they bind and read; nothing is compiled.

  A mutant is refused (with a sentence saying why) when, compared with the
  original source:

    * it does not parse;
    * a clause of the mutated function reads a variable nothing binds any more
      (`Anchor.Domain.DataFlow`'s `:free` keys), or binds one nothing reads
      (a variable left unused), counted by name;
    * the module loses the last use of one of its private functions, of a
      module attribute it reads, of an alias it declares, of a name in an
      `import M, only: [...]` list (the compiler reports each listed name),
      or of the last call an `import` with no `only:` list can serve (the
      compiler reports that import only when no call reaches it, so removing
      the last call of one name while another still reaches it is a mutant,
      DND-5563): each is a compiler warning.

  Comparing with the original, not judging the mutant alone, means a warning
  the original already has never refuses a mutant.
  """

  alias Anchor.Domain.DataFlow
  alias Anchor.Domain.DataFlow.Forms
  alias Anchor.Domain.Sabotage.Patch
  alias Anchor.Domain.Sabotage.SourceTree

  @defs [:def, :defp, :defmacro, :defmacrop]

  @doc """
  `:ok`, or `{:skip, reason}`. `range` is the edit's range in the original
  source; it maps the mutant's line numbers back to the original's in the
  reason.
  """
  @spec check(String.t(), String.t(), {module(), atom(), arity()}, Patch.range()) ::
          :ok | {:skip, String.t()}
  def check(original, mutated, {module, name, arity}, range) do
    lines = line_map(original, mutated, range)

    with {:ok, mutated_ast} <- parse_mutant(mutated),
         {:ok, original_ast} <- SourceTree.parse(original),
         :ok <-
           variables(original, original_ast, mutated, mutated_ast, {module, name, arity}, lines) do
      module_refs(original, original_ast, mutated, mutated_ast, module)
    end
  end

  defp parse_mutant(mutated) do
    case SourceTree.parse(mutated) do
      {:ok, ast} ->
        {:ok, ast}

      {:error, {:parse_error, line, message}} ->
        {:skip, "the mutant does not parse (line #{line}: #{message})"}
    end
  end

  # -- variables ------------------------------------------------------------

  defp variables(original, original_ast, mutated, mutated_ast, mfa, lines) do
    with {:ok, before} <- variable_facts(original, original_ast, mfa),
         {:ok, later} <- variable_facts(mutated, mutated_ast, mfa) do
      variable_verdict(before, later, lines)
    else
      :error -> {:skip, "the mutated function could not be read back"}
    end
  end

  defp variable_verdict(before, later, lines) do
    free = first_new(before.free, later.free)
    unused = first_new(before.unused, later.unused)

    cond do
      free != nil ->
        {:skip,
         "orphans variable `#{free}` bound at line #{binding_line(before, free, lines)} " <>
           "and used at line #{lines.(use_line(later, free))}"}

      unused != nil ->
        {:skip,
         "leaves variable `#{unused}` bound at line #{lines.(unused_line(later, unused))} unused"}

      true ->
        :ok
    end
  end

  defp binding_line(before, name, lines) do
    {start_line, _end_line} = lines.(:edit)

    before.bound
    |> Enum.filter(fn {bound, line} -> bound == name and line >= start_line end)
    |> Enum.map(&elem(&1, 1))
    |> Enum.min(fn -> start_line end)
  end

  defp clause_facts(source, clause) do
    {{head_line, _column}, _stop} = SourceTree.range(clause.node)

    case SourceTree.dataflow_clause(source, clause) do
      {:ok, triple} -> {:ok, flow_facts(DataFlow.analyze(triple), head_line)}
      :error -> :error
    end
  end

  defp first_new(before, later) do
    counts = Enum.frequencies_by(before, &elem(&1, 0))

    later
    |> Enum.frequencies_by(&elem(&1, 0))
    |> Enum.filter(fn {name, count} -> count > Map.get(counts, name, 0) end)
    |> Enum.map(&elem(&1, 0))
    |> Enum.sort()
    |> List.first()
  end

  defp flow_facts(flow, head_line) do
    line_of = fn
      :param -> head_line
      id -> flow.nodes[id].line || head_line
    end

    free =
      for {{name, _ctx, :free}, ids} <- flow.uses, do: {name, line_of.(hd(ids))}

    bound = for {{name, _ctx, _version}, definer} <- flow.defs, do: {name, line_of.(definer)}

    unused =
      for {{name, _ctx, _version} = key, definer} <- flow.defs,
          not Map.has_key?(flow.uses, key),
          key not in flow.guard_uses,
          do: {name, line_of.(definer)}

    %{free: free, bound: bound, unused: unused}
  end

  # Maps a line of the mutant to the original's numbering (lines after the
  # edit move by the edit's line delta); `:edit` gives the edit's own lines.
  defp line_map(original, mutated, {{start_line, _sc}, {end_line, _ec}}) do
    delta = line_count(mutated) - line_count(original)

    fn
      :edit -> {start_line, end_line}
      line when line >= end_line + delta and line >= start_line -> line - delta
      line -> line
    end
  end

  defp line_count(text), do: length(String.split(text, "\n"))

  defp unused_line(facts, name),
    do:
      facts.unused |> Enum.filter(&(elem(&1, 0) == name)) |> Enum.map(&elem(&1, 1)) |> Enum.max()

  defp use_line(facts, name),
    do: facts.free |> Enum.filter(&(elem(&1, 0) == name)) |> Enum.map(&elem(&1, 1)) |> Enum.min()

  defp variable_facts(source, ast, {module, name, arity}) do
    with {:ok, clauses} <- SourceTree.function_clauses(ast, module, name, arity),
         {:ok, facts} <- collect(Enum.map(clauses, &clause_facts(source, &1))) do
      {:ok,
       Enum.reduce(facts, %{free: [], bound: [], unused: []}, fn f, acc ->
         %{free: acc.free ++ f.free, bound: acc.bound ++ f.bound, unused: acc.unused ++ f.unused}
       end)}
    else
      _error -> :error
    end
  end

  defp collect(results) do
    if Enum.all?(results, &match?({:ok, _facts}, &1)),
      do: {:ok, Enum.map(results, &elem(&1, 1))},
      else: :error
  end

  # -- module-level references ---------------------------------------------

  defp module_refs(original, original_ast, mutated, mutated_ast, module) do
    with {:ok, before} <- refs_of(original, original_ast, module),
         {:ok, later} <- refs_of(mutated, mutated_ast, module) do
      case Enum.sort(MapSet.difference(tracked(before), tracked(later))) do
        [] -> :ok
        [lost | _rest] -> {:skip, "removes the last use of #{describe(lost)}"}
      end
    else
      _error -> {:skip, "the mutated module could not be read back"}
    end
  end

  defp describe({:call, name, arity}), do: "function `#{name}/#{arity}`"

  defp describe(:import_calls),
    do: "an `import` (no call to an imported function is left)"

  defp describe({:attr, name}), do: "module attribute `@#{name}`"
  defp describe({:alias, name}), do: "alias `#{name}`"

  defp refs_of(source, ast, module) do
    with {:ok, node} <- SourceTree.module_node(ast, module),
         {{line, _column}, _stop} = range <- SourceTree.range(node),
         {:ok, quoted} <- SourceTree.quoted(Patch.slice(source, range), line) do
      acc = %{uses: MapSet.new(), defined: %{}, aliases: MapSet.new(), imports: []}
      {_definition, _meta, [_name | lists]} = Forms.desugar_pipes(quoted)
      {:ok, refs(lists |> Enum.concat() |> Keyword.get(:do), acc)}
    else
      _error -> :error
    end
  end

  # What the compiler warns about when the last use goes (DND-5563):
  #
  #   * a private function, a module attribute, an alias: each its own key;
  #   * a name in an `import M, only: [...]` list: its own key, because the
  #     compiler reports `unused import M.name/arity` per listed name;
  #   * the calls that may reach an `import` with no `only:` list: ONE key
  #     between them, `:import_calls`, because the compiler reports
  #     `unused import M` only when no call reaches the import at all. Which
  #     import such a call reaches is unknown without compiling, so with two
  #     of these imports the key stands for them together: a mutant that
  #     empties one while the other is still called is not seen (at worst it
  #     fails to compile and is `invalid`).
  defp tracked(refs) do
    refs.uses
    |> Enum.map(&tracked_key(refs, &1))
    |> Enum.reject(&is_nil/1)
    |> MapSet.new()
  end

  defp tracked_key(refs, {:call, name, arity} = use),
    do:
      call_key(
        use,
        private?(refs, name, arity),
        listed?(refs, name, arity),
        open?(refs, name, arity)
      )

  defp tracked_key(_refs, {:attr, _name} = use), do: use

  defp tracked_key(refs, {:alias, name} = use),
    do: if(MapSet.member?(refs.aliases, name), do: use)

  defp call_key(use, true, _listed, _open), do: use
  defp call_key(use, _private, true, _open), do: use
  defp call_key(_use, _private, _listed, true), do: :import_calls
  defp call_key(_use, _private, _listed, _open), do: nil

  # A call to a name in an `only:` list, which the module does not define.
  defp listed?(refs, name, arity) do
    not Map.has_key?(refs.defined, name) and
      Enum.any?(refs.imports, &listed_in?(&1, name, arity))
  end

  defp listed_in?({:only, names}, name, arity), do: {name, arity} in names
  defp listed_in?(:all, _name, _arity), do: false

  # A call that may reach an `import` with no `only:` list: any name the module
  # does not define and is not listed, a special form, an operator or a
  # `Kernel` function or macro.
  defp open?(refs, name, arity) do
    not Map.has_key?(refs.defined, name) and :all in refs.imports and
      not listed?(refs, name, arity) and not builtin?(name, arity)
  end

  defp builtin?(name, arity) do
    Macro.special_form?(name, arity) or Macro.operator?(name, arity) or
      {name, arity} in Kernel.__info__(:functions) or {name, arity} in Kernel.__info__(:macros) or
      name in [:__block__, :__aliases__, :{}, :%{}, :%, :<<>>, :fn, :->, :"::", :.]
  end

  defp private?(refs, name, arity) do
    refs.defined
    |> Map.get(name, [])
    |> Enum.any?(fn {kind, range} -> kind in [:defp, :defmacrop] and arity in range end)
  end

  defp refs({def, _meta, [head | rest]}, acc) when def in @defs do
    {call, guards} =
      case head do
        {:when, _wmeta, [call, guard]} -> {call, [guard]}
        call -> {call, []}
      end

    acc = acc |> define(def, call) |> then(&refs(guards, refs(head_args(call), &1)))

    # A private function's call to itself is not a use: the compiler still
    # reports it unused when nothing else calls it.
    body = refs(rest, %{acc | uses: MapSet.new()})
    %{body | uses: MapSet.union(acc.uses, own_calls_dropped(body.uses, def, call))}
  end

  # A nested module, or a protocol implementation (DND-5624), is its own
  # module: its definitions and uses are not this one's.
  defp refs({definition, _meta, _args}, acc) when definition in [:defmodule, :defimpl],
    do: acc

  defp refs({:@, _meta, [{name, _nmeta, context}]}, acc) when is_atom(name) and is_atom(context),
    do: add_use(acc, {:attr, name})

  defp refs({:@, _meta, [{name, _nmeta, args}]}, acc) when is_atom(name) and is_list(args),
    do: refs(args, acc)

  defp refs({:alias, _meta, [target | opts]}, acc) do
    %{acc | aliases: MapSet.union(acc.aliases, MapSet.new(alias_names(target, opts)))}
  end

  defp refs({:import, _meta, [_module | opts]}, acc),
    do: %{acc | imports: [import_scope(opts) | acc.imports]}

  defp refs({:&, _meta, [{:/, _smeta, [{name, _nmeta, context}, arity]}]}, acc)
       when is_atom(name) and is_atom(context) and is_integer(arity),
       do: add_use(acc, {:call, name, arity})

  defp refs({:__aliases__, _meta, [first | _rest]}, acc) when is_atom(first),
    do: add_use(acc, {:alias, first})

  defp refs({name, _meta, args}, acc) when is_atom(name) and is_list(args),
    do: refs(args, add_use(acc, {:call, name, length(args)}))

  defp refs({form, _meta, args}, acc) when is_list(args), do: refs(args, refs(form, acc))
  defp refs({left, right}, acc), do: refs(right, refs(left, acc))
  defp refs(list, acc) when is_list(list), do: Enum.reduce(list, acc, &refs/2)
  defp refs(_literal, acc), do: acc

  defp import_scope(opts) do
    case Keyword.get(List.flatten(opts), :only) do
      names when is_list(names) ->
        {:only,
         Enum.filter(names, &match?({name, arity} when is_atom(name) and is_integer(arity), &1))}

      _all ->
        :all
    end
  end

  defp alias_names({{:., _dmeta, [{:__aliases__, _ameta, _base}, :{}]}, _meta, children}, _opts),
    do: Enum.flat_map(children, &alias_names(&1, []))

  defp alias_names({:__aliases__, _meta, segments}, opts) do
    case Keyword.get(List.flatten(opts), :as) do
      {:__aliases__, _ameta, [as]} -> [as]
      nil -> [List.last(segments)]
      _other -> []
    end
  end

  defp alias_names(_target, _opts), do: []

  defp define(acc, def, {name, _meta, args}) when is_atom(name) do
    args = if is_list(args), do: args, else: []
    defaults = Enum.count(args, &match?({:\\, _dmeta, [_pattern, _default]}, &1))
    entry = {def, (length(args) - defaults)..length(args)//1}
    %{acc | defined: Map.update(acc.defined, name, [entry], &[entry | &1])}
  end

  defp define(acc, _def, _call), do: acc

  # A head's parameter patterns (and their defaults): an alias or attribute
  # there is a use.
  defp head_args({_name, _meta, args}) when is_list(args), do: args
  defp head_args(_call), do: []

  defp own_calls_dropped(uses, def, {name, _meta, args}) when def in [:defp, :defmacrop] do
    args = if is_list(args), do: args, else: []
    defaults = Enum.count(args, &match?({:\\, _dmeta, [_pattern, _default]}, &1))
    arities = (length(args) - defaults)..length(args)//1

    MapSet.reject(uses, fn
      {:call, ^name, arity} -> arity in arities
      _other -> false
    end)
  end

  defp own_calls_dropped(uses, _def, _call), do: uses

  defp add_use(acc, ref), do: %{acc | uses: MapSet.put(acc.uses, ref)}
end
