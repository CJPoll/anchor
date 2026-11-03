defmodule Anchor.Adapters.SourceReaderTest do
  # DND-5440: the source reader adapter, conversions only (ADR 002): a file
  # becomes its SourceFacts, never raw text.
  #
  # Sabotage record: ../../sabotage_records/graph_runner-20261103-dnd_5440_graph_runner.md
  # Sabotage record: ../../sabotage_records/graph_runner-20261103-dnd_5630_graph_hardening.md
  use ExUnit.Case, async: true

  alias Anchor.Adapters.SourceReader
  alias Anchor.Adapters.SourceSource

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

  # DND-5636: an empty map is a measured "nothing", never refused. A file with
  # no literal defmodule (a DSL file whose modules are macro output) has no
  # uses at all, and a read of no paths returns no entries. Both are checked
  # against the port's return type (Hammox), beside an unparseable file,
  # whose facts are unknown.
  test "a file with no defmodule, and a read of no paths, conform to the port's type",
       %{tmp_dir: tmp_dir} do
    read = Hammox.protect({SourceReader, :read, 2}, SourceSource)

    File.mkdir_p!(Path.join(tmp_dir, "lib"))
    File.write!(Path.join(tmp_dir, "lib/dsl.ex"), "use MyApp.DSL\nresource :user\n")
    File.write!(Path.join(tmp_dir, "lib/broken.ex"), "defmodule B do\n")

    assert read.(tmp_dir, ["lib/dsl.ex", "lib/broken.ex"]) == %{
             "lib/dsl.ex" => %{defmodules: [], uses: %{}, nonliteral_defmodule?: false},
             "lib/broken.ex" => {:error, :unparseable}
           }

    assert read.(tmp_dir, []) == %{}
  end
end
