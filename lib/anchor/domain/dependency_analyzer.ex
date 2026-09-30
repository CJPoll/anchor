defmodule Anchor.Domain.DependencyAnalyzer do
  @moduledoc """
  Pure module-dependency analysis over an already-acquired AST — the **Domain**
  bucket (ADR 001).

  Every function here is side-effect-free: same AST in, same data out. There is
  **zero `Credo.*`** and no IO. AST acquisition (turning a `Credo.SourceFile`
  into an AST) happens at the Framework edge in `Anchor.Check.Source`, which
  unwraps Credo's `{:ok, ast}` exactly once and hands the **bare AST** inward.

  ## What it derives

    * `extract_module_names/1` — every `defmodule` in the file, fully qualified,
      in pre-order depth-first source order (a nested `defmodule B` inside `A`
      is `A.B`). `defimpl`/`defprotocol` bodies are walked for dependencies but
      are not emitted as named module nodes.
    * `extract_direct_dependencies/1` — the modules a file references. Outside a
      `quote`, `__MODULE__.Sub` resolves to the lexically-enclosing module's
      submodule (`Enclosing.Sub`); inside a `quote` that resolution is
      suppressed (opaque). A bare `%__MODULE__{}` (a struct self-reference,
      outside or inside a `quote`) is intentionally not emitted — a module is
      never its own external dependency. Attribute/variable field access
      (`@attr.Sub`, `var.Sub`) never records a spurious module dependency and
      never crashes. A remote call on a **bare-atom** module
      (`:telemetry.execute(...)`) records the callee as the raw atom
      (`:telemetry`, never `Elixir.telemetry`), so a `forbidden_modules` rule can
      target an Erlang/OTP module; this is scoped strictly to the call callee, so
      inert atom literals (`:ok`, a list element) are not recorded.
    * `extract_call_dependencies/1` — the modules a file calls (see its doc).
    * `dependency_lines/2` — the same sets as the two above, each module paired
      with the line of its first occurrence.
    * `unresolved_directives/1` — `alias`/`import`/`require` directives whose
      target cannot be resolved statically (see below).
    * `function_references/1` — every function the file calls or captures, and
      every call it cannot resolve (see *Function-level calls*).
    * `extract_uses/1` — the modules a file `use`s.
    * `module_dependencies/1` — one graph node per `defmodule`, each carrying the
      direct dependencies found in that module's own body (nested modules are
      separate nodes). This is what `Anchor.Managers.Lint.build_modules_map/2`
      reduces over.
    * `find_transitive_dependencies/2,3` — pure reachability over that graph.

  ## Alias and import resolution (DND-1266)

  Every module reference is resolved through the lexical environment the
  compiler would use, so a dependency is recorded under its **full** name:

    * `alias A.B` makes `B` mean `A.B`; `alias A.B, as: C` makes `C` mean `A.B`;
      `alias A.{B, C}` aliases both `A.B` and `A.C` (never the bare prefix `A`);
      `require A.B, as: C` aliases like `alias`. An alias of an alias resolves
      through the first (`alias A.B` then `alias B.C` is `A.B.C`).
    * A nested `defmodule Child` inside `Parent` aliases `Child` to
      `Parent.Child`, in its own body and in the rest of `Parent`.
    * `alias __MODULE__.Sub` and `__MODULE__.Sub` resolve against the
      enclosing module.
    * `import A.B` resolves bare calls in **call** mode. `only: [f: 1]` narrows
      the import to exactly those name/arity pairs; `except:` removes them. A
      later `import` of the same module replaces the earlier filter. Because the
      exports of `A.B` are not visible to a source-only pass, an unrestricted or
      `except:` import claims every bare call that is neither a function the
      enclosing module defines nor a `Kernel`/special-form call. That errs toward
      reporting: a bare call whose real home is a macro-generated local is
      attributed to the import.

  Directives are lexically scoped. One applies to the expressions after it in
  the same block and everything nested in them; it never leaks out of a
  `defmodule`, a function body, or any other nested construct, and it does not
  apply to code before it.

  An `alias`/`import`/`require` whose target is not a literal module (for
  example `alias @target, as: T`) cannot be resolved. Rather than read that as
  "no dependency", `unresolved_directives/1` returns it so the check can report
  it. References through such an alias record nothing; the directive report is
  what makes the miss visible.

  ## Function-level calls (DND-1267)

  `function_references/1` records every function the file calls or captures,
  as `{module, function, arity}`, through the same environment. A pipe is the
  call it builds (`x |> M.f(y)` is `M.f(x, y)`), so every shape sees its real
  arity. The shapes:

    * a remote call on an alias, a bare Erlang atom or `__MODULE__`, including
      a zero-arity call without parens;
    * a bare call or capture an `import` in scope owns;
    * a remote capture `&M.f/2` (arity 2) and `&M.f(&1)` (arity 1);
    * an MFA dispatcher — `apply/3`, `Kernel.apply/3`, `:erlang.apply/3`,
      `Function.capture/3`, `:erlang.make_fun/3` — on its first two arguments,
      at the arity its third shows (`:any` when that is not a literal list or
      integer);
    * an MFA held as data: a literal module, a literal atom and a literal
      argument list, in a row, in a call's arguments or a 3-tuple
      (`spawn(M, :f, [x])`, `{M, :f, [x]}`). Without the list it is not an MFA
      (`GenServer.call(M, :msg)`, `%{M => :f}`, `{M, :f}`);
    * `defdelegate f(a), to: M, as: :g`, a call on `M.g/1` at every arity a
      default argument makes callable;
    * a module attribute the module bound to a literal module (`@repo
      MyApp.Repo`, then `@repo.insert(x)`, `apply(@repo, ...)`, `to: @repo`).
      The binding applies to the code after it in that module, the latest one
      wins, and a nested module does not inherit it;
    * a bare call or capture `Kernel` owns (`send(pid, msg)`, `&send/2`), as a
      call on `Kernel`, so a `Kernel.*` token matches its usual spelling.

  A call the pass cannot resolve is recorded as a `t:dynamic_call/0`, never
  dropped: a call on a variable, call-result or unbound-attribute module
  (`m.f(x)`, `adapter().f(x)`, `&m.f/1`), a dispatcher whose module or function
  is not literal, a capture of a dispatcher (`&apply/3`), a `defdelegate` whose
  `to:` is not a literal module, and an unquote fragment outside a `quote`
  (`M.unquote(name)(x)`, `defdelegate unquote(name)(x), to: M`), whose module is
  known and function is not. `m.f` without parens reads a field and is
  not a call. A local call is never a call on a module, and an anonymous call
  `fun.(x)` is not recorded: its function value was made at a capture or a
  dispatcher, and that site is.

  In call mode, `defdelegate ..., to: M`, every dispatcher's literal module and
  a call on a bound attribute are call dependencies too (DND-1280).

  ## Static-analysis boundary (macro/quote)

  A static pass never runs macros, so macro-expansion-time constructs are out of
  scope by construction: a `defmodule` with a non-literal name
  (`defmodule unquote(x)`) or one nested inside a `quote` emits no node, a
  pure-DSL file with no literal `defmodule` yields `[]`, and `__MODULE__` inside
  a `quote` is left opaque. A non-literal directive inside a `quote` is macro
  code and is skipped rather than reported. Every such construct degrades
  gracefully — it is skipped, never crashes, and no claim is emitted about code
  the pass cannot see.
  """

  @def_kinds [:def, :defp, :defmacro, :defmacrop, :defguard, :defguardp, :defdelegate]

  # Type-attribute bodies are macro-time type expressions, not runtime calls.
  # `@spec f(Foo.Bar.t()) :: :ok` parses `Foo.Bar.t()` as a call node, so the
  # whole attribute is skipped in call mode to keep a typespec's alias out of the
  # call set.
  @type_attributes [:spec, :type, :typep, :opaque, :callback, :macrocallback]

  # Calls an unrestricted import can never own: every `Kernel` function and
  # macro (by name and arity) that `Kernel` still imports, and every special
  # form or piece of call-shaped syntax (by name — special forms are variadic).
  # Read at compile time from the Elixir that compiles Anchor, not the one the
  # analysed project runs; a `Kernel` function added in a later Elixir is not in
  # the set, which errs toward reporting.
  @kernel_calls MapSet.new(Kernel.__info__(:functions) ++ Kernel.__info__(:macros))
  @syntax_names MapSet.new(
                  Keyword.keys(Kernel.SpecialForms.__info__(:macros)) ++
                    [:->, :<-, :\\, :when, :|]
                )

  @initial_env %{
    mode: :reference,
    enclosing: nil,
    current: nil,
    in_quote: false,
    aliases: %{},
    imports: [],
    kernel: :all,
    locals: MapSet.new(),
    attributes: %{}
  }

  # The calls that take a module and a function as data and call (or capture)
  # that function: `{module, function, arity}`. Their first argument is the
  # callee's module, the second its function, the third its argument list (or,
  # for a capture, its arity). Bare `apply/3` is `Kernel.apply/3`.
  @mfa_dispatchers [
    {Kernel, :apply, 3},
    {:erlang, :apply, 3},
    {Function, :capture, 3},
    {:erlang, :make_fun, 3}
  ]

  @initial_acc %{file: %{}, by_module: %{}, unresolved: [], calls: %{}, dynamic: []}

  @typedoc """
  A call whose module or function a source pass cannot resolve: `module` and
  `function` are `nil` when unknown, `arity` is `:any` when unknown.
  """
  @type dynamic_call :: %{
          module: module() | nil,
          function: atom() | nil,
          arity: arity() | :any,
          line: pos_integer() | nil
        }

  @doc """
  Returns every `defmodule` name in `ast`, fully qualified, in pre-order DFS
  (a module, then its children in source order).
  """
  @spec extract_module_names(Macro.t()) :: [module()]
  def extract_module_names(ast) do
    ast
    |> module_nodes([])
    |> Enum.map(fn {module, _parts, _body} -> module end)
  end

  @doc """
  Returns the sorted, de-duplicated list of modules `ast` directly references,
  each resolved through the aliases in scope.
  """
  @spec extract_direct_dependencies(Macro.t()) :: [module()]
  def extract_direct_dependencies(ast), do: dependency_names(ast, :reference)

  @doc """
  Returns the sorted, de-duplicated list of modules `ast` references in **call
  position** — Gap A' (DND-142).

  A module is recorded only when it is the callee of a call:

    * a remote call `{{:., _, [mod, fun]}, _, args}` on an alias (resolved
      through the aliases in scope) or a bare atom (`Foo.Bar.baz(x)`,
      `B.baz(x)` after `alias Foo.B`, `:telemetry.execute(...)`),
    * a bare local call, piped call or local capture that an `import` in scope
      resolves (DND-1266; see the moduledoc for the `only:`/`except:` rules),
    * an MFA dispatcher (`apply/3`, piped or not, `Kernel.apply/3`,
      `:erlang.apply/3`, `Function.capture/3`, `:erlang.make_fun/3`) with a
      **literal** `mod` (an alias or a bare atom; a variable `mod` is dynamic
      dispatch, outside the module-level boundary, and records nothing here —
      `function_references/1` reports it), or
    * the `to:` module of a `defdelegate` (DND-1280).

  A module that appears only as an **inert** reference — a value in a map/keyword
  list, a plain alias reference, an `alias`/`import`/`require` directive, or
  inside a typespec body — is NOT recorded. This is the load-bearing difference
  from `extract_direct_dependencies/1` (which records those references): it
  honors ADR-001's "Domain-router-holds-atoms" carve-out, where a Domain module
  may hold an adapter module as an atom value so long as it never calls it.
  `__MODULE__.Sub.f()` resolves to the enclosing module's submodule
  (`Enclosing.Sub`), exactly as in the direct walk.
  """
  @spec extract_call_dependencies(Macro.t()) :: [module()]
  def extract_call_dependencies(ast), do: dependency_names(ast, :call)

  @doc """
  Returns `[{module, line}]`, sorted by module, for every dependency `ast` has in
  `mode` (`:reference` — as `extract_direct_dependencies/1` — or `:call` — as
  `extract_call_dependencies/1`). `line` is the line of the module's first
  occurrence in source order, or `nil` when the AST carries no line.
  """
  @spec dependency_lines(Macro.t(), :reference | :call) :: [{module(), pos_integer() | nil}]
  def dependency_lines(ast, mode) do
    ast
    |> analyze(mode)
    |> Map.fetch!(:file)
    |> Enum.sort()
  end

  @doc """
  Returns `[{directive, line}]`, in source order, for every `alias`, `import`
  or `require` outside a `quote` whose target (or `as:` name) is not a literal
  module, so it cannot be resolved statically. `directive` is `:alias`,
  `:import` or `:require`.
  """
  @spec unresolved_directives(Macro.t()) :: [{:alias | :import | :require, pos_integer() | nil}]
  def unresolved_directives(ast) do
    ast
    |> analyze(:reference)
    |> Map.fetch!(:unresolved)
    |> Enum.reverse()
  end

  @doc """
  Returns every function `ast` calls or captures (DND-1267), resolved through
  the lexical environment, and every call whose module or function it cannot
  resolve.

    * `:calls` — `[{{module, function, arity}, line}]`, sorted, one entry per
      distinct `{module, function, arity}` at its first line. `arity` is `:any`
      when the source does not show it (`apply(M, :f, args)`).
    * `:dynamic` — `[dynamic_call()]`, in source order: a call on a variable,
      attribute or call-result module, an MFA dispatcher (`apply/3`,
      `Kernel.apply/3`, `:erlang.apply/3`, `Function.capture/3`,
      `:erlang.make_fun/3`) with a non-literal module or function, and a
      `defdelegate` whose `to:` is not a literal module.

  See the moduledoc, *Function-level calls*, for every shape.
  """
  @spec function_references(Macro.t()) :: %{
          calls: [{{module(), atom(), arity() | :any}, pos_integer() | nil}],
          dynamic: [dynamic_call()]
        }
  def function_references(ast) do
    acc = analyze(ast, :call)
    %{calls: Enum.sort(acc.calls), dynamic: Enum.reverse(acc.dynamic)}
  end

  @doc """
  Returns the sorted, de-duplicated list of modules `ast` `use`s.
  """
  @spec extract_uses(Macro.t()) :: [module()]
  def extract_uses(ast) do
    {_ast, uses} = Macro.prewalk(ast, MapSet.new(), &collect_use/2)

    uses
    |> MapSet.to_list()
    |> Enum.sort()
  end

  @doc """
  Returns one graph node per `defmodule` in `ast`, as
  `{module, %{module: module, direct_dependencies: [module]}}`. Each node's
  dependencies are those found in that module's own body, resolved through the
  aliases in scope there (including ones declared in an enclosing module);
  nested modules are their own nodes.
  """
  @spec module_dependencies(Macro.t()) :: [
          {module(), %{module: module(), direct_dependencies: [module()]}}
        ]
  def module_dependencies(ast) do
    by_module = ast |> analyze(:reference) |> Map.fetch!(:by_module)

    ast
    |> module_nodes([])
    |> Enum.map(fn {module, _parts, _body} ->
      deps = by_module |> Map.get(module, MapSet.new()) |> MapSet.to_list() |> Enum.sort()
      {module, %{module: module, direct_dependencies: deps}}
    end)
  end

  @doc """
  Returns `true` when `ast` directly references `module`.
  """
  @spec has_direct_dependency?(Macro.t(), module()) :: boolean()
  def has_direct_dependency?(ast, module), do: module in extract_direct_dependencies(ast)

  @doc """
  Returns `true` when `ast` `use`s `module`.
  """
  @spec has_use?(Macro.t(), module()) :: boolean()
  def has_use?(ast, module), do: module in extract_uses(ast)

  @doc """
  Pure graph reachability: the set of modules reachable from `start_module`
  (inclusive) over `modules_map`, terminating on cycles.
  """
  @spec find_transitive_dependencies(map(), module(), MapSet.t()) :: MapSet.t()
  def find_transitive_dependencies(modules_map, start_module, visited \\ MapSet.new()) do
    if MapSet.member?(visited, start_module) do
      visited
    else
      visited = MapSet.put(visited, start_module)

      case Map.get(modules_map, start_module) do
        nil ->
          visited

        %{direct_dependencies: deps} ->
          Enum.reduce(deps, visited, fn dep, acc ->
            find_transitive_dependencies(modules_map, dep, acc)
          end)
      end
    end
  end

  # ---- module-name collection (pre-order DFS, fully qualified) ----

  # Returns [{module, parts, body}] in pre-order DFS. `prefix` is the enclosing
  # module's parts; a literal nested name is qualified against it.
  defp module_nodes(ast, prefix) do
    ast
    |> top_defmodules()
    |> Enum.flat_map(fn {name_ast, body} ->
      case literal_alias_parts(name_ast) do
        {:ok, parts} ->
          full = prefix ++ parts
          [{Module.concat(full), full, body} | module_nodes(body, full)]

        :error ->
          []
      end
    end)
  end

  # The `defmodule` nodes directly reachable in `ast` without crossing into a
  # deeper `defmodule` (recursion into a module's body is `module_nodes/2`'s job)
  # and without entering a `quote` (quoted code is macro-time, out of scope).
  defp top_defmodules({:defmodule, _meta, [name_ast, body_kw]}) do
    [{name_ast, do_block(body_kw)}]
  end

  defp top_defmodules({:quote, _meta, _args}), do: []

  defp top_defmodules({_form, _meta, args}) when is_list(args),
    do: Enum.flat_map(args, &top_defmodules/1)

  defp top_defmodules({left, right}), do: top_defmodules(left) ++ top_defmodules(right)
  defp top_defmodules(list) when is_list(list), do: Enum.flat_map(list, &top_defmodules/1)
  defp top_defmodules(_other), do: []

  defp do_block(body_kw) when is_list(body_kw), do: Keyword.get(body_kw, :do)
  defp do_block(_other), do: nil

  defp literal_alias_parts({:__aliases__, _meta, parts}) when is_list(parts) do
    if Enum.all?(parts, &is_atom/1), do: {:ok, parts}, else: :error
  end

  defp literal_alias_parts(_other), do: :error

  # ---- the lexical walk (pure) ----
  #
  # One walk serves both match modes. `env` is the lexical environment at the
  # node: the mode, the enclosing module (`enclosing` parts, `current` atom), the
  # aliases and imports in scope, the enclosing module's own function
  # definitions, and whether we are inside a `quote`. `acc` collects the
  # file-wide first-occurrence lines, the per-module dependency sets, and the
  # unresolvable directives.

  defp analyze(ast, mode), do: walk(ast, %{@initial_env | mode: mode}, @initial_acc)

  defp dependency_names(ast, mode) do
    ast
    |> dependency_lines(mode)
    |> Enum.map(fn {module, _line} -> module end)
  end

  # Walks `node` and discards any environment change it makes: a directive only
  # affects its later siblings, which `walk_sequence/3` threads.
  defp walk(node, env, acc) do
    {_env, acc} = step(node, env, acc)
    acc
  end

  # A block threads the environment through its expressions in order, so a
  # directive applies to the expressions after it and never to those before.
  defp step({:__block__, _meta, exprs}, env, acc) when is_list(exprs) do
    {env, walk_sequence(exprs, env, acc)}
  end

  defp step({:defmodule, _meta, [name_ast, body_kw]}, env, acc) do
    step_defmodule(literal_alias_parts(name_ast), body_kw, env, acc)
  end

  defp step({:quote, _meta, args}, env, acc) do
    {env, walk_children(args, %{env | in_quote: true}, acc)}
  end

  defp step({directive, meta, [target | opts]}, env, acc)
       when directive in [:alias, :require, :import] and is_list(opts) do
    step_directive(directive, target, directive_opts(opts), line(meta), env, acc)
  end

  # A module attribute set in a module body (`@repo MyApp.Repo`) binds its name
  # for the code after it in that module, so `@repo.insert(x)` resolves
  # (DND-1267). A value that is not a literal module unbinds it.
  defp step({:@, _meta, [{name, _ameta, [value]}]} = node, %{current: current} = env, acc)
       when is_atom(name) and name not in @type_attributes and not is_nil(current) do
    acc = visit(node, env, acc)

    attributes =
      case resolve_module(value, env) do
        {:ok, module} -> Map.put(env.attributes, name, module)
        _not_a_module -> Map.delete(env.attributes, name)
      end

    {%{env | attributes: attributes}, acc}
  end

  defp step(node, env, acc), do: {env, visit(node, env, acc)}

  defp walk_sequence(exprs, env, acc) do
    {_env, acc} = Enum.reduce(exprs, {env, acc}, fn expr, {env, acc} -> step(expr, env, acc) end)
    acc
  end

  # A literal `defmodule` opens a new module scope that inherits the aliases and
  # imports in scope. When nested, it also aliases its first name segment
  # (`defmodule Child` inside `Parent` makes `Child` mean `Parent.Child`), in its
  # own body and in the rest of the enclosing block.
  defp step_defmodule({:ok, [head | _rest] = parts}, body_kw, env, acc) do
    full = (env.enclosing || []) ++ parts
    body = do_block(body_kw)
    outer_env = nested_module_alias(env, head)

    inner_env = %{
      outer_env
      | enclosing: full,
        current: Module.concat(full),
        locals: local_definitions(body),
        attributes: %{}
    }

    {outer_env, walk(body, inner_env, acc)}
  end

  defp step_defmodule(:error, body_kw, env, acc), do: {env, walk(do_block(body_kw), env, acc)}

  defp nested_module_alias(%{enclosing: nil} = env, _head), do: env

  defp nested_module_alias(env, head),
    do: %{env | aliases: Map.put(env.aliases, head, Module.concat(env.enclosing ++ [head]))}

  # ---- directives: alias / require / import ----

  defp directive_opts([opts]) when is_list(opts), do: opts
  defp directive_opts(_opts), do: []

  # A directive's target is a reference (reference mode records it) but never a
  # call. An `import` then scopes its bare calls; an `alias` or `require ...,
  # as:` binds names. A target or `as:` name that is not a literal module is
  # recorded as unresolved, and a name it binds resolves to nothing.
  defp step_directive(:import, target, opts, line, env, acc) do
    case resolve_target(target, env) do
      [{:ok, Kernel, _short, _line} = resolved] ->
        acc = record_directive_target(resolved, acc, env, line)
        {%{env | kernel: import_filter(opts)}, acc}

      [{:ok, module, _short, _line} = resolved] ->
        acc = record_directive_target(resolved, acc, env, line)
        {add_import(env, module, import_filter(opts)), acc}

      _unresolved ->
        {env, record_unresolved(acc, env, :import, line)}
    end
  end

  defp step_directive(directive, target, opts, line, env, acc) do
    targets = resolve_target(target, env)
    acc = Enum.reduce(targets, acc, &record_directive_target(&1, &2, env, line))
    {bindings, resolved?} = alias_bindings(directive, targets, Keyword.fetch(opts, :as))
    env = Enum.reduce(bindings, env, fn {name, module}, env -> put_alias(env, name, module) end)
    acc = if resolved?, do: acc, else: record_unresolved(acc, env, directive, line)
    {env, acc}
  end

  defp record_directive_target(
         {:ok, module, _short, target_line},
         acc,
         %{mode: :reference} = env,
         line
       ),
       do: record_reference(acc, env, module, target_line || line)

  defp record_directive_target(_target, acc, _env, _line), do: acc

  # The names a directive binds, and whether it resolved completely. `as:` names
  # the alias explicitly (one literal target only); without it, `alias` binds
  # each target's last written segment and `require` binds nothing.
  defp alias_bindings(_directive, targets, {:ok, as_ast}) do
    case {literal_alias_parts(as_ast), targets} do
      {{:ok, [name]}, [{:ok, module, _short, _line}]} -> {[{name, module}], true}
      {{:ok, [name]}, _unresolved} -> {[{name, :unresolved}], false}
      _bad_as -> {[], false}
    end
  end

  defp alias_bindings(:alias, targets, :error) do
    bindings = for {:ok, module, short, _line} <- targets, short != nil, do: {short, module}
    {bindings, resolved_all?(targets)}
  end

  defp alias_bindings(:require, targets, :error), do: {[], resolved_all?(targets)}

  defp resolved_all?(targets), do: Enum.all?(targets, &match?({:ok, _module, _short, _line}, &1))

  defp put_alias(env, name, module), do: %{env | aliases: Map.put(env.aliases, name, module)}

  # Resolves a directive target into `[{:ok, module, short_name, line} | :error]`:
  # one entry per module a multi-alias names, one entry otherwise. `short_name`
  # is the name `alias` binds without `as:` (the last written segment), or `nil`
  # when there is none (an Erlang atom).
  defp resolve_target({{:., _dmeta, [base, :{}]}, _meta, elems}, env) when is_list(elems) do
    case resolve_module(base, env) do
      {:ok, base_module} -> Enum.map(elems, &resolve_multi_element(&1, base_module))
      _unresolved -> [:error]
    end
  end

  defp resolve_target(target, env) do
    case resolve_module(target, env) do
      {:ok, module} -> [{:ok, module, short_name(target, env), node_line(target)}]
      _unresolved -> [:error]
    end
  end

  defp resolve_multi_element({:__aliases__, meta, parts} = elem, base_module)
       when is_list(parts) do
    case literal_alias_parts(elem) do
      {:ok, parts} -> {:ok, concat(base_module, parts), List.last(parts), line(meta)}
      :error -> :error
    end
  end

  defp resolve_multi_element(_elem, _base_module), do: :error

  defp short_name({:__aliases__, _meta, parts}, _env) do
    last = List.last(parts)
    if is_atom(last), do: last
  end

  defp short_name({:__MODULE__, _meta, _ctx}, env), do: List.last(env.enclosing)
  defp short_name(_target, _env), do: nil

  defp import_filter(opts) do
    case {Keyword.get(opts, :only), Keyword.get(opts, :except)} do
      {only, _except} when is_list(only) -> filter_from(:only, only)
      {_only, except} when is_list(except) -> filter_from(:except, except)
      _unrestricted -> :all
    end
  end

  # A literal name/arity list narrows the import; anything else (`only:
  # :functions`, an attribute) is not statically known and is treated as
  # unrestricted, which errs toward reporting.
  defp filter_from(kind, pairs) do
    if Enum.all?(pairs, &name_arity?/1), do: {kind, MapSet.new(pairs)}, else: :all
  end

  defp name_arity?({name, arity}), do: is_atom(name) and is_integer(arity)
  defp name_arity?(_other), do: false

  # A later `import` of the same module replaces the earlier one.
  defp add_import(env, module, filter) do
    imports = Enum.reject(env.imports, fn {imported, _filter} -> imported == module end)
    %{env | imports: imports ++ [{module, filter}]}
  end

  # ---- node visitors (no environment change escapes a visited node) ----

  # A module reference. Reference mode records it; call mode records only
  # callees (below), so an inert alias is not a call.
  defp visit({:__aliases__, meta, parts} = node, env, acc) when is_list(parts) do
    if env.mode == :reference do
      record_resolved(acc, env, resolve_module(node, env), line(meta))
    else
      acc
    end
  end

  # A type attribute in call mode — skip its body entirely (no call recorded).
  defp visit({:@, _meta, [{name, _ameta, _args}]}, %{mode: :call}, acc)
       when name in @type_attributes do
    acc
  end

  # Any module attribute: its name is not a call; walk its value only.
  defp visit({:@, _meta, [{name, _ameta, args}]}, env, acc) when is_atom(name) do
    walk_args(args, env, acc)
  end

  # A pipe is the call it builds: `x |> f(y)` is `f(x, y)` and `x |> M.f(y)` is
  # `M.f(x, y)`, so every call shape below sees its real arity and arguments
  # (DND-1280: `M |> apply(:f, args)` is `apply(M, :f, args)`).
  defp visit({:|>, _meta, [left, right]}, env, acc), do: walk(piped(left, right), env, acc)

  # A remote capture `&M.f/2`: a reference to `M.f/2`, so a call of arity 2
  # (the callee node inside it is written without parens and has no args).
  defp visit(
         {:&, _meta, [{:/, _smeta, [{{:., _dmeta, [callee, fun]}, cmeta, []}, arity]}]},
         env,
         acc
       )
       when is_integer(arity) do
    visit_remote(callee, fun, [], arity, cmeta, :capture, env, acc)
  end

  # A remote call (`Foo.Bar.baz(...)`, `B.baz(...)`, `__MODULE__.Sub.f(...)`,
  # `:telemetry.execute(...)`, `mod.f(...)`). A multi-alias `A.{B, C}` outside a
  # directive is not a call.
  defp visit({{:., _dmeta, [callee, fun]}, meta, args}, env, acc)
       when fun != :{} and is_list(args) do
    acc = visit_remote(callee, fun, args, length(args), meta, :call, env, acc)
    walk_args(args, env, acc)
  end

  # An unquote fragment outside a `quote` (`M.unquote(name)(x)` in a `for`
  # comprehension that defines functions): the module is known, the function
  # is not.
  defp visit({{{:., _dmeta, [callee, :unquote]}, _umeta, [fun_ast]}, meta, args}, env, acc)
       when is_list(args) do
    acc = walk(fun_ast, env, acc)
    acc = visit_remote(callee, fun_ast, args, length(args), meta, :call, env, acc)
    walk_args(args, env, acc)
  end

  # `apply(mod, fun, args)` in call mode, while `Kernel` owns `apply/3`: an MFA
  # dispatcher. A literal module is a call dependency; the function it names
  # is a call. A local or imported `apply/3` is an ordinary bare call.
  defp visit({:apply, meta, [_mod, _fun, _args] = call_args}, %{mode: :call} = env, acc) do
    if kernel_owns?(env, :apply, 3) do
      acc = record_call(acc, env, Kernel, :apply, 3, line(meta))
      acc = record_mfa_dispatch(acc, env, call_args, line(meta))
      walk_children(call_args, env, acc)
    else
      visit_bare_call(:apply, meta, call_args, env, acc)
    end
  end

  # `defdelegate f(a), to: M, as: :g` defines `f/1` as a call on `M.g/1`
  # (DND-1280): in call mode `M` is a call dependency, and `M.g` is a call.
  defp visit({:defdelegate, meta, [head, opts]}, env, acc) when is_list(opts) do
    acc = walk_head(head, env, acc)
    acc = record_delegate(acc, env, head, opts, line(meta))
    walk_children(opts, env, acc)
  end

  # A function head is a definition, not a call: walk its patterns, defaults and
  # guards, then the body.
  defp visit({kind, _meta, [head | rest]}, env, acc) when kind in @def_kinds do
    acc = walk_head(head, env, acc)
    walk_children(rest, env, acc)
  end

  # A local capture `&f/1` resolves through the imports like a bare call.
  # `&apply/3` captures the MFA dispatcher itself: whatever it is later handed
  # is unknown here.
  defp visit({:&, _meta, [{:/, _smeta, [{name, fmeta, ctx}, arity]}]}, env, acc)
       when is_atom(name) and is_atom(ctx) and is_integer(arity) do
    acc = record_bare_call(acc, env, name, arity, line(fmeta))

    if {name, arity} == {:apply, 3} and kernel_owns?(env, :apply, 3),
      do: record_dynamic(acc, env, nil, nil, :any, line(fmeta)),
      else: acc
  end

  defp visit({name, meta, args}, env, acc) when is_atom(name) and is_list(args),
    do: visit_bare_call(name, meta, args, env, acc)

  # Generic 3-tuple: walk the callee form and the arguments, never the metadata.
  defp visit({form, _meta, args}, env, acc) do
    acc = walk(form, env, acc)
    walk_args(args, env, acc)
  end

  defp visit({left, right}, env, acc), do: walk(right, env, walk(left, env, acc))

  defp visit(list, env, acc) when is_list(list), do: walk_children(list, env, acc)
  defp visit(_leaf, _env, acc), do: acc

  defp walk_children(list, env, acc) when is_list(list),
    do: Enum.reduce(list, acc, fn child, acc -> walk(child, env, acc) end)

  defp walk_args(args, env, acc) when is_list(args), do: walk_children(args, env, acc)
  defp walk_args(_args, _env, acc), do: acc

  defp walk_head({:when, _meta, [head | guards]}, env, acc),
    do: walk_children(guards, env, walk_head(head, env, acc))

  defp walk_head({name, _meta, args}, env, acc) when is_atom(name), do: walk_args(args, env, acc)
  defp walk_head(head, env, acc), do: walk(head, env, acc)

  # A bare local call `f(x)`: in call mode an import in scope, or `Kernel`, may
  # own it. Its arguments may hold an MFA (`spawn(M, :f, args)`, and a 3-tuple
  # `{M, :f, args}`, which is the call `{}`).
  defp visit_bare_call(name, meta, args, env, acc) do
    acc = record_bare_call(acc, env, name, length(args), line(meta))
    acc = record_mfa_refs(acc, env, args, line(meta))
    walk_children(args, env, acc)
  end

  # ---- function-level calls (DND-1267) ----

  # The call a pipe builds. A pipe into something that is not a call (a bare
  # alias, a literal) builds nothing: both sides are walked as they are.
  defp piped(left, {call, meta, args}) when is_list(args) and call != :__aliases__,
    do: {call, meta, [left | args]}

  defp piped(left, {name, meta, ctx}) when is_atom(name) and is_atom(ctx),
    do: {name, meta, [left]}

  defp piped(left, right), do: [left, right]

  # A remote call or capture on `callee`. `kind` is `:call` or `:capture`;
  # `arity` is the call's (or the capture's) arity. Alias and bare-atom callees
  # are module dependencies, exactly as before DND-1267; `__MODULE__.f()` calls
  # the module itself, which is a function call but never its own dependency.
  defp visit_remote(
         {:__aliases__, ameta, _parts} = callee,
         fun,
         args,
         arity,
         meta,
         kind,
         env,
         acc
       ) do
    resolution = resolve_module(callee, env)
    acc = record_resolved(acc, env, resolution, line(ameta))
    record_remote(acc, env, resolution, fun, args, arity, line(meta) || line(ameta), kind)
  end

  defp visit_remote(callee, fun, args, arity, meta, kind, env, acc) when is_atom(callee) do
    acc = record_reference(acc, env, callee, line(meta))
    record_remote(acc, env, {:ok, callee}, fun, args, arity, line(meta), kind)
  end

  defp visit_remote({:__MODULE__, _m, ctx} = callee, fun, args, arity, meta, kind, env, acc)
       when is_atom(ctx) do
    record_remote(acc, env, resolve_module(callee, env), fun, args, arity, line(meta), kind)
  end

  # An attribute bound to a literal module in this module (`@repo MyApp.Repo`,
  # then `@repo.insert(x)`) is that module, as a call dependency too.
  defp visit_remote(
         {:@, _ameta, [{name, _nmeta, ctx}]} = callee,
         fun,
         args,
         arity,
         meta,
         kind,
         env,
         acc
       )
       when is_atom(name) and is_atom(ctx) and is_map_key(env.attributes, name) do
    resolution = resolve_module(callee, env)
    acc = record_resolved(acc, env, resolution, line(meta))
    record_remote(acc, env, resolution, fun, args, arity, line(meta), kind)
  end

  # A variable, call-result or unbound-attribute callee: its module is not in
  # the source. `m.f` without parens and without args reads a field, not a call.
  defp visit_remote(callee, fun, args, arity, meta, kind, env, acc) do
    acc = walk(callee, env, acc)

    if kind == :call and args == [] and Keyword.get(meta, :no_parens, false),
      do: acc,
      else: record_remote(acc, env, :error, fun, args, arity, line(meta), kind)
  end

  # Records the call on `module.fun/arity`. An MFA dispatcher's own arguments
  # name the function it really calls; any other call's arguments may hold an
  # MFA. Capturing a dispatcher (`&Kernel.apply/3`) hands it anything later.
  defp record_remote(acc, env, {:ok, module}, fun, args, arity, line, kind) when is_atom(fun) do
    acc = record_call(acc, env, module, fun, arity, line)

    cond do
      {module, fun, arity} not in @mfa_dispatchers -> record_mfa_refs(acc, env, args, line)
      kind == :capture -> record_dynamic(acc, env, nil, nil, :any, line)
      true -> record_mfa_dispatch(acc, env, args, line)
    end
  end

  defp record_remote(acc, env, {:ok, module}, _fun, _args, arity, line, _kind),
    do: record_dynamic(acc, env, module, nil, arity, line)

  # A name bound by an unresolvable directive: that directive is reported
  # (`unresolved_directives/1`), once, so this call is not reported again.
  defp record_remote(acc, _env, :unresolved, _fun, _args, _arity, _line, _kind), do: acc

  defp record_remote(acc, env, :error, fun, _args, arity, line, _kind),
    do: record_dynamic(acc, env, nil, literal_function(fun), arity, line)

  # `apply(M, :f, args)`, `Function.capture(M, :f, 2)` and the rest of
  # `@mfa_dispatchers`: the call is on `M.f`, at the arity the third argument
  # shows. In call mode a literal `M` is a call dependency.
  defp record_mfa_dispatch(acc, env, [module_ast, function_ast, third], line) do
    module = resolve_module(module_ast, env)
    function = resolve_module(function_ast, env)
    arity = mfa_arity(third)
    acc = if env.mode == :call, do: record_resolved(acc, env, module, line), else: acc

    case {module, function} do
      {{:ok, module}, {:ok, function}} -> record_call(acc, env, module, function, arity, line)
      {:unresolved, _function} -> acc
      {_module, :unresolved} -> acc
      {{:ok, module}, :error} -> record_dynamic(acc, env, module, nil, arity, line)
      {:error, {:ok, function}} -> record_dynamic(acc, env, nil, function, arity, line)
      {:error, :error} -> record_dynamic(acc, env, nil, nil, arity, line)
    end
  end

  defp record_mfa_dispatch(acc, _env, _args, _line), do: acc

  defp mfa_arity(args) when is_list(args), do: length(args)
  defp mfa_arity(arity) when is_integer(arity), do: arity
  defp mfa_arity(_args), do: :any

  # An MFA held as data: a literal module, a literal atom and a literal
  # argument list, in a row, in a call's arguments or a 3-tuple
  # (`spawn(M, :f, [x])`, `Task.start(M, :f, [x])`, `{M, :f, [x]}`). It is a
  # call on `M.f` at the list's length. The list is what marks it an MFA:
  # `GenServer.call(M, :msg)` and `%{M => :f}` are a process name and a
  # message, or a map pair, not a function.
  defp record_mfa_refs(acc, %{mode: :call} = env, elements, line) do
    elements
    |> Enum.chunk_every(3, 1, :discard)
    |> Enum.reduce(acc, fn [module_ast, function, args], acc ->
      case {resolve_module(module_ast, env), function, args} do
        {{:ok, module}, function, args}
        when is_atom(function) and function not in [nil, true, false] and is_list(args) ->
          record_call(acc, env, module, function, length(args), node_line(module_ast) || line)

        _not_an_mfa ->
          acc
      end
    end)
  end

  defp record_mfa_refs(acc, _env, _elements, _line), do: acc

  # `defdelegate f(a), to: M, as: :g` is a call on `M.g/1` (every arity a
  # default argument makes callable). In call mode `M` is a call dependency.
  # A head that is not literal (`defdelegate unquote(name)(x), to: M` in a
  # comprehension) still delegates to `M`: the function is `as:` or unknown,
  # the arity unknown.
  defp record_delegate(acc, env, head, opts, line) do
    to = Keyword.get(opts, :to)

    {function, arities} =
      case head_signature(head) do
        {name, arities} -> {Keyword.get(opts, :as, name), arities}
        :error -> {Keyword.get(opts, :as), [:any]}
      end

    delegate(acc, env, resolve_module(to, env), function, arities, node_line(to) || line)
  end

  defp delegate(acc, env, {:ok, module}, function, arities, line) do
    acc = if env.mode == :call, do: record_reference(acc, env, module, line), else: acc

    if is_atom(function) and not is_nil(function),
      do: Enum.reduce(arities, acc, &record_call(&2, env, module, function, &1, line)),
      else: record_dynamic(acc, env, module, nil, single_arity(arities), line)
  end

  defp delegate(acc, _env, :unresolved, _function, _arities, _line), do: acc

  defp delegate(acc, env, :error, function, arities, line),
    do: record_dynamic(acc, env, nil, literal_function(function), single_arity(arities), line)

  defp single_arity([arity]), do: arity
  defp single_arity(_arities), do: :any

  defp literal_function(function) when is_atom(function), do: function
  defp literal_function(_function), do: nil

  # ---- resolution ----

  # `{:ok, module}` for a module the environment resolves, `:unresolved` for a
  # name bound by an unresolvable directive, `:error` for anything that is not a
  # literal module (`@attr.Sub`, `var.Sub`, `__MODULE__` inside a `quote`).
  defp resolve_module({:__aliases__, _meta, [head | tail]}, env) when is_atom(head) do
    case Map.fetch(env.aliases, head) do
      {:ok, :unresolved} -> :unresolved
      {:ok, module} when tail == [] -> {:ok, module}
      {:ok, module} -> literal_tail(module, tail)
      :error -> literal_tail(Module.concat([head]), tail)
    end
  end

  defp resolve_module({:__aliases__, _meta, [{:__MODULE__, _m, _c} | tail]}, env),
    do: self_reference(tail, env)

  defp resolve_module({:__MODULE__, _meta, ctx}, env) when is_atom(ctx),
    do: self_reference([], env)

  # An attribute this module bound to a literal module (DND-1267).
  defp resolve_module({:@, _meta, [{name, _nmeta, ctx}]}, env)
       when is_atom(name) and is_atom(ctx),
       do: Map.fetch(env.attributes, name)

  defp resolve_module(atom, _env) when is_atom(atom) and not is_nil(atom), do: {:ok, atom}
  defp resolve_module(_other, _env), do: :error

  defp literal_tail(module, tail) do
    if Enum.all?(tail, &is_atom/1), do: {:ok, concat(module, tail)}, else: :error
  end

  defp self_reference(tail, %{in_quote: false, enclosing: enclosing}) when is_list(enclosing) do
    if Enum.all?(tail, &is_atom/1), do: {:ok, Module.concat(enclosing ++ tail)}, else: :error
  end

  defp self_reference(_tail, _env), do: :error

  defp concat(module, []), do: module
  defp concat(module, tail), do: Module.concat([module | tail])

  # A bare call `name/arity` is recorded against EVERY import in scope that can
  # own it. Elixir rejects an ambiguous call, so at most one really does; when
  # the pass cannot tell which, it over-reports rather than guessing. The
  # enclosing module's own functions always win. A call `Kernel` owns is also a
  # function call on `Kernel` (DND-1267), never a module dependency.
  defp record_bare_call(acc, %{mode: :call} = env, name, arity, line) do
    cond do
      MapSet.member?(env.locals, {name, arity}) ->
        acc

      kernel_owns?(env, name, arity) ->
        acc
        |> record_call(env, Kernel, name, arity, line)
        |> record_imported_call(env, name, arity, line)

      true ->
        record_imported_call(acc, env, name, arity, line)
    end
  end

  defp record_bare_call(acc, _env, _name, _arity, _line), do: acc

  # `Kernel` owns a bare call to one of its functions or macros while it still
  # imports it and the module does not define its own (DND-1267: so a
  # `Kernel.send/2` token matches `send(pid, msg)`).
  defp kernel_owns?(env, name, arity) do
    not MapSet.member?(env.locals, {name, arity}) and
      MapSet.member?(@kernel_calls, {name, arity}) and filter_covers?(env.kernel, name, arity)
  end

  # A bare call `name/arity` is recorded against EVERY import in scope that can
  # own it (see `record_bare_call/5`).
  defp record_imported_call(acc, env, name, arity, line) do
    env.imports
    |> Enum.filter(fn {_module, filter} -> imports?(filter, name, arity, env.kernel) end)
    |> Enum.reduce(acc, fn {module, _filter}, acc ->
      acc
      |> record_reference(env, module, line)
      |> record_call(env, module, name, arity, line)
    end)
  end

  defp imports?({:only, pairs}, name, arity, _kernel), do: MapSet.member?(pairs, {name, arity})

  defp imports?({:except, pairs}, name, arity, kernel),
    do: not MapSet.member?(pairs, {name, arity}) and not builtin_call?(name, arity, kernel)

  defp imports?(:all, name, arity, kernel), do: not builtin_call?(name, arity, kernel)

  # A special form is always built in. A `Kernel` call is built in only while
  # `Kernel` still imports it: `import Kernel, except: [inspect: 1]` hands
  # `inspect/1` to whichever import provides it.
  defp builtin_call?(name, arity, kernel) do
    MapSet.member?(@syntax_names, name) or
      (MapSet.member?(@kernel_calls, {name, arity}) and filter_covers?(kernel, name, arity))
  end

  defp filter_covers?(:all, _name, _arity), do: true
  defp filter_covers?({:only, pairs}, name, arity), do: MapSet.member?(pairs, {name, arity})
  defp filter_covers?({:except, pairs}, name, arity), do: not MapSet.member?(pairs, {name, arity})

  # ---- local definitions (the enclosing module's own functions) ----

  # Every `{name, arity}` the module body defines with a literal head, including
  # each arity a default argument makes callable. Nested modules and quotes are
  # not this module's definitions.
  defp local_definitions(body) do
    {_ast, locals} =
      Macro.prewalk(body, MapSet.new(), fn
        {:defmodule, _meta, _args}, locals ->
          {nil, locals}

        {:quote, _meta, _args}, locals ->
          {nil, locals}

        {kind, _meta, [head | _rest]} = node, locals when kind in @def_kinds ->
          {node, add_signatures(locals, head)}

        node, locals ->
          {node, locals}
      end)

    locals
  end

  defp add_signatures(locals, head) do
    case head_signature(head) do
      {name, arities} -> Enum.reduce(arities, locals, &MapSet.put(&2, {name, &1}))
      :error -> locals
    end
  end

  # A literal function head's name and every arity it is callable at (a default
  # argument adds one), or `:error` for a head that is not literal.
  defp head_signature({:when, _meta, [head | _guards]}), do: head_signature(head)

  defp head_signature({name, _meta, args}) when is_atom(name) and is_list(args) do
    defaults = Enum.count(args, &match?({:\\, _, _}, &1))
    {name, Enum.to_list((length(args) - defaults)..length(args)//1)}
  end

  defp head_signature({name, _meta, ctx}) when is_atom(name) and is_atom(ctx), do: {name, [0]}
  defp head_signature(_head), do: :error

  # ---- recording ----

  defp record_resolved(acc, env, {:ok, module}, line),
    do: record_reference(acc, env, module, line)

  defp record_resolved(acc, _env, _unresolved, _line), do: acc

  # Records `module` against the file (first line wins) and against the module
  # whose body it occurs in.
  defp record_reference(acc, env, module, line) do
    by_module =
      Map.update(acc.by_module, env.current, MapSet.new([module]), &MapSet.put(&1, module))

    %{acc | file: Map.put_new(acc.file, module, line), by_module: by_module}
  end

  # A call on `module.function/arity` (DND-1267), first line wins. Recorded
  # only by the call-mode walk that `function_references/1` runs.
  defp record_call(acc, %{mode: :call}, module, function, arity, line),
    do: %{acc | calls: Map.put_new(acc.calls, {module, function, arity}, line)}

  defp record_call(acc, _env, _module, _function, _arity, _line), do: acc

  # A call the pass cannot resolve (DND-1267). Inside a `quote` it is macro
  # code (`unquote(mod).f()`), outside the static boundary, and is skipped as a
  # non-literal directive is.
  defp record_dynamic(acc, %{mode: :call, in_quote: false}, module, function, arity, line) do
    site = %{module: module, function: function, arity: arity, line: line}
    %{acc | dynamic: [site | acc.dynamic]}
  end

  defp record_dynamic(acc, _env, _module, _function, _arity, _line), do: acc

  # A non-literal directive inside a `quote` is macro code, outside the static
  # boundary; everywhere else it is reported.
  defp record_unresolved(acc, %{in_quote: true}, _directive, _line), do: acc

  defp record_unresolved(acc, _env, directive, line),
    do: %{acc | unresolved: [{directive, line} | acc.unresolved]}

  defp line(meta) when is_list(meta), do: Keyword.get(meta, :line)
  defp line(_meta), do: nil

  defp node_line({_form, meta, _args}), do: line(meta)
  defp node_line(_node), do: nil

  # ---- use collection ----

  defp collect_use({:use, _meta, [{:__aliases__, _ameta, parts} | _rest]} = node, acc)
       when is_list(parts) do
    if Enum.all?(parts, &is_atom/1) do
      {node, MapSet.put(acc, Module.concat(parts))}
    else
      {node, acc}
    end
  end

  defp collect_use(node, acc), do: {node, acc}
end
