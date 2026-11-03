defmodule Anchor.Domain.Graph.ProjectFileTest do
  # DND-5588, DND-5630: a beam's source path against the project root. Pure
  # Domain. Every beam the runner reads came from a project ebin, so every
  # path places as project code: inside the root, or outside it with a
  # root-relative `../` path.
  #
  # Sabotage record: ../../../sabotage_records/builder-20261103-dnd_5581_hardening_batch.md
  # Sabotage record: ../../../sabotage_records/graph_runner-20261103-dnd_5630_graph_hardening.md
  use ExUnit.Case, async: true

  alias Anchor.Domain.Graph.ProjectFile

  @root "/work/my_app"

  test "the table" do
    for {file, expected} <- [
          # relative: inside the root, as it stands
          {"lib/my_app/user.ex", {:inside_root, "lib/my_app/user.ex"}},
          {"lib/../lib/x.ex", {:inside_root, "lib/x.ex"}},
          # absolute inside the root: made relative to it
          {"/work/my_app/lib/my_app/user.ex", {:inside_root, "lib/my_app/user.ex"}},
          {"/work/my_app/lib/../lib/x.ex", {:inside_root, "lib/x.ex"}},
          # absolute outside the root: relative to it, through `..`
          {"/work/shared/foo.ex", {:outside_root, "../shared/foo.ex"}},
          {"/work/my_app_extra/lib/x.ex", {:outside_root, "../my_app_extra/lib/x.ex"}},
          {"/work/my_app/../dep/lib/x.ex", {:outside_root, "../dep/lib/x.ex"}},
          {"/elsewhere/x.ex", {:outside_root, "../../elsewhere/x.ex"}},
          # relative and outside (a path already given through `..`)
          {"../shared/foo.ex", {:outside_root, "../shared/foo.ex"}},
          {"lib/../../shared/foo.ex", {:outside_root, "../shared/foo.ex"}},
          # a name that only starts with two dots is inside
          {"..foo/x.ex", {:inside_root, "..foo/x.ex"}},
          {"/work/my_app/..foo/x.ex", {:inside_root, "..foo/x.ex"}},
          # a `~` is a directory name here, never the home directory
          {"~/x.ex", {:inside_root, "~/x.ex"}},
          # no source path: the model decides
          {nil, {:inside_root, nil}}
        ] do
      assert ProjectFile.place(file, @root) == expected, inspect(file)
    end
  end

  test "a relative root is refused: reading it would need the working directory" do
    assert_raise ArgumentError, ~r/must be an absolute path, got: "my_app"/, fn ->
      ProjectFile.place("/work/my_app/lib/x.ex", "my_app")
    end
  end

  test "a root given with a trailing slash or a .. places the same" do
    assert ProjectFile.place("/work/my_app/lib/x.ex", "/work/my_app/") ==
             {:inside_root, "lib/x.ex"}

    assert ProjectFile.place("/work/my_app/lib/x.ex", "/work/other/../my_app") ==
             {:inside_root, "lib/x.ex"}

    assert ProjectFile.place("/work/shared/x.ex", "/work/my_app/") ==
             {:outside_root, "../shared/x.ex"}
  end

  # DND-5637: in an umbrella, Mix compiles each app from its own directory, so
  # a beam's relative_file is relative to the app (recorded on a real
  # two-app umbrella: apps/alpha/lib/alpha.ex has relative_file
  # "lib/alpha.ex"). `place/3` reads a relative path against the app's
  # directory and keys it against the umbrella root.
  describe "place/3 with the directory the compiler ran in" do
    test "an app-relative path is keyed umbrella-root-relative" do
      assert ProjectFile.place("lib/alpha.ex", @root, "apps/alpha") ==
               {:inside_root, "apps/alpha/lib/alpha.ex"}

      assert ProjectFile.place("lib/beta/b.ex", @root, "apps/beta") ==
               {:inside_root, "apps/beta/lib/beta/b.ex"}

      # An app's elixirc_paths entry outside the umbrella root
      assert ProjectFile.place("../../../shared/x.ex", @root, "apps/alpha") ==
               {:outside_root, "../shared/x.ex"}
    end

    test "an absolute path does not depend on the directory" do
      assert ProjectFile.place("/work/my_app/apps/alpha/lib/alpha.ex", @root, "apps/beta") ==
               {:inside_root, "apps/alpha/lib/alpha.ex"}
    end

    test "place/2 is place/3 with the root itself" do
      assert ProjectFile.place("lib/x.ex", @root) == ProjectFile.place("lib/x.ex", @root, ".")
    end

    test "an absolute directory is refused: it is relative to the root" do
      assert_raise ArgumentError, ~r/must be relative to the root, got: "\/apps\/alpha"/, fn ->
        ProjectFile.place("lib/x.ex", @root, "/apps/alpha")
      end
    end
  end
end
