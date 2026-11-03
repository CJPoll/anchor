defmodule Anchor.Adapters.GraphArtifactTest do
  # DND-5440: the graph artifact adapter, conversions only (ADR 002), in an
  # ExUnit tmp_dir.
  #
  # Sabotage record: ../../sabotage_records/graph_runner-20261103-dnd_5440_graph_runner.md
  use ExUnit.Case, async: true

  alias Anchor.Adapters.GraphArtifact

  @moduletag :tmp_dir

  defp dir(tmp_dir), do: Path.join([tmp_dir, "_build", "test", "anchor"])

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

  test "a directory outside _build/<env>/anchor is refused, for write and read", %{
    tmp_dir: tmp_dir
  } do
    for outside <- [
          tmp_dir,
          Path.join(tmp_dir, "anchor"),
          Path.join([tmp_dir, "_build", "test", "anchor", ".."]),
          Path.join([tmp_dir, "lib", "test", "anchor"])
        ] do
      assert GraphArtifact.write(outside, "k", :graph) == {:error, :outside_artifact_dir}
      assert GraphArtifact.read(outside, "k") == {:error, :outside_artifact_dir}
    end

    assert File.ls!(tmp_dir) == []
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
