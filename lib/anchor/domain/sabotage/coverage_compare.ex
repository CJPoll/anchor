defmodule Anchor.Domain.Sabotage.CoverageCompare do
  @moduledoc """
  The verdict on two builds of the coverage map at one commit and one seed
  (DND-5692), the guard for the rule that a tool or test whose result differs
  between identical runs is wrong. Pure **Domain**: read results in, a verdict, an
  exit code and lines out.

  In this order, each decided before the next:

    1. **COULD NOT MEASURE, exit 3.** A build whose map is absent or cannot be
       believed (`CoverageMap.check/1`, `CoverageMap.validate/1`, a field this
       module reads in the wrong shape), or two maps that are not of one commit,
       Elixir and OTP, or a map with no commit. A missing second build is never a
       pass, and is reported even when the first leaked. So is one file given as
       both builds (the Manager's check, which needs no read).
    2. **A leak in either build, exit 1.** Each build's pairs are printed. The lists
       are never compared: a leak's failure repeats, but which call lands past a
       window is scheduling (1 of 15 fixture builds added a pair with the map
       unchanged, run 42170921422), so a list is identical only at empty.
    3. **A failed suite in either build, exit 1.** Its map describes a broken suite,
       so saying the two agree would mean nothing.
    4. **`CoverageMap.canonical/1`, byte for byte.** Equal is exit 0. Otherwise exit 1,
       naming each differing (test, function), each test in one build only, and each
       ambient function. Bytes that differ with nothing to name still fail.

  The seed is not in the map: the workflow passes both builds the same `--seed`.
  """

  alias Anchor.Domain.Sabotage.CoverageMap

  @type build :: :first | :second
  @type read :: {:ok, term()} | {:error, term()}
  @type difference ::
          {:function, map(), String.t(), build()}
          | {:test, map(), build()}
          | {:ambient, String.t(), build()}
          | :unnamed
  @type refusal ::
          {build(), term()}
          | {:different_build, atom(), term(), term()}
          | :no_commit
          | :same_file
  @type verdict ::
          :identical
          | {:different, [difference()]}
          | {:leaked, [CoverageMap.leak()], [CoverageMap.leak()]}
          | {:suite_failed, [build()]}
          | {:could_not_measure, [refusal()]}

  @prefix "anchor.sabotage coverage-compare: "

  @doc "The verdict on what each build's file read as."
  @spec judge(read(), read()) :: verdict()
  def judge(first_read, second_read) do
    case {measured(first_read), measured(second_read)} do
      {{:ok, first}, {:ok, second}} -> judged(first, second)
      {first, second} -> {:could_not_measure, refusal(:first, first) ++ refusal(:second, second)}
    end
  end

  @doc "0 identical; 1 a leak, a failed suite or a difference; 3 COULD NOT MEASURE."
  @spec exit_code(verdict()) :: 0 | 1 | 3
  def exit_code(:identical), do: 0
  def exit_code({:could_not_measure, _refusals}), do: 3
  def exit_code(_failed), do: 1

  @doc "What to print, given the verdict and the path of each build's file."
  @spec lines(verdict(), %{first: String.t(), second: String.t()}) :: [String.t()]
  def lines(:identical, paths) do
    [
      @prefix <>
        "identical: #{paths.first} and #{paths.second} hold the same canonical bytes, " <>
        "and neither build leaked"
    ]
  end

  def lines({:different, differences}, paths) do
    [
      @prefix <>
        "two builds of one commit at one seed differ, so a test or the tool is nondeterministic"
    ] ++
      Enum.map(differences, &difference_line(&1, paths)) ++
      [
        "Fix: this is a defect in a test or in the tool, never a reason to exclude anything. " <>
          "A test whose work runs past its end: await it, or sync with the server it handed " <>
          "work to. A credit that depends on which test ran first: stop it depending on order."
      ]
  end

  def lines({:leaked, first, second}, paths) do
    [@prefix <> "a build leaked, so this fails, and the two maps were not compared"] ++
      build_leaks(:first, first, paths) ++
      build_leaks(:second, second, paths) ++
      [
        "a leak list is identical only at empty: which call lands past a window is " <>
          "scheduling, so the leak is the finding, never a difference between these lists",
        CoverageMap.leak_fix()
      ]
  end

  def lines({:suite_failed, builds}, paths) do
    names = Enum.map_join(builds, " and ", &build_name(&1, paths))

    [
      @prefix <>
        "the suite failed in the #{names}, so that map describes a broken suite and the " <>
        "two were not compared",
      "Fix: make the suite green first"
    ]
  end

  def lines({:could_not_measure, refusals}, paths) do
    [
      "COULD NOT MEASURE: " <>
        @prefix <> "the two builds cannot be compared, so nothing is proven"
    ] ++
      Enum.map(refusals, &refusal_line(&1, paths)) ++
      [
        "Fix: run both builds at one commit, each writing its map " <>
          "(mix anchor.sabotage coverage --out PATH); each build's own output says why it wrote none"
      ]
  end

  # --- what a file must hold before anything is compared ---

  defp measured({:error, reason}), do: {:error, reason}

  defp measured({:ok, term}) do
    with {:ok, map} <- CoverageMap.check(term),
         :ok <- well_formed(map),
         :ok <- CoverageMap.validate(map) do
      {:ok, map}
    end
  end

  # `CoverageMap.check/1` holds what reaches a command line. This holds the rest of
  # what this module reads, so a bad artifact is a refusal, never a crash.
  defp well_formed(
         %{tests: tests, leaks: leaks, ambient: ambient, modules_traced: n, suite_exit: exit} =
           map
       )
       when is_integer(n) and n >= 0 and is_integer(exit) do
    if Enum.all?(tests, &is_binary(Map.get(&1, :name))) and Enum.all?(leaks, &leak?/1) and
         Enum.all?(ambient, &is_binary/1) and is_binary(Map.get(map, :elixir)) and
         is_binary(Map.get(map, :otp)) do
      :ok
    else
      {:error, :malformed}
    end
  end

  defp well_formed(_map), do: {:error, :malformed}

  defp leak?(%{from: %{file: file, line: line, name: name}, function: function}),
    do: is_binary(file) and is_integer(line) and is_binary(name) and is_binary(function)

  defp leak?(%{from: %{module: module}, function: function}),
    do: is_binary(module) and is_binary(function)

  defp leak?(_leak), do: false

  defp refusal(_build, {:ok, _map}), do: []
  defp refusal(build, {:error, reason}), do: [{build, reason}]

  # --- the verdict on two maps that can be compared ---

  defp judged(first, second) do
    with :ok <- one_build(first, second),
         :ok <- no_leak(first, second),
         :ok <- suites_passed(first, second) do
      compared(first, second)
    end
  end

  defp one_build(%{commit: nil}, %{commit: nil}), do: {:could_not_measure, [:no_commit]}

  defp one_build(first, second) do
    case Enum.find([:commit, :elixir, :otp], &(first[&1] != second[&1])) do
      nil -> :ok
      key -> {:could_not_measure, [{:different_build, key, first[key], second[key]}]}
    end
  end

  defp no_leak(%{leaks: []}, %{leaks: []}), do: :ok
  defp no_leak(%{leaks: first}, %{leaks: second}), do: {:leaked, first, second}

  defp suites_passed(%{suite_exit: 0}, %{suite_exit: 0}), do: :ok

  defp suites_passed(first, second) do
    failed = for {build, map} <- [first: first, second: second], map.suite_exit != 0, do: build
    {:suite_failed, failed}
  end

  defp compared(first, second) do
    if CoverageMap.canonical(first) == CoverageMap.canonical(second),
      do: :identical,
      else: {:different, differences(first, second)}
  end

  defp differences(first, second) do
    case test_differences(first.tests, second.tests) ++
           one_side(first.ambient, second.ambient, &{:ambient, &1, &2}) do
      [] -> [:unnamed]
      differences -> differences
    end
  end

  defp test_differences(first, second) do
    first = by_ref(first)
    second = by_ref(second)

    (Map.keys(first) ++ Map.keys(second))
    |> Enum.uniq()
    |> Enum.sort_by(&{&1.file, &1.line, &1.name})
    |> Enum.flat_map(&ref_differences(&1, Map.fetch(first, &1), Map.fetch(second, &1)))
  end

  defp by_ref(tests), do: Map.new(tests, &{Map.delete(&1, :functions), &1.functions})

  defp ref_differences(ref, {:ok, first}, {:ok, second}),
    do: one_side(first, second, &{:function, ref, &1, &2})

  defp ref_differences(ref, {:ok, first}, :error),
    do: [{:test, ref, :first} | one_side(first, [], &{:function, ref, &1, &2})]

  defp ref_differences(ref, :error, {:ok, second}),
    do: [{:test, ref, :second} | one_side([], second, &{:function, ref, &1, &2})]

  defp one_side(first, second, difference) do
    only_first = Enum.map(first -- second, &{&1, :first})
    only_second = Enum.map(second -- first, &{&1, :second})

    (only_first ++ only_second)
    |> Enum.sort()
    |> Enum.map(fn {function, build} -> difference.(function, build) end)
  end

  # --- words ---

  defp build_leaks(build, [], paths), do: ["#{build_name(build, paths)}: no leak"]

  defp build_leaks(build, leaks, paths),
    do: Enum.map(leaks, &"#{build_name(build, paths)}: #{CoverageMap.leak_pair(&1)}")

  defp difference_line({:function, ref, function, build}, paths),
    do: "differs: #{CoverageMap.owner_name(ref)} ran #{function}: #{only_in(build, paths)}"

  defp difference_line({:test, ref, build}, paths),
    do: "differs: #{CoverageMap.owner_name(ref)}: #{only_in(build, paths)}"

  defp difference_line({:ambient, function, build}, paths),
    do: "differs: ambient #{function}: #{only_in(build, paths)}"

  defp difference_line(:unnamed, paths) do
    "differs: the canonical bytes differ, and no test or function differs: " <>
      "compare #{paths.first} and #{paths.second} (an order or a field, not a set)"
  end

  defp only_in(build, paths), do: "only in the #{build_name(build, paths)}"

  defp refusal_line({:different_build, key, first, second}, _paths),
    do: "the two maps are not of one build: #{key} #{inspect(first)} and #{inspect(second)}"

  defp refusal_line(:same_file, paths),
    do: "#{paths.first} was given as both builds, and a file always equals itself"

  defp refusal_line(:no_commit, _paths),
    do: "a map has no commit, so it cannot say the two are builds of one commit"

  defp refusal_line({build, :enoent}, paths),
    do: "#{build_name(build, paths)}: no file, so that build wrote no map"

  defp refusal_line({build, reason}, paths),
    do: "#{build_name(build, paths)}: #{inspect(reason, limit: 8, printable_limit: 200)}"

  defp build_name(build, paths), do: "#{build} build (#{Map.fetch!(paths, build)})"
end
