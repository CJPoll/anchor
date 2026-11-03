defmodule Anchor.Domain.Sabotage.MutatorDefimplTest do
  # DND-5624: the generator resolves a protocol implementation's function
  # (`P.T`, as `FunctionSpans` names it) to the def inside the matching
  # `defimpl` block, for every source shape `FunctionSpans` names.
  # Sabotage record: ../../../sabotage_records/sabotage-20261103-dnd_5624_sabotage_defimpl.md
  use ExUnit.Case, async: true

  alias Anchor.Domain.Sabotage.FunctionSpans
  alias Anchor.Domain.Sabotage.Mutant
  alias Anchor.Domain.Sabotage.Mutator
  alias Anchor.Domain.Sabotage.NoMutant

  @path "lib/calc.ex"

  # The impl's def is lines 2..5 (`top_level`) or 5..8 (`nested`): every
  # mutant's edit lies inside it.
  @top_level """
  defimpl String.Chars, for: Calc do
    def to_string(c) do
      Logger.info("rendering")
      c.name
    end
  end
  """

  @nested """
  defmodule Calc do
    defstruct [:name]

    defimpl String.Chars do
      def to_string(c) do
        Logger.info("rendering")
        c.name
      end
    end
  end
  """

  @listed """
  defimpl String.Chars, for: [Calc, Other] do
    def to_string(c) do
      Logger.info("rendering")
      c.name
    end
  end
  """

  @not_literal """
  defimpl String.Chars, for: target do
    def to_string(c) do
      Logger.info("rendering")
      c.name
    end
  end
  """

  @protocol """
  defprotocol Shape do
    def area(shape)

    defmodule Helpers do
      def twice(x) do
        Logger.info("twice")
        x * 2
      end
    end
  end

  defimpl Shape, for: Calc do
    def area(c), do: c.w * c.h

    defmodule Helpers do
      def half(x) do
        Logger.info("half")
        x / 2
      end
    end
  end
  """

  # `{operator, target}` of every mutant the impl's def yields.
  @impl_mutants [
    {:drop_effect_call, "Logger.info(\"rendering\")"},
    {:return_input, "to_string(c)"}
  ]

  defp generate!(source, mfa) do
    assert {:ok, %{mutants: mutants}} = Mutator.generate(source, @path, mfa)
    mutants
  end

  defp summary(mutants), do: Enum.map(mutants, &{&1.operator, &1.target})

  defp lines(%Mutant{range: {{first, _c1}, {last, _c2}}}), do: first..last

  defp within?(mutants, span),
    do: Enum.all?(mutants, &(lines(&1).first >= span.first and lines(&1).last <= span.last))

  describe "generate/4 inside defimpl (DND-5624)" do
    test "D1: a top-level defimpl P, for: T: P.T's def is mutated at its own lines" do
      mutants = generate!(@top_level, {String.Chars.Calc, :to_string, 1})

      assert summary(mutants) == @impl_mutants
      assert within?(mutants, 2..5)
      assert Enum.all?(mutants, &(&1.module == String.Chars.Calc))
    end

    test "D2: a defimpl with no for: inside defmodule T is P.T, never T's own function" do
      mutants = generate!(@nested, {String.Chars.Calc, :to_string, 1})

      assert summary(mutants) == @impl_mutants
      assert within?(mutants, 5..8)

      assert Mutator.generate(@nested, @path, {Calc, :to_string, 1}) ==
               {:error, :not_in_source}
    end

    test "D3: for: [T1, T2]: each P.Tn resolves to the one def; the same edits, an id per target" do
      calc = generate!(@listed, {String.Chars.Calc, :to_string, 1})
      other = generate!(@listed, {String.Chars.Other, :to_string, 1})

      assert summary(calc) == @impl_mutants
      assert within?(calc, 2..5)

      assert Enum.map(calc, &{&1.range, &1.replacement}) ==
               Enum.map(other, &{&1.range, &1.replacement})

      assert Enum.map(other, & &1.module) == [String.Chars.Other, String.Chars.Other]
      assert MapSet.disjoint?(MapSet.new(calc, & &1.id), MapSet.new(other, & &1.id))

      assert Mutator.generate(@listed, @path, {String.Chars.Third, :to_string, 1}) ==
               {:error, :not_in_source}
    end

    test "D4: a defimpl's for: __MODULE__, a one-line defimpl and one inside an if resolve too" do
      source = """
      defmodule Calc do
        defimpl Inspect, for: __MODULE__ do
          def inspect(c, _opts) do
            Logger.info("inspecting")
            c.name
          end
        end

        if Code.ensure_loaded?(Jason) do
          defimpl Jason.Encoder do
            def encode(c, opts) do
              Logger.info("encoding")
              c.name
            end
          end
        end
      end

      defimpl List.Chars, for: Calc, do: (def to_charlist(c), do: Logger.info(c))
      """

      inspect = generate!(source, {Inspect.Calc, :inspect, 2})

      assert summary(inspect) == [
               {:drop_effect_call, "Logger.info(\"inspecting\")"},
               {:return_input, "inspect(c, _opts)"}
             ]

      assert within?(inspect, 3..6)

      encode = generate!(source, {Jason.Encoder.Calc, :encode, 2})

      assert summary(encode) == [
               {:drop_effect_call, "Logger.info(\"encoding\")"},
               {:return_input, "encode(c, opts)"},
               {:return_input, "encode(c, opts)"}
             ]

      assert within?(encode, 11..14)

      charlist = generate!(source, {List.Chars.Calc, :to_charlist, 1})
      assert summary(charlist) == [{:return_input, "to_charlist(c)"}]
      assert within?(charlist, 19..19)
    end

    test "D5: positive control: a plain defmodule def is still found, beside a same-named impl def" do
      source = """
      defmodule Calc do
        def to_string(c) do
          send(self(), :own)
          c
        end

        defimpl String.Chars do
          def to_string(c) do
            Logger.info("rendering")
            c.name
          end
        end
      end
      """

      own = generate!(source, {Calc, :to_string, 1})

      assert summary(own) == [
               {:drop_effect_call, "send(self(), :own)"},
               {:return_input, "to_string(c)"}
             ]

      assert within?(own, 2..5)

      impl = generate!(source, {String.Chars.Calc, :to_string, 1})
      assert summary(impl) == @impl_mutants
      assert within?(impl, 8..11)
    end

    test "D6: a defimpl whose for: is not a literal names its own reason, never the macro line" do
      assert Mutator.generate(@not_literal, @path, {nil, :to_string, 1}) ==
               {:error, :defimpl_target_not_literal}

      assert NoMutant.reason(Mutator.generate(@not_literal, @path, {nil, :to_string, 1})) ==
               "defimpl target not a literal: the source does not spell its module name " <>
                 "(a for: that is not a module name, or an unnamed enclosing module)"

      # A function no module can be named for, outside any defimpl, is still
      # not in source.
      built = "defmodule unquote(name) do\n  def to_string(c), do: c\nend\n"
      assert Mutator.generate(built, @path, {nil, :to_string, 1}) == {:error, :not_in_source}
    end

    test "D7: the orphan check reads a defimpl's own body: the last call of its private helper is kept" do
      source = """
      defimpl String.Chars, for: Calc do
        def to_string(c) do
          _ = check(c)
          c.name
        end

        defp check(c), do: c
      end
      """

      assert {:ok, %{mutants: mutants, skipped: skipped}} =
               Mutator.generate(source, @path, {String.Chars.Calc, :to_string, 1})

      assert mutants == []

      assert Enum.map(skipped, &{&1.operator, &1.reason}) == [
               {:delete_statement, "removes the last use of function `check/1`"},
               {:return_input, "removes the last use of function `check/1`"}
             ]
    end

    test "D8: a defimpl nested in T is its own module: its helper call never keeps T's own alive" do
      source = """
      defmodule Calc do
        def name(c) do
          _ = check(c)
          c.name
        end

        defp check(c), do: c

        defimpl String.Chars do
          def to_string(c), do: check(c)

          defp check(c), do: c.name
        end
      end
      """

      assert {:ok, %{mutants: [], skipped: skipped}} =
               Mutator.generate(source, @path, {Calc, :name, 1})

      assert Enum.map(skipped, &{&1.operator, &1.reason}) == [
               {:delete_statement, "removes the last use of function `check/1`"},
               {:return_input, "removes the last use of function `check/1`"}
             ]
    end

    test "D9: a defimpl inside quote builds code; it defines nothing to mutate" do
      source = """
      defmodule Calc do
        defmacro __using__(_opts) do
          quote do
            defimpl String.Chars do
              def to_string(c), do: Logger.info(c)
            end
          end
        end
      end
      """

      assert Mutator.generate(source, @path, {String.Chars.Calc, :to_string, 1}) ==
               {:error, :not_in_source}
    end

    test "D11: a defprotocol's declarations are in source with nothing to mutate; modules nested in a defprotocol or a defimpl resolve" do
      assert Mutator.generate(@protocol, @path, {Shape, :area, 1}) ==
               {:ok, %{mutants: [], skipped: []}}

      assert NoMutant.reason(Mutator.generate(@protocol, @path, {Shape, :area, 1})) ==
               "no mutable site"

      in_protocol = generate!(@protocol, {Shape.Helpers, :twice, 1})

      assert summary(in_protocol) == [
               {:drop_effect_call, "Logger.info(\"twice\")"},
               {:return_input, "twice(x)"}
             ]

      assert within?(in_protocol, 5..8)

      in_impl = generate!(@protocol, {Shape.Calc.Helpers, :half, 1})

      assert summary(in_impl) == [
               {:drop_effect_call, "Logger.info(\"half\")"},
               {:return_input, "half(x)"}
             ]

      assert within?(in_impl, 16..19)
    end

    test "D12: for: nil and for: [] are the enclosing module, as FunctionSpans reads them" do
      for target <- ["nil", "[]"] do
        source = """
        defmodule Calc do
          defimpl String.Chars, for: #{target} do
            def to_string(c) do
              Logger.info("rendering")
              c.name
            end
          end
        end
        """

        assert {:ok, [%{module: String.Chars.Calc}]} = FunctionSpans.spans(source, @path)
        assert summary(generate!(source, {String.Chars.Calc, :to_string, 1})) == @impl_mutants
      end
    end

    test "D10: every function FunctionSpans names in these sources the generator resolves" do
      sources = [@top_level, @nested, @listed, @protocol]

      for source <- sources,
          {:ok, spans} = FunctionSpans.spans(source, @path),
          span <- spans,
          not span.excluded_macro do
        assert {:ok, %{mutants: _mutants}} =
                 Mutator.generate(source, @path, {span.module, span.name, span.arity}),
               "#{inspect(span.module)}.#{span.name}/#{span.arity} was not resolved"
      end
    end
  end
end
