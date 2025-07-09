defmodule AnchorTest do
  use ExUnit.Case
  doctest Anchor

  test "returns list of checks" do
    checks = Anchor.checks()
    assert length(checks) == 3
    assert Anchor.Check.NoDependency in checks
    assert Anchor.Check.MustUseModule in checks
    assert Anchor.Check.ModulePatternRestrictions in checks
  end
end
