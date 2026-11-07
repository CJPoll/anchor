defmodule Anchor.Domain.Proposal do
  @moduledoc """
  One placement proposal, the unit every placement rule reports (DND-5448) — a
  **Domain** value (ADR 001).

  A violation of a placement rule is exactly a proposal whose `current` differs
  from its `proposed`, and its `Fix:` is `Anchor.Domain.Placement.render/1` of the
  proposal.

    * `level` — what moves: `:function` here; later tickets add `:expression`,
      `:module`, `:directory`, `:context`, `:app` and `:aggregate`.
    * `subject` — what the proposal is about: an mfa at the function level, a module
      or a directory path at the directory level (DND-5462), a module at the module
      level (DND-5463).
    * `current`, `proposed` — where it is, and where it belongs: a module,
      `{:bucket, role, context, module | nil}` (`module` named when the target is
      known), `:delete`, `{:inline, mfa}` (an inert hop's callers call `mfa`
      directly, DND-5461), a directory path or `{:library_context, contexts}`
      (DND-5462), `{:split, [{module, [mfa]}]}` (one module per component) or
      `{:extract, module}` (a shared private helper's own module, DND-5463).
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
  @type place ::
          module()
          | {:bucket, atom(), String.t() | nil, module() | nil}
          | :delete
          | {:inline, mfa()}
          | Path.t()
          | {:library_context, [String.t()]}
          | {:split, [{module(), [mfa()]}]}
          | {:extract, module()}
  @type t :: %__MODULE__{
          level: level(),
          subject: mfa() | module() | Path.t(),
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
