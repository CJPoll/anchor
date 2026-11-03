defmodule Anchor.Test.GraphRuleStubs do
  @moduledoc """
  Test-only graph rules (DND-5440). No graph rule type ships with the runner,
  so the Manager and task tests inject this registry (`graph_rules: all()`).
  Their types are not in `Anchor.Domain.RuleSchema`: they never load from a
  real `.anchor.yml`.
  """
  alias Anchor.Domain.Violation

  defmodule Ok do
    @moduledoc false
    @behaviour Anchor.Domain.GraphRule
    def rule_type, do: :stub_ok
    def check(_model, _rule), do: []
  end

  defmodule Finds do
    @moduledoc false
    @behaviour Anchor.Domain.GraphRule
    def rule_type, do: :stub_finds

    # One violation per selected module, on its source file.
    def check(model, rule) do
      for module <- Anchor.Domain.GraphRules.select(model, rule) do
        classified = model.classification[module]

        %Violation{
          filename: classified.source_file,
          line: 2,
          message: "#{inspect(module)} was found. Fix: do not be found.",
          key: inspect(module)
        }
      end
    end
  end

  defmodule Raises do
    @moduledoc false
    @behaviour Anchor.Domain.GraphRule
    def rule_type, do: :stub_raises
    def check(_model, _rule), do: raise("rule blew up")
  end

  defmodule Throws do
    @moduledoc false
    @behaviour Anchor.Domain.GraphRule
    def rule_type, do: :stub_throws
    def check(_model, _rule), do: throw(:thrown)
  end

  defmodule Exits do
    @moduledoc false
    @behaviour Anchor.Domain.GraphRule
    def rule_type, do: :stub_exits
    def check(_model, _rule), do: exit(:gone)
  end

  defmodule Malformed do
    @moduledoc false
    @behaviour Anchor.Domain.GraphRule
    def rule_type, do: :stub_malformed
    # Not a list of violations: the runner must report it, not crash.
    def check(_model, _rule), do: :oops
  end

  # DND-5574: a rule's view of `Model.cfa`, as one violation on the first
  # selected module: "cfa: nil" or "cfa: <total> sites".
  def cfa_probe(model, rule) do
    seen =
      case model.cfa do
        nil -> "nil"
        %Anchor.Domain.Cfa{counts: counts} -> "#{counts.total} sites"
      end

    [module | _] = Anchor.Domain.GraphRules.select(model, rule)

    [
      %Violation{
        filename: model.classification[module].source_file,
        line: 1,
        message: "#{rule.id} saw cfa: #{seen}. Fix: none, a probe.",
        key: rule.id
      }
    ]
  end

  defmodule CfaProbe do
    @moduledoc false
    @behaviour Anchor.Domain.GraphRule
    def rule_type, do: :stub_cfa_probe
    def check(model, rule), do: Anchor.Test.GraphRuleStubs.cfa_probe(model, rule)
  end

  defmodule NeedsCfa do
    @moduledoc false
    @behaviour Anchor.Domain.GraphRule
    def rule_type, do: :stub_needs_cfa
    def needs, do: [:cfa, :cfa]
    def check(model, rule), do: Anchor.Test.GraphRuleStubs.cfa_probe(model, rule)
  end

  defmodule NeedsUnknown do
    @moduledoc false
    @behaviour Anchor.Domain.GraphRule
    def rule_type, do: :stub_needs_unknown
    def needs, do: [:cfa, :nope]
    def check(_model, _rule), do: []
  end

  defmodule NeedsNonList do
    @moduledoc false
    @behaviour Anchor.Domain.GraphRule
    def rule_type, do: :stub_needs_non_list
    def needs, do: :cfa
    def check(_model, _rule), do: []
  end

  def all,
    do: [
      Ok,
      Finds,
      Raises,
      Throws,
      Exits,
      Malformed,
      CfaProbe,
      NeedsCfa,
      NeedsUnknown,
      NeedsNonList
    ]
end
