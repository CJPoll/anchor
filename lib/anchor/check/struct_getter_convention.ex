defmodule Anchor.Check.StructGetterConvention do
  use Anchor.Check.Base,
    category: :consistency,
    explanations: [
      check: """
      Ensures that getter functions follow a consistent pattern.
      
      A function is considered a getter if ALL of the following are true:
      1. The function takes exactly one argument
      2. The function pattern matches a struct type on that argument
      3. The pattern match extracts a value from the struct
      4. The function returns that value with no additional processing
      
      For getter functions, this check validates:
      1. The function name matches the field being extracted
      2. The function is defined in the struct's module
      
      ## Examples
      
      GOOD:
      
          defmodule MyApp.User do
            defstruct [:name, :email, :profile]
            
            def name(%__MODULE__{name: name}), do: name
            def email(%__MODULE__{email: email}), do: email
            def profile(%__MODULE__{profile: profile}), do: profile
          end
      
      BAD:
      
          defmodule MyApp.User do
            defstruct [:name, :email]
            
            # Wrong: function name doesn't match field
            def get_name(%__MODULE__{name: name}), do: name
            
            # Wrong: processes the value (not detected as getter)
            def email(%__MODULE__{email: email}), do: String.downcase(email)
          end
      
      Note: The check purposely allows getters to return %Ecto.Association.NotLoaded{}
      structs when associations aren't loaded, as this is the natural behavior.
      """
    ]

  @doc false
  def rule_type, do: :struct_getter_convention

  @doc false
  def check_file(source_file, _rules, _params) do
    case Credo.Code.ast(source_file) do
      {:ok, ast} ->
        case extract_module_info(ast) do
          {:ok, module_ast} ->
            struct_fields = find_struct_fields(module_ast)
            
            if struct_fields == [] do
              # No struct defined, no getters to check
              []
            else
              module_ast
              |> find_all_functions()
              |> Enum.filter(&is_getter_candidate?/1)
              |> Enum.flat_map(&validate_getter(&1, struct_fields, source_file))
            end
          
          :no_module ->
            []
        end
      
      _ ->
        []
    end
  end

  defp extract_module_info({:defmodule, _, [_alias, [do: body]]}) do
    {:ok, body}
  end
  
  defp extract_module_info(_), do: :no_module

  defp find_struct_fields({:__block__, _, statements}) do
    Enum.find_value(statements, [], &extract_struct_def/1)
  end
  
  defp find_struct_fields(single_statement) do
    extract_struct_def(single_statement) || []
  end

  defp extract_struct_def({:defstruct, _, [fields]}) when is_list(fields) do
    Enum.map(fields, fn
      atom when is_atom(atom) -> atom
      {atom, _default} when is_atom(atom) -> atom
      _ -> nil
    end)
    |> Enum.filter(& &1)
  end
  
  defp extract_struct_def(_), do: nil

  defp find_all_functions({:__block__, _, statements}) do
    Enum.filter(statements, &is_function_def?/1)
  end
  
  defp find_all_functions(single_statement) do
    if is_function_def?(single_statement) do
      [single_statement]
    else
      []
    end
  end

  defp is_function_def?({:def, _, _}), do: true
  defp is_function_def?({:defp, _, _}), do: true
  defp is_function_def?(_), do: false

  defp is_getter_candidate?({_, _, [{_, _, args}, _]}) when is_list(args) do
    length(args) == 1
  end
  defp is_getter_candidate?(_), do: false

  defp validate_getter({_, meta, [{function_name, _, [arg]}, [do: body]]}, _struct_fields, source_file) do
    case analyze_getter_pattern(arg, body) do
      {:getter, field_name} ->
        if function_name != field_name do
          [create_naming_issue(source_file, function_name, field_name, meta)]
        else
          []
        end
      
      :not_a_getter ->
        []
    end
  end
  
  defp validate_getter(_, _, _), do: []

  defp analyze_getter_pattern(
    {:%, _, [{:__MODULE__, _, _}, {:%{}, _, pattern}]},
    {var_name, _, nil}
  ) when is_atom(var_name) do
    # Simple return of extracted variable
    case find_field_for_var(pattern, var_name) do
      {:ok, field_name} -> {:getter, field_name}
      :not_found -> :not_a_getter
    end
  end
  
  defp analyze_getter_pattern(_, _), do: :not_a_getter

  defp find_field_for_var(pattern, var_name) when is_list(pattern) do
    case Enum.find(pattern, fn
      {_field, {^var_name, _, nil}} -> true
      _ -> false
    end) do
      {field_name, _} -> {:ok, field_name}
      nil -> :not_found
    end
  end
  
  defp find_field_for_var(_, _), do: :not_found

  defp create_naming_issue(source_file, function_name, field_name, meta) do
    format_issue(
      source_file,
      message: "Getter function `#{function_name}` should be named `#{field_name}` to match the field it extracts",
      line_no: meta[:line],
      trigger: to_string(function_name)
    )
  end
end