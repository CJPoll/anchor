defmodule Anchor.Domain.Sabotage.OrphanCheckImportsTest do
  # DND-5563: an `import` is used or unused per what the compiler says. With
  # `only:` a list, each name is its own import (`unused import String.upcase/1`);
  # with none, the import is unused only when no call reaches it
  # (`unused import String`). A mutant that removes the last call of one name
  # while the import is still used for others is a mutant, not an orphan. The
  # test compiles the mutants it expects and the edits it refuses.
  # Sabotage record: ../../../sabotage_records/sabotage-20261103-dnd_5570_sabotage_hardening.md
  use ExUnit.Case, async: true

  alias Anchor.Domain.Sabotage.Mutator
  alias Anchor.Domain.Sabotage.Patch

  defp source(body, tag), do: "defmodule AnchorFixtures.OrphanImports#{tag} do\n#{body}\nend\n"

  defp generate(source, tag) do
    {:ok, result} =
      Mutator.generate(
        source,
        "lib/m.ex",
        {Module.concat(["AnchorFixtures", "OrphanImports#{tag}"]), :f, 1},
        operators: [:delete_statement]
      )

    result
  end

  # {:ok | :error, warning and error messages}; the module is purged.
  defp compile(source, tag) do
    {result, diagnostics} =
      Code.with_diagnostics(fn ->
        try do
          Code.compile_string(source, "m_#{tag}.ex")
        rescue
          error -> {:error, Exception.message(error)}
        end
      end)

    :code.purge(Module.concat(["AnchorFixtures", "OrphanImports#{tag}"]))
    :code.delete(Module.concat(["AnchorFixtures", "OrphanImports#{tag}"]))

    {if(match?({:error, _message}, result), do: :error, else: :ok),
     Enum.map(diagnostics, & &1.message)}
  end

  defp applied(source, edit), do: Patch.apply_range(source, edit.range, edit.replacement)

  defp targets(items), do: Enum.map(items, & &1.target)

  describe "an import with no only: list (the import is unused when no call reaches it)" do
    test "1: removing the last call of one name, the import still used for another, is a mutant that compiles" do
      src =
        source(
          """
            import String

            def f(x) do
              upcase(x)
              downcase(x)
              x
            end
          """,
          "A"
        )

      assert {:ok, []} =
               compile(String.replace(src, "OrphanImportsA", "OrphanImportsAOrig"), "AOrig")

      result = generate(src, "A")

      assert targets(result.mutants) == ["upcase(x)", "downcase(x)"]
      assert result.skipped == []

      for {mutant, i} <- Enum.with_index(result.mutants) do
        mutated = applied(src, mutant) |> String.replace("OrphanImportsA", "OrphanImportsAM#{i}")
        assert compile(mutated, "AM#{i}") == {:ok, []}, mutant.target
      end
    end

    test "2: positive control: removing the only call that reaches the import is refused, and it would warn" do
      src =
        source(
          """
            import String

            def f(x) do
              upcase(x)
              x + 1
            end
          """,
          "B"
        )

      result = generate(src, "B")

      assert result.mutants == []
      assert [%{target: "upcase(x)", reason: reason} = skipped] = result.skipped

      assert reason ==
               "removes the last use of an `import` (no call to an imported function is left)"

      mutated = applied(src, skipped) |> String.replace("OrphanImportsB", "OrphanImportsBM")
      assert {_status, warnings} = compile(mutated, "BM")
      assert Enum.any?(warnings, &(&1 =~ "unused import String"))
    end

    test "3: another function's call keeps the import used: the mutant is not refused" do
      src =
        source(
          """
            import String

            def f(x) do
              upcase(x)
              x
            end

            def g(x), do: downcase(x)
          """,
          "C"
        )

      result = generate(src, "C")

      assert targets(result.mutants) == ["upcase(x)"]
      assert result.skipped == []

      mutated =
        applied(src, hd(result.mutants)) |> String.replace("OrphanImportsC", "OrphanImportsCM")

      assert compile(mutated, "CM") == {:ok, []}
    end
  end

  test "7: no import at all: a call to a name a `use` brought in is not an import's last call" do
    src =
      source(
        """
          use Helpers

          def f(x) do
            brought_in(x)
            x
          end
        """,
        "G"
      )

    result = generate(src, "G")

    assert targets(result.mutants) == ["brought_in(x)"]
    assert result.skipped == []
  end

  describe "an import with an only: list (each name is its own import)" do
    test "4: removing the last call of a listed name is refused even when another name is still used" do
      src =
        source(
          """
            import String, only: [upcase: 1, downcase: 1]

            def f(x) do
              upcase(x)
              downcase(x)
              x
            end
          """,
          "D"
        )

      result = generate(src, "D")

      assert result.mutants == []

      assert Enum.map(result.skipped, &{&1.target, &1.reason}) == [
               {"upcase(x)", "removes the last use of function `upcase/1`"},
               {"downcase(x)", "removes the last use of function `downcase/1`"}
             ]

      for skipped <- result.skipped do
        mutated = applied(src, skipped) |> String.replace("OrphanImportsD", "OrphanImportsDM")
        assert {_status, warnings} = compile(mutated, "DM")
        assert Enum.any?(warnings, &(&1 =~ "unused import String.")), skipped.target
      end
    end

    test "5: a listed name called elsewhere too: removing one of its calls is a mutant that compiles" do
      src =
        source(
          """
            import String, only: [upcase: 1]

            def f(x) do
              upcase(x)
              x
            end

            def g(x), do: upcase(x)
          """,
          "E"
        )

      result = generate(src, "E")

      assert targets(result.mutants) == ["upcase(x)"]

      mutated =
        applied(src, hd(result.mutants)) |> String.replace("OrphanImportsE", "OrphanImportsEM")

      assert compile(mutated, "EM") == {:ok, []}
    end
  end

  describe "both kinds of import in one module" do
    test "6: the listed name is its own import; the unlisted calls share the other" do
      src =
        source(
          """
            import String, only: [upcase: 1]
            import Enum

            def f(x) do
              upcase(x)
              count(x)
              x
            end
          """,
          "F"
        )

      result = generate(src, "F")

      assert result.mutants == []

      assert Enum.map(result.skipped, &{&1.target, &1.reason}) == [
               {"upcase(x)", "removes the last use of function `upcase/1`"},
               {"count(x)",
                "removes the last use of an `import` (no call to an imported function is left)"}
             ]

      for skipped <- result.skipped do
        mutated = applied(src, skipped) |> String.replace("OrphanImportsF", "OrphanImportsFM")
        assert {_status, warnings} = compile(mutated, "FM")
        assert Enum.any?(warnings, &(&1 =~ "unused import")), skipped.target
      end
    end
  end
end
