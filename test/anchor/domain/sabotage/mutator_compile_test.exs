defmodule Anchor.Domain.Sabotage.MutatorCompileTest do
  # DND-5471: the compile canary. Every mutant the generator emits of the
  # canary fixture compiles with no error and no warning (so it compiles under
  # --warnings-as-errors); every edit it refused as an orphan does not. The
  # test, not the generator, compiles: each mutant under its own module name,
  # purged afterwards.
  # Sabotage record: ../../../sabotage_records/sabotage-20261103-dnd_5471.md
  use ExUnit.Case, async: true

  alias Anchor.Domain.Sabotage.Mutator
  alias Anchor.Domain.Sabotage.Patch

  @canary_path "test/fixtures/sabotage/canary.ex"
  @canary AnchorFixtures.Sabotage.Canary
  @functions [
    {@canary, :statements, 1},
    {@canary, :checked, 1},
    {@canary, :effects, 2},
    {@canary, :classify, 1},
    {@canary, :unwrap, 1},
    {@canary, :pipeline, 2},
    {@canary, :decide, 2},
    {@canary, :grade, 1},
    {@canary, :pick, 2},
    {@canary, :scaled, 1},
    {@canary, :scaled, 2},
    {@canary, :bits, 2},
    {@canary, :limited, 2},
    {@canary, :counted, 1},
    {@canary, :host, 1},
    {Module.concat(@canary, Nested), :twice, 1}
  ]

  setup_all do
    canary = File.read!(@canary_path)

    results =
      Enum.map(@functions, fn mfa ->
        {:ok, result} = Mutator.generate(canary, @canary_path, mfa)
        result
      end)

    %{canary: canary, results: results}
  end

  # Compiles `source` with the canary's module renamed; {:ok | :error, diagnostics}.
  defp compile(source, tag) do
    name = "AnchorFixtures.MutatorCompileTest.Canary#{tag}"

    renamed =
      String.replace(
        source,
        "defmodule AnchorFixtures.Sabotage.Canary do",
        "defmodule #{name} do"
      )

    {result, diagnostics} =
      Code.with_diagnostics(fn ->
        try do
          Code.compile_string(renamed, "canary_#{tag}.ex")
        rescue
          error -> {:error, Exception.message(error)}
        end
      end)

    for module <- [Module.concat([name]), Module.concat([name, "Nested"])] do
      :code.purge(module)
      :code.delete(module)
    end

    status = if match?({:error, _message}, result), do: :error, else: :ok
    {status, Enum.map(diagnostics, & &1.message)}
  end

  test "positive control: the canary itself compiles with no warning", %{canary: canary} do
    assert compile(canary, "Original") == {:ok, []}
  end

  test "1: every emitted mutant compiles with no error and no warning", %{
    canary: canary,
    results: results
  } do
    mutants = Enum.flat_map(results, & &1.mutants)
    assert length(mutants) >= 30

    for {mutant, index} <- Enum.with_index(mutants) do
      mutated = Patch.apply_range(canary, mutant.range, mutant.replacement)

      compiled = compile(mutated, "M#{index}")

      assert compiled == {:ok, []},
             "#{mutant.operator} #{inspect(mutant.variant)} #{inspect(mutant.target)}: " <>
               inspect(compiled)
    end
  end

  test "2: every edit refused as an orphan would not compile cleanly", %{
    canary: canary,
    results: results
  } do
    refused = results |> Enum.flat_map(& &1.skipped) |> Enum.filter(& &1.range)
    assert length(refused) >= 4

    for {skipped, index} <- Enum.with_index(refused) do
      mutated = Patch.apply_range(canary, skipped.range, skipped.replacement)

      assert compile(mutated, "S#{index}") != {:ok, []},
             "#{skipped.operator} #{inspect(skipped.target)}: #{skipped.reason}"
    end
  end
end
