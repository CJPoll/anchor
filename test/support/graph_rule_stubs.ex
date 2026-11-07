defmodule Anchor.Test.GraphRuleStubs do
  @moduledoc """
  Test-only graph rules (DND-5440). The Manager and task tests inject this
  registry (`graph_rules: all()`), so they exercise the runner apart from the
  real rule modules (`Anchor.Domain.GraphRules.all/0`).
  Their types are not in `Anchor.Domain.RuleSchema`: they never load from a
  real `.anchor.yml`.
  """
  alias Anchor.Domain.Violation

  defmodule Ok do
    @moduledoc false
    @behaviour Anchor.Domain.GraphRule
    def rule_type, do: :stub_ok
    def narrows?(_base_key, _key), do: false
    def check(_model, _rule), do: []
  end

  defmodule Finds do
    @moduledoc false
    @behaviour Anchor.Domain.GraphRule
    def rule_type, do: :stub_finds
    def narrows?(_base_key, _key), do: false

    # One violation per selected module, on its source file.
    def check(model, rule) do
      for module <- Anchor.Domain.GraphRules.select(model, rule) do
        classified = model.classification[module]

        %Violation{
          filename: classified.source_file,
          line: 2,
          message: "#{inspect(module)} was found. Fix: do not be found.",
          # DND-5441: a stable key, `<id>|<Module>|found`.
          key: Anchor.Domain.ViolationKey.graph_key(rule, inspect(module), "found")
        }
      end
    end
  end

  # DND-5633: finds as `Finds` does, and reads any key ending `|found` as a
  # narrowing of the same rule's key ending `|wider`.
  defmodule FindsNarrowing do
    @moduledoc false
    @behaviour Anchor.Domain.GraphRule
    def rule_type, do: :stub_finds_narrowing
    def check(model, rule), do: Finds.check(model, rule)

    def narrows?(base_key, key),
      do: String.ends_with?(base_key, "|wider") and String.ends_with?(key, "|found")
  end

  # Declares narrows?/2 and is used by exactly one test, which unloads it to
  # prove the answer does not depend on whether a module is loaded. Not in
  # all/0, so no other test can load it behind that test's back.
  defmodule NarrowsWhenUnloaded do
    @moduledoc false
    @behaviour Anchor.Domain.GraphRule
    def rule_type, do: :stub_narrows_when_unloaded
    def check(_model, _rule), do: []
    def narrows?(base_key, key), do: {base_key, key} == {"r|wider", "r|found"}
  end

  defmodule Raises do
    @moduledoc false
    @behaviour Anchor.Domain.GraphRule
    def rule_type, do: :stub_raises
    def narrows?(_base_key, _key), do: false
    def check(_model, _rule), do: raise("rule blew up")
  end

  defmodule Throws do
    @moduledoc false
    @behaviour Anchor.Domain.GraphRule
    def rule_type, do: :stub_throws
    def narrows?(_base_key, _key), do: false
    def check(_model, _rule), do: throw(:thrown)
  end

  defmodule Exits do
    @moduledoc false
    @behaviour Anchor.Domain.GraphRule
    def rule_type, do: :stub_exits
    def narrows?(_base_key, _key), do: false
    def check(_model, _rule), do: exit(:gone)
  end

  defmodule Malformed do
    @moduledoc false
    @behaviour Anchor.Domain.GraphRule
    def rule_type, do: :stub_malformed
    def narrows?(_base_key, _key), do: false
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
    def narrows?(_base_key, _key), do: false
    def check(model, rule), do: Anchor.Test.GraphRuleStubs.cfa_probe(model, rule)
  end

  defmodule NeedsCfa do
    @moduledoc false
    @behaviour Anchor.Domain.GraphRule
    def rule_type, do: :stub_needs_cfa
    def narrows?(_base_key, _key), do: false
    def needs, do: [:cfa, :cfa]
    def check(model, rule), do: Anchor.Test.GraphRuleStubs.cfa_probe(model, rule)
  end

  defmodule NeedsUnknown do
    @moduledoc false
    @behaviour Anchor.Domain.GraphRule
    def rule_type, do: :stub_needs_unknown
    def narrows?(_base_key, _key), do: false
    def needs, do: [:cfa, :nope]
    def check(_model, _rule), do: []
  end

  defmodule NeedsNonList do
    @moduledoc false
    @behaviour Anchor.Domain.GraphRule
    def rule_type, do: :stub_needs_non_list
    def narrows?(_base_key, _key), do: false
    def needs, do: :cfa
    def check(_model, _rule), do: []
  end

  defmodule NeedsEffectsWithoutCfa do
    @moduledoc false
    @behaviour Anchor.Domain.GraphRule
    def rule_type, do: :stub_needs_effects_without_cfa
    def narrows?(_base_key, _key), do: false
    def needs, do: [:effects]
    def check(_model, _rule), do: []
  end

  defmodule NeedsPlacementWithoutEffects do
    @moduledoc false
    @behaviour Anchor.Domain.GraphRule
    def rule_type, do: :stub_needs_placement_without_effects
    def narrows?(_base_key, _key), do: false
    def needs, do: [:cfa, :placement]
    def check(_model, _rule), do: []
  end

  defmodule NeedsDemandWithoutCfa do
    @moduledoc false
    @behaviour Anchor.Domain.GraphRule
    def rule_type, do: :stub_needs_demand_without_cfa
    def narrows?(_base_key, _key), do: false
    def needs, do: [:demand]
    def check(_model, _rule), do: []
  end

  def all,
    do: [
      Ok,
      Finds,
      FindsNarrowing,
      Raises,
      Throws,
      Exits,
      Malformed,
      CfaProbe,
      NeedsCfa,
      NeedsUnknown,
      NeedsNonList,
      NeedsEffectsWithoutCfa,
      NeedsPlacementWithoutEffects,
      NeedsDemandWithoutCfa
    ]
end
