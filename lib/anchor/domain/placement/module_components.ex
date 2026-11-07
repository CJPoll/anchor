defmodule Anchor.Domain.Placement.ModuleComponents do
  @moduledoc """
  Module split proposals, M1 and M3 (DND-5463) — **Domain**, pure over the model.

  ## The causal components of a module (M1, LCOM4)

  `components/2` links a module's public functions (`def`s an author wrote,
  `Anchor.Domain.Placement.Rules.authored?/1`) when:

    * one reaches the other through the module's own call graph (a local call, or a
      remote call into the same module), walking through its private functions; a
      private function does not itself link two public ones;
    * both build, update or match the module's own struct, a private function's use
      counting for every public function that reaches it;
    * both implement the callbacks of one behaviour (a project behaviour's, or an
      external one's the effect inference was given, `Effects.callbacks`).

  The connected components of those links are the module's causal components. A
  shared private callee does not link: if it did, M3 could never fire (DND-5463's
  design, on purpose).

  ## Proposals

  `proposals/1` judges each classified, hand-written module that is no interface (a
  context facade crosses a boundary by design, Cody's decision 2) and has two or more
  public functions. Length never triggers anything.

    * **M1.** A module with two or more components gets one `:components` proposal:
      split it, one module per component. The component that uses the module's own
      struct keeps the name (at most one can: its users are linked); with none, the
      one with the most public functions does (ties: the one holding the
      alphabetically first function). Each other is named after the type it owns: the project struct its
      functions return by `@spec` (`Ownership.output_owner/2`) or build, most frequent
      first, ties alphabetical, as the module's last name segment. One that owns no
      type is named after its first public function (`Ledger.FormatCurrency`), and
      the evidence says to rename it. No name is given twice: a name the module or
      another part already has falls back to the first function's name, then to it
      with the arity (`Ledger.Fmt1`), then to `Ledger.Part2`, ...; the evidence says to
      rename it. A name an existing module already has makes the proposal name that
      module as the target, and the evidence says to merge into it.
    * **M3.** A private function reached from two or more components is a shared
      private helper: one `:shared_private_helper` proposal to extract it into its own
      module (its name camelized, never a part's or another helper's: else with its
      arity), naming the components. One reached from one component moves with it.
  """

  alias Anchor.Domain.Classification
  alias Anchor.Domain.Digraph
  alias Anchor.Domain.Graph
  alias Anchor.Domain.Graph.Call
  alias Anchor.Domain.Graph.FunctionNode
  alias Anchor.Domain.Graph.ModuleNode
  alias Anchor.Domain.Graph.StructUse
  alias Anchor.Domain.GraphAlgorithms
  alias Anchor.Domain.Model
  alias Anchor.Domain.Placement
  alias Anchor.Domain.Placement.FunctionFacts
  alias Anchor.Domain.Placement.Ownership
  alias Anchor.Domain.Placement.Rules
  alias Anchor.Domain.Proposal
  alias Anchor.Domain.ViolationKey

  @type component :: %{
          functions: [mfa()],
          privates: [mfa()],
          owned_type: module() | nil,
          own_struct?: boolean()
        }

  @doc "The causal components of `module`, sorted by first function; see the moduledoc."
  @spec components(Model.t(), module()) :: [component()]
  def components(%Model{graph: graph} = model, module) do
    node = Map.fetch!(graph.modules, module)
    public = public_functions(module, node)
    local = local_edges(graph, module)
    reach = Map.new(public, &{&1, reach(&1, local, MapSet.new(public))})
    struct_users = struct_users(graph, module, public, reach)
    callback_groups = callback_groups(model, module, node, public)

    links =
      for({from, %{public: reached}} <- reach, to <- reached, do: {from, to}) ++
        chain(struct_users) ++ Enum.flat_map(callback_groups, &chain/1)

    public
    |> Digraph.new(links)
    |> GraphAlgorithms.components()
    |> Enum.map(fn members ->
      privates = members |> Enum.flat_map(&reach[&1].privates) |> Enum.uniq() |> Enum.sort()

      %{
        functions: members,
        privates: privates,
        owned_type: owned_type(graph, module, members, privates),
        own_struct?: Enum.any?(members, &(&1 in struct_users))
      }
    end)
    |> Enum.sort_by(&hd(&1.functions))
  end

  @doc "The M1 and M3 proposals of every judged module, sorted by key; see the moduledoc."
  @spec proposals(Model.t()) :: [Proposal.t()]
  def proposals(%Model{graph: graph} = model) do
    graph.modules
    |> Map.keys()
    |> Enum.filter(&judged?(model, &1))
    |> Enum.flat_map(&module_proposals(model, &1))
    |> Enum.sort_by(& &1.key)
  end

  # --- which modules ---------------------------------------------------------------

  defp judged?(%Model{graph: graph, classification: classification}, module) do
    node = graph.modules[module]

    # A generated module has no authored function (`Placement.generated_function?/2`
    # answers for the module too), so it never has two.
    match?(%Classification{interface?: false}, Map.get(classification, module)) and
      length(public_functions(module, node)) >= 2
  end

  defp public_functions(module, %ModuleNode{functions: functions} = node) do
    for {{name, arity}, %FunctionNode{kind: :def} = function} <- functions,
        facts = %FunctionFacts{
          mfa: {module, name, arity},
          kind: :def,
          generated?: Placement.generated_function?(function, node)
        },
        Rules.authored?(facts),
        do: {module, name, arity}
  end

  # --- links -----------------------------------------------------------------------

  defp local_edges(%Graph{calls: calls}, module) do
    for %Call{from: {^module, _f, _a} = from, to: {^module, _g, _b} = to} <- calls,
        from != to,
        reduce: %{} do
      acc -> Map.update(acc, from, [to], &[to | &1])
    end
  end

  # BFS from `start` through private functions; a public function reached is a link
  # and the walk stops there.
  defp reach(start, local, public) do
    walk(Map.get(local, start, []), local, public, MapSet.new([start]), %{
      public: [],
      privates: []
    })
  end

  defp walk([], _local, _public, _seen, acc),
    do: %{public: Enum.sort(acc.public), privates: Enum.sort(acc.privates)}

  defp walk([next | rest], local, public, seen, acc) do
    cond do
      MapSet.member?(seen, next) ->
        walk(rest, local, public, seen, acc)

      MapSet.member?(public, next) ->
        walk(rest, local, public, MapSet.put(seen, next), %{acc | public: [next | acc.public]})

      true ->
        walk(
          rest ++ Map.get(local, next, []),
          local,
          public,
          MapSet.put(seen, next),
          %{acc | privates: [next | acc.privates]}
        )
    end
  end

  defp struct_users(%Graph{struct_uses: uses}, module, public, reach) do
    users =
      for %StructUse{from: {^module, _f, _a} = from, struct: ^module} <- uses,
          into: MapSet.new(),
          do: from

    Enum.filter(public, fn mfa ->
      MapSet.member?(users, mfa) or Enum.any?(reach[mfa].privates, &MapSet.member?(users, &1))
    end)
  end

  defp callback_groups(%Model{graph: graph} = model, module, node, public) do
    external = if model.effects, do: model.effects.callbacks, else: %{}

    for behaviour <- node.behaviours do
      callbacks =
        case Map.get(graph.modules, behaviour) do
          %ModuleNode{callbacks: callbacks} -> callbacks
          nil -> Map.get(external, behaviour, [])
        end

      Enum.filter(public, fn {^module, name, arity} -> {name, arity} in callbacks end)
    end
  end

  defp chain([first | rest]), do: Enum.map(rest, &{first, &1})
  defp chain([]), do: []

  # --- naming ----------------------------------------------------------------------

  defp owned_type(%Graph{} = graph, module, functions, privates) do
    returned =
      for mfa <- functions,
          {:ok, owner} <- [Ownership.output_owner(graph, mfa)],
          owner != module,
          do: owner

    built =
      for %StructUse{from: from, struct: struct, op: :build} <- graph.struct_uses,
          from in functions or from in privates,
          struct != module,
          Map.has_key?(graph.modules, struct),
          do: struct

    case Enum.frequencies(returned ++ built) do
      empty when map_size(empty) == 0 -> nil
      counts -> counts |> Enum.sort_by(fn {type, n} -> {-n, type} end) |> hd() |> elem(0)
    end
  end

  # --- proposals -------------------------------------------------------------------

  defp module_proposals(model, module) do
    case components(model, module) do
      [_one] ->
        []

      several ->
        %Proposal{proposed: {:split, parts}} = split = split(model, module, several)
        taken = MapSet.new(parts, &elem(&1, 0))
        [split | shared_helpers(module, several, taken)]
    end
  end

  defp split(model, module, components) do
    # The module's own struct is its identity: the component using it keeps the name.
    # Otherwise the largest; `components` is sorted by first function and max_by keeps
    # the first of a tie, the component holding the alphabetically first function.
    kept =
      Enum.find(components, & &1.own_struct?) || Enum.max_by(components, &length(&1.functions))

    {parts, _taken} =
      Enum.map_reduce(components, MapSet.new([module]), fn
        ^kept, taken ->
          {{module, kept, []}, taken}

        component, taken ->
          {name, notes} = named(model, module, component, taken)
          {{name, component, notes}, MapSet.put(taken, name)}
      end)

    %Proposal{
      level: :module,
      subject: module,
      current: module,
      proposed:
        {:split, Enum.map(parts, fn {name, component, _note} -> {name, component.functions} end)},
      rule: :module_one_component,
      reason: :components,
      evidence: Enum.map(parts, &component_line/1),
      key:
        Enum.join(
          [
            "module_one_component",
            "module",
            inspect(module),
            components |> Enum.map(&function_set/1) |> Enum.sort() |> Enum.join(";")
          ],
          "|"
        )
    }
  end

  # The part's name: its owned type's, as the module's sibling; else its first public
  # function's, with a note to rename it. A name the module or another part already
  # has is never given twice: the next candidate is tried (`unique/3`).
  defp named(model, module, %{owned_type: type, functions: [{_m, name, arity} | _]}, taken) do
    by_function = Module.concat(module, Macro.camelize(Atom.to_string(name)))
    fallbacks = [by_function, Module.concat(module, Macro.camelize("#{name}#{arity}"))]

    candidates =
      if type == nil,
        do: fallbacks,
        else: [sibling(module, type) | fallbacks]

    target = unique(candidates, module, taken)
    {target, notes(type, target, sibling_or_nil(module, type)) ++ merge_note(model, target)}
  end

  defp sibling(module, type) do
    module
    |> Module.split()
    |> Enum.drop(-1)
    |> Kernel.++([type |> Module.split() |> List.last()])
    |> Module.concat()
  end

  defp sibling_or_nil(_module, nil), do: nil
  defp sibling_or_nil(module, type), do: sibling(module, type)

  defp notes(nil, target, nil), do: ["no owned type: rename #{inspect(target)}"]
  defp notes(type, target, target), do: ["owns %#{inspect(type)}{}"]

  defp notes(type, target, typed),
    do: ["owns %#{inspect(type)}{}", "#{inspect(typed)} is taken: rename #{inspect(target)}"]

  # The first candidate no one has, then `<module>.Part2`, `Part3`, ...: always one.
  defp unique(candidates, module, taken) do
    numbered = Stream.map(Stream.iterate(2, &(&1 + 1)), &Module.concat(module, "Part#{&1}"))

    candidates
    |> Stream.concat(numbered)
    |> Enum.find(&(not MapSet.member?(taken, &1)))
  end

  defp merge_note(%Model{graph: graph}, target),
    do:
      if(Map.has_key?(graph.modules, target),
        do: ["merge into existing #{inspect(target)}"],
        else: []
      )

  defp component_line({name, component, notes}) do
    Enum.join(
      [
        "#{inspect(name)}: #{Enum.map_join(component.functions, ", ", &ViolationKey.mfa/1)}"
        | notes
      ],
      "; "
    )
  end

  defp function_set(%{functions: functions}),
    do: Enum.map_join(functions, ",", fn {_m, name, arity} -> "#{name}/#{arity}" end)

  defp shared_helpers(module, components, taken) do
    components
    |> Enum.with_index()
    |> Enum.flat_map(fn {component, index} -> Enum.map(component.privates, &{&1, index}) end)
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
    |> Enum.filter(fn {_private, indexes} -> length(Enum.uniq(indexes)) >= 2 end)
    |> Enum.sort()
    |> Enum.map_reduce(taken, fn {{_m, name, arity} = private, indexes}, taken ->
      sharing = Enum.map(Enum.uniq(indexes), &Enum.at(components, &1))

      target =
        unique(
          [
            Module.concat(module, Macro.camelize(Atom.to_string(name))),
            Module.concat(module, Macro.camelize("#{name}#{arity}"))
          ],
          module,
          taken
        )

      {helper(module, private, target, sharing), MapSet.put(taken, target)}
    end)
    |> elem(0)
  end

  defp helper(module, private, target, sharing) do
    %Proposal{
      level: :function,
      subject: private,
      current: module,
      proposed: {:extract, target},
      rule: :module_one_component,
      reason: :shared_private_helper,
      evidence: Enum.map(sharing, &("component " <> function_set(&1))),
      key:
        Enum.join(
          ["module_one_component", "function", ViolationKey.mfa(private), inspect(target)],
          "|"
        )
    }
  end
end
