defmodule Anchor.Adapters.GraphArtifactTest do
  # DND-5440: the graph artifact adapter, conversions only (ADR 002), in an
  # ExUnit tmp_dir.
  #
  # Sabotage record: ../../sabotage_records/graph_runner-20261103-dnd_5440_graph_runner.md
  # Sabotage record: ../../sabotage_records/graph_runner-20261103-dnd_5581_hardening_batch.md
  use ExUnit.Case, async: true

  alias Anchor.Adapters.GraphArtifact

  @moduletag :tmp_dir

  # The artifact dir is <build_path>/anchor, and a Mix build path holds
  # lib/<app>/ebin.
  defp dir(tmp_dir) do
    File.mkdir_p!(Path.join([tmp_dir, "_build", "test", "lib", "app", "ebin"]))
    Path.join([tmp_dir, "_build", "test", "anchor"])
  end

  test "write then read round-trips the term under its key", %{tmp_dir: tmp_dir} do
    term = %{modules: [A, B], calls: [{1, 2}]}

    assert GraphArtifact.write(dir(tmp_dir), "k1", term) == :ok
    assert GraphArtifact.read(dir(tmp_dir), "k1") == {:ok, term}
    assert File.ls!(dir(tmp_dir)) == ["graph.etf"]
  end

  test "another key is stale, never used", %{tmp_dir: tmp_dir} do
    :ok = GraphArtifact.write(dir(tmp_dir), "k1", :graph)
    assert GraphArtifact.read(dir(tmp_dir), "k2") == {:error, :stale}
  end

  test "a directory that is not <build_path>/anchor is refused, for write and read", %{
    tmp_dir: tmp_dir
  } do
    # tmp_dir/build is a build path (it holds lib/app/ebin). tmp_dir/project
    # is a project root: it holds lib/app, with no ebin. Nothing else is.
    File.mkdir_p!(Path.join([tmp_dir, "build", "lib", "app", "ebin"]))
    File.mkdir_p!(Path.join([tmp_dir, "project", "lib", "app"]))

    for outside <- [
          tmp_dir,
          Path.join(tmp_dir, "anchor"),
          Path.join([tmp_dir, "build", "other"]),
          Path.join([tmp_dir, "build", "anchor", ".."]),
          Path.join([tmp_dir, "build", "lib", "anchor"]),
          Path.join([tmp_dir, "_build", "test", "anchor"]),
          Path.join([tmp_dir, "project", "anchor"])
        ] do
      assert GraphArtifact.write(outside, "k", :graph) == {:error, :outside_artifact_dir}
      assert GraphArtifact.read(outside, "k") == {:error, :outside_artifact_dir}
    end

    assert tmp_dir |> File.ls!() |> Enum.sort() == ["build", "project"]
    assert File.ls!(Path.join(tmp_dir, "build")) == ["lib"]
    assert File.ls!(Path.join(tmp_dir, "project")) == ["lib"]
  end

  # DND-5585: MIX_BUILD_PATH can name any directory; its anchor/ is the
  # artifact dir, whatever the build path is called.
  test "a build path not named _build/<env> is accepted", %{tmp_dir: tmp_dir} do
    build = Path.join(tmp_dir, "custom-build")
    File.mkdir_p!(Path.join([build, "lib", "app", "ebin"]))

    assert GraphArtifact.write(Path.join(build, "anchor"), "k", :graph) == :ok
    assert GraphArtifact.read(Path.join(build, "anchor"), "k") == {:ok, :graph}
    assert File.ls!(Path.join(build, "anchor")) == ["graph.etf"]
  end

  test "a corrupt file is unreadable; a missing one is :enoent", %{tmp_dir: tmp_dir} do
    assert GraphArtifact.read(dir(tmp_dir), "k") == {:error, :enoent}

    File.mkdir_p!(dir(tmp_dir))
    File.write!(Path.join(dir(tmp_dir), "graph.etf"), "not a term")
    assert GraphArtifact.read(dir(tmp_dir), "k") == {:error, :unreadable}

    File.write!(Path.join(dir(tmp_dir), "graph.etf"), :erlang.term_to_binary(:other_shape))
    assert GraphArtifact.read(dir(tmp_dir), "k") == {:error, :unreadable}
  end
end
