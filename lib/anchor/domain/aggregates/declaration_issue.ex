defmodule Anchor.Domain.Aggregates.DeclarationIssue do
  @moduledoc """
  A declaration that names nothing or claims too much (DND-5476) — **Domain**
  data (ADR 001). `Anchor.Domain.Aggregates.Index.build/2` finds them;
  `Anchor.Domain.GraphRules.AggregateDeclarations` reports each one.

    * `kind`:
      * `:claimed_twice` — a schema or table two aggregates claim (one issue
        per claiming site);
      * `:unknown_schema` / `:unknown_owner` — a schema or owner naming no
        module of the project;
      * `:not_a_schema` — a schema module with no `__schema__/1`;
      * `:empty_aggregate` — an aggregate with no schemas and no tables;
      * `:malformed_attribute` — an `@anchor_aggregate` value of the wrong
        shape (the module contributes nothing);
      * `:persists_under_none` — under `aggregates: declare: none`, a module
        that persists (`Anchor.Domain.Aggregates.Persistence`), at
        `{:module, ...}` (DND-5659).
    * `subject` — what it is about: a module, or a table name (a string).
    * `aggregates` — the aggregate names involved, sorted.
    * `site` — where it sits (`t:Anchor.Domain.Aggregates.Declaration.site/0`).
    * `detail` — for `:malformed_attribute`, what is wrong; for
      `:persists_under_none`, why the module persists; else `nil`.
  """

  alias Anchor.Domain.Aggregates.Declaration

  @enforce_keys [:kind, :subject, :site]
  defstruct [:kind, :subject, :site, aggregates: [], detail: nil]

  @type kind ::
          :claimed_twice
          | :unknown_schema
          | :not_a_schema
          | :unknown_owner
          | :empty_aggregate
          | :malformed_attribute
          | :persists_under_none

  @type t :: %__MODULE__{
          kind: kind(),
          subject: module() | String.t(),
          site: Declaration.site(),
          aggregates: [String.t()],
          detail: String.t() | nil
        }
end
