defmodule Anchor.Adapters.SourceReaderTest do
  # DND-5440: the source reader adapter, conversions only (ADR 002): a file
  # becomes its SourceFacts, never raw text.
  #
  # Sabotage record: ../../sabotage_records/graph_runner-20261103-dnd_5440_graph_runner.md
  use ExUnit.Case, async: true

  alias Anchor.Adapters.SourceReader

  @moduletag :tmp_dir

  test "each path relative to the root becomes its facts; unparseable and missing files are errors, never dropped",
       %{tmp_dir: tmp_dir} do
    File.mkdir_p!(Path.join(tmp_dir, "lib"))
    File.write!(Path.join(tmp_dir, "lib/a.ex"), "defmodule A do\n  use GenServer\nend\n")
    File.write!(Path.join(tmp_dir, "lib/broken.ex"), "defmodule B do\n")

    assert SourceReader.read(tmp_dir, ["lib/a.ex", "lib/broken.ex", "lib/gone.ex"]) == %{
             "lib/a.ex" => %{
               defmodules: ["A"],
               uses: %{"A" => ["GenServer"]},
               nonliteral_defmodule?: false
             },
             "lib/broken.ex" => {:error, :unparseable},
             "lib/gone.ex" => {:error, :enoent}
           }
  end
end
