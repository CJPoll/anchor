defmodule Anchor.Domain.Sabotage.MutantIdTest do
  # DND-5471: a mutant's stable id. Pure table tests.
  # Sabotage record: ../../../sabotage_records/sabotage-20261103-dnd_5471.md
  use ExUnit.Case, async: true

  alias Anchor.Domain.Sabotage.MutantId

  @base %{
    module: Foo,
    name: :bar,
    arity: 2,
    operator: :delete_statement,
    variant: nil,
    target: "x = 1",
    occurrence: 0
  }

  describe "compute/1" do
    test "1: 12 lowercase hex characters, pinned to the hash input format" do
      id = MutantId.compute(@base)

      assert id =~ ~r/\A[0-9a-f]{12}\z/

      expected =
        :crypto.hash(:sha256, "Foo.bar/2|delete_statement||x = 1|0")
        |> Base.encode16(case: :lower)
        |> binary_part(0, 12)

      assert id == expected
      assert id == "297def091c0a"
    end

    test "2: the same input gives the same id" do
      assert MutantId.compute(@base) == MutantId.compute(@base)
    end

    test "3: operator, variant, target, occurrence and arity each change the id" do
      changed = [
        operator: :drop_effect_call,
        variant: true,
        target: "x = 2",
        occurrence: 1,
        arity: 3
      ]

      ids = for {key, value} <- changed, do: MutantId.compute(%{@base | key => value})

      assert length(Enum.uniq([MutantId.compute(@base) | ids])) == 6
    end
  end
end
