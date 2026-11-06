defmodule Anchor.Adapters.LintKeys do
  @moduledoc """
  Behaviour for running the project's Credo checks and collecting the keys
  of their findings, the **Side Effect** port (ADR 001) behind `mix
  anchor.baseline --write` (DND-5632). The real adapter is
  `Anchor.Adapters.CredoKeys`; tests double it with Hammox
  (`Anchor.LintKeysMock`).

  `keys/0` runs every check `.credo.exs` enables over the whole file set,
  from the working directory, and returns `{rule_id, key}` for every finding
  that has a key (a finding of an ast rule with a `baseline:`,
  `Anchor.Domain.ViolationKey.ast_key/3`) and the ids of the baselined rules
  some check judged (each finding and each baseline issue names its rule): a
  rule whose check is not enabled is in neither. It never returns a Credo
  type: Domain values only. `{:error, reason}` when Credo halted.
  """

  @callback keys() ::
              {:ok, %{keys: [{String.t(), String.t()}], rule_ids: [String.t()]}}
              | {:error, term()}
end
