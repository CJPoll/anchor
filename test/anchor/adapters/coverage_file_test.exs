defmodule Anchor.Adapters.CoverageFileTest do
  # DND-5474: the coverage map file, written and read back on a tmp dir.
  # Sabotage record: ../../sabotage_records/sabotage-20261103-dnd_5474_coverage_map.md
  use ExUnit.Case, async: true

  alias Anchor.Adapters.CoverageFile

  @moduletag :tmp_dir

  test "a map round-trips, its directory made first", %{tmp_dir: dir} do
    path = Path.join([dir, "deep", "cov.etf"])
    map = %{version: 2, commit: "abc", tests: [%{file: "t.exs", line: 1, functions: ["A.f/0"]}]}

    assert CoverageFile.write(path, map) == :ok
    assert CoverageFile.read(path) == {:ok, map}
  end

  test "the same map writes the same bytes", %{tmp_dir: dir} do
    a = Path.join(dir, "a.etf")
    b = Path.join(dir, "b.etf")
    map = Map.new(1..64, &{&1, "v#{&1}"})

    assert CoverageFile.write(a, map) == :ok
    assert CoverageFile.write(b, Map.new(Enum.reverse(Map.to_list(map)))) == :ok
    assert File.read!(a) == File.read!(b)
    assert File.read!(a) == :erlang.term_to_binary(map, [:deterministic])
  end

  test "a missing file is its posix error", %{tmp_dir: dir} do
    assert CoverageFile.read(Path.join(dir, "none.etf")) == {:error, :enoent}
  end

  test "bytes that are not an external term are :undecodable", %{tmp_dir: dir} do
    path = Path.join(dir, "junk.etf")
    File.write!(path, "not a term")

    assert CoverageFile.read(path) == {:error, :undecodable}
  end

  test "a term naming an atom this VM does not have is refused, never created", %{tmp_dir: dir} do
    path = Path.join(dir, "atom.etf")
    name = "anchor_coverage_file_test_never_an_atom_#{System.unique_integer([:positive])}"

    # The external term format of an atom: 131 (version), 119 (SMALL_ATOM_UTF8_EXT), length, bytes.
    File.write!(path, <<131, 119, byte_size(name)>> <> name)

    assert CoverageFile.read(path) == {:error, :undecodable}
  end

  test "a directory that cannot be made is a write error", %{tmp_dir: dir} do
    blocker = Path.join(dir, "file")
    File.write!(blocker, "")

    assert {:error, _posix} = CoverageFile.write(Path.join([blocker, "sub", "cov.etf"]), %{})
  end
end
