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
      never crashes.
    * `extract_uses/1` — the modules a file `use`s.
    * `module_dependencies/1` — one graph node per `defmodule`, each carrying the
      direct dependencies found in that module's own body (nested modules are
      separate nodes). This is what `Anchor.Managers.Lint.build_modules_map/2`
      reduces over.
    * `find_transitive_dependencies/2,3` — pure reachability over that graph.

  ## Static-analysis boundary (macro/quote)

  A static pass never runs macros, so macro-expansion-time constructs are out of
  scope by construction: a `defmodule` with a non-literal name
  (`defmodule unquote(x)`) or one nested inside a `quote` emits no node, a
  pure-DSL file with no literal `defmodule` yields `[]`, and `__MODULE__` inside
  a `quote` is left opaque. Every such construct degrades gracefully — it is
  skipped, never crashes, and no claim is emitted about code the pass cannot see.
  """

  # Lexical scope carried through the dependency walk. `enclosing` is the
  # fully-qualified parts of the innermost `defmodule` (for `__MODULE__`
  # resolution), `in_quote` suppresses that resolution inside a `quote`, and
  # `stop_at_nested` stops the walk at nested `defmodule` boundaries so a
  # module's dependencies exclude its children's (used by `module_dependencies/1`).
  @initial_scope %{enclosing: nil, in_quote: false, stop_at_nested: false}

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
  Returns the sorted, de-duplicated list of modules `ast` directly references.
  """
  @spec extract_direct_dependencies(Macro.t()) :: [module()]
  def extract_direct_dependencies(ast) do
    ast
    |> collect_deps(@initial_scope, MapSet.new())
    |> MapSet.to_list()
    |> Enum.sort()
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
  dependencies are those found in that module's own body; nested modules are
  their own nodes.
  """
  @spec module_dependencies(Macro.t()) :: [
          {module(), %{module: module(), direct_dependencies: [module()]}}
        ]
  def module_dependencies(ast) do
    ast
    |> module_nodes([])
    |> Enum.map(fn {module, parts, body} ->
      deps = body_dependencies(body, parts)
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

  # ---- direct-dependency collection (lexical-scope-aware, pure) ----

  # A `defmodule` updates the enclosing scope and (unless we are scoped to a
  # single module's body) descends into the body only — a module is never its
  # own dependency, and nested modules keep resolving `__MODULE__` to the
  # innermost enclosing module.
  defp collect_deps({:defmodule, _meta, [name_ast, body_kw]}, scope, acc) do
    if scope.stop_at_nested do
      acc
    else
      enclosing =
        case literal_alias_parts(name_ast) do
          {:ok, parts} -> (scope.enclosing || []) ++ parts
          :error -> scope.enclosing
        end

      collect_deps(do_block(body_kw), %{scope | enclosing: enclosing}, acc)
    end
  end

  # Inside a `quote`, `__MODULE__` resolution is suppressed (opaque).
  defp collect_deps({:quote, _meta, args}, scope, acc) do
    collect_children(args, %{scope | in_quote: true}, acc)
  end

  # A module reference. Recording is enough; its parts (atoms, `__MODULE__`, or
  # an attribute/variable marker) carry no further module dependency.
  defp collect_deps({:__aliases__, _meta, parts}, scope, acc) when is_list(parts) do
    record_alias(parts, scope, acc)
  end

  # Generic 3-tuple: recurse into the callee (which may itself be a `.` node) and
  # the argument list, but never into the metadata keyword list.
  defp collect_deps({form, _meta, args}, scope, acc) do
    acc = collect_deps(form, scope, acc)
    collect_arg_list(args, scope, acc)
  end

  defp collect_deps({left, right}, scope, acc) do
    acc = collect_deps(left, scope, acc)
    collect_deps(right, scope, acc)
  end

  defp collect_deps(list, scope, acc) when is_list(list), do: collect_children(list, scope, acc)
  defp collect_deps(_other, _scope, acc), do: acc

  defp collect_children(list, scope, acc) when is_list(list) do
    Enum.reduce(list, acc, fn child, acc -> collect_deps(child, scope, acc) end)
  end

  defp collect_arg_list(args, scope, acc) when is_list(args),
    do: collect_children(args, scope, acc)

  defp collect_arg_list(_args, _scope, acc), do: acc

  defp record_alias(parts, scope, acc) do
    cond do
      Enum.all?(parts, &is_atom/1) ->
        MapSet.put(acc, Module.concat(parts))

      resolvable_self_reference?(parts, scope) ->
        [{:__MODULE__, _meta, _ctx} | tail] = parts
        MapSet.put(acc, Module.concat(scope.enclosing ++ tail))

      true ->
        acc
    end
  end

  defp resolvable_self_reference?([{:__MODULE__, _meta, _ctx} | tail], scope) do
    Enum.all?(tail, &is_atom/1) and not scope.in_quote and scope.enclosing != nil
  end

  defp resolvable_self_reference?(_parts, _scope), do: false

  # Dependencies found in one module's own body: scoped to `enclosing_parts` for
  # `__MODULE__` resolution, and stopping at nested `defmodule` boundaries so a
  # child module's dependencies are attributed to the child, not the parent.
  defp body_dependencies(body, enclosing_parts) do
    scope = %{enclosing: enclosing_parts, in_quote: false, stop_at_nested: true}

    body
    |> collect_deps(scope, MapSet.new())
    |> MapSet.to_list()
    |> Enum.sort()
  end

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
