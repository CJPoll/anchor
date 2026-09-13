defmodule Anchor.Check.StructGetterConventionTest do
  # Framework-edge characterization matrix for the `struct_getter_convention`
  # check, exercised end-to-end through `check_file/3`: source string in,
  # `[%Credo.Issue{}]` out. Detection is the pure
  # `Anchor.Domain.Checks.StructGetterConvention`; this file pins the naming and
  # LOCATION messages, triggers and lines Credo renders, plus the alias / `:as`
  # resolution and the `Elixir.<Name>` bare-literal rule.
  #
  # Sabotage record:
  #   ../../sabotage_records/struct_getter_convention-20260913-dnd_137_t6_12_struct_getter_convention.md
  use ExUnit.Case, async: true

  alias Anchor.Check.StructGetterConvention
  alias Credo.SourceFile

  defp issues(source) do
    source
    |> SourceFile.parse("lib/test.ex")
    |> StructGetterConvention.check_file([], [])
  end

  # Row #1 — %__MODULE__{} getter, name != field → naming violation
  test "#1 flags a %__MODULE__{} getter whose name does not match the field" do
    source = """
    defmodule MyApp.User do
      defstruct [:name]
      def get_name(%__MODULE__{name: name}), do: name
    end
    """

    assert [issue] = issues(source)

    assert issue.message ==
             "Getter function `get_name` should be named `name` to match the field it extracts"

    assert issue.trigger == "get_name"
    assert issue.line_no == 3
  end

  # Row #2 — correct %__MODULE__{} getter → []
  test "#2 accepts a correctly named %__MODULE__{} getter" do
    source = """
    defmodule MyApp.User do
      defstruct [:name]
      def name(%__MODULE__{name: name}), do: name
    end
    """

    assert [] == issues(source)
  end

  # Row #3 — processes the value → not a getter → []
  test "#3 ignores a function that processes the extracted value" do
    source = """
    defmodule MyApp.User do
      defstruct [:name]
      def name(%__MODULE__{name: name}), do: String.downcase(name)
    end
    """

    assert [] == issues(source)

    # Positive control: returning the bare field with a wrong name flags.
    control = """
    defmodule MyApp.User do
      defstruct [:name]
      def get_name(%__MODULE__{name: name}), do: name
    end
    """

    refute [] == issues(control)
  end

  # Row #4 — multiple arguments → not a getter → []
  test "#4 ignores a multi-argument function" do
    source = """
    defmodule MyApp.User do
      defstruct [:role]
      def has_role?(%__MODULE__{role: role}, expected), do: role == expected
    end
    """

    assert [] == issues(source)
  end

  # Row #5 — no defstruct → []
  test "#5 says nothing when the enclosing module has no literal defstruct" do
    source = """
    defmodule MyApp.User do
      def get_name(%__MODULE__{name: name}), do: name
    end
    """

    assert [] == issues(source)

    # Positive control: add the defstruct and the misnamed getter flags.
    control = """
    defmodule MyApp.User do
      defstruct [:name]
      def get_name(%__MODULE__{name: name}), do: name
    end
    """

    refute [] == issues(control)
  end

  # Row #6 — enclosing fully-qualified %MyApp.User{} misnamed → naming violation
  test "#6 flags a misnamed getter written with the fully-qualified enclosing struct" do
    source = """
    defmodule MyApp.User do
      defstruct [:name]
      def get_name(%MyApp.User{name: name}), do: name
    end
    """

    assert [issue] = issues(source)

    assert issue.message ==
             "Getter function `get_name` should be named `name` to match the field it extracts"

    assert issue.trigger == "get_name"
  end

  # Row #7 — enclosing fully-qualified %MyApp.User{} correct → []
  test "#7 accepts a correct getter written with the fully-qualified enclosing struct" do
    source = """
    defmodule MyApp.User do
      defstruct [:name]
      def name(%MyApp.User{name: name}), do: name
    end
    """

    assert [] == issues(source)
  end

  # Row #8 — aliased %User{} (via `alias MyApp.User`) misnamed → naming violation
  test "#8 flags a misnamed getter written with an aliased enclosing struct" do
    source = """
    defmodule MyApp.User do
      alias MyApp.User
      defstruct [:name]
      def get_name(%User{name: name}), do: name
    end
    """

    assert [issue] = issues(source)

    assert issue.message ==
             "Getter function `get_name` should be named `name` to match the field it extracts"

    assert issue.trigger == "get_name"
  end

  # Row #9 — aliased %User{} correct → []
  test "#9 accepts a correct getter written with an aliased enclosing struct" do
    source = """
    defmodule MyApp.User do
      alias MyApp.User
      defstruct [:name]
      def name(%User{name: name}), do: name
    end
    """

    assert [] == issues(source)
  end

  # Row #10 — `:as` alias (`alias MyApp.User, as: X`, `%X{}`) misnamed → naming
  test "#10 flags a misnamed getter written with an `:as` alias of the enclosing struct" do
    source = """
    defmodule MyApp.User do
      alias MyApp.User, as: X
      defstruct [:name]
      def get_name(%X{name: name}), do: name
    end
    """

    assert [issue] = issues(source)

    assert issue.message ==
             "Getter function `get_name` should be named `name` to match the field it extracts"

    assert issue.trigger == "get_name"
  end

  # Row #11 — `:as` alias correct → []
  test "#11 accepts a correct getter written with an `:as` alias of the enclosing struct" do
    source = """
    defmodule MyApp.User do
      alias MyApp.User, as: X
      defstruct [:name]
      def name(%X{name: name}), do: name
    end
    """

    assert [] == issues(source)
  end

  # Row #12 — foreign fully-qualified %Other{} in module A → LOCATION violation
  test "#12 flags a getter for a foreign struct as a location violation" do
    source = """
    defmodule A do
      def name(%Other{name: name}), do: name
    end
    """

    assert [issue] = issues(source)

    assert issue.message ==
             "Getter for `Other.name` should be defined in `Other` (not in `A`)"

    assert issue.trigger == "name"
    assert issue.line_no == 2
  end

  # Row #13 — foreign aliased (`alias Other.Thing, as: O`, `%O{}`) → names Other.Thing
  test "#13 resolves an `:as` alias to the real foreign module name in the location message" do
    source = """
    defmodule A do
      alias Other.Thing, as: O
      def name(%O{name: name}), do: name
    end
    """

    assert [issue] = issues(source)

    assert issue.message ==
             "Getter for `Other.Thing.name` should be defined in `Other.Thing` (not in `A`)"

    assert issue.trigger == "name"
  end

  # Row #14 — foreign getter defined in its own module → []
  test "#14 accepts a getter for a foreign-looking struct when defined in that struct's module" do
    source = """
    defmodule Other do
      defstruct [:name]
      def name(%Other{name: name}), do: name
    end
    """

    assert [] == issues(source)

    # Positive control: misnaming it flags a naming violation (not a location one).
    control = """
    defmodule Other do
      defstruct [:name]
      def get_name(%Other{name: name}), do: name
    end
    """

    assert [issue] = issues(control)
    assert issue.message =~ "should be named `name`"
  end

  # Row #15 — bare literal %Unknown{} with no alias → location for Elixir.Unknown
  test "#15 treats a bare literal struct with no alias as a foreign module" do
    source = """
    defmodule MyApp.Service do
      def name(%Unknown{name: name}), do: name
    end
    """

    assert [issue] = issues(source)

    # A bare literal resolves to Elixir.Unknown (foreign): a location violation,
    # NOT a naming one.
    assert issue.message =~ "should be defined in `Unknown`"
    assert issue.message =~ "(not in `MyApp.Service`)"
    refute issue.message =~ "should be named"
    assert issue.trigger == "name"
  end

  # Row #16 — %Ecto.Association.NotLoaded{} return remains allowed
  test "#16 allows a getter whose value may be %Ecto.Association.NotLoaded{}" do
    source = """
    defmodule MyApp.User do
      defstruct [:profile]
      # profile might be %Ecto.Association.NotLoaded{} and that is fine
      def profile(%__MODULE__{profile: profile}), do: profile
    end
    """

    assert [] == issues(source)

    # Positive control: misnaming the same getter flags.
    control = """
    defmodule MyApp.User do
      defstruct [:profile]
      def get_profile(%__MODULE__{profile: profile}), do: profile
    end
    """

    refute [] == issues(control)
  end

  # Row #17 — multi-field, all correctly named → []
  test "#17 accepts a struct whose every getter is correctly named" do
    source = """
    defmodule MyApp.User do
      defstruct [:name, :email, :profile]
      def name(%__MODULE__{name: name}), do: name
      def email(%__MODULE__{email: email}), do: email
      def profile(%__MODULE__{profile: profile}), do: profile
    end
    """

    assert [] == issues(source)
  end

  # Row #18 — one wrong-named getter among correct ones → exactly one issue
  test "#18 flags only the misnamed getter among correct ones" do
    source = """
    defmodule MyApp.User do
      defstruct [:name, :email]
      def name(%__MODULE__{name: name}), do: name
      # blank line to place get_email on line 5
      def get_email(%__MODULE__{email: email}), do: email
    end
    """

    assert [issue] = issues(source)
    assert issue.trigger == "get_email"

    assert issue.message ==
             "Getter function `get_email` should be named `email` to match the field it extracts"

    assert issue.line_no == 5
  end

  # Row #19 — macro non-literal function name (`def unquote(field)(...)`) skipped
  test "#19 skips a macro-generated getter with a non-literal function name" do
    source = """
    defmodule MyApp.User do
      defstruct [:name]
      for field <- [:name] do
        def unquote(field)(%__MODULE__{unquote(field) => value}), do: value
      end
    end
    """

    assert [] == issues(source)
  end

  # Row #20 — non-literal struct / field skipped (no crash, no flag)
  test "#20 skips a getter whose struct is a non-literal expression" do
    source = """
    defmodule MyApp.User do
      defstruct [:name]
      @struct __MODULE__
      def name(%@struct{name: name}), do: name
    end
    """

    assert [] == issues(source)
  end

  # Row #21 — macro-injected struct (`use SomeSchema`, no literal defstruct) → []
  test "#21 says nothing when the struct is injected by a macro (no literal defstruct)" do
    source = """
    defmodule MyApp.User do
      use SomeSchema
      def get_name(%__MODULE__{name: name}), do: name
    end
    """

    assert [] == issues(source)
  end
end
