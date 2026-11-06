defmodule Anchor.Domain.Proposal do
  @moduledoc """
  One placement proposal, the unit every placement rule reports (DND-5448) — a
  **Domain** value (ADR 001).

  A violation of a placement rule is exactly a proposal whose `current` differs
  from its `proposed`, and its `Fix:` is `Anchor.Domain.Placement.render/1` of the
  proposal.

    * `level` — what moves: `:function` here; later tickets add `:expression`,
      `:module`, `:directory`, `:context`, `:app` and `:aggregate`.
    * `subject` — what the proposal is about (an mfa at the function level).
    * `current`, `proposed` — where it is, and where it belongs: a module,
      `{:bucket, role, context, module | nil}` (`module` named when the target is
      known), or `:delete`.
    * `rule` — the rule type that reports it.
    * `reason` — why; one `render/1` clause per reason, and an unknown reason
      raises.
    * `evidence` — what the reason rests on, as text the render may quote.
    * `key` — the stable baseline key, never a line number (`key/4`).
  """

  alias Anchor.Domain.ViolationKey

  @enforce_keys [:level, :subject, :current, :proposed, :rule, :reason]
  defstruct [:level, :subject, :current, :proposed, :rule, :reason, evidence: [], key: nil]

  @type level :: :expression | :function | :module | :directory | :context | :app | :aggregate
  @type place :: module() | {:bucket, atom(), String.t() | nil, module() | nil} | :delete
  @type t :: %__MODULE__{
          level: level(),
          subject: mfa(),
          current: place(),
          proposed: place(),
          rule: atom(),
          reason: atom(),
          evidence: [String.t()],
          key: String.t() | nil
        }

  @doc """
  The stable key of a proposal: rule, level, subject and proposed, joined by a
  vertical bar. No line number, and no text that moves.
  """
  @spec key(atom(), level(), mfa(), place()) :: String.t()
  def key(rule, level, subject, proposed) do
    Enum.join([rule, level, ViolationKey.mfa(subject), place_text(proposed)], "|")
  end

  @doc "`place` as text: a module's name, `delete`, or a bucket's role."
  @spec place_text(place()) :: String.t()
  def place_text(:delete), do: "delete"
  def place_text({:bucket, role, _context, _module}), do: Atom.to_string(role)
  def place_text(module) when is_atom(module), do: inspect(module)
end
