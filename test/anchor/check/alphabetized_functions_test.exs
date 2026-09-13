defmodule Anchor.Check.AlphabetizedFunctionsTest do
  # Framework-edge characterization matrix for the `alphabetized_functions`
  # check, exercised end-to-end through `check_file/3`: source string in,
  # `[%Credo.Issue{}]` out. Detection is the pure
  # `Anchor.Domain.Checks.AlphabetizedFunctions`; this file pins the public/
  # private message prefixes, triggers and lines Credo renders, plus the T3
  # atom-keyed `mode` read and the `defguard`/multi-clause adjudications.
  #
  # Sabotage record:
  #   ../../sabotage_records/alphabetized_functions-20260913-dnd_135_t6_10_alphabetized_functions.md
  use ExUnit.Case, async: true

  alias Anchor.Check.AlphabetizedFunctions
  alias Credo.SourceFile

  defp issues(source, rule) do
    source
    |> SourceFile.parse("lib/test.ex")
    |> AlphabetizedFunctions.check_file([rule], [])
  end

  # Row #1 — :all, out of order (banana then apple)
  test "#1 :all flags an out-of-order function with exact message/trigger/line" do
    source = """
    defmodule M do
      def banana(), do: :ok
      def apple(), do: :ok
    end
    """

    result = issues(source, %{type: :alphabetized_functions, mode: :all})

    banana = Enum.find(result, &(&1.trigger == "banana/0"))
    assert banana

    assert banana.message ==
             "function `banana/0` is not in alphabetical order. It should appear after apple/0."

    assert banana.line_no == 2
  end

  # Row #2 — :all, ordered
  test "#2 :all passes ordered functions" do
    ordered = """
    defmodule M do
      def apple(), do: :ok
      def banana(), do: :ok
    end
    """

    assert [] == issues(ordered, %{type: :alphabetized_functions, mode: :all})

    # Positive control: swapping them flags.
    swapped = """
    defmodule M do
      def banana(), do: :ok
      def apple(), do: :ok
    end
    """

    refute [] == issues(swapped, %{type: :alphabetized_functions, mode: :all})
  end

  # Row #3 — arity tie-break (foo/0 before foo/1)
  test "#3 :all tie-breaks equal names by arity" do
    ordered = """
    defmodule M do
      def foo(), do: :ok
      def foo(a), do: a
    end
    """

    assert [] == issues(ordered, %{type: :alphabetized_functions, mode: :all})

    # Positive control: higher arity first is out of order.
    reversed = """
    defmodule M do
      def foo(a), do: a
      def foo(), do: :ok
    end
    """

    assert Enum.any?(
             issues(reversed, %{type: :alphabetized_functions, mode: :all}),
             &(&1.trigger == "foo/1")
           )
  end

  # Row #4 — case-insensitive. Uppercase-*initial* names (`Apple`) parse as
  # aliases, not defs, so they are never extracted; to actually exercise the
  # `String.downcase` in the sort we use two valid lowercase-initial names whose
  # ASCII order (`aB` < `aa`) is the reverse of their case-insensitive order
  # (`aa` < `aB`). Dropping the downcase flips these and reddens this row.
  test "#4 :all sorts case-insensitively" do
    ordered = """
    defmodule M do
      def aa(), do: :ok
      def aB(), do: :ok
    end
    """

    assert [] == issues(ordered, %{type: :alphabetized_functions, mode: :all})

    # Positive control: case-insensitively out of order still flags.
    out_of_order = """
    defmodule M do
      def aB(), do: :ok
      def aa(), do: :ok
    end
    """

    refute [] == issues(out_of_order, %{type: :alphabetized_functions, mode: :all})
  end

  # Row #5 — :public_only ignores private ordering
  test "#5 :public_only ignores out-of-order private functions" do
    source = """
    defmodule M do
      def apple(), do: :ok
      def banana(), do: :ok

      defp zebra(), do: :ok
      defp aardvark(), do: :ok
    end
    """

    assert [] == issues(source, %{type: :alphabetized_functions, mode: :public_only})

    # Positive control: out-of-order public IS flagged (Row #6 property).
    public_broken = """
    defmodule M do
      def banana(), do: :ok
      def apple(), do: :ok

      defp zebra(), do: :ok
      defp aardvark(), do: :ok
    end
    """

    refute [] == issues(public_broken, %{type: :alphabetized_functions, mode: :public_only})
  end

  # Row #6 — :public_only flags out-of-order public despite private noise
  test "#6 :public_only flags out-of-order public with `public ` prefix" do
    source = """
    defmodule M do
      def banana(), do: :ok
      def apple(), do: :ok

      defp zebra(), do: :ok
      defp aardvark(), do: :ok
    end
    """

    result = issues(source, %{type: :alphabetized_functions, mode: :public_only})

    apple = Enum.find(result, &(&1.trigger == "apple/0"))
    assert apple
    assert apple.message =~ "public function `apple/0` is not in alphabetical order"
    # Private noise is never reported in :public_only mode.
    refute Enum.any?(result, &(&1.trigger in ["zebra/0", "aardvark/0"]))
  end

  # Row #7 — :separate, out-of-order in public group
  test "#7 :separate flags out-of-order public with `public ` prefix" do
    source = """
    defmodule M do
      def banana(), do: :ok
      def apple(), do: :ok

      defp aardvark(), do: :ok
      defp zebra(), do: :ok
    end
    """

    result = issues(source, %{type: :alphabetized_functions, mode: :separate})

    apple = Enum.find(result, &(&1.trigger == "apple/0"))
    assert apple
    assert apple.message =~ "public function `apple/0` is not in alphabetical order"
    assert apple.line_no == 3
  end

  # Row #8 — :separate, out-of-order in private group
  test "#8 :separate flags out-of-order private with `private ` prefix" do
    source = """
    defmodule M do
      def apple(), do: :ok
      def banana(), do: :ok

      defp zebra(), do: :ok
      defp aardvark(), do: :ok
    end
    """

    result = issues(source, %{type: :alphabetized_functions, mode: :separate})

    aardvark = Enum.find(result, &(&1.trigger == "aardvark/0"))
    assert aardvark
    assert aardvark.message =~ "private function `aardvark/0` is not in alphabetical order"
    assert aardvark.line_no == 6
  end

  # Row #9 — :separate structural: private before public
  test "#9 :separate flags a private function before public functions" do
    source = """
    defmodule M do
      defp helper(), do: :ok

      def apple(), do: :ok
      def banana(), do: :ok
    end
    """

    result = issues(source, %{type: :alphabetized_functions, mode: :separate})

    helper = Enum.find(result, &(&1.trigger == "helper/0"))
    assert helper

    assert helper.message ==
             "private function `helper/0` appears before public functions. " <>
               "In :separate mode, all public functions must come before private functions."

    assert helper.line_no == 2
  end

  # Row #10 — :separate default (no mode key), ordered public-then-private
  test "#10 :separate is the default when the rule has no mode" do
    ordered = """
    defmodule M do
      def apple(), do: :ok
      def banana(), do: :ok

      defp aardvark(), do: :ok
      defp zebra(), do: :ok
    end
    """

    # No `:mode` key at all — must default to :separate.
    assert [] == issues(ordered, %{type: :alphabetized_functions})

    # Positive control: a private-before-public structural break flags even
    # under the defaulted mode.
    structural_break = """
    defmodule M do
      defp helper(), do: :ok
      def apple(), do: :ok
    end
    """

    assert Enum.any?(
             issues(structural_break, %{type: :alphabetized_functions}),
             &(&1.message =~ "appears before public functions")
           )
  end

  # Row #11 — defmacro/defmacrop ordered within their visibility group
  test "#11 :separate orders defmacro/defmacrop within visibility groups" do
    ordered = """
    defmodule M do
      defmacro apple(), do: quote(do: :ok)
      defmacro banana(), do: quote(do: :ok)

      defmacrop aardvark(), do: quote(do: :ok)
      defmacrop zebra(), do: quote(do: :ok)
    end
    """

    assert [] == issues(ordered, %{type: :alphabetized_functions, mode: :separate})

    # Positive control: swapped public macros flag with the `public ` prefix.
    broken = """
    defmodule M do
      defmacro banana(), do: quote(do: :ok)
      defmacro apple(), do: quote(do: :ok)
    end
    """

    assert Enum.any?(
             issues(broken, %{type: :alphabetized_functions, mode: :separate}),
             &(&1.trigger == "apple/0" and &1.message =~ "public function")
           )
  end

  # Row #12 — defguard/defguardp are counted (participate in ordering)
  test "#12 :separate counts defguard/defguardp in ordering" do
    ordered = """
    defmodule M do
      defguard is_apple(x) when x == :apple
      defguard is_banana(x) when x == :banana

      defguardp is_aardvark(x) when x == :aardvark
      defguardp is_zebra(x) when x == :zebra
    end
    """

    assert [] == issues(ordered, %{type: :alphabetized_functions, mode: :separate})

    # Positive control: swapping the public guards flags one of them, proving
    # defguard nodes are extracted and ordered (not silently skipped).
    broken = """
    defmodule M do
      defguard is_banana(x) when x == :banana
      defguard is_apple(x) when x == :apple
    end
    """

    result = issues(broken, %{type: :alphabetized_functions, mode: :separate})
    assert Enum.any?(result, &(&1.trigger == "is_apple/1" and &1.message =~ "public function"))
  end

  # Row #13 — multi-clause function collapses to one unit (ordered → [])
  test "#13 :all treats a multi-clause function as a single ordered unit" do
    ordered = """
    defmodule M do
      def apple(:x), do: 1
      def apple(:y), do: 2
      def zebra(), do: 3
    end
    """

    assert [] == issues(ordered, %{type: :alphabetized_functions, mode: :all})

    # Positive control: reordering the units flags (Row #14 territory).
    reordered = """
    defmodule M do
      def zebra(1), do: 1
      def zebra(2), do: 2
      def apple(), do: :ok
    end
    """

    refute [] == issues(reordered, %{type: :alphabetized_functions, mode: :all})
  end

  # Row #14 — mis-ordered multi-clause reports exactly one issue for that
  # function, anchored at the first clause line (not one issue per clause).
  test "#14 :all reports a mis-ordered multi-clause function once, at its first clause" do
    source = """
    defmodule M do
      def banana(:x), do: 1
      def banana(:y), do: 2
      def apple(), do: :ok
    end
    """

    result = issues(source, %{type: :alphabetized_functions, mode: :all})

    banana_issues = Enum.filter(result, &(&1.trigger == "banana/1"))
    assert length(banana_issues) == 1
    assert hd(banana_issues).line_no == 2
  end
end
