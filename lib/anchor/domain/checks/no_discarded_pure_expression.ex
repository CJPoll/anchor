defmodule Anchor.Domain.Checks.NoDiscardedPureExpression do
  @moduledoc """
  Pure detection for the `no_discarded_pure_expression` rule (DND-5451, proposal
  F1) — the **Domain** bucket (ADR 001). Same AST and rules in, same
  violations out; no IO and no `Credo.*`.

  ## What it reports

  An expression whose value nobody uses and whose evaluation has no effect
  causes nothing: it is on no path to any output. This reports each such
  expression, in two positions:

    * **discarded position**: every element of a block (`{:__block__, _,
      exprs}`: a function, `fn`, clause, `do`/`else` or module body) except the
      last, which is the block's value;
    * **underscore binding**: the right side of `_ = expr` or `_name = expr`
      when that `=` is itself in a discarded position. (A final `_ = expr` is
      the block's value, so its right side is used.)

  Code inside `quote` is skipped: it is a macro's output, not this module's
  code.

  ## Pure, exactly

  `pure?/2` is true exactly for:

    1. a literal (atom, number, string, `nil`, `true`, `false`);
    2. a variable, or a module attribute read (`@attr`);
    3. a list, tuple, map, map update, struct, binary or interpolated string
       whose every element is pure;
    4. an operator (`#{inspect(~w(+ - * / ++ -- <> == != === !== < > <= >= and or not && || ! in .. |>)a)}`)
       over pure operands, and a field read `x.field` on a pure value (a pipe
       is the call it builds);
    5. a remote call `M.f(args)` where `M`, resolved through the aliases in
       scope (`Anchor.Domain.DependencyAnalyzer.resolved_modules/1`), is in
       the stdlib pure set or matches a `pure_patterns` glob, `f` does not end
       in `!`, `{M, f}` is not a stdlib effect (a clock or random read,
       `Stream.run/1`), and every argument is pure;
    6. a local call `f(args)` in a module whose name matches a
       `pure_patterns` glob, `f` not ending in `!` and not a `Kernel` or
       special form, every argument pure;
    7. a `Kernel` pure function (the guard-safe set, `to_string`, `inspect`)
       over pure arguments, bare or as `Kernel.f`;
    8. an `fn` whose every clause body is pure, a capture `&(...)` of a pure
       expression, and a capture `&M.f/n` or `&f/n` whose target is pure by 5,
       6 or 7.

  Anything else is not pure: an unknown call, a dynamic call (`mod.f()`,
  `apply/3`, `fun.()`), `send`, `raise`, `throw`, `exit`, `spawn`, a bang
  function, and every control-flow form (`case`, `cond`, `if`, `with`,
  `receive`, `try`), which is judged inside, not as a whole. A name the
  resolver cannot place is unknown, so not pure: a miss is possible, a false
  positive should not be.
  """

  alias Anchor.Domain.DependencyAnalyzer
  alias Anchor.Domain.GlobPattern
  alias Anchor.Domain.Violation

  @binary_operators ~w(+ - * / ++ -- <> == != === !== < > <= >= and or && || in .. |)a
  @unary_operators ~w(+ - ! not)a

  @stdlib_pure [
    Access,
    Atom,
    Base,
    Bitwise,
    Date,
    Enum,
    Float,
    Integer,
    Keyword,
    List,
    Map,
    MapSet,
    NaiveDateTime,
    Range,
    Stream,
    String,
    Time,
    Tuple,
    URI
  ]

  # Functions of the pure set that read the clock or the random state, or
  # whose whole job is an effect. Every arity.
  @stdlib_effectful [
    {Date, :utc_today},
    {Enum, :random},
    {Enum, :shuffle},
    {Enum, :take_random},
    {NaiveDateTime, :local_now},
    {NaiveDateTime, :utc_now},
    {Stream, :run},
    {Time, :utc_now}
  ]

  @kernel_pure MapSet.new(
                 ~w(abs div rem max min length elem hd tl tuple_size map_size byte_size
                    bit_size to_string inspect)a ++
                   for(
                     {name, _arity} <- Kernel.__info__(:functions) ++ Kernel.__info__(:macros),
                     String.starts_with?(Atom.to_string(name), "is_"),
                     do: name
                   )
               )

  # Bare names that are never a module-local function: every Kernel function
  # and macro, and every special form.
  @kernel_names MapSet.new(
                  Keyword.keys(Kernel.__info__(:functions)) ++
                    Keyword.keys(Kernel.__info__(:macros)) ++
                    Keyword.keys(Kernel.SpecialForms.__info__(:macros))
                )

  @trigger_length 60

  @shape "use the value (bind it and use the binding, or make it the block's last " <>
           "expression), or delete it. A call kept for its effect must be to a module " <>
           "outside pure_patterns and the stdlib pure set."

  @doc """
  Returns the violations in `ast` for each of the already-selected `rules`.
  A rule's `:pure_patterns` (module-name globs, default `[]`) declares extra
  pure modules.
  """
  @spec detect_violations(Macro.t(), [map()]) :: [Violation.t()]
  def detect_violations(ast, rules) do
    Enum.flat_map(rules, fn rule -> detect(ast, rule) end)
  end

  @doc "The conforming shape: a violation's `Fix:` text."
  @spec shape(map()) :: String.t()
  def shape(_rule), do: @shape

  defp detect(ast, rule) do
    ctx = %{
      resolved: DependencyAnalyzer.resolved_modules(ast),
      patterns: pure_patterns(rule),
      module: nil,
      line: nil
    }

    ast |> scan(ctx, []) |> Enum.reverse()
  end

  defp pure_patterns(rule) when is_map(rule) do
    case Map.get(rule, :pure_patterns) || Map.get(rule, "pure_patterns") do
      patterns when is_list(patterns) -> patterns
      _absent -> []
    end
  end

  # ---- the walk ----

  defp scan({:quote, _meta, args}, _ctx, acc) when is_list(args), do: acc

  defp scan({:defmodule, meta, [name, body]}, ctx, acc) do
    module = Map.get(ctx.resolved, position(name))
    scan(body, %{ctx | module: module, line: line(meta) || ctx.line}, acc)
  end

  defp scan({:__block__, meta, exprs}, ctx, acc) when is_list(exprs) and exprs != [] do
    ctx = %{ctx | line: line(meta) || ctx.line}
    {discarded, [last]} = Enum.split(exprs, -1)

    acc =
      Enum.reduce(discarded, acc, fn expr, acc ->
        acc = report_discarded(expr, ctx, acc)
        scan(expr, ctx, acc)
      end)

    scan(last, ctx, acc)
  end

  defp scan({form, meta, args}, ctx, acc) do
    ctx = %{ctx | line: line(meta) || ctx.line}
    acc = scan(form, ctx, acc)
    if is_list(args), do: scan(args, ctx, acc), else: acc
  end

  defp scan({left, right}, ctx, acc), do: scan(right, ctx, scan(left, ctx, acc))
  defp scan(list, ctx, acc) when is_list(list), do: Enum.reduce(list, acc, &scan(&1, ctx, &2))
  defp scan(_leaf, _ctx, acc), do: acc

  # An expression in a discarded position: an underscore binding discards its
  # right side; anything else is discarded whole.
  defp report_discarded({:=, _meta, [pattern, rhs]} = expr, ctx, acc) do
    if underscore?(pattern), do: report_if_pure(rhs, expr, ctx, acc), else: acc
  end

  defp report_discarded(expr, ctx, acc), do: report_if_pure(expr, expr, ctx, acc)

  defp report_if_pure(judged, shown, ctx, acc) do
    if pure?(judged, ctx), do: [violation(shown, ctx) | acc], else: acc
  end

  defp underscore?({name, _meta, ctx}) when is_atom(name) and is_atom(ctx),
    do: String.starts_with?(Atom.to_string(name), "_")

  defp underscore?(_pattern), do: false

  defp violation(expr, ctx) do
    %Violation{
      line: first_line(expr) || ctx.line,
      trigger: trigger(expr),
      message:
        "This expression's value is discarded and it has no effect, so it causes nothing. " <>
          "Fix: " <> @shape
    }
  end

  defp trigger(expr) do
    text = Macro.to_string(expr)

    if String.length(text) > @trigger_length,
      do: String.slice(text, 0, @trigger_length),
      else: text
  end

  # ---- Pure ----

  # 1. literals
  defp pure?(literal, _ctx) when is_atom(literal) or is_number(literal) or is_binary(literal),
    do: true

  # 2. a module attribute read (`@attr`, not `@attr value`)
  defp pure?({:@, _meta, [{name, _ameta, ctx}]}, _ctx) when is_atom(name) and is_atom(ctx),
    do: true

  # 3. containers
  defp pure?(list, ctx) when is_list(list), do: Enum.all?(list, &pure?(&1, ctx))
  defp pure?({left, right}, ctx), do: pure?(left, ctx) and pure?(right, ctx)

  defp pure?({container, _meta, elements}, ctx)
       when container in [:{}, :%{}, :<<>>] and is_list(elements),
       do: Enum.all?(elements, &pure?(&1, ctx))

  defp pure?({:%, _meta, [name, map]}, ctx), do: pure?(name, ctx) and pure?(map, ctx)
  defp pure?({:"::", _meta, [value, _type]}, ctx), do: pure?(value, ctx)
  defp pure?({:__aliases__, _meta, _parts}, _ctx), do: true

  # 4. operators; a pipe is the call it builds
  defp pure?({:|>, _meta, [left, right]}, ctx), do: piped_pure?(left, right, ctx)

  defp pure?({op, _meta, [left, right]}, ctx) when op in @binary_operators,
    do: pure?(left, ctx) and pure?(right, ctx)

  defp pure?({op, _meta, [operand]}, ctx) when op in @unary_operators, do: pure?(operand, ctx)

  defp pure?({:..//, _meta, [first, last, step]}, ctx),
    do: Enum.all?([first, last, step], &pure?(&1, ctx))

  # 8. anonymous functions and captures
  defp pure?({:fn, _meta, clauses}, ctx) when is_list(clauses),
    do: Enum.all?(clauses, &clause_pure?(&1, ctx))

  defp pure?({:&, _meta, [index]}, _ctx) when is_integer(index), do: true

  defp pure?({:&, _meta, [{:/, _smeta, [target, arity]}]}, ctx) when is_integer(arity),
    do: capture_target_pure?(target, ctx)

  defp pure?({:&, _meta, [expr]}, ctx), do: pure?(expr, ctx)

  # 5. remote calls (and 4. a field read on a pure value)
  defp pure?({{:., _dmeta, [receiver, fun]}, meta, args}, ctx)
       when is_atom(fun) and is_list(args) do
    case module_of(receiver, ctx) do
      {:ok, module} -> pure_function?(module, fun, ctx) and pure?(args, ctx)
      :not_a_module -> field_read?(meta, args) and pure?(receiver, ctx)
      :unknown -> false
    end
  end

  # 6. and 7. local calls
  defp pure?({name, _meta, args}, ctx) when is_atom(name) and is_list(args),
    do: local_pure?(name, ctx) and pure?(args, ctx)

  # 2. a variable
  defp pure?({name, _meta, context}, _ctx) when is_atom(name) and is_atom(context), do: true

  defp pure?(_other, _ctx), do: false

  defp piped_pure?(left, {call, meta, args}, ctx) when is_list(args) and call != :__aliases__,
    do: pure?({call, meta, [left | args]}, ctx)

  defp piped_pure?(_left, _right, _ctx), do: false

  defp clause_pure?({:->, _meta, [_args, body]}, ctx), do: body_pure?(body, ctx)
  defp clause_pure?(_clause, _ctx), do: false

  defp body_pure?({:__block__, _meta, exprs}, ctx), do: Enum.all?(exprs, &pure?(&1, ctx))
  defp body_pure?(body, ctx), do: pure?(body, ctx)

  defp capture_target_pure?({{:., _dmeta, [receiver, fun]}, _meta, []}, ctx) when is_atom(fun) do
    case module_of(receiver, ctx) do
      {:ok, module} -> pure_function?(module, fun, ctx)
      _not_a_module -> false
    end
  end

  defp capture_target_pure?({name, _meta, ctx_atom}, ctx)
       when is_atom(name) and is_atom(ctx_atom),
       do: local_pure?(name, ctx)

  defp capture_target_pure?(_target, _ctx), do: false

  # `x.field` parses as a zero-argument call written without parens.
  defp field_read?(meta, []), do: Keyword.get(meta, :no_parens, false)
  defp field_read?(_meta, _args), do: false

  # The module a call's receiver names: `{:ok, module}` when the source names
  # one the resolver placed, `:not_a_module` for a value (a variable, a call
  # result), and `:unknown` for a name the resolver could not place.
  defp module_of({:__aliases__, _meta, _parts} = name, ctx), do: lookup(name, ctx)
  defp module_of({:__MODULE__, _meta, c} = name, ctx) when is_atom(c), do: lookup(name, ctx)
  defp module_of(atom, _ctx) when is_atom(atom), do: {:ok, atom}
  defp module_of(_value, _ctx), do: :not_a_module

  defp lookup(name, ctx) do
    case Map.fetch(ctx.resolved, position(name)) do
      {:ok, module} -> {:ok, module}
      :error -> :unknown
    end
  end

  defp pure_function?(Kernel, fun, _ctx), do: MapSet.member?(@kernel_pure, fun)

  defp pure_function?(module, fun, ctx) do
    not bang?(fun) and {module, fun} not in @stdlib_effectful and
      (module in @stdlib_pure or pure_module?(module, ctx))
  end

  defp local_pure?(name, ctx) do
    cond do
      MapSet.member?(@kernel_pure, name) -> true
      MapSet.member?(@kernel_names, name) -> false
      bang?(name) -> false
      true -> ctx.module != nil and pure_module?(ctx.module, ctx)
    end
  end

  defp pure_module?(module, ctx) do
    name = Atom.to_string(module)
    Enum.any?(ctx.patterns, &GlobPattern.matches_module_pattern?(name, &1))
  end

  defp bang?(fun), do: fun |> Atom.to_string() |> String.ends_with?("!")

  # ---- positions ----

  defp position({_form, meta, _args}) when is_list(meta),
    do: {Keyword.get(meta, :line), Keyword.get(meta, :column)}

  defp position(_node), do: nil

  defp line(meta) when is_list(meta), do: Keyword.get(meta, :line)
  defp line(_meta), do: nil

  # The first line the expression carries. A bare literal carries none.
  defp first_line(expr) do
    {_expr, found} =
      Macro.prewalk(expr, nil, fn
        {_form, meta, _args} = node, nil when is_list(meta) -> {node, line(meta)}
        node, found -> {node, found}
      end)

    found
  end
end
