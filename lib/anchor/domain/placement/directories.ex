defmodule Anchor.Domain.Placement.Directories do
  @moduledoc """
  Directory placement, D1 to D3 (DND-5462) — **Domain**, pure over the placement
  model and the classification.

  ## The module dominator tree

  `module_dominators/1` collapses the placement model's function call graph to its
  modules (an edge from `A` to `B` when a function of `A` calls one of `B`) and takes
  each module's immediate dominator from every module that holds a root, through the
  virtual root (`Anchor.Domain.Digraph.virtual_root/0`). A module no root reaches has
  none.

  ## The proposals

  A module is placed when it is classified, hand-written (`ModuleNode.generated?`
  `false`) and has a source file; any other is counted, never placed
  (`not_placed/1`). `proposals/3`:

    * **A directory is a dominator subtree within one bucket of one context.** A
      module whose immediate dominator `d` is another module of its bucket and
      context belongs in `d`'s companion directory, `d`'s source path without `.ex`
      (`lib/billing/domain/invoice.ex` gives `lib/billing/domain/invoice`), and `d`
      stays where it is as the directory's public module. Direct dominance only, so a
      chain nests one level per move. Reason `:dominator_subtree`.
    * **Shared modules.** A module whose immediate dominator is the virtual root and
      that holds no root is shared. When its callers are all in its own context it
      belongs at the bucket root (`bucket_root/3`), unless the tie-break
      (`Anchor.Domain.Placement.TieBreak`) picks one of its callers' directories;
      without evidence the proposal says `no tie-break evidence`. When its callers
      span contexts it belongs in a library context, and no path is invented: the
      evidence names the contexts. Callers all in one other context are the context
      rule's question (DND-5460), not a directory's: no proposal. Reason
      `:shared_module`.
    * **Inert directories.** A directory strictly below its bucket root that holds two
      or more placed modules of one bucket and context, each reached from a root,
      none of whose immediate dominator is a module of that directory or the
      directory's companion module (`<dir>.ex`), encapsulates nothing: flatten it, its
      modules moving up one level. Reason `:inert_directory`.

  A module already where it is proposed gets nothing.
  """

  alias Anchor.Domain.Classification
  alias Anchor.Domain.Digraph
  alias Anchor.Domain.Graph.ModuleNode
  alias Anchor.Domain.GraphAlgorithms
  alias Anchor.Domain.Model
  alias Anchor.Domain.Placement
  alias Anchor.Domain.Placement.TieBreak
  alias Anchor.Domain.Proposal

  @doc "Each module's immediate dominator, a module or the virtual root; see the moduledoc."
  @spec module_dominators(Placement.t()) :: %{module() => module() | atom()}
  def module_dominators(%Placement{functions: functions, roots: roots}) do
    root_modules = roots |> Enum.map(&elem(&1, 0)) |> Enum.uniq()

    edges =
      for {{to, _f, _a}, facts} <- functions,
          {from, _g, _b} <- facts.callers,
          from != to,
          uniq: true,
          do: {from, to}

    nodes =
      Enum.uniq(
        Enum.map(Map.keys(functions), &elem(&1, 0)) ++
          root_modules ++ Enum.flat_map(edges, &Tuple.to_list/1)
      )

    if root_modules == [],
      do: %{},
      else: GraphAlgorithms.dominators(Digraph.new(nodes, edges), root_modules).idom
  end

  @doc """
  The bucket root of `bucket` in `context`: the deepest directory holding every
  classified module of that bucket and context, or `nil` for none.
  """
  @spec bucket_root(Model.t(), String.t(), String.t() | nil) :: Path.t() | nil
  def bucket_root(%Model{classification: classification}, bucket, context) do
    dirs =
      for {_module, %Classification{bucket: ^bucket, context: ^context, source_file: file}} <-
            classification,
          is_binary(file),
          do: file |> Path.dirname() |> Path.split()

    case dirs do
      [] -> nil
      [first | rest] -> rest |> Enum.reduce(first, &common_prefix/2) |> Path.join()
    end
  end

  @doc """
  How many modules of the graph are not placed: generated or possibly so, unclassified,
  or with no source file.
  """
  @spec not_placed(Model.t()) :: non_neg_integer()
  def not_placed(%Model{graph: graph} = model),
    do: Enum.count(Map.keys(graph.modules), &(not placed?(model, &1)))

  @doc "The directory proposals, sorted by key; `evidence` is the tie-break's (`nil`: none)."
  @spec proposals(Placement.t(), Model.t(), map() | nil) :: [Proposal.t()]
  def proposals(%Placement{} = placement, %Model{} = model, evidence) do
    idom = module_dominators(placement)
    root_modules = placement.roots |> Enum.map(&elem(&1, 0)) |> MapSet.new()
    callers = module_callers(placement)

    moves =
      for {module, dominator} <- idom,
          placed?(model, module),
          proposal <-
            List.wrap(module_proposal(model, module, dominator, root_modules, callers, evidence)),
          do: proposal

    Enum.sort_by(moves ++ flattens(model, idom), & &1.key)
  end

  # --- one module ------------------------------------------------------------------

  defp module_proposal(model, module, dominator, root_modules, callers, evidence) do
    cond do
      dominator == Digraph.virtual_root() and not MapSet.member?(root_modules, module) ->
        shared(model, module, Map.get(callers, module, []), evidence)

      is_atom(dominator) and dominator != Digraph.virtual_root() ->
        interior(model, module, dominator)

      true ->
        nil
    end
  end

  defp interior(model, module, dominator) do
    class = model.classification[module]

    with true <- placed?(model, dominator),
         %Classification{bucket: bucket, context: context} = owner <-
           model.classification[dominator],
         true <- bucket == class.bucket and context == class.context do
      companion = Path.rootname(owner.source_file)
      current = Path.dirname(class.source_file)

      if current != companion,
        do:
          proposal(module, current, companion, :dominator_subtree, [
            "dominated by #{inspect(dominator)}"
          ])
    else
      _not_its_interior -> nil
    end
  end

  defp shared(model, module, callers, evidence) do
    class = model.classification[module]
    current = Path.dirname(class.source_file)

    contexts =
      callers
      |> Enum.map(&Map.get(model.classification, &1))
      |> Enum.reject(&is_nil/1)
      |> Enum.map(& &1.context)
      |> Enum.uniq()
      |> Enum.sort()

    reached =
      "reached from #{length(callers)} unrelated callers: #{Enum.map_join(callers, ", ", &inspect/1)}"

    case contexts do
      [context] when context == class.context ->
        root = bucket_root(model, class.bucket, context)

        candidates = [
          root
          | callers
            |> Enum.map(&caller_dir(model, &1))
            |> Enum.reject(&is_nil/1)
            |> Enum.uniq()
            |> Enum.sort()
        ]

        case TieBreak.choose(candidates, evidence) do
          {:none, ^current} ->
            nil

          {:none, dir} ->
            proposal(module, current, dir, :shared_module, [reached, "no tie-break evidence"])
        end

      # Callers all in one other context: the context rules' question. No classified
      # caller: nothing to place it by.
      one_or_none when length(one_or_none) < 2 ->
        nil

      several ->
        proposal(module, current, {:library_context, several}, :shared_module, [reached])
    end
  end

  defp caller_dir(model, caller) do
    case Map.get(model.classification, caller) do
      %Classification{source_file: file} when is_binary(file) -> Path.dirname(file)
      _none -> nil
    end
  end

  defp module_callers(%Placement{functions: functions}) do
    edges =
      for {{to, _f, _a}, facts} <- functions,
          {from, _g, _b} <- facts.callers,
          from != to,
          uniq: true,
          do: {to, from}

    edges
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
    |> Map.new(fn {to, froms} -> {to, Enum.sort(froms)} end)
  end

  # --- inert directories -----------------------------------------------------------

  defp flattens(model, idom) do
    model.classification
    |> Map.keys()
    |> Enum.filter(&placed?(model, &1))
    |> Enum.group_by(&Path.dirname(model.classification[&1].source_file))
    |> Enum.flat_map(fn {dir, modules} ->
      List.wrap(flatten(model, idom, dir, Enum.sort(modules)))
    end)
  end

  defp flatten(model, idom, dir, modules) do
    classes = Enum.map(modules, &model.classification[&1])
    places = classes |> Enum.map(&{&1.bucket, &1.context}) |> Enum.uniq()

    with [_, _ | _] <- modules,
         [{bucket, context}] <- places,
         root when is_binary(root) <- bucket_root(model, bucket, context),
         true <- String.starts_with?(dir, root <> "/"),
         true <- Enum.all?(modules, &Map.has_key?(idom, &1)),
         false <- Enum.any?(modules, &dominated_inside?(model, idom[&1], dir)) do
      %Proposal{
        level: :directory,
        subject: dir,
        current: dir,
        proposed: Path.dirname(dir),
        rule: :directory_placement,
        reason: :inert_directory,
        evidence: ["holds #{Enum.map_join(modules, ", ", &inspect/1)}"],
        key: key(dir, Path.dirname(dir))
      }
    else
      _not_inert -> nil
    end
  end

  defp dominated_inside?(model, dominator, dir) do
    case Map.get(model.classification, dominator) do
      %Classification{source_file: file} when is_binary(file) ->
        Path.dirname(file) == dir or file == dir <> ".ex"

      _other ->
        false
    end
  end

  # --- shared ----------------------------------------------------------------------

  defp placed?(%Model{graph: graph, classification: classification}, module) do
    match?(%ModuleNode{generated?: false}, Map.get(graph.modules, module)) and
      match?(
        %Classification{source_file: file} when is_binary(file),
        Map.get(classification, module)
      )
  end

  defp common_prefix(parts, acc) do
    acc |> Enum.zip(parts) |> Enum.take_while(fn {a, b} -> a == b end) |> Enum.map(&elem(&1, 0))
  end

  defp proposal(module, current, proposed, reason, evidence) do
    %Proposal{
      level: :directory,
      subject: module,
      current: current,
      proposed: proposed,
      rule: :directory_placement,
      reason: reason,
      evidence: evidence,
      key: key(inspect(module), proposed)
    }
  end

  defp key(subject, {:library_context, contexts}),
    do:
      Enum.join(
        ["directory_placement", "directory", subject, "library:" <> Enum.join(contexts, ",")],
        "|"
      )

  defp key(subject, dir), do: Enum.join(["directory_placement", "directory", subject, dir], "|")
end
