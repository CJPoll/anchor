defmodule Anchor.Managers.LintAttributeNamesTest do
  # Every Anchor check, through the real Manager, over a file whose module
  # attribute is named like a special form or a name a walker clause matches
  # (`@quote`, `@use`, `@import`, ...). Setting an attribute is
  # `{:@, meta, [{name, meta, [value]}]}` and reading one is
  # `{:@, meta, [{name, meta, context}]}`: the inner node of a set has the shape
  # of the call `name(value)`, so a walker that descends into it without
  # stopping at `@` reads `@use Other.Mod` as `use Other.Mod`, and `@quote x` as
  # a quote block. Each check must report on that file exactly what it reports
  # when the attribute is named `value`.
  #
  # The config loader is a Hammox mock (`expect/3`, so each load self-proves);
  # everything else is real: parsing, facts, selection, the module graph and
  # every check's detection.
  use ExUnit.Case, async: true

  import Hammox

  alias Anchor.Config
  alias Anchor.ConfigLoaderMock
  alias Anchor.Managers.Lint
  alias Credo.SourceFile

  setup :verify_on_exit!

  @attribute_names "test/fixtures/special_variable_names.txt"
                   |> File.read!()
                   |> String.split()
                   |> Enum.map(&String.to_atom/1)

  # One rule per check, each selecting `lib/**/*.ex`, each with a relation the
  # sample source violates where the type has one, so a check that stopped
  # reading the file at the attribute would report less.
  @rules [
    %{"type" => "no_direct_dependency", "forbidden_modules" => ["Foo.Bar"]},
    %{
      "type" => "no_direct_dependency",
      "match" => "call",
      "forbidden_patterns" => ["*.Sub"],
      "forbidden_functions" => ["Foo.Bar.call/1"]
    },
    %{"type" => "no_transitive_dependency", "forbidden_modules" => ["Foo.Bar"]},
    %{"type" => "must_use_module", "required_modules" => ["Other.Mod"]},
    %{"type" => "module_pattern_restrictions", "allowed_functions" => ["other"]},
    %{"type" => "single_control_flow"},
    %{"type" => "no_tuple_match_in_head"},
    %{"type" => "case_on_bare_arg"},
    %{"type" => "no_comparison_in_if"},
    %{"type" => "no_discarding_arrow_in_with"},
    %{"type" => "alphabetized_functions"},
    %{"type" => "max_file_length", "max_lines" => 1},
    %{"type" => "struct_getter_convention"},
    %{"type" => "no_discarded_pure_expression"},
    %{"type" => "no_forwarding_function"},
    %{"type" => "struct_owned_by_module"}
  ]

  @config Config.parse_config(%{
            "rules" =>
              Enum.map(@rules, &Map.merge(&1, %{"paths" => ["lib/**/*.ex"], "recursive" => true}))
          })

  # The attribute is set from a module, from a keyword list with a `do:` (the
  # shape of a block call's arguments) and read inside a function; the
  # references after it prove the attribute left the lexical environment alone.
  defp source(name) do
    """
    defmodule Sample.AttrUser do
      alias Foo.Bar

      @#{name} Other.Mod
      @#{name} [do: Third.Mod]

      def run(x) do
        y = Bar.call(@#{name})
        __MODULE__.Sub.go(y)
        Mod.go(x)
      end
    end
    """
  end

  # Every check's violations on `source`, as comparable tuples, per check.
  defp violations_by_check(source) do
    Map.new(Anchor.checks(), fn check ->
      source_file = SourceFile.parse(source, "lib/sample/attr_user.ex")
      expect(ConfigLoaderMock, :load, fn -> {:ok, @config} end)

      assert {:ok, results} = Lint.run(check, [source_file], [], config_loader: ConfigLoaderMock)

      violations =
        for {_file, violations} <- results, violation <- violations do
          {violation.kind, violation.line, violation.trigger, violation.message}
        end

      {check, violations}
    end)
  end

  test "the plain-named baseline: the relation checks flag the sample, none fails closed" do
    by_check = violations_by_check(source(:value))

    fail_closed =
      for {check, violations} <- by_check,
          {:fail_closed, _line, _trigger, _message} = v <- violations,
          do: {check, v}

    assert fail_closed == []

    assert Enum.map(by_check[Anchor.Check.NoDependency], &elem(&1, 2)) |> Enum.sort() ==
             ["Foo.Bar", "Foo.Bar.call/1", "Sample.AttrUser.Sub"]

    assert by_check[Anchor.Check.NoTransitiveDependency] != []

    # The sample never `use`s Other.Mod; it only stores it in an attribute.
    assert [{_kind, _line, _trigger, _message}] = by_check[Anchor.Check.MustUseModule]
  end

  for name <- @attribute_names do
    test "every check reads an attribute named @#{name} as it reads one named @value" do
      name = unquote(name)
      baseline = violations_by_check(source(:value))
      by_check = violations_by_check(source(name))

      # Every check that differs, not only the first, so a failure names them all.
      differing =
        for check <- Anchor.checks(), by_check[check] != baseline[check] do
          {check, want: baseline[check], got: by_check[check]}
        end

      assert differing == [], "an attribute named @#{name}: #{inspect(differing, pretty: true)}"
    end
  end
end
