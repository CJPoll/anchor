defmodule Anchor.Domain.Demand do
  @moduledoc """
  Demand (absence) analysis over Core Erlang — **Domain**, pure (DND-5498;
  the shared contract is the Anchor causal engine epic, section 13).

  For every `def`/`defp` with Core it answers, per parameter and per field of
  it, whether the value can reach an observable use: the function's return
  value (always demanded in full, R2) or an effect
  (`Anchor.Domain.EffectPrimitives`; an escape through `send`, a spawned
  process, ETS, `:persistent_term` or the process dictionary is one). The
  answer is a demand (`Anchor.Domain.Demand.Lattice`): `:absent`,
  `{:used, fields}` or `:all`. F2 (DND-5470) reports the parameters that are
  `:absent`.

  ## Summaries and the fixpoint

  A function's summary is the demand on each of its parameters, reused at
  every call (`Anchor.Domain.Demand.Transfer` is one backward pass over one
  function, given its callees' summaries). Each lambda in a function has a
  summary too, keyed `{mfa, ordinal}` as the 0-CFA (`Anchor.Domain.Cfa`)
  names it, so an apply site gets the join of the summaries of the closures
  the 0-CFA resolves it to.

  `analyze/4` runs the passes bottom-up over the strongly connected
  components (`Anchor.Domain.GraphAlgorithms.sccs/1`) of the call graph:
  project calls, local calls, and the closures resolved at apply sites. Each
  component starts every member's summary at all-`:absent` and re-runs every
  member, in sorted order, against the previous round's summaries, joining
  each result into its summary, until a round changes nothing. Recursion
  that only passes a parameter to itself leaves it `:absent` (R5).

  The demands only grow, and their lattice has finite height (field demands
  are cut at depth 3 and keys are literals of the program), so a component
  stabilises. It is also bounded by `:max_rounds` rounds per component
  (default 50). A component that hits the bound is not a result: each of
  its members' parameters is `:all` (used), the member is listed in
  `imprecise` with reason `:bound_hit` (and a caller that passes it a
  parameter with `{:via, member}`), and `bound_hit` names it, so a lost run
  never reads as "unused".

  ## Imprecision

  The passes run twice: sound, and optimistic, in which an `:any` apply site
  and a call of code outside the tables (a library function that is neither
  pure nor an effect, a call on a variable module) demand nothing. A
  parameter whose two demands differ is imprecise: its use rests on code the
  analysis cannot see. `imprecise` maps each function with an imprecise
  parameter (or lambda parameter) to its reasons, sorted: the `:any` sites
  and unknown calls in its body (`t:Anchor.Domain.Demand.Transfer.reason/0`),
  and `{:via, closure}` for each function or lambda it calls that is
  imprecise itself. The sound demand is the summary.

  ## Not here

  The runner wiring (`needs: [:demand]`, the printed counts) is
  `Anchor.Managers.Graph` and `Anchor.Domain.GraphReport` (DND-5470).
  Macros are not analysed. Per-parameter `passes` are not split per field.
  """

  alias Anchor.Domain.Cfa
  alias Anchor.Domain.Core
  alias Anchor.Domain.Demand.Lattice
  alias Anchor.Domain.Demand.Param
  alias Anchor.Domain.Demand.Transfer
  alias Anchor.Domain.Digraph
  alias Anchor.Domain.EffectPrimitives
  alias Anchor.Domain.Graph
  alias Anchor.Domain.Graph.FunctionNode
  alias Anchor.Domain.Graph.ModuleNode
  alias Anchor.Domain.GraphAlgorithms

  @max_rounds 50

  defstruct summaries: %{},
            lambdas: %{},
            imprecise: %{},
            bound_hit: [],
            counts: %{
              functions: 0,
              parameters: 0,
              absent: 0,
              imprecise_parameters: 0,
              imprecise_functions: 0,
              components: 0,
              rounds: 0
            }

  @type reason :: Transfer.reason() | {:via, Transfer.closure()} | :bound_hit
  @type t :: %__MODULE__{
          summaries: %{mfa() => [Param.t()]},
          lambdas: %{{mfa(), non_neg_integer()} => [Lattice.t()]},
          imprecise: %{mfa() => [reason()]},
          bound_hit: [mfa()],
          counts: %{
            functions: non_neg_integer(),
            parameters: non_neg_integer(),
            absent: non_neg_integer(),
            imprecise_parameters: non_neg_integer(),
            imprecise_functions: non_neg_integer(),
            components: non_neg_integer(),
            rounds: non_neg_integer()
          }
        }

  @doc """
  Analyses every `def`/`defp` of `graph` that has Core, with `cfa` (a
  `Anchor.Domain.Cfa.analyze/3` result over the same graph) resolving apply
  sites, and `effects` the extra effect tokens (`.anchor.yml`'s
  `architecture.effects`; a token that does not parse raises). `opts`:
  `:max_rounds`, the bound on rounds per component.
  """
  @spec analyze(Graph.t(), Cfa.t(), [String.t()], keyword()) :: t()
  def analyze(%Graph{} = graph, %Cfa{} = cfa, effects, opts \\ []) when is_list(effects) do
    max_rounds = max_rounds!(Keyword.get(opts, :max_rounds, @max_rounds))
    functions = project_functions(graph)
    program = program(functions, cfa, EffectPrimitives.parse_extra!(effects))
    components = components(functions, program)
    start = %{sound: %{}, optimistic: %{}, results: %{}, bound_hit: [], rounds: 0}
    state = Enum.reduce(components, start, &solve(&1, program, &2, max_rounds))
    report(program, state, length(components))
  end

  @doc """
  The demand on parameter `index` (0-based) of `mfa`. Raises for a function
  the analysis did not cover: an unanalysed function is never "unused".
  """
  @spec param(t(), mfa(), non_neg_integer()) :: Lattice.t()
  def param(%__MODULE__{summaries: summaries}, mfa, index) do
    case Map.fetch(summaries, mfa) do
      {:ok, params} when is_integer(index) and index >= 0 and index < length(params) ->
        Enum.at(params, index).demand

      _missing ->
        raise ArgumentError,
              "Demand.param/3: #{inspect(mfa)} parameter #{index} was not analysed. " <>
                "Fix: ask only for a def/defp with Core of the analysed graph."
    end
  end

  defp max_rounds!(rounds) when is_integer(rounds) and rounds > 0, do: rounds

  defp max_rounds!(rounds) do
    raise ArgumentError,
          "Demand.analyze/4: :max_rounds must be a positive integer, got #{inspect(rounds)}. " <>
            "Fix: pass a positive integer, or leave it out for the default (#{@max_rounds})."
  end

  # --- the program -------------------------------------------------------------------

  defp project_functions(%Graph{modules: modules}) do
    for {module, %ModuleNode{functions: functions}} <- modules,
        {{name, arity}, %FunctionNode{kind: kind, core: core}} <- functions,
        kind in [:def, :defp] and core != nil do
      {{module, name, arity}, Core.label(core)}
    end
    |> Enum.sort_by(&elem(&1, 0))
  end

  defp program(functions, cfa, effects) do
    lambdas =
      Map.new(functions, fn {mfa, core} ->
        {mfa,
         core
         |> Core.lambdas()
         |> Enum.map(fn {ordinal, fun} -> {{mfa, ordinal}, length(:cerl.fun_vars(fun))} end)}
      end)

    %{
      cores: Map.new(functions),
      arities: Map.new(functions, fn {{_m, _f, arity} = mfa, _core} -> {mfa, arity} end),
      lambdas: lambdas,
      cfa: cfa,
      effects: effects
    }
  end

  # The call graph's components, callees first.
  defp components(functions, program) do
    nodes = Enum.map(functions, &elem(&1, 0))
    edges = Enum.flat_map(functions, fn {mfa, core} -> edges(mfa, core, program) end)
    nodes |> Digraph.new(edges) |> GraphAlgorithms.sccs()
  end

  defp edges(mfa, core, program) do
    module = elem(mfa, 0)

    core
    |> :cerl.fun_body()
    |> then(
      &:cerl_trees.fold(fn node, acc -> callees(node, mfa, module, program) ++ acc end, [], &1)
    )
    |> Enum.filter(&Map.has_key?(program.cores, &1))
    |> Enum.uniq()
    |> Enum.map(&{mfa, &1})
  end

  defp callees(node, mfa, module, program) do
    case :cerl.type(node) do
      # A call is an edge to its callee, and a call that is an apply site
      # (`apply/2`, a `HigherOrder` function) to the closures it resolves to.
      :call ->
        [
          Core.call_mfa(node)
          | Enum.flat_map(Core.site_ordinals(node), &site_owners({mfa, &1}, program.cfa))
        ]

      :apply ->
        operator = :cerl.apply_op(node)

        if :cerl.is_c_fname(operator) do
          {name, arity} = :cerl.var_name(operator)
          [{module, name, arity}]
        else
          node |> Core.site_ordinals() |> Enum.flat_map(&site_owners({mfa, &1}, program.cfa))
        end

      _other ->
        []
    end
  end

  defp site_owners(site_id, cfa) do
    case Cfa.closures_at(cfa, site_id) do
      {:ok, closures} -> Enum.map(closures, &closure_owner/1)
      _any -> []
    end
  end

  defp closure_owner({mfa, ordinal}) when is_integer(ordinal), do: mfa
  defp closure_owner(mfa), do: mfa

  # --- the fixpoint -------------------------------------------------------------------

  defp solve(members, program, state, max_rounds) do
    start = Map.new(Enum.flat_map(members, &bottoms(&1, program)))

    state = %{
      state
      | sound: Map.merge(state.sound, start),
        optimistic: Map.merge(state.optimistic, start)
    }

    round(members, program, state, 1, max_rounds)
  end

  defp bottoms(mfa, program) do
    [{mfa, List.duplicate(:absent, Map.fetch!(program.arities, mfa))}] ++
      Enum.map(Map.fetch!(program.lambdas, mfa), fn {id, arity} ->
        {id, List.duplicate(:absent, arity)}
      end)
  end

  # The bound: every member's (and lambda's) parameters become `:all`, and
  # `:absent` in the optimistic summaries, so the members and every caller
  # that passes them a parameter read as imprecise.
  defp round(members, program, state, round, max_rounds) when round > max_rounds do
    ids = Enum.flat_map(members, &bottoms(&1, program))
    tops = Map.new(ids, fn {id, params} -> {id, Enum.map(params, fn _param -> :all end)} end)

    %{
      state
      | sound: Map.merge(state.sound, tops),
        optimistic: Map.merge(state.optimistic, Map.new(ids)),
        rounds: state.rounds + max_rounds,
        bound_hit: state.bound_hit ++ members
    }
  end

  defp round(members, program, state, round, max_rounds) do
    results =
      Map.new(members, fn mfa ->
        core = Map.fetch!(program.cores, mfa)

        {mfa,
         %{
           sound: run(core, mfa, :sound, state, program),
           optimistic: run(core, mfa, :optimistic, state, program)
         }}
      end)

    sound = Enum.reduce(results, state.sound, &merge(&1, &2, :sound))
    optimistic = Enum.reduce(results, state.optimistic, &merge(&1, &2, :optimistic))
    changed? = sound != state.sound or optimistic != state.optimistic

    state = %{
      state
      | sound: sound,
        optimistic: optimistic,
        results: Map.merge(state.results, results)
    }

    if changed?,
      do: round(members, program, state, round + 1, max_rounds),
      else: %{state | rounds: state.rounds + round}
  end

  defp run(core, mfa, mode, state, program) do
    Transfer.function(core, %{
      mfa: mfa,
      mode: mode,
      summaries: Map.fetch!(state, mode),
      cfa: program.cfa,
      effects: program.effects
    })
  end

  defp merge({mfa, results}, summaries, mode) do
    %{params: params, lambdas: lambdas} = Map.fetch!(results, mode)

    lambdas
    |> Enum.map(fn {ordinal, lambda_params} -> {{mfa, ordinal}, lambda_params} end)
    |> List.insert_at(0, {mfa, params})
    |> Enum.reduce(summaries, fn {id, new}, summaries ->
      Map.update(
        summaries,
        id,
        new,
        &Enum.zip_with(&1, new, fn old, n -> Lattice.join(old, n) end)
      )
    end)
  end

  # --- the report ----------------------------------------------------------------------

  defp report(program, state, components) do
    functions = program.cores |> Map.keys() |> Enum.sort()
    bound = MapSet.new(state.bound_hit)
    imprecise_ids = imprecise_ids(state)

    summaries =
      Map.new(functions, fn mfa ->
        sound = Map.fetch!(state.sound, mfa)
        optimistic = Map.fetch!(state.optimistic, mfa)
        passes = state.results |> Map.fetch!(mfa) |> Map.fetch!(:sound) |> Map.fetch!(:passes)

        params =
          [sound, optimistic, passes]
          |> Enum.zip()
          |> Enum.map(fn {demand, opt, pass} ->
            %Param{demand: demand, passes: pass, imprecise?: demand != opt or mfa in bound}
          end)

        {mfa, params}
      end)

    imprecise =
      functions
      |> Enum.filter(&(&1 in bound or function_imprecise?(&1, program, imprecise_ids)))
      |> Map.new(&{&1, reasons(&1, state, bound, imprecise_ids)})

    lambdas =
      for {_mfa, ids} <- program.lambdas, {id, _arity} <- ids, into: %{} do
        {id, Map.fetch!(state.sound, id)}
      end

    params = summaries |> Map.values() |> List.flatten()

    %__MODULE__{
      summaries: summaries,
      lambdas: lambdas,
      imprecise: imprecise,
      bound_hit: Enum.sort(state.bound_hit),
      counts: %{
        functions: length(functions),
        parameters: length(params),
        absent: Enum.count(params, &(&1.demand == :absent)),
        imprecise_parameters: Enum.count(params, & &1.imprecise?),
        imprecise_functions: map_size(imprecise),
        components: components,
        rounds: state.rounds
      }
    }
  end

  # Every function and lambda whose sound and optimistic summaries differ.
  defp imprecise_ids(state) do
    state.sound
    |> Enum.filter(fn {id, params} -> params != Map.fetch!(state.optimistic, id) end)
    |> MapSet.new(&elem(&1, 0))
  end

  defp function_imprecise?(mfa, program, ids) do
    MapSet.member?(ids, mfa) or
      Enum.any?(Map.fetch!(program.lambdas, mfa), fn {id, _arity} -> MapSet.member?(ids, id) end)
  end

  defp reasons(mfa, state, bound, ids) do
    if MapSet.member?(bound, mfa) do
      [:bound_hit]
    else
      %{reasons: direct, callees: callees} =
        state.results |> Map.fetch!(mfa) |> Map.fetch!(:sound)

      via =
        callees
        |> Enum.filter(&(MapSet.member?(ids, &1) and closure_owner(&1) != mfa))
        |> Enum.map(&{:via, &1})

      Enum.sort(MapSet.to_list(direct) ++ via)
    end
  end
end
