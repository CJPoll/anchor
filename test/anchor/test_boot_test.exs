defmodule Anchor.TestBootTest do
  # DND-5690: `test/test_helper.exs` loads every module of Anchor's application
  # closure (`Anchor.TestPreload`) before `ExUnit.start/0`, so no test loads one
  # on demand through `code_server`, and every run has it, the coverage run
  # included. This fails when the helper stops doing that work up front.
  # Sabotage record: ../sabotage_records/test_preload-20261106-dnd_5690_preload.md
  use ExUnit.Case, async: true

  alias Anchor.TestPreload

  test "every module of Anchor's closure is loaded before any test runs" do
    unloaded = TestPreload.unloaded(:anchor)

    assert unloaded == [],
           "#{length(unloaded)} module(s) of Anchor's closure are not loaded, so a test loads " <>
             "them on demand through code_server: #{inspect(Enum.take(unloaded, 10))}. " <>
             "Fix: call Anchor.TestPreload.load!(:anchor) in test/test_helper.exs before " <>
             "ExUnit.start/0."
  end

  # Positive control: an empty closure would leave nothing unloaded, and the
  # test above would pass having checked nothing.
  test "the closure it checks holds Anchor, its dependencies and what they need" do
    apps = TestPreload.apps(:anchor)

    # :bunt is needed by credo and not named by Anchor: the closure is transitive.
    assert [:anchor, :bunt, :credo, :kernel] -- apps == []

    modules = TestPreload.modules(apps)
    assert [Anchor.Managers.Lint, Bunt, Credo, :gen_server] -- modules == []
  end
end
