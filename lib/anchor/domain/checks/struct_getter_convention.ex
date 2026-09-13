defmodule Anchor.Domain.Checks.StructGetterConvention do
  @moduledoc """
  Pure detection for the "struct getter convention" check — the **Domain**
  bucket (ADR 001).

  Given the bare AST of a single module (the Framework edge `Anchor.Check.Source`
  acquires it; the Manager selects the rules), this returns the
  `[%Anchor.Domain.Violation{}]` the check reports. Every function here is
  side-effect-free: same AST in, same violations out. There is **zero `Credo.*`**
  and no IO — mapping a `%Violation{}` onto a `Credo.Issue` is the Framework's job
  (`Anchor.Check.Base`).

  ## What counts as a getter

  A function is a getter when it takes exactly one argument, pattern-matches a
  struct on that argument, binds one of the struct's fields to a variable, and
  returns that variable unchanged:

      def name(%__MODULE__{name: name}), do: name

  A function that processes the extracted value (`String.downcase(name)`), takes
  more than one argument, or does not bind a struct field is not a getter and is
  ignored.

  ## Alias resolution (the load-bearing capability)

  The struct in a getter head is resolved to a real module by reading the
  module's `alias` directives, so a getter is judged by the module its struct
  *actually* refers to — not the spelling at the call site. All of these resolve
  to the same module when `alias MyApp.User` (or `alias MyApp.User, as: X`) is in
  scope:

    * `%__MODULE__{}` — the enclosing module
    * `%MyApp.User{}` — fully qualified
    * `%User{}` — via `alias MyApp.User`
    * `%X{}` — via `alias MyApp.User, as: X`

  A bare literal struct name with no visible alias resolves to `Elixir.<Name>`
  (`%Unknown{}` → `Elixir.Unknown`) and is therefore treated as a foreign module.

  ## What it flags

    * **Naming** — a getter for the *enclosing* module's struct whose function
      name does not match the field it extracts (`get_name` extracting `:name`).
    * **Location** — a getter whose struct resolves to a *different* module: the
      getter belongs in that module, not here. Alias resolution recovers the real
      foreign module name for the message.

  A getter for the enclosing module is only subject to the naming rule when the
  module has a **literal** `defstruct`; a module with no `defstruct` (or one whose
  struct is injected by a macro such as `use SomeSchema`) yields no naming
  violations, because the fields are not visible in the AST. Non-literal function
  names, structs, or fields (macro/`unquote` forms) are skipped without crashing.
  """

  alias Anchor.Domain.Violation

  @doc """
  Returns the `%Violation{}` list for `ast`.

  `rules` is accepted for signature parity with the other `detect_violations/2`
  detectors; this check consumes no rule configuration.
  """
  @spec detect_violations(Macro.t(), [map()]) :: [Violation.t()]
  def detect_violations(ast, _rules \\ []) do
    case extract_module(ast) do
      {:ok, enclosing_module, body} ->
        aliases = alias_map(body)
        has_literal_struct? = struct_fields(body) != []

        body
        |> functions()
        |> Enum.filter(&getter_candidate?/1)
        |> Enum.flat_map(&validate_getter(&1, enclosing_module, aliases, has_literal_struct?))

      :no_module ->
        []
    end
  end

  # --- Module / body ---------------------------------------------------------

  defp extract_module({:defmodule, _, [{:__aliases__, _, parts}, [do: body]]})
       when is_list(parts) do
    if Enum.all?(parts, &is_atom/1) do
      {:ok, Module.concat(parts), body}
    else
      :no_module
    end
  end

  defp extract_module(_), do: :no_module

  defp statements({:__block__, _, stmts}), do: stmts
  defp statements(single), do: [single]

  defp functions(body) do
    body
    |> statements()
    |> Enum.filter(&function_def?/1)
  end

  defp function_def?({:def, _, _}), do: true
  defp function_def?({:defp, _, _}), do: true
  defp function_def?(_), do: false

  # --- Struct fields (literal defstruct only) --------------------------------

  defp struct_fields(body) do
    body
    |> statements()
    |> Enum.find_value([], &extract_struct_def/1)
  end

  defp extract_struct_def({:defstruct, _, [fields]}) when is_list(fields) do
    fields
    |> Enum.map(fn
      atom when is_atom(atom) -> atom
      {atom, _default} when is_atom(atom) -> atom
      _ -> nil
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp extract_struct_def(_), do: nil

  # --- Alias resolution ------------------------------------------------------

  defp alias_map(body) do
    body
    |> statements()
    |> Enum.reduce(%{}, &collect_alias/2)
  end

  # `alias A.B, as: X` → %{X => A.B}
  defp collect_alias(
         {:alias, _, [{:__aliases__, _, parts}, opts]},
         acc
       )
       when is_list(parts) and is_list(opts) do
    with true <- Enum.all?(parts, &is_atom/1),
         {:ok, {:__aliases__, _, [short]}} <- Keyword.fetch(opts, :as),
         true <- is_atom(short) do
      Map.put(acc, short, Module.concat(parts))
    else
      _ -> acc
    end
  end

  # `alias A.{B, C}` → %{B => A.B, C => A.C}
  defp collect_alias(
         {:alias, _, [{{:., _, [{:__aliases__, _, base}, :{}]}, _, children}]},
         acc
       )
       when is_list(base) and is_list(children) do
    if Enum.all?(base, &is_atom/1) do
      Enum.reduce(children, acc, fn
        {:__aliases__, _, child_parts}, inner when is_list(child_parts) ->
          add_plain_alias(inner, base ++ child_parts)

        _, inner ->
          inner
      end)
    else
      acc
    end
  end

  # `alias A.B` → %{B => A.B}
  defp collect_alias({:alias, _, [{:__aliases__, _, parts}]}, acc) when is_list(parts) do
    add_plain_alias(acc, parts)
  end

  defp collect_alias(_, acc), do: acc

  defp add_plain_alias(acc, parts) do
    if parts != [] and Enum.all?(parts, &is_atom/1) do
      Map.put(acc, List.last(parts), Module.concat(parts))
    else
      acc
    end
  end

  # --- Getter recognition ----------------------------------------------------

  defp getter_candidate?({_, _, [{_, _, args}, _]}) when is_list(args) do
    length(args) == 1
  end

  defp getter_candidate?(_), do: false

  defp validate_getter(
         {_, meta, [{function_name, _, [arg]}, [do: body]]},
         enclosing_module,
         aliases,
         has_literal_struct?
       )
       when is_atom(function_name) do
    case analyze_getter(arg, body) do
      {:getter, struct_ast, field_name} ->
        struct_module = resolve_struct_module(struct_ast, enclosing_module, aliases)

        adjudicate(
          struct_module,
          enclosing_module,
          has_literal_struct?,
          function_name,
          field_name,
          meta
        )

      :not_a_getter ->
        []
    end
  end

  defp validate_getter(_, _, _, _), do: []

  defp adjudicate(module, module, false, _function_name, _field_name, _meta) do
    # Getter for the enclosing struct, but no literal `defstruct` is visible
    # (macro-injected struct, or no struct at all): the fields are not in the
    # AST, so we say nothing.
    []
  end

  defp adjudicate(module, module, true, function_name, field_name, meta) do
    if function_name == field_name do
      []
    else
      [naming_violation(function_name, field_name, meta)]
    end
  end

  defp adjudicate(struct_module, enclosing_module, _has_struct?, _function_name, field_name, meta) do
    [location_violation(struct_module, enclosing_module, field_name, meta)]
  end

  defp analyze_getter({:%, _, [struct_ast, {:%{}, _, pattern}]}, {var_name, _, nil})
       when is_atom(var_name) and is_list(pattern) do
    if literal_struct?(struct_ast) do
      case field_for_var(pattern, var_name) do
        {:ok, field_name} -> {:getter, struct_ast, field_name}
        :not_found -> :not_a_getter
      end
    else
      :not_a_getter
    end
  end

  defp analyze_getter(_, _), do: :not_a_getter

  defp literal_struct?({:__MODULE__, _, _}), do: true

  defp literal_struct?({:__aliases__, _, parts}) when is_list(parts),
    do: parts != [] and Enum.all?(parts, &is_atom/1)

  defp literal_struct?(_), do: false

  defp field_for_var(pattern, var_name) do
    case Enum.find(pattern, fn
           {field, {^var_name, _, nil}} when is_atom(field) -> true
           _ -> false
         end) do
      {field_name, _} -> {:ok, field_name}
      nil -> :not_found
    end
  end

  defp resolve_struct_module({:__MODULE__, _, _}, enclosing_module, _aliases) do
    enclosing_module
  end

  defp resolve_struct_module({:__aliases__, _, [head | rest]}, _enclosing_module, aliases)
       when is_atom(head) do
    case Map.fetch(aliases, head) do
      {:ok, resolved} -> Module.concat([resolved | rest])
      :error -> Module.concat([head | rest])
    end
  end

  # --- Violations ------------------------------------------------------------

  defp naming_violation(function_name, field_name, meta) do
    %Violation{
      message:
        "Getter function `#{function_name}` should be named `#{field_name}` " <>
          "to match the field it extracts",
      line: meta[:line],
      trigger: to_string(function_name)
    }
  end

  defp location_violation(struct_module, enclosing_module, field_name, meta) do
    struct_name = inspect(struct_module)
    enclosing_name = inspect(enclosing_module)

    %Violation{
      message:
        "Getter for `#{struct_name}.#{field_name}` should be defined in " <>
          "`#{struct_name}` (not in `#{enclosing_name}`)",
      line: meta[:line],
      trigger: to_string(field_name)
    }
  end
end
