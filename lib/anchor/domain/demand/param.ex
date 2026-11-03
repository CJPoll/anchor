defmodule Anchor.Domain.Demand.Param do
  @moduledoc """
  One parameter's entry in a demand summary (`Anchor.Domain.Demand`) —
  **Domain** data (DND-5498).

    * `:demand` — the sound demand on the parameter
      (`Anchor.Domain.Demand.Lattice`): `:absent` means it reaches neither
      the return value nor an effect;
    * `:passes` — the `{callee, index}` pairs it is passed to unchanged, sorted,
      where `callee` is a project function's mfa or a lambda id `{mfa,
      ordinal}` (for DND-5470, which rebuilds the chain of calls that drops
      it);
    * `:imprecise?` — whether its demand rests on code the analysis cannot see
      (an `:any` apply site, an unknown call), or on a component that hit
      the round bound.
  """

  @enforce_keys [:demand, :passes, :imprecise?]
  defstruct [:demand, :passes, :imprecise?]

  @type t :: %__MODULE__{
          demand: Anchor.Domain.Demand.Lattice.t(),
          passes: [{Anchor.Domain.Cfa.closure(), non_neg_integer()}],
          imprecise?: boolean()
        }
end
