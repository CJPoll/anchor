defmodule Anchor.Adapters.ProjectModulesTest do
  # DND-5474: a project's modules are named by its ebin directories' beams.
  # Sabotage record: ../../sabotage_records/sabotage-20261103-dnd_5474_coverage_map.md
  use ExUnit.Case, async: true

  alias Anchor.Adapters.ProjectModules

  @moduletag :tmp_dir

  test "each *.beam names a module; other files and other directories do not", %{tmp_dir: dir} do
    a = Path.join(dir, "a/ebin")
    b = Path.join(dir, "b/ebin")
    File.mkdir_p!(a)
    File.mkdir_p!(b)
    File.write!(Path.join(a, "Elixir.Anchor.Zed.beam"), "")
    File.write!(Path.join(a, "Elixir.Anchor.Alpha.beam"), "")
    File.write!(Path.join(a, "anchor.app"), "")
    File.write!(Path.join(b, "Elixir.Anchor.Alpha.beam"), "")
    File.write!(Path.join(dir, "Elixir.Outside.beam"), "")

    assert ProjectModules.list([a, b]) == [Anchor.Alpha, Anchor.Zed]
    assert ProjectModules.list([Path.join(dir, "missing")]) == []
  end
end
