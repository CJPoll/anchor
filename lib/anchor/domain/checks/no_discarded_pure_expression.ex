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
       `Stream.run/1`), and every argument is pure. An argument a stdlib
       function may call (`@callable_positions`, read from its `@spec`) must
       be a written value (an `fn` or capture literal judged pure, a literal):
       a function held in a variable, field or attribute may be any function;
    6. a local call `f(args)` to a `def`/`defp` its own module defines, in a
       module whose name matches a `pure_patterns` glob, `f` not ending in
       `!`, every argument pure (an imported or `use`-injected name is
       unknown);
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

  # For each function of the stdlib pure set, the 1-based argument positions
  # it may call: those its @spec types as a function (`(... -> ...)`, `fun()`,
  # `function()`, a `when` variable bound to one) or a `Collectable.t()`. Read
  # once, at compile time, from the specs of the Elixir that compiles Anchor.
  # A function whose own arity has no spec takes the positions of the nearest
  # higher arity that has one (an arity made by a default argument); one with
  # no spec at all is absent, and every argument of it is judged as callable.
  @callable_positions (
                        callable? = fn type, constraints ->
                          type =
                            case type do
                              {name, _meta, ctx} when is_atom(name) and is_atom(ctx) ->
                                Keyword.get(constraints, name, type)

                              _type ->
                                type
                            end

                          {_type, found} =
                            Macro.prewalk(type, false, fn
                              {:->, _meta, _args} = node, _found ->
                                {node, true}

                              {name, _meta, args} = node, _found
                              when name in [:fun, :function] and args in [nil, []] ->
                                {node, true}

                              {{:., _dmeta, [Collectable, :t]}, _meta, _args} = node, _found ->
                                {node, true}

                              node, found ->
                                {node, found}
                            end)

                          found
                        end

                        positions = fn name, spec ->
                          {spec, constraints} =
                            case Code.Typespec.spec_to_quoted(name, spec) do
                              {:when, _meta, [spec, constraints]} -> {spec, constraints}
                              spec -> {spec, []}
                            end

                          {:"::", _meta, [{^name, _hmeta, args}, _return]} = spec

                          for {type, index} <- Enum.with_index(List.wrap(args), 1),
                              callable?.(type, constraints),
                              do: index
                        end

                        for module <- @stdlib_pure,
                            {:ok, specs} = Code.Typespec.fetch_specs(module),
                            {name, arity} <- module.__info__(:functions),
                            match =
                              specs
                              |> Enum.filter(fn {{n, a}, _specs} -> n == name and a >= arity end)
                              |> Enum.min_by(fn {{_n, a}, _specs} -> a end, fn -> nil end),
                            match != nil,
                            into: %{} do
                          {_key, specs_of} = match

                          found =
                            specs_of
                            |> Enum.flat_map(&positions.(name, &1))
                            |> Enum.filter(&(&1 <= arity))
                            |> Enum.uniq()
                            |> Enum.sort()

                          {{module, name, arity}, found}
                        end
                      )

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
      defs: MapSet.new(),
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
    ctx = %{ctx | module: module, defs: definitions(body), line: line(meta) || ctx.line}
    scan(body, ctx, acc)
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
    do: capture_target_pure?(target, arity, ctx)

  defp pure?({:&, _meta, [expr]}, ctx), do: pure?(expr, ctx)

  # 5. remote calls (and 4. a field read on a pure value)
  defp pure?({{:., _dmeta, [receiver, fun]}, meta, args}, ctx)
       when is_atom(fun) and is_list(args) do
    case module_of(receiver, ctx) do
      {:ok, module} ->
        pure_function?(module, fun, ctx) and arguments_pure?(module, fun, args, ctx)

      :not_a_module ->
        field_read?(meta, args) and pure?(receiver, ctx)

      :unknown ->
        false
    end
  end

  # 6. and 7. local calls
  defp pure?({name, _meta, args}, ctx) when is_atom(name) and is_list(args),
    do: local_pure?(name, length(args), ctx) and pure?(args, ctx)

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

  defp capture_target_pure?({{:., _dmeta, [receiver, fun]}, _meta, []}, _arity, ctx)
       when is_atom(fun) do
    case module_of(receiver, ctx) do
      {:ok, module} -> pure_function?(module, fun, ctx)
      _not_a_module -> false
    end
  end

  defp capture_target_pure?({op, _meta, ctx_atom}, 2, _ctx)
       when op in @binary_operators and is_atom(ctx_atom),
       do: true

  defp capture_target_pure?({name, _meta, ctx_atom}, arity, ctx)
       when is_atom(name) and is_atom(ctx_atom),
       do: local_pure?(name, arity, ctx)

  defp capture_target_pure?(_target, _arity, _ctx), do: false

  # A stdlib function calls the arguments its spec types as a function (or a
  # `Collectable.t()`): there only an `fn` or a capture literal, judged pure,
  # or a plain atom option (`:desc`) is pure. A variable there may hold any
  # function, so the call is not pure. A function with no spec is judged as
  # calling every argument. A `pure_patterns` module's arguments are judged as
  # data: the rule trusts that declaration (see the README's known limits).
  defp arguments_pure?(module, fun, args, ctx) do
    if module in @stdlib_pure do
      callable = Map.get(@callable_positions, {module, fun, length(args)}, :all)

      args
      |> Enum.with_index(1)
      |> Enum.all?(fn {arg, index} -> argument_pure?(arg, callable?(callable, index), ctx) end)
    else
      pure?(args, ctx)
    end
  end

  defp callable?(:all, _index), do: true
  defp callable?(positions, index), do: index in positions

  defp argument_pure?(arg, false, ctx), do: pure?(arg, ctx)

  defp argument_pure?(arg, true, ctx) do
    if written_value?(arg), do: pure?(arg, ctx), else: false
  end

  # A value the source writes out, so it cannot be a function held elsewhere:
  # an `fn` or capture literal (judged by `pure?/2`), a literal, a container
  # literal. Not a variable, an attribute, a field read or a call's result.
  defp written_value?({form, _meta, _args}) when form in [:fn, :&, :{}, :%{}, :%, :<<>>],
    do: true

  defp written_value?({:__aliases__, _meta, _parts}), do: false
  defp written_value?({_form, _meta, _args}), do: false
  defp written_value?(_literal_list_or_pair), do: true

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

  # A local call is pure only when it is a Kernel pure function, or a
  # non-bang function this `pure_patterns` module defines itself. A name an
  # `import` or a `use` brings in (`field/2` in `embedded_schema`) is unknown.
  defp local_pure?(name, arity, ctx) do
    cond do
      MapSet.member?(@kernel_pure, name) -> true
      MapSet.member?(@kernel_names, name) -> false
      bang?(name) -> false
      not MapSet.member?(ctx.defs, {name, arity}) -> false
      true -> ctx.module != nil and pure_module?(ctx.module, ctx)
    end
  end

  # The `{name, arity}` of every `def`/`defp` written directly in a module
  # body, each arity a default argument makes callable included.
  defp definitions([{:do, body} | _rest]), do: definitions(body)
  defp definitions({:__block__, _meta, statements}), do: definitions(statements)

  defp definitions(statements) when is_list(statements),
    do: statements |> Enum.flat_map(&definition/1) |> MapSet.new()

  defp definitions(statement), do: definitions([statement])

  defp definition({kind, _meta, [head | _body]}) when kind in [:def, :defp] do
    case signature(head) do
      {name, args} -> arities(name, args)
      :error -> []
    end
  end

  defp definition(_statement), do: []

  defp signature({:when, _meta, [head | _guards]}), do: signature(head)
  defp signature({name, _meta, args}) when is_atom(name) and is_list(args), do: {name, args}
  defp signature({name, _meta, ctx}) when is_atom(name) and is_atom(ctx), do: {name, []}
  defp signature(_head), do: :error

  defp arities(name, args) do
    defaults = Enum.count(args, &match?({:\\, _meta, _default}, &1))
    total = length(args)
    for arity <- (total - defaults)..total, do: {name, arity}
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
