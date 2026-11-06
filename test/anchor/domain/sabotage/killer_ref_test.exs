defmodule Anchor.Domain.Sabotage.KillerRefTest do
  # DND-5485: a kill map's killer, read back as a test to run.
  # Sabotage record: ../../../sabotage_records/sabotage-20261103-dnd_5483_survivors_replay.md
  use ExUnit.Case, async: true

  alias Anchor.Domain.Sabotage.KillerRef

  test "1: file:line full name" do
    assert KillerRef.parse("test/a_test.exs:12 test add/2 sums") ==
             {:ok, %{file: "test/a_test.exs", line: 12, name: "test add/2 sums"}}
  end

  test "2: a name holding : and digits is split on the first :<digits> only" do
    assert KillerRef.parse("test/a_test.exs:7 test ratio 3:4 holds at 10:30 2") ==
             {:ok, %{file: "test/a_test.exs", line: 7, name: "test ratio 3:4 holds at 10:30 2"}}
  end

  test "3: two refs in one file and one in another: each file once, every name filter after" do
    refs = [
      %{file: "test/a_test.exs", line: 1, name: "test x"},
      %{file: "test/a_test.exs", line: 2, name: "test y"},
      %{file: "test/b_test.exs", line: 3, name: "test z"}
    ]

    assert KillerRef.to_test_args(refs) == [
             "test/a_test.exs",
             "test/b_test.exs",
             "--only",
             "test:test x",
             "--only",
             "test:test y",
             "--only",
             "test:test z"
           ]
  end

  test "4: the bound's (timeout) names no test" do
    assert KillerRef.parse("(timeout)") == {:error, :not_a_test}
  end

  test "a per-test timeout's killer names its test" do
    assert KillerRef.parse("(test timeout) test/a_test.exs:9 test slow") ==
             {:ok, %{file: "test/a_test.exs", line: 9, name: "test slow"}}
  end

  test "a killer whose file is an option or outside the project is refused" do
    assert KillerRef.parse("--include:1 test x") == {:error, {:bad_path, :option}}
    assert KillerRef.parse("../x_test.exs:1 test x") == {:error, {:bad_path, :parent_segment}}
  end

  test "text with no :<digits> <name> is not a ref" do
    assert KillerRef.parse("test/a_test.exs test x") ==
             {:error, {:not_a_ref, "test/a_test.exs test x"}}

    assert KillerRef.parse("test/a_test.exs:12") == {:error, {:not_a_ref, "test/a_test.exs:12"}}
  end
end
