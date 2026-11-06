defmodule Anchor.Domain.Sabotage.CoverageCompareTest do
  # DND-5692: the verdict on two builds of one commit at one seed. Pure: read results
  # in, a verdict, an exit code and lines out.
  # Sabotage record: ../../../sabotage_records/coverage_compare-20261106-dnd_5692_repeatability_check.md
  use ExUnit.Case, async: true

  alias Anchor.Domain.Sabotage.CoverageCompare
  alias Anchor.Domain.Sabotage.CoverageMap

  @sha String.duplicate("a", 40)
  @a %{file: "test/a_test.exs", line: 3, name: "test one", module: "ATest"}
  @b %{file: "test/b_test.exs", line: 9, name: "test two", module: "BTest"}
  @paths %{first: "one.etf", second: "two.etf"}

  defp map(overrides \\ %{}) do
    Map.merge(
      %{
        version: 2,
        commit: @sha,
        elixir: "1.19.4",
        otp: "28",
        tests: [Map.put(@a, :functions, ["A.f/0", "A.g/1"]), Map.put(@b, :functions, ["B.f/0"])],
        leaks: [],
        ambient: ["C.boot/0"],
        modules_traced: 3,
        suite_exit: 0,
        counters: %{call_rows: 5, credited_by_label: 0, spawns: 2}
      },
      overrides
    )
  end

  defp judge(first, second), do: CoverageCompare.judge({:ok, first}, {:ok, second})
  defp text(verdict), do: verdict |> CoverageCompare.lines(@paths) |> Enum.join("\n")

  describe "two identical builds" do
    test "pass, exit 0, and the line names what was compared" do
      verdict = judge(map(), map())

      assert verdict == :identical
      assert CoverageCompare.exit_code(verdict) == 0
      assert text(verdict) =~ "identical"
      assert text(verdict) =~ "one.etf"
      assert text(verdict) =~ "two.etf"
    end

    test "what canonical/1 does not hold is not compared: counters differ, still identical" do
      second = map(%{counters: %{call_rows: 500, credited_by_label: 1, spawns: 9}})

      assert judge(map(), second) == :identical
    end
  end

  describe "a function that differs" do
    test "in a test's set: exit 1, the test and the function named, with the build holding it" do
      second =
        map(%{
          tests: [Map.put(@a, :functions, ["A.f/0"]), Map.put(@b, :functions, ["B.f/0"])]
        })

      verdict = judge(map(), second)

      assert verdict == {:different, [{:function, @a, "A.g/1", :first}]}
      assert CoverageCompare.exit_code(verdict) == 1

      assert text(verdict) =~
               "differs: test/a_test.exs:3 test one ran A.g/1: only in the first build"

      assert text(verdict) =~ "Fix: "
    end

    test "held by the second build alone: the line says the second" do
      second =
        map(%{
          tests: [
            Map.put(@a, :functions, ["A.f/0", "A.g/1", "A.h/2"]),
            Map.put(@b, :functions, ["B.f/0"])
          ]
        })

      verdict = judge(map(), second)

      assert verdict == {:different, [{:function, @a, "A.h/2", :second}]}
      assert text(verdict) =~ "ran A.h/2: only in the second build"
    end

    test "in ambient: exit 1, the function named" do
      verdict = judge(map(), map(%{ambient: ["C.boot/0", "C.late/0"]}))

      assert verdict == {:different, [{:ambient, "C.late/0", :second}]}
      assert CoverageCompare.exit_code(verdict) == 1
      assert text(verdict) =~ "differs: ambient C.late/0: only in the second build"
    end

    test "a test in one build only is named, with each function it ran" do
      second = map(%{tests: [Map.put(@a, :functions, ["A.f/0", "A.g/1"])]})

      verdict = judge(map(), second)

      assert verdict ==
               {:different, [{:test, @b, :first}, {:function, @b, "B.f/0", :first}]}

      assert text(verdict) =~ "differs: test/b_test.exs:9 test two: only in the first build"
      assert text(verdict) =~ "test/b_test.exs:9 test two ran B.f/0: only in the first build"
    end

    test "every difference is listed, not only the first" do
      second =
        map(%{
          ambient: [],
          tests: [Map.put(@a, :functions, ["A.f/0"]), Map.put(@b, :functions, [])]
        })

      assert {:different, differences} = judge(map(), second)

      assert differences == [
               {:function, @a, "A.g/1", :first},
               {:function, @b, "B.f/0", :first},
               {:ambient, "C.boot/0", :first}
             ]
    end

    test "bytes that differ with no pair to name still fail, and say so" do
      reordered = map(%{ambient: ["C.boot/0", "C.late/0"]})
      second = map(%{ambient: ["C.late/0", "C.boot/0"]})

      verdict = judge(reordered, second)

      assert verdict == {:different, [:unnamed]}
      assert CoverageCompare.exit_code(verdict) == 1
      assert text(verdict) =~ "the canonical bytes differ, and no test or function differs"
      assert text(verdict) =~ "Fix: "
    end
  end

  describe "a leak" do
    @leak %{from: @a, function: "A.late/0"}
    @module_leak %{from: %{module: "BTest"}, function: "B.late/0"}

    test "in the second build only: exit 1, each build's pairs, the note, a Fix: line" do
      verdict = judge(map(), map(%{leaks: [@leak]}))

      assert verdict == {:leaked, [], [@leak]}
      assert CoverageCompare.exit_code(verdict) == 1

      output = text(verdict)
      assert output =~ "first build (one.etf): no leak"
      assert output =~ "second build (two.etf): leak: test/a_test.exs:3 test one left a process"
      assert output =~ "A.late/0"
      assert output =~ "a leak list is identical only at empty"
      assert output =~ "Fix: make the process end inside its test"
    end

    test "in the first build only: still fails, and the second's clean list is printed" do
      verdict = judge(map(%{leaks: [@leak]}), map())

      assert verdict == {:leaked, [@leak], []}
      assert CoverageCompare.exit_code(verdict) == 1
      assert text(verdict) =~ "first build (one.etf): leak: test/a_test.exs:3"
      assert text(verdict) =~ "second build (two.etf): no leak"
    end

    test "in both, with different lists: the lists are not compared as nondeterminism" do
      verdict = judge(map(%{leaks: [@leak]}), map(%{leaks: [@leak, @module_leak]}))

      assert verdict == {:leaked, [@leak], [@leak, @module_leak]}

      output = text(verdict)
      assert output =~ "setup_all of BTest left a process that called B.late/0"
      refute output =~ "differs:"
      refute output =~ "nondeterministic"
    end

    test "in both, with the same list: it still fails" do
      verdict = judge(map(%{leaks: [@leak]}), map(%{leaks: [@leak]}))

      assert verdict == {:leaked, [@leak], [@leak]}
      assert CoverageCompare.exit_code(verdict) == 1
    end

    test "the leak is reported before a difference in the map" do
      verdict = judge(map(%{leaks: [@leak]}), map(%{ambient: []}))

      assert verdict == {:leaked, [@leak], []}
    end

    test "the Fix: line is the one a build prints" do
      fix = {:leaked, [@leak], []} |> CoverageCompare.lines(@paths) |> List.last()

      assert fix == map(%{leaks: [@leak]}) |> CoverageMap.leak_lines() |> List.last()
    end
  end

  describe "a build that cannot be compared: COULD NOT MEASURE, exit 3" do
    test "a missing second build, naming it" do
      verdict = CoverageCompare.judge({:ok, map()}, {:error, :enoent})

      assert verdict == {:could_not_measure, [{:second, :enoent}]}
      assert CoverageCompare.exit_code(verdict) == 3

      output = text(verdict)
      assert output =~ "COULD NOT MEASURE"
      assert output =~ "second build (two.etf): no file"
      assert output =~ "Fix: "
    end

    test "a missing first build, naming it" do
      verdict = CoverageCompare.judge({:error, :enoent}, {:ok, map()})

      assert verdict == {:could_not_measure, [{:first, :enoent}]}
      assert CoverageCompare.exit_code(verdict) == 3
    end

    test "both missing: both named" do
      verdict = CoverageCompare.judge({:error, :enoent}, {:error, :enoent})

      assert verdict == {:could_not_measure, [{:first, :enoent}, {:second, :enoent}]}
      assert text(verdict) =~ "first build (one.etf)"
      assert text(verdict) =~ "second build (two.etf)"
    end

    test "a missing build wins over a leak in the other: the job cannot say it compared" do
      leaked = map(%{leaks: [%{from: @a, function: "A.late/0"}]})

      verdict = CoverageCompare.judge({:ok, leaked}, {:error, :enoent})

      assert CoverageCompare.exit_code(verdict) == 3
    end

    test "an unreadable file" do
      verdict = CoverageCompare.judge({:ok, map()}, {:error, :undecodable})

      assert verdict == {:could_not_measure, [{:second, :undecodable}]}
      assert text(verdict) =~ "second build (two.etf): :undecodable"
    end

    test "a term that is no map, an old version, and a bad commit are refused" do
      assert judge(map(), :nonsense) == {:could_not_measure, [{:second, :not_a_map}]}

      assert judge(map(), map(%{version: 1})) ==
               {:could_not_measure, [{:second, {:version, 1}}]}

      assert judge(map(%{commit: "main"}), map()) ==
               {:could_not_measure, [{:first, {:commit, "main"}}]}
    end

    test "a map that measured nothing is refused: two empty maps are not repeatable" do
      empty = map(%{tests: []})

      verdict = judge(empty, empty)

      assert verdict == {:could_not_measure, [{:first, :no_tests}, {:second, :no_tests}]}
      assert CoverageCompare.exit_code(verdict) == 3

      assert judge(map(%{modules_traced: 0}), map()) ==
               {:could_not_measure, [{:first, :no_modules}]}
    end

    test "a field the comparison reads that is missing or the wrong shape is refused" do
      for broken <- [
            Map.delete(map(), :modules_traced),
            Map.delete(map(), :suite_exit),
            map(%{modules_traced: -1}),
            Map.delete(map(), :elixir),
            Map.delete(map(), :otp),
            map(%{ambient: [:not_text]}),
            map(%{leaks: [:not_a_leak]}),
            map(%{leaks: [%{from: %{file: "x"}, function: "A.f/0"}]}),
            map(%{leaks: [%{from: @a, function: :not_text}]}),
            map(%{tests: [%{file: "test/a_test.exs", line: 3, functions: []}]})
          ] do
        assert judge(broken, map()) == {:could_not_measure, [{:first, :malformed}]}
      end
    end

    test "one file given as both builds says so" do
      verdict = {:could_not_measure, [:same_file]}

      assert CoverageCompare.exit_code(verdict) == 3
      assert text(verdict) =~ "one.etf was given as both builds"
    end

    test "maps of two commits are not two builds of one" do
      other = String.duplicate("b", 40)

      verdict = judge(map(), map(%{commit: other}))

      assert verdict == {:could_not_measure, [{:different_build, :commit, @sha, other}]}
      assert CoverageCompare.exit_code(verdict) == 3
      assert text(verdict) =~ "the two maps are not of one build: commit #{inspect(@sha)}"
    end

    test "maps of two tool versions are not two builds of one" do
      assert judge(map(), map(%{elixir: "1.18.0"})) ==
               {:could_not_measure, [{:different_build, :elixir, "1.19.4", "1.18.0"}]}

      assert judge(map(), map(%{otp: "27"})) ==
               {:could_not_measure, [{:different_build, :otp, "28", "27"}]}
    end

    test "a map with no commit cannot say it is the same commit" do
      verdict = judge(map(%{commit: nil}), map(%{commit: nil}))

      assert verdict == {:could_not_measure, [:no_commit]}
      assert CoverageCompare.exit_code(verdict) == 3

      assert judge(map(%{commit: nil}), map()) ==
               {:could_not_measure, [{:different_build, :commit, nil, @sha}]}
    end
  end

  describe "a failed suite" do
    test "fails on its own, naming the build, and is not called repeatable" do
      verdict = judge(map(), map(%{suite_exit: 1}))

      assert verdict == {:suite_failed, [:second]}
      assert CoverageCompare.exit_code(verdict) == 1

      output = text(verdict)
      assert output =~ "second build (two.etf)"
      assert output =~ "Fix: make the suite green first"
      refute output =~ "identical"
    end

    test "in both builds: both named, even with the same bytes" do
      failed = map(%{suite_exit: 1})

      assert judge(failed, failed) == {:suite_failed, [:first, :second]}
    end

    test "a leak is still printed first" do
      leak = %{from: @a, function: "A.late/0"}

      assert judge(map(%{leaks: [leak], suite_exit: 1}), map()) == {:leaked, [leak], []}
    end
  end
end
