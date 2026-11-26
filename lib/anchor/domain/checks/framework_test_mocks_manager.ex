defmodule Anchor.Domain.Checks.FrameworkTestMocksManager do
  @moduledoc """
  Pure detection for the `framework_test_mocks_manager` check, the
  **Domain** bucket (ADR 001).

  A Framework test mocks the Manager: it asserts the Manager function is called
  with the expected arguments and that the entry point returns the expected
  value, with the layer below the entry point doubled (Anchor's own ADR 002).
  A test file a rule selects must therefore:

    1. set at least one **expectation** on a double the rule names in
       `mock_patterns` (module-name globs, `Anchor.Domain.GlobPattern`):
       `expect(Mock, :f, fun)`, `expect(Mock, :f, n, fun)`, `Mox.expect/3,4`,
       `Hammox.expect/3,4`, or the piped forms (`Mock |> expect(:f, fun)`,
       chains included). A `stub` is not an expectation: it passes with the
       call deleted, so it proves nothing about the call. An expectation of zero
       calls (`expect(Mock, :f, 0, fun)`) counts: it is how a test proves the
       Manager was not reached;
    2. **verify** its expectations: `setup :verify_on_exit!` (alone, in a
       list, or as `{Mox, :verify_on_exit!}` / `{Hammox, :verify_on_exit!}`),
       or a call of `verify_on_exit!` or `verify!/0` (bare, `Mox.` or
       `Hammox.`); `verify!(Mock)` verifies only that double, so it counts
       when it names a manager double the file expects on. An expectation nobody verifies passes when the endpoint
       never reaches the double, which is exactly the case this rule exists to
       catch: the Manager's seam is not bound to the mock.

  Names resolve through `Anchor.Domain.DependencyAnalyzer.resolved_modules/1`,
  so `alias App.Managers.SearchMock` then `expect(SearchMock, ...)` names
  `App.Managers.SearchMock`. A bare `expect` is Mox's or Hammox's unless the
  file defines its own `expect` of that arity (`def`, `defp`, `defmacro`,
  `defmacrop`), when it counts for nothing; the same holds for a bare
  `verify!` or `verify_on_exit!` (and for `setup :verify_on_exit!`, which
  calls `verify_on_exit!/1`). A definition's head names its own local
  function, so it never verifies.

  It fails closed: an expectation whose double is not a literal module name
  (a variable, an attribute, a function call) cannot be judged, so it never
  satisfies the rule; the violation names each such site. A file with no
  module, or one the rule selects by mistake, has no expectation and is
  reported.

  What this check cannot prove, and which other rules or the test run must
  (README, *framework_test_mocks_manager*): that the Framework module reaches
  the Manager only through the seam the double stands in at (a
  `no_direct_dependency` rule over the Framework code does), that test config
  binds the seam to this double (Mox's verification does, at run time, once
  the file verifies), that the double was declared for the Manager's contract
  (`Mox.defmock/2` requires `for:`), and that the test asserts the arguments
  and the returned value. It judges a file, not each test in it.

  Same AST and rules in, same violations out: no IO, no `Credo.*`.
  """

  use Anchor.Domain.Detector

  @doc "The rule type this detector reads (DND-8063)."
  @impl Anchor.Domain.Detector
  def rule_type, do: :framework_test_mocks_manager

  @doc "Detects one file's `%Anchor.Domain.Detector.Input{}` (DND-8063)."
  @impl Anchor.Domain.Detector
  def detect(%Anchor.Domain.Detector.Input{} = input),
    do: detect_violations(input.ast, input.rules)

  alias Anchor.Domain.AttributeNode
  alias Anchor.Domain.DependencyAnalyzer
  alias Anchor.Domain.GlobPattern
  alias Anchor.Domain.RuleShapes
  alias Anchor.Domain.Violation

  @behaviour Anchor.Domain.RuleShape

  @mock_libraries [Mox, Hammox]
  @verifiers [:verify_on_exit!, :verify!]
  @local_names [:expect | @verifiers]
  @definitions [:def, :defp, :defmacro, :defmacrop]

  @doc "The conforming shape: a violation's `Fix:` text."
  @impl Anchor.Domain.RuleShape
  @spec shape(map()) :: String.t()
  def shape(rule) do
    "expect the call on a manager double (#{patterns(rule)}) in this file, e.g. " <>
      "`expect(SearchMock, :search, fn input -> ... end)`, and verify it with " <>
      "`setup :verify_on_exit!`"
  end

  @doc """
  Returns a `%Violation{}` per selected rule the file does not satisfy.

  `rules` are the already-selected `framework_test_mocks_manager` rule maps,
  each carrying `:mock_patterns` (a non-empty list of module-name globs).
  """
  @spec detect_violations(Macro.t(), [map()]) :: [Violation.t()]
  def detect_violations(ast, rules) do
    facts = facts(ast)
    Enum.flat_map(rules, &judge(&1, facts))
  end

  defp judge(rule, facts) do
    patterns = Map.get(rule, :mock_patterns) || []
    {manager, other} = Enum.split_with(facts.resolved_sites, &manager_double?(&1.mock, patterns))

    rule
    |> verdict(manager, other, facts)
    |> List.wrap()
    |> Enum.map(&RuleShapes.with_shape(&1, shape(rule)))
  end

  defp verdict(rule, [], other, facts) do
    %Violation{
      message:
        "Framework test sets no expectation on a manager double (a module matching " <>
          "#{patterns(rule)})#{others(other)}#{unresolved(facts.unresolved_sites)}",
      line: 1,
      trigger: "expect"
    }
  end

  defp verdict(_rule, [first | _rest] = manager, _other, facts) do
    if verified?(manager, facts), do: nil, else: unverified(first)
  end

  # Every expectation in the file is verified (`verify_on_exit!`, `verify!/0`),
  # or `verify!/1` names one of the manager doubles the file expects on.
  defp verified?(manager, facts) do
    facts.verifies_all? or Enum.any?(manager, &(&1.mock in facts.verified_mocks))
  end

  defp unverified(first) do
    %Violation{
      message:
        "Framework test expects on #{inspect(first.mock)} but never verifies its " <>
          "expectations, so it passes when the endpoint never reaches the double",
      line: first.line,
      trigger: "verify_on_exit!"
    }
  end

  defp others([]), do: ""

  defp others(sites) do
    names = sites |> Enum.map(&inspect(&1.mock)) |> Enum.uniq() |> Enum.join(", ")
    "; its expectations name only #{names}, which no mock_patterns entry matches"
  end

  defp unresolved([]), do: ""

  defp unresolved(sites) do
    listed = Enum.map_join(sites, ", ", &"line #{&1.line} `#{&1.source}`")

    "; the double of #{length(sites)} expectation(s) is not a module name, so it cannot be judged: #{listed}"
  end

  defp patterns(rule), do: Enum.join(Map.get(rule, :mock_patterns) || [], ", ")

  defp manager_double?(mock, patterns) do
    name = Atom.to_string(mock)
    Enum.any?(patterns, &GlobPattern.matches_module_pattern?(name, &1))
  end

  # --- Facts: one walk over the file ----------------------------------------

  defp facts(ast) do
    ctx = %{
      resolved: DependencyAnalyzer.resolved_modules(ast),
      locals: local_arities(ast)
    }

    acc0 = %{sites: [], verifies_all?: false, verified_mocks: []}
    {_ast, acc} = Macro.prewalk(ast, acc0, &collect(&1, &2, ctx))
    sites = Enum.reverse(acc.sites)

    %{
      resolved_sites: Enum.filter(sites, &(&1.mock != nil)),
      unresolved_sites: Enum.filter(sites, &(&1.mock == nil)),
      verifies_all?: acc.verifies_all?,
      verified_mocks: acc.verified_mocks
    }
  end

  # A module attribute's name is never code (`@setup :verify_on_exit!` sets
  # an attribute); only its value is walked.
  defp collect({:@, _meta, _args} = node, acc, _ctx), do: {AttributeNode.without_name(node), acc}

  # A pipe into `expect`: the double is the pipe's head. The `expect` node is
  # replaced by its arguments, so the walk does not read it again as an
  # unpiped call (whose first argument would be the function name).
  defp collect({:|>, meta, [lhs, rhs]} = node, acc, ctx) do
    case expect_args(rhs, :piped, ctx) do
      {:ok, args} ->
        site = site(mock_node(lhs, ctx), node, ctx)
        {{:|>, meta, [lhs, {:__block__, [], args}]}, add_site(acc, site)}

      :error ->
        piped_verification(node, acc, ctx)
    end
  end

  defp collect({_name, _meta, args} = node, acc, ctx) when is_list(args) do
    acc = verification(verifies(node, ctx), acc)

    case expect_args(node, :direct, ctx) do
      {:ok, [mock | _rest]} -> {node, add_site(acc, site(mock_node(mock, ctx), node, ctx))}
      :error -> {node, acc}
    end
  end

  defp collect(node, acc, _ctx), do: {node, acc}

  # A pipe into a verifier is the call with the pipe's head as its first
  # argument (`Mock |> verify!()` is `verify!(Mock)`). The verifier node is
  # always replaced by its arguments, whatever it verifies, so the walk never
  # reads it again without that argument (as `verify!/0`, or at an arity the
  # file's own verifier does not have).
  defp piped_verification({:|>, meta, [lhs, {name, call_meta, args}]}, acc, ctx)
       when name in @verifiers and is_list(args),
       do: consume_verifier(meta, lhs, {name, call_meta, args}, acc, ctx)

  defp piped_verification(
         {:|>, meta, [lhs, {{:., _dot, [_qualifier, name]}, _m, args} = call]},
         acc,
         ctx
       )
       when name in @verifiers and is_list(args),
       do: consume_verifier(meta, lhs, call, acc, ctx)

  defp piped_verification(node, acc, _ctx), do: {node, acc}

  defp consume_verifier(meta, lhs, {call, call_meta, args}, acc, ctx) do
    found = verifies({call, call_meta, [lhs | args]}, ctx)
    {{:|>, meta, [lhs, {:__block__, [], args}]}, verification(found, acc)}
  end

  defp add_site(acc, site), do: %{acc | sites: [site | acc.sites]}

  defp site(mock, node, ctx) do
    %{mock: resolve(mock, ctx), line: line(node), source: Macro.to_string(mock)}
  end

  # The node that names the double: through pipes and nested `expect` calls
  # (each returns its double), down to the first argument.
  defp mock_node({:|>, _meta, [lhs, rhs]} = node, ctx) do
    case expect_args(rhs, :piped, ctx) do
      {:ok, _args} -> mock_node(lhs, ctx)
      :error -> node
    end
  end

  defp mock_node(node, ctx) do
    case expect_args(node, :direct, ctx) do
      {:ok, [mock | _rest]} -> mock_node(mock, ctx)
      :error -> node
    end
  end

  # `expect` call arguments: 3 or 4 when called directly, 2 or 3 when piped
  # into (the double is the pipe's head).
  defp expect_args({:expect, _meta, args}, mode, ctx) when is_list(args) do
    if local?(ctx, :expect, call_arity(args, mode)), do: :error, else: arity_ok(args, mode)
  end

  defp expect_args({{:., _dot, [qualifier, :expect]}, _meta, args}, mode, ctx)
       when is_list(args) do
    if resolve(qualifier, ctx) in @mock_libraries, do: arity_ok(args, mode), else: :error
  end

  defp expect_args(_node, _mode, _ctx), do: :error

  defp arity_ok(args, :direct) when length(args) in [3, 4], do: {:ok, args}
  defp arity_ok(args, :piped) when length(args) in [2, 3], do: {:ok, args}
  defp arity_ok(_args, _mode), do: :error

  defp call_arity(args, :piped), do: length(args) + 1
  defp call_arity(args, _mode), do: length(args)

  defp verification(:all, acc), do: %{acc | verifies_all?: true}
  defp verification({:mock, mock}, acc), do: %{acc | verified_mocks: [mock | acc.verified_mocks]}
  defp verification(:none, acc), do: acc

  # What a node verifies: `:all` for `setup :verify_on_exit!` (alone, in a
  # list, or `{Mox, :verify_on_exit!}`), `verify_on_exit!` and `verify!/0`;
  # `{:mock, module}` for `verify!(Mock)`, which verifies only that double
  # (`nil` when it is not a module name, which no expectation's double
  # equals, so it verifies nothing); `:none`
  # otherwise. A bare verifier the file defines itself is its own function,
  # and so is a definition's head (`defp verify!(conn)` names a local).
  defp verifies({:setup, _meta, [arg]}, ctx) do
    if setup_verifies?(arg, ctx), do: :all, else: :none
  end

  defp verifies({name, _meta, args}, ctx) when name in @verifiers and is_list(args) do
    if local?(ctx, name, length(args)), do: :none, else: verifier(name, args, ctx)
  end

  defp verifies({{:., _dot, [qualifier, name]}, _meta, args}, ctx)
       when name in @verifiers and is_list(args) do
    if resolve(qualifier, ctx) in @mock_libraries, do: verifier(name, args, ctx), else: :none
  end

  defp verifies(_node, _ctx), do: :none

  defp verifier(:verify!, [mock], ctx), do: {:mock, resolve(mock, ctx)}
  defp verifier(_name, _args, _ctx), do: :all

  # `setup :verify_on_exit!` calls `verify_on_exit!/1` with the context, so a
  # file defining its own `verify_on_exit!/1` verifies nothing by it.
  defp setup_verifies?(:verify_on_exit!, ctx), do: not local?(ctx, :verify_on_exit!, 1)

  defp setup_verifies?(list, ctx) when is_list(list),
    do: Enum.any?(list, &setup_verifies?(&1, ctx))

  defp setup_verifies?({qualifier, :verify_on_exit!}, ctx),
    do: resolve(qualifier, ctx) in @mock_libraries

  defp setup_verifies?(_arg, _ctx), do: false

  defp local?(ctx, name, arity), do: {name, arity} in ctx.locals

  # A literal module name, as the analyzer resolved it through the file's
  # aliases; `nil` for anything else (a variable, an attribute, a call, an
  # atom), and for a name the analyzer did not resolve, so it fails closed.
  defp resolve({:__aliases__, meta, _parts}, ctx),
    do: Map.get(ctx.resolved, {Keyword.get(meta, :line), Keyword.get(meta, :column)})

  defp resolve(_node, _ctx), do: nil

  defp line({_name, meta, _args}), do: Keyword.get(meta, :line, 1)

  # The `{name, arity}` of each `expect`, `verify!` and `verify_on_exit!` the
  # file defines (`def`, `defp`, `defmacro`, `defmacrop`; default arguments
  # give one arity each): a bare call of one is the file's own function, not
  # Mox's or Hammox's.
  defp local_arities(ast) do
    {_ast, arities} =
      Macro.prewalk(ast, MapSet.new(), fn
        {:@, _meta, _args} = node, acc ->
          {AttributeNode.without_name(node), acc}

        {kind, _meta, [head | _body]} = node, acc when kind in @definitions ->
          {node, MapSet.union(acc, defined_arities(head))}

        node, acc ->
          {node, acc}
      end)

    arities
  end

  defp defined_arities({:when, _meta, [head | _guards]}), do: defined_arities(head)

  defp defined_arities({name, _meta, args}) when name in @local_names and is_list(args) do
    defaults = Enum.count(args, &match?({:\\, _meta, _default}, &1))
    MapSet.new((length(args) - defaults)..length(args), &{name, &1})
  end

  # `def verify!, do: ...`: a bodied head with no parentheses is arity 0.
  defp defined_arities({name, _meta, context}) when name in @local_names and is_atom(context),
    do: MapSet.new([{name, 0}])

  defp defined_arities(_head), do: MapSet.new()
end
