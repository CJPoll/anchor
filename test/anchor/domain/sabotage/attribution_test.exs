defmodule Anchor.Domain.Sabotage.AttributionTest do
  # DND-5691: ownership first, then the label, and a label credits only inside
  # its own window. Test 3's window is open at word 7.
  # Sabotage record: ../../../sabotage_records/coverage_attribution-20261106-dnd_5691_causal_attribution.md
  use ExUnit.Case, async: true

  alias Anchor.Domain.Sabotage.Attribution

  @t3 {:test, 3}
  @m {:module, M}
  # M's span ends at word 12: module_finished/2 reports it, so 12 is already past.
  @context %{windows: MapSet.new([7, 11]), module_ends: %{M => 12}}

  defp classify(owner, label, word), do: Attribution.classify(owner, label, word, @context)

  test "1: an owned call inside its window is credit" do
    assert classify(@t3, 7, 7) == {:credit, @t3}
  end

  test "2: an owned call past its window is credit and a leak" do
    assert classify(@t3, :none, 8) == {:leak, @t3}
  end

  test "3: a leaked process holding the next test's label leaks from its owner" do
    assert classify(@t3, 11, 11) == {:leak, @t3}
  end

  test "4: an owned process with no label inside its window is credited" do
    assert classify(@t3, :none, 7) == {:credit, @t3}
  end

  test "5: a module-owned call past the module is a leak, from the first word past it" do
    assert classify(@m, :none, 13) == {:leak, @m}
    assert classify(@m, :none, 12) == {:leak, @m}
  end

  test "a module-owned call inside the span is credit, whatever the label" do
    assert classify(@m, 7, 11) == {:credit, @m}
    assert classify(@m, :none, 0) == {:credit, @m}
  end

  test "6: an unowned call with its test's label inside the window is credit" do
    assert classify(nil, 7, 7) == {:credit, @t3}
  end

  test "7: a stale label on an unowned process is ambient, not credit, not a leak" do
    assert classify(nil, 7, 8) == :ambient
    assert classify(nil, 7, 11) == :ambient
  end

  test "8: an unowned call with a module label inside the span credits the module" do
    assert classify(nil, M, 11) == {:credit, @m}
  end

  test "9: a module label past the span is ambient" do
    assert classify(nil, M, 12) == :ambient
    assert classify(nil, M, 13) == :ambient
  end

  test "10: no owner and no label is ambient" do
    assert classify(nil, :none, 0) == :ambient
    assert classify(nil, :none, 7) == :ambient
  end

  test "11: an even integer is not a label" do
    assert classify(nil, 8, 8) == {:error, {:bad_label, 8}}
  end

  test "12: a foreign term is not a label" do
    assert classify(nil, {:x}, 7) == {:error, {:bad_label, {:x}}}
  end

  test "13: a module atom not in this run is not a label" do
    assert classify(nil, :other, 7) == {:error, {:bad_label, :other}}
  end

  test "an odd integer that opened no window is not a label" do
    assert classify(nil, 9, 9) == {:error, {:bad_label, 9}}
  end

  test "an owned process's label is never read, even a foreign one" do
    assert classify(@t3, {:x}, 7) == {:credit, @t3}
  end

  test "open_word/1 and test_number/1 are inverse" do
    assert Attribution.open_word(3) == 7
    assert Attribution.test_number(7) == 3
  end
end
