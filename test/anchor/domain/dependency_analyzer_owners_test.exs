defmodule Anchor.Domain.DependencyAnalyzerOwnersTest do
  # DND-1269: which module each piece of code belongs to, for `allowed_callers`.
  #
  # `defined_modules/1` is the set of modules the file defines that code can be
  # attributed to. It is what the run-time "an allowed caller that no longer
  # exists" report compares a rule's `allowed_callers` against, so it must name
  # exactly the modules the attribution can produce: a caller the attribution
  # can exempt is one this list can find, and nothing else.
  #
  # Sabotage record:
  #   ../../sabotage_records/dependency_analyzer-20260929-dnd_1269_allowed_callers.md
  use ExUnit.Case, async: true

  alias Anchor.Domain.DependencyAnalyzer

  # {label, source, defined modules (sorted)}
  @rows [
    {"one module", "defmodule A do\nend\n", [A]},
    {"two modules in one file", "defmodule A do\nend\ndefmodule B do\nend\n", [A, B]},
    {"a nested module is qualified by its parent",
     "defmodule A do\n  defmodule B do\n  end\nend\n", [A, A.B]},
    {"a dotted nested name", "defmodule A do\n  defmodule B.C do\n  end\nend\n", [A, A.B.C]},
    {"a defprotocol, nested like a defmodule",
     "defmodule A do\n  defprotocol P do\n    def f(t)\n  end\nend\n", [A, A.P]},
    {"a defimpl with for:", "defimpl String.Chars, for: A do\nend\n", [String.Chars.A]},
    {"a defimpl inside a module defaults for: to the module",
     "defmodule A do\n  defimpl String.Chars do\n  end\nend\n", [A, String.Chars.A]},
    {"a defimpl resolves its protocol and for: through aliases",
     "defmodule A do\n  alias X.Proto\n  alias Y.T\n  defimpl Proto, for: T do\n  end\nend\n",
     [A, X.Proto.Y.T]},
    {"a module nested in a defimpl is qualified by the impl module",
     "defimpl P, for: A do\n  defmodule H do\n  end\nend\n", [P.A, P.A.H]},
    {"a defimpl for: a list names no module", "defimpl P, for: [A, B] do\nend\n", []},
    {"a top-level defimpl with no for: names no module", "defimpl P do\nend\n", []},
    {"a defimpl whose for: is not literal names no module", "defimpl P, for: @t do\nend\n", []},
    {"a non-literal defmodule names no module, nor anything nested in it",
     "defmodule unquote(n) do\n  defmodule B do\n  end\nend\n", []},
    {"a module inside a quote is the macro caller's, not this file's",
     "defmodule A do\n  defmacro m do\n    quote do\n      defmodule B do\n      end\n" <>
       "    end\n  end\nend\n", [A]},
    {"a variable named defmodule is not a module (DND-1310)",
     "defmodule A do\n  def f(defimpl), do: defimpl\nend\n", [A]},
    # Elixir expands a top-level `defmodule` name through the aliases in scope,
    # and an `Elixir.`- or `__MODULE__`-headed name wherever it is. A nested
    # name with a plain head is the parent's child, whatever is aliased.
    # Each expected value below is what `elixir` itself defines.
    {"a top-level alias as: renames the module a defmodule defines",
     "alias Evil.Ns, as: Athena\ndefmodule Athena.Allowed do\nend\n", [Evil.Ns.Allowed]},
    {"a top-level alias renames the module a defmodule defines",
     "alias Evil.Athena\ndefmodule Athena.Allowed do\nend\n", [Evil.Athena.Allowed]},
    {"a top-level alias renames the module a defprotocol defines",
     "alias Evil.Ns, as: P9\ndefprotocol P9.Proto do\n  def m(t)\nend\n", [Evil.Ns.Proto]},
    {"a top-level Elixir. prefix", "defmodule Elixir.T.Allowed do\nend\n", [T.Allowed]},
    {"a nested name ignores the aliases in scope",
     "defmodule O do\n  alias X.Foo\n  defmodule Foo.Bar do\n  end\nend\n", [O, O.Foo.Bar]},
    {"a nested Elixir. prefix is absolute",
     "defmodule O do\n  defmodule Elixir.T.Mod do\n  end\nend\n", [O, T.Mod]},
    {"a nested __MODULE__ prefix is the parent",
     "defmodule O do\n  defmodule __MODULE__.Inner do\n  end\nend\n", [O, O.Inner]},
    {"no module", "x = 1\n", []}
  ]

  test "defined_modules/1 names exactly the modules code can be attributed to" do
    failures =
      for {label, source, expected} <- @rows,
          got = DependencyAnalyzer.defined_modules(Code.string_to_quoted!(source)),
          got != expected do
        "#{label}: want #{inspect(expected)}, got #{inspect(got)}"
      end

    assert failures == [], Enum.join(failures, "\n")
  end
end
