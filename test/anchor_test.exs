defmodule AnchorTest do
  use ExUnit.Case
  doctest Anchor

  test "returns list of checks" do
    checks = Anchor.checks()
    assert length(checks) == 12
    assert Anchor.Check.NoDependency in checks
    assert Anchor.Check.NoTransitiveDependency in checks
    assert Anchor.Check.MustUseModule in checks
    assert Anchor.Check.ModulePatternRestrictions in checks
    assert Anchor.Check.SingleControlFlow in checks
    assert Anchor.Check.NoTupleMatchInHead in checks
    assert Anchor.Check.CaseOnBareArg in checks
    assert Anchor.Check.NoComparisonInIf in checks
    assert Anchor.Check.NoDiscardingArrowInWith in checks
    assert Anchor.Check.AlphabetizedFunctions in checks
    assert Anchor.Check.MaxFileLength in checks
    assert Anchor.Check.StructGetterConvention in checks
  end

  test "every entry in checks/0 is a loadable, well-formed Credo check module" do
    for check <- Anchor.checks() do
      assert Code.ensure_loaded?(check), "#{inspect(check)} is not a loadable module"

      assert function_exported?(check, :run_on_all_source_files, 3),
             "#{inspect(check)} does not implement run_on_all_source_files/3 (Anchor.Check.Base)"

      assert function_exported?(check, :rule_type, 0),
             "#{inspect(check)} does not implement rule_type/0 (Anchor.Check.Base)"

      assert function_exported?(check, :check_file, 3),
             "#{inspect(check)} does not implement check_file/3 (Anchor.Check.Base)"

      assert function_exported?(check, :category, 0),
             "#{inspect(check)} is not a valid Credo.Check (missing category/0)"
    end
  end

  test "checks/0 matches every check module that actually exists on disk" do
    check_dir = Path.join([__DIR__, "..", "lib", "anchor", "check"])

    modules_on_disk =
      check_dir
      |> File.ls!()
      |> Enum.reject(&(&1 == "base.ex"))
      |> Enum.map(fn filename ->
        filename
        |> Path.basename(".ex")
        |> Macro.camelize()
        |> then(&Module.concat([Anchor, Check, &1]))
      end)
      |> Enum.sort()

    assert Enum.sort(Anchor.checks()) == modules_on_disk,
           "Anchor.checks/0 has drifted from the check modules under lib/anchor/check/ " <>
             "(excluding base.ex, the shared __using__ macro). Add or remove entries in " <>
             "Anchor.checks/0 to match."
  end
end
