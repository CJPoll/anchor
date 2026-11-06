defmodule Anchor.Domain.Sabotage.CoverageMapTest do
  # DND-5474, DND-5691: per-test coverage, classified from what the VM read at each
  # call and resolved once the run is over. Pids are only names here.
  # Sabotage record: ../../../sabotage_records/sabotage-20261103-dnd_5474_coverage_map.md
  # Sabotage record: ../../../sabotage_records/coverage_attribution-20261106-dnd_5691_causal_attribution.md
  use ExUnit.Case, async: true

  alias Anchor.Domain.Sabotage.CoverageMap

  @t1 %{file: "/proj/test/a_test.exs", line: 3, name: "test one", module: "ATest"}
  @t2 %{file: "/proj/test/b_test.exs", line: 7, name: "test two", module: "BTest"}
  @meta %{
    commit: "abababababababababababababababababababab",
    elixir: "1.19.4",
    otp: "28",
    modules_traced: 2,
    suite_exit: 0,
    total: 2,
    root: "/proj"
  }
  @a {A, :f, 0}
  @b {B, :g, 0}

  # Two tests of one runner, each with its own process calling one function.
  defp row1 do
    [runner, t1, t2] = for _i <- 1..3, do: spawn(fn -> :ok end)

    [
      {:test_started, runner, 1, @t1, ATest},
      {:spawn, runner, t1, nil},
      {:entry, 1},
      {:call, @a, t1, 1, 1},
      {:test_finished, runner, 2, true, ATest},
      {:test_started, runner, 3, @t2, BTest},
      {:spawn, runner, t2, nil},
      {:entry, 3},
      {:call, @b, t2, 3, 3},
      {:test_finished, runner, 4, true, BTest}
    ]
  end

  defp build(events, meta \\ @meta) do
    assert {:ok, map} =
             CoverageMap.new() |> CoverageMap.attribute(events) |> CoverageMap.finalize(meta)

    map
  end

  defp refused(events, meta \\ @meta),
    do: CoverageMap.new() |> CoverageMap.attribute(events) |> CoverageMap.finalize(meta)

  defp sets(map), do: Map.new(map.tests, &{&1.name, &1.functions})
  defp pid, do: spawn(fn -> :ok end)

  describe "attribute/2 and finalize/2" do
    test "each call goes to the test that owns its process" do
      map = build(row1())

      assert sets(map) == %{"test one" => ["A.f/0"], "test two" => ["B.g/0"]}
      assert map.leaks == []
      assert map.ambient == []
    end

    test "a thousand calls of one function make one element" do
      [started, spawn, entry, call, finished | _rest] = row1()
      calls = List.duplicate(call, 1000)
      map = build([started, spawn, entry] ++ calls ++ [finished], %{@meta | total: 1})

      assert sets(map) == %{"test one" => ["A.f/0"]}
      assert map.counters.call_rows == 1
    end

    test "a process spawned by the runner between windows belongs to the module" do
      [runner, s, t] = [pid(), pid(), pid()]

      map =
        build([
          {:module_started, runner, ATest},
          {:spawn, runner, s, nil},
          {:call, @a, s, ATest, 0},
          {:test_started, runner, 1, @t1, ATest},
          {:spawn, runner, t, nil},
          {:entry, 1},
          {:test_finished, runner, 2, true, ATest},
          {:test_started, runner, 3, %{@t1 | line: 9}, ATest},
          {:entry, 3},
          {:test_finished, runner, 4, true, ATest},
          {:module_finished, runner, ATest, 6}
        ])

      assert Enum.map(map.tests, & &1.functions) == [["A.f/0"], ["A.f/0"]]
    end

    test "a module credit never reaches its test that never ran" do
      [runner, s] = [pid(), pid()]

      map =
        build([
          {:test_started, runner, 1, %{@t1 | line: 9}, ATest},
          {:test_finished, runner, 2, false, ATest},
          {:module_started, runner, ATest},
          {:spawn, runner, s, nil},
          {:call, @a, s, ATest, 2},
          {:test_started, runner, 3, @t1, ATest},
          {:entry, 3},
          {:test_finished, runner, 4, true, ATest},
          {:module_finished, runner, ATest, 6}
        ])

      assert [%{line: 3, functions: ["A.f/0"]}] = map.tests
    end

    test "a spawn after the runner's module finished is not a root" do
      [runner, late] = [pid(), pid()]

      map =
        build(
          [
            {:module_started, runner, ATest},
            {:test_started, runner, 1, @t1, ATest},
            {:entry, 1},
            {:test_finished, runner, 2, true, ATest},
            {:module_finished, runner, ATest, 4},
            {:spawn, runner, late, nil},
            {:call, @a, late, :none, 4}
          ],
          %{@meta | total: 1}
        )

      assert map.ambient == ["A.f/0"]
    end

    test "mfa tuples become `Module.fun/arity` strings; files are made relative to root" do
      map = build(row1())

      assert [test | _rest] = map.tests
      assert test.functions == ["A.f/0"]
      assert test.file == "test/a_test.exs"
      assert test.module == "ATest"
    end

    test "the map records commit, versions, module count and suite exit" do
      map = build(row1())

      assert %{
               version: 2,
               commit: "abababababababababababababababababababab",
               elixir: "1.19.4",
               otp: "28"
             } = map

      assert map.modules_traced == 2
      assert map.suite_exit == 0
    end

    test "a test ExUnit ran twice (parameterized) is one row with both sets" do
      [runner, t1, t2] = [pid(), pid(), pid()]

      map =
        build([
          {:test_started, runner, 1, @t1, ATest},
          {:spawn, runner, t1, nil},
          {:entry, 1},
          {:call, @a, t1, 1, 1},
          {:test_finished, runner, 2, true, ATest},
          {:test_started, runner, 3, @t1, ATest},
          {:spawn, runner, t2, nil},
          {:entry, 3},
          {:call, @b, t2, 3, 3},
          {:test_finished, runner, 4, true, ATest}
        ])

      assert [%{functions: ["A.f/0", "B.g/0"]}] = map.tests
    end
  end

  describe "leaks and ambient" do
    test "a call past its owner's window is a leak, listed once, and still credited" do
      [runner, t] = [pid(), pid()]
      leak_calls = for word <- [2, 3, 4], do: {:call, @a, t, :none, word}

      map =
        build(
          [
            {:test_started, runner, 1, @t1, ATest},
            {:spawn, runner, t, nil},
            {:entry, 1},
            {:test_finished, runner, 2, true, ATest}
          ] ++ leak_calls,
          %{@meta | total: 1}
        )

      assert map.leaks == [
               %{
                 from: %{file: "test/a_test.exs", line: 3, name: "test one", module: "ATest"},
                 function: "A.f/0"
               }
             ]

      assert sets(map) == %{"test one" => ["A.f/0"]}
    end

    test "a parameterized module's end is its last by word, in either arrival order" do
      [r1, r2, s] = [pid(), pid(), pid()]

      started = [
        {:module_started, r1, ATest},
        {:spawn, r1, s, nil},
        {:module_started, r2, ATest},
        {:test_started, r2, 3, @t1, ATest},
        {:entry, 3},
        {:test_finished, r2, 4, true, ATest},
        {:call, @a, s, :none, 5}
      ]

      first = {:module_finished, r1, ATest, 2}
      last = {:module_finished, r2, ATest, 6}

      for ends <- [[first, last], [last, first]] do
        map = build(started ++ ends, %{@meta | total: 1})
        assert map.leaks == [], inspect(ends)
        assert sets(map) == %{"test one" => ["A.f/0"]}, inspect(ends)
      end
    end

    test "a module-owned call past the module leaks from the module" do
      [runner, s] = [pid(), pid()]

      map =
        build(
          [
            {:module_started, runner, ATest},
            {:spawn, runner, s, nil},
            {:test_started, runner, 1, @t1, ATest},
            {:entry, 1},
            {:test_finished, runner, 2, true, ATest},
            {:module_finished, runner, ATest, 4},
            {:call, @a, s, :none, 4}
          ],
          %{@meta | total: 1}
        )

      assert map.leaks == [%{from: %{module: "ATest"}, function: "A.f/0"}]
      assert sets(map) == %{"test one" => ["A.f/0"]}
    end

    test "an unowned call is ambient, credited to no test; a label in its window credits" do
      [_ | _] = events = row1()
      [server, compiler] = [pid(), pid()]

      map =
        build(
          events ++
            [
              {:call, {S, :stale, 0}, server, 1, 3},
              {:call, {S, :handler, 0}, server, 3, 3},
              {:call, {C, :body, 0}, compiler, :none, 0}
            ]
        )

      assert map.ambient == ["C.body/0", "S.stale/0"]
      assert sets(map)["test two"] == ["B.g/0", "S.handler/0"]
      assert map.counters.credited_by_label == 1
      assert map.leaks == []
    end

    test "leak_lines/1 names each pair and ends with a Fix:; no leak, no lines" do
      assert CoverageMap.leak_lines(build(row1())) == []

      map = %{
        leaks: [
          %{from: %{file: "test/a_test.exs", line: 3, name: "test one"}, function: "A.f/0"},
          %{from: %{module: "ATest"}, function: "B.g/0"}
        ]
      }

      assert [first, second, fix] = CoverageMap.leak_lines(map)
      assert first =~ "leak: test/a_test.exs:3 test one left a process that called A.f/0"
      assert second =~ "leak: setup_all of ATest left a process that called B.g/0"
      assert fix =~ "Fix: make the process end inside its test"
    end
  end

  describe "refusals: a run that cannot be believed writes no map" do
    test "fewer windows than total" do
      assert refused(row1(), %{@meta | total: 3}) == {:error, {:windows, 2, 3}}
    end

    test "windows with no total" do
      assert refused(row1(), %{@meta | total: nil}) == {:error, {:windows, 2, nil}}
    end

    test "no windows and no total is no refusal here: validate/1 says it measured nothing" do
      assert {:ok, %{tests: []}} = refused([], %{@meta | total: nil})
    end

    test "a test that ran with no entry message, naming it" do
      runner = pid()

      assert refused(
               [
                 {:test_started, runner, 1, @t1, ATest},
                 {:test_finished, runner, 2, true, ATest}
               ],
               %{@meta | total: 1}
             ) == {:error, {:no_entry, @t1}}
    end

    test "a test with no process needs no entry, and is not in the map" do
      runner = pid()

      assert {:ok, %{tests: []}} =
               refused(
                 [
                   {:test_started, runner, 1, @t1, ATest},
                   {:test_finished, runner, 2, false, ATest}
                 ],
                 %{@meta | total: 1}
               )
    end

    test "a label from outside this run, or a recorded error, by name" do
      assert refused(row1() ++ [{:call, @a, pid(), {:x}, 1}]) == {:error, {:bad_label, {:x}}}

      assert refused(row1() ++ [{:error, {:task_shape, {Task.Supervised, :noreply, []}}}]) ==
               {:error, {:task_shape, {Task.Supervised, :noreply, []}}}
    end

    test "a test finished with no start, by name" do
      assert {:error, {:unreadable, {:test_finished, 2}}} =
               refused([{:test_finished, pid(), 2, true, ATest}], %{@meta | total: 1})
    end

    test "a module that started and never finished" do
      runner = pid()

      assert refused(
               [
                 {:module_started, runner, ATest},
                 {:test_started, runner, 1, @t1, ATest},
                 {:entry, 1},
                 {:test_finished, runner, 2, true, ATest}
               ],
               %{@meta | total: 1}
             ) == {:error, {:module_unfinished, ATest}}
    end
  end

  describe "canonical/1" do
    # A real arrival order keeps each tracee's own order, and only that: the three
    # below interleave the runner's, the test process's and a server's.
    test "1: the same calls and edges in any arrival order give the same bytes" do
      [runner, t, server, a] = [pid(), pid(), pid(), pid()]

      runner_stream = [
        {:test_started, runner, 1, @t1, ATest},
        {:spawn, runner, t, nil},
        {:test_finished, runner, 2, true, ATest}
      ]

      others = [
        {:entry, 1},
        {:spawn, t, a, nil},
        {:call, @a, t, 1, 1},
        {:call, @b, a, 1, 2},
        {:call, {S, :h, 0}, server, 1, 1}
      ]

      bytes =
        for order <- [
              runner_stream ++ others,
              others ++ runner_stream,
              Enum.reverse(others) ++ runner_stream
            ] do
          order |> build(%{@meta | total: 1}) |> CoverageMap.canonical()
        end

      assert [same, same, same] = bytes
    end

    test "2: a leak is listed once" do
      [runner, t] = [pid(), pid()]

      events =
        [
          {:test_started, runner, 1, @t1, ATest},
          {:spawn, runner, t, nil},
          {:entry, 1},
          {:test_finished, runner, 2, true, ATest}
        ] ++ for(word <- 2..6, do: {:call, @a, t, :none, word})

      map = build(events, %{@meta | total: 1})
      assert length(map.leaks) == 1
    end

    test "3: no counts, no stamps, no pids, no commit" do
      map = build(row1())
      term = map |> CoverageMap.canonical() |> :erlang.binary_to_term()

      assert Map.keys(term) |> Enum.sort() == [:ambient, :leaks, :tests, :version]
      refute inspect(term) =~ "#PID"

      assert CoverageMap.canonical(%{map | commit: nil, counters: %{}}) ==
               CoverageMap.canonical(map)
    end

    test "a function called in another order or by another pid changes nothing" do
      first = row1()
      second = row1()
      assert CoverageMap.canonical(build(first)) == CoverageMap.canonical(build(second))
    end
  end

  describe "summary/2" do
    test "the counters live on the summary line" do
      line = CoverageMap.summary(build(row1()), "out.etf")

      assert line =~ "tests: 2, modules_traced: 2, leaks: 0, ambient: 0, call_rows: 2"
      assert line =~ "credited_by_label: 0, suite_exit: 0"
      assert line =~ "wrote out.etf"
    end
  end

  describe "validate/1 and tests_for/2" do
    test "1: zero tests is refused" do
      assert CoverageMap.validate(build([], %{@meta | total: 0})) == {:error, :no_tests}
    end

    test "2: zero modules traced is refused" do
      map = %{build(row1()) | modules_traced: 0}
      assert CoverageMap.validate(map) == {:error, :no_modules}
    end

    test "a map with tests and modules is valid" do
      assert CoverageMap.validate(build(row1())) == :ok
    end

    test "3: tests_for lists the tests that ran a function, and none for another" do
      map = build(row1())

      assert CoverageMap.tests_for(map, "A.f/0") == [
               %{file: "test/a_test.exs", line: 3, name: "test one", module: "ATest"}
             ]

      assert CoverageMap.tests_for(map, "Z.z/0") == []
    end

    test "index/1 maps each function to its tests' file:line args" do
      assert CoverageMap.index(build(row1())) == %{
               "A.f/0" => ["test/a_test.exs:3"],
               "B.g/0" => ["test/b_test.exs:7"]
             }
    end
  end

  describe "check/1: every field that reaches a command line is checked" do
    defp with_test(map, file, line \\ 3),
      do: %{
        map
        | tests: [%{file: file, line: line, name: "t", module: "M", functions: ["A.f/0"]}]
      }

    test "commit is nil or a 40-character lowercase hex sha" do
      map = build(row1())
      sha = String.duplicate("a1", 20)

      assert {:ok, _map} = CoverageMap.check(%{map | commit: sha})
      assert {:ok, _map} = CoverageMap.check(%{map | commit: nil})
      assert CoverageMap.check(%{map | commit: "--output=x"}) == {:error, {:commit, "--output=x"}}
      assert CoverageMap.check(%{map | commit: 1}) == {:error, {:commit, 1}}

      assert CoverageMap.check(%{map | commit: String.upcase(sha)}) ==
               {:error, {:commit, String.upcase(sha)}}
    end

    test "a test file is a relative path inside the project that is not an option" do
      map = build(row1())

      assert {:ok, _map} = CoverageMap.check(with_test(map, "test/a_test.exs"))

      # DND-5640: the shared TestPath rule, so a non-test file is refused too.
      for file <- [
            "-x",
            "--include=slow",
            "/etc/x_test.exs",
            "test/../../x.exs",
            "",
            "test/x.exs"
          ] do
        assert CoverageMap.check(with_test(map, file)) == {:error, {:test_file, file}},
               inspect(file)
      end

      assert CoverageMap.check(with_test(map, "test/a_test.exs", 0)) == {:error, :not_a_map}
    end
  end

  describe "check/1" do
    test "a version-2 map passes; version 1, another version or another term is refused" do
      map = build(row1())

      assert CoverageMap.check(map) == {:ok, map}
      assert CoverageMap.check(%{map | version: 1}) == {:error, {:version, 1}}
      assert CoverageMap.check(%{map | version: 3}) == {:error, {:version, 3}}
      assert CoverageMap.check(:nope) == {:error, :not_a_map}
      assert CoverageMap.check(%{map | tests: [%{file: 1}]}) == {:error, :not_a_map}
      assert CoverageMap.check(Map.delete(map, :leaks)) == {:error, :not_a_map}
      assert CoverageMap.check(%{map | ambient: :x}) == {:error, :not_a_map}
    end
  end
end
