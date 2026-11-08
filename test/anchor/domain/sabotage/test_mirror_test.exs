defmodule Anchor.Domain.Sabotage.TestMirrorTest do
  # DND-6070: a mirror file's siblings, the `<stem>_<topic>_test.exs` files a
  # module's tests are split into, which a mutant runs beside the mirror file.
  use ExUnit.Case, async: true

  alias Anchor.Domain.Sabotage.TestMirror

  @mirror "apps/runtime/test/runtime/agents/domain/machine_decider_test.exs"

  describe "sibling?/2" do
    test "a `<stem>_<topic>_test.exs` file in the mirror's directory is a sibling" do
      assert TestMirror.sibling?(
               @mirror,
               "apps/runtime/test/runtime/agents/domain/machine_decider_agents_test.exs"
             )

      assert TestMirror.sibling?("test/x_test.exs", "test/x_more_test.exs")
      assert TestMirror.sibling?("test/x_test.exs", "test/x_two_words_test.exs")
      assert TestMirror.sibling?("x_test.exs", "x_more_test.exs")
    end

    test "the mirror file itself is not its own sibling" do
      refute TestMirror.sibling?(@mirror, @mirror)
      assert TestMirror.sibling?("test/x_test.exs", "test/x_y_test.exs")
    end

    test "the stem must end at an underscore: another module's test is not a sibling" do
      refute TestMirror.sibling?("test/x_test.exs", "test/xy_test.exs")
      refute TestMirror.sibling?("test/x_test.exs", "test/x__test.exs")
      refute TestMirror.sibling?("test/x_test.exs", "test/y_x_test.exs")
      assert TestMirror.sibling?("test/x_test.exs", "test/x_y_test.exs")
    end

    test "a file in another directory, above, below or beside, is not a sibling" do
      refute TestMirror.sibling?("test/a/x_test.exs", "test/a/b/x_more_test.exs")
      refute TestMirror.sibling?("test/a/x_test.exs", "test/x_more_test.exs")
      refute TestMirror.sibling?("test/a/x_test.exs", "test/b/x_more_test.exs")
      refute TestMirror.sibling?("x_test.exs", "test/x_more_test.exs")
      assert TestMirror.sibling?("test/a/x_test.exs", "test/a/x_more_test.exs")
    end

    test "only a `_test.exs` file is a sibling" do
      refute TestMirror.sibling?("test/x_test.exs", "test/x_more.exs")
      refute TestMirror.sibling?("test/x_test.exs", "test/x_more_test.ex")
      refute TestMirror.sibling?("test/x_test.exs", "test/x_more_test.exs.orig")
      assert TestMirror.sibling?("test/x_test.exs", "test/x_more_test.exs")
    end

    test "a mirror path that is not a `_test.exs` file has no siblings" do
      refute TestMirror.sibling?("test/x.exs", "test/x_more_test.exs")
      refute TestMirror.sibling?("test/x_spec.exs", "test/x_spec_more_test.exs")
      refute TestMirror.sibling?("test/_test.exs", "test/_more_test.exs")
    end
  end
end
