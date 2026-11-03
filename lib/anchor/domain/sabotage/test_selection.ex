defmodule Anchor.Domain.Sabotage.TestSelection do
  @moduledoc """
  Which tests a mutant runs (DND-5473). Pure **Domain**.

  `select/2` returns `{source, test_args}`. The sources, by priority:
  `:coverage` (DND-5474), `:kill_map` (DND-5484), `:mirror`, `:none`. This
  ticket implements `:mirror` (the first `test_mirror` rule whose `from`
  matches the mutant's file names a test file, which must exist) and `:none`.
  The source is always stated in the report.
  """

  alias Anchor.Domain.Sabotage.TestMirror

  @type inputs :: %{mirror: [TestMirror.rule()], existing_tests: MapSet.t(String.t())}
  @type source :: :mirror | :none

  @spec select(%{file: String.t()}, inputs()) :: {source(), [String.t()]}
  def select(%{file: file}, %{mirror: rules, existing_tests: existing}) do
    case TestMirror.first_target(rules, file) do
      nil -> {:none, []}
      path -> if MapSet.member?(existing, path), do: {:mirror, [path]}, else: {:none, []}
    end
  end

  @doc "The test file the mirror looks for, or `nil` when no rule matches the file."
  @spec mirror_path(%{file: String.t()}, [TestMirror.rule()]) :: String.t() | nil
  def mirror_path(%{file: file}, rules), do: TestMirror.first_target(rules, file)
end
