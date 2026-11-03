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
    * `changed_functions` — how many functions the scope found (`nil` before the
      scope is read, or when the run stopped before it); `0` after a good diff
      read is a legitimate empty scope, said loudly by the report;
    * `baseline` — `:passed`, `:none` (no mutant selected a test), or `nil`;
    * `outcomes` — one per mutant applied (or with no test), in plan order;
    * `planned` — the dry run's mutants with their selection;
    * `skipped` — `Anchor.Domain.Sabotage.Skipped`, never applied;
    * `errors` — `{changed_function, reason}` for a function no mutant could
      be made of (`:not_in_source`, `:defimpl_target_not_literal`,
      `{:parse_error, line, message}`,
      `{:unreadable, posix}`);
    * `not_run` — the mutants past the cap;
    * `generated` — how many mutants the changed functions yielded (`nil`
      when the run stopped before generating); `0` beside one or more changed
      functions is said loudly by the report (DND-5617);
    * `no_mutant` — `{changed_function, reason}` for each changed function
      that yielded no mutant (`Anchor.Domain.Sabotage.NoMutant.reason/1`).
    * `records` — the sabotage records written (DND-5484), `{:create |
      :append, path}`;
    * `record_error` — `nil`, or why a record could not be written. The
      outcomes still stand and keep their verdict: a survivor stays exit 1
      and an unmeasured run exit 3; only a pass becomes exit 2 (DND-5641).
  """

  alias Anchor.Domain.Sabotage.Mutant
  alias Anchor.Domain.Sabotage.Outcome
  alias Anchor.Domain.Sabotage.Skipped

  defstruct base: nil,
            notes: [],
            refusal: nil,
            dry_run: false,
            restore: false,
            changed_functions: nil,
            baseline: nil,
            outcomes: [],
            planned: [],
            skipped: [],
            errors: [],
            not_run: [],
            generated: nil,
            no_mutant: [],
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
          changed_functions: nil | non_neg_integer(),
          baseline: nil | :passed | :none,
          outcomes: [outcome()],
          planned: [{Mutant.t(), selection()}],
          skipped: [Skipped.t()],
          errors: [{map(), term()}],
          not_run: [Mutant.t()],
          generated: nil | non_neg_integer(),
          no_mutant: [{map(), String.t()}],
          records: [{:create | :append, String.t()}],
          record_error: String.t() | nil
        }
end
