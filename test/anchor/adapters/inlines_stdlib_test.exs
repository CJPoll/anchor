defmodule Anchor.Adapters.InlinesStdlibTest do
  # Adapter (ADR 002): the boundary here is the real stdlib. `Anchor.Domain.Graph.Inlines`
  # reads every exported function of the `:elixir` application when Anchor
  # compiles; this reads them once more, once for the whole module, and holds
  # what was compiled in equal to what that Elixir says now, so the tables are
  # never a copy. It loads every stdlib module through the code server, so it
  # is not a Domain test (DND-5715); the table logic is tested on hand-built
  # exports in ../domain/graph/inlines_test.exs.
  #
  # Sabotage record: ../../sabotage_records/inlines-20261106-dnd_5715_bucket_split.md
  use ExUnit.Case, async: true

  alias Anchor.Domain.Graph.Inlines
  alias Anchor.Domain.Graph.Inlines.Derive

  @moduletag bucket: :adapter

  setup_all do
    exports =
      for module <- Application.spec(:elixir, :modules),
          String.starts_with?(Atom.to_string(module), "Elixir."),
          do: {module, module.module_info(:exports)}

    %{exports: exports}
  end

  test "the stdlib was read: Map is there, with put/3 (positive control)", %{exports: exports} do
    assert {:put, 3} in Keyword.fetch!(exports, Map)
  end

  test "table/0 is the table Elixir's rewrite rules give on the Elixir it runs on, not a copy",
       %{exports: exports} do
    assert Inlines.table() == Derive.derive(exports)
  end

  test "tags/0 is derived from Elixir's rules, not copied", %{exports: exports} do
    assert Inlines.tags() == Derive.tags(exports)
  end
end
