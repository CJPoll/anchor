defmodule Anchor.Domain.Placement.OwnershipTest do
  # Domain (ADR 002). DND-5448: the owner of a function, from its spec and its slices,
  # on hand-built graphs (Anchor.Test.PlacementModels).
  #
  # Sabotage record: ../../../sabotage_records/placement-20261106-dnd_5448_placement_core.md
  use ExUnit.Case, async: true

  import Anchor.Test.PlacementModels

  alias Anchor.Domain.Placement.Ownership

  defp graph(spec_text, opts \\ []) do
    model(
      [
        {Inv, "domain", [], struct: [:x]},
        {Pay, "domain", [], struct: [:y]},
        {F, "domain", [{:f, Keyword.get(opts, :arity, 1)}],
         specs: if(spec_text, do: %{{:f, Keyword.get(opts, :arity, 1)} => spec_text}, else: %{}),
         clauses: %{{:f, Keyword.get(opts, :arity, 1)} => Keyword.get(opts, :clauses, [])}}
      ],
      []
    ).graph
  end

  describe "output_owner/2" do
    for {name, spec, expected} <- [
          {"a struct literal", "f(term()) :: %Inv{}", {:ok, Inv}},
          {"a t() type", "f(term()) :: Inv.t()", :named},
          {"nil beside it", "f(term()) :: Inv.t() | nil", :named},
          {"an ok tuple with an error member", "f(term()) :: {:ok, Inv.t()} | {:error, term()}",
           :named}
        ] do
      test "#{name} is the struct's module" do
        graph = graph(unquote(spec))
        graph = put_in(graph.modules[Inv].types, %{{:t, 0} => {:type, spec("t() :: %Inv{}")}})

        expected = with :named <- unquote(Macro.escape(expected)), do: {:ok, Inv}
        assert Ownership.output_owner(graph, {F, :f, 1}) == expected
      end
    end

    test "an ok tuple as a beam writes it, a tuple node, is the struct's module" do
      graph = graph("f(term()) :: %Inv{}")
      ok = {:|, [], [{:{}, [], [:ok, spec("%Inv{}")]}, {:{}, [], [:error, spec("term()")]}]}
      spec = {:"::", [], [{:f, [], [spec("term()")]}, ok]}
      graph = put_in(graph.modules[F].specs, %{{:f, 1} => [spec]})

      assert Ownership.output_owner(graph, {F, :f, 1}) == {:ok, Inv}
    end

    test "two different structs are ambiguous" do
      graph = graph("f(term()) :: %Inv{} | %Pay{}")

      assert Ownership.output_owner(graph, {F, :f, 1}) == :ambiguous
    end

    test "no spec is no_spec" do
      assert Ownership.output_owner(graph(nil), {F, :f, 1}) == :no_spec
    end

    test "a struct beside a non-error member has no owner" do
      assert Ownership.output_owner(graph("f(term()) :: %Inv{} | integer()"), {F, :f, 1}) == :none
    end

    test "a non-project struct is not owned" do
      assert Ownership.output_owner(graph("f(term()) :: DateTime.t()"), {F, :f, 1}) == :none
      assert Ownership.output_owner(graph("f(term()) :: %DateTime{}"), {F, :f, 1}) == :none
    end
  end

  describe "input_owner/3" do
    defp input_owner(spec, clauses) do
      arity = spec |> Code.string_to_quoted!() |> elem(2) |> hd() |> elem(2) |> length()
      graph = graph(spec, arity: arity, clauses: clauses)
      node = graph.modules[F].functions[{:f, arity}]
      Ownership.input_owner(graph, {F, :f, arity}, node)
    end

    test "a predicate over one struct is that struct's" do
      assert input_owner("f(%Inv{}, integer()) :: boolean()", [
               "def f(%Inv{} = l, now), do: l.x > now"
             ]) == {:ok, Inv}
    end

    test "a struct parameter matched and not used is not on the slice" do
      assert input_owner("f(%Inv{}, integer()) :: integer()", ["def f(%Inv{}, n), do: n * 2"]) ==
               :none
    end

    test "a struct parameter bound and not used is not on the slice" do
      assert input_owner("f(%Inv{}, integer()) :: integer()", [
               "def f(%Inv{} = l, n) do\n  _ = n\n  m = l\n  _ = m\n  n * 2\nend"
             ]) == :none
    end

    test "a field bound in the head and used is on the slice" do
      assert input_owner("f(%Inv{}, integer()) :: integer()", [
               "def f(%Inv{x: x}, n), do: x + n"
             ]) == {:ok, Inv}
    end

    test "a parameter only a guard reads decides the result: it is on the slice" do
      assert input_owner("f(%Inv{}, integer()) :: integer()", [
               "def f(l, n) when l.x > 0, do: n"
             ]) == {:ok, Inv}
    end

    test "two struct parameters on the slice are ambiguous" do
      assert input_owner("f(%Inv{}, %Pay{}) :: boolean()", [
               "def f(%Inv{} = a, %Pay{} = b), do: a.x > b.y"
             ]) == :ambiguous
    end

    test "on the slice in one clause only is not on the slice" do
      assert input_owner("f(%Inv{}, integer()) :: integer()", [
               "def f(%Inv{} = l, 0), do: l.x",
               "def f(%Inv{}, n), do: n"
             ]) == :none
    end

    test "a struct return is not judged here" do
      assert input_owner("f(%Inv{}) :: %Pay{}", ["def f(%Inv{} = l), do: l"]) == :none
    end

    test "no spec is no_spec" do
      graph = graph(nil)

      assert Ownership.input_owner(graph, {F, :f, 1}, graph.modules[F].functions[{:f, 1}]) ==
               :no_spec
    end

    test "a function with no clause to read is unjoined" do
      assert input_owner("f(%Inv{}) :: boolean()", []) == :unjoined
    end

    test "a named parameter's type counts" do
      assert input_owner("f(lease :: %Inv{}) :: boolean()", ["def f(l), do: l.x"]) == {:ok, Inv}
    end
  end

  describe "primitive?/1" do
    for type <- [
          "boolean()",
          "integer()",
          "float()",
          "number()",
          "atom()",
          "binary()",
          "String.t()",
          "non_neg_integer()",
          ":a | :b",
          "boolean() | :unknown"
        ] do
      test "#{type} is a primitive" do
        assert Ownership.primitive?(spec(unquote(type)))
      end
    end

    for type <- ["map()", "%Inv{}", "Inv.t()", "[integer()]", "integer() | %Inv{}", "nil"] do
      test "#{type} is no primitive" do
        refute Ownership.primitive?(spec(unquote(type)))
      end
    end
  end
end
