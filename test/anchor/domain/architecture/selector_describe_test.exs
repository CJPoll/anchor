defmodule Anchor.Domain.Architecture.SelectorDescribeTest do
  # DND-5440: a selector as an ambiguous-module message names it, in the
  # spelling `.anchor.yml` uses. Pure Domain, table-driven.
  #
  # Sabotage record: ../../../sabotage_records/architecture-20261103-dnd_5440_graph_runner.md
  use ExUnit.Case, async: true

  alias Anchor.Domain.Architecture.Selector

  @rows [
    {{:paths, ["lib/**/domain/**/*.ex"]}, ~s|paths ["lib/**/domain/**/*.ex"]|},
    {{:pattern, "Mix.Tasks.*"}, ~s|pattern "Mix.Tasks.*"|},
    {{:uses_module, GenServer}, "uses_module GenServer"},
    {{:behaviour, Supervisor}, "behaviour Supervisor"},
    {{:behaviour, :gen_server}, "behaviour :gen_server"},
    {{:exports_function, {:__aggregate__, 0}}, ~s|exports_function "__aggregate__/0"|}
  ]

  test "describe/1 writes each selector kind as the config spells it" do
    for {selector, text} <- @rows, do: assert(Selector.describe(selector) == text)
  end
end
