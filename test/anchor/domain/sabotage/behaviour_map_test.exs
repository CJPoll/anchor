defmodule Anchor.Domain.Sabotage.BehaviourMapTest do
  # DND-5489: the functions that confirm a behaviour, and how far they spread.
  # Pure Domain.
  # Sabotage record: ../../../sabotage_records/sabotage-20261106-dnd_5470_param_sink_locality.md
  use ExUnit.Case, async: true

  alias Anchor.Domain.Baseline
  alias Anchor.Domain.Sabotage.BehaviourMap
  alias Anchor.Domain.Sabotage.BehaviourMap.Behaviour

  @t_file "test/t_test.exs"
  @t_name "test t does it"
  @t_key "test/t_test.exs::test t does it"
  @u_key "test/u_test.exs::test u"

  defp test_ref(functions, overrides \\ %{}) do
    Map.merge(
      %{file: @t_file, line: 3, name: @t_name, module: "TTest", functions: functions},
      overrides
    )
  end

  defp map(tests), do: %{tests: tests}

  defp killed(mfa, file, killers \\ ["#{@t_file}:3 #{@t_name}"]) do
    %{id: "x", file: file, mfa: mfa, operator: "op", status: "killed", killers: killers}
  end

  defp one(result) do
    assert [%Behaviour{} = behaviour] = result.behaviours
    behaviour
  end

  describe "build/3" do
    test "a test that killed a mutant of each function it ran: both confirmed, both directories" do
      result =
        BehaviourMap.build(
          map([test_ref(["A.f/0", "B.g/0"])]),
          [killed("A.f/0", "lib/a/a.ex"), killed("B.g/0", "lib/b/b.ex")],
          %{}
        )

      behaviour = one(result)
      assert behaviour.test_key == @t_key
      assert behaviour.executed == ["A.f/0", "B.g/0"]
      assert behaviour.confirmed == ["A.f/0", "B.g/0"]
      assert behaviour.directories == ["lib/a", "lib/b"]
      assert result.unconfirmed == []
    end

    test "a function only executed is no cause and no directory" do
      result =
        BehaviourMap.build(
          map([test_ref(["A.f/0", "B.g/0"])]),
          [killed("A.f/0", "lib/a/a.ex")],
          %{"B" => "lib/b/b.ex"}
        )

      behaviour = one(result)
      assert behaviour.confirmed == ["A.f/0"]
      assert behaviour.directories == ["lib/a"]
      assert behaviour.executed_only == ["B.g/0"]
      assert behaviour.executed_only_directories == ["lib/b"]
    end

    test "an executed-only function with no source shows as generated, for display only" do
      result =
        BehaviourMap.build(
          map([test_ref(["A.f/0", "B.g/0"])]),
          [killed("A.f/0", "lib/a/a.ex")],
          %{}
        )

      assert one(result).executed_only_directories == ["(generated)"]
    end

    test "a test no kill row names is unconfirmed" do
      result = BehaviourMap.build(map([test_ref(["A.f/0"])]), [], %{})

      assert result.behaviours == []
      assert result.unconfirmed == [@t_key]
    end

    test "a row killed by another test confirms nothing here" do
      other = killed("A.f/0", "lib/a/a.ex", ["test/u_test.exs:1 test u"])
      result = BehaviourMap.build(map([test_ref(["A.f/0"])]), [other], %{})

      assert result.unconfirmed == [@t_key]
      assert result.unmatched_killers == [@u_key]
    end

    test "only a killed row confirms: every other status, with a killer, is no evidence" do
      for status <- ~w(timeout survived no_tests invalid crashed) do
        row = %{killed("A.f/0", "lib/a/a.ex") | status: status}
        result = BehaviourMap.build(map([test_ref(["A.f/0"])]), [row], %{})
        assert result.unconfirmed == [@t_key], status
      end
    end

    test "a kill row at another line than the map's still matches" do
      row = killed("A.f/0", "lib/a/a.ex", ["#{@t_file}:99 #{@t_name}"])

      assert one(BehaviourMap.build(map([test_ref(["A.f/0"])]), [row], %{})).confirmed == [
               "A.f/0"
             ]
    end

    test "a confirmed function with no source file: no directory, shown as generated" do
      result = BehaviourMap.build(map([test_ref(["A.f/0"])]), [killed("A.f/0", "")], %{})

      behaviour = one(result)
      assert behaviour.confirmed == ["A.f/0"]
      assert behaviour.directories == []
      assert behaviour.generated == ["A.f/0"]
    end

    test "a row with no file falls back to the module's source file" do
      result =
        BehaviourMap.build(map([test_ref(["A.B.f/0"])]), [killed("A.B.f/0", "")], %{
          "A.B" => "lib/ab/b.ex"
        })

      behaviour = one(result)
      assert behaviour.directories == ["lib/ab"]
      assert behaviour.generated == []
    end

    test "a function name with a dot does not read as part of the module" do
      row = killed("A.b.c/0", "")
      index = %{"A" => "lib/a/a.ex", "A.b" => "lib/wrong/x.ex"}

      assert one(BehaviourMap.build(map([test_ref(["A.b.c/0"])]), [row], index)).directories == [
               "lib/a"
             ]
    end

    test "a function with no Elixir module name has no module to look up" do
      row = killed(":erl.f/0", "")

      assert one(BehaviourMap.build(map([test_ref([":erl.f/0"])]), [row], %{"erl" => "lib/x.ex"})).generated ==
               [":erl.f/0"]
    end

    test "a function recorded in two files counts both: an old record cannot hide one" do
      rows = [killed("A.f/0", "lib/old/a.ex"), killed("A.f/0", "lib/new/a.ex")]

      assert one(BehaviourMap.build(map([test_ref(["A.f/0"])]), rows, %{})).directories ==
               ["lib/new", "lib/old"]
    end

    test "two functions in one directory are one directory" do
      rows = [killed("A.f/0", "lib/a/a.ex"), killed("B.g/0", "lib/a/b.ex")]

      assert one(BehaviourMap.build(map([test_ref(["A.f/0", "B.g/0"])]), rows, %{})).directories ==
               ["lib/a"]
    end

    test "two tests with one key are one behaviour, their functions together" do
      rows = [killed("A.f/0", "lib/a/a.ex"), killed("B.g/0", "lib/b/b.ex")]

      tests = [test_ref(["A.f/0"]), test_ref(["B.g/0"], %{line: 9, module: "Other"})]

      assert one(BehaviourMap.build(map(tests), rows, %{})).directories == ["lib/a", "lib/b"]
    end

    test "a killer naming no test of the map, and an unreadable one, are both said" do
      rows = [
        killed("A.f/0", "lib/a/a.ex", [
          "#{@t_file}:3 #{@t_name}",
          "test/gone_test.exs:1 test gone"
        ]),
        killed("A.g/0", "lib/a/a.ex", ["no line here"])
      ]

      result = BehaviourMap.build(map([test_ref(["A.f/0"])]), rows, %{})

      assert result.unmatched_killers == ["test/gone_test.exs::test gone", "no line here"]
    end

    test "a test killing a function the map says it never ran confirms nothing, and is counted" do
      result =
        BehaviourMap.build(map([test_ref(["A.f/0"])]), [killed("B.g/0", "lib/b/b.ex")], %{})

      assert result.behaviours == []
      assert result.unconfirmed == [@t_key]
      assert result.not_executed == 1
      assert result.unmatched_killers == []
    end
  end

  describe "test_key/2" do
    test "holds no line, and stays one trimmed baseline line" do
      assert BehaviourMap.test_key("test/a_test.exs", " test a\nb\r ") ==
               "test/a_test.exs::test a\\nb"
    end
  end

  describe "locality_keys/1" do
    test "a behaviour's key once per directory" do
      result = %{
        behaviours: [behaviour(@t_key, ["lib/a", "lib/b"]), behaviour(@u_key, ["lib/c"])],
        unconfirmed: []
      }

      assert BehaviourMap.locality_keys(result) == [@t_key, @t_key, @u_key]
    end

    test "a behaviour with only generated causes adds no key" do
      assert BehaviourMap.locality_keys(%{behaviours: [behaviour(@t_key, [])]}) == []
    end
  end

  describe "top/2" do
    test "the widest first, ties by key, at most n" do
      result = %{
        behaviours: [
          behaviour("c", ["x"]),
          behaviour("b", ["x", "y"]),
          behaviour("a", ["x"]),
          behaviour("d", ["x"])
        ]
      }

      assert result |> BehaviourMap.top(3) |> Enum.map(& &1.test_key) == ["b", "a", "c"]
    end
  end

  describe "malformed/1" do
    test "an entry needs a file and a test name" do
      assert BehaviourMap.malformed(["a::b", "no key", "::b", "a::"]) == ["no key", "::b", "a::"]
    end
  end

  describe "files_by_module/1" do
    test "each module's file; an unreadable file names none; the first file sorted wins" do
      facts = %{
        "lib/b.ex" => %{defmodules: ["B", "Both"]},
        "lib/a.ex" => %{defmodules: ["A", "Both"]},
        "lib/broken.ex" => {:error, :unparseable}
      }

      assert BehaviourMap.files_by_module(facts) ==
               %{"A" => "lib/a.ex", "B" => "lib/b.ex", "Both" => "lib/a.ex"}
    end
  end

  describe "the ratchet, through Baseline.compare/2" do
    test "a count that grew is one NEW" do
      assert %{new: [@t_key], stale: []} =
               Baseline.compare(List.duplicate(@t_key, 3), List.duplicate(@t_key, 2))
    end

    test "a count that shrank is one STALE" do
      assert %{new: [], stale: [@t_key]} = Baseline.compare([@t_key], List.duplicate(@t_key, 2))
    end

    test "the same count is clean" do
      keys = List.duplicate(@t_key, 2)
      assert %{new: [], stale: [], held: ^keys} = Baseline.compare(keys, keys)
    end
  end

  defp behaviour(key, directories) do
    %Behaviour{
      test_key: key,
      executed: [],
      confirmed: [],
      directories: directories,
      generated: []
    }
  end
end
