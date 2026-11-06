defmodule Anchor.Adapters.CoverageAttributionTest do
  # DND-5691: what the map says about a real ExUnit run, traced for real, in a VM of
  # its own (test/fixtures/sabotage/coverage_attribution). Rows are the QA plan's:
  # "a real leak fails" (l), "what must not fail" (n).
  # sync: it starts two VMs. Not tagged :global_tracing: it traces no process here.
  # Sabotage record: ../../sabotage_records/coverage_attribution-20261106-dnd_5691_causal_attribution.md
  use ExUnit.Case, async: false

  alias Anchor.Domain.Sabotage.CoverageMap

  @run Path.expand("../../fixtures/sabotage/coverage_attribution/run.exs", __DIR__)
  defp f(name), do: "AnchorFixtures.Attribution.F.#{name}/0"

  defp build(dir, name) do
    ebin = :code.which(CoverageMap) |> Path.dirname()
    out = Path.join(dir, name)

    {output, code} = System.cmd("elixir", ["-pa", ebin, @run, out], stderr_to_stdout: true)

    assert code == 0, output
    out |> File.read!() |> :erlang.binary_to_term()
  end

  setup_all do
    dir = Path.join(System.tmp_dir!(), "anchor-attribution-#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf!(dir) end)

    first = build(dir, "first.etf")
    second = build(dir, "second.etf")
    {results, {:ok, map}} = first
    %{results: results, map: map, first: first, second: second}
  end

  defp set(map, name) do
    case Enum.filter(map.tests, &(&1.name == "test " <> name)) do
      [test] -> test.functions
      other -> flunk("expected one test named #{name}, got #{inspect(other)}")
    end
  end

  defp leaked?(map, name, function) do
    Enum.any?(map.leaks, &(leak_name(&1.from) == name and &1.function == f(function)))
  end

  defp leak_name(%{name: "test " <> name}), do: name
  defp leak_name(%{module: module}), do: module

  test "the fixture suite passes, and its window count is exact", %{results: results} do
    assert results.failures == 0

    # total counts the skipped and the excluded test, and every test that ran has an
    # entry: finalize would have refused otherwise, as the setup's match holds.
    assert results.skipped == 1
    assert results.excluded == 1
    assert results.total >= 30
  end

  test "8: two builds at one seed are byte-identical", %{first: first, second: second} do
    {_results, {:ok, map1}} = first
    {_results, {:ok, map2}} = second
    assert CoverageMap.canonical(map1) == CoverageMap.canonical(map2)
  end

  describe "a real leak fails" do
    test "1: a spinner left running", %{map: map} do
      assert leaked?(map, "l1 spinner a", :l1_after)
      assert f(:l1_after) in set(map, "l1 spinner a")
      refute f(:l1_after) in set(map, "l1 spinner b")
    end

    test "2: a process released by the next test", %{map: map} do
      assert leaked?(map, "l2 released a", :l2_released)
      refute f(:l2_released) in set(map, "l2 released b")
    end

    test "3: a process released by a message with no label", %{map: map} do
      assert leaked?(map, "l3 unlabelled a", :l3_unlabelled)
      refute f(:l3_unlabelled) in set(map, "l3 unlabelled b")
    end

    test "4: a grandchild whose parent is gone", %{map: map} do
      assert leaked?(map, "l4 grandchild a", :l4_grandchild)
    end

    test "5: a port holder calling project code afterwards", %{map: map} do
      assert leaked?(map, "l5 port a", :l5_port)
    end

    test "6: a Task under an application's supervisor (noreply)", %{map: map} do
      assert leaked?(map, "l6 task a", :l6_task)
      refute f(:l6_task) in set(map, "l6 task b")
    end

    test "7: a process from setup_all outliving its module", %{map: map} do
      assert leaked?(map, "AnchorFixtures.Attribution.SetupAllCases", :l7_setup_all)
      refute f(:l7_setup_all) in set(map, "l7 released from the next module")
    end

    test "8: a Task from start_child/5 under an application's supervisor (reply)", %{map: map} do
      assert leaked?(map, "l8 task reply a", :l8_task_reply)
      refute f(:l8_task_reply) in set(map, "l8 task reply b")
    end

    test "9: a Task from async_nolink", %{map: map} do
      assert leaked?(map, "l9 task nolink a", :l9_task_nolink)
      refute f(:l9_task_nolink) in set(map, "l9 task nolink b")
    end
  end

  describe "what must not fail" do
    # Every leak in the fixture is one of the rows above, so none of these leaks.
    test "the leak list holds the l rows and nothing else", %{map: map} do
      assert map.leaks |> Enum.map(& &1.function) |> Enum.sort() ==
               Enum.sort(
                 Enum.map(
                   ~w(l1_after l2_released l3_unlabelled l4_grandchild l5_port l6_task l7_setup_all
                      l8_task_reply l9_task_nolink),
                   &f/1
                 )
               )
    end

    test "1: an awaited Task", %{map: map} do
      assert f(:n1_task) in set(map, "n1 awaited task")
    end

    test "2: start_supervised work", %{map: map} do
      assert f(:start_supervised_init) in set(map, "n2 start_supervised")
    end

    test "3: a linked process that dies with its test and never calls after", %{map: map} do
      assert set(map, "n3 linked idle server") == []
    end

    test "4: a test file's module body", %{map: map} do
      assert f(:n4_compile) in map.ambient
      refute Enum.any?(map.tests, &(f(:n4_compile) in &1.functions))
    end

    test "5: a test that compiles code itself", %{map: map} do
      assert f(:n5_compiled) in set(map, "n5 compiles code itself")
      refute f(:n5_compiled) in map.ambient
    end

    test "6: an application server's own timer work", %{map: map} do
      assert f(:n6_timer) in map.ambient
      assert set(map, "n6 server's own timer") == []
    end

    test "7: an application server handling a test's call", %{map: map} do
      assert f(:n7_call) in set(map, "n7 server call")
    end

    test "9: a late cast", %{map: map} do
      assert f(:n9_late_cast) in map.ambient
      refute f(:n9_late_cast) in set(map, "n9 late cast a")
      refute f(:n9_late_cast) in set(map, "n9 late cast b")
    end

    test "10: a stale label on a server's timer", %{map: map} do
      assert f(:n10_stale_timer) in map.ambient
      refute f(:n10_stale_timer) in set(map, "n10 stale timer a")
      refute f(:n10_stale_timer) in set(map, "n10 stale timer b")
    end

    test "11: a test that lost its label calls a server", %{map: map} do
      assert f(:n11_handler) in map.ambient
      assert set(map, "n11 lost its label") == [f(:n11_own)]
    end

    test "12: :timer.apply_after inside its window", %{map: map} do
      assert f(:n12_apply_after) in set(map, "n12 apply_after inside its window")
    end

    test "13: setup_all calling a server reaches every test of the module", %{map: map} do
      assert f(:n13_setup_all) in set(map, "s1 setup_all's work reaches this test")
      assert f(:n13_setup_all) in set(map, "n14 a test's task under a setup_all supervisor")
      refute f(:n13_setup_all) in set(map, "n7 server call")
    end

    test "14: a test's Task under a setup_all supervisor is that test's only", %{map: map} do
      assert f(:n14_task) in set(map, "n14 a test's task under a setup_all supervisor")
      refute f(:n14_task) in set(map, "s1 setup_all's work reaches this test")
    end

    test "on_exit: a test's is that test's; a module's reaches the module", %{map: map} do
      assert f(:on_exit_test) in set(map, "on_exit")
      assert f(:on_exit_module) in set(map, "s1 setup_all's work reaches this test")
    end

    test "a skipped or excluded test has no row", %{map: map} do
      names = Enum.map(map.tests, & &1.name)
      refute "test skipped" in names
      refute "test excluded" in names
    end
  end
end
