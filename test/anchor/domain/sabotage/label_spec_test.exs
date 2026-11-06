defmodule Anchor.Domain.Sabotage.LabelSpecTest do
  # DND-5691: the specs as data, run through the VM's own match_spec_test in this
  # process. The real installs are CallTracerTest's and the attribution fixture's.
  # Sabotage record: ../../../sabotage_records/coverage_attribution-20261106-dnd_5691_causal_attribution.md
  use ExUnit.Case, async: true

  alias Anchor.Domain.Sabotage.LabelSpec

  # This test's own token is put back, so it never reads as a foreign label in a
  # traced run: nothing is sent while it holds 7.
  defp with_label(label, fun) do
    saved = :seq_trace.get_token()
    :seq_trace.set_token(:label, label)

    try do
      fun.()
    after
      restore(saved)
    end
  end

  defp restore([]), do: :seq_trace.set_token([])
  defp restore(token), do: :seq_trace.set_token(token)

  defp without_token(fun), do: with_label(0, fn -> :seq_trace.set_token([]) && fun.() end)

  defp message(spec, args \\ []) do
    assert {:ok, result, [], []} = :erlang.match_spec_test(args, spec, :trace)
    result
  end

  describe "call_spec/0" do
    test "1: every call sends its label and word, or :none with no token" do
      assert {_label, word} = with_label(7, fn -> message(LabelSpec.call_spec()) end)
      assert is_integer(word)
      assert {7, ^word} = with_label(7, fn -> message(LabelSpec.call_spec()) end)
      assert {:none, ^word} = without_token(fn -> message(LabelSpec.call_spec()) end)
    end

    test "a module atom is carried as it is" do
      assert {AModule, _word} = with_label(AModule, fn -> message(LabelSpec.call_spec()) end)
    end
  end

  describe "patterns/0" do
    test "names the six functions, the private ones by a local pattern" do
      assert for({mfa, _spec, flags} <- LabelSpec.patterns(), do: {mfa, flags}) == [
               {{ExUnit.EventManager, :test_started, 2}, [:global]},
               {{ExUnit.EventManager, :test_finished, 2}, [:global]},
               {{ExUnit.EventManager, :module_finished, 2}, [:global]},
               {{ExUnit.OnExitHandler, :register, 1}, [:global]},
               {{ExUnit.Runner, :run_setup_all, 4}, [:local]},
               {{ExUnit.Runner, :exec_on_exit, 3}, [:local]}
             ]
    end

    test "a struct spec's argument that moved is a message the collector cannot read" do
      specs = Map.new(LabelSpec.patterns(), fn {{_m, name, _a}, spec, _flags} -> {name, spec} end)

      assert message(specs.module_finished, [:not_a_runner, :not_a_module]) == :shape_changed
      assert message(specs.run_setup_all, [:a, :b, :c, :d]) == :shape_changed
      assert message(specs.exec_on_exit, [:a, :b, :c]) == :shape_changed
    end

    test "every spec compiles for tracing" do
      for {mfa, spec, _flags} <- LabelSpec.patterns() do
        assert {:ok, _result, _flags, []} =
                 :erlang.match_spec_test([:_, :_, :_, :_], spec, :trace),
               inspect(mfa)
      end
    end
  end
end
