defmodule Anchor do
  @moduledoc """
  Anchor provides custom Credo checks to enforce architectural constraints on your Elixir codebase.

  ## Configuration

  Create an `.anchor.yml` file in your project root with rules defining your architectural constraints.

  ## Available Checks

  - `Anchor.Check.NoDependency` - Prevents direct dependencies on forbidden modules
  - `Anchor.Check.MustUseModule` - Ensures modules use required modules
  - `Anchor.Check.ModulePatternRestrictions` - Restricts functions in modules matching patterns
  - `Anchor.Check.SingleControlFlow` - Ensures function clauses contain at most one control-flow structure
  - `Anchor.Check.NoTupleMatchInHead` - Prevents pattern matching on :ok/:error tuples in function heads
  - `Anchor.Check.CaseOnBareArg` - Discourages case statements on bare function arguments

  ## Integration with Credo

  Add the Anchor checks to your `.credo.exs` configuration:

      %{
        configs: [
          %{
            name: "default",
            checks: %{
              enabled: [
                {Anchor.Check.NoDependency, []},
                {Anchor.Check.MustUseModule, []},
                {Anchor.Check.ModulePatternRestrictions, []},
                {Anchor.Check.SingleControlFlow, []},
                {Anchor.Check.NoTupleMatchInHead, []},
                {Anchor.Check.CaseOnBareArg, []}
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
      Anchor.Check.MustUseModule,
      Anchor.Check.ModulePatternRestrictions,
      Anchor.Check.SingleControlFlow,
      Anchor.Check.NoTupleMatchInHead,
      Anchor.Check.CaseOnBareArg
    ]
  end
end
