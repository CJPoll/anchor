defmodule Anchor.Domain.Graph.Builder do
  @moduledoc """
  Builds `Anchor.Domain.Graph` from decoded beams and source facts —
  **Domain**, pure (DND-5438).

  Module-level facts come from each beam's `elixir_v1` metadata: the source
  file (`relative_file`), behaviours and the other persisted attributes, struct
  fields, and each definition's kind and def line. Each function is joined with
  its Core Erlang `c_fun` (`def`/`defp` keep `name/arity` in Core; a macro is
  `MACRO-name/arity+1`, mapped back), and `Anchor.Domain.Graph.CoreWalker`
  reads its call and struct-use edges. Specs and types are turned into quoted
  form with `Code.Typespec`.

  `generated?` compares the module's name with the literal `defmodule`s of its
  source file (`Anchor.Domain.Graph.SourceFacts`): absent there, the module is
  macro output. With no facts for the file, facts that are
  `{:error, :unparseable}`, or a file that also has a `defmodule` with a
  non-literal name (which may be this module), it is `:unknown`, never `false`
  and never a guessed `true`.

  With `root:` (the project root, `build/3`), a module's `source_file` is its
  path as `Anchor.Domain.Graph.ProjectFile.place/2` gives it: an absolute path
  inside the root is made relative to it (DND-5588), so it matches the
  `source_facts` keys and the selectors' `paths`. Its edges are still read
  against the path the beam names, which is the one Core's annotations hold.

  A decode error is carried into `graph.unreadable` (in path order), never
  dropped; the good beams beside it are all built. Two beams of one module (a
  stale copy in a second ebin) build the first by path, and the other is in
  `unreadable` as `{:duplicate_module, kept_path}`. A module with a public
  function or macro its Core does not define is built, and is in `unreadable`
  too, as `{:no_core, [{name, arity}]}` (DND-5549).
  """

  alias Anchor.Domain.Failures
  alias Anchor.Domain.Graph
  alias Anchor.Domain.Graph.Beam
  alias Anchor.Domain.Graph.CoreWalker
  alias Anchor.Domain.Graph.FunctionNode
  alias Anchor.Domain.Graph.ModuleNode
  alias Anchor.Domain.Graph.ProjectFile
  alias Anchor.Domain.Graph.SourceFacts

  @doc """
  Builds the graph. `source_facts` maps a source file (as the beams'
  `relative_file` names it, relativised against `opts[:root]` when given) to
  its `SourceFacts.from_source/2` result.
  """
  @spec build(
          [Beam.t() | Beam.decode_error()],
          %{String.t() => SourceFacts.t() | {:error, :unparseable}},
          root: Path.t()
        ) :: Graph.t()
  def build(beams, source_facts, opts \\ []) do
    root = Keyword.get(opts, :root)
    {decoded, errors} = Enum.split_with(beams, &match?(%Beam{}, &1))
    {kept, duplicates} = first_per_module(decoded)

    {built, crashed} =
      kept |> Enum.map(&guarded_module(&1, source_facts, root)) |> split_built()

    paths = Map.new(kept, &{&1.module, &1.path})
    no_core = Enum.flat_map(built, fn {node, _edges} -> public_without_core(node, paths) end)

    %Graph{
      modules: Map.new(built, fn {node, _edges} -> {node.module, node} end),
      calls: Enum.flat_map(built, fn {_node, {calls, _uses}} -> calls end),
      struct_uses: Enum.flat_map(built, fn {_node, {_calls, uses}} -> uses end),
      unreadable:
        errors
        |> Enum.map(fn {:error, error} -> error end)
        |> Enum.concat(duplicates)
        |> Enum.concat(crashed)
        |> Enum.concat(no_core)
        |> Enum.sort_by(& &1.path)
    }
  end

  # One module's node and edges, built together, so a crash leaves no partial
  # module behind (DND-5548). A raise, throw or exit while building it is that
  # module's `{:walk_crashed, summary}` entry in `unreadable`, never the whole
  # build's: every other module is still built.
  defp guarded_module(%Beam{} = beam, source_facts, root) do
    node = module_node(beam, source_facts, root)
    # Core's `{:file, _}` annotations hold the cwd-relative path, the beam's
    # own `elixir_v1` `:relative_file`, before any relativising (DND-5588).
    {:built, {node, module_edges(node, Map.get(beam.elixir, :relative_file))}}
  catch
    kind, reason ->
      {:crashed,
       %{
         path: beam.path,
         module: beam.module,
         reason: {:walk_crashed, Failures.crash_summary(kind, reason, __STACKTRACE__)}
       }}
  end

  defp split_built(results) do
    {built, crashed} = Enum.split_with(results, &match?({:built, _}, &1))
    {Enum.map(built, &elem(&1, 1)), Enum.map(crashed, &elem(&1, 1))}
  end

  # One beam per module: the first by path. Every other beam of that module (a
  # stale copy in a second ebin) is reported, naming the beam that was kept.
  defp first_per_module(decoded) do
    decoded
    |> Enum.sort_by(& &1.path)
    |> Enum.group_by(& &1.module)
    |> Enum.reduce({[], []}, fn {_module, [first | others]}, {kept, duplicates} ->
      extra =
        Enum.map(
          others,
          &%{path: &1.path, module: &1.module, reason: {:duplicate_module, first.path}}
        )

      {[first | kept], extra ++ duplicates}
    end)
  end

  # A public function or macro the Core module does not define cannot be
  # walked, so it is reported, never read as a function with no calls. A
  # private one with no Core is expected: the compiler emits no code for a
  # `defmacrop` (expanded where it is used) or for a `defp` nothing calls.
  # `Graph.functions_without_core/1` counts both kinds (DND-5549).
  defp public_without_core(%ModuleNode{module: module, functions: functions}, paths) do
    missing =
      for {name_arity, %FunctionNode{core: nil, kind: kind}} <- functions,
          kind in [:def, :defmacro],
          do: name_arity

    case Enum.sort(missing) do
      [] -> []
      missing -> [%{path: Map.fetch!(paths, module), module: module, reason: {:no_core, missing}}]
    end
  end

  defp module_node(%Beam{module: module, elixir: elixir} = beam, source_facts, root) do
    source_file = project_file(Map.get(elixir, :relative_file), root)
    attributes = Map.get(elixir, :attributes, [])
    core_defs = core_defs(beam.core)

    %ModuleNode{
      module: module,
      app: beam.app,
      source_file: source_file,
      line: anno_line(Map.get(elixir, :anno)),
      behaviours: attributes |> Keyword.get_values(:behaviour) |> List.flatten(),
      attributes: attributes,
      specs: specs(beam.specs, macros(Map.get(elixir, :definitions, []))),
      types: types(beam.types),
      struct_fields: struct_fields(Map.get(elixir, :struct)),
      functions:
        elixir
        |> Map.get(:definitions, [])
        |> Map.new(&function_node(module, &1, core_defs)),
      generated?: generated(module, Map.get(source_facts, source_file))
    }
  end

  # The node's path: relativised against the root when one is given; a path
  # the root does not hold stands as the beam names it.
  defp project_file(file, nil), do: file

  defp project_file(file, root) do
    case ProjectFile.place(file, root) do
      {:project, relative} -> relative
      :dependency -> file
    end
  end

  defp module_edges(%ModuleNode{module: module, functions: functions}, file) do
    functions
    |> Enum.sort_by(fn {name_arity, _node} -> name_arity end)
    |> Enum.map(fn {name_arity, node} -> function_edges(module, name_arity, node, file) end)
    |> Enum.unzip()
    |> then(fn {calls, uses} -> {List.flatten(calls), List.flatten(uses)} end)
  end

  defp function_edges(_module, _name_arity, %FunctionNode{core: nil}, _file), do: {[], []}

  defp function_edges(module, name_arity, %FunctionNode{core: core, line: line}, file),
    do: CoreWalker.walk(module, name_arity, core, line, file)

  defp function_node(module, {{name, arity}, kind, meta, clauses}, core_defs) do
    node = %FunctionNode{
      module: module,
      name: name,
      arity: arity,
      kind: kind,
      line: Keyword.get(meta, :line),
      clauses: clauses,
      core: Map.get(core_defs, core_name(kind, name, arity))
    }

    {{name, arity}, node}
  end

  defp core_name(kind, name, arity) when kind in [:defmacro, :defmacrop],
    do: {:"MACRO-#{name}", arity + 1}

  defp core_name(_kind, name, arity), do: {name, arity}

  defp core_defs(nil), do: %{}

  defp core_defs(core) do
    Map.new(:cerl.module_defs(core), fn {fname, fun} -> {:cerl.var_name(fname), fun} end)
  end

  # The `defmodule` line: `elixir_v1`'s `:anno` is `{line, column}` or a line.
  defp anno_line({line, _column}) when is_integer(line), do: line
  defp anno_line(line) when is_integer(line), do: line
  defp anno_line(_anno), do: nil

  defp generated(_module, nil), do: :unknown
  defp generated(_module, {:error, :unparseable}), do: :unknown

  defp generated(module, %{defmodules: names, nonliteral_defmodule?: nonliteral?}) do
    cond do
      module_name(module) in names -> false
      nonliteral? -> :unknown
      true -> true
    end
  end

  defp module_name(module), do: module |> Atom.to_string() |> String.replace_prefix("Elixir.", "")

  defp struct_fields(nil), do: nil
  defp struct_fields(fields), do: Enum.map(fields, & &1.field)

  defp specs(specs, macros) do
    Map.new(specs, fn {{name, arity}, forms} ->
      case macro_spec(name, arity, macros) do
        nil ->
          {{name, arity}, Enum.map(forms, &Code.Typespec.spec_to_quoted(name, &1))}

        macro ->
          forms = Enum.map(forms, &without_caller/1)
          {macro, Enum.map(forms, &Code.Typespec.spec_to_quoted(elem(macro, 0), &1))}
      end
    end)
  end

  defp macros(definitions) do
    for {name_arity, kind, _meta, _clauses} <- definitions,
        kind in [:defmacro, :defmacrop],
        do: name_arity
  end

  # A macro's spec is compiled under `MACRO-name/arity+1`, its first argument
  # the caller's env. It is keyed under the macro's own name and arity, the
  # key its FunctionNode has (kind `:defmacro`), checked against the module's
  # macros: a name that only looks like one keeps its key (DND-5550).
  defp macro_spec(name, arity, macros) do
    case Atom.to_string(name) do
      "MACRO-" <> macro ->
        Enum.find(macros, fn {macro_name, macro_arity} ->
          macro_arity == arity - 1 and Atom.to_string(macro_name) == macro
        end)

      _function ->
        nil
    end
  end

  defp without_caller({:type, line, :bounded_fun, [fun, constraints]}),
    do: {:type, line, :bounded_fun, [without_caller(fun), constraints]}

  defp without_caller(
         {:type, line, :fun, [{:type, product_line, :product, [_caller | args]}, result]}
       ),
       do: {:type, line, :fun, [{:type, product_line, :product, args}, result]}

  defp without_caller(form) do
    raise ArgumentError,
          "a macro spec of an unknown shape: #{inspect(form)}. Fix: Anchor's graph builder " <>
            "must learn this spec shape (DND-5550)."
  end

  defp types(types) do
    Map.new(types, fn {kind, {name, _body, args} = type} ->
      {{name, length(args)}, {kind, Code.Typespec.type_to_quoted(type)}}
    end)
  end
end
