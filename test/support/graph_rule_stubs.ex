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
          # DND-5441: a stable key, `<id>|<Module>|found`.
          key: Anchor.Domain.ViolationKey.graph_key(rule, inspect(module), "found")
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

  def all, do: [Ok, Finds, Raises, Throws, Exits, Malformed]
end
