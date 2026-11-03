defmodule AnchorFixtures.Agg.Threads.Rogue do
  @moduledoc false
  Module.register_attribute(__MODULE__, :anchor_aggregate, persist: true)
  @anchor_aggregate [name: AnchorFixtures.Agg.Threads.Space, tables: ["audit_rows"]]
end
