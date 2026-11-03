defmodule Anchor.Domain.Architecture.Bucket do
  @moduledoc """
  One bucket of an `architecture:` section (DND-5437) — a **Domain** module
  (ADR 001), a plain struct.

    * `name` — unique in the section, lower-case letters and `_`;
    * `role` — one of the five roles of ADR 001;
    * `selectors` — `[Anchor.Domain.Architecture.Selector.t()]`, in file order:
      a module matching any one is in the bucket;
    * `min_modules` — the fewest modules the bucket must select (default 1);
    * `infer` — whether placement compares the effects-inferred role (default
      `true`).
  """

  alias Anchor.Domain.Architecture.Selector

  @enforce_keys [:name, :role, :selectors]
  defstruct [:name, :role, :selectors, min_modules: 1, infer: true]

  @type role :: :framework | :ui | :adapters | :domain | :managers

  @type t :: %__MODULE__{
          name: String.t(),
          role: role(),
          selectors: [Selector.t()],
          min_modules: pos_integer(),
          infer: boolean()
        }
end
