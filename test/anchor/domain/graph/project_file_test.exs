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
end
