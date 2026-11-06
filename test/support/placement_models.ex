defmodule Anchor.Test.PlacementModels do
  @moduledoc """
  Hand-built models for the placement engine (DND-5448): `Anchor.Test.EffectsModels`'
  model, plus what placement reads. A module's opts may also hold:

    * `:specs` — `%{{name, arity} => "total(Inv.t()) :: integer()"}`, parsed the way a
      beam gives them: an alias is its module atom;
    * `:clauses` — `%{{name, arity} => ["def f(%Inv{} = i), do: i.x"]}`;
    * `:struct` — the module's struct fields;
    * `:types` — `%{{name, arity} => "t() :: %Inv{}"}`;
    * `:generated` — `ModuleNode.generated?`, `false` by default;
    * `:callbacks` — the callbacks the module declares;
    * `:interface` — the module is its context's interface;
    * `:context` — its context, `"ctx"` by default.
  """

  alias Anchor.Domain.Model
  alias Anchor.Test.EffectsModels

  @doc "The model; see the moduledoc. `opts` are `EffectsModels.model/3`'s."
  @spec model([tuple()], [tuple()], keyword()) :: Model.t()
  def model(modules, calls, opts \\ []) do
    base = EffectsModels.model(modules, calls, opts)

    Enum.reduce(modules, base, fn {module, _bucket, _functions, module_opts}, model ->
      model
      |> update_node(module, module_opts)
      |> update_class(module, module_opts)
    end)
  end

  @doc "A spec string as a beam's `ModuleNode.specs` holds it."
  @spec spec(String.t()) :: Macro.t()
  def spec(text) do
    text
    |> Code.string_to_quoted!()
    |> Macro.prewalk(fn
      {:__aliases__, _meta, parts} -> Module.concat(parts)
      other -> other
    end)
  end

  @doc "A clause `{meta, args, guards, body}` from `def` source."
  @spec clause(String.t()) :: tuple()
  def clause(text) do
    {:def, meta, [head, [do: body]]} = text |> Code.string_to_quoted!() |> expand_aliases()

    case head do
      {:when, _when_meta, [{_name, _head_meta, args}, guard]} -> {meta, args, [guard], body}
      {_name, _head_meta, args} -> {meta, args, [], body}
    end
  end

  defp expand_aliases(ast) do
    Macro.prewalk(ast, fn
      {:__aliases__, _meta, parts} -> Module.concat(parts)
      other -> other
    end)
  end

  defp update_node(model, module, opts) do
    node = model.graph.modules[module]

    functions =
      Map.new(node.functions, fn {name_arity, function} ->
        clauses = opts |> Keyword.get(:clauses, %{}) |> Map.get(name_arity, [])
        {name_arity, %{function | clauses: Enum.map(clauses, &clause/1)}}
      end)

    node = %{
      node
      | functions: functions,
        specs: Map.new(Keyword.get(opts, :specs, %{}), fn {key, text} -> {key, [spec(text)]} end),
        types:
          Map.new(Keyword.get(opts, :types, %{}), fn {key, text} ->
            {key, {:type, {:"::", [], tl(Tuple.to_list(spec(text))) |> tl() |> hd()}}}
          end),
        struct_fields: Keyword.get(opts, :struct),
        callbacks: Keyword.get(opts, :callbacks, []),
        generated?: Keyword.get(opts, :generated, false)
    }

    put_in(model.graph.modules[module], node)
  end

  defp update_class(model, module, opts) do
    class = %{
      model.classification[module]
      | interface?: Keyword.get(opts, :interface, false),
        context: Keyword.get(opts, :context, "ctx")
    }

    put_in(model.classification[module], class)
  end
end
