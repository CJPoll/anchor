defmodule Anchor.Domain.Aggregates.Declaration do
  @moduledoc """
  One aggregate declaration (DND-5476) — **Domain** data (ADR 001).

  An aggregate is the set of tables one transaction may write. A declaration
  comes from the `aggregates: declare:` section of `.anchor.yml`
  (`Anchor.Domain.Aggregates.Config`) or from a module's persisted
  `@anchor_aggregate` attribute (`use Anchor.Aggregate`, or the attribute
  written by hand); `Anchor.Domain.Aggregates.Index` merges every declaration
  of one name into one.

    * `name` — the aggregate's name, a module-name string
      (`"MyApp.Threads.ThreadSpace"`); it need not name a module. Names are
      kept as strings so no atom is made from config text.
    * `schemas` — the Ecto schema modules in it, exact module atoms.
    * `tables` — tables written by name with no schema module.
    * `owners` — the modules allowed to write its schemas (DND-5478 reads it).
    * `sites` — where it was declared: `:config` (the `.anchor.yml`) or
      `{:attribute, module, source_file, line}` (the module whose
      `@anchor_aggregate` declared it, its source file and `defmodule` line,
      either `nil` when the beam has none). An issue may also sit at
      `{:module, module, source_file, line}`: a module that persists under
      `declare: none` (DND-5659), which declares nothing.
  """

  @enforce_keys [:name]
  defstruct [:name, schemas: [], tables: [], owners: [], sites: []]

  @type site ::
          :config
          | {:attribute, module(), String.t() | nil, pos_integer() | nil}
          | {:module, module(), String.t() | nil, pos_integer() | nil}

  @type t :: %__MODULE__{
          name: String.t(),
          schemas: [module()],
          tables: [String.t()],
          owners: [module()],
          sites: [site()]
        }
end
