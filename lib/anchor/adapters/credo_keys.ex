defmodule Anchor.Adapters.CredoKeys do
  @moduledoc """
  The real `Anchor.Adapters.LintKeys` adapter (DND-5632), a **Side Effect**
  (ADR 001): it runs Credo (`Credo.run/1`, `--strict`, no paths, so the
  whole file set) from the working directory and returns the baseline key of
  every finding that carries one. `Anchor.Check.Base` puts a finding's key on
  its Credo issue as `meta[:anchor_key]`, and its rule's id as
  `meta[:anchor_rule_id]`. Credo's own report is not printed
  (`run_quietly/1`): `mix anchor.baseline` prints its own.
  """

  @behaviour Anchor.Adapters.LintKeys

  alias Credo.CLI.Output.Shell

  @impl true
  def keys do
    case run_quietly(["--strict"]) do
      %Credo.Execution{halted: true} ->
        {:error, :halted}

      %Credo.Execution{} = exec ->
        issues = Credo.Execution.get_issues(exec)

        {:ok,
         %{keys: meta(issues, :anchor_key), rule_ids: Enum.uniq(meta(issues, :anchor_rule_id))}}
    end
  end

  @doc """
  `Credo.run(argv)` with Credo's report not printed: its shell
  (`Credo.CLI.Output.Shell`, a process of Credo's own) is muted for the run
  and unmuted after it, whether it returns or raises.
  """
  @spec run_quietly([String.t()]) :: Credo.Execution.t()
  def run_quietly(argv) do
    {:ok, _apps} = Application.ensure_all_started(:credo)
    GenServer.call(Shell, {:suppress_output, true})

    try do
      Credo.run(argv)
    after
      GenServer.call(Shell, {:suppress_output, false})
    end
  end

  defp meta(issues, name) do
    for %Credo.Issue{meta: meta} <- issues,
        value = Keyword.get(List.wrap(meta), name),
        is_binary(value),
        do: value
  end
end
