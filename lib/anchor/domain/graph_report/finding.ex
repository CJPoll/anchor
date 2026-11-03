defmodule Anchor.Domain.GraphReport.Finding do
  @moduledoc """
  One line of a `mix anchor.graph` report (DND-5440) — **Domain** data.

    * `rule_id` — the rule's `id`, or `nil` (a fail-closed issue, or a rule
      without one);
    * `type` — the rule type, or `nil` for a fail-closed issue;
    * `label` — how the line names its source: the rule's label
      (`Anchor.Domain.Failures.rule_label/1`), or `anchor.graph` for a
      fail-closed issue;
    * `enforcement` — `:enforce` (fails the run) or `:report` (printed only);
    * `key` — the stable baseline key (DND-5441), or `nil`;
    * `file`, `line` — where it sits (`line` may be `nil`);
    * `message` — the whole message, ending with `Fix: <shape>`.
  """

  alias Anchor.Domain.Violation

  @enforce_keys [:label, :enforcement, :file, :message]
  defstruct [:rule_id, :type, :label, :enforcement, :key, :file, :line, :message]

  @type enforcement :: :enforce | :report

  @type t :: %__MODULE__{
          rule_id: String.t() | nil,
          type: atom() | nil,
          label: String.t(),
          enforcement: enforcement(),
          key: String.t() | nil,
          file: String.t(),
          line: pos_integer() | nil,
          message: String.t()
        }

  @fail_closed_label "anchor.graph"

  @doc "The label of a fail-closed issue."
  @spec fail_closed_label() :: String.t()
  def fail_closed_label, do: @fail_closed_label

  @doc """
  A fail-closed issue from its `%Violation{}` (`Anchor.Domain.Failures`):
  always `:enforce`, on the violation's file (`default_file` when it names
  none).
  """
  @spec fail_closed(Violation.t(), String.t()) :: t()
  def fail_closed(%Violation{} = violation, default_file) do
    %__MODULE__{
      label: @fail_closed_label,
      enforcement: :enforce,
      key: violation.key,
      file: violation.filename || default_file,
      line: violation.line,
      message: violation.message
    }
  end

  @doc """
  A report-only note from its `%Violation{}`: `fail_closed/2`, but
  `:report`, so it prints and never fails the run (DND-5658: the landed
  judge's FIRST LANDING lines).
  """
  @spec note(Violation.t(), String.t()) :: t()
  def note(%Violation{} = violation, default_file),
    do: %{fail_closed(violation, default_file) | enforcement: :report}

  @doc """
  A rule finding: the rule's `%Violation{}`, labelled by `label`, with the
  rule's enforcement (`:enforce` unless the rule says `:report`).
  """
  @spec from_rule(Violation.t(), map(), String.t(), String.t()) :: t()
  def from_rule(%Violation{} = violation, rule, label, default_file) do
    %__MODULE__{
      rule_id: Map.get(rule, :id),
      type: rule.type,
      label: label,
      enforcement: enforcement(rule),
      key: violation.key,
      file: violation.filename || default_file,
      line: violation.line,
      message: violation.message
    }
  end

  @doc "A rule's enforcement: `:report` when it says so, else `:enforce`."
  @spec enforcement(map()) :: enforcement()
  def enforcement(rule) do
    if Map.get(rule, :enforcement) in [:report, "report"], do: :report, else: :enforce
  end

  @doc """
  The finding as the JSON document's entry: `rule_id, type, enforcement, key,
  file, line, message, fix`, where `message` is the text before `Fix:` and
  `fix` the text after it.
  """
  @spec to_json(t()) :: map()
  def to_json(%__MODULE__{} = finding) do
    {message, fix} = split_fix(finding.message)

    %{
      "rule_id" => finding.rule_id,
      "type" => finding.type && Atom.to_string(finding.type),
      "enforcement" => Atom.to_string(finding.enforcement),
      "key" => finding.key,
      "file" => finding.file,
      "line" => finding.line,
      "message" => message,
      "fix" => fix
    }
  end

  defp split_fix(message) do
    case String.split(message, " Fix: ", parts: 2) do
      [text, fix] -> {text, fix}
      [text] -> {text, nil}
    end
  end
end
