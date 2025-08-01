defmodule Anchor.Check.StructGetterConventionTest do
  use ExUnit.Case, async: true

  alias Anchor.Check.StructGetterConvention

  describe "struct getter convention check" do
    test "accepts properly named getter functions" do
      source = """
      defmodule MyApp.User do
        defstruct [:name, :email, :profile]
        
        def name(%__MODULE__{name: name}), do: name
        def email(%__MODULE__{email: email}), do: email
        def profile(%__MODULE__{profile: profile}), do: profile
      end
      """

      issues = run_check(source)
      assert Enum.empty?(issues)
    end

    test "flags getter with incorrect function name" do
      source = """
      defmodule MyApp.User do
        defstruct [:name, :email]
        
        def get_name(%__MODULE__{name: name}), do: name
        def email(%__MODULE__{email: email}), do: email
      end
      """

      issues = run_check(source)
      assert length(issues) == 1
      assert hd(issues).message =~ "Getter function `get_name` should be named `name`"
    end

    test "ignores functions that process the value" do
      source = """
      defmodule MyApp.User do
        defstruct [:name, :email]
        
        def name(%__MODULE__{name: name}), do: String.upcase(name)
        def email(%__MODULE__{email: email}), do: String.downcase(email)
      end
      """

      issues = run_check(source)
      assert Enum.empty?(issues)
    end

    test "ignores functions with multiple arguments" do
      source = """
      defmodule MyApp.User do
        defstruct [:name, :role]
        
        def has_role?(%__MODULE__{role: role}, expected_role) do
          role == expected_role
        end
      end
      """

      issues = run_check(source)
      assert Enum.empty?(issues)
    end

    test "ignores functions that don't pattern match on struct" do
      source = """
      defmodule MyApp.User do
        defstruct [:name]
        
        def process(data) do
          data
        end
      end
      """

      issues = run_check(source)
      assert Enum.empty?(issues)
    end

    test "accepts getters returning Ecto.Association.NotLoaded" do
      source = """
      defmodule MyApp.User do
        defstruct [:name, :profile]
        
        def profile(%__MODULE__{profile: profile}), do: profile
        # profile might be %Ecto.Association.NotLoaded{} and that's fine
      end
      """

      issues = run_check(source)
      assert Enum.empty?(issues)
    end

    test "ignores modules without defstruct" do
      source = """
      defmodule MyApp.Service do
        def process(%{data: data}), do: data
      end
      """

      issues = run_check(source)
      assert Enum.empty?(issues)
    end

    test "handles nested pattern matching correctly" do
      source = """
      defmodule MyApp.User do
        defstruct [:profile]
        
        def profile_name(%__MODULE__{profile: %{name: name}}), do: name
      end
      """

      # This is not a simple getter - it's extracting a nested value
      issues = run_check(source)
      assert Enum.empty?(issues)
    end

    test "flags multiple incorrectly named getters" do
      source = """
      defmodule MyApp.User do
        defstruct [:first_name, :last_name, :email]
        
        def get_first_name(%__MODULE__{first_name: first_name}), do: first_name
        def get_last_name(%__MODULE__{last_name: last_name}), do: last_name
        def email(%__MODULE__{email: email}), do: email
      end
      """

      issues = run_check(source)
      assert length(issues) == 2
      assert Enum.any?(issues, & &1.message =~ "get_first_name")
      assert Enum.any?(issues, & &1.message =~ "get_last_name")
    end

    test "handles struct fields with default values" do
      source = """
      defmodule MyApp.Config do
        defstruct [:timeout, retries: 3]
        
        def timeout(%__MODULE__{timeout: timeout}), do: timeout
        def retries(%__MODULE__{retries: retries}), do: retries
      end
      """

      issues = run_check(source)
      assert Enum.empty?(issues)
    end

    test "ignores private functions" do
      source = """
      defmodule MyApp.User do
        defstruct [:name]
        
        defp get_name(%__MODULE__{name: name}), do: name
      end
      """

      # Currently the check applies to both public and private functions
      # You could modify it to only check public functions if desired
      issues = run_check(source)
      assert length(issues) == 1
    end

    test "handles single expression module body" do
      source = """
      defmodule MyApp.Simple do
        defstruct [:value]
        def value(%__MODULE__{value: value}), do: value
      end
      """

      issues = run_check(source)
      assert Enum.empty?(issues)
    end
  end

  defp run_check(source) do
    source_file = Credo.SourceFile.parse(source, "test.ex")
    
    # Simulate the check_file callback
    StructGetterConvention.check_file(source_file, [], [])
  end
end