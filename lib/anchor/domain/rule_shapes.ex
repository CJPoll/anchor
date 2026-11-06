defmodule Anchor.Domain.RuleShapes do
  @moduledoc """
  The conforming shape of every rule type, in one place (DND-5446) — a
  **Domain** module (ADR 001). Pure.

  `for/1` answers a parsed rule's shape (`Anchor.Domain.RuleShape`): the
  sentence a violation's `Fix:` ends with, and the one `mix anchor.explain`
  prints for the rule. It dispatches on the rule's `type` to the module that
  checks it: each AST type's `Anchor.Domain.Checks.*` module, each graph
  type's `Anchor.Domain.GraphRules.*` module. A type with no entry raises
  `FunctionClauseError`, and a test enumerates `RuleSchema.rule_types/0`, so
  a new rule type with no shape fails the suite.

  `with_fix/2` ends a rule violation's message with exactly one `Fix:`
  sentence: `<message>. Fix: <shape>`. A message that already carries a
  `Fix:` (a finding with a more specific one: an unresolvable alias, a
  layering route) is left as it is, so no issue ever carries two.
  """

  alias Anchor.Domain.Checks
  alias Anchor.Domain.GraphRules
  alias Anchor.Domain.Violation

  @modules %{
    aggregate_declarations: GraphRules.AggregateDeclarations,
    aggregate_write_sources: GraphRules.AggregateWriteSources,
    alphabetized_functions: Checks.AlphabetizedFunctions,
    analyses_complete: GraphRules.AnalysesComplete,
    case_on_bare_arg: Checks.CaseOnBareArg,
    context_acyclic: GraphRules.ContextAcyclic,
    effects_match_bucket: GraphRules.EffectsMatchBucket,
    function_placement: GraphRules.FunctionPlacement,
    interface: GraphRules.Interface,
    layering: GraphRules.Layering,
    max_file_length: Checks.MaxFileLength,
    module_pattern_restrictions: Checks.ModulePatternRestrictions,
    must_use_module: Checks.MustUseModule,
    no_comparison_in_if: Checks.NoComparisonInIf,
    no_direct_dependency: Checks.NoDependency,
    no_discarded_pure_expression: Checks.NoDiscardedPureExpression,
    no_discarding_arrow_in_with: Checks.NoDiscardingArrowInWith,
    no_forwarding_function: Checks.NoForwardingFunction,
    no_inert_hop: GraphRules.NoInertHop,
    no_transitive_dependency: Checks.NoTransitiveDependency,
    no_tuple_match_in_head: Checks.NoTupleMatchInHead,
    parameter_reaches_sink: GraphRules.ParameterReachesSink,
    reachable_from_root: GraphRules.ReachableFromRoot,
    single_control_flow: Checks.SingleControlFlow,
    struct_getter_convention: Checks.StructGetterConvention,
    struct_owned_by_module: Checks.StructOwnedByModule,
    struct_owned_by_module_flow: GraphRules.StructOwnedByModuleFlow
  }

  @fix "Fix:"

  @doc "The module whose `shape/1` gives rules of `type` their shape."
  @spec module(atom()) :: module()
  def module(type) when is_map_key(@modules, type), do: Map.fetch!(@modules, type)

  @doc "The conforming shape of `rule` (a parsed rule map with a `type`)."
  @spec for(map()) :: String.t()
  def for(%{type: type} = rule) when is_map_key(@modules, type), do: module(type).shape(rule)

  @doc """
  `message` (or a `%Violation{}`'s message) ending with ` Fix: <shape of
  rule>`, a full stop added first when it has none. Unchanged when it already
  carries a `Fix:`.
  """
  @spec with_fix(String.t() | Violation.t(), map()) :: String.t() | Violation.t()
  def with_fix(%Violation{message: message} = violation, rule),
    do: %{violation | message: with_fix(message, rule)}

  def with_fix(message, rule) when is_binary(message),
    do: append_fix(message, __MODULE__.for(rule))

  @doc """
  `with_fix/2` with the shape given: what a check's own detector uses, with
  its own `shape/1` (a rule map built in memory need not carry a `type`).
  """
  @spec with_shape(String.t() | Violation.t(), String.t()) :: String.t() | Violation.t()
  def with_shape(%Violation{message: message} = violation, shape),
    do: %{violation | message: append_fix(message, shape)}

  def with_shape(message, shape) when is_binary(message), do: append_fix(message, shape)

  @doc "`message` ending with ` Fix: <shape>`, unless it already carries a `Fix:`."
  @spec append_fix(String.t(), String.t()) :: String.t()
  def append_fix(message, shape) when is_binary(message) and is_binary(shape) do
    if String.contains?(message, @fix),
      do: message,
      else: "#{sentence(message)} #{@fix} #{shape}"
  end

  @doc "How many `Fix:` sentences `message` carries (the invariant is exactly one)."
  @spec fix_count(String.t()) :: non_neg_integer()
  def fix_count(message), do: length(String.split(message, @fix)) - 1

  @doc """
  `message` without its `Fix:` sentence: the finding, apart from how to fix it.
  Two rules that make one finding differ only there (each ends it with its own
  shape).
  """
  @spec without_fix(String.t()) :: String.t()
  def without_fix(message), do: message |> String.split(" #{@fix}", parts: 2) |> hd()

  defp sentence(message) do
    trimmed = String.trim_trailing(message)
    if String.ends_with?(trimmed, [".", "!", "?"]), do: trimmed, else: trimmed <> "."
  end
end
