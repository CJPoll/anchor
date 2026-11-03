defmodule Anchor.Domain.Graph.ProjectFileTest do
  # DND-5588: a beam's source path against the project root. Pure Domain.
  #
  # Sabotage record: ../../../sabotage_records/graph_runner-20261103-dnd_5581_hardening_batch.md
  use ExUnit.Case, async: true

  alias Anchor.Domain.Graph.ProjectFile

  @root "/work/my_app"

  test "the table" do
    for {file, expected} <- [
          # relative: the project's, as it stands
          {"lib/my_app/user.ex", {:project, "lib/my_app/user.ex"}},
          # absolute inside the root: the project's, made relative to it
          {"/work/my_app/lib/my_app/user.ex", {:project, "lib/my_app/user.ex"}},
          {"/work/my_app/lib/../lib/x.ex", {:project, "lib/x.ex"}},
          # absolute outside the root: a dependency's
          {"/work/dep/lib/dep.ex", :dependency},
          {"/work/my_app_extra/lib/x.ex", :dependency},
          {"/work/my_app/../dep/lib/x.ex", :dependency},
          {"/work/my_app", :dependency},
          # no source path: the model decides
          {nil, {:project, nil}}
        ] do
      assert ProjectFile.place(file, @root) == expected, inspect(file)
    end
  end

  test "a root given with a trailing slash or a .. places the same" do
    assert ProjectFile.place("/work/my_app/lib/x.ex", "/work/my_app/") == {:project, "lib/x.ex"}

    assert ProjectFile.place("/work/my_app/lib/x.ex", "/work/other/../my_app") ==
             {:project, "lib/x.ex"}
  end
end
