defmodule Anchor.Adapters.SourceReaderTest do
  # DND-5440: the source reader adapter, conversions only (ADR 002).
  #
  # Sabotage record: ../../sabotage_records/graph_runner-20261103-dnd_5440_graph_runner.md
  use ExUnit.Case, async: true

  alias Anchor.Adapters.SourceReader

  @moduletag :tmp_dir

  test "reads each path relative to the root; a missing file is {:error, :enoent}, never dropped",
       %{tmp_dir: tmp_dir} do
    File.mkdir_p!(Path.join(tmp_dir, "lib"))
    File.write!(Path.join(tmp_dir, "lib/a.ex"), "defmodule A do end")

    assert SourceReader.read(tmp_dir, ["lib/a.ex", "lib/gone.ex"]) == %{
             "lib/a.ex" => {:ok, "defmodule A do end"},
             "lib/gone.ex" => {:error, :enoent}
           }
  end
end
