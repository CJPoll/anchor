defmodule Anchor.Domain.Sabotage.NoMutantTest do
  # DND-5617: why a changed function yielded no mutant, read from the real
  # generator's results.
  # Sabotage record: ../../../sabotage_records/sabotage-20261103-dnd_5617_sabotage_cfa_batch.md
  use ExUnit.Case, async: true

  alias Anchor.Domain.Sabotage.Mutator
  alias Anchor.Domain.Sabotage.NoMutant

  defp generated(source), do: Mutator.generate(source, "lib/calc.ex", {Calc, :add, 2})

  test "N1: a function with a mutant has no reason" do
    source = "defmodule Calc do\n  def add(a, b) do\n    a + b\n  end\nend\n"
    assert NoMutant.reason(generated(source)) == nil
  end

  test "N2: every edit skipped: `skipped:` with each operator and reason" do
    source = "defmodule Calc do\n  def add(_a, _b) do\n    x = :ok\n    x\n  end\nend\n"

    assert NoMutant.reason(generated(source)) ==
             "skipped: delete_statement: orphans variable `x` bound at line 3 and used at line 4"
  end

  test "N3: a function no literal clause covers is a macro" do
    assert NoMutant.reason(generated("defmodule Calc do\nend\n")) ==
             "macro: no literal def/defp clause in the source (a macro made it)"
  end

  test "N4: nothing to change is `no mutable site`" do
    source = "defmodule Calc do\n  def add(_a, _b) do\n    :ok\n  end\nend\n"
    assert NoMutant.reason(generated(source)) == "no mutable site"
  end

  test "N5: a file error names itself" do
    assert NoMutant.reason({:error, {:parse_error, 3, "missing end"}}) ==
             "does not parse at line 3: missing end"

    assert NoMutant.reason({:error, {:unreadable, :enoent}}) == "could not be read (:enoent)"
  end
end
