defmodule Anchor.BackstopTest do
  # DND-5480: the backstop's Framework entry point. What it does itself: it
  # refuses a repo with no telemetry prefix and a bad escapes: mode before it
  # starts anything, and watch/1 refuses to run before attach!/1. A crossing
  # failing a test is the Manager's verdict!/3 (managers/backstop_test.exs)
  # and the integration test's: a successful attach!/1 here would install the
  # VM's one session and print a summary at the end of Anchor's own suite.
  #
  # Sabotage record: ../sabotage_records/backstop-20261106-dnd_5480_test_backstop.md
  use ExUnit.Case, async: true

  defmodule NoPrefixRepo do
    @moduledoc false
    def config, do: [otp_app: :anchor]
  end

  test "F1: watch/1 before attach!/1 raises: call attach!/1 in test_helper.exs" do
    error =
      assert_raise ArgumentError, fn ->
        Anchor.Backstop.watch(%{module: __MODULE__, test: :"test F1"})
      end

    assert error.message ==
             "anchor backstop: watch/1 was called before the backstop was attached. " <>
               "Fix: call Anchor.Backstop.attach!/1 in test_helper.exs."
  end

  test "F2: a repo with no telemetry prefix raises, naming the repo" do
    error = assert_raise ArgumentError, fn -> Anchor.Backstop.attach!(repo: NoPrefixRepo) end

    assert error.message ==
             "anchor backstop: Anchor.BackstopTest.NoPrefixRepo has no telemetry prefix. Fix: " <>
               "pass repo: an Ecto repo (use Ecto.Repo), whose config/0 holds :telemetry_prefix."
  end

  test "F2: a module that is not a repo at all raises, naming it" do
    error = assert_raise ArgumentError, fn -> Anchor.Backstop.attach!(repo: String) end
    assert error.message =~ "anchor backstop: String has no telemetry prefix. Fix:"
  end

  test "an escapes: mode other than :report or :fail raises with Fix:" do
    error =
      assert_raise ArgumentError, fn ->
        Anchor.Backstop.attach!(repo: NoPrefixRepo, escapes: :warn)
      end

    assert error.message =~ "escapes: must be :report or :fail, got: :warn. Fix:"
  end

  test "repo: is required" do
    assert_raise KeyError, fn -> Anchor.Backstop.attach!([]) end
  end
end
