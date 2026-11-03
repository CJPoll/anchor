defmodule Anchor.Domain.Sabotage.EffectCallsTest do
  # DND-5471: which statements are effect calls (drop_effect_call) and which
  # are not (delete_statement).
  # Sabotage record: ../../../sabotage_records/sabotage-20261103-dnd_5471.md
  use ExUnit.Case, async: true

  alias Anchor.Domain.Sabotage.EffectCalls

  defp effect?(source, tokens \\ []),
    do: source |> Code.string_to_quoted!() |> EffectCalls.effect?(tokens)

  describe "effect?/2" do
    test "1: the default effect calls are effects" do
      for source <- [
            "MyApp.Repo.insert(cs)",
            "Repo.update!(cs)",
            "cs |> Repo.insert()",
            "send(pid, m)",
            "Kernel.send(pid, m)",
            "spawn(fn -> :ok end)",
            "GenServer.cast(s, m)",
            "Process.put(:k, 1)",
            ":ets.insert(t, r)",
            "Logger.info(\"x\")",
            "File.write!(p, b)",
            "System.cmd(\"ls\", [])",
            "IO.puts(x)",
            "Task.start(f)",
            "Phoenix.PubSub.broadcast(ps, t, m)"
          ] do
        assert effect?(source), source
      end
    end

    test "2: positive control: pure calls and a non-Repo module are not effects" do
      for source <- [
            "Enum.map(xs, f)",
            "Map.put(m, k, v)",
            "MyApp.Repository.insert(x)",
            "Repo.get(Schema, id)",
            "send(pid)",
            "validate(x)",
            "foo(Repo.insert(x))",
            "x + 1"
          ] do
        refute effect?(source), source
      end
    end

    test "3: an extra FunctionRef token makes a call an effect" do
      assert effect?("Notifier.push(x)", ["Notifier.push/1"])
      assert effect?("Notifier.push(x)", ["Notifier.push"])
      refute effect?("Notifier.push(x)")
      refute effect?("Notifier.push(x, y)", ["Notifier.push/1"])
      assert effect?(":gen_tcp.send(s, p)", [":gen_tcp.send/2"])
    end

    test "a token that does not parse is refused, never a token that matches nothing" do
      assert_raise ArgumentError,
                   ~r/sabotage effect_calls: "Notifier" is not a function reference/,
                   fn ->
                     effect?("Notifier.push(x)", ["Notifier"])
                   end
    end
  end
end
