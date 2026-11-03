defmodule Anchor.Domain.Sabotage.Run do
  @moduledoc """
  One `mix anchor.sabotage run` (DND-5473), as data: what it found, did and
  refused. Pure **Domain**; `Anchor.Domain.Sabotage.Report` renders it, and
  the Manager saves it to `_build/<env>/anchor/sabotage/last-run.etf` for
  DND-5483 and DND-5484.

    * `notes` — lines said before anything else (a leftover journal restored);
    * `refusal` — `nil`, or `{exit_code, message}`: the run stopped there;
    * `dry_run` — the plan was printed and nothing applied;
    * `restore` — a `mix anchor.sabotage restore`: only its notes are said;
    * `baseline` — `:passed`, `:none` (no mutant selected a test), or `nil`;
    * `outcomes` — one per mutant applied (or with no test), in plan order;
    * `planned` — the dry run's mutants with their selection;
    * `skipped` — `Anchor.Domain.Sabotage.Skipped`, never applied;
    * `errors` — `{changed_function, reason}` for a function no mutant could
      be made of (`:not_in_source`, `{:parse_error, line, message}`,
      `{:unreadable, posix}`);
    * `not_run` — the mutants past the cap;
    * `records` — the sabotage records written (DND-5484), `{:create |
      :append, path}`;
    * `record_error` — `nil`, or why a record could not be written (exit 2;
      the outcomes still stand).
  """

  alias Anchor.Domain.Sabotage.Mutant
  alias Anchor.Domain.Sabotage.Outcome
  alias Anchor.Domain.Sabotage.Skipped

  defstruct base: nil,
            notes: [],
            refusal: nil,
            dry_run: false,
            restore: false,
            baseline: nil,
            outcomes: [],
            planned: [],
            skipped: [],
            errors: [],
            not_run: [],
            records: [],
            record_error: nil

  @type selection :: {atom(), [String.t()]}
  @type outcome :: %{
          mutant: Mutant.t(),
          status: Outcome.status(),
          killers: [Outcome.killer()],
          selection: selection(),
          reason: String.t() | nil
        }
  @type t :: %__MODULE__{
          base: String.t() | nil,
          notes: [String.t()],
          refusal: nil | {pos_integer(), String.t()},
          dry_run: boolean(),
          restore: boolean(),
          baseline: nil | :passed | :none,
          outcomes: [outcome()],
          planned: [{Mutant.t(), selection()}],
          skipped: [Skipped.t()],
          errors: [{map(), term()}],
          not_run: [Mutant.t()],
          records: [{:create | :append, String.t()}],
          record_error: String.t() | nil
        }
end
