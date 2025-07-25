defmodule AnchorTest do
  use ExUnit.Case
  doctest Anchor

  test "returns list of checks" do
    checks = Anchor.checks()
    assert length(checks) == 7
    assert Anchor.Check.NoDependency in checks
    assert Anchor.Check.NoTransitiveDependency in checks
    assert Anchor.Check.MustUseModule in checks
    assert Anchor.Check.ModulePatternRestrictions in checks
    assert Anchor.Check.SingleControlFlow in checks
    assert Anchor.Check.NoTupleMatchInHead in checks
    assert Anchor.Check.CaseOnBareArg in checks
  end
end
