defmodule AnchorFixtures.Agg.Threads.Store do
  @moduledoc false
  use Anchor.Aggregate,
    name: AnchorFixtures.Agg.Threads.Space,
    schemas: [AnchorFixtures.Agg.Threads.Thread]
end
