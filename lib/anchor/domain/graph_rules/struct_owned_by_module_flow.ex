defmodule Anchor.Domain.GraphRules.StructOwnedByModuleFlow do
  @moduledoc """
  The `struct_owned_by_module_flow` graph rule (DND-5454): only a struct's
  own module changes it, judged by the value flow of the compiled code — a
  **Domain** module (ADR 001), pure over the run's `Anchor.Domain.Model`.

  It is the flow half of struct ownership. The AST rule
  `struct_owned_by_module` (DND-5453) is the literal half: what one file's
  text decides. This rule reads each selected function's Core Erlang
  (`Anchor.Domain.StructFlow`), seeded by the `@type t` fields and `@spec`
  returns of every project module (`Anchor.Domain.StructTypes`), so it knows
  a value the text alone does not (`Turn.new() |> Map.put(...)`,
  `%{state.turn | ...}` through `@type t`, `%Game{turn: t}` in a head), and
  it sees code a macro injected, which the source does not hold.

  ## One finding per site

  A write site (a function and a line) the AST rule reports is not reported
  again, so the two rules never give two findings for one site:

    * a line that holds literal struct syntax naming another module's struct
      (`%S{...}`, `%S{s | ...}`: the graph's `:build` and `:update` struct
      uses), and every `struct(S, kw)` naming a module (never a known value);
    * a write on a value known only by a match (`%S{} = s`) in a function
      written in the source: the AST rule knows that variable too. The same
      write in a function a macro injected (its clauses carry the macro's
      `:context`) is reported here, at the line Core gives it (the `use`
      line).

  Each other site gives one violation, on the write the site starts from
  (for `put_in(game.turn.status, v)` on a spec-known `game`, the write on
  `game`, not the one on its `turn`).

  ## Owners and scope (shared with DND-5453)

  The owner of a function is its module, or for a protocol implementation
  (`__impl__(:for)`, read from its spec) the struct it is for. Like the AST
  rule, an implementation written with a list `for:` is owned by its
  protocol: the beams of such a `defimpl` are the implementations of one
  protocol sharing one source file and line. A write is judged when its
  struct is not the owner and is in scope
  (`Anchor.Domain.StructOwnership`). With `owned_namespaces`, a selected
  module that defines a struct outside every namespace is itself a
  violation, so a struct is never silently unchecked.

  The message is `<Mod.fun/a> changes <S> (<op>; known as <S> by <how>)
  outside <S>`, keyed `<id>|<Mod.fun/a>|<S>|<op>`.
  """

  @behaviour Anchor.Domain.GraphRule
  @behaviour Anchor.Domain.RuleShape

  alias Anchor.Domain.Failures
  alias Anchor.Domain.Graph.FunctionNode
  alias Anchor.Domain.Graph.ModuleNode
  alias Anchor.Domain.GraphRules
  alias Anchor.Domain.Model
  alias Anchor.Domain.StructFlow
  alias Anchor.Domain.StructOwnership
  alias Anchor.Domain.StructTypes
  alias Anchor.Domain.Violation
  alias Anchor.Domain.ViolationKey

  @impl Anchor.Domain.GraphRule
  def rule_type, do: :struct_owned_by_module_flow

  @impl Anchor.Domain.GraphRule
  def narrows?(_base_key, _key), do: false

  @impl Anchor.Domain.RuleShape
  def shape(_rule) do
    "only a struct's own module builds or changes it: call a function on the struct's " <>
      "module (e.g. S.new/1, S.put_<field>/2) instead; read fields and pattern-match freely"
  end

  @impl Anchor.Domain.GraphRule
  def check(%Model{graph: graph} = model, rule) do
    owned = StructOwnership.owned_namespaces(rule)
    index = StructTypes.index(graph)
    owners = owners(graph.modules)
    literal = literal_sites(graph, owners, owned)
    selected = GraphRules.select(model, rule)

    flows =
      for module <- selected,
          %ModuleNode{} = node <- [Map.get(graph.modules, module)],
          flow <- module_flows(node, index),
          do: flow

    judge = %{owners: owners, owned: owned, literal: literal, rule: rule}

    writes =
      for {node, mfa, function, _status, writes} <- flows,
          violation <- function_violations(node, mfa, function, writes, judge),
          do: violation

    unowned(selected, graph.modules, owned, rule) ++
      bound_hit(flows, rule, model) ++ writes
  end

  # A function whose value flow did not settle within StructFlow's pass bound
  # (DND-5676): its writes are what the last pass found from the seeds it
  # started with, so the rule fails closed naming it, never reads it as
  # complete. The bound named is the one the flow carries.
  defp bound_hit(flows, rule, %Model{config: config}) do
    case for({_node, mfa, _fun, {:bound_hit, passes}, _writes} <- flows, do: {mfa, passes}) do
      [] ->
        []

      [{_mfa, passes} | _rest] = hits ->
        [Failures.struct_flow_bound_hit(rule, Enum.map(hits, &elem(&1, 0)), passes, config.path)]
    end
  end

  # ---- owners ----

  # %{impl module => owner}: the struct it is for, or its protocol when one
  # `defimpl` with a list `for:` made it (same protocol, file and line).
  defp owners(modules) do
    impls =
      for {module, %ModuleNode{specs: specs} = node} <- modules,
          {:ok, target, protocol} <- [impl_of(specs)],
          do: {module, target, protocol, {protocol, node.source_file, node.line}}

    shared = impls |> Enum.frequencies_by(&elem(&1, 3)) |> Map.filter(fn {_k, n} -> n > 1 end)

    Map.new(impls, fn {module, target, protocol, site} ->
      {module, if(Map.has_key?(shared, site), do: protocol, else: target)}
    end)
  end

  defp impl_of(specs) do
    clauses = Map.get(specs, {:__impl__, 1}, [])

    with target when is_atom(target) and target != nil <- impl_answer(clauses, :for),
         protocol when is_atom(protocol) and protocol != nil <- impl_answer(clauses, :protocol) do
      {:ok, target, protocol}
    else
      _not_an_impl -> :error
    end
  end

  defp impl_answer(clauses, key) do
    Enum.find_value(clauses, fn
      {:"::", _meta, [{:__impl__, _cmeta, [^key]}, answer]} when is_atom(answer) -> answer
      _other -> nil
    end)
  end

  defp other?(struct, owner, owned),
    do: struct != owner and StructOwnership.in_scope?(struct, owned)

  # ---- the AST rule's sites ----

  # {mfa, line} of every literal struct syntax naming another module's struct.
  defp literal_sites(graph, owners, owned) do
    for %{op: op, from: {module, _f, _a} = from, struct: struct, line: line} <- graph.struct_uses,
        op in [:build, :update],
        other?(struct, Map.get(owners, module, module), owned),
        into: MapSet.new(),
        do: {from, line}
  end

  # ---- writes ----

  # Each function of `node` with Core: its value flow's writes, and whether
  # the flow settled (`{:bound_hit, passes}` when it did not).
  defp module_flows(%ModuleNode{module: module} = node, index) do
    for {{name, arity}, %FunctionNode{core: core} = function} <- Enum.sort(node.functions),
        core != nil do
      {status, writes} = flow(StructFlow.writes(core, index, module))
      {node, {module, name, arity}, function, status, writes}
    end
  end

  defp flow({:ok, writes}), do: {:ok, writes}
  defp flow({:bound_hit, passes, writes}), do: {{:bound_hit, passes}, writes}

  defp function_violations(%ModuleNode{module: module} = node, mfa, function, writes, judge) do
    generated? = generated?(function)
    owner = Map.get(judge.owners, module, module)

    for {line, site} <- sites(writes, owner, judge.owned),
        not MapSet.member?(judge.literal, {mfa, line}),
        not Enum.any?(site, &(&1.how == :matched and not generated?)),
        do: violation(mfa, node, outermost(site), judge.rule)
  end

  # The write on the value a site starts from: not a field of another write's
  # struct there (`put_in(game.turn.status, v)` writes `game`, then its turn).
  defp outermost([first | _rest] = writes) do
    structs = MapSet.new(writes, & &1.struct)

    Enum.find(writes, first, fn
      %{how: {:field, container, _field}} -> not MapSet.member?(structs, container)
      _root -> true
    end)
  end

  # The writes to another module's struct, grouped by line in first-seen order.
  defp sites(writes, owner, owned) do
    writes
    |> Enum.filter(&other?(&1.struct, owner, owned))
    |> Enum.group_by(& &1.line)
    |> Enum.sort_by(fn {line, _writes} -> line || 0 end)
  end

  # A function a macro injected: its clauses carry the macro's `:context`.
  defp generated?(%FunctionNode{clauses: clauses}) do
    Enum.any?(clauses, fn
      {meta, _args, _guards, _body} when is_list(meta) -> Keyword.has_key?(meta, :context)
      _other -> false
    end)
  end

  defp violation(mfa, node, write, rule) do
    struct = inspect(write.struct)
    caller = ViolationKey.mfa(mfa)

    %Violation{
      filename: node.source_file,
      line: write.line || function_line(node, mfa),
      trigger: caller,
      rule_id: Map.get(rule, :id),
      key: ViolationKey.graph_key(rule, caller, "#{struct}|#{write.op}"),
      message:
        "#{caller} changes #{struct} (#{write.op}; known as #{struct} by " <>
          "#{how_text(write.how, struct)}) outside #{struct}: call a function on #{struct} instead " <>
          "(e.g. #{struct}.put_<field>/2). Fix: " <> shape(rule)
    }
  end

  defp function_line(%ModuleNode{functions: functions}, {_module, name, arity}) do
    case Map.get(functions, {name, arity}) do
      %FunctionNode{line: line} -> line
      nil -> nil
    end
  end

  defp how_text(:matched, struct), do: "a match on %#{struct}{}"
  defp how_text({:spec, mfa}, _struct), do: "the @spec of #{ViolationKey.mfa(mfa)}"

  defp how_text({:field, struct, field}, _struct),
    do: "the @type t of #{inspect(struct)} (field #{inspect(field)})"

  # ---- owned_namespaces ----

  defp unowned(_selected, _modules, :all, _rule), do: []

  defp unowned(selected, modules, owned, rule) do
    for module <- selected,
        %ModuleNode{struct_fields: [_ | _]} = node <- [Map.get(modules, module)],
        not StructOwnership.in_scope?(module, owned) do
      name = inspect(module)

      %Violation{
        filename: node.source_file,
        line: node.line,
        trigger: name,
        rule_id: Map.get(rule, :id),
        key: ViolationKey.graph_key(rule, name, "outside owned_namespaces"),
        message:
          "#{name} defines a struct outside owned_namespaces, so no write to it is ever " <>
            "checked. Fix: add its namespace to owned_namespaces, or stop selecting #{name}."
      }
    end
  end
end
