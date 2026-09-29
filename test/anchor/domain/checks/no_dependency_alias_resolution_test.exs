defmodule Anchor.Domain.Checks.NoDependencyAliasResolutionTest do
  # Alias and import resolution for `no_direct_dependency` (DND-1266).
  #
  # Each test forbids a TARGET module and reaches it through a lexical directive:
  # `alias` (single, `as:`, multi `{}`), `require ... as:`, `import` (bare,
  # `only:`, `except:`), a nested `defmodule`'s implicit alias, and
  # `__MODULE__`. Before DND-1266 the analyzer saw aliases only through the
  # directive line, so `match: :call` missed every aliased or imported call and a
  # multi-alias evaded both modes: a rule read green while checking nothing.
  #
  # Tests run in BOTH match modes wherever both apply. The negative tests prove
  # the resolution is scoped: a same-named module that is not the target is not
  # reported, and a directive in another module's scope does not apply.
  #
  # Sabotage records:
  #   ../../../sabotage_records/dependency_analyzer-20260929-dnd_1266_alias_import_resolution.md
  #   ../../../sabotage_records/no_dependency-20260929-dnd_1266_alias_import_resolution.md
  use ExUnit.Case, async: true

  alias Anchor.Domain.Checks.NoDependency
  alias Anchor.Domain.Violation

  defp detect(source, forbidden, mode) do
    rule = %{forbidden_modules: forbidden, forbidden_patterns: [], match: mode}
    NoDependency.detect_violations(Code.string_to_quoted!(source), [rule])
  end

  defp triggers(source, forbidden, mode) do
    source |> detect(forbidden, mode) |> Enum.map(& &1.trigger) |> Enum.sort()
  end

  for mode <- [:reference, :call] do
    describe "an aliased target is reported (match: #{mode})" do
      @describetag mode: mode

      test "alias A.B then B.f()", %{mode: mode} do
        source = """
        defmodule W do
          alias Forbidden.Target

          def f, do: Target.run()
        end
        """

        assert triggers(source, [Forbidden.Target], mode) == ["Forbidden.Target"]
      end

      test "alias A.B, as: C then C.f()", %{mode: mode} do
        source = """
        defmodule W do
          alias Forbidden.Target, as: T

          def f, do: T.run()
        end
        """

        assert triggers(source, [Forbidden.Target], mode) == ["Forbidden.Target"]
      end

      test "multi-alias alias A.{B, C} then B.f() and C.f()", %{mode: mode} do
        source = """
        defmodule W do
          alias Forbidden.{Target, Other}

          def f, do: Target.run()
          def g, do: Other.run()
        end
        """

        assert triggers(source, [Forbidden.Target, Forbidden.Other], mode) ==
                 ["Forbidden.Other", "Forbidden.Target"]
      end

      test "multi-alias with a multi-segment element aliases its last segment", %{mode: mode} do
        source = """
        defmodule W do
          alias Forbidden.{Deep.Target, Other}

          def f, do: Target.run()
        end
        """

        assert triggers(source, [Forbidden.Deep.Target], mode) == ["Forbidden.Deep.Target"]
      end

      test "an alias of an alias resolves through the first", %{mode: mode} do
        source = """
        defmodule W do
          alias Forbidden.Target
          alias Target.Sub

          def f, do: Sub.run()
        end
        """

        assert triggers(source, [Forbidden.Target.Sub], mode) == ["Forbidden.Target.Sub"]
      end

      test "require A.B, as: C then C.m()", %{mode: mode} do
        source = """
        defmodule W do
          require Forbidden.Target, as: T

          def f, do: T.run()
        end
        """

        assert triggers(source, [Forbidden.Target], mode) == ["Forbidden.Target"]
      end

      test "alias :erlang_mod, as: M then M.f() resolves to the atom", %{mode: mode} do
        source = """
        defmodule W do
          alias :forbidden_mod, as: M

          def f, do: M.run()
        end
        """

        assert triggers(source, [:forbidden_mod], mode) == [":forbidden_mod"]
      end

      test "an alias declared in an outer module is visible in a nested module", %{mode: mode} do
        source = """
        defmodule Outer do
          alias Forbidden.Target

          defmodule Inner do
            def f, do: Target.run()
          end
        end
        """

        assert triggers(source, [Forbidden.Target], mode) == ["Forbidden.Target"]
      end

      test "a nested defmodule aliases its name in the enclosing module", %{mode: mode} do
        source = """
        defmodule Outer do
          defmodule Target do
            def run, do: :ok
          end

          def f, do: Target.run()
        end
        """

        assert triggers(source, [Outer.Target], mode) == ["Outer.Target"]
      end

      test "alias __MODULE__.Sub then Sub.f()", %{mode: mode} do
        source = """
        defmodule Forbidden do
          alias __MODULE__.Target

          def f, do: Target.run()
        end
        """

        assert triggers(source, [Forbidden.Target], mode) == ["Forbidden.Target"]
      end

      test "__MODULE__.Sub.f()", %{mode: mode} do
        source = """
        defmodule Forbidden do
          def f, do: __MODULE__.Target.run()
        end
        """

        assert triggers(source, [Forbidden.Target], mode) == ["Forbidden.Target"]
      end

      test "import A.B then bare f()", %{mode: mode} do
        source = """
        defmodule W do
          import Forbidden.Target

          def f, do: run()
        end
        """

        assert triggers(source, [Forbidden.Target], mode) == ["Forbidden.Target"]
      end

      test "import A.B, only: [f: 0] then f()", %{mode: mode} do
        source = """
        defmodule W do
          import Forbidden.Target, only: [run: 0]

          def f, do: run()
        end
        """

        assert triggers(source, [Forbidden.Target], mode) == ["Forbidden.Target"]
      end

      test "import A.B, except: [g: 1] then f()", %{mode: mode} do
        source = """
        defmodule W do
          import Forbidden.Target, except: [other: 1]

          def f, do: run()
        end
        """

        assert triggers(source, [Forbidden.Target], mode) == ["Forbidden.Target"]
      end

      test "a same-named module that is not the target is not reported", %{mode: mode} do
        source = """
        defmodule W do
          alias Elsewhere.Target

          def f, do: Target.run()
        end
        """

        assert detect(source, [Forbidden.Target], mode) == []
      end

      test "forbidding the short name does not match an alias of another module", %{mode: mode} do
        source = """
        defmodule W do
          alias Forbidden.Target, as: Short

          def f, do: Short.run()
        end
        """

        assert detect(source, [Short], mode) == []
      end

      test "a multi-alias does not report its bare prefix", %{mode: mode} do
        source = """
        defmodule W do
          alias Forbidden.{Target}

          def f, do: Target.run()
        end
        """

        assert detect(source, [Forbidden], mode) == []
      end
    end
  end

  describe "resolution is lexically scoped (match: :call)" do
    test "an alias inside a nested module does not leak to its sibling" do
      source = """
      defmodule Outer do
        defmodule Inner do
          alias Forbidden.Target
        end

        defmodule Sibling do
          def f, do: Target.run()
        end
      end
      """

      assert detect(source, [Forbidden.Target], :call) == []
    end

    test "an alias in one top-level module does not apply in the next" do
      source = """
      defmodule First do
        alias Forbidden.Target
      end

      defmodule Second do
        def f, do: Target.run()
      end
      """

      assert detect(source, [Forbidden.Target], :call) == []
    end

    test "an alias inside a function body does not leak to the next function" do
      source = """
      defmodule W do
        def f do
          alias Forbidden.Target
          :ok
        end

        def g, do: Target.run()
      end
      """

      assert detect(source, [Forbidden.Target], :call) == []
    end

    test "an alias applies only after it is declared" do
      source = """
      defmodule W do
        def f, do: Target.run()

        alias Forbidden.Target
      end
      """

      assert detect(source, [Forbidden.Target], :call) == []
    end

    test "a later alias of the same short name replaces the earlier one" do
      source = """
      defmodule W do
        alias Forbidden.Target
        alias Elsewhere.Target

        def f, do: Target.run()
      end
      """

      assert detect(source, [Forbidden.Target], :call) == []
    end

    test "an import in one module does not resolve bare calls in its sibling" do
      source = """
      defmodule First do
        import Forbidden.Target
      end

      defmodule Second do
        def f, do: run()
      end
      """

      assert detect(source, [Forbidden.Target], :call) == []
    end
  end

  describe "import only:/except: narrow which bare calls resolve (match: :call)" do
    test "only: [f: 0] does not claim a bare call to another name" do
      source = """
      defmodule W do
        import Forbidden.Target, only: [run: 0]

        def f, do: other()
      end
      """

      assert detect(source, [Forbidden.Target], :call) == []
    end

    test "only: [f: 0] does not claim f with another arity" do
      source = """
      defmodule W do
        import Forbidden.Target, only: [run: 0]

        def f(x), do: run(x)
      end
      """

      assert detect(source, [Forbidden.Target], :call) == []
    end

    test "except: [f: 0] does not claim f/0" do
      source = """
      defmodule W do
        import Forbidden.Target, except: [run: 0]

        def f, do: run()
      end
      """

      assert detect(source, [Forbidden.Target], :call) == []
    end

    test "a later import of the same module replaces the earlier filter" do
      source = """
      defmodule W do
        import Forbidden.Target
        import Forbidden.Target, only: [other: 0]

        def f, do: run()
      end
      """

      assert detect(source, [Forbidden.Target], :call) == []
    end

    test "a local function is not claimed by an unrestricted import" do
      source = """
      defmodule W do
        import Forbidden.Target

        def f, do: helper(1)

        defp helper(x), do: x
      end
      """

      assert detect(source, [Forbidden.Target], :call) == []
    end

    test "Kernel calls, attributes and def heads are not claimed by an unrestricted import" do
      source = """
      defmodule W do
        import Forbidden.Target

        @moduledoc "doc"
        @doc "f"
        def f(x) when is_integer(x), do: inspect(x)
      end
      """

      assert detect(source, [Forbidden.Target], :call) == []
    end

    test "import Kernel, except: hands a Kernel name to an unrestricted import" do
      source = """
      defmodule W do
        import Kernel, except: [inspect: 1]
        import Forbidden.Target

        def f(x), do: inspect(x)
      end
      """

      assert triggers(source, [Forbidden.Target], :call) == ["Forbidden.Target"]
    end

    test "a piped bare call counts the piped argument toward its arity" do
      source = """
      defmodule W do
        import Forbidden.Target, only: [run: 1]

        def f(x), do: x |> run()
      end
      """

      assert triggers(source, [Forbidden.Target], :call) == ["Forbidden.Target"]
    end

    test "a local capture &f/1 resolves through the import" do
      source = """
      defmodule W do
        import Forbidden.Target, only: [run: 1]

        def f(xs), do: Enum.map(xs, &run/1)
      end
      """

      assert triggers(source, [Forbidden.Target], :call) == ["Forbidden.Target"]
    end

    test "an import directive alone is not a call" do
      source = """
      defmodule W do
        import Forbidden.Target, only: [run: 0]
      end
      """

      assert detect(source, [Forbidden.Target], :call) == []
    end
  end

  describe "violation line points at the resolved reference" do
    test "call mode reports the aliased call's line" do
      source = """
      defmodule W do
        alias Forbidden.Target

        def f, do: Target.run()
      end
      """

      assert [%Violation{line: 4}] = detect(source, [Forbidden.Target], :call)
    end

    test "call mode reports the imported bare call's line" do
      source = """
      defmodule W do
        import Forbidden.Target

        def f, do: run()
      end
      """

      assert [%Violation{line: 4}] = detect(source, [Forbidden.Target], :call)
    end

    test "a module called twice is reported once, at its first call" do
      source = """
      defmodule W do
        alias Forbidden.Target

        def f, do: Target.run()
        def g, do: Target.run()
      end
      """

      assert [%Violation{line: 4}] = detect(source, [Forbidden.Target], :call)
    end

    test "reference mode reports a multi-alias element's line" do
      source = """
      defmodule W do
        alias Forbidden.{
          Other,
          Target
        }
      end
      """

      assert [%Violation{line: 4}] = detect(source, [Forbidden.Target], :reference)
    end
  end

  for mode <- [:reference, :call] do
    describe "an unresolvable directive is reported, never read as no dependency (match: #{mode})" do
      @describetag mode: mode

      test "alias with a non-literal target", %{mode: mode} do
        source = """
        defmodule W do
          alias @target, as: T

          def f, do: T.run()
        end
        """

        assert [%Violation{} = violation] = detect(source, [Forbidden.Target], mode)
        assert violation.trigger == "alias"
        assert violation.line == 2
        assert violation.message =~ "cannot statically resolve"
        assert violation.message =~ "Fix:"
      end

      test "import with a non-literal target", %{mode: mode} do
        source = """
        defmodule W do
          import unquote(target)

          def f, do: run()
        end
        """

        assert [%Violation{trigger: "import", line: 2}] = detect(source, [Forbidden.Target], mode)
      end

      test "is reported once per file, not once per rule", %{mode: mode} do
        source = """
        defmodule W do
          alias @target, as: T
        end
        """

        rules =
          for forbidden <- [Forbidden.Target, Forbidden.Other] do
            %{forbidden_modules: [forbidden], forbidden_patterns: [], match: mode}
          end

        assert [%Violation{trigger: "alias", line: 2}] =
                 NoDependency.detect_violations(Code.string_to_quoted!(source), rules)
      end

      test "a non-literal directive inside a quote stays opaque", %{mode: mode} do
        source = """
        defmodule W do
          defmacro __using__(target) do
            quote do
              alias unquote(target)
            end
          end
        end
        """

        assert detect(source, [Forbidden.Target], mode) == []
      end
    end
  end
end
