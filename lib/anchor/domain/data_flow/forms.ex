defmodule Anchor.Domain.DataFlow.Forms do
  @moduledoc """
  The source-AST shapes `Anchor.Domain.DataFlow` reads (DND-5439). Pure
  **Domain**: it only walks quoted code, never evaluates or compiles it.

  `decompose/1` turns each scoping form (`case`, `cond`, `if`, `unless`,
  `with`, `receive`, `try`, `fn`, `for`) into one description:

    * `head` — expressions evaluated in the enclosing scope before any clause
      (a scrutinee, an `if` condition, a `receive` timeout, `for` options);
    * `clauses` — each with the `patterns` it binds in its own scope, its
      `guards`, its `pre` steps (`with` and `for` steps, a `cond` condition:
      `{:match, pattern, guards, rhs}` or `{:expr, ast}`), its `body` (`:none`
      when the source has none, e.g. an `if` with no `else`) and whether the
      body's value is the form's value (`value: false` only for `try`'s
      `after`).

  A form whose shape is not the documented one is `:error`, and the caller
  reads it as an ordinary call: every variable in it is a use.
  """

  @pdict_erlang [:erase, :get, :get_keys, :put]
  @pdict_process [:delete, :get, :get_keys, :put]

  @type clause :: %{
          patterns: [Macro.t()],
          guards: [Macro.t()],
          pre: [{:match, Macro.t(), [Macro.t()], Macro.t()} | {:expr, Macro.t()}],
          body: Macro.t() | :none,
          value: boolean()
        }
  @type desc :: %{
          form: atom(),
          kind: :branch | :fn | :for,
          head: [Macro.t()],
          clauses: [clause()]
        }

  @doc "The description of a scoping form, or `:error` for anything else."
  @spec decompose(Macro.t()) :: {:ok, desc()} | :error
  def decompose({:case, _meta, [scrutinee, [do: clauses]]}) do
    with {:ok, parsed} <- arrows(clauses), do: {:ok, desc(:case, :branch, [scrutinee], parsed)}
  end

  def decompose({:cond, _meta, [[do: clauses]]}) do
    with {:ok, parsed} <- arrows(clauses),
         {:ok, conds} <- cond_clauses(parsed) do
      {:ok, desc(:cond, :branch, [], conds)}
    end
  end

  def decompose({form, _meta, [condition, opts]}) when form in [:if, :unless] and is_list(opts) do
    with {:ok, do_body} <- Keyword.fetch(opts, :do) do
      clauses = [block_clause(do_body), block_clause(Keyword.get(opts, :else, :none))]
      {:ok, desc(form, :branch, [condition], clauses)}
    end
  end

  def decompose({:receive, _meta, [opts]}) when is_list(opts), do: receive_desc(opts)
  def decompose({:try, _meta, [opts]}) when is_list(opts), do: try_desc(opts)
  def decompose({:with, _meta, [_ | _] = args}), do: steps_desc(:with, args)
  def decompose({:for, _meta, [_ | _] = args}), do: steps_desc(:for, args)

  def decompose({:fn, _meta, clauses}) do
    with {:ok, parsed} <- arrows(clauses), do: {:ok, desc(:fn, :fn, [], parsed)}
  end

  def decompose(_other), do: :error

  @doc "Every `|>` in `ast` read as the call it desugars to."
  @spec desugar_pipes(Macro.t()) :: Macro.t()
  def desugar_pipes(ast), do: Macro.prewalk(ast, &unpipe/1)

  @doc "The first source line in `ast` (outermost first), or `nil`."
  @spec first_line(Macro.t()) :: pos_integer() | nil
  def first_line(ast) do
    {_ast, line} = Macro.prewalk(ast, nil, &line_step/2)
    line
  end

  @doc """
  The parts of a pattern: the variables it binds (name and context, in order,
  repeated names included), the expressions it reads before binding (pins,
  default arguments) and after binding (binary `size`/`unit` arguments, which
  may name a variable bound earlier in the same pattern).
  """
  @spec pattern_parts(Macro.t()) :: %{
          vars: [{atom(), atom() | nil}],
          pins: [Macro.t()],
          sizes: [Macro.t()]
        }
  def pattern_parts(pattern) do
    acc = parts(pattern, %{vars: [], pins: [], sizes: []})
    %{vars: Enum.reverse(acc.vars), pins: Enum.reverse(acc.pins), sizes: Enum.reverse(acc.sizes)}
  end

  @doc """
  The expressions a `quote` reads in the clause: its options other than `:do`
  (`bind_quoted:` values among them) and the arguments of every `unquote` and
  `unquote_splicing` in its body.
  """
  @spec quote_reads([Macro.t()]) :: [Macro.t()]
  def quote_reads(args) do
    {opts, body} =
      Enum.flat_map(args, &List.wrap/1) |> Enum.split_with(&(not match?({:do, _body}, &1)))

    option_values = Enum.flat_map(opts, &option_value/1)
    {_ast, unquoted} = Macro.prewalk(body, [], &unquote_step/2)
    option_values ++ Enum.reverse(unquoted)
  end

  @doc """
  Whether a pattern can fail to match (raise `MatchError` in a `=`): anything
  but a variable, `_`, `var!/1` or a `=` of those.
  """
  @spec refutable?(Macro.t()) :: boolean()
  def refutable?({:=, _meta, [left, right]}), do: refutable?(left) or refutable?(right)
  def refutable?({:var!, _meta, [_var | _rest]}), do: false
  def refutable?({name, _meta, context}) when is_atom(name) and is_atom(context), do: false
  def refutable?(_pattern), do: true

  @doc """
  Whether any `=` in `asts` (outermost first, nested forms included) has a
  refutable pattern: the expression asserts a shape, so removing it changes
  behaviour even when nothing reads what it binds.
  """
  @spec refutable_match?([Macro.t()]) :: boolean()
  def refutable_match?(asts) do
    {_asts, found?} = Macro.prewalk(asts, false, &refutable_step/2)
    found?
  end

  @doc "The expressions a binary segment's type spec reads (`size(n)`, `unit(n)`)."
  @spec spec_exprs(Macro.t()) :: [Macro.t()]
  def spec_exprs({spec, _meta, [expr]}) when spec in [:size, :unit], do: [expr]
  def spec_exprs({:-, _meta, [left, right]}), do: spec_exprs(left) ++ spec_exprs(right)
  def spec_exprs({:*, _meta, [left, right]}), do: spec_exprs(left) ++ spec_exprs(right)
  def spec_exprs(_other), do: []

  @doc """
  The block a body expands to: the expressions of a `__block__`, `[]` for
  `:none`, or the expression alone.
  """
  @spec statements(Macro.t() | :none) :: [Macro.t()]
  def statements(:none), do: []
  def statements({:__block__, _meta, exprs}) when is_list(exprs), do: exprs
  def statements(expr), do: [expr]

  @doc """
  The reason the first unsliceable form in `asts` (outermost first) cannot be
  followed: `:receive`, `:process_dictionary` (`Process.get/put/delete/
  get_keys`, `:erlang.get/put/erase/get_keys`, at any arity) or `:var_bang`
  (`var!/1,2`) or `:binding` (`binding/0,1`, which reads every variable in
  scope by name). `nil` when there is none.
  """
  @spec unsliceable([Macro.t()]) :: Anchor.Domain.DataFlow.Node.unsliceable()
  def unsliceable(asts) do
    {_asts, reason} = Macro.prewalk(asts, nil, &unsliceable_step/2)
    reason
  end

  @doc "Whether an AST node is a variable that binds or reads (not `_`-prefixed)."
  @spec variable?(Macro.t()) :: boolean()
  def variable?({name, _meta, context}) when is_atom(name) and is_atom(context),
    do: not String.starts_with?(Atom.to_string(name), "_")

  def variable?(_other), do: false

  defp arrow({:->, _meta, [[{:when, _wmeta, when_args}], body]})
       when is_list(when_args) and when_args != [] do
    {:ok, clause(Enum.drop(when_args, -1), [List.last(when_args)], [], body)}
  end

  defp arrow({:->, _meta, [lhs, body]}) when is_list(lhs), do: {:ok, clause(lhs, [], [], body)}
  defp arrow(_other), do: :error

  defp arrows(clauses) when is_list(clauses) do
    clauses
    |> Enum.map(&arrow/1)
    |> collect()
  end

  defp arrows(_other), do: :error

  defp block_clause(body), do: clause([], [], [], body)

  defp clause(patterns, guards, pre, body),
    do: %{patterns: patterns, guards: guards, pre: pre, body: body, value: true}

  defp collect(results) do
    if Enum.all?(results, &match?({:ok, _clause}, &1)),
      do: {:ok, Enum.map(results, &elem(&1, 1))},
      else: :error
  end

  defp cond_clauses(clauses) do
    clauses
    |> Enum.map(&cond_clause/1)
    |> collect()
  end

  defp cond_clause(%{patterns: [condition], guards: []} = clause),
    do: {:ok, %{clause | patterns: [], pre: [{:expr, condition}]}}

  defp cond_clause(_clause), do: :error

  defp desc(form, kind, head, clauses),
    do: %{form: form, kind: kind, head: head, clauses: clauses}

  defp line_step({_form, meta, _args} = node, nil) when is_list(meta),
    do: {node, Keyword.get(meta, :line)}

  defp line_step(node, line), do: {node, line}

  defp option_value({_key, value}), do: [value]
  defp option_value(_other), do: []

  defp optional_arrows(opts, key) do
    case Keyword.fetch(opts, key) do
      {:ok, clauses} -> arrows(clauses)
      :error -> {:ok, []}
    end
  end

  defp parts({:^, _meta, [expr]}, acc), do: %{acc | pins: [expr | acc.pins]}

  defp parts({:"::", _meta, [left, spec]}, acc),
    do: parts(left, %{acc | sizes: Enum.reverse(spec_exprs(spec), acc.sizes)})

  defp parts({:\\, _meta, [pattern, default]}, acc),
    do: parts(pattern, %{acc | pins: [default | acc.pins]})

  defp parts({:@, _meta, _args}, acc), do: acc
  defp parts({:var!, _meta, [var | _rest]}, acc), do: parts(var, acc)

  defp parts({name, _meta, context} = var, acc) when is_atom(name) and is_atom(context),
    do: if(variable?(var), do: %{acc | vars: [{name, context} | acc.vars]}, else: acc)

  defp parts({form, _meta, args}, acc) when is_list(args) do
    acc = if is_atom(form), do: acc, else: parts(form, acc)
    Enum.reduce(args, acc, &parts/2)
  end

  defp parts({left, right}, acc), do: parts(right, parts(left, acc))
  defp parts(list, acc) when is_list(list), do: Enum.reduce(list, acc, &parts/2)
  defp parts(_literal, acc), do: acc

  defp pdict_call?({:__aliases__, _meta, [:Process]}, fun), do: fun in @pdict_process
  defp pdict_call?(Process, fun), do: fun in @pdict_process
  defp pdict_call?(:erlang, fun), do: fun in @pdict_erlang
  defp pdict_call?(_module, _fun), do: false

  defp receive_desc(opts) do
    with {:ok, clauses} <- optional_arrows(opts, :do),
         {:ok, after_clauses} <- optional_arrows(opts, :after) do
      timeouts = Enum.flat_map(after_clauses, & &1.patterns)
      after_bodies = Enum.map(after_clauses, &block_clause(&1.body))
      {:ok, desc(:receive, :branch, timeouts, clauses ++ after_bodies)}
    end
  end

  defp rescue_clause(%{patterns: [{:in, _meta, [var, _exceptions]}]} = clause),
    do: %{clause | patterns: [var]}

  defp rescue_clause(clause), do: clause

  defp split_steps(args) do
    {steps, [opts]} = Enum.split(args, -1)

    if is_list(opts) and Keyword.keyword?(opts) and Keyword.has_key?(opts, :do),
      do: {:ok, steps, opts},
      else: :error
  end

  defp step({:<-, _meta, [{:when, _wmeta, [pattern, guard]}, rhs]}),
    do: {:match, pattern, [guard], rhs}

  defp step({:<-, _meta, [pattern, rhs]}), do: {:match, pattern, [], rhs}
  defp step({:<<>>, _meta, [{:<-, _gmeta, [pattern, rhs]}]}), do: {:match, pattern, [], rhs}
  defp step({:=, _meta, [pattern, rhs]}), do: {:match, pattern, [], rhs}
  defp step(expr), do: {:expr, expr}

  defp steps_desc(form, args) do
    with {:ok, steps, opts} <- split_steps(args) do
      pre = Enum.map(steps, &step/1)
      steps_clauses(form, pre, opts)
    end
  end

  defp steps_clauses(:with, pre, opts) do
    with {:ok, else_clauses} <- optional_arrows(opts, :else) do
      {:ok,
       desc(:with, :branch, [], [clause([], [], pre, Keyword.fetch!(opts, :do)) | else_clauses])}
    end
  end

  defp steps_clauses(:for, pre, opts) do
    head = opts |> Keyword.delete(:do) |> Keyword.values()

    case arrows(Keyword.fetch!(opts, :do)) do
      {:ok, [_ | _] = reducers} ->
        {:ok, desc(:for, :for, head, Enum.map(reducers, &%{&1 | pre: pre}))}

      _not_reducers ->
        {:ok, desc(:for, :for, head, [clause([], [], pre, Keyword.fetch!(opts, :do))])}
    end
  end

  defp try_desc(opts) do
    with {:ok, do_body} <- Keyword.fetch(opts, :do),
         {:ok, rescues} <- optional_arrows(opts, :rescue),
         {:ok, catches} <- optional_arrows(opts, :catch),
         {:ok, elses} <- optional_arrows(opts, :else) do
      after_clause = try_after(Keyword.fetch(opts, :after))

      clauses =
        [block_clause(do_body)] ++
          Enum.map(rescues, &rescue_clause/1) ++ catches ++ elses ++ after_clause

      {:ok, desc(:try, :branch, [], clauses)}
    end
  end

  defp try_after({:ok, body}), do: [%{block_clause(body) | value: false}]
  defp try_after(:error), do: []

  defp refutable_step({:=, _meta, [pattern, _rhs]} = node, false), do: {node, refutable?(pattern)}
  defp refutable_step(node, found?), do: {node, found?}

  defp unquote_step({form, _meta, [expr]} = node, acc) when form in [:unquote, :unquote_splicing],
    do: {node, [expr | acc]}

  defp unquote_step(node, acc), do: {node, acc}

  defp unpipe({:|>, _meta, [_left, _right]} = ast) do
    [{first, _pos} | rest] = Macro.unpipe(ast)
    Enum.reduce(rest, first, fn {call, pos}, acc -> Macro.pipe(acc, call, pos) end)
  rescue
    ArgumentError -> ast
  end

  defp unpipe(ast), do: ast

  defp unsliceable_step(node, nil), do: {node, unsliceable_reason(node)}
  defp unsliceable_step(node, reason), do: {node, reason}

  defp unsliceable_reason({:receive, _meta, args}) when is_list(args), do: :receive
  defp unsliceable_reason({:var!, _meta, args}) when is_list(args), do: :var_bang
  defp unsliceable_reason({:binding, _meta, args}) when is_list(args), do: :binding

  defp unsliceable_reason({{:., _dmeta, [module, fun]}, _meta, args})
       when is_atom(fun) and is_list(args),
       do: if(pdict_call?(module, fun), do: :process_dictionary)

  defp unsliceable_reason(_node), do: nil
end
