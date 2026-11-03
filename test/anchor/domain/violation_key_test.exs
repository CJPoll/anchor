defmodule Anchor.Domain.ViolationKeyTest do
  # DND-5441: a graph finding's stable key. Pure Domain.
  #
  # Sabotage record: ../../sabotage_records/baseline-20261103-dnd_5441_graph_rules_a.md
  use ExUnit.Case, async: true

  alias Anchor.Domain.Violation
  alias Anchor.Domain.ViolationKey

  describe "graph_key/3" do
    test "<id>|<subject>|<detail>, the id when the rule has one, else its type" do
      assert ViolationKey.graph_key(%{type: :layering, id: "web"}, "A.f/1", "-> B.g/0") ==
               "web|A.f/1|-> B.g/0"

      assert ViolationKey.graph_key(%{type: :layering, id: nil}, "A.f/1", "-> B.g/0") ==
               "layering|A.f/1|-> B.g/0"
    end

    test "a newline in any segment raises" do
      for {subject, detail} <- [{"A\n", "d"}, {"A", "d\r"}] do
        assert_raise ArgumentError, ~r/newline/, fn ->
          ViolationKey.graph_key(%{type: :layering, id: "x"}, subject, detail)
        end
      end

      assert_raise ArgumentError, fn ->
        ViolationKey.graph_key(%{type: :layering, id: "x\ny"}, "A", "d")
      end
    end

    test "two violations differing only in line give the same key (no line in a key)" do
      rule = %{type: :layering, id: "r"}

      for line <- [1, 7, 120, 9999] do
        violation = %Violation{
          message: "m at #{line}",
          line: line,
          key: ViolationKey.graph_key(rule, ViolationKey.mfa({A, :f, 1}), "-> B.g/0")
        }

        assert violation.key == "r|A.f/1|-> B.g/0"
        refute violation.key =~ Integer.to_string(line) and line > 1
      end
    end
  end

  describe "mfa/1" do
    test "Mod.fun/arity without the Elixir. prefix; an Erlang module keeps its colon" do
      assert ViolationKey.mfa({MyApp.Repo, :insert, 2}) == "MyApp.Repo.insert/2"
      assert ViolationKey.mfa({:ets, :new, 2}) == ":ets.new/2"
    end
  end
end
