defmodule Mix.Tasks.Anchor.Sabotage do
  @shortdoc "Generated sabotage: the functions a branch changed (scope)"

  @moduledoc """
  Generated sabotage for the functions a change touched, the **Framework**
  entry point (ADR 001). It parses arguments, makes one
  `Anchor.Managers.Sabotage` call, renders the result and exits; it calls no
  adapter itself.

  ## scope (DND-5472)

      mix anchor.sabotage scope [--base REF] [--format text|json]

  Prints the functions the working tree changed (committed, staged, unstaged
  and untracked `.ex` files) relative to the merge-base of `REF` (default
  `origin/main`) and `HEAD`: one TSV line per function
  (`file, module, name/arity, kind, changed line ranges`), then a summary that
  counts everything left out (test files, non-source files, deleted files,
  hunks outside a function, macros). It reads git and source files only: no
  compile, and no project code runs.

  Exit codes: 0 measured (a clean diff prints `0 functions`); 2 usage;
  3 `COULD NOT MEASURE` with a `Fix:` line (not a git work tree, `REF`
  unresolvable or no merge-base, git failing, a changed `.ex` file that does
  not parse or cannot be read).
  """

  use Mix.Task

  alias Anchor.Domain.Failures
  alias Anchor.Domain.Sabotage.Scope
  alias Anchor.Managers.Sabotage

  @default_base "origin/main"
  @usage "Usage: mix anchor.sabotage scope [--base REF] [--format text|json]"

  @impl Mix.Task
  def run(argv), do: run(argv, [])

  @doc """
  Runs the task with `opts` passed to the Manager (tests inject
  `change_source:` here).
  """
  @spec run([String.t()], keyword()) :: :ok
  def run(["scope" | argv], opts) do
    case OptionParser.parse(argv, strict: [base: :string, format: :string]) do
      {parsed, [], []} ->
        scope(Keyword.get(parsed, :base, @default_base), format(parsed[:format]), opts)

      _invalid ->
        usage()
    end
  end

  def run(_argv, _opts), do: usage()

  defp scope(_base, :invalid, _opts), do: usage()

  defp scope(base, format, opts) do
    case Sabotage.scope(%{root: File.cwd!(), base: base}, opts) do
      {:ok, result} ->
        Mix.shell().info(Scope.render(result, format))

      {:error, reason} ->
        Mix.shell().error(Failures.scope_could_not_measure(reason))
        exit({:shutdown, 3})
    end
  end

  defp format(nil), do: :text
  defp format("text"), do: :text
  defp format("json"), do: :json
  defp format(_other), do: :invalid

  defp usage do
    Mix.shell().error(@usage)
    exit({:shutdown, 2})
  end
end
