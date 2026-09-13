defmodule Anchor do
  @moduledoc """
  Anchor provides custom Credo checks to enforce architectural constraints on your Elixir codebase.

  ## Configuration

  Create an `.anchor.yml` file in your project root with rules defining your architectural constraints.

  ## Available Checks

  - `Anchor.Check.NoDependency` - Prevents direct dependencies on forbidden modules
  - `Anchor.Check.NoTransitiveDependency` - Prevents transitive dependencies on forbidden modules
  - `Anchor.Check.MustUseModule` - Ensures modules use required modules
  - `Anchor.Check.ModulePatternRestrictions` - Restricts functions in modules matching patterns
  - `Anchor.Check.SingleControlFlow` - Ensures function clauses contain at most one control-flow structure
  - `Anchor.Check.NoTupleMatchInHead` - Prevents pattern matching on :ok/:error tuples in function heads
  - `Anchor.Check.CaseOnBareArg` - Discourages case statements on bare function arguments
  - `Anchor.Check.NoComparisonInIf` - Discourages comparison operators in if/unless conditions
  - `Anchor.Check.NoDiscardingArrowInWith` - Prevents discarding `<-` results in `with` clauses
  - `Anchor.Check.AlphabetizedFunctions` - Ensures function clauses are alphabetized within a module
  - `Anchor.Check.MaxFileLength` - Enforces a maximum number of lines per file
  - `Anchor.Check.StructGetterConvention` - Enforces a consistent convention for struct getter functions

  ## Integration with Credo

  Add the Anchor checks to your `.credo.exs` configuration:

      %{
        configs: [
          %{
            name: "default",
            checks: %{
              enabled: [
                {Anchor.Check.NoDependency, []},
                {Anchor.Check.NoTransitiveDependency, []},
                {Anchor.Check.MustUseModule, []},
                {Anchor.Check.ModulePatternRestrictions, []},
                {Anchor.Check.SingleControlFlow, []},
                {Anchor.Check.NoTupleMatchInHead, []},
                {Anchor.Check.CaseOnBareArg, []},
                {Anchor.Check.NoComparisonInIf, []},
                {Anchor.Check.NoDiscardingArrowInWith, []},
                {Anchor.Check.AlphabetizedFunctions, []},
                {Anchor.Check.MaxFileLength, []},
                {Anchor.Check.StructGetterConvention, []}
              ]
            }
          }
        ]
      }
  """

  @doc """
  Returns the list of available Anchor checks.
  """
  def checks do
    [
      Anchor.Check.NoDependency,
      Anchor.Check.NoTransitiveDependency,
      Anchor.Check.MustUseModule,
      Anchor.Check.ModulePatternRestrictions,
      Anchor.Check.SingleControlFlow,
      Anchor.Check.NoTupleMatchInHead,
      Anchor.Check.CaseOnBareArg,
      Anchor.Check.NoComparisonInIf,
      Anchor.Check.NoDiscardingArrowInWith,
      Anchor.Check.AlphabetizedFunctions,
      Anchor.Check.MaxFileLength,
      Anchor.Check.StructGetterConvention
    ]
  end
end
