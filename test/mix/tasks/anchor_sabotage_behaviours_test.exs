defmodule Mix.Tasks.Anchor.SabotageBehavioursTest do
  # Framework tests for `mix anchor.sabotage behaviours` (DND-5489): argv and the exit
  # code, the Manager's ports doubled.
  # sync: capture_io(:stderr) captures the VM-wide standard_error device, which
  # another async test's output would interleave with.
  # Sabotage record: ../../sabotage_records/sabotage-20261106-dnd_5470_param_sink_locality.md
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO
  import Hammox

  alias Anchor.Domain.Sabotage.Config
  alias Mix.Tasks.Anchor.Sabotage

  setup :verify_on_exit!

  @opts [config_loader: Anchor.ConfigLoaderMock, coverage_store: Anchor.CoverageStoreMock]

  defp config do
    expect(Anchor.ConfigLoaderMock, :load_in, fn _root ->
      {:ok, %Anchor.Config{sabotage: %Config{}}}
    end)
  end

  test "--coverage reaches the Manager, and its exit 3 is the task's" do
    config()

    expect(Anchor.CoverageStoreMock, :read, fn path ->
      assert String.ends_with?(path, "/given.etf")
      {:error, :enoent}
    end)

    stderr =
      capture_io(:stderr, fn ->
        assert catch_exit(Sabotage.run(["behaviours", "--coverage", "given.etf"], @opts)) ==
                 {:shutdown, 3}
      end)

    assert stderr =~ "Fix: download the anchor-coverage artifact (CI) and pass --coverage"
  end

  test "the facts: each flag, and what its absence means" do
    assert {:ok, facts} =
             Sabotage.behaviours_facts(
               ~w(--coverage c.etf --format json --write-baseline --base main)
             )

    assert %{coverage: "c.etf", format: :json, write_baseline: true, base: "main"} = facts
    assert is_binary(facts.root)

    assert {:ok, %{coverage: nil, format: :text, write_baseline: false, base: nil}} =
             Sabotage.behaviours_facts([])
  end

  test "no --coverage reads the config" do
    config()

    stderr =
      capture_io(:stderr, fn ->
        assert catch_exit(Sabotage.run(["behaviours"], @opts)) == {:shutdown, 3}
      end)

    assert stderr =~ "no coverage map was given"
  end

  for {label, argv} <- [
        {"an unknown format", ["behaviours", "--format", "xml"]},
        {"an unknown flag", ["behaviours", "--nope"]},
        {"a stray argument", ["behaviours", "stray"]}
      ] do
    test "#{label} is usage, exit 2, nothing read" do
      stderr =
        capture_io(:stderr, fn ->
          assert catch_exit(Sabotage.run(unquote(argv), @opts)) == {:shutdown, 2}
        end)

      assert stderr =~ "mix anchor.sabotage behaviours [--coverage PATH]"
    end
  end
end
