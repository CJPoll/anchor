defmodule Anchor.Domain.Violation do
  @moduledoc """
  A single architectural violation detected by a check — **Domain** data
  (ADR 001).

  This is the value a check's Domain detection returns, free of any framework
  type: it carries only what a violation *is* (`line`, `trigger`, `message`),
  not how Credo renders it. `Anchor.Check.Base` (Framework) maps each
  `%Violation{}` onto a `Credo.Issue` via `format_issue/2`, so the mapping to the
  framework's issue struct — category, priority, and other check metadata — stays
  at the Framework edge and never leaks into the Manager or the detection code.

  ## Fields

    * `:line` — the 1-based source line the violation is reported on, or `nil`
      when the detector could not resolve a line (Credo then defaults it).
    * `:trigger` — the token Credo highlights (a module name, a function
      name/arity, `"if"`, `"case"`, a filename, ...), as a string.
    * `:message` — the human-readable explanation shown to the developer.
    * `:filename` — the file the violation sits on, or `nil` (the default) for
      the source file the check ran on. Only a failure that is not about a
      checked source file sets it: a missing or invalid `.anchor.yml` sits on the
      config path (DND-1265).
    * `:kind` — `:rule` (the default) for a rule a checked file broke, or
      `:fail_closed` for a report that Anchor could not check something (a
      missing or invalid config, an unparseable file). See
      `Anchor.Domain.Failures`.
    * `:key` — a graph rule's stable baseline key (DND-5440, DND-5441): no
      line numbers and no message text that moves; `nil` otherwise.
    * `:rule_id` — the `id` of the rule a graph violation belongs to, or `nil`.
    * `:enforcement` — `:enforce` (the default: the finding fails the run) or
      `:report` (DND-5441: a finding of an `enforcement: report` rule, printed
      and never failing). A fail-closed violation is always `:enforce`.
  """

  @enforce_keys [:message]
  defstruct [
    :line,
    :trigger,
    :message,
    filename: nil,
    kind: :rule,
    key: nil,
    rule_id: nil,
    enforcement: :enforce
  ]

  @type kind :: :rule | :fail_closed

  @type t :: %__MODULE__{
          line: pos_integer() | nil,
          trigger: String.t() | nil,
          message: String.t(),
          filename: String.t() | nil,
          kind: kind(),
          key: String.t() | nil,
          rule_id: String.t() | nil,
          enforcement: :enforce | :report
        }

  @doc """
  `violation` with `enforcement` (`:enforce` or `:report`); every other field
  kept. The one place outside a struct literal that sets it.
  """
  @spec with_enforcement(t(), :enforce | :report) :: t()
  def with_enforcement(%__MODULE__{} = violation, enforcement)
      when enforcement in [:enforce, :report],
      do: %{violation | enforcement: enforcement}
end
