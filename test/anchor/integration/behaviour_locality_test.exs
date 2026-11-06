defmodule Anchor.Integration.BehaviourLocalityTest do
  # DND-5489: `mix anchor.sabotage behaviours`'s flow on real files, no double: a map,
  # a record and a source tree on disk, the baseline written, then the ratchet.
  # Sabotage record: ../../sabotage_records/sabotage-20261106-dnd_5470_param_sink_locality.md
  use ExUnit.Case, async: true

  alias Anchor.Adapters.CoverageFile
  alias Anchor.Managers.Sabotage

  @moduletag :tmp_dir
  @key "test/t_test.exs::test t"
  @baseline ".anchor/baselines/behaviour-locality.txt"

  setup %{tmp_dir: root} do
    write(root, ".anchor.yml", "rules: []\nsabotage:\n  coverage_map: map.etf\n")
    write(root, "lib/a/a.ex", "defmodule A do\n  def f, do: :ok\nend\n")
    write(root, "lib/b/b.ex", "defmodule B do\n  def g, do: :ok\nend\n")

    write(root, "test/sabotage_records/r.md", """
    # r
    ```anchor-kills
    # id\tfile\tmfa\toperator\tstatus\tkillers
    a\tlib/a/a.ex\tA.f/0\top\tkilled\ttest/t_test.exs:9 test t
    b\tlib/b/b.ex\tB.g/0\top\tkilled\ttest/t_test.exs:9 test t
    ```
    """)

    :ok =
      CoverageFile.write(Path.join(root, "map.etf"), %{
        version: 2,
        leaks: [],
        ambient: [],
        commit: nil,
        modules_traced: 2,
        tests: [
          %{
            file: "test/t_test.exs",
            line: 3,
            name: "test t",
            module: "T",
            functions: ["A.f/0", "B.g/0"]
          },
          %{file: "test/u_test.exs", line: 3, name: "test u", module: "U", functions: ["A.f/0"]}
        ]
      })

    {:ok, facts: %{root: root, coverage: nil, format: :text, write_baseline: false, base: nil}}
  end

  defp write(root, path, text) do
    File.mkdir_p!(Path.dirname(Path.join(root, path)))
    File.write!(Path.join(root, path), text)
  end

  test "no baseline, written, clean, then a shrunk behaviour is STALE",
       %{facts: facts, tmp_dir: root} do
    assert {0, lines} = Sabotage.behaviours(facts)
    assert Enum.join(lines, "\n") =~ "NEW #{@key}"

    assert {0, ["behaviour locality: wrote #{@baseline} with 2 entries"]} ==
             Sabotage.behaviours(%{facts | write_baseline: true})

    assert File.read!(Path.join(root, @baseline)) ==
             "# anchor baseline for behaviour-locality; shrink only\n#{@key}\n#{@key}\n"

    assert {0, clean} = Sabotage.behaviours(facts)
    assert Enum.join(clean, "\n") =~ "2\t#{@key}\tlib/a lib/b"
    assert Enum.join(clean, "\n") =~ "clean against #{@baseline} (report mode)"

    assert {2, _refused} = Sabotage.behaviours(%{facts | write_baseline: true})

    File.write!(Path.join(root, @baseline), "#{@key}\n#{@key}\n#{@key}\n")
    assert {0, stale} = Sabotage.behaviours(facts)
    assert Enum.join(stale, "\n") =~ "STALE #{@key}"
  end
end
