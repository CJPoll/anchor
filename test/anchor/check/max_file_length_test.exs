defmodule Anchor.Check.MaxFileLengthTest do
  use ExUnit.Case

  alias Anchor.Check.MaxFileLength
  alias Credo.SourceFile

  describe "realistic module with various elements" do
    test "counts only actual code lines, excluding docs and comments" do
      source_file = """
      defmodule MyApp.Users.User do
        @moduledoc \"\"\"
        This module represents a user in the system.
        
        Users have various attributes and can perform
        multiple actions within the application.
        
        ## Examples
        
            iex> User.new(name: "John")
            %User{name: "John"}
            
        ## Fields
        
        - `:name` - The user's full name
        - `:email` - The user's email address
        - `:role` - The user's role in the system
        \"\"\"
        
        use Ecto.Schema
        import Ecto.Changeset
        
        # This is a single-line comment
        
        @typedoc \"\"\"
        Represents a user struct with all its fields.
        
        This type is used throughout the application
        to ensure type safety when dealing with users.
        \"\"\"
        @type t :: %__MODULE__{
          id: integer() | nil,
          name: String.t(),
          email: String.t(),
          role: atom()
        }
        
        @doc \"\"\"
        Creates a new user with the given attributes.
        
        ## Parameters
        
        - `attrs` - A map of user attributes
        
        ## Examples
        
            iex> User.new(%{name: "Jane", email: "jane@example.com"})
            %User{name: "Jane", email: "jane@example.com"}
        \"\"\"
        def new(attrs) do
          %__MODULE__{}
          |> cast(attrs, [:name, :email, :role])
          |> validate_required([:name, :email])
        end
        
        # Another comment
        # that spans
        # multiple lines
        
        @doc \"\"\"
        Validates a user changeset.
        \"\"\"
        def validate(changeset) do
          changeset
          |> validate_length(:name, min: 2, max: 100)
          |> validate_format(:email, ~r/@/)
        end
        
        @doc false
        def internal_function(user) do
          # This function is for internal use only
          do_something(user)
        end
        
        # Private functions
        
        defp do_something(user) do
          user
        end
        
        
        
        # Empty lines above should not count
        
        defp another_helper do
          :ok
        end
        
        @doc \"\"\"
        A macro that does something special.
        \"\"\"
        defmacro special_macro(ast) do
          quote do
            unquote(ast)
          end
        end
      end
      """
      
      # When counting actual code lines (excluding docs, comments, empty lines):
      # Should count: module definition, use, import, @type, function defs, actual code lines
      # Should NOT count: @moduledoc, @typedoc, @doc, comments, empty lines
      
      rule = %{"type" => "max_file_length", "max_lines" => 30}
      source = SourceFile.parse(source_file, "lib/test.ex")
      issues = MaxFileLength.check_file(source, [rule], [])
      
      # This should count approximately 20-25 actual code lines, well under 30
      assert [] == issues
    end
    
    test "detects when actual code exceeds limit despite many comments" do
      functions = Enum.map(1..50, fn i ->
        """
        @doc \"\"\"
        Function #{i} documentation.
        \"\"\"
        def function_#{i}(x) do
          # Comment for function #{i}
          x + #{i}
        end
        """
      end)
      
      source_file = """
      defmodule MyModule do
        @moduledoc \"\"\"
        A module with many functions.
        \"\"\"
        
        #{Enum.join(functions, "\n")}
      end
      """
      
      rule = %{"type" => "max_file_length", "max_lines" => 100}
      source = SourceFile.parse(source_file, "lib/test.ex")
      issues = MaxFileLength.check_file(source, [rule], [])
      
      # With 50 functions, each having ~3 lines of actual code (def, body, end)
      # Plus module definition, this should exceed 100 lines of actual code
      assert length(issues) == 1
    end
  end

  test "no issue when file is under default limit of 400 lines" do
    lines = Enum.map(1..396, fn i -> "  def function_#{i}(), do: :ok" end)
    source_file = "defmodule MyModule do\n#{Enum.join(lines, "\n")}\nend"

    rule = %{"type" => "max_file_length"}
    source = SourceFile.parse(source_file, "lib/test.ex")
    assert [] == MaxFileLength.check_file(source, [rule], [])
  end

  test "no issue when file is exactly at default limit of 400 lines" do
    lines = Enum.map(1..398, fn i -> "  def function_#{i}(), do: :ok" end)
    source_file = "defmodule MyModule do\n#{Enum.join(lines, "\n")}\nend"

    rule = %{"type" => "max_file_length"}
    source = SourceFile.parse(source_file, "lib/test.ex")
    assert [] == MaxFileLength.check_file(source, [rule], [])
  end

  test "detects file exceeding default limit of 400 lines" do
    lines = Enum.map(1..399, fn i -> "  def function_#{i}(), do: :ok" end)
    source_file = "defmodule MyModule do\n#{Enum.join(lines, "\n")}\nend"

    rule = %{"type" => "max_file_length"}
    source = SourceFile.parse(source_file, "lib/test.ex")
    issues = MaxFileLength.check_file(source, [rule], [])
    
    assert length(issues) == 1
    issue = hd(issues)
    assert issue.message =~ "File contains 401 lines of code (maximum allowed: 400)"
    assert issue.message =~ "Consider breaking this file into smaller"
    assert issue.line_no == 1
  end

  test "respects custom max_lines configuration as integer" do
    lines = Enum.map(1..99, fn i -> "  def function_#{i}(), do: :ok" end)
    source_file = "defmodule MyModule do\n#{Enum.join(lines, "\n")}\nend"

    rule = %{"type" => "max_file_length", "max_lines" => 100}
    source = SourceFile.parse(source_file, "lib/test.ex")
    issues = MaxFileLength.check_file(source, [rule], [])
    
    assert length(issues) == 1
    issue = hd(issues)
    assert issue.message =~ "File contains 101 lines of code (maximum allowed: 100)"
  end

  test "respects custom max_lines configuration as string" do
    lines = Enum.map(1..99, fn i -> "  def function_#{i}(), do: :ok" end)
    source_file = "defmodule MyModule do\n#{Enum.join(lines, "\n")}\nend"

    rule = %{"type" => "max_file_length", "max_lines" => "100"}
    source = SourceFile.parse(source_file, "lib/test.ex")
    issues = MaxFileLength.check_file(source, [rule], [])
    
    assert length(issues) == 1
    issue = hd(issues)
    assert issue.message =~ "File contains 101 lines of code (maximum allowed: 100)"
  end

  test "no issue when file is under custom limit" do
    lines = Enum.map(1..47, fn i -> "  def function_#{i}(), do: :ok" end)
    source_file = "defmodule MyModule do\n#{Enum.join(lines, "\n")}\nend"

    rule = %{"type" => "max_file_length", "max_lines" => 50}
    source = SourceFile.parse(source_file, "lib/test.ex")
    assert [] == MaxFileLength.check_file(source, [rule], [])
  end

  test "handles empty files" do
    source_file = ""

    rule = %{"type" => "max_file_length"}
    source = SourceFile.parse(source_file, "lib/test.ex")
    assert [] == MaxFileLength.check_file(source, [rule], [])
  end

  describe "documentation and comment handling" do
    test "excludes @moduledoc from line count" do
      source_file = """
      defmodule MyModule do
        @moduledoc \"\"\"
        This is a very long module documentation
        that spans multiple lines.
        
        It includes:
        - Examples
        - Usage instructions
        - Implementation details
        
        And should not count towards the line limit.
        \"\"\"
        
        def hello, do: :world
      end
      """
      
      # Should only count: defmodule line, def line, and end lines (approximately 3-4 lines)
      rule = %{"type" => "max_file_length", "max_lines" => 10}
      source = SourceFile.parse(source_file, "lib/test.ex")
      assert [] == MaxFileLength.check_file(source, [rule], [])
    end
    
    test "excludes @doc and @typedoc from line count" do
      source_file = """
      defmodule MyModule do
        @typedoc \"\"\"
        A custom type with documentation.
        This documentation is multiple lines.
        \"\"\"
        @type custom_type :: String.t()
        
        @doc \"\"\"
        Function documentation.
        
        ## Examples
        
            iex> hello()
            :world
        \"\"\"
        def hello, do: :world
        
        @doc \"\"\"
        Another function with docs.
        \"\"\"
        @spec goodbye() :: :moon
        def goodbye, do: :moon
      end
      """
      
      # Should count: defmodule, @type, @spec, def lines, end - but not @doc/@typedoc
      rule = %{"type" => "max_file_length", "max_lines" => 15}
      source = SourceFile.parse(source_file, "lib/test.ex")
      assert [] == MaxFileLength.check_file(source, [rule], [])
    end
    
    test "excludes comments from line count" do
      source_file = """
      defmodule MyModule do
        # This is a comment
        # Another comment line
        # Yet another comment
        
        def hello do
          # Inline comment
          :world # End of line comment
        end
        
        # Comment between functions
        # With multiple lines
        # That should not count
        
        def goodbye do
          :moon
        end
      end
      """
      
      # Should only count actual code lines
      rule = %{"type" => "max_file_length", "max_lines" => 10}
      source = SourceFile.parse(source_file, "lib/test.ex")
      assert [] == MaxFileLength.check_file(source, [rule], [])
    end
    
    test "excludes empty lines and whitespace-only lines" do
      source_file = """
      defmodule MyModule do
        
        
        def hello, do: :world
        
        
        
        def goodbye, do: :moon
        
        
      end
      """
      
      # Should only count the 4 actual code lines
      rule = %{"type" => "max_file_length", "max_lines" => 5}
      source = SourceFile.parse(source_file, "lib/test.ex")
      assert [] == MaxFileLength.check_file(source, [rule], [])
    end
  end
  
  describe "complex module structures" do
    test "handles modules with macros, callbacks, and behaviours" do
      source_file = """
      defmodule MyApp.ComplexModule do
        @moduledoc \"\"\"
        A complex module with various Elixir constructs.
        \"\"\"
        
        @behaviour GenServer
        
        use GenServer
        require Logger
        import Ecto.Query
        alias MyApp.{User, Post, Comment}
        
        @impl true
        def init(state) do
          {:ok, state}
        end
        
        @impl true
        def handle_call(:get, _from, state) do
          {:reply, state, state}
        end
        
        @doc \"\"\"
        A public function.
        \"\"\"
        def public_function(x) do
          x * 2
        end
        
        # Private functions section
        
        defp private_helper(x) do
          x + 1
        end
        
        defmacro my_macro(ast) do
          quote do
            unquote(ast)
          end
        end
        
        defmacrop private_macro(ast) do
          ast
        end
      end
      """
      
      # Count actual code, not docs/comments
      # Module has ~28 lines of actual code
      rule = %{"type" => "max_file_length", "max_lines" => 30}
      source = SourceFile.parse(source_file, "lib/test.ex")
      assert [] == MaxFileLength.check_file(source, [rule], [])
    end
    
    test "handles nested modules" do
      source_file = """
      defmodule OuterModule do
        @moduledoc \"\"\"
        Outer module docs.
        \"\"\"
        
        defmodule InnerModule do
          @moduledoc \"\"\"
          Inner module docs.
          \"\"\"
          
          def inner_function do
            :inner
          end
        end
        
        def outer_function do
          :outer
        end
      end
      """
      
      # Should count all defmodule and def lines, but not @moduledoc
      rule = %{"type" => "max_file_length", "max_lines" => 10}
      source = SourceFile.parse(source_file, "lib/test.ex")
      assert [] == MaxFileLength.check_file(source, [rule], [])
    end
  end

  test "no longer counts blank lines and comments" do
    source_file = "defmodule MyModule do\n  # This is a comment\n  def hello, do: :world\n  \n  # Another comment\n  \n  def goodbye, do: :moon\nend"

    # New implementation only counts actual code lines (4 lines: defmodule, def, def, end)
    rule = %{"type" => "max_file_length", "max_lines" => 5}
    source = SourceFile.parse(source_file, "lib/test.ex")
    issues = MaxFileLength.check_file(source, [rule], [])
    
    # Should not trigger because only 4 lines of actual code
    assert issues == []
  end

  test "trigger contains filename" do
    lines = Enum.map(1..399, fn i -> "  def function_#{i}(), do: :ok" end)
    source_file = "defmodule MyModule do\n#{Enum.join(lines, "\n")}\nend"

    rule = %{"type" => "max_file_length"}
    source = SourceFile.parse(source_file, "lib/my_app/some_module.ex")
    issues = MaxFileLength.check_file(source, [rule], [])
    
    assert length(issues) == 1
    issue = hd(issues)
    assert issue.trigger == "lib/my_app/some_module.ex"
  end
end