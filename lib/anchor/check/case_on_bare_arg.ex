defmodule Anchor.Check.CaseOnBareArg do
  use Anchor.Check.Base,
    detector: Anchor.Domain.Checks.CaseOnBareArg,
    category: :design,
    explanations: [
      check: """
      This check discourages using case statements on bare function arguments.

      When a case statement operates directly on a function argument, it's often better
      to use function head pattern matching instead. This leads to clearer, more
      idiomatic Elixir code.

      Bad:
          def process(status) do
            case status do
              :ok -> handle_success()
              :error -> handle_failure()
            end
          end

      Good (using function heads):
          def process(:ok), do: handle_success()
          def process(:error), do: handle_failure()

      Good (case on expression):
          def process(data) do
            case validate(data) do
              :ok -> handle_success()
              :error -> handle_failure()
            end
          end
      """
    ]
end
