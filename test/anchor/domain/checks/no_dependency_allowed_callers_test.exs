defmodule Anchor.Domain.Checks.NoDependencyAllowedCallersTest do
  # `allowed_callers` on `no_direct_dependency` (DND-1269, gap A5 of the DND-1263
  # design): the listed modules may do what the rule forbids everyone else.
  #
  # The exemption is per DEFINING module, never per file. ONE table of files,
  # each run against one rule per relation (`forbidden_modules`,
  # `forbidden_patterns`, `forbidden_functions`) in both `match` modes. Every
  # row's code reaches the target the same way, `Bad.Web.f(1)`, so every
  # relation must give the same answer: `[line]` (the first line a module that
  # is not an allowed caller reaches it) or `[]` (only allowed callers do).
  #
  # Code is attributed to the module whose body it is in. A nested module is its
  # own module, in both directions. A `defimpl` body belongs to the module the
  # `defimpl` defines (`Protocol.For`), and a `defprotocol` body to the protocol.
  # Code whose module the source cannot show is attributed to no module, so no
  # allowed caller exempts it: top-level code, a `quote` (the macro's caller
  # runs it), a non-literal `defmodule`, a `defimpl` for a list of types.
  #
  # Sabotage record:
  #   ../../../sabotage_records/no_dependency-20260929-dnd_1269_allowed_callers.md
  use ExUnit.Case, async: true

  alias Anchor.Domain.Checks.NoDependency
  alias Anchor.Domain.FunctionRef
  alias Anchor.Domain.Violation

  @allowed [App.Allowed]

  # {label, source, allowed_callers, expected lines}
  @rows [
    {"the allowed caller itself",
     """
     defmodule App.Allowed do
       def a, do: Bad.Web.f(1)
     end
     """, @allowed, []},
    {"a caller that is not listed",
     """
     defmodule App.Other do
       def a, do: Bad.Web.f(1)
     end
     """, @allowed, [2]},
    {"two modules in one file: the second cannot launder through the first",
     """
     defmodule App.Allowed do
       def a, do: :ok
     end

     defmodule App.Other do
       def b, do: Bad.Web.f(1)
     end
     """, @allowed, [6]},
    {"two modules in one file: the first cannot launder through the second",
     """
     defmodule App.Other do
       def b, do: Bad.Web.f(1)
     end

     defmodule App.Allowed do
       def a, do: Bad.Web.f(1)
     end
     """, @allowed, [2]},
    {"two modules in one file, both calling: only the unlisted one is reported",
     """
     defmodule App.Allowed do
       def a, do: Bad.Web.f(1)
     end

     defmodule App.Other do
       def b, do: Bad.Web.f(1)
     end
     """, @allowed, [6]},
    {"two unlisted modules calling: reported once, at the first line",
     """
     defmodule App.One do
       def a, do: Bad.Web.f(1)
     end

     defmodule App.Two do
       def b, do: Bad.Web.f(1)
     end
     """, @allowed, [2]},
    {"an allowed module nested in an unlisted one: its own call is allowed",
     """
     defmodule App do
       defmodule Allowed do
         def a, do: Bad.Web.f(1)
       end
     end
     """, @allowed, []},
    {"an allowed module nested in an unlisted one: the parent's call is not",
     """
     defmodule App do
       defmodule Allowed do
         def a, do: :ok
       end

       def b, do: Bad.Web.f(1)
     end
     """, @allowed, [6]},
    {"an unlisted module nested in an allowed one: the child's call is not allowed",
     """
     defmodule App.Allowed do
       defmodule Inner do
         def a, do: Bad.Web.f(1)
       end
     end
     """, @allowed, [3]},
    {"an unlisted module nested in an allowed one: the parent's call after it is allowed",
     """
     defmodule App.Allowed do
       defmodule Inner do
         def a, do: :ok
       end

       def b, do: Bad.Web.f(1)
     end
     """, @allowed, []},
    {"a module with the allowed name nested elsewhere is another module",
     """
     defmodule Other do
       defmodule App.Allowed do
         def a, do: Bad.Web.f(1)
       end
     end
     """, @allowed, [3]},
    {"a parent namespace of the allowed caller is not the caller",
     """
     defmodule App do
       def a, do: Bad.Web.f(1)
     end
     """, @allowed, [2]},
    {"a child namespace of the allowed caller is not the caller",
     """
     defmodule App.Allowed.Child do
       def a, do: Bad.Web.f(1)
     end
     """, @allowed, [2]},
    {"top-level code belongs to no module",
     """
     Bad.Web.f(1)
     """, @allowed, [1]},
    {"a quote inside the allowed caller runs in the macro's caller",
     """
     defmodule App.Allowed do
       defmacro m do
         quote do
           Bad.Web.f(1)
         end
       end
     end
     """, @allowed, [4]},
    {"a non-literal defmodule inside the allowed caller names no module",
     """
     defmodule App.Allowed do
       defmodule unquote(name) do
         def a, do: Bad.Web.f(1)
       end
     end
     """, @allowed, [3]},
    {"a defimpl inside the allowed caller is the impl module, not the caller",
     """
     defmodule App.Allowed do
       defimpl String.Chars do
         def to_string(_), do: Bad.Web.f(1)
       end
     end
     """, @allowed, [3]},
    {"a defimpl whose impl module is listed",
     """
     defimpl String.Chars, for: App.Thing do
       def to_string(_), do: Bad.Web.f(1)
     end
     """, [String.Chars.App.Thing], []},
    {"a defimpl resolves its protocol through an alias and defaults for: to the module",
     """
     defmodule App.Thing do
       alias App.Proto

       defimpl Proto do
         def f(_), do: Bad.Web.f(1)
       end
     end
     """, [App.Proto.App.Thing], []},
    {"a defimpl for: a list defines several modules, so it is never exempt",
     """
     defimpl App.Proto, for: [App.A, App.B] do
       def f(_), do: Bad.Web.f(1)
     end
     """, [App.Proto.App.A, App.Proto.App.B], [2]},
    {"a defimpl's call is not the enclosing module's",
     """
     defmodule App.Other do
       defimpl String.Chars do
         def to_string(_), do: Bad.Web.f(1)
       end
     end
     """, [App.Other], [3]},
    {"a defprotocol nested in the allowed caller is its own module",
     """
     defmodule App.Allowed do
       defprotocol P do
         @x Bad.Web.f(1)
         def g(t)
       end
     end
     """, @allowed, [3]},
    {"a listed defprotocol",
     """
     defprotocol App.P do
       @x Bad.Web.f(1)
       def g(t)
     end
     """, [App.P], []},
    {"two listed callers",
     """
     defmodule App.Allowed do
       def a, do: Bad.Web.f(1)
     end

     defmodule App.Also do
       def b, do: Bad.Web.f(1)
     end
     """, [App.Allowed, App.Also], []},
    {"the allowed caller reaches the target through an alias",
     """
     defmodule App.Allowed do
       alias Bad.Web
       def a, do: Web.f(1)
     end
     """, @allowed, []},
    {"an alias in the allowed parent does not exempt the child that uses it",
     """
     defmodule App.Allowed do
       alias Bad.Web

       defmodule Child do
         def a, do: Web.f(1)
       end
     end
     """, @allowed, [5]},
    {"no allowed callers: every caller is reported",
     """
     defmodule App.Allowed do
       def a, do: Bad.Web.f(1)
     end
     """, [], [2]}
  ]

  @relations %{
    forbidden_modules: %{forbidden_modules: [Bad.Web]},
    forbidden_patterns: %{forbidden_patterns: ["*.Web"]},
    forbidden_functions: %{
      forbidden_functions: [%FunctionRef{module: Bad.Web, function: :f, arity: :any}]
    }
  }

  for relation <- Map.keys(@relations), mode <- [:reference, :call] do
    describe "allowed_callers with #{relation} (match: #{mode})" do
      @describetag relation: relation, mode: mode

      test "every row reports exactly its expected lines", %{relation: relation, mode: mode} do
        failures =
          for {label, source, allowed, expected} <- @rows,
              got = lines(source, [rule(relation, mode, allowed)]),
              got != expected do
            "#{label}: want #{inspect(expected)}, got #{inspect(got)}"
          end

        assert failures == [], Enum.join(failures, "\n")
      end
    end
  end

  describe "the exemption is per rule" do
    test "a caller allowed by one rule is still reported by a rule that does not list it" do
      source = "defmodule App.Allowed do\n  def a, do: Bad.Web.f(1)\nend\n"

      rules = [
        rule(:forbidden_modules, :reference, [App.Allowed]),
        rule(:forbidden_modules, :reference, [])
      ]

      assert lines(source, rules) == [2]
    end

    test "every relation of the rule is exempt for the caller, and only for it" do
      source = """
      defmodule App.Allowed do
        def a, do: Bad.Web.f(1)
        def b, do: Bad.Repo.insert(1)
      end

      defmodule App.Other do
        def c, do: Bad.Repo.insert(1)
      end
      """

      rule = %{
        forbidden_modules: [Bad.Web],
        forbidden_patterns: ["*.Repo"],
        forbidden_functions: [%FunctionRef{module: Bad.Repo, function: :insert, arity: 1}],
        match: :call,
        allowed_callers: [App.Allowed]
      }

      assert source |> detect([rule]) |> Enum.map(&{&1.trigger, &1.line}) ==
               [{"Bad.Repo", 7}, {"Bad.Repo.insert/1", 7}]
    end

    test "same_context scoping still applies to the callers that are not listed" do
      source = """
      defmodule App.Allowed do
        def a, do: App.Web.f(1)
      end

      defmodule App.Other do
        def b, do: App.Web.f(1)
      end
      """

      rule = %{
        forbidden_modules: [],
        forbidden_patterns: ["*.Web"],
        same_context: true,
        context_depth: 1,
        allowed_callers: [App.Allowed]
      }

      assert Enum.map(NoDependency.detect_violations(ast(source), [rule], ["App"]), & &1.line) ==
               [6]
    end
  end

  describe "dynamic calls" do
    @refs [%FunctionRef{module: Bad.Web, function: :f, arity: :any}]

    test "a dynamic call in the allowed caller is not reported" do
      source = "defmodule App.Allowed do\n  def a(m), do: m.f(1)\nend\n"
      assert dynamic_lines(source, [ff_rule(@refs, [App.Allowed])]) == []
    end

    test "a dynamic call in a caller that is not listed is reported" do
      source = "defmodule App.Other do\n  def a(m), do: m.f(1)\nend\n"
      assert dynamic_lines(source, [ff_rule(@refs, [App.Allowed])]) == [2]
    end

    test "a dynamic call exempt under one rule names only the rules that still apply" do
      source = "defmodule App.Allowed do\n  def a(m), do: m.f(1)\nend\n"
      other = [%FunctionRef{module: Other.Mod, function: :f, arity: :any}]

      assert [%Violation{message: message, line: 2}] =
               detect(source, [ff_rule(@refs, [App.Allowed]), ff_rule(other, [])])

      assert message =~ "(Other.Mod.f)"
      refute message =~ "Bad.Web.f"
    end
  end

  describe "what allowed_callers does not exempt" do
    test "an unresolvable directive in the allowed caller is still reported" do
      source = "defmodule App.Allowed do\n  alias @target, as: T\n  def a, do: T.f(1)\nend\n"

      assert [%Violation{trigger: "alias", line: 2}] =
               detect(source, [rule(:forbidden_modules, :reference, [App.Allowed])])
    end
  end

  defp rule(relation, mode, allowed) do
    %{forbidden_modules: [], forbidden_patterns: [], match: mode, allowed_callers: allowed}
    |> Map.merge(Map.fetch!(@relations, relation))
  end

  defp ff_rule(refs, allowed) do
    %{forbidden_modules: [], forbidden_functions: refs, allowed_callers: allowed}
  end

  defp ast(source), do: Code.string_to_quoted!(source)

  defp detect(source, rules), do: NoDependency.detect_violations(ast(source), rules)

  defp lines(source, rules), do: source |> detect(rules) |> Enum.map(& &1.line)

  defp dynamic_lines(source, rules) do
    for %Violation{message: "Anchor cannot statically resolve" <> _rest, line: line} <-
          detect(source, rules),
        do: line
  end
end
