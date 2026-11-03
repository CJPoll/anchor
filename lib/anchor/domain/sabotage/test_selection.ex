defmodule Anchor.Domain.Sabotage.TestSelection do
  @moduledoc """
  Which tests a mutant runs (DND-5473). Pure **Domain**.

  `select/2` returns `{source, test_args}`. The sources, by priority:

    1. `:coverage` (DND-5474): the tests whose per-test coverage set holds the
       mutant's `Module.fun/arity`, as `file:line` args (input `coverage`, the
       `Anchor.Domain.Sabotage.CoverageMap.index/1` of a map);
    2. `:mirror`: the first `test_mirror` rule whose `from` matches the
       mutant's file names a test file, which must exist;
    3. `:none`.

  A function absent from the coverage index (or a run with no map) falls to
  the next source. The source is always stated in the report.
  """

  alias Anchor.Domain.Sabotage.TestMirror

  @type inputs :: %{
          required(:mirror) => [TestMirror.rule()],
          required(:existing_tests) => MapSet.t(String.t()),
          optional(:coverage) => %{String.t() => [String.t()]} | nil
        }
  @type source :: :coverage | :mirror | :none

  @spec select(%{file: String.t()}, inputs()) :: {source(), [String.t()]}
  def select(%{file: file} = mutant, %{mirror: rules, existing_tests: existing} = inputs) do
    case indexed(Map.get(inputs, :coverage), mfa(mutant)) do
      [_ | _] = tests -> {:coverage, tests}
      [] -> mirror(rules, file, existing)
    end
  end

  @doc "The test file the mirror looks for, or `nil` when no rule matches the file."
  @spec mirror_path(%{file: String.t()}, [TestMirror.rule()]) :: String.t() | nil
  def mirror_path(%{file: file}, rules), do: TestMirror.first_target(rules, file)

  @doc "`\"Module.fun/arity\"` of a mutant, or `nil` for a bare `%{file: ...}`."
  @spec mfa(map()) :: String.t() | nil
  def mfa(%{module: module, function: {name, arity}}), do: "#{inspect(module)}.#{name}/#{arity}"
  def mfa(_mutant), do: nil

  defp indexed(nil, _mfa), do: []
  defp indexed(_index, nil), do: []
  defp indexed(index, mfa), do: Map.get(index, mfa, [])

  defp mirror(rules, file, existing) do
    case TestMirror.first_target(rules, file) do
      nil -> {:none, []}
      path -> if MapSet.member?(existing, path), do: {:mirror, [path]}, else: {:none, []}
    end
  end
end
