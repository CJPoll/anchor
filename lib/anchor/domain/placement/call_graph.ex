defmodule Anchor.Domain.Placement.CallGraph do
  @moduledoc """
  The function call graph the placement model reads (DND-5448) — **Domain**, pure
  over the graph.

  Nodes are the project's functions, macros included. An edge is:

    * a call of kind remote, local, capture or apply naming a project function;
    * a dynamic call with a known name, to each project function it can reach
      (`Anchor.Domain.DynamicCalls.candidates/2`);
    * a literal `{M, :f, args}` a function holds (a child spec's `start:`,
      `spawn(M, :f, [a])`, `Anchor.Domain.Core.mfa_references/1`);
    * a call that takes a module, a known name and arguments of unknown length
      (`spawn(M, :f, args)`, `Task.start(mod, :f, args)`, `Core.partial_mfa_calls/1`),
      to every project function of that name, of `M` when it names one;
    * another project module a function holds as a value (`children = [M, {N, arg}]`,
      `Core.held_atoms/1`), to that module's `child_spec/1`, because a supervisor calls
      it. That edge is what reaches the `start_link/1` the child spec names. A held
      name is not always a child, so this can keep an unused process reachable. A
      module's own name does not count: every `use GenServer` callback holds it.

  The last four also mark the target `named`: it must stay public.

  A call whose function name is computed (`apply(mod, name, args)`, `spawn(mod, name,
  args)`) has no edge, because any function could be its target: it is a `computed`
  site, and one in a reachable function loses reachability's precision. A variable
  application (`fun.(x)`) is not one: what it can reach was captured somewhere, and a
  capture is an edge. A function outside `Core.partial_mfa_calls/1`'s table that takes
  an MFA in variables is not read; what only it reaches reads as unreachable.
  """

  alias Anchor.Domain.Core
  alias Anchor.Domain.Digraph
  alias Anchor.Domain.DynamicCalls
  alias Anchor.Domain.Graph
  alias Anchor.Domain.Graph.Call
  alias Anchor.Domain.Graph.FunctionNode
  alias Anchor.Domain.Graph.ModuleNode

  defstruct digraph: nil, named: MapSet.new(), computed: []

  @type site :: %{from: mfa(), file: String.t() | nil, line: non_neg_integer() | nil}
  @type t :: %__MODULE__{digraph: Digraph.t(), named: MapSet.t(mfa()), computed: [site()]}

  @doc "The call graph of `graph`; see the moduledoc."
  @spec build(Graph.t()) :: t()
  def build(%Graph{} = graph) do
    nodes = functions(graph)
    known = MapSet.new(nodes)
    resolved = Enum.flat_map(graph.calls, &resolve(&1, graph, known))
    references = references(graph, known) ++ partial_targets(graph) ++ held_children(graph, known)
    named = for({:named, _from, to} <- resolved, do: to) ++ Enum.map(references, &elem(&1, 1))

    edges =
      for({_tag, from, to} when from != to <- resolved, do: {from, to}) ++
        Enum.reject(references, fn {from, to} -> from == to end)

    %__MODULE__{
      digraph: Digraph.new(nodes, Enum.filter(edges, &known_edge?(&1, known))),
      named: MapSet.new(named),
      computed:
        computed(graph) |> Kernel.++(partial_computed(graph)) |> Enum.uniq() |> Enum.sort()
    }
  end

  defp known_edge?({from, to}, known),
    do: MapSet.member?(known, from) and MapSet.member?(known, to)

  defp functions(%Graph{modules: modules}) do
    for {module, %ModuleNode{functions: functions}} <- modules,
        {{name, arity}, %FunctionNode{}} <- functions,
        do: {module, name, arity}
  end

  defp resolve(%Call{to: {:dynamic, nil, _arity, _receiver}}, _graph, _known), do: []

  defp resolve(%Call{from: from, to: {:dynamic, name, arity, _receiver}}, graph, known) do
    for module <- DynamicCalls.candidates(graph, {name, arity}),
        {{^name, candidate}, %FunctionNode{kind: :def}} <- functions_of(graph, module),
        arity == nil or candidate == arity,
        MapSet.member?(known, {module, name, candidate}),
        do: {:named, from, {module, name, candidate}}
  end

  defp resolve(%Call{from: from, to: {_module, _name, _arity} = to}, _graph, known) do
    if MapSet.member?(known, to), do: [{:call, from, to}], else: []
  end

  defp functions_of(%Graph{modules: modules}, module),
    do: modules |> Map.fetch!(module) |> Map.fetch!(:functions)

  defp references(%Graph{modules: modules}, known) do
    for {module, %ModuleNode{functions: functions}} <- modules,
        {{name, arity}, %FunctionNode{core: core}} when core != nil <- functions,
        target <- Core.mfa_references(core),
        MapSet.member?(known, target),
        do: {{module, name, arity}, target}
  end

  defp held_children(%Graph{modules: modules}, known) do
    for {module, %ModuleNode{functions: functions}} <- modules,
        {{name, arity}, %FunctionNode{core: core}} when core != nil <- functions,
        held <- Core.held_atoms(core),
        held != module,
        MapSet.member?(known, {held, :child_spec, 1}),
        do: {{module, name, arity}, {held, :child_spec, 1}}
  end

  defp computed(%Graph{calls: calls} = graph) do
    calls
    |> Enum.filter(&computed_name?/1)
    |> Enum.map(fn %Call{from: {module, _f, _a} = from, line: line} ->
      %{from: from, file: source_file(graph, module), line: line}
    end)
  end

  defp partial_calls(%Graph{modules: modules}) do
    for {module, %ModuleNode{functions: functions}} <- modules,
        {{name, arity}, %FunctionNode{core: core}} when core != nil <- functions,
        call <- Core.partial_mfa_calls(core),
        do: {{module, name, arity}, call}
  end

  defp partial_computed(graph) do
    for {{module, _f, _a} = from, %{name: nil, line: line}} <- partial_calls(graph),
        do: %{from: from, file: source_file(graph, module), line: line}
  end

  defp partial_targets(graph) do
    for {from, %{module: module, name: name}} when name != nil <- partial_calls(graph),
        target_module <- target_modules(module, name, graph),
        {{^name, arity}, %FunctionNode{kind: :def}} <- functions_of(graph, target_module),
        do: {from, {target_module, name, arity}}
  end

  defp target_modules(nil, name, graph), do: DynamicCalls.candidates(graph, {name, nil})

  defp target_modules(module, _name, %Graph{modules: modules}),
    do: if(Map.has_key?(modules, module), do: [module], else: [])

  # The one closure form is a variable application; it is `Model.cfa`'s to answer.
  defp computed_name?(%Call{kind: :apply, to: {:dynamic, nil, _arity, :variable}}), do: false
  defp computed_name?(%Call{to: {:dynamic, nil, _arity, _receiver}}), do: true
  defp computed_name?(%Call{}), do: false

  defp source_file(%Graph{modules: modules}, module) do
    case Map.get(modules, module) do
      %ModuleNode{source_file: file} -> file
      nil -> nil
    end
  end
end
