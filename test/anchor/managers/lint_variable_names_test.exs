defmodule Anchor.Managers.LintVariableNamesTest do
  # DND-1310: every Anchor check, through the real Manager, over a file whose
  # variable is named like a special form or a name a walker clause matches
  # (`quote`, `case`, `import`, ...). A variable is `{name, meta, context_atom}`;
  # a clause that read it as the call `{name, meta, [args]}` crashed the check
  # (a variable named `quote`) or counted it (a variable named `case` as a
  # control-flow structure). Each check must report on that file exactly what it
  # reports when the variable is named `value`.
  #
  # The config loader is a Hammox mock (`expect/3`, so each load self-proves);
  # everything else is real: parsing, facts, selection, the module graph and
  # every check's detection.
  #
  # Sabotage records:
  #   ../../sabotage_records/dependency_analyzer-20260929-dnd_1310_analyzer_quote_crash.md
  #   ../../sabotage_records/single_control_flow-20260929-dnd_1310_analyzer_quote_crash.md
  #   ../../sabotage_records/struct_getter_convention-20260929-dnd_1310_analyzer_quote_crash.md
  #   ../../sabotage_records/lint-20260929-dnd_1310_analyzer_quote_crash.md (paired mutations)
  use ExUnit.Case, async: true

  import Hammox

  alias Anchor.Config
  alias Anchor.ConfigLoaderMock
  alias Anchor.Managers.Lint
  alias Credo.SourceFile

  setup :verify_on_exit!

  @variable_names "test/fixtures/special_variable_names.txt"
                  |> File.read!()
                  |> String.split()
                  |> Enum.map(&String.to_atom/1)

  @fragment File.read!("test/fixtures/option_parser_split.txt")

  # One rule per check, each selecting `lib/**/*.ex`, each with a relation the
  # sample source violates where the type has one, so a check that stopped
  # reading the file after the variable would report less.
  @rules [
    %{"type" => "no_direct_dependency", "forbidden_modules" => ["Foo.Bar"]},
    %{
      "type" => "no_direct_dependency",
      "match" => "call",
      "forbidden_patterns" => ["*.Sub"],
      "forbidden_functions" => ["Foo.Bar.call/1"]
    },
    # Not in the sample; `Enum.reverse/1` in OptionParser.split/1 comes after
    # its `quote` variables.
    %{"type" => "no_direct_dependency", "forbidden_modules" => ["Enum"]},
    %{"type" => "no_transitive_dependency", "forbidden_modules" => ["Foo.Bar"]},
    %{"type" => "must_use_module", "required_modules" => ["Some.Base"]},
    %{"type" => "module_pattern_restrictions", "allowed_functions" => ["other"]},
    %{"type" => "single_control_flow"},
    %{"type" => "no_tuple_match_in_head"},
    %{"type" => "case_on_bare_arg"},
    %{"type" => "no_comparison_in_if"},
    %{"type" => "no_discarding_arrow_in_with"},
    %{"type" => "alphabetized_functions"},
    %{"type" => "max_file_length", "max_lines" => 1},
    %{"type" => "struct_getter_convention"}
  ]

  @config Config.parse_config(%{
            "rules" =>
              Enum.map(@rules, &Map.merge(&1, %{"paths" => ["lib/**/*.ex"], "recursive" => true}))
          })

  defp source(name) do
    """
    defmodule Sample.VarUser do
      alias Foo.Bar

      def run(#{name}) do
        #{name} = Bar.call(#{name})
        __MODULE__.Sub.go(#{name})
      end
    end
    """
  end

  # Every check's violations on `source`, as comparable tuples, per check.
  defp violations_by_check(source) do
    Map.new(Anchor.checks(), fn check ->
      source_file = SourceFile.parse(source, "lib/sample/var_user.ex")
      expect(ConfigLoaderMock, :load, fn -> {:ok, @config} end)

      assert {:ok, results} = Lint.run(check, [source_file], [], config_loader: ConfigLoaderMock)

      violations =
        for {_file, violations} <- results, violation <- violations do
          {violation.kind, violation.line, violation.trigger, violation.message}
        end

      {check, violations}
    end)
  end

  defp fail_closed(by_check) do
    for {check, violations} <- by_check,
        {:fail_closed, _line, _trigger, _message} = v <- violations,
        do: {check, v}
  end

  test "the plain-named baseline: every relation check flags the sample, none fails closed" do
    by_check = violations_by_check(source(:value))

    assert fail_closed(by_check) == []

    for check <- [
          Anchor.Check.NoDependency,
          Anchor.Check.NoTransitiveDependency,
          Anchor.Check.MustUseModule,
          Anchor.Check.ModulePatternRestrictions,
          Anchor.Check.MaxFileLength
        ] do
      assert by_check[check] != [], "#{inspect(check)} flagged nothing on the baseline"
    end

    assert Enum.map(by_check[Anchor.Check.NoDependency], &elem(&1, 2)) |> Enum.sort() ==
             ["Foo.Bar", "Foo.Bar.call/1", "Sample.VarUser.Sub"]

    assert by_check[Anchor.Check.SingleControlFlow] == []
  end

  for name <- @variable_names do
    test "every check reads a variable named #{name} as it reads one named value" do
      name = unquote(name)
      baseline = violations_by_check(source(:value))
      by_check = violations_by_check(source(name))

      # Every check that differs, not only the first, so a failure names them all.
      differing =
        for check <- Anchor.checks(), by_check[check] != baseline[check] do
          {check, want: baseline[check], got: by_check[check]}
        end

      assert differing == [], "a variable named #{name}: #{inspect(differing, pretty: true)}"
    end
  end

  test "every check runs over Elixir's OptionParser.split/1 without failing closed" do
    by_check = violations_by_check(@fragment)

    assert fail_closed(by_check) == []

    # Positive control: the dependency check read past the `quote` variables.
    assert Enum.map(by_check[Anchor.Check.NoDependency], &elem(&1, 2)) == ["Enum"]
  end
end
