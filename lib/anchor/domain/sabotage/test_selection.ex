defmodule Anchor.Domain.Sabotage.TestSelection do
  @moduledoc """
  Which tests a mutant runs (DND-5473). Pure **Domain**.

  `select/2` returns `{source, test_args}`. The sources, by priority:

    1. `:coverage` (DND-5474): the tests whose per-test coverage set holds the
       mutant's `Module.fun/arity`, as `file:line` args (input `coverage`, the
       `Anchor.Domain.Sabotage.CoverageMap.index/1` of a map);
    2. `:kill_map` (DND-5484): the test files whose tests killed a mutant of
       the same `Module.fun/arity` in an earlier sabotage record (input
       `kill_map`, `\"M.f/a\" => [file]`), each of which must exist, with
       the mirror's test file when it exists (a branch's new tests for the
       function live there, and no record names them yet);
    3. `:mirror`: the first `test_mirror` rule whose `from` matches the
       mutant's file names a test file, which must exist;
    4. `:none`.

  Wherever the mirror file is selected, so are its siblings (DND-6070): the
  existing `<stem>_<topic>_test.exs` files beside it (`TestMirror.sibling?/2`),
  where a module's tests are split by topic. With no mirror file, the
  siblings alone are a `:mirror` selection. The caller lists the mirror's
  directory (`mirror_dir/2`) into `existing_tests`. They only add tests: a
  mutant never runs fewer than the mirror file alone would.

  A function absent from the coverage index (or a run with no map) falls to
  the next source. The source is always stated in the report.

  A ref into a test file that no longer exists (`existing_tests`) is dropped;
  with none left the mutant falls to the next source. A map's `file:line`
  refs are as of the commit it was built at. Input
  `stale_tests` names the test files that changed since then (`:all` when
  that is unknown): a ref into one of them runs its whole file, never a line
  that may now hold another test, and the mutant's mirror file, when it is
  stale and exists, is added whole, so a test the branch added for the
  function runs too.

  Every path this module returns goes into `mix test`'s argv, so each one, of
  every source, must pass `Anchor.Domain.Sabotage.TestPath.check_arg/1`
  (DND-5640) here, at the point it is emitted, whatever its source checked
  when it was read: a coverage ref, a killer or a mirror file that is an
  option, absolute, outside the project or not a `_test.exs` file is never
  selected.
  """

  alias Anchor.Domain.Sabotage.TestMirror
  alias Anchor.Domain.Sabotage.TestPath

  @type inputs :: %{
          required(:mirror) => [TestMirror.rule()],
          required(:existing_tests) => MapSet.t(String.t()),
          optional(:coverage) => %{String.t() => [String.t()]} | nil,
          optional(:stale_tests) => MapSet.t(String.t()) | :all,
          optional(:kill_map) => %{String.t() => [String.t()]}
        }
  @type source :: :coverage | :kill_map | :mirror | :none

  @spec select(%{file: String.t()}, inputs()) :: {source(), [String.t()]}
  def select(%{file: file} = mutant, %{mirror: rules, existing_tests: existing} = inputs) do
    refs =
      inputs
      |> Map.get(:coverage)
      |> indexed(mfa(mutant))
      |> Enum.filter(&(TestPath.safe_arg?(&1) and MapSet.member?(existing, ref_file(&1))))

    killers =
      inputs
      |> Map.get(:kill_map)
      |> indexed(mfa(mutant))
      |> Enum.filter(&(TestPath.safe_arg?(&1) and MapSet.member?(existing, &1)))

    cond do
      refs != [] -> {:coverage, fresh(refs, rules, file, existing, stale(inputs))}
      killers != [] -> {:kill_map, with_mirror(killers, rules, file, existing)}
      true -> mirror(rules, file, existing)
    end
  end

  defp with_mirror(killers, rules, file, existing) do
    mirror =
      case mirror(rules, file, existing) do
        {:mirror, paths} -> paths
        {:none, []} -> []
      end

    (killers ++ mirror) |> Enum.uniq() |> Enum.sort()
  end

  @doc """
  The test files a coverage selection of `mutant` could pass: the files of
  its refs in the index, which the caller checks exist (`existing_tests`).
  """
  @spec coverage_files(map(), %{String.t() => [String.t()]} | nil) :: [String.t()]
  def coverage_files(mutant, index),
    do: index |> indexed(mfa(mutant)) |> Enum.map(&ref_file/1) |> Enum.uniq()

  @doc "The test files a kill-map selection of `mutant` could pass."
  @spec kill_map_files(map(), %{String.t() => [String.t()]} | nil) :: [String.t()]
  def kill_map_files(mutant, kill_map), do: kill_map |> indexed(mfa(mutant)) |> Enum.uniq()

  @doc "The test file the mirror looks for, or `nil` when no rule matches the file."
  @spec mirror_path(%{file: String.t()}, [TestMirror.rule()]) :: String.t() | nil
  def mirror_path(%{file: file}, rules), do: TestMirror.first_target(rules, file)

  @doc """
  The directory of the mirror path, which the caller lists so the mirror's
  siblings (`TestMirror.sibling?/2`) can be selected, or `nil` when no rule
  matches the file.
  """
  @spec mirror_dir(%{file: String.t()}, [TestMirror.rule()]) :: String.t() | nil
  def mirror_dir(mutant, rules) do
    case mirror_path(mutant, rules) do
      nil -> nil
      path -> Path.dirname(path)
    end
  end

  @doc "`\"Module.fun/arity\"` of a mutant, or `nil` for a bare `%{file: ...}`."
  @spec mfa(map()) :: String.t() | nil
  def mfa(%{module: module, function: {name, arity}}), do: "#{inspect(module)}.#{name}/#{arity}"
  def mfa(_mutant), do: nil

  defp stale(inputs), do: Map.get(inputs, :stale_tests, MapSet.new())

  defp fresh(refs, rules, file, existing, stale) do
    refs = Enum.map(refs, &if(stale?(stale, ref_file(&1)), do: ref_file(&1), else: &1))

    mirror =
      case mirror(rules, file, existing) do
        {:mirror, paths} -> Enum.filter(paths, &stale?(stale, &1))
        {:none, []} -> []
      end

    (refs ++ mirror) |> Enum.uniq() |> Enum.sort()
  end

  defp stale?(:all, _file), do: true
  defp stale?(stale, file), do: MapSet.member?(stale, file)

  defp ref_file(ref), do: ref |> String.split(":", parts: 2) |> hd()

  defp indexed(nil, _mfa), do: []
  defp indexed(_index, nil), do: []
  defp indexed(index, mfa), do: Map.get(index, mfa, [])

  defp emit?(path, existing), do: TestPath.safe_arg?(path) and MapSet.member?(existing, path)

  # The mirror file, when it exists, and its existing siblings (DND-6070).
  defp mirror(rules, file, existing) do
    case TestMirror.first_target(rules, file) do
      nil -> {:none, []}
      path -> mirror_files(path, existing)
    end
  end

  defp mirror_files(path, existing) do
    siblings = Enum.filter(existing, &TestMirror.sibling?(path, &1))

    case Enum.filter([path | siblings], &emit?(&1, existing)) do
      [] -> {:none, []}
      paths -> {:mirror, paths |> Enum.uniq() |> Enum.sort()}
    end
  end
end
