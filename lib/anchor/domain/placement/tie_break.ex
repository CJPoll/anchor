defmodule Anchor.Domain.Placement.TieBreak do
  @moduledoc """
  The tie-break seam of directory placement (DND-5462) — **Domain**, pure.

  Where the static rules leave a choice (a shared module whose callers sit in several
  directories of one context), `choose/2` picks the directory. With no evidence it
  keeps the first candidate, the bucket root, and says so: `{:none, root}`. The
  co-causation tie-break (DND-5475) adds the clause that reads coverage evidence and
  answers `{:coverage, dir}`; until then any evidence raises, so a caller that passes
  some is never silently ignored.

  The design's `choose/3` also took the module; this clause reads nothing of it, and
  `parameter_reaches_sink` refuses a parameter that causes nothing, so DND-5475 adds it
  with the clause that reads it.
  """

  @doc "The directory a shared module goes to among `candidates` (the bucket root first)."
  @spec choose([Path.t(), ...], map() | nil) :: {:none, Path.t()} | {:coverage, Path.t()}
  def choose([root | _others], nil), do: {:none, root}
end
