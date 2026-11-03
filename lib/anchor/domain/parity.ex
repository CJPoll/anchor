defmodule Anchor.Domain.Parity do
  @moduledoc """
  The AST/graph parity comparison (DND-5491) — a **Domain** module (ADR 001).
  Pure.

  The engine split: layering is a property of what the program does, so the
  graph engine (`layering`, DND-5442) is its authority. The AST dependency
  rules (`no_direct_dependency`, `no_transitive_dependency`) stay as its
  write-time early warnings (`Anchor.Domain.RuleSchema.early_warning_of/1`):
  they run before compile, with exact lines. On code where both can see
  everything (no macros), they must agree, and
  `test/anchor/integration/layering_parity_test.exs` holds them equal with
  the functions here:

    * `ast_rules_for/1` derives, from one `architecture:` section, the AST
      rules that say what its calls matrix says. Production configs are not
      generated with it; it makes the comparison mechanical.
    * `pairs_from_ast/1` and `pairs_from_graph/1` read each engine's findings
      as `{caller module, callee module}` pairs; `diff/2` compares them.
    * `uncovered/3` checks the transitive rule's findings, which the graph
      does not make as such: the graph judges direct calls, so a transitive
      finding A to C is covered when the graph flags a call X to Y on a
      chain A to X to Y to C.

  The derivation reads each bucket's `pattern:` selectors: an AST rule
  forbids callee modules by name, and only a module-name glob says which
  modules a bucket holds before compile. A bucket selected any other way, or
  a `same_context` matrix entry (an AST rule can forbid a bucket within the
  caller's context, never outside it), raises `ArgumentError`: such an
  architecture has no AST equivalent.
  """

  alias Anchor.Domain.Architecture
  alias Anchor.Domain.Architecture.Bucket
  alias Anchor.Domain.Violation

  @type pair :: {String.t(), String.t()}

  @doc """
  The AST rules equivalent to `architecture`'s calls matrix. For each
  bucket, per `pattern:` selector:

    * `parity:<bucket>:direct` (`no_direct_dependency`) and
      `parity:<bucket>:transitive` (`no_transitive_dependency`) forbid the
      buckets its row omits, by their patterns;
    * `parity:<bucket>:same_context` (`no_direct_dependency`, `same_context:
      true`) forbids each bucket its row allows only as `other_context`, within
      the caller's own context.

  A bucket whose row forbids nothing gets no rule.
  """
  @spec ast_rules_for(Architecture.t()) :: [map()]
  def ast_rules_for(%Architecture{buckets: buckets, calls: calls, context_depth: depth}) do
    patterns = Map.new(buckets, &{&1.name, patterns!(&1)})
    names = Enum.map(buckets, & &1.name)

    Enum.flat_map(buckets, fn %Bucket{name: name} ->
      row = Map.get(calls, name, [])
      refuse_same_context!(name, row)

      listed = row |> Enum.map(&elem(&1, 0)) |> Enum.uniq()
      any = for {bucket, :any} <- row, do: bucket
      other_only = (for({bucket, :other_context} <- row, do: bucket) |> Enum.uniq()) -- any

      forbidden = Enum.flat_map(names -- listed, &Map.fetch!(patterns, &1))
      scoped = Enum.flat_map(other_only, &Map.fetch!(patterns, &1))

      Enum.flat_map(Map.fetch!(patterns, name), fn pattern ->
        rules(name, pattern, :direct, forbidden, false, depth) ++
          rules(name, pattern, :transitive, forbidden, false, depth) ++
          rules(name, pattern, :same_context, scoped, true, depth)
      end)
    end)
  end

  @doc """
  The `{caller, callee}` pairs of the AST rules' findings. `results` holds,
  per checked file, the module it defines (as `inspect/1` prints it) and the
  violations its check returned. A violation whose trigger is not a module
  name (an unresolvable `alias`, a file that did not parse) names no callee.
  """
  @spec pairs_from_ast([{String.t(), [Violation.t()]}]) :: MapSet.t(pair())
  def pairs_from_ast(results) do
    for {caller, violations} <- results,
        %Violation{kind: :rule, trigger: trigger} <- violations,
        module_name?(trigger),
        into: MapSet.new(),
        do: {caller, trigger}
  end

  @doc """
  The `{caller, callee}` pairs of the `layering` rule's findings, read from
  their keys (`<id>|Caller.f/a|-> Callee.g/b`). A call whose function name is
  computed reaches no module: no pair.
  """
  @spec pairs_from_graph([Violation.t()]) :: MapSet.t(pair())
  def pairs_from_graph(violations) do
    for %Violation{key: key} <- violations,
        [_rule, from, "-> " <> to] <- [String.split(key, "|")],
        caller = module_of(from),
        callee = module_of(to),
        module_name?(caller) and module_name?(callee),
        into: MapSet.new(),
        do: {caller, callee}
  end

  @doc "The pairs only one engine reports, each list sorted."
  @spec diff(MapSet.t(pair()), MapSet.t(pair())) :: %{ast_only: [pair()], graph_only: [pair()]}
  def diff(ast_pairs, graph_pairs) do
    %{
      ast_only: ast_pairs |> MapSet.difference(graph_pairs) |> Enum.sort(),
      graph_only: graph_pairs |> MapSet.difference(ast_pairs) |> Enum.sort()
    }
  end

  @doc """
  The transitive findings `{a, c}` no graph finding covers, sorted. `{a, c}`
  is covered when the graph flags `{x, y}` with `x` reachable from `a` and
  `c` reachable from `y` (each reachable from itself) over `deps`, each
  module's direct dependencies.
  """
  @spec uncovered(MapSet.t(pair()), MapSet.t(pair()), %{String.t() => [String.t()]}) ::
          [pair()]
  def uncovered(transitive_pairs, graph_pairs, deps) do
    transitive_pairs
    |> Enum.reject(fn {a, c} ->
      from_a = reach(deps, a)
      Enum.any?(graph_pairs, fn {x, y} -> x in from_a and c in reach(deps, y) end)
    end)
    |> Enum.sort()
  end

  defp rules(_name, _pattern, _kind, [], _same_context, _depth), do: []

  defp rules(name, pattern, kind, forbidden, same_context, depth) do
    [
      %{
        type: if(kind == :transitive, do: :no_transitive_dependency, else: :no_direct_dependency),
        id: "parity:#{name}:#{kind}",
        pattern: pattern,
        paths: nil,
        uses_module: nil,
        recursive: false,
        forbidden_modules: [],
        forbidden_patterns: forbidden,
        forbidden_functions: [],
        allowed_callers: [],
        match: :reference,
        same_context: same_context,
        context_depth: depth,
        enforcement: :enforce,
        min_files: 1
      }
    ]
  end

  defp patterns!(%Bucket{name: name, selectors: selectors}) do
    Enum.map(selectors, fn
      {:pattern, glob} ->
        glob

      {key, _value} ->
        raise ArgumentError,
              "bucket #{name} selects by #{key}; the parity derivation reads pattern " <>
                "selectors only (an AST rule forbids callees by module name)"
    end)
  end

  defp refuse_same_context!(name, row) do
    case for {bucket, :same_context} <- row, do: bucket do
      [] ->
        :ok

      [bucket | _rest] ->
        raise ArgumentError,
              "row #{name} allows #{bucket}:same_context, which no AST rule can write: " <>
                "same_context: true forbids a bucket within the caller's context, never " <>
                "outside it"
    end
  end

  # `Mod.fun/arity` to `Mod`; `Mod` stays `Mod`.
  defp module_of(mfa) do
    case String.split(mfa, "/") do
      [name, _arity] -> name |> String.split(".") |> Enum.drop(-1) |> Enum.join(".")
      _no_arity -> mfa
    end
  end

  # An Elixir module name as `inspect/1` prints one: dot-separated segments
  # of letters, digits and `_`, the first starting upper-case. (No regex:
  # `Anchor.Domain.GlobPattern` is lib/'s only regex compiler, DND-1292.)
  defp module_name?(<<first, _rest::binary>> = name) when first in ?A..?Z,
    do: name |> String.split(".") |> Enum.all?(&segment?/1)

  defp module_name?(_name), do: false

  defp segment?(""), do: false

  defp segment?(segment),
    do: segment |> String.to_charlist() |> Enum.all?(&segment_char?/1)

  defp segment_char?(char) when char in ?a..?z or char in ?A..?Z or char in ?0..?9, do: true
  defp segment_char?(char), do: char == ?_

  defp reach(deps, start), do: reach(deps, [start], MapSet.new([start]))

  defp reach(_deps, [], seen), do: seen

  defp reach(deps, [module | rest], seen) do
    next = deps |> Map.get(module, []) |> Enum.reject(&MapSet.member?(seen, &1))
    reach(deps, rest ++ next, MapSet.union(seen, MapSet.new(next)))
  end
end
