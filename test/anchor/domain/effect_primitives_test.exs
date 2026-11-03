defmodule Anchor.Domain.EffectPrimitivesTest do
  # Domain (ADR 002). DND-5498 R2-R3: the effect and escape table, read by
  # the demand analysis, keyed by the callee as Core names it.
  #
  # Sabotage record: ../../sabotage_records/demand-20261103-dnd_5498_demand.md
  use ExUnit.Case, async: true

  alias Anchor.Domain.EffectPrimitives

  describe "escape?/1" do
    test "send, spawn, Task, ETS writes, persistent_term and the process dictionary escape" do
      for mfa <- [
            {:erlang, :send, 2},
            {:erlang, :spawn, 1},
            {Task, :start, 1},
            {Task, :async, 1},
            {:ets, :insert, 2},
            {:persistent_term, :put, 2},
            {:erlang, :put, 2},
            {Process, :put, 2},
            {GenServer, :cast, 2}
          ] do
        assert EffectPrimitives.escape?(mfa), "#{inspect(mfa)} should escape"
      end
    end

    test "a read is no escape" do
      for mfa <- [{:ets, :lookup, 2}, {:persistent_term, :get, 1}, {:erlang, :get, 1}] do
        refute EffectPrimitives.escape?(mfa), "#{inspect(mfa)} should not escape"
      end
    end
  end

  describe "effect?/2" do
    test "IO, Logger, a raise and a Repo write are effects; a pure call is not" do
      assert EffectPrimitives.effect?({IO, :puts, 1}, [])
      assert EffectPrimitives.effect?({Logger, :__do_log__, 4}, [])
      assert EffectPrimitives.effect?({:erlang, :error, 1}, [])
      assert EffectPrimitives.effect?({MyApp.Repo, :insert, 2}, [])
      refute EffectPrimitives.effect?({MyApp.Repository, :insert, 2}, [])
      refute EffectPrimitives.effect?({MyApp.Repo, :get, 2}, [])
      refute EffectPrimitives.effect?({:repo, :insert, 2}, [])
      refute EffectPrimitives.effect?({String, :upcase, 1}, [])
    end

    test "an extra token makes its function an effect, at its arity only" do
      extra = EffectPrimitives.parse_extra!(["Notifier.push/1"])
      assert EffectPrimitives.effect?({Notifier, :push, 1}, extra)
      refute EffectPrimitives.effect?({Notifier, :push, 2}, extra)
      refute EffectPrimitives.effect?({Notifier, :push, 1}, [])
    end

    test "a module token makes every function of that module an effect" do
      extra = EffectPrimitives.parse_extra!(["Req", ":gen_tcp"])
      assert EffectPrimitives.effect?({Req, :get, 2}, extra)
      assert EffectPrimitives.effect?({:gen_tcp, :connect, 3}, extra)
      refute EffectPrimitives.effect?({Req.Request, :new, 1}, extra)
      refute EffectPrimitives.effect?({Req, :get, 2}, [])
    end

    test "module_name/1 spells a module as a token does" do
      assert EffectPrimitives.module_name(IO) == "IO"
      assert EffectPrimitives.module_name(:ets) == ":ets"
    end

    test "a token that does not parse raises with the grammar's message" do
      assert_raise ArgumentError, ~r/is not a function reference/, fn ->
        EffectPrimitives.parse_extra!(["Notifier.*"])
      end
    end

    test "default/0 lists every row once with its kind" do
      rows = EffectPrimitives.default()
      assert {:escape, {":erlang", :send, :*}} in rows
      assert {:effect, {"IO", :*, :*}} in rows
      assert length(rows) == length(Enum.uniq(rows))
    end
  end
end
