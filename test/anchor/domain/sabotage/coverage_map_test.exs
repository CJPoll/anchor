defmodule Anchor.Domain.Sabotage.CoverageMapTest do
  # DND-5474: per-test coverage, windowed by strict monotonic stamps. The
  # order of events is set by their stamps, never by real time.
  # Sabotage record: ../../../sabotage_records/sabotage-20261103-dnd_5474_coverage_map.md
  # Sabotage record (DND-5489): ../../../sabotage_records/sabotage-20261106-dnd_5470_param_sink_locality.md
  # Sabotage record (DND-5642): ../../../sabotage_records/sabotage-20261103-dnd_5639_sabotage_followups.md
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
    root: "/proj"
  }

  defp row1 do
    [
      {:window_open, 1, @t1},
      {:call, 2, "A.f/0"},
      {:window_close, 3, @t1},
      {:window_open, 4, @t2},
      {:call, 5, "B.g/0"},
      {:window_close, 6, @t2}
    ]
  end

  defp build(events, slack \\ 10) do
    [slack: slack] |> CoverageMap.new() |> CoverageMap.attribute(events) |> finalize()
  end

  defp finalize(state), do: CoverageMap.finalize(state, @meta)

  defp sets(map), do: Map.new(map.tests, &{&1.name, &1.functions})

  describe "check/1, a test's name (DND-5489)" do
    test "a test with no string name is no usable map: a key is built from it" do
      test_ref = %{file: "test/a_test.exs", line: 1, functions: []}
      map = %{version: 1, commit: nil, tests: [test_ref]}

      assert CoverageMap.check(map) == {:error, :not_a_map}

      assert CoverageMap.check(%{map | tests: [Map.put(test_ref, :name, :atom)]}) ==
               {:error, :not_a_map}

      assert {:ok, _map} = CoverageMap.check(%{map | tests: [Map.put(test_ref, :name, "test a")]})
    end
  end

  describe "attribute/2 and finalize/2" do
    test "1: each call goes to the window it happened in" do
      map = build(row1())

      assert sets(map) == %{"test one" => ["A.f/0"], "test two" => ["B.g/0"]}
      assert map.outside_windows == 0
      assert map.late_events == 0
    end

    test "2: events out of arrival order are attributed by stamp" do
      [open1, call_a, close1, open2, call_b, close2] = row1()
      shuffled = [open1, call_b, call_a, open2, close1, close2]

      assert sets(build(shuffled)) == sets(build(row1()))
      assert sets(build(shuffled, 6)) == %{"test one" => ["A.f/0"], "test two" => ["B.g/0"]}
    end

    test "2: a batch boundary does not reorder: the slack holds back events" do
      [open1, call_a, close1, open2, call_b, close2] = row1()

      state =
        [slack: 2]
        |> CoverageMap.new()
        |> CoverageMap.attribute([open1, call_b, open2])
        |> CoverageMap.attribute([call_a, close1, close2])

      assert sets(finalize(state)) == %{"test one" => ["A.f/0"], "test two" => ["B.g/0"]}
      assert finalize(state).late_events == 0
    end

    test "3: a call after every window closed is outside_windows, in no test" do
      map = build(row1() ++ [{:call, 7, "C.h/0"}])

      assert map.outside_windows == 1
      refute Enum.any?(map.tests, &("C.h/0" in &1.functions))
      assert sets(map) == %{"test one" => ["A.f/0"], "test two" => ["B.g/0"]}
    end

    test "4: 50 alternating tests never mix their sets" do
      events =
        Enum.flat_map(1..50, fn i ->
          ref = %{file: "/proj/test/x_test.exs", line: i, name: "test #{i}", module: "XTest"}
          call = if rem(i, 2) == 1, do: "A.f/0", else: "B.g/0"
          base = i * 10
          [{:window_open, base, ref}, {:call, base + 1, call}, {:window_close, base + 2, ref}]
        end)

      map = build(events, 7)

      assert length(map.tests) == 50

      for test <- map.tests do
        expected = if rem(test.line, 2) == 1, do: ["A.f/0"], else: ["B.g/0"]
        assert test.functions == expected, "test #{test.line}: #{inspect(test.functions)}"
      end
    end

    test "5: a thousand calls of one function make one element" do
      calls = for i <- 1..1000, do: {:call, i + 1, "A.f/0"}
      events = [{:window_open, 1, @t1}] ++ calls ++ [{:window_close, 2000, @t1}]

      assert [%{functions: ["A.f/0"]}] = build(events, 50).tests
    end

    test "6: an event later than the slack allows is counted, never attributed" do
      events = [
        {:window_open, 10, @t1},
        {:call, 20, "A.f/0"},
        {:window_close, 30, @t1},
        {:window_open, 40, @t2},
        {:call, 50, "B.g/0"}
      ]

      state = [slack: 2] |> CoverageMap.new() |> CoverageMap.attribute(events)
      state = CoverageMap.attribute(state, [{:call, 15, "LATE.x/0"}, {:window_close, 60, @t2}])
      map = finalize(state)

      assert map.late_events == 1
      refute Enum.any?(map.tests, &("LATE.x/0" in &1.functions))
      assert CoverageMap.summary(map, "out.etf") =~ "late_events: 1"
    end

    test "mfa tuples become `Module.fun/arity` strings; files are made relative to root" do
      events = [
        {:window_open, 1, @t1},
        {:call, 2, {Anchor.Domain.GlobPattern, :matches_pattern?, 2}},
        {:window_close, 3, @t1}
      ]

      assert [test] = build(events).tests
      assert test.functions == ["Anchor.Domain.GlobPattern.matches_pattern?/2"]
      assert test.file == "test/a_test.exs"
      assert test.module == "ATest"
    end

    test "the map records commit, versions, module count and suite exit" do
      map = build(row1())

      assert %{
               version: 1,
               commit: "abababababababababababababababababababab",
               elixir: "1.19.4",
               otp: "28"
             } = map

      assert map.modules_traced == 2
      assert map.suite_exit == 0
    end

    test "a window the suite never closed is kept" do
      map = build([{:window_open, 1, @t1}, {:call, 2, "A.f/0"}])
      assert sets(map) == %{"test one" => ["A.f/0"]}
    end
  end

  describe "validate/1 and tests_for/2" do
    test "1: zero tests is refused" do
      assert CoverageMap.validate(build([])) == {:error, :no_tests}
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
    test "a version-1 map passes; another version or another term is refused" do
      map = build(row1())

      assert CoverageMap.check(map) == {:ok, map}
      assert CoverageMap.check(%{map | version: 2}) == {:error, {:version, 2}}
      assert CoverageMap.check(:nope) == {:error, :not_a_map}
      assert CoverageMap.check(%{map | tests: [%{file: 1}]}) == {:error, :not_a_map}
    end
  end

  describe "window leaks (DND-5642)" do
    @p1 :erlang.list_to_pid(~c"<0.901.0>")
    @p2 :erlang.list_to_pid(~c"<0.902.0>")
    @t3 %{file: "/proj/test/b_test.exs", line: 11, name: "test three", module: "BTest"}

    defp rel(ref), do: %{ref | file: Path.relative_to(ref.file, "/proj")}

    defp leaking do
      [
        {:window_open, 1, @t1},
        {:call, 2, "A.f/0", @p1},
        {:window_close, 3, @t1},
        {:window_open, 4, @t2},
        {:call, 5, "B.g/0", @p1},
        {:call, 6, "B.g/0", @p1},
        {:window_close, 7, @t2}
      ]
    end

    test "L1: a process first seen in an earlier window, calling in a later one, is a leak; selection unchanged" do
      map = build(leaking())

      assert map.window_leaks == [%{from: [rel(@t1)], to: rel(@t2), calls: 2}]
      assert sets(map) == %{"test one" => ["A.f/0"], "test two" => ["B.g/0"]}

      assert CoverageMap.leak_warnings(map) == [
               "anchor.sabotage coverage: warning: test/b_test.exs: 2 calls from a process first " <>
                 "seen during an earlier test were credited to a later test (selection unchanged): " <>
                 "test/a_test.exs:3 test one -> test/b_test.exs:7 test two (2 calls)"
             ]
    end

    test "L2: positive control: a clean pair (each process in its own window) has no leak" do
      events = [
        {:window_open, 1, @t1},
        {:call, 2, "A.f/0", @p1},
        {:window_close, 3, @t1},
        {:window_open, 4, @t2},
        {:call, 5, "B.g/0", @p2},
        {:window_close, 6, @t2}
      ]

      map = build(events)
      assert map.window_leaks == []
      assert CoverageMap.leak_warnings(map) == []
      assert sets(map) == %{"test one" => ["A.f/0"], "test two" => ["B.g/0"]}
    end

    test "L3: a process first seen outside every window is never a leak" do
      map = build([{:call, 1, "A.f/0", @p1} | tl(tl(leaking()))])

      assert map.window_leaks == []
      assert map.outside_windows == 1
    end

    test "L4: a call while the window that first saw the process is still open is no leak" do
      events = [
        {:window_open, 1, @t1},
        {:call, 2, "A.f/0", @p1},
        {:window_open, 3, @t2},
        {:call, 4, "B.g/0", @p1},
        {:window_close, 5, @t1},
        {:window_close, 6, @t2}
      ]

      assert build(events).window_leaks == []
    end

    test "L5: leaks follow stamp order, not arrival order" do
      [open1, call_a, close1, open2, call_b, call_b2, close2] = leaking()
      shuffled = [open1, open2, call_b, close1, call_a, call_b2, close2]

      assert build(shuffled).window_leaks == build(leaking()).window_leaks
    end

    test "L6: one line per credited test file, at most five pairs shown, in file order" do
      earlier =
        for i <- 1..7 do
          %{file: "/proj/test/a_test.exs", line: i, name: "test a#{i}", module: "ATest"}
        end

      pids = for i <- 1..7, do: :erlang.list_to_pid(~c"<0.#{910 + i}.0>")

      firsts =
        earlier
        |> Enum.zip(pids)
        |> Enum.with_index()
        |> Enum.flat_map(fn {{ref, pid}, i} ->
          [
            {:window_open, i * 3 + 1, ref},
            {:call, i * 3 + 2, "A.f/0", pid},
            {:window_close, i * 3 + 3, ref}
          ]
        end)

      later =
        [{:window_open, 100, @t2}] ++
          Enum.with_index(pids, &{:call, 101 + &2, "B.g/0", &1}) ++
          [{:window_close, 120, @t2}, {:window_open, 121, @t3}, {:call, 122, "B.g/0", hd(pids)}] ++
          [{:window_close, 123, @t3}]

      map = build(firsts ++ later, 50)
      assert [b_line] = CoverageMap.leak_warnings(map)

      assert b_line =~ "warning: test/b_test.exs: 8 calls from a process"
      assert b_line =~ "test/a_test.exs:1 test a1 -> test/b_test.exs:7 test two (1 calls); "

      assert b_line =~
               "test/a_test.exs:5 test a5 -> test/b_test.exs:7 test two (1 calls); and 3 more"

      # The three not shown: a6 and a7 into test two, a1 into test three.
      refute b_line =~ "test three"
      assert b_line =~ "; and 3 more"
      assert length(map.window_leaks) == 8

      a_leak = %{file: "/proj/test/a_test.exs", line: 9, name: "test a9", module: "ATest"}

      two_files =
        build(
          firsts ++
            [
              {:window_open, 200, a_leak},
              {:call, 201, "B.g/0", hd(pids)},
              {:window_close, 202, a_leak}
            ] ++
            later,
          50
        )

      assert [a_line, b_line2] = CoverageMap.leak_warnings(two_files)
      assert a_line =~ "warning: test/a_test.exs: 1 calls"
      assert b_line2 =~ "warning: test/b_test.exs: "
    end

    test "L8: an application process a test first wakes is reported as first seen there, never as started by it" do
      # A long-lived server sits idle until test one calls it, then serves
      # test two: its calls in test two are reported, and the line claims
      # only where it was first seen.
      server = :erlang.list_to_pid(~c"<0.950.0>")

      map =
        build([
          {:window_open, 1, @t1},
          {:call, 2, "Cache.get/1", server},
          {:window_close, 3, @t1},
          {:window_open, 4, @t2},
          {:call, 5, "Cache.get/1", server},
          {:window_close, 6, @t2}
        ])

      assert [line] = CoverageMap.leak_warnings(map)
      assert line =~ "1 calls from a process first seen during an earlier test"
      refute line =~ "started"
    end

    test "L7: a call with no pid (an older event shape) and a map with no window_leaks warn of nothing" do
      events = [
        {:window_open, 1, @t1},
        {:call, 2, "A.f/0"},
        {:window_close, 3, @t1},
        {:window_open, 4, @t2},
        {:call, 5, "B.g/0"},
        {:window_close, 6, @t2}
      ]

      assert build(events).window_leaks == []
      assert CoverageMap.leak_warnings(Map.delete(build(events), :window_leaks)) == []
    end
  end
end
