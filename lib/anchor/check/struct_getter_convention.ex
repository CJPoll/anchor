defmodule Anchor.Check.StructGetterConvention do
  use Anchor.Check.Base,
    category: :consistency,
    explanations: [
      check: """
      Ensures that struct getter functions follow a consistent pattern.

      A function is considered a getter if ALL of the following are true:
      1. The function takes exactly one argument
      2. The function pattern matches a struct type on that argument
      3. The pattern match extracts a field value into a variable
      4. The function returns that variable with no additional processing

      For getter functions, this check validates:
      1. A getter for the ENCLOSING module's struct is named after the field it
         extracts (`name` for `:name`, not `get_name`).
      2. A getter whose struct resolves to a DIFFERENT module is defined in that
         module (a LOCATION violation otherwise).

      The struct is resolved to a real module by reading the module's `alias`
      directives, including `:as` aliases, so `%__MODULE__{}`, `%MyApp.User{}`,
      `%User{}` (via `alias MyApp.User`) and `%X{}` (via `alias MyApp.User, as: X`)
      are all judged against the module they actually name. A bare literal struct
      with no visible alias resolves to `Elixir.<Name>` and is treated as foreign.

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

  # Thin Framework delegate: the Manager hands over the bare AST; detection lives
  # in the pure Domain module, and Base maps the returned
  # `%Anchor.Domain.Violation{}`s onto `Credo.Issue`s.
  @doc false
  def detect_violations(_source_file, ast, rules, _context) do
    Anchor.Domain.Checks.StructGetterConvention.detect_violations(ast, rules)
  end
end
