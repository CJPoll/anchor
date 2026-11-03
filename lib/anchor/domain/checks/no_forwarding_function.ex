defmodule Anchor.Domain.Checks.NoForwardingFunction do
  @moduledoc """
  Pure detection for the `no_forwarding_function` rule (DND-5452, proposal F4,
  the same-module half) — the **Domain** bucket (ADR 001). Same AST and rules
  in, same violations out; no IO and no `Credo.*`.

  ## What it reports

  A function whose every clause only hands its arguments, unchanged and in
  order, to another function of the same module is an inert hop: it adds
  depth and causes nothing. Inside one module no boundary is crossed, so the
  hop is always inert there. Cross-module hops are the graph rule
  `no_inert_hop`'s (DND-5463), which knows the boundaries.

  Per module body (the innermost `defmodule`; a nested module is its own),
  a **forwarding clause** of `f/n` is a `def`/`defp` clause whose:

    1. head arguments are `n` bare variables, pairwise distinct, none starting
       with `_`, none a default (`\\\\`), and with no `when` guard;
    2. body is exactly one expression (`do:` only: no `rescue`, `catch`,
       `else` or `after`) which, after pipe normalization (`x |> g(y)` is
       `g(x, y)`), is a call `g(v1, ..., vn)` or `__MODULE__.g(v1, ..., vn)`
       whose arguments are exactly the head variables in the same order;
    3. target `g/n` is a `def`/`defp` of the same module body (a default
       argument's arities included) and is not `f/n` itself.

  `f/n` is reported when every one of its clauses is a forwarding clause to
  the same `g/n`, and no `@impl` (other than `@impl false`) and no
  `@deprecated` sits between its first clause and the definition before it:
  a behaviour callback is a boundary, and a deprecated wrapper is an API
  transition. `defdelegate f(args), to: __MODULE__, as: :g` with distinct bare
  variable arguments is reported when `g/n` is defined here; a `defdelegate`
  to any other module is the graph rule's. A `defimpl` body is not a module
  body here (its functions are protocol callbacks), and code inside `quote` is
  skipped. A shape
  the detector does not recognise (an unquoted head, `unquote` in the body) is
  not reported: a miss is possible, a false report should not be.
  """

  alias Anchor.Domain.Violation

  @behaviour Anchor.Domain.RuleShape

  @shape "inline the hop: make the callers of f/n call g/n directly and delete f/n, or " <>
           "rename g/n to f/n (public if f/n was). Keep a forwarding function only where it " <>
           "crosses a boundary (a behaviour callback marked @impl, another module's public API)."

  @doc """
  Returns the violations in `ast` for each of the already-selected `rules`.
  The rule reads no key of its own.
  """
  @spec detect_violations(Macro.t(), [map()]) :: [Violation.t()]
  def detect_violations(ast, rules) do
    Enum.flat_map(rules, fn _rule -> ast |> module_bodies([]) |> Enum.flat_map(&detect/1) end)
  end

  @doc "The conforming shape: a violation's `Fix:` text."
  @impl Anchor.Domain.RuleShape
  @spec shape(map()) :: String.t()
  def shape(_rule), do: @shape

  # ---- module bodies (innermost defmodule; quote skipped; a defimpl is never one) ----

  defp module_bodies({:defmodule, _meta, [_name, [{:do, body} | _rest]]}, acc) do
    module_bodies(statements(body), [statements(body) | acc])
  end

  defp module_bodies({:quote, _meta, args}, acc) when is_list(args), do: acc

  defp module_bodies({form, _meta, args}, acc) when is_list(args),
    do: module_bodies(args, module_bodies(form, acc))

  defp module_bodies({left, right}, acc), do: module_bodies(right, module_bodies(left, acc))
  defp module_bodies(list, acc) when is_list(list), do: Enum.reduce(list, acc, &module_bodies/2)
  defp module_bodies(_leaf, acc), do: acc

  defp statements({:__block__, _meta, statements}), do: statements
  defp statements(nil), do: []
  defp statements(statement), do: [statement]

  # ---- one module body ----

  defp detect(statements) do
    entries = entries(statements)
    defined = entries |> Enum.flat_map(&arities/1) |> MapSet.new()

    entries
    |> Enum.group_by(&key/1)
    |> Enum.sort_by(fn {_key, [first | _rest]} -> first.line || 0 end)
    |> Enum.flat_map(fn {key, group} -> report(key, group, defined) end)
  end

  # Each def/defp clause and defdelegate in the body, in order, with the
  # boundary attributes written since the previous definition.
  defp entries(statements) do
    {entries, _attrs} =
      Enum.reduce(statements, {[], []}, fn statement, {entries, attrs} ->
        case entry(statement, attrs) do
          {:attribute, name, value} -> {entries, [{name, value} | attrs]}
          nil -> {entries, attrs}
          entry -> {[entry | entries], []}
        end
      end)

    Enum.reverse(entries)
  end

  defp entry({:@, _meta, [{name, _ameta, [value]}]}, _attrs) when name in [:impl, :deprecated],
    do: {:attribute, name, value}

  defp entry({kind, meta, [head | rest]}, attrs) when kind in [:def, :defp] do
    {name, args, guarded?} = signature(head)

    %{
      kind: :clause,
      name: name,
      args: args,
      guarded?: guarded?,
      body: body(rest),
      line: line(meta),
      exempt?: exempt?(attrs)
    }
  end

  defp entry({:defdelegate, meta, [head, opts]}, attrs) when is_list(opts) do
    {name, args, guarded?} = signature(head)

    %{
      kind: :delegate,
      name: name,
      args: args,
      guarded?: guarded?,
      opts: opts,
      line: line(meta),
      exempt?: exempt?(attrs)
    }
  end

  defp entry(_statement, _attrs), do: nil

  defp exempt?(attrs) do
    Enum.any?(attrs, fn
      {:impl, false} -> false
      {:impl, _value} -> true
      {:deprecated, _value} -> true
    end)
  end

  defp signature({:when, _meta, [head | _guards]}) do
    {name, args, _guarded?} = signature(head)
    {name, args, true}
  end

  defp signature({name, _meta, args}) when is_atom(name) and is_list(args),
    do: {name, args, false}

  defp signature({name, _meta, ctx}) when is_atom(name) and is_atom(ctx), do: {name, [], false}
  defp signature(_head), do: {nil, [], false}

  # Only a plain `do:` body can be a single forwarding expression.
  defp body([[{:do, body}]]), do: {:ok, body}
  defp body(_rest), do: :error

  defp key(%{name: name, args: args}), do: {name, length(args)}

  # Every arity the definition makes callable: one per default argument.
  defp arities(%{name: nil}), do: []

  defp arities(%{name: name, args: args}) do
    defaults = Enum.count(args, &match?({:\\, _meta, _default}, &1))
    total = length(args)
    for arity <- (total - defaults)..total, do: {name, arity}
  end

  # ---- the verdict for one f/n ----

  defp report({nil, _arity}, _group, _defined), do: []

  defp report({name, arity} = key, [first | _rest] = group, defined) do
    with false <- first.exempt?,
         {:ok, target} <- common_target(group),
         true <- target != key and MapSet.member?(defined, target) do
      [violation(name, arity, target, first.line)]
    else
      _not_reported -> []
    end
  end

  # The one target every entry of the group forwards to, or `:error`.
  defp common_target(group) do
    case group |> Enum.map(&target/1) |> Enum.uniq() do
      [{:ok, target}] -> {:ok, target}
      _none_or_several -> :error
    end
  end

  defp target(%{guarded?: true}), do: :error

  defp target(%{kind: :clause, args: args, body: {:ok, body}}) do
    with {:ok, vars} <- head_variables(args),
         {:ok, name, call_args} <- local_call(pipe(body)),
         true <- call_args == vars or :error do
      {:ok, {name, length(vars)}}
    end
  end

  defp target(%{kind: :delegate, name: name, args: args, opts: opts}) do
    with {:ok, vars} <- head_variables(args),
         true <- self_module?(Keyword.get(opts, :to)) or :error,
         as when is_atom(as) <- Keyword.get(opts, :as, name) do
      {:ok, {as, length(vars)}}
    else
      _not_a_self_delegate -> :error
    end
  end

  defp target(_entry), do: :error

  # The head's variable names, when every argument is a distinct bare
  # variable that does not start with `_`.
  defp head_variables(args) do
    names = Enum.map(args, &variable_name/1)

    if Enum.all?(names, &is_atom/1) and length(Enum.uniq(names)) == length(names),
      do: {:ok, names},
      else: :error
  end

  defp variable_name({name, _meta, ctx}) when is_atom(name) and is_atom(ctx) do
    if String.starts_with?(Atom.to_string(name), "_"), do: :error, else: name
  end

  defp variable_name(_pattern), do: :error

  # A bare variable reference, compared by name only (metadata differs).
  defp variable_ref({name, _meta, ctx}) when is_atom(name) and is_atom(ctx), do: name
  defp variable_ref(_arg), do: :not_a_variable

  # `x |> g(y)` is `g(x, y)`, recursively on the left.
  defp pipe({:|>, _meta, [left, {call, meta, args}]}) when is_list(args),
    do: {call, meta, [pipe(left) | args]}

  defp pipe(expr), do: expr

  # `g(args)` or `__MODULE__.g(args)`, with the arguments as variable names.
  defp local_call({name, _meta, args}) when is_atom(name) and is_list(args),
    do: {:ok, name, Enum.map(args, &variable_ref/1)}

  defp local_call({{:., _dmeta, [{:__MODULE__, _mmeta, ctx}, name]}, _meta, args})
       when is_atom(ctx) and is_atom(name) and is_list(args),
       do: {:ok, name, Enum.map(args, &variable_ref/1)}

  defp local_call(_expr), do: :error

  defp self_module?({:__MODULE__, _meta, ctx}) when is_atom(ctx), do: true
  defp self_module?(_to), do: false

  defp violation(name, arity, {target_name, target_arity}, line) do
    from = "#{name}/#{arity}"
    to = "#{target_name}/#{target_arity}"

    %Violation{
      line: line,
      trigger: from,
      message:
        "#{from} only forwards its arguments unchanged to #{to} in the same module: " <>
          "an inert hop. Fix: " <> @shape
    }
  end

  defp line(meta) when is_list(meta), do: Keyword.get(meta, :line)
  defp line(_meta), do: nil
end
