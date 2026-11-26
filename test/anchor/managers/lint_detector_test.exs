defmodule Anchor.Managers.LintDetectorTest do
  # DND-8063: Lint runs a check's Domain detector. A file no rule selects is
  # never handed to the detector (one that ignores its rules would report
  # it), and a key Lint cannot build for a baselined rule's finding is a
  # crash on the file, named for the check. A sibling of lint_test.exs, so a
  # sabotage run of Lint selects it.
  #
  # Sabotage record:
  #   ../../sabotage_records/lint-20261127-athena_DND_8063_framework_tests_mock_manager.md
  use ExUnit.Case, async: true

  import Hammox

  alias Anchor.BaselineStoreMock
  alias Anchor.Config
  alias Anchor.ConfigLoaderMock
  alias Anchor.Domain.Violation
  alias Anchor.Managers.Lint
  alias Credo.SourceFile

  setup :verify_on_exit!

  # CaseOnBareArg reads no key of its rules: handed a file, it reports it.
  @bare """
  defmodule MyApp.Bare do
    def f(x) do
      case x do
        _ -> 1
      end
    end
  end
  """

  test "a file no rule selects is not detected, though its detector ignores its rules" do
    rule = %{type: :case_on_bare_arg, paths: ["lib/other/**/*.ex"], recursive: true}
    expect(ConfigLoaderMock, :load, fn -> {:ok, %Config{rules: [rule]}} end)
    file = SourceFile.parse(@bare, "lib/my_app/bare.ex")

    assert {:ok, [{^file, []} | _config]} =
             Lint.run(Anchor.Domain.Checks.CaseOnBareArg, [file], [],
               config_loader: ConfigLoaderMock,
               enforce_selection_floors: false
             )
  end

  test "control: the same file, selected, is reported" do
    rule = %{type: :case_on_bare_arg, paths: ["lib/**/*.ex"], recursive: true}
    expect(ConfigLoaderMock, :load, fn -> {:ok, %Config{rules: [rule]}} end)
    file = SourceFile.parse(@bare, "lib/my_app/bare.ex")

    assert {:ok, [{^file, [%Violation{kind: :rule}]}]} =
             Lint.run(Anchor.Domain.Checks.CaseOnBareArg, [file], [],
               config_loader: ConfigLoaderMock
             )
  end

  test "a finding whose key cannot be built (its file holds |) is one crash on the file, naming the check" do
    rule = %{
      type: :case_on_bare_arg,
      id: "bare",
      paths: ["lib/**/*.ex"],
      recursive: true,
      baseline: ".anchor/baselines/bare.txt"
    }

    expect(ConfigLoaderMock, :load, fn -> {:ok, %Config{rules: [rule]}} end)
    stub(BaselineStoreMock, :read, fn _root, _path -> {:ok, []} end)
    file = SourceFile.parse(@bare, "lib/my_app/a|b.ex")

    assert {:ok, [{^file, violations} | _config]} =
             Lint.run(Anchor.Domain.Checks.CaseOnBareArg, [file], [],
               check: Anchor.Check.CaseOnBareArg,
               config_loader: ConfigLoaderMock,
               baseline_store: BaselineStoreMock,
               root: "/proj",
               enforce_selection_floors: false
             )

    assert [%Violation{kind: :fail_closed, trigger: "Anchor.Check.CaseOnBareArg"}] =
             Enum.filter(violations, &(&1.kind == :fail_closed))
  end
end
