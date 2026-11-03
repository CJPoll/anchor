defmodule Anchor.Adapters.BeamSource do
  @moduledoc """
  Behaviour for reading a project's compiled beams — the **Side Effect** port
  (ADR 001) the graph runner depends on (DND-5438, DND-5440).

  `read_ebins/1` takes `{app, ebin_dir}` pairs and returns one entry per beam:
  an `Anchor.Domain.Graph.Beam` or a decode error naming the path, the module
  when known, and the cause. A missing or unreadable ebin directory is one
  error naming that directory, never an empty list. The real adapter is
  `Anchor.Adapters.BeamReader`.
  """

  alias Anchor.Domain.Graph.Beam

  @callback read_ebins([{atom(), Path.t()}]) :: [Beam.t() | Beam.decode_error()]
end
