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
  """

  @enforce_keys [:message]
  defstruct [:line, :trigger, :message]

  @type t :: %__MODULE__{
          line: pos_integer() | nil,
          trigger: String.t() | nil,
          message: String.t()
        }
end
